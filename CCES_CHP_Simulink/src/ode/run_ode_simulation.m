% =========================================================================
% run_ode_simulation.m — CCES-CHP ODE动态仿真
% =========================================================================

clc; clear; close all;
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src')
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src/ode')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')

%% 参数
V_HPT = 6228;  Rg = 188.9;  T_amb = 298;
P_min = 0.102e6;  P_max = 6.80e6;
m_min = P_min * V_HPT / (Rg * T_amb);
m_max = P_max * V_HPT / (Rg * T_amb);
Q_cap  = 150 * 3600;
Q_init =  75 * 3600;

%% 初始状态
m_HPT_0 = 0.5 * (m_min + m_max);
T_tank_0 = 298;
x0 = [m_HPT_0; Q_init; T_tank_0];

%% 仿真
dt = 60;  t_sim = 1 * 86400;  tspan = 0:dt:t_sim;
fprintf('CCES-CHP ODE仿真 (1天, REFPROP+动态T): 充电7.5h, 放电3h\n');

opts = odeset('RelTol', 1e-4, 'MaxStep', 300);
[t, x] = ode45(@ode_dynamics, tspan, x0, opts);

%% 后处理
m_HPT = x(:,1);  Q_HTV = x(:,2);  T_tank = x(:,3);
P_HPT = m_HPT .* Rg .* T_tank / V_HPT / 1e6;

n = length(t);
W_comp = zeros(n,1);  W_turb = zeros(n,1);
Q_IC   = zeros(n,1);  Q_HR   = zeros(n,1);
T_heat = zeros(n,1);  mode   = zeros(n,1);

for i = 1:n
    [~, Wc, Qic, Wt, Qhr, Th, md] = ode_dynamics(t(i), x(i,:)');
    W_comp(i)=Wc; Q_IC(i)=Qic; W_turb(i)=Wt; Q_HR(i)=Qhr;
    T_heat(i)=Th; mode(i)=md;
end

t_day = t / 86400;
t_hr  = t / 3600;
E_ch = trapz(t_hr, W_comp);
E_dis = trapz(t_hr, W_turb);
SOC_gas = (m_HPT - m_min) / (m_max - m_min) * 100;
SOC_heat = Q_HTV / Q_cap * 100;

fprintf('========================================\n');
fprintf('E_charge:    %.1f MWh\n', E_ch);
fprintf('E_discharge: %.1f MWh\n', E_dis);
fprintf('RTE:         %.1f %%\n', E_dis/E_ch*100);
fprintf('P_HPT:  %.2f - %.2f MPa\n', min(P_HPT), max(P_HPT));
fprintf('T_tank: %.1f - %.1f K\n', min(T_tank), max(T_tank));
fprintf('Q_HTV:  %.0f - %.0f MWh_th\n', min(Q_HTV)/3600, max(Q_HTV)/3600);
fprintf('SOC_gas:  %.0f - %.0f %%\n', min(SOC_gas), max(SOC_gas));
fprintf('SOC_heat: %.0f - %.0f %%\n', min(SOC_heat), max(SOC_heat));
fprintf('========================================\n');

%% 可视化
figure('Name','CCES-CHP ODE Simulation','Color','w','Position',[40,40,1450,750]);

% (a) HPT 压力 + HTV 蓄热
subplot(2,2,1); hold on; grid on;
yyaxis left;
plot(t_day, P_HPT, 'b-', 'LineWidth', 1.5);
yline(P_max/1e6, 'b--'); yline(P_min/1e6, 'b--');
ylabel('P_{HPT} (MPa)');
yyaxis right;
plot(t_day, Q_HTV/3600, 'r-', 'LineWidth', 1.5);
ylabel('Q_{HTV} (MWh_{th})');
xlabel('Time (days)'); title('HPT Pressure & HTV Heat');
xlim([0 t_sim/86400]);

% (b) 功率
subplot(2,2,2); hold on; grid on;
stairs(t_day, W_comp, 'r', 'LineWidth', 1);
stairs(t_day, W_turb, 'b', 'LineWidth', 1);
xlabel('Time (days)'); ylabel('Power (MW)');
title('Power');
legend('W_{comp}', 'W_{turb}', 'Location', 'best');
xlim([0 t_sim/86400]);

% (c) Dual SOC
subplot(2,2,3); hold on; grid on;
yyaxis left;
h1 = plot(t_day, SOC_gas, 'b-', 'LineWidth', 1.5);
ylabel('Gas SOC (%)'); ylim([-5 105]);
yyaxis right;
h2 = plot(t_day, SOC_heat, 'r-', 'LineWidth', 1.5);
ylabel('Heat SOC (%)'); ylim([-5 105]);
xlabel('Time (days)'); title('Dual SOC');
legend([h1 h2], {'Gas SOC', 'Heat SOC'}, 'Location', 'best');
xlim([0 t_sim/86400]);

% (d) 累积能量
subplot(2,2,4); hold on; grid on;
cum_Wc = cumtrapz(t_hr, W_comp);
cum_Wt = cumtrapz(t_hr, W_turb);
plot(t_day, cum_Wc, 'r-', 'LineWidth', 2);
plot(t_day, cum_Wt, 'b-', 'LineWidth', 2);
xlabel('Time (days)'); ylabel('Cumulative Energy (MWh)');
title(sprintf('Energy: RTE=%.1f%%', E_dis/E_ch*100));
legend('E_{comp}', 'E_{turb}', 'Location', 'northwest');
xlim([0 t_sim/86400]);

sgtitle(sprintf('CCES-CHP %.0f-Day Simulation (ODE)', t_sim/86400), 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/ode/ode_simulation.png');
fprintf('Chart saved.\n');
