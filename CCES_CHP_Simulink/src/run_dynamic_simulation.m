% =========================================================================
% run_dynamic_simulation.m — CCES-CHP ODE动态仿真 (基于REFPROP)
% 直接使用 ODE45 求解储罐质量/压力演变和蓄热动态
% =========================================================================

clc; clear; close all;

%% 0. 环境设置
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src')
CCES_parameters;

%% 1. 仿真时间轴定义
dt_out = 60;  % 输出记录间隔 [s]
t_charge_hr    = 6;   % 充电时间 [h]
t_idle_hr      = 2;   % 闲置时间 [h]
t_discharge_hr = 6;   % 放电时间 [h]

t_charge    = t_charge_hr    * 3600;
t_idle      = t_idle_hr      * 3600;
t_discharge = t_discharge_hr * 3600;
t_total     = t_charge + t_idle + t_discharge;

t_span = 0:dt_out:t_total;
n_steps = length(t_span);

%% 2. 状态向量初始化
% x(1): HPT CO2 质量 [kg]
% x(2): HTV 蓄热量 [MJ]
% x(3): LPT CO2 质量 [kg]

% P = m*R*T/V => m = P*V/(R*T)   [Pa, m³, J/(kg·K), K → kg]

% 可用的 CO2 质量差 (Pmin → Pmax 之间 HPT 可容纳的 CO2)
mass_usable = (params.P_HPT_nom - params.P_LPT_nom) * params.V_HPT ...
              / (params.Rg_CO2 * params.T_HPT_store);
max_charge_time = mass_usable / (params.alpha1 * params.W_design);
max_disch_time  = mass_usable / (params.alpha2 * params.W_design);

fprintf('HPT 可用储气容量:  %.0f kg\n', mass_usable);
fprintf('10MW 满功率充电可持续: %.1f min\n', max_charge_time/60);
fprintf('10MW 满功率放电可持续: %.1f min\n\n', max_disch_time/60);

% 初始: 从接近放空状态开始 (Pa)
P_HPT_init = params.P_LPT_nom + 0.2e6;   % 略高于 LPT 压力
P_LPT_init = params.P_LPT_nom + 1.0e6;   % LPT 有足够 CO2
m_HPT_init = P_HPT_init * params.V_HPT / (params.Rg_CO2 * params.T_HPT_store);
m_LPT_init = P_LPT_init * params.V_LPT / (params.Rg_CO2 * params.T_amb);
fprintf('初始 HPT: %.3f MPa (%0.f kg)\n', P_HPT_init/1e6, m_HPT_init);
fprintf('初始 LPT: %.3f MPa (%0.f kg)\n', P_LPT_init/1e6, m_LPT_init);
Q_HTV_init = params.Q_HTV_initial;

x0 = [m_HPT_init; Q_HTV_init; m_LPT_init];

%% 3. ODE 求解
fprintf('==================================================================\n');
fprintf('  CCES-CHP 动态仿真 (ODE45 + REFPROP)\n');
fprintf('  充电: %d h | 闲置: %d h | 放电: %d h\n', t_charge_hr, t_idle_hr, t_discharge_hr);
fprintf('==================================================================\n\n');

options = odeset('RelTol', 1e-5, 'MaxStep', 300);

t_start = tic;
[t_ode, x_ode] = ode45(@(t,x) CCES_dynamics(t, x, params), t_span, x0, options);
elapsed = toc(t_start);
fprintf('ODE 求解完成，耗时 %.1f 秒\n\n', elapsed);

%% 4. 提取结果
m_HPT = x_ode(:,1);
Q_HTV = x_ode(:,2);
m_LPT = x_ode(:,3);

P_HPT = m_HPT * params.Rg_CO2 * params.T_HPT_store ./ params.V_HPT;  % Pa
P_LPT = m_LPT * params.Rg_CO2 * params.T_amb ./ params.V_LPT;

% 转换为 MPa 用于显示
P_HPT_MPa = P_HPT / 1e6;
P_LPT_MPa = P_LPT / 1e6;
P_HPT_nom_MPa = params.P_HPT_nom / 1e6;
P_LPT_nom_MPa = params.P_LPT_nom / 1e6;

% 计算各时刻的功率和热量
n = length(t_ode);
W_comp = zeros(n,1);
Q_IC   = zeros(n,1);
W_turb = zeros(n,1);
Q_HR   = zeros(n,1);
mode_hist = zeros(n,1);

for i = 1:n
    [dx, Wc, Qic, Wt, Qhr, md] = CCES_dynamics(t_ode(i), x_ode(i,:)', params);
    W_comp(i) = Wc;
    Q_IC(i)   = Qic;
    W_turb(i) = Wt;
    Q_HR(i)   = Qhr;
    mode_hist(i) = md;
end

SOC_heat = Q_HTV / params.Q_HTV_capacity * 100;
SOC_gas  = (P_HPT - params.P_LPT_nom) ./ (params.P_HPT_nom - params.P_LPT_nom) * 100;

%% 5. 结果可视化
t_hr = t_ode / 3600;

figure('Name', 'CCES-CHP Dynamic Simulation Results', ...
       'Color', 'w', 'Position', [100, 80, 1400, 900]);

% --- (a) 功率曲线 ---
subplot(3,2,1);
hold on; grid on;
area(t_hr, W_comp, 'FaceColor', [1 0.7 0.7], 'EdgeColor', 'r', 'LineWidth', 1.2);
area(t_hr, -W_turb, 'FaceColor', [0.7 0.7 1], 'EdgeColor', 'b', 'LineWidth', 1.2);
plot(t_hr, W_comp - W_turb, 'k--', 'LineWidth', 1.5);
xlabel('Time (h)'); ylabel('Power (MW)');
legend('Compressor Power', 'Turbine Power', 'Net Power', 'Location', 'best');
title('Power Flow');
xlim([0 t_total/3600]);

% --- (b) HPT 压力 ---
subplot(3,2,2);
hold on; grid on;
plot(t_hr, P_HPT_MPa, 'b-', 'LineWidth', 2);
yline(P_HPT_nom_MPa, 'r--', 'Design P_{max}');
yline(P_LPT_nom_MPa, 'g--', 'P_{min}');
xlabel('Time (h)'); ylabel('Pressure (MPa)');
title('HPT CO_2 Pressure');
legend('P_{HPT}', 'P_{max}', 'P_{min}', 'Location', 'best');
xlim([0 t_total/3600]);

% --- (c) 蓄热量 ---
subplot(3,2,3);
hold on; grid on;
yyaxis left;
plot(t_hr, Q_HTV/3600, 'r-', 'LineWidth', 2);
ylabel('Stored Heat (MWh_{th})');
yyaxis right;
plot(t_hr, SOC_heat, 'b--', 'LineWidth', 1.5);
ylabel('Heat SOC (%)');
xlabel('Time (h)');
title('Thermal Oil Storage (HTV)');
xlim([0 t_total/3600]);

% --- (d) 热量流 ---
subplot(3,2,4);
hold on; grid on;
plot(t_hr, Q_IC, 'r-', 'LineWidth', 1.5);
plot(t_hr, Q_HR, 'b-', 'LineWidth', 1.5);
xlabel('Time (h)'); ylabel('Heat Power (MW_{th})');
legend('Q_{IC} (recovered)', 'Q_{HR} (consumed)', 'Location', 'best');
title('Heat Recovery & Consumption');
xlim([0 t_total/3600]);

% --- (e) 质量变化 ---
subplot(3,2,5);
hold on; grid on;
yyaxis left;
plot(t_hr, m_HPT/1000, 'b-', 'LineWidth', 2);
ylabel('HPT Mass (ton)');
yyaxis right;
plot(t_hr, m_LPT/1000, 'r-', 'LineWidth', 2);
ylabel('LPT Mass (ton)');
xlabel('Time (h)');
title('CO_2 Mass Distribution');
legend('HPT', 'LPT', 'Location', 'best');
xlim([0 t_total/3600]);

% --- (f) 双 SOC ---
subplot(3,2,6);
hold on; grid on;
plot(t_hr, SOC_gas, 'b-', 'LineWidth', 2);
plot(t_hr, SOC_heat, 'r-', 'LineWidth', 2);
xlabel('Time (h)'); ylabel('SOC (%)');
legend('Gas SOC (P)', 'Heat SOC (Q)', 'Location', 'best');
title('Dual State of Charge');
ylim([0 110]); xlim([0 t_total/3600]);

sgtitle('CCES-CHP System Dynamic Simulation', 'FontSize', 16, 'FontWeight', 'bold');
saveas(gcf, '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/dynamic_simulation_results.png');

%% 6. 性能摘要
fprintf('==================================================================\n');
fprintf('                     仿真性能摘要\n');
fprintf('==================================================================\n');

charge_idx  = t_ode <= t_charge;
disch_idx   = t_ode >= (t_charge + t_idle);
idle_idx    = ~charge_idx & ~disch_idx;

E_charge    = trapz(t_ode(charge_idx), W_comp(charge_idx)) / 3600;     % MWh
E_discharge = trapz(t_ode(disch_idx),  W_turb(disch_idx))  / 3600;

fprintf('充电电能:         %.2f MWh\n', E_charge);
fprintf('发电电能:         %.2f MWh\n', E_discharge);
fprintf('往返效率 (RTE):   %.1f %%\n', E_discharge/E_charge*100);
fprintf('HPT 压力范围:     %.3f - %.3f MPa\n', min(P_HPT_MPa), max(P_HPT_MPa));
fprintf('HTV 蓄热范围:     %.1f - %.1f MWh_th\n', min(Q_HTV)/3600, max(Q_HTV)/3600);
fprintf('==================================================================\n');

%% 7. 保存仿真结果
save('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/simulation_results.mat', ...
     't_ode', 'm_HPT', 'Q_HTV', 'm_LPT', 'P_HPT', 'P_LPT', ...
     'W_comp', 'W_turb', 'Q_IC', 'Q_HR', 'SOC_heat', 'SOC_gas', 'mode_hist');
fprintf('结果已保存至 simulation_results.mat\n');

% ======================================================================
%  ODE 系统动力学函数
% ======================================================================
function [dx, W_comp, Q_IC, W_turb, Q_HR, mode] = CCES_dynamics(t, x, p)
    % x(1): m_HPT [kg]
    % x(2): Q_HTV [MJ]
    % x(3): m_LPT [kg]

    % 确定运行模式
    if t <= p.t_charge
        mode = 1;        % 充电
    elseif t <= p.t_charge + p.t_idle
        mode = 0;        % 闲置
    else
        mode = -1;       % 放电
    end

    % 设计点功率
    W_design = p.W_design;  % MW

    % ==== 充电模式 ====
    if mode == 1
        P_HPT_curr = x(1) * p.Rg_CO2 * p.T_HPT_store / p.V_HPT;  % [Pa]

        max_m_dot = (p.P_HPT_nom - P_HPT_curr) * p.V_HPT / (p.Rg_CO2 * p.T_HPT_store);
        W_C_actual = min(p.W_design, max_m_dot / p.alpha1);
        W_C_actual = max(0, W_C_actual);

        m_dot = p.alpha1 * W_C_actual;
        Q_IC_act = p.beta1 * W_C_actual;

        dm_HPT_dt = m_dot;
        dm_LPT_dt = -m_dot;
        dQ_HTV_dt = Q_IC_act;

        W_comp = W_C_actual;
        Q_IC   = Q_IC_act;
        W_turb = 0;
        Q_HR   = 0;

    % ==== 闲置模式 ====
    elseif mode == 0
        dm_HPT_dt = 0;
        dm_LPT_dt = 0;
        dQ_HTV_dt = 0;
        W_comp = 0;
        Q_IC   = 0;
        W_turb = 0;
        Q_HR   = 0;

    % ==== 放电模式 ====
    else
        P_HPT_curr = x(1) * p.Rg_CO2 * p.T_HPT_store / p.V_HPT;  % [Pa]

        max_m_dot = (P_HPT_curr - p.P_LPT_nom) * p.V_HPT / (p.Rg_CO2 * p.T_HPT_store);
        W_T_actual = min(p.W_design, max_m_dot / p.alpha2);
        W_T_actual = max(0, W_T_actual);

        m_dot = p.alpha2 * W_T_actual;
        Q_HR_act = p.beta2 * W_T_actual;

        dm_HPT_dt = -m_dot;
        dm_LPT_dt = m_dot;
        dQ_HTV_dt = -Q_HR_act;

        W_comp = 0;
        Q_IC   = 0;
        W_turb = W_T_actual;
        Q_HR   = Q_HR_act;
    end

    dx = [dm_HPT_dt; dQ_HTV_dt; dm_LPT_dt];
end
