% =========================================================================
% run_tank_thermal.m — HPT储罐蒸发降温动态仿真
% 耦合: 液相CO2排出 → 闪蒸补位 → 潜热来自液相 → 温度/压力下降
% 基于 REFPROP 饱和物性 + 能量平衡 + 壁面传热
% =========================================================================

clc; clear; close all;

%% 0. 环境与参数
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src')
CCES_parameters;

libLoc = '/opt/refprop/';
Fluid  = 'CO2';

V_HPT = 500;         % m³ (实际罐容)
T_amb = 298;         % K (环境温度)
h_wall = 1.0;        % W/(m²·K) 壁面传热系数 (保温罐体)
A_wall = 304;        % m² 罐体表面积 (球形罐500m³)
m_dot_discharge = 40.3;  % kg/s 放电质量流量

%% 1. 初始条件 — HPT充满饱和液体CO2
T0 = 298;
Psat0 = getFluidProperty(libLoc, 'P', 'T', T0, 'Q', 0, Fluid, 1, 1, 'MASS BASE SI');
rho_f0 = getFluidProperty(libLoc, 'D', 'T', T0, 'Q', 0, Fluid, 1, 1, 'MASS BASE SI');
rho_g0 = getFluidProperty(libLoc, 'D', 'T', T0, 'Q', 1, Fluid, 1, 1, 'MASS BASE SI');
h_f0   = getFluidProperty(libLoc, 'H', 'T', T0, 'Q', 0, Fluid, 1, 1, 'MASS BASE SI');
h_g0   = getFluidProperty(libLoc, 'H', 'T', T0, 'Q', 1, Fluid, 1, 1, 'MASS BASE SI');

% 初始20%液态 + 80%气相 (加速展示蒸发效应, 对应低SOC工况)
v_f0 = 1 / rho_f0;  v_g0 = 1 / rho_g0;
V_liq0 = 0.20 * V_HPT;  V_vap0 = 0.80 * V_HPT;
m_liq0 = V_liq0 / v_f0;
m_vap0 = V_vap0 / v_g0;
m_total0 = m_liq0 + m_vap0;
x0 = m_vap0 / m_total0;
u_f0 = h_f0 - Psat0 / rho_f0;
u_g0 = h_g0 - Psat0 / rho_g0;
U0 = m_liq0 * u_f0 + m_vap0 * u_g0;

fprintf('==============================================================\n');
fprintf('  HPT储罐蒸发降温动态仿真 (REFPROP耦合)\n');
fprintf('  初始温度: %.1f K | 压力: %.3f MPa\n', T0, Psat0/1e6);
fprintf('  液相: %.0f kg | 气相: %.0f kg | 干度: %.4f\n', m_liq0, m_vap0, x0);
fprintf('  潜热: %.0f kJ/kg\n', (h_g0-h_f0)/1000);
fprintf('==============================================================\n\n');

%% 2. 时间推进仿真
dt   = 10;      % 时间步长 [s]
t_end = 1800;   % 仿真30分钟
t_vec = 0:dt:t_end;
n = length(t_vec);

% 状态变量
m_total = zeros(n,1);   U_total = zeros(n,1);
T_tank  = zeros(n,1);   P_tank  = zeros(n,1);
x_qual  = zeros(n,1);   m_liq   = zeros(n,1);  m_vap = zeros(n,1);
h_outflow = zeros(n,1); Q_env   = zeros(n,1);

m_total(1) = m_total0;  U_total(1) = U0;
T_tank(1)  = T0;        P_tank(1)  = Psat0;
x_qual(1)  = x0;        m_liq(1)   = m_liq0;  m_vap(1) = m_vap0;

% 温度求解范围 (扩展到低温: CO2三相点~216.6K)
T_range = [220:0.5:260, 260.5:0.1:304];
nT = length(T_range);

% 预计算饱和曲线
Psat_tab = zeros(nT,1);  rhof_tab = zeros(nT,1);  rhog_tab = zeros(nT,1);
hf_tab   = zeros(nT,1);  hg_tab   = zeros(nT,1);

fprintf('预计算CO2饱和曲线 (%d点)... ', nT);
for i = 1:nT
    Psat_tab(i)  = getFluidProperty(libLoc, 'P', 'T', T_range(i), 'Q', 0, Fluid, 1, 1, 'MASS BASE SI');
    rhof_tab(i)  = getFluidProperty(libLoc, 'D', 'T', T_range(i), 'Q', 0, Fluid, 1, 1, 'MASS BASE SI');
    rhog_tab(i)  = getFluidProperty(libLoc, 'D', 'T', T_range(i), 'Q', 1, Fluid, 1, 1, 'MASS BASE SI');
    hf_tab(i)    = getFluidProperty(libLoc, 'H', 'T', T_range(i), 'Q', 0, Fluid, 1, 1, 'MASS BASE SI');
    hg_tab(i)    = getFluidProperty(libLoc, 'H', 'T', T_range(i), 'Q', 1, Fluid, 1, 1, 'MASS BASE SI');
end
fprintf('完成\n');

%% 3. 主时间循环
fprintf('\n 时间  | 温度  | 压力  | 干度  | 液质量 | 蒸质量 | Q_env\n');
fprintf('  [s]  |  [K]  | [MPa] |   x   |  [kg]  |  [kg]  | [kW]\n');
fprintf('-------+-------+-------+-------+--------+--------+-------\n');

for k = 1:n-1
    if m_total(k) < 100  % 罐体已排空
        T_tank(k+1:end) = T_tank(k);
        P_tank(k+1:end) = P_tank(k);
        break;
    end

    Tk = T_tank(k);
    mk = m_total(k);
    Uk = U_total(k);

    % 获取当前T下的饱和物性 (线性插值)
    if Tk < T_range(1) || Tk > T_range(end)
        warning('T=%.1f 超出预计算范围, 终止', Tk);  break;
    end
    rhof = interp1(T_range, rhof_tab, Tk);
    rhog = interp1(T_range, rhog_tab, Tk);
    hf   = interp1(T_range, hf_tab,   Tk);
    hg   = interp1(T_range, hg_tab,   Tk);
    Psat = interp1(T_range, Psat_tab, Tk);

    % 当前比容和质量分布
    v_tot = V_HPT / mk;  % m³/kg
    vf = 1 / rhof;
    vg = 1 / rhog;

    % 干度 (由比容约束)
    if v_tot < vf
        xk = 0;  % 过冷液体
    elseif v_tot > vg
        xk = 1;  % 过热蒸气
    else
        xk = (v_tot - vf) / (vg - vf);
    end
    xk = max(0, min(1, xk));

    % 液相/气相质量
    uf = hf - Psat / rhof;
    ug = hg - Psat / rhog;

    % ==== 质量流出 (液相优先) ====
    m_liq_k = (1 - xk) * mk;
    m_vap_k = xk * mk;

    if m_liq_k > m_dot_discharge * dt
        dm_out = m_dot_discharge * dt;
        dm_liq_out = dm_out;
        dm_vap_out = 0;
    else
        dm_liq_out = m_liq_k;
        dm_vap_out = min(m_vap_k, m_dot_discharge * dt - dm_liq_out);
        dm_out = dm_liq_out + dm_vap_out;
    end

    % 流出焓 (液相取出)
    h_out = hf;

    % ==== 壁面传热 (环境→罐体) ====
    Q_dot = h_wall * A_wall * (T_amb - Tk);  % W

    % ==== 能量平衡 ====
    dU = -dm_out * h_out + Q_dot * dt;
    U_new = Uk + dU;
    m_new = mk - dm_out;

    % ==== 反解新温度 ====
    % u_new = U_new / m_new 应匹配饱和模型中的u(T, x(T,m))
    u_target = U_new / m_new;
    v_new = V_HPT / m_new;

    % 在T_range中搜索匹配温度 (最小化 |u_model(T) - u_target|)
    T_err_best = inf;
    T_new = Tk;
    for j = 1:nT
        T_try = T_range(j);
        v_f_j = 1 / rhof_tab(j);  v_g_j = 1 / rhog_tab(j);

        if v_new <= v_f_j
            x_try = 0;
        elseif v_new >= v_g_j
            x_try = 1;
        else
            x_try = (v_new - v_f_j) / (v_g_j - v_f_j);
        end

        u_f_j = hf_tab(j) - Psat_tab(j) / rhof_tab(j);
        u_g_j = hg_tab(j) - Psat_tab(j) / rhog_tab(j);
        u_try = u_f_j + x_try * (u_g_j - u_f_j);

        err = abs(u_try - u_target);
        if err < T_err_best
            T_err_best = err;
            T_new = T_try;
        end
    end

    T_tank(k+1) = T_new;
    m_total(k+1) = m_new;
    % 重算U以保持一致性
    Tk2 = T_tank(k+1);
    rhof2 = interp1(T_range, rhof_tab, Tk2);
    rhog2 = interp1(T_range, rhog_tab, Tk2);
    hf2   = interp1(T_range, hf_tab,   Tk2);
    hg2   = interp1(T_range, hg_tab,   Tk2);
    Psat2 = interp1(T_range, Psat_tab, Tk2);
    uf2 = hf2 - Psat2 / rhof2;
    ug2 = hg2 - Psat2 / rhog2;
    v2  = V_HPT / m_new;
    vf2 = 1/rhof2;  vg2 = 1/rhog2;
    if v2 < vf2; x2=0; elseif v2>vg2; x2=1; else; x2=(v2-vf2)/(vg2-vf2); end
    U_total(k+1) = m_new * (uf2 + x2 * (ug2 - uf2));

    P_tank(k+1)  = Psat2;
    x_qual(k+1)  = x2;
    m_liq(k+1)   = (1-x2) * m_new;
    m_vap(k+1)   = x2 * m_new;
    h_outflow(k+1) = h_out;
    Q_env(k+1)   = Q_dot / 1000;

    if mod(k, 60) == 0
        fprintf('%6.0f | %5.1f | %5.3f | %5.4f | %6.0f | %6.0f | %5.1f\n', ...
            t_vec(k), T_tank(k), P_tank(k)/1e6, x_qual(k), m_liq(k), m_vap(k), Q_dot/1000);
    end
end
fprintf('-------+-------+-------+-------+--------+--------+-------\n\n');

%% 4. 性能汇总
dT_total = T_tank(1) - T_tank(end);
dP_total = (P_tank(1) - P_tank(end)) / 1e6;
m_discharged = m_total0 - m_total(end);
E_cooling = U_total(1) - U_total(end);
fprintf('=== 放电 %.0f 分钟后 ===\n', t_end/60);
fprintf('温度下降:    %.1f K (%.1f → %.1f K)\n', dT_total, T0, T_tank(end));
fprintf('压力下降:    %.3f MPa (%.3f → %.3f MPa)\n', dP_total, Psat0/1e6, P_tank(end)/1e6);
fprintf('CO2排出:     %.0f kg\n', m_discharged);
fprintf('内能减少:    %.1f MJ\n', E_cooling/1e6);
fprintf('=====================================\n\n');

%% 5. 可视化 — 4面板
figure('Name', 'HPT Tank Evaporative Cooling Dynamics', ...
       'Color', 'w', 'Position', [100, 60, 1400, 900]);

t_min = t_vec / 60;

% (a) 温度演变
subplot(2,2,1);
hold on; grid on;
plot(t_min, T_tank, 'r-', 'LineWidth', 2.5);
yline(T_amb, 'k--', 'T_{amb}', 'LineWidth', 1);
xlabel('Time (min)'); ylabel('Temperature (K)');
title('(a) HPT Tank Temperature');
legend('T_{HPT}', 'T_{amb}', 'Location', 'best');

% (b) 压力演变
subplot(2,2,2);
hold on; grid on;
yyaxis left;
plot(t_min, P_tank/1e6, 'b-', 'LineWidth', 2.5);
ylabel('Pressure (MPa)');
yyaxis right;
plot(t_min, x_qual*100, 'g-', 'LineWidth', 1.5);
ylabel('Vapor Quality (%)');
xlabel('Time (min)');
title('(b) Saturation Pressure & Quality');
legend('P_{sat}', 'Quality x', 'Location', 'best');

% (c) 质量分布
subplot(2,2,3);
hold on; grid on;
area(t_min, m_liq/1000, 'FaceColor', [0.3 0.5 0.9], 'EdgeColor', 'b', 'LineWidth', 1);
area(t_min, m_vap/1000, 'FaceColor', [0.9 0.5 0.3], 'EdgeColor', 'r', 'LineWidth', 1);
xlabel('Time (min)'); ylabel('Mass (ton)');
title('(c) Liquid/Vapor Mass Distribution');
legend('Liquid', 'Vapor', 'Location', 'best');

% (d) 环境传热与潜热
subplot(2,2,4);
hold on; grid on;
plot(t_min, Q_env, 'r-', 'LineWidth', 2);
% 潜热消耗 ≈ m_dot * L(T) / 1000
L_kW = m_dot_discharge * (hg - hf) / 1000 * ones(size(t_min));
L_kW_valid = interp1(T_range, hg_tab-hf_tab, T_tank) / 1000 * m_dot_discharge;
plot(t_min, L_kW_valid, 'b-', 'LineWidth', 2);
xlabel('Time (min)'); ylabel('Heat Rate (kW)');
title('(d) Heat Transfer: Ambient vs Latent');
legend('Q_{env} (gain)', 'Q_{latent} (evap loss)', 'Location', 'best');

sgtitle('HPT CO_2 Tank — Evaporative Cooling During Discharge', ...
       'FontSize', 15, 'FontWeight', 'bold');

saveas(gcf, '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/tank_thermal_results.png');

%% 6. 导出数据
save('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/tank_thermal_data.mat', ...
     't_vec', 'T_tank', 'P_tank', 'x_qual', 'm_total', 'm_liq', 'm_vap', ...
     'U_total', 'Q_env', 'h_outflow', 'dT_total', 'dP_total');
fprintf('数据已导出至 tank_thermal_data.mat\n');
