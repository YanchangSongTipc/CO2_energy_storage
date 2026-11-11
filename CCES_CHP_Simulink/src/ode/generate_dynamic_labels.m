% =========================================================================
% generate_dynamic_labels.m
% 路线 A：动态可行域，三个层次
%
%   Part 1  P_max(H; SOC)        恒定功率的可持续时长（降额曲面）
%   Part 2  D_LP(SOC_h, SOC_g)   24 h 调度下"存在可行轨迹"（LP）—— 线性、凸
%   Part 3  D_MILP(...)          叠加最小出力 + 模式互斥（MILP）—— 非凸
%
% 为什么要 Part 3：
%   动力学线性 + 目标线性 ⇒ LP 的值函数是初始状态的凹分段线性函数，
%   可行集仍是多面体，代理模型照样只是拟合一个闭式结构（Part 2 已验证：
%   覆盖率随初始 SOC_heat 单调，SOC_gas 只在 10% 附近起作用）。
%   一旦引入最小稳定出力（机组不能"滴灌"）和充放互斥，可行集变成
%   非凸、可能不连通，边界无法用 §3 的四条不等式表达——这时代理模型
%   才有了真正的用武之地。
%
% 输出（ML_EnergyStorage_Optimization/data/）：
%   dynamic_pmax.csv
%   dynamic_state_map.csv        LP
%   dynamic_state_map_milp.csv   MILP（最小出力 20%，充放互斥）
%   fig_dynamic_feasibility.png
% =========================================================================

clc; clear; close all;

rootDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..');
addpath(rootDir);
addpath(fullfile(rootDir, 'CCES_CHP_Simulink', 'src', 'ode'));
dataDir = fullfile(rootDir, 'ML_EnergyStorage_Optimization', 'data');

dp = cces_design_point(483);
m_full_t = dp.m_full/1000;
fprintf('设计点: α1=%.3f α2=%.3f γ1=%.3f γ2=%.3f | m_full=%.1f t | Q_cap=%.0f MWh\n', ...
    dp.alpha1, dp.alpha2, dp.gamma1, dp.gamma2, m_full_t, dp.Q_HTV_cap);

%% ---------------- Part 1：恒定功率的可持续时长 ----------------
Hlist = [1 3 6 12 24];
socH  = 0:10:100;
socG  = 0:10:100;
Pmax  = zeros(numel(Hlist), numel(socG), numel(socH));
fprintf('\nPart 1: %d 组 (H, SOC_g, SOC_h)，二分求 P_max ...\n', numel(Pmax));

for iH = 1:numel(Hlist)
    for iG = 1:numel(socG)
        m0 = socG(iG)/100*m_full_t;
        for iHh = 1:numel(socH)
            Q0 = socH(iHh)/100*dp.Q_HTV_cap;
            lo = 0; hi = dp.W_discharge;
            if ~cces_feasible_dyn(dp, m0, Q0, hi, 0, -1, Hlist(iH))
                for it = 1:40
                    mid = (lo+hi)/2;
                    if cces_feasible_dyn(dp, m0, Q0, mid, 0, -1, Hlist(iH)), lo = mid; else, hi = mid; end
                end
                Pmax(iH,iG,iHh) = lo;
            else
                Pmax(iH,iG,iHh) = hi;
            end
        end
    end
end

fid = fopen(fullfile(dataDir,'dynamic_pmax.csv'),'w');
fprintf(fid,'H_h,SOC_heat_pct,SOC_gas_pct,P_max_MW\n');
for iH = 1:numel(Hlist)
    for iG = 1:numel(socG)
        for iHh = 1:numel(socH)
            fprintf(fid,'%.0f,%.0f,%.0f,%.4f\n',Hlist(iH),socH(iHh),socG(iG),Pmax(iH,iG,iHh));
        end
    end
end
fclose(fid);
iG50 = find(socG==50); iH50 = find(socH==50);
fprintf('  P_max(H)·H / W_design（SOC_h=50%%, SOC_g=50%%）= %s\n', ...
    mat2str(squeeze(Pmax(:,iG50,iH50))'.*Hlist/dp.W_discharge, 3));
fprintf('  → dynamic_pmax.csv\n');

%% ---------------- 调度指令（论文算例） ----------------
Heat_Load = [38 35 32 30 29 28 28 29 31 33 36 39 41.5 41 40 38 37 35 40 42 41.5 40 42 40]';
Elec_Load = [28 22 18 16 15 14 16 18 20 22 26 48 48 48 45 30 28 24 32 48 48 48 48 35]';
Wind      = [18 16 14 12 13 12 8 6 5 4 3 2 2 3 4 6 10 12 8 6 5 14 16 18]';
CCHP_heat = min(Heat_Load, 36);
CCHP_elec = CCHP_heat/1.2;
q_req = max(Heat_Load - CCHP_heat, 0);
elec  = Elec_Load - CCHP_elec - Wind;
w_req = max(-elec, 0);
c_req = max( elec, 0);
sumQ = sum(q_req);  sumW = sum(w_req);
fprintf('\n调度指令: ΣQ = %.1f MWh, ΣW_discharge = %.1f MWh\n', sumQ, sumW);

socH2 = 0:5:100;  socG2 = 10:5:90;

%% ---------------- Part 2：LP 可行域 ----------------
fprintf('\nPart 2: LP（凸）...\n');
[HeatC_LP, DisC_LP] = service_map(dp, q_req, w_req, c_req, socH2, socG2, false, 0);
maxDis_LP = max(DisC_LP(:));
fprintf('  最优放电覆盖率 %.1f%%（=%.1f MWh）\n', maxDis_LP*100, maxDis_LP*sumW);
write_map(fullfile(dataDir,'dynamic_state_map.csv'), socH2, socG2, HeatC_LP, DisC_LP, maxDis_LP);

%% ---------------- Part 3：MILP 可行域（最小出力 + 互斥） ----------------
Wmin = 0.2*dp.W_discharge;        % 20% 最小稳定出力
fprintf('\nPart 3: MILP（最小出力 %.1f MW + 充放互斥）...\n', Wmin);
[HeatC_MLP, DisC_MLP] = service_map(dp, q_req, w_req, c_req, socH2, socG2, true, Wmin);
maxDis_MLP = max(DisC_MLP(:));
fprintf('  最优放电覆盖率 %.1f%%（=%.1f MWh）\n', maxDis_MLP*100, maxDis_MLP*sumW);
write_map(fullfile(dataDir,'dynamic_state_map_milp.csv'), socH2, socG2, HeatC_MLP, DisC_MLP, maxDis_MLP);

%% ---------------- 图 ----------------
figure('Color','w','Position',[40,120,1600,480]);

subplot(1,3,1); hold on; grid on;
cmap = lines(numel(Hlist));
for iH = 1:numel(Hlist)
    plot(socH, squeeze(Pmax(iH,iG50,:))', '-o', 'Color', cmap(iH,:), ...
        'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName', sprintf('H = %d h', Hlist(iH)));
end
xlabel('SOC_{heat} [%]'); ylabel('P_{max} [MW]');
title('(a) Sustainable power, SOC_{gas} = 50 %');
legend('Location','northeast'); xlim([0 100]); ylim([0 10.5]);

subplot(1,3,2); hold on; grid on;
imagesc(socG2, socH2, DisC_LP); set(gca,'YDir','normal');
colormap(gca, flipud(gray)); clim([0 0.55]);
contour(socG2, socH2, DisC_LP, [1 1]*0.95*maxDis_LP, 'r-', 'LineWidth', 2);
xlabel('SOC_{gas} [%]'); ylabel('SOC_{heat} [%]');
title('(b) LP: convex, monotone in SOC_{heat}');
cb = colorbar; ylabel(cb,'discharge coverage');

subplot(1,3,3); hold on; grid on;
imagesc(socG2, socH2, DisC_MLP); set(gca,'YDir','normal');
colormap(gca, flipud(gray)); clim([0 0.55]);
contour(socG2, socH2, DisC_MLP, [1 1]*0.95*maxDis_MLP, 'r-', 'LineWidth', 2);
xlabel('SOC_{gas} [%]'); ylabel('SOC_{heat} [%]');
title(sprintf('(c) MILP: min load %.0f %%, non-convex', 100*Wmin/dp.W_discharge));
cb = colorbar; ylabel(cb,'discharge coverage');

sgtitle('Dynamic feasibility: why the static domain is not enough', 'FontSize', 13, 'FontWeight','bold');
exportgraphics(gcf, fullfile(dataDir,'fig_dynamic_feasibility.png'), 'Resolution', 200);
fprintf('\n  → fig_dynamic_feasibility.png\n');

%% ================= 局部函数 =================
function [HeatC, DisC] = service_map(dp, q_req, w_req, c_req, socH2, socG2, useMILP, Wmin)
T = 24;  nBase = 5*T;
Aeq = zeros(2*T, nBase);  beq = zeros(2*T,1);
for t = 1:T
    Aeq(t, t) = 1;
    if t > 1, Aeq(t, t-1) = -1; end
    Aeq(t, 2*T+t) = -dp.gamma1;
    Aeq(t, 3*T+t) =  dp.gamma2;
    Aeq(t, 4*T+t) =  1;

    Aeq(T+t, T+t) = 1;
    if t > 1, Aeq(T+t, T+t-1) = -1; end
    Aeq(T+t, 2*T+t) = -dp.alpha1/1000;
    Aeq(T+t, 3*T+t) =  dp.alpha2/1000;
end

m_lo = dp.SOC_gas_min*dp.m_full/1000;
m_hi = dp.SOC_gas_max*dp.m_full/1000;
lb = [zeros(T,1); m_lo*ones(T,1); zeros(3*T,1)];
ub = [dp.Q_HTV_cap*ones(T,1); m_hi*ones(T,1); c_req; w_req; q_req];
f  = -[zeros(2*T,1); zeros(T,1); ones(T,1)/sum(w_req); ones(T,1)/sum(q_req)];

Aineq = []; bineq = []; intcon = []; opts = optimoptions('linprog','Display','none');

if useMILP
    zIdx = (nBase+1):(nBase+T);        % 放电开
    yIdx = (nBase+T+1):(nBase+2*T);    % 充电开
    Aeq   = [Aeq zeros(2*T, 2*T)];
    lb    = [lb; zeros(2*T,1)];
    ub    = [ub; ones(2*T,1)];
    f     = [f; zeros(2*T,1)];
    Aineq = zeros(5*T, nBase+2*T);  bineq = zeros(5*T,1);
    for t = 1:T
        r = (t-1)*5 + 1;
        Aineq(r,   3*T+t) =  1;  Aineq(r,   zIdx(t)) = -dp.W_discharge;   % W <= 10 z
        Aineq(r+1, 3*T+t) = -1;  Aineq(r+1, zIdx(t)) =  Wmin;             % W >= Wmin z
        Aineq(r+2, 2*T+t) =  1;  Aineq(r+2, yIdx(t)) = -dp.W_charge;      % C <= 10 y
        Aineq(r+3, 2*T+t) = -1;  Aineq(r+3, yIdx(t)) =  Wmin;             % C >= Wmin y
        Aineq(r+4, zIdx(t)) = 1; Aineq(r+4, yIdx(t)) = 1; bineq(r+4) = 1; % 互斥
    end
    intcon = [zIdx yIdx];
    opts = optimoptions('intlinprog','Display','none');
end

HeatC = nan(numel(socH2), numel(socG2));
DisC  = nan(size(HeatC));
for i = 1:numel(socH2)
    for j = 1:numel(socG2)
        b = beq;
        b(1)   = socH2(i)/100*dp.Q_HTV_cap;
        b(T+1) = socG2(j)/100*dp.m_full/1000;
        if useMILP
            [x,~,flag] = intlinprog(f, intcon, Aineq, bineq, Aeq, b, lb, ub, opts);
        else
            [x,~,flag] = linprog(f, Aineq, bineq, Aeq, b, lb, ub, opts);
        end
        if ~isempty(x) && flag > 0
            HeatC(i,j) = sum(x(4*T+1:5*T))/sum(q_req);
            DisC(i,j)  = sum(x(3*T+1:4*T))/sum(w_req);
        end
    end
end
end

function write_map(fname, socH2, socG2, HeatC, DisC, maxDis)
maxHeat = max(HeatC(:), [], 'omitnan');
feas = (HeatC >= 0.99*maxHeat) & (DisC >= 0.95*maxDis);
fid = fopen(fname,'w');
fprintf(fid,'SOC_heat_pct,SOC_gas_pct,heat_coverage,discharge_coverage,feasible\n');
for i = 1:numel(socH2)
    for j = 1:numel(socG2)
        fprintf(fid,'%.0f,%.0f,%.4f,%.4f,%d\n', socH2(i), socG2(j), HeatC(i,j), DisC(i,j), feas(i,j));
    end
end
fclose(fid);
fprintf('  可行（近最优服务）的初始状态占 %.1f%%\n', mean(feas(:))*100);
end
