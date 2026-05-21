% =========================================================================
% plot_longterm.m — 7天仿真: HPT温度/压力/效率长期漂移
% =========================================================================

addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src')
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src/simulink')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')

tmp = load('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/data/REFPROP_lookup.mat');
fns = fieldnames(tmp);
for k = 1:length(fns); assignin('base', fns{k}, tmp.(fns{k})); end

try close_system('CCES_CHP_System', 0); catch; end
build_CCES_model;
mw = get_param('CCES_CHP_System', 'ModelWorkspace');
for k = 1:length(fns); mw.assignin(fns{k}, tmp.(fns{k})); end

T_days = 7;
set_param('CCES_CHP_System', 'SaveOutput', 'on', 'OutputSaveName', 'yout', ...
    'StopTime', num2str(T_days*86400), 'SimulationMode', 'normal');
try add_block('simulink/Ports & Subsystems/Out1', 'CCES_CHP_System/Out5'); catch; end
try delete_line('CCES_CHP_System', 'Storage/3', 'Out5/1'); catch; end
add_line('CCES_CHP_System', 'Storage/3', 'Out5/1');

fprintf('Running %d-day simulation...\n', T_days);
so = sim('CCES_CHP_System');
close_system('CCES_CHP_System', 0);

t_day = so.tout / 86400;
Wc = so.yout.get(1).Values.Data;
Wt = so.yout.get(2).Values.Data;
P  = so.yout.get(3).Values.Data;
Q  = so.yout.get(4).Values.Data;
T_hpt = so.yout.get(5).Values.Data;

% 每日汇总
for d = 1:T_days
    idx = t_day >= (d-1) & t_day < d;
    if any(idx)
        E_c(d)  = trapz(t_day(idx), Wc(idx));
        E_d(d)  = trapz(t_day(idx), Wt(idx));
        T_min(d) = min(T_hpt(idx));
        T_max(d) = max(T_hpt(idx));
        T_avg(d) = mean(T_hpt(idx));
        P_min(d) = min(P(idx));
        P_max(d) = max(P(idx));
        Q_end(d) = Q(find(idx, 1, 'last'));
        RTE(d)   = E_d(d) / E_c(d) * 100;
    end
end

figure('Name', 'CCES-CHP 7-Day Long-Term Dynamics', ...
       'Color', 'w', 'Position', [40, 40, 1500, 850]);

% ---- (a) 温度: 7天全程 ----
subplot(3,2,1);
hold on; grid on;
plot(t_day, T_hpt, 'Color', [0.8 0.3 0.3], 'LineWidth', 1);
plot(1:T_days, T_avg, 'r-o', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
yline(298, 'k--', 'T_{amb}');
xlabel('Time (days)'); ylabel('T_{HPT} (K)');
title('HPT Temperature: Evaporative Cooling Drift');
legend('Instantaneous', 'Daily avg', 'Location', 'best');
xlim([0 T_days]);

% ---- (b) 压力: 7天全程 ----
subplot(3,2,2);
hold on; grid on;
plot(t_day, P, 'b-', 'LineWidth', 0.8);
plot(1:T_days, P_max, 'b-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
yline(6.80, 'r--'); yline(0.12, 'r--');
xlabel('Time (days)'); ylabel('P_{HPT} (MPa)');
title('HPT Pressure: Range Stable but Cycles Weaken');
legend('Instantaneous', 'Daily P_{max}', 'P limits', 'Location', 'best');
xlim([0 T_days]);

% ---- (c) 每日能量吞吐 ----
subplot(3,2,3);
hold on; grid on;
bar(1:T_days, [E_c' E_d']);
plot(1:T_days, E_c, 'r-o', 'LineWidth', 2, 'MarkerFaceColor', 'r');
plot(1:T_days, E_d, 'b-s', 'LineWidth', 2, 'MarkerFaceColor', 'b');
xlabel('Day'); ylabel('Energy (MWh)');
title('Daily Energy Throughput Decay');
legend('Charge E_{in}', 'Discharge E_{out}', 'Location', 'best');
xlim([0.5 T_days+0.5]);

% ---- (d) RTE 漂移 ----
subplot(3,2,4);
hold on; grid on;
yyaxis left;
plot(1:T_days, RTE, 'k-o', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'k');
ylabel('RTE (%)');
yyaxis right;
plot(1:T_days, T_avg, 'r-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
ylabel('T_{avg} (K)');
xlabel('Day');
title('RTE vs Temperature: Inverse Correlation');
legend('RTE (E_{out}/E_{in})', 'T_{avg}', 'Location', 'best');
xlim([0.5 T_days+0.5]);

% ---- (e) 最低/最高温度 ----
subplot(3,2,5);
hold on; grid on;
fill([1:T_days fliplr(1:T_days)], [T_max fliplr(T_min)], ...
     [0.9 0.6 0.6], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
plot(1:T_days, T_max, 'r-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'r');
plot(1:T_days, T_min, 'b-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
plot(1:T_days, T_avg, 'k-s', 'LineWidth', 2, 'MarkerFaceColor', 'k');
yline(298, 'k--');
xlabel('Day'); ylabel('T_{HPT} (K)');
title('Daily T Range: Progressive Cooling');
legend('Range', 'T_{max}', 'T_{min}', 'T_{avg}', 'Location', 'best');
xlim([0.5 T_days+0.5]);

% ---- (f) 累计能量 ----
subplot(3,2,6);
hold on; grid on;
cum_Wc = cumtrapz(t_day, Wc);
cum_Wt = cumtrapz(t_day, Wt);
plot(t_day, cum_Wc, 'r-', 'LineWidth', 2);
plot(t_day, cum_Wt, 'b-', 'LineWidth', 2);
plot(t_day, cum_Wc - cum_Wt, 'k--', 'LineWidth', 1.5);
xlabel('Time (days)'); ylabel('Cumulative Energy (MWh)');
title('7-Day Cumulative Energy Balance');
legend('E_{comp}', 'E_{turb}', 'Net', 'Location', 'northwest');
xlim([0 T_days]); grid on;

sgtitle(sprintf('CCES-CHP 7-Day Long-Term Dynamics (T drift: %.0f K, Capacity: -%.0f%%)', ...
    T_avg(1)-T_avg(end), (1-E_c(end)/E_c(1))*100), ...
    'FontSize', 14, 'FontWeight', 'bold');

saveas(gcf, '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/simulink/7day_longterm.png');
fprintf('Chart saved to output/7day_longterm.png\n');
