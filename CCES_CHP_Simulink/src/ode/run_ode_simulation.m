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
Th=573; Tc=298; rho_oil=850; cp_oil=2.5;
V_total = 150*3600*1000 / (rho_oil * cp_oil * (Th - Tc));  % MJ→kJ, ~923 m³
V_hot_0 = 0.5 * V_total;  % 50% SOC
Q_HTV_0 = V_hot_0 * rho_oil * cp_oil * (Th - Tc) / 3600;  % MWh_th

fprintf('双罐HTV: V_total=%.0f m3, V_hot_0=%.0f (%.0f MWh)\n', V_total, V_hot_0, Q_HTV_0);

%% 初始状态
T_tank_0 = 298;
x0 = [m_HPT_0; V_hot_0; T_tank_0];

%% 仿真
dt = 180;  t_sim = 21 * 86400;  tspan = 0:dt:t_sim;
fprintf('CCES-CHP ODE仿真 (21天, 双罐HTV): 充电7.5h 放电5h\n');

opts = odeset('RelTol', 2e-4, 'MaxStep', 900);
[t, x] = ode45(@ode_dynamics, tspan, x0, opts);

%% 后处理
m_HPT = x(:,1);  V_hot = x(:,2);  T_tank = x(:,3);
Th=573; Tc=298;
Q_HTV = V_hot * 850 * 2.5 * (Th - Tc) / 1000;  % [MJ], kJ→MJ
Q_cap = 150 * 3600;
% P_HPT: 两相模型 (与 ode_dynamics 一致), 使用 T_tank 动态计算
P_sat_298 = getFluidProperty(cfg.REFPROP_LIB,'P','T',298,'Q',0,'CO2',1,1,'MASS BASE SI');
T_sat_v = 260:0.5:304;  P_sat_v = zeros(size(T_sat_v));
for i=1:length(T_sat_v)
    P_sat_v(i)=getFluidProperty(cfg.REFPROP_LIB,'P','T',T_sat_v(i),'Q',0,'CO2',1,1,'MASS BASE SI');
end
P_HPT = zeros(size(m_HPT));
for i = 1:length(m_HPT)
    Tc = max(260, min(304, T_tank(i)));
    Ps = interp1(T_sat_v, P_sat_v, Tc, 'linear');
    rl = getFluidProperty(cfg.REFPROP_LIB,'D','T',Tc,'Q',0,'CO2',1,1,'MASS BASE SI');
    rv = getFluidProperty(cfg.REFPROP_LIB,'D','T',Tc,'Q',1,'CO2',1,1,'MASS BASE SI');
    if m_HPT(i) >= rl*V_HPT
        P_HPT(i) = Ps/1e6 + (m_HPT(i)-rl*V_HPT)/(rl*V_HPT)*1000;
    elseif m_HPT(i) > rv*V_HPT*0.05
        P_HPT(i) = Ps/1e6;
    else
        P_HPT(i) = m_HPT(i)*188.9*T_tank(i)/V_HPT/1e6;
    end
end

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
