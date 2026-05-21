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

% 添加 Out5 捕获 HPT 温度
try add_block('simulink/Ports & Subsystems/Out1','CCES_CHP_System/Out5'); catch; end
try delete_line('CCES_CHP_System','Storage/3','Out5/1'); catch; end
add_line('CCES_CHP_System','Storage/3','Out5/1');

set_param('CCES_CHP_System', 'SaveOutput', 'on', 'OutputSaveName', 'yout', ...
    'StopTime', '86400', 'SimulationMode', 'normal');
so = sim('CCES_CHP_System');

t = so.tout / 3600;
Wc = so.yout.get(1).Values.Data;
Wt = so.yout.get(2).Values.Data;
P  = so.yout.get(3).Values.Data;
Q  = so.yout.get(4).Values.Data;
T_hpt_raw = so.yout.get(5).Values.Data;
if length(T_hpt_raw) == 1
    T_hpt = T_hpt_raw * ones(size(P));
else
    T_hpt = T_hpt_raw;
end

close_system('CCES_CHP_System', 0);

figure('Name', 'CCES-CHP 24h Simulation', 'Color', 'w', 'Position', [60, 60, 1400, 700]);

% ---- 左上: HPT 温度 + 压力 ----
ax1 = subplot(2,2,1);
hold on; grid on;
yyaxis left;
hP = plot(t, P, 'b-', 'LineWidth', 2);
yline(6.80, 'b--'); yline(0.12, 'b--');
ylabel('P_{HPT} (MPa)'); ylim([0 8]);
yyaxis right;
hT = plot(t, T_hpt, 'r-', 'LineWidth', 2);
yline(298, 'r--');
ylabel('T_{HPT} (K)'); ylim([260 310]);
xlabel('Time (h)'); title('HPT: Pressure & Temperature');
legend([hP hT], {'P_{HPT} (MPa)', 'T_{HPT} (K)'}, 'Location', 'best');
xlim([0 24]);

% ---- 右上: 功率 ----
ax2 = subplot(2,2,2);
hold on; grid on;
stairs(t, Wc, 'r', 'LineWidth', 1.5);
stairs(t, Wt, 'b', 'LineWidth', 1.5);
xlabel('Time (h)'); ylabel('Power (MW)');
title('Charge / Discharge Power');
legend('W_{comp} (charge)', 'W_{turb} (discharge)', 'Location', 'best');
xlim([0 24]);

% ---- 左下: 双 SOC + Q_HTV ----
ax3 = subplot(2,2,3);
hold on; grid on;
SOC_g = (P - 0.12) / (6.80 - 0.12) * 100;
SOC_h = Q / 150 * 100;
yyaxis left;
h1 = plot(t, SOC_g, 'b-', 'LineWidth', 2);
ylabel('Gas SOC (%)'); ylim([-5 105]);
yyaxis right;
h2 = plot(t, SOC_h, 'r-', 'LineWidth', 2);
plot(t, Q, 'r:', 'LineWidth', 1);
ylabel('Heat SOC (%) / Q_{HTV} (MWh)'); ylim([-5 105]);
xlabel('Time (h)'); title('Dual SOC & Thermal Storage');
legend([h1 h2], {'Gas SOC (P)', 'Heat SOC (Q/150)'}, 'Location', 'best');
xlim([0 24]);

% ---- 右下: 累积能量 ----
ax4 = subplot(2,2,4);
hold on; grid on;

cum_Wc = cumtrapz(t, Wc);    % 压缩机耗电 [MWh_e]
cum_Wt = cumtrapz(t, Wt);    % 透平发电 [MWh_e]
cum_net = cum_Wc - cum_Wt;   % 净耗电

plot(t, cum_Wc, 'r-', 'LineWidth', 2);
plot(t, cum_Wt, 'b-', 'LineWidth', 2);
plot(t, cum_net, 'k--', 'LineWidth', 1.5);
yline(0, 'k-');
xlabel('Time (h)'); ylabel('Energy (MWh)');
title('Cumulative Energy (HTV from empty)');
legend('E_{comp} (电网入)', 'E_{turb} (发电出)', 'Net (入-出)', 'Location', 'northwest');
xlim([0 24]); grid on;

sgtitle('CCES-CHP 24h Dynamic Simulation', 'FontSize', 16, 'FontWeight', 'bold');
saveas(gcf, '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/24h_dual_axis.png');
fprintf('图表已保存。\n');
