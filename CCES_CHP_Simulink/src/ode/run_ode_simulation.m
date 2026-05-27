% =========================================================================
% run_ode_simulation.m — CCES-CHP ODE动态仿真
% =========================================================================

clc; clear; close all;
rootDir = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(rootDir);
addpath(fullfile(rootDir, 'ode'));
energyRoot = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(energyRoot));
cfg = config_paths();

%% 参数 (过冷液态 HPT)
V_HPT = 6228;  T_amb = 298;
rho_liq = getFluidProperty(cfg.REFPROP_LIB, 'D', 'T', T_amb, 'P', 6.80e6, ...
    'CO2', 1, 1, 'MASS BASE SI');  % 过冷液密度 ~713 kg/m3
m_full = rho_liq * V_HPT;    % 满液质量 ~4,439 t
m_HPT_0 = 0.5 * m_full;      % 初始50%充装
T_amb = 298;  T_max = 573;
T_HTV_0 = 298 + 0.5 * (T_max - T_amb);  % 50% SOC → 435.5 K
Q_init_MJ = 150*3600 / (T_max-T_amb) * (T_HTV_0 - T_amb);  % 75 MWh

fprintf('HTV导热油: T_init=%.0f K (%.0f MWh)\n', T_HTV_0, Q_init_MJ/3600);

%% 初始状态
T_tank_0 = 298;
x0 = [m_HPT_0; T_HTV_0; T_tank_0];

%% 仿真
dt = 180;  t_sim = 21 * 86400;  tspan = 0:dt:t_sim;
fprintf('CCES-CHP ODE仿真 (21天, 导热油HTV): 充电7.5h 放电5h\n');

opts = odeset('RelTol', 2e-4, 'MaxStep', 900);
[t, x] = ode45(@ode_dynamics, tspan, x0, opts);

%% 后处理
m_HPT = x(:,1);  T_HTV = x(:,2);  T_tank = x(:,3);
% HPT压力: 有液时6.80 MPa, 排空时降压
mcp_oil = 150*3600 / (573-298);
Q_HTV = mcp_oil * max(0, T_HTV - 298);
Q_cap = 150 * 3600;
P_HPT = 6.80 * ones(size(m_HPT));
P_HPT(m_HPT < m_full * 0.05) = m_HPT(m_HPT < m_full * 0.05) .* 188.9 .* T_tank(m_HPT < m_full * 0.05) / V_HPT / 1e6;

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
SOC_gas = m_HPT / m_full * 100;  % 充装率%
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
fprintf('----------------------------------------\n');
fprintf('          每日循环能量 (MWh)\n');
fprintf(' Day   Charge   Disch     RTE   Q_start  Q_end\n');
n_days = floor(t_sim/86400);
for d = 1:n_days
    idx = t_day >= (d-1) & t_day < d;
    if any(idx)
        Ec_d = trapz(t_hr(idx), W_comp(idx));
        Ed_d = trapz(t_hr(idx), W_turb(idx));
        ii = find(idx);
        fprintf(' %2d    %6.1f  %6.1f   %5.1f%%   %6.0f  %6.0f\n', ...
            d, Ec_d, Ed_d, Ed_d/(Ec_d+eps)*100, Q_HTV(ii(1))/3600, Q_HTV(ii(end))/3600);
    end
end
fprintf('========================================\n');

outDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'output', 'ode');
cum_Wc = cumtrapz(t_hr, W_comp);
cum_Wt = cumtrapz(t_hr, W_turb);

%% Fig 1: HPT 压力 + 温度 (左右双面板)
figure('Color','w','Position',[60,200,1300,480]);
subplot(1,2,1); hold on; grid on;
plot(t_day, P_HPT, 'b-', 'LineWidth', 1.8);
yline(6.80, 'r--', 'P_{design} 6.80');
xlabel('Time (days)'); ylabel('Pressure (MPa)');
title('HPT CO_2 Pressure'); xlim([0 t_sim/86400]);

subplot(1,2,2); hold on; grid on;
plot(t_day, T_tank, 'r-', 'LineWidth', 1.8);
yline(298, 'k--', 'T_{amb} 298K');
xlabel('Time (days)'); ylabel('Temperature (K)');
title('HPT Tank Temperature'); xlim([0 t_sim/86400]);

sgtitle('HPT Storage State', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(outDir, 'fig01_pressure_temp.png'));

%% Fig 2: 功率 + 累积能量 (上下布局)
figure('Color','w','Position',[60,200,1000,650]);
subplot(2,1,1); hold on; grid on;
stairs(t_day, W_comp, 'r', 'LineWidth', 1.5);
stairs(t_day, W_turb, 'b', 'LineWidth', 1.5);
xlabel('Time (days)'); ylabel('Power (MW)');
title('Compressor & Turbine Power');
legend('W_{comp} (charge)', 'W_{turb} (discharge)', 'Location', 'best');
xlim([0 t_sim/86400]);

subplot(2,1,2); hold on; grid on;
plot(t_day, cum_Wc, 'r-', 'LineWidth', 2);
plot(t_day, cum_Wt, 'b-', 'LineWidth', 2);
plot(t_day, cum_Wc - cum_Wt, 'k--', 'LineWidth', 1.2);
yline(0, 'k-');
xlabel('Time (days)'); ylabel('Cumulative Energy (MWh)');
title(sprintf('Energy Balance (RTE = %.1f%%)', E_dis/E_ch*100));
legend('E_{comp}', 'E_{turb}', 'Net', 'Location', 'northwest');
xlim([0 t_sim/86400]);

sgtitle('Power & Energy', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(outDir, 'fig02_power_energy.png'));

%% Fig 3: 双 SOC + HTV 蓄热
figure('Color','w','Position',[60,200,1300,480]);
subplot(1,2,1); hold on; grid on;
yyaxis left;
h1 = plot(t_day, SOC_gas, 'b-', 'LineWidth', 1.8);
ylabel('Gas SOC (%)'); ylim([-5 105]);
yyaxis right;
h2 = plot(t_day, SOC_heat, 'r-', 'LineWidth', 1.8);
ylabel('Heat SOC (%)'); ylim([-5 105]);
xlabel('Time (days)'); title('Dual State-of-Charge');
legend([h1 h2], {'Gas SOC (P_{HPT})', 'Heat SOC (Q_{HTV})'}, 'Location', 'best');
xlim([0 t_sim/86400]);

subplot(1,2,2); hold on; grid on;
plot(t_day, Q_HTV/3600, 'r-', 'LineWidth', 1.8);
yline(150, 'r--', 'Q_{max} 150'); yline(0, 'k--', 'Q_{min} 0');
xlabel('Time (days)'); ylabel('Q_{HTV} (MWh_{th})');
title('HTV Thermal Storage');
xlim([0 t_sim/86400]);

sgtitle('Storage State-of-Charge', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(outDir, 'fig03_soc_heat.png'));

fprintf('Charts saved to %s/\n', outDir);
