% =========================================================================
% plot_simulation.m — 24h 仿真结果双 y 轴可视化
% =========================================================================

addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')

tmp = load('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/data/REFPROP_lookup.mat');
fns = fieldnames(tmp);
for k = 1:length(fns); assignin('base', fns{k}, tmp.(fns{k})); end

try close_system('CCES_CHP_System', 0); catch; end
build_CCES_model;
mw = get_param('CCES_CHP_System', 'ModelWorkspace');
for k = 1:length(fns); mw.assignin(fns{k}, tmp.(fns{k})); end

set_param('CCES_CHP_System', 'SaveOutput', 'on', 'OutputSaveName', 'yout', ...
    'StopTime', '86400', 'SimulationMode', 'normal');
so = sim('CCES_CHP_System');

t = so.tout / 3600;
Wc = so.yout.get(1).Values.Data;
Wt = so.yout.get(2).Values.Data;
P  = so.yout.get(3).Values.Data;
Q  = so.yout.get(4).Values.Data;

close_system('CCES_CHP_System', 0);

figure('Name', 'CCES-CHP 24h Simulation', 'Color', 'w', 'Position', [60, 60, 1400, 700]);

% ---- 左: 双 y 轴 P + Q ----
ax1 = subplot(2,2,1);
yyaxis left;
plot(t, P, 'b-', 'LineWidth', 2);
yline(6.80, 'r--'); yline(0.12, 'g--');
ylabel('P_{HPT} (MPa)'); ylim([0 8]);

yyaxis right;
plot(t, Q, 'r-', 'LineWidth', 2);
yline(150, 'k--'); yline(0, 'k--');
ylabel('Q_{HTV} (MWh_{th})'); ylim([0 160]);

xlabel('Time (h)'); title('Storage: Pressure & Heat');
xlim([0 24]); grid on;
legend('P_{HPT}', 'P_{max}', 'P_{min}', 'Q_{HTV}', 'Q_{max}');

% ---- 右: 功率 ----
ax2 = subplot(2,2,2);
hold on; grid on;
stairs(t, Wc, 'r', 'LineWidth', 1.5);
stairs(t, -Wt, 'b', 'LineWidth', 1.5);
xlabel('Time (h)'); ylabel('Power (MW)');
title('Charge / Discharge Power');
legend('W_{comp} (charge)', 'W_{turb} (discharge)', 'Location', 'best');
xlim([0 24]);

% ---- 底左: SOC ----
ax3 = subplot(2,2,3);
hold on; grid on;
SOC_g = (P - 0.12) / (6.80 - 0.12) * 100;
SOC_h = Q / 150 * 100;
yyaxis left;
plot(t, SOC_g, 'b-', 'LineWidth', 2);
ylabel('Gas SOC (%)'); ylim([-5 105]);
yyaxis right;
plot(t, SOC_h, 'r-', 'LineWidth', 2);
ylabel('Heat SOC (%)'); ylim([-5 105]);
xlabel('Time (h)'); title('Dual SOC');
xlim([0 24]);

% ---- 底右: 累积能量 (含相变焓) ----
ax4 = subplot(2,2,4);
hold on; grid on;

% 充电质量流量: m_dot = alpha1 * charge_cmd
% CO2 气相→液相焓降: Δh = 505708 - 269875 = 235833 J/kg
dh_phase = 235833;  % J/kg
alpha1 = 2.744;     % kg/(s·MW)

% 从 controller 指令推算 mass flow
charge_cmd = Wc / 9.39 * 10;  % Wc ∝ cmd, 9.39MW at 10MW cmd
m_dot_ch = alpha1 * charge_cmd;  % kg/s

% 相变储存功率: m_dot * dh_phase / 1e6 [MW]
P_phase = m_dot_ch * dh_phase / 1e6;

cum_Wc = cumtrapz(t, Wc);          % 电力 [MWh_e]
cum_phase = cumtrapz(t, P_phase);   % 相变焓 [MWh_th]
cum_stored = cum_Wc + cum_phase;    % 总储存 = 电 + 相变
cum_Wt = cumtrapz(t, Wt);           % 放电 [MWh_e]

plot(t, cum_Wc, 'r-', 'LineWidth', 1.5);
plot(t, cum_stored, 'm-', 'LineWidth', 2);
plot(t, cum_Wt, 'b-', 'LineWidth', 1.5);
xlabel('Time (h)'); ylabel('Energy (MWh)');
title('Cumulative Energy (incl. phase change)');
legend('E_{elec}', 'E_{stored}=elec+phase', 'E_{discharge}', 'Location', 'best');
xlim([0 24]); grid on;

sgtitle('CCES-CHP 24h Dynamic Simulation', 'FontSize', 16, 'FontWeight', 'bold');
saveas(gcf, '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/24h_dual_axis.png');
fprintf('图表已保存。\n');
