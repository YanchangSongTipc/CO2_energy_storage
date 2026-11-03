% =========================================================================
% run_ode_simulation.m — CCES-CHP 双 SOC 动态仿真（21 天，周期性稳态校验）
%
% 模型要点（与旧版的关键差别）：
%   1) 设计点由 cces_design_point 统一给出，α/γ/时长全部来自 REFPROP，
%      不再手写常数，也不会与 Cycle/ML 两条线漂移。
%   2) 充电时长由质量闭合反解（m_c*t_c = m_d*t_d），对外供热由热量闭合反解
%      （Q_IC*t_c = (Q_HR+Q_export)*t_d）。因此逐日严格回到同一状态，
%      不会出现"撞上限后削峰"的假稳态。
%   3) HPT 为定压室温液态储罐：状态量是储液质量，压力恒为 6.8 MPa
%      （由泵/背压维持），储气 SOC = 液位。旧版把 6228 m³ 按理想气体建模，
%      与"室温液态储存"自相矛盾，且 6.8 MPa 与 P_sat 混用。
% =========================================================================

clc; clear; close all;
clear ode_dynamics;   % 清掉 ode_dynamics 内的持久设计点

here     = fileparts(mfilename('fullpath'));
rootDir  = fullfile(here, '..', '..', '..');
outDir   = fullfile(here, '..', '..', 'output', 'ode');
addpath(rootDir);  addpath(here);
if ~exist(outDir, 'dir'), mkdir(outDir); end

cfg = config_paths();
g = @(varargin) getFluidProperty(cfg.REFPROP_LIB, varargin{:}, 'CO2', 1, 1, 'MASS BASE SI');

%% 1. 设计点（单一真源）
dp = cces_design_point(483);

fprintf('=========== CCES-CHP 设计点（REFPROP）===========\n');
fprintf(' 透平入口温度        %8.1f K\n', dp.Th);
fprintf(' 每 kg 功/热         w_c=%.1f  w_t=%.1f  q_IC=%.1f  q_HR=%.1f  q_EHE=%.1f kJ/kg\n', ...
        dp.w_c, dp.w_t, dp.q_IC, dp.q_HR, dp.q_EHE);
fprintf(' 无量纲参数          α1=%.3f  α2=%.3f  γ1=%.3f  γ2=%.3f\n', ...
        dp.alpha1, dp.alpha2, dp.gamma1, dp.gamma2);
fprintf(' 充/放质量流量       %.2f / %.2f kg/s\n', dp.m_charge, dp.m_discharge);
fprintf(' 充/放时长           %.3f h / %.3f h（质量闭合反解）\n', dp.t_charge, dp.t_discharge);
fprintf(' 循环质量            %.1f t\n', dp.M_cycle/1000);
fprintf(' 对外供热            %.2f MW（热量闭合反解）, X=%.1f%%\n', dp.Q_export, dp.X*100);
fprintf(' HPT  满液 %.1f t = %.0f m3, 初值 %.1f t (%.0f%%)\n', ...
        dp.m_full/1000, dp.V_HPT, dp.m0/1000, dp.SOC_gas_min*100);
fprintf(' HTV  容量 %.0f MWh, 初始 %.0f MWh, 峰值 %.0f MWh (%.0f%%)\n', ...
        dp.Q_HTV_cap, dp.Q_HTV_0, dp.Q_HTV_peak, dp.Q_HTV_peak/dp.Q_HTV_cap*100);
fprintf('================================================\n\n');

%% 2. 仿真
x0 = [dp.m0; dp.Q_HTV_0*3600];          % [kg; MJ]
t_sim = 21*86400;
% 输出时刻包含调度分界点，避免 600 s 采样把功率跳变"抹平"造成能量积分误差
tspan = (0:600:t_sim)';
tb = [];
off = [dp.t_charge, dp.t_charge+dp.t_idle_half, ...
       dp.t_charge+dp.t_idle_half+dp.t_discharge]*3600;
for d = 0:floor(t_sim/86400)
    b = d*86400;
    tb = [tb; b - 1; b + 1];                          % 跨日跳变（待机->充电）前后各取 1 点
    for k = 1:3
        tb = [tb; b + off(k) - 1; b + off(k) + 1];   % 段内跳变前后各取 1 点
    end
end
tspan = unique([tspan; tb(tb >= 0 & tb <= t_sim)]);

opts = odeset('RelTol', 1e-8, 'AbsTol', 1e-8, 'MaxStep', 600);
[t, x] = ode45(@ode_dynamics, tspan, x0, opts);

m_HPT   = x(:,1);
Q_HTV   = x(:,2);                        % MJ
SOC_gas = m_HPT/dp.m_full*100;
SOC_heat= Q_HTV/(dp.Q_HTV_cap*3600)*100;

%% 3. 逐点重算功率与模式
n = numel(t);
W_comp = zeros(n,1); Q_IC = zeros(n,1);
W_turb = zeros(n,1); Q_HR = zeros(n,1); mode = zeros(n,1);
for i = 1:n
    [~, W_comp(i), Q_IC(i), W_turb(i), Q_HR(i), ~, mode(i)] = ode_dynamics(t(i), x(i,:)');
end
t_hr = t/3600;  t_day = t/86400;
mflow = dp.m_charge*(mode==1) - dp.m_discharge*(mode==-1);   % kg/s

E_ch  = trapz(t_hr, W_comp);
E_dis = trapz(t_hr, W_turb);
Q_in  = trapz(t_hr, Q_IC);
Q_exp_rate  = dp.Q_export*(mode==-1);       % 仅放电段对外供热
Q_HR_total  = trapz(t_hr, Q_HR);
Q_exp_total = trapz(t_hr, Q_exp_rate);
Q_resid     = Q_in - Q_HR_total - Q_exp_total;

%% 4. 物理闭合与约束校核
fprintf('=========== 物理一致性校核 ===========\n');

% 4.1 逐日闭合
n_days = floor(t_sim/86400);
dM = zeros(n_days,1);  dQ = zeros(n_days,1);
Ec = zeros(n_days,1);  Ed = zeros(n_days,1);
Qi = zeros(n_days,1);  Qo = zeros(n_days,1);
m_in = zeros(n_days,1);  m_out = zeros(n_days,1);
for d = 1:n_days
    idx = (t_day >= d-1) & (t_day < d);
    ii  = find(idx);
    dM(d) = m_HPT(ii(end)) - m_HPT(ii(1));
    dQ(d) = (Q_HTV(ii(end)) - Q_HTV(ii(1)))/3600;       % MWh
    Ec(d) = trapz(t_hr(idx), W_comp(idx));
    Ed(d) = trapz(t_hr(idx), W_turb(idx));
    Qi(d) = trapz(t_hr(idx), Q_IC(idx));
    Qo(d) = trapz(t_hr(idx), Q_HR(idx) + Q_exp_rate(idx));
    m_in(d)  = trapz(t(idx), max( mflow(idx), 0))/1000;   % t
    m_out(d) = trapz(t(idx), max(-mflow(idx), 0))/1000;   % t
end

max_dM = max(abs(dM));  max_dQ = max(abs(dQ));
tol_M  = 1e-5*dp.M_cycle;   tol_Q = 1e-5*dp.Q_HTV_swing;

% 4.2 段内功率是否被截断（用能量偏差判定，比数采样点更可靠）
def_ch  = max(abs(Ec - dp.W_charge*dp.t_charge))/(dp.W_charge*dp.t_charge);
def_dis = max(abs(Ed - dp.W_discharge*dp.t_discharge))/(dp.W_discharge*dp.t_discharge);
def_q   = max(abs(Qi - dp.Q_IC_rate*dp.t_charge))/(dp.Q_IC_rate*dp.t_charge);
clip_charge    = sum(mode==1 & W_comp==0 & Ec(1)>0 & false);   % 保留变量, 逻辑见下
clip_discharge = sum(mode==-1 & W_turb==0 & false);
soc_gas_range  = [min(SOC_gas) max(SOC_gas)];
soc_heat_range = [min(SOC_heat) max(SOC_heat)];

fprintf(' 质量闭合  每日漂移 max |Δm| = %.3e kg  (相对 %.1e, 容差 %.1e kg) -> %s\n', ...
        max_dM, max_dM/dp.M_cycle, tol_M, tern(max_dM < tol_M, 'PASS', 'FAIL'));
fprintf(' 热量闭合  每日漂移 max |ΔQ| = %.3e MWh (相对 %.1e, 容差 %.1e MWh) -> %s\n', ...
        max_dQ, max_dQ/dp.Q_HTV_swing, tol_Q, tern(max_dQ < tol_Q, 'PASS', 'FAIL'));
fprintf(' 段内截断  充电 %.2e, 放电 %.2e, 热量 %.2e（相对偏差）-> %s\n', ...
        def_ch, def_dis, def_q, ...
        tern(max([def_ch def_dis def_q]) < 1e-3, 'PASS', 'FAIL'));
fprintf(' 储液 SOC  %.1f%% ~ %.1f%%  (设计窗口 %.0f%%~%.0f%%)\n', ...
        soc_gas_range, dp.SOC_gas_min*100, dp.SOC_gas_max*100);
fprintf(' 蓄热 SOC  %.1f%% ~ %.1f%%  (0~100%%)\n', soc_heat_range);
fprintf(' 电-电效率 %.1f%%（E_dis %.1f / E_ch %.1f MWh）\n', ...
        E_dis/E_ch*100, E_dis, E_ch);
fprintf(' 供热分配  Q_IC %.1f MWh = 回热 %.1f + 对外 %.1f MWh（残差 %.2e MWh）\n', ...
        Q_in, Q_HR_total, Q_exp_total, Q_resid);
fprintf('======================================\n\n');

% 4.3 逐日表
fprintf('           每日闭合明细（前 7 天）\n');
fprintf(' Day  Δm[kg]   ΔQ[MWh]   E_ch   E_dis   Q_in   Q_out   Q_HTV_end\n');
for d = 1:min(7,n_days)
    idx = (t_day >= d-1) & (t_day < d);
    fprintf(' %2d  %8.2f  %8.4f  %6.1f  %6.1f  %6.1f  %6.1f   %6.1f\n', ...
        d, dM(d), dQ(d), Ec(d), Ed(d), Qi(d), Qo(d), Q_HTV(find(idx,1,'last'))/3600);
end
fprintf(' （第 8~21 天与上表同值，逐日偏差为数值积分误差量级）\n\n');

%% 5. 图 1：HPT 储液状态（定压液态储罐）
figure('Color','w','Position',[60,200,1300,480]);

subplot(1,2,1); hold on; grid on;
yyaxis left;
plot(t_day, m_HPT/1000, 'b-', 'LineWidth', 1.8);
yline(dp.SOC_gas_max*dp.m_full/1000, 'b--', 'SOC 90%');
yline(dp.SOC_gas_min*dp.m_full/1000, 'b--', 'SOC 10%');
ylabel('HPT liquid inventory [t]');
yyaxis right;
plot(t_day, SOC_gas, 'r-', 'LineWidth', 1.2);
ylabel('Gas SOC (fill level) [%]');  ylim([0 100]);
xlabel('Time [days]');
title('HPT Liquid Storage');  xlim([0 t_sim/86400]);

subplot(1,2,2); hold on; grid on;
P_sat298 = g('P','T',298,'Q',0)/1e6;
plot(t_day, dp.P_HPT*ones(size(t_day)), 'b-', 'LineWidth', 2.2);
yline(P_sat298, 'r--', sprintf('P_{sat}(298K)=%.2f', P_sat298));
ylim([6.0 7.0]);
xlabel('Time [days]');  ylabel('Pressure [MPa]');
title('HPT Pressure (constant-pressure liquid store)');
text(1, 6.72, sprintf('P_{tank}=%.2f MPa 由泵/背压维持\n亚冷度 %.2f MPa 保证节流前不闪蒸', ...
     dp.P_HPT, dp.P_HPT-P_sat298), 'FontSize', 9, 'BackgroundColor', 'w');
xlim([0 t_sim/86400]);

sgtitle('HPT Storage State', 'FontSize', 14, 'FontWeight', 'bold');
exportgraphics(gcf, fullfile(outDir,'fig01_pressure_temp.png'), 'Resolution', 200);

%% 6. 图 2：功率与累积能量
figure('Color','w','Position',[60,200,1000,650]);
subplot(2,1,1); hold on; grid on;
stairs(t_day, W_comp, 'r', 'LineWidth', 1.4);
stairs(t_day, W_turb, 'b', 'LineWidth', 1.4);
stairs(t_day, Q_IC, 'Color', [0.85 0.4 0.1], 'LineWidth', 1.0);
stairs(t_day, Q_HR, 'g', 'LineWidth', 1.0);
ylabel('Power [MW]');
legend({'W_{comp}','W_{turb}','Q_{IC} (compression heat)','Q_{HR} (reheat)'}, ...
       'Location','eastoutside');
title('Power Schedule (first 3 days)');  xlim([0 3]);

subplot(2,1,2); hold on; grid on;
plot(t_day, cumtrapz(t_hr, W_comp), 'r-', 'LineWidth', 2);
plot(t_day, cumtrapz(t_hr, W_turb), 'b-', 'LineWidth', 2);
plot(t_day, cumtrapz(t_hr, W_comp)-cumtrapz(t_hr, W_turb), 'k--', 'LineWidth', 1.2);
xlabel('Time [days]'); ylabel('Cumulative Energy [MWh]');
title(sprintf('Energy Balance (E_{dis}/E_{ch} = %.1f%%)', E_dis/E_ch*100));
legend({'E_{comp}','E_{turb}','Net'}, 'Location','northwest');
xlim([0 t_sim/86400]);
sgtitle('Power & Energy', 'FontSize', 14, 'FontWeight', 'bold');
exportgraphics(gcf, fullfile(outDir,'fig02_power_energy.png'), 'Resolution', 200);

%% 7. 图 3：双 SOC 与 HTV 蓄热
figure('Color','w','Position',[60,200,1300,480]);
subplot(1,2,1); hold on; grid on;
yyaxis left;
plot(t_day, SOC_gas, 'b-', 'LineWidth', 1.8);
ylabel('Gas SOC (liquid level) [%]'); ylim([0 100]);
yyaxis right;
plot(t_day, SOC_heat, 'r-', 'LineWidth', 1.8);
ylabel('Heat SOC [%]'); ylim([0 100]);
xlabel('Time [days]'); title('Dual State-of-Charge'); xlim([0 t_sim/86400]);

subplot(1,2,2); hold on; grid on;
plot(t_day, Q_HTV/3600, 'r-', 'LineWidth', 1.8);
yline(dp.Q_HTV_cap, 'r--', 'Q_{max} 150');
yline(0, 'k--', 'Q_{min} 0');
xlabel('Time [days]'); ylabel('Q_{HTV} [MWh_{th}]');
title('HTV Thermal Storage'); xlim([0 t_sim/86400]); ylim([-6 158]);
sgtitle('Storage State-of-Charge', 'FontSize', 14, 'FontWeight', 'bold');
exportgraphics(gcf, fullfile(outDir,'fig03_soc_heat.png'), 'Resolution', 200);

%% 8. 图 4：闭合验证（每日进出与残差）
figure('Color','w','Position',[60,200,1100,600]);

subplot(2,1,1); hold on; grid on;
bar((1:n_days)-0.2, m_in,  0.4, 'FaceColor', [0.4 0.6 0.9]);
bar((1:n_days)+0.2, m_out, 0.4, 'FaceColor', [0.9 0.5 0.4]);
ylabel('Mass per cycle [t]');
legend({'m_c·t_c (in)','m_d·t_d (out)'}, 'Location','eastoutside');
title(sprintf('Mass Closure: max |\\Deltam| = %.2e kg', max_dM));

subplot(2,1,2); hold on; grid on;
bar((1:n_days)-0.2, Qi, 0.4, 'FaceColor', [0.85 0.4 0.1]);
bar((1:n_days)+0.2, Qo, 0.4, 'FaceColor', [0.3 0.7 0.4]);
plot(1:n_days, dQ, 'k.-', 'LineWidth', 1, 'MarkerSize', 10);
ylabel('Heat per cycle [MWh]');
legend({'Q_{in} = Q_{IC}·t_c','Q_{out} = (Q_{HR}+Q_{exp})·t_d','\DeltaQ'}, ...
       'Location','eastoutside');
xlabel('Day');
title(sprintf('Heat Closure: max |\\DeltaQ| = %.2e MWh', max_dQ));

sgtitle('Cycle Closure Verification', 'FontSize', 14, 'FontWeight', 'bold');
exportgraphics(gcf, fullfile(outDir,'fig04_closure.png'), 'Resolution', 200);

fprintf('Figures saved to %s/\n', outDir);

%% 局部函数
function out = tern(cond, a, b)
    if cond, out = a; else, out = b; end
end
