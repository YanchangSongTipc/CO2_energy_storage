% =========================================================================
% run_paper_dispatch.m — CCES-CHP 24h调度仿真 (基于论文负荷曲线)
% 使用 PaperReproduction.m 的实际负荷/风电数据和调度逻辑
% =========================================================================

clc; clear; close all;

%% 0. 环境设置
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src')

%% 1. 负荷与风电数据 (来自论文 Fig. 8)
% 热负荷 [MW] — 典型供暖日
Heat_Load = [38, 35, 32, 30, 29, 28, 28, 29, 31, 33, 36, 39, ...
             41.5, 41, 40, 38, 37, 35, 40, 42, 41.5, 40, 42, 40]';
% 电负荷 [MW]
Elec_Load = [28, 22, 18, 16, 15, 14, 16, 18, 20, 22, 26, 48, ...
             48, 48, 45, 30, 28, 24, 32, 48, 48, 48, 48, 35]';
% 风电出力 [MW]
Wind_Power = [18, 16, 14, 12, 13, 12, 8, 6, 5, 4, 3, 2, ...
              2, 3, 4, 6, 10, 12, 8, 6, 5, 14, 16, 18]';

N_hours = 24;
t_hours = 1:N_hours;

%% 2. CCES-CHP 系统参数 (与论文一致)
% 设计点参数
W_design  = 10;          % 设计功率 [MW]
beta1  = 1.185;          % Q_IC / W_C_E
beta2  = 2.307;          % Q_HR / W_T_E
alpha1 = 2.744;          % m_charge / W_C_E [kg/(s·MW)]
alpha2 = 4.117;          % m_discharge / W_T_E [kg/(s·MW)]

% 储罐参数 (标定至5h满功率放电 @ 10MW)
V_HPT = 6228;            % m³ (匹配 t_discharge=5h)
T_HPT = 298;             % K
Rg = 188.9;              % J/(kg·K) (SI单位)
P_HPT_upper = 6.80;      % MPa
P_HPT_lower = 0.12;      % MPa

% HTV 蓄热参数
Q_HTV_upper = 150;       % MWh_th
Q_HTV_lower = 0;

% 功率约束
W_C_upper = W_design;
W_T_upper = W_design;
Q_HG_LG_max = beta1 * W_C_upper;  % 最大供热 [MW_th]

% 时间步长
dt_h = 1.0;              % 小时
dt_s = dt_h * 3600;      % 秒 (alpha系数单位 kg/(s·MW) 需要秒)

%% 3. C-CHP 参数 (以热定电)
CCHP_capacity    = 30;       % MW
CCHP_therm_ratio = 1.2;     % 热电比
CCHP_heat_max = CCHP_capacity * CCHP_therm_ratio;  % 36 MW_th

% C-CHP 热出力 = min(热负荷, 最大热出力)
CCHP_Heat = min(Heat_Load, CCHP_heat_max);
CCHP_Elec = CCHP_Heat / CCHP_therm_ratio;

% CCES 调度指令
Heat_Dispatch = Heat_Load - CCHP_Heat;            % 热缺口 (>0: CCES需供热)
Elec_Dispatch = Elec_Load - CCHP_Elec - Wind_Power; % 电缺口 (>0: 需充电; <0: 需放电)

%% 4. 初始化状态
Q_HTV_array = zeros(N_hours, 1);
P_HPT_array = zeros(N_hours, 1);

Q_HTV_array(1) = 0.5 * Q_HTV_upper;   % 50% 初始蓄热
P_HPT_array(1) = 0.5 * (P_HPT_upper + P_HPT_lower);  % 50% 初始压力

W_C_hourly    = zeros(N_hours, 1);
W_T_hourly    = zeros(N_hours, 1);
Q_heat_hourly = zeros(N_hours, 1);
Mode          = cell(N_hours, 1);

%% 5. 逐时调度模拟
fprintf('============================================================\n');
fprintf('  CCES-CHP 24h 调度仿真 (基于论文负荷曲线)\n');
fprintf('  设计功率: %d MW | β1=%.2f β2=%.2f\n', W_design, beta1, beta2);
fprintf('  α1=%.2f α2=%.2f kg/(s·MW)\n', alpha1, alpha2);
fprintf('============================================================\n\n');
fprintf(' 时刻 | 模式          | W_C  | W_T  | Q_h  | P_HPT  | Q_HTV \n');
fprintf('      |               | [MW] | [MW] | [MW] | [MPa]  | [MWh] \n');
fprintf('------+---------------+------+------+------+--------+-------\n');

for t = 1:N_hours
    if t > 1
        Q_HTV_array(t) = Q_HTV_array(t-1);
        P_HPT_array(t) = P_HPT_array(t-1);
    end

    % ===== 判断运行模式 =====
    if Elec_Dispatch(t) > 0.5  % 需充电 (电网余量 > 0.5 MW)
        % ---- 充电-供热模式 ----
        Mode{t} = 'Charge+Heat';

        W_C_target = min(Elec_Dispatch(t), W_C_upper);

        % HTV上限约束: dQ/dt = beta1 * W, 限制W使Q不超上限
        W_C_HTV = max(0, (Q_HTV_upper - Q_HTV_array(t)) / dt_h / beta1);
        % HPT上限约束: dm/dt = alpha1 * W [kg/(s·MW)*MW = kg/s]
        % dP = dm * Rg * T / (V * 1e6) [MPa], dt in seconds
        W_C_HPT = max(0, (P_HPT_upper - P_HPT_array(t)) * V_HPT * 1e6 ...
                   / (Rg * T_HPT) / dt_s / alpha1);

        W_C_hourly(t) = min([W_C_target, W_C_HTV, W_C_HPT]);

        % 压缩热存入 HTV
        Q_comp = beta1 * W_C_hourly(t);

        % 供热 (从 HTV)
        if Heat_Dispatch(t) > 0
            Q_heat_hourly(t) = min(Heat_Dispatch(t), Q_HG_LG_max);
            Q_heat_hourly(t) = min(Q_heat_hourly(t), Q_HTV_array(t)/dt_h);
        end

        Q_HTV_array(t) = Q_HTV_array(t) + (Q_comp - Q_heat_hourly(t)) * dt_h;
        % dm[kg] = alpha1[kg/(s·MW)] * W[MW] * dt_s[s]
        % dP[MPa] = dm * Rg[kJ/(kg·K)] * T[K] / (V[m³] * 1e3[kJ/MJ]) / 1e3 →
        % dP = dm * Rg * T / (V * 1e6)
        dm_charge = alpha1 * W_C_hourly(t) * dt_s;
        delta_P = dm_charge * Rg * T_HPT / (V_HPT * 1e6);
        P_HPT_array(t) = P_HPT_array(t) + delta_P;

    elseif Elec_Dispatch(t) < -0.5  % 需放电 (电网缺口 > 0.5 MW)
        % ---- 放电-供热模式 ----
        Mode{t} = 'Dischg+Heat';

        W_T_target = min(abs(Elec_Dispatch(t)), W_T_upper);

        % HTV下限约束
        W_T_HTV = max(0, (Q_HTV_array(t) - Q_HTV_lower) / dt_h / beta2);
        % HPT下限约束: P drop = dm_out * Rg * T / (V * 1e6)
        W_T_HPT = max(0, (P_HPT_array(t) - P_HPT_lower) * V_HPT * 1e6 ...
                   / (Rg * T_HPT) / dt_s / alpha2);

        W_T_hourly(t) = min([W_T_target, W_T_HTV, W_T_HPT]);

        Q_return = beta2 * W_T_hourly(t);  % 回热消耗

        if Heat_Dispatch(t) > 0
            Q_heat_hourly(t) = min(Heat_Dispatch(t), Q_HG_LG_max);
            Q_heat_hourly(t) = min(Q_heat_hourly(t), ...
                (Q_HTV_array(t) - Q_return * dt_h) / dt_h);
        end

        Q_HTV_array(t) = Q_HTV_array(t) - (Q_return + Q_heat_hourly(t)) * dt_h;
        dm_disch = alpha2 * W_T_hourly(t) * dt_s;
        delta_P = dm_disch * Rg * T_HPT / (V_HPT * 1e6);
        P_HPT_array(t) = P_HPT_array(t) - delta_P;

    else  % |Elec_Dispatch| <= 0.5 MW: 接近平衡
        % ---- 仅供热或待机 ----
        Mode{t} = 'HeatOnly';

        if Heat_Dispatch(t) > 0
            Q_heat_hourly(t) = min(Heat_Dispatch(t), Q_HTV_array(t)/dt_h);
            Q_HTV_array(t) = Q_HTV_array(t) - Q_heat_hourly(t) * dt_h;
        end
    end

    % 边界修正
    Q_HTV_array(t) = max(Q_HTV_lower, min(Q_HTV_upper, Q_HTV_array(t)));
    P_HPT_array(t) = max(P_HPT_lower, min(P_HPT_upper, P_HPT_array(t)));

    fprintf('  %2d   | %-13s | %4.1f | %4.1f | %4.1f | %6.2f  | %5.1f \n', ...
        t, Mode{t}, W_C_hourly(t), W_T_hourly(t), Q_heat_hourly(t), ...
        P_HPT_array(t), Q_HTV_array(t));
end

%% 6. SOC 计算
SOC_heat = Q_HTV_array / Q_HTV_upper * 100;
SOC_gas  = (P_HPT_array - P_HPT_lower) / (P_HPT_upper - P_HPT_lower) * 100;

CCES_net_power = W_T_hourly - W_C_hourly;  % + = 净供电

%% 7. 性能汇总
fprintf('\n============================================================\n');
fprintf('              24h 调度性能摘要\n');
fprintf('============================================================\n');
E_charge  = sum(W_C_hourly) * dt_h;
E_disch   = sum(W_T_hourly) * dt_h;
E_heat    = sum(Q_heat_hourly) * dt_h;
RTE_elec  = E_disch / E_charge * 100;

fprintf('总充电量:      %8.2f MWh\n', E_charge);
fprintf('总放电量:      %8.2f MWh\n', E_disch);
fprintf('总供热量:      %8.2f MWh_th\n', E_heat);
fprintf('电力 RTE:      %8.1f %%\n', RTE_elec);
fprintf('HPT压力范围:   %5.2f - %.2f MPa\n', min(P_HPT_array), max(P_HPT_array));
fprintf('HTV蓄热范围:   %5.1f - %.1f MWh_th\n', min(Q_HTV_array), max(Q_HTV_array));
fprintf('SOC_gas范围:   %5.1f - %.1f %%\n', min(SOC_gas), max(SOC_gas));
fprintf('SOC_heat范围:  %5.1f - %.1f %%\n', min(SOC_heat), max(SOC_heat));
fprintf('============================================================\n');

%% 8. 综合可视化 (8面板)
figure('Name', 'CCES-CHP 24h Paper Dispatch Simulation', ...
       'Color', 'w', 'Position', [40, 30, 1550, 960]);

% --- (a) 负荷与风电 ---
subplot(3,3,1);
hold on; grid on;
plot(t_hours, Heat_Load, 'r-o', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'r');
plot(t_hours, Elec_Load, 'b-s', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'b');
plot(t_hours, Wind_Power, 'g-^', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'g');
xlabel('Hour'); ylabel('Power (MW)');
title('(a) Load & Wind Power');
legend('Heat Load', 'Elec Load', 'Wind', 'Location', 'best');
xlim([1 24]);

% --- (b) 调度指令 ---
subplot(3,3,2);
hold on; grid on;
bar(t_hours, Elec_Dispatch, 'FaceColor', [0.6 0.6 1]);
bar(t_hours, Heat_Dispatch, 'FaceColor', [1 0.7 0.7]);
yline(0, 'k-', 'LineWidth', 1.5);
xlabel('Hour'); ylabel('Power (MW)');
title('(b) CCES Dispatch Signal');
legend('Elec Dispatch (+=Charge)', 'Heat Dispatch', 'Location', 'best');
xlim([1 24]);

% --- (c) CCES 运行功率 ---
subplot(3,3,3);
hold on; grid on;
bar(t_hours, W_C_hourly, 'r', 'FaceAlpha', 0.7);
bar(t_hours, -W_T_hourly, 'b', 'FaceAlpha', 0.7);
plot(t_hours, CCES_net_power, 'k-o', 'LineWidth', 2, 'MarkerFaceColor', 'k');
yline(0, 'k-');
xlabel('Hour'); ylabel('Power (MW)');
title('(c) CCES Operation');
legend('Charge W_C', 'Discharge W_T', 'Net Power', 'Location', 'best');
xlim([1 24]);

% --- (d) 电力平衡 ---
subplot(3,3,4);
hold on; grid on;
bar(t_hours, CCHP_Elec, 'FaceColor', [1 0.85 0.3]);        % C-CHP
bar(t_hours, Wind_Power, 'FaceColor', [0.2 0.8 0.2]);       % Wind
bar(t_hours, W_T_hourly, 'FaceColor', [0.3 0.5 0.9]);       % CCES disch
bar(t_hours, -W_C_hourly, 'FaceColor', [0.9 0.4 0.4]);      % CCES charge
bar(t_hours, -Elec_Load, 'FaceColor', [0.3 0.3 0.3]);       % Load
xlabel('Hour'); ylabel('Electric Power (MW)');
title('(d) Electricity Balance');
legend('C-CHP', 'Wind', 'CCES Disch', 'CCES Charg', 'Load', 'Location', 'best');
xlim([1 24]);

% --- (e) 热力平衡 ---
subplot(3,3,5);
hold on; grid on;
bar(t_hours, CCHP_Heat, 'FaceColor', [1 0.85 0.3]);
bar(t_hours, Q_heat_hourly, 'FaceColor', [0.9 0.4 0.4]);
plot(t_hours, Heat_Load, 'k--', 'LineWidth', 2);
xlabel('Hour'); ylabel('Heat Power (MW_{th})');
title('(e) Heat Balance');
legend('C-CHP Heat', 'CCES Heat', 'Heat Load', 'Location', 'best');
xlim([1 24]);

% --- (f) 双 SOC 演变 ---
subplot(3,3,6);
hold on; grid on;
yyaxis left;
plot(t_hours, SOC_gas, 'b-o', 'LineWidth', 2.5, 'MarkerFaceColor', 'b');
ylabel('Gas SOC (%)'); ylim([-5 105]);
yyaxis right;
plot(t_hours, SOC_heat, 'r-s', 'LineWidth', 2.5, 'MarkerFaceColor', 'r');
ylabel('Heat SOC (%)'); ylim([-5 105]);
xlabel('Hour');
title('(f) Dual SOC Evolution');
legend('Gas SOC', 'Heat SOC', 'Location', 'best');
xlim([1 24]);

% --- (g) HPT压力 ---
subplot(3,3,7);
hold on; grid on;
area(t_hours, P_HPT_array, 'FaceColor', [0.3 0.7 0.3], 'EdgeColor', 'g', 'LineWidth', 2);
yline(P_HPT_upper, 'r--', 'P_{max}', 'LineWidth', 1.5);
yline(P_HPT_lower, 'b--', 'P_{min}', 'LineWidth', 1.5);
xlabel('Hour'); ylabel('Pressure (MPa)');
title('(g) HPT Pressure');
xlim([1 24]);

% --- (h) HTV 蓄热量 ---
subplot(3,3,8);
hold on; grid on;
area(t_hours, Q_HTV_array, 'FaceColor', [0.9 0.6 0.3], 'EdgeColor', 'r', 'LineWidth', 2);
yline(Q_HTV_upper, 'r--', 'Q_{max}', 'LineWidth', 1.5);
yline(Q_HTV_lower, 'b--', 'Q_{min}', 'LineWidth', 1.5);
xlabel('Hour'); ylabel('Stored Heat (MWh_{th})');
title('(h) HTV Thermal Storage');
xlim([1 24]);

sgtitle('CCES-CHP 24h Dispatch — Paper Load Curves', 'FontSize', 16, 'FontWeight', 'bold');
saveas(gcf, '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/paper_dispatch_results.png');

%% 9. 导出数据
save('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/paper_dispatch_data.mat', ...
     't_hours', 'Heat_Load', 'Elec_Load', 'Wind_Power', ...
     'CCHP_Heat', 'CCHP_Elec', 'Heat_Dispatch', 'Elec_Dispatch', ...
     'W_C_hourly', 'W_T_hourly', 'Q_heat_hourly', 'Mode', ...
     'P_HPT_array', 'Q_HTV_array', 'SOC_gas', 'SOC_heat', 'CCES_net_power');
fprintf('数据已导出到 paper_dispatch_data.mat\n');
