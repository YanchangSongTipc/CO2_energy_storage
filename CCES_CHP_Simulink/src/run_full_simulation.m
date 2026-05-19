% =========================================================================
% run_full_simulation.m — CCES-CHP 24h 完整动态仿真 (基于REFPROP耦合模型)
% 包括: 多循环调度、双SOC约束、可行性域、综合可视化
% =========================================================================

clc; clear; close all;

%% 0. 环境与参数加载
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src')
CCES_parameters;

%% 1. 24小时多循环调度场景配置
% 电价/负荷驱动: 低价充电 → 高价放电
n_cycles = 3;                    % 每天充放电循环次数
hours_per_cycle = 24 / n_cycles; % 8小时/循环
charge_hours_per_cycle = 3;      % 每循环充电3h (低价时段)
idle_hours_per_cycle = 1;        % 闲置1h
discharge_hours_per_cycle = 3;   % 每循环放电3h (高价时段)
reserve_hours = hours_per_cycle - charge_hours_per_cycle - idle_hours_per_cycle - discharge_hours_per_cycle;

dt = 60;          % 时间步长 [s]
t_total = 24 * 3600;
t_span = 0:dt:t_total;
n_steps = length(t_span);

% 负荷曲线 (归一化, 模拟典型日负荷)
t_hr_of_day = mod(t_span/3600, 24);
load_factor = 0.6 + 0.4 * sin(pi * (t_hr_of_day - 6) / 12);  % 昼高夜低
load_factor(t_hr_of_day > 18 | t_hr_of_day < 6) = 0.5;        % 夜间低谷

%% 2. 系统状态初始化
% 可用质量差
delta_m_max = (params.P_HPT_nom - params.P_LPT_nom) * params.V_HPT ...
              / (params.Rg_CO2 * params.T_HPT_store);  % ~59,493 kg

% 初始状态 (50% SOC)
SOC_gas_init  = 0.50;
SOC_heat_init = 0.50;
m_HPT_init = (params.P_LPT_nom + SOC_gas_init * (params.P_HPT_nom - params.P_LPT_nom)) ...
             * params.V_HPT / (params.Rg_CO2 * params.T_HPT_store);
Q_HTV_init = SOC_heat_init * params.Q_HTV_capacity;
m_LPT_init = (params.P_LPT_nom + 1e6) * params.V_LPT / (params.Rg_CO2 * params.T_amb);

x0 = [m_HPT_init; Q_HTV_init; m_LPT_init];

fprintf('============================================================\n');
fprintf('  CCES-CHP 24小时动态仿真\n');
fprintf('  循环次数: %d | 每循环: 充电%dh 闲置%dh 放电%dh\n', ...
    n_cycles, charge_hours_per_cycle, idle_hours_per_cycle, discharge_hours_per_cycle);
fprintf('  初始 Gas SOC: %.1f%% | Heat SOC: %.1f%%\n', SOC_gas_init*100, SOC_heat_init*100);
fprintf('  可用CO2质量: %.0f kg\n', delta_m_max);
fprintf('============================================================\n\n');

%% 3. ODE求解 (含调度逻辑)
options = odeset('RelTol', 1e-6, 'MaxStep', 120);
t_sim = tic;
[t_ode, x_ode] = ode45(@(t,x) system_dynamics(t, x, params, n_cycles, ...
    charge_hours_per_cycle, idle_hours_per_cycle, discharge_hours_per_cycle, ...
    load_factor, t_span), t_span, x0, options);
fprintf('ODE求解完成, 耗时 %.1f 秒\n', toc(t_sim));

%% 4. 后处理 — 提取全部时序
n_pts = length(t_ode);
m_HPT = x_ode(:,1);  Q_HTV = x_ode(:,2);  m_LPT = x_ode(:,3);

% 压力 (Pa → MPa)
P_HPT    = m_HPT .* params.Rg_CO2 .* params.T_HPT_store ./ params.V_HPT;
P_LPT    = m_LPT .* params.Rg_CO2 .* params.T_amb ./ params.V_LPT;

% SOC
SOC_gas  = (P_HPT - params.P_LPT_nom) ./ (params.P_HPT_nom - params.P_LPT_nom) * 100;
SOC_heat = Q_HTV / params.Q_HTV_capacity * 100;

% 时序功率
W_comp = zeros(n_pts,1);  Q_IC = zeros(n_pts,1);
W_turb = zeros(n_pts,1);  Q_HR = zeros(n_pts,1);
Q_heat_out = zeros(n_pts,1);
mode_hist  = zeros(n_pts,1);

for i = 1:n_pts
    [~, Wc, Qic, Wt, Qhr, Qh, md] = system_dynamics(t_ode(i), x_ode(i,:)', params, ...
        n_cycles, charge_hours_per_cycle, idle_hours_per_cycle, ...
        discharge_hours_per_cycle, load_factor, t_span);
    W_comp(i) = Wc;  Q_IC(i) = Qic;
    W_turb(i) = Wt;  Q_HR(i) = Qhr;
    Q_heat_out(i) = Qh;
    mode_hist(i) = md;
end

%% 5. 性能指标汇总
charge_mask  = mode_hist == 1;
disch_mask   = mode_hist == -1;

E_charge_elec  = trapz(t_ode(charge_mask), W_comp(charge_mask)) / 3600;   % MWh_e
E_disch_elec   = trapz(t_ode(disch_mask),  W_turb(disch_mask))  / 3600;
E_charge_heat  = trapz(t_ode(charge_mask), Q_IC(charge_mask))   / 3600;   % MWh_th
E_disch_heat   = trapz(t_ode(disch_mask),  Q_HR(disch_mask))    / 3600;
E_heat_supply  = trapz(t_ode(disch_mask),  Q_heat_out(disch_mask)) / 3600;
RTE_elec       = E_disch_elec / E_charge_elec * 100;
RTE_combined   = (E_disch_elec + E_heat_supply) / (E_charge_elec + E_charge_heat) * 100;

fprintf('\n============================================================\n');
fprintf('              24h 性能摘要\n');
fprintf('============================================================\n');
fprintf('充电量 (电力):    %8.2f MWh_e\n', E_charge_elec);
fprintf('放电量 (电力):    %8.2f MWh_e\n', E_disch_elec);
fprintf('回收热量:         %8.2f MWh_th\n', E_charge_heat);
fprintf('回热消耗:         %8.2f MWh_th\n', E_disch_heat);
fprintf('对外供热:         %8.2f MWh_th\n', E_heat_supply);
fprintf('电力往返效率:     %8.1f %%\n', RTE_elec);
fprintf('综合效率:         %8.1f %%\n', RTE_combined);
fprintf('---\n');
fprintf('HPT压力范围:      %6.2f – %6.2f MPa\n', min(P_HPT)/1e6, max(P_HPT)/1e6);
fprintf('Gas SOC 范围:     %6.1f – %6.1f %%\n', min(SOC_gas), max(SOC_gas));
fprintf('Heat SOC 范围:    %6.1f – %6.1f %%\n', min(SOC_heat), max(SOC_heat));
fprintf('循环次数:         %d\n', n_cycles);
fprintf('============================================================\n');

%% 6. 综合可视化
t_hr = t_ode / 3600;

figure('Name', 'CCES-CHP 24-Hour Dynamic Simulation', ...
       'Color', 'w', 'Position', [60, 40, 1500, 920]);

% --- (a) 电力与热功率流 ---
ax1 = subplot(3,2,1);
hold on; grid on;
h1 = area(t_hr, W_comp, 'FaceColor', [0.9 0.5 0.5], 'EdgeColor', 'r', 'LineWidth', 1);
h2 = area(t_hr, -W_turb, 'FaceColor', [0.5 0.5 0.9], 'EdgeColor', 'b', 'LineWidth', 1);
h3 = plot(t_hr, W_comp - W_turb, 'k-', 'LineWidth', 2);
xlabel('Time (hours)'); ylabel('Power (MW)');
legend([h1, h2, h3], 'Compressor W_C', 'Turbine W_T', 'Net Power', 'Location', 'northeast');
title('(a) Electrical Power Flow');
xlim([0 24]); ylim auto;

% --- (b) 双 SOC 演变 ---
ax2 = subplot(3,2,2);
hold on; grid on;
yyaxis left;
plot(t_hr, SOC_gas, 'b-', 'LineWidth', 2.5);
ylabel('Gas SOC (%)'); ylim([-5 105]);
yyaxis right;
plot(t_hr, SOC_heat, 'r-', 'LineWidth', 2.5);
ylabel('Heat SOC (%)'); ylim([-5 105]);
xlabel('Time (hours)');
title('(b) Dual State-of-Charge');
legend('Gas SOC (P_H_P_T)', 'Heat SOC (Q_H_T_V)', 'Location', 'best');
xlim([0 24]);

% --- (c) 热量流与对外供热 ---
ax3 = subplot(3,2,3);
hold on; grid on;
h4 = plot(t_hr, Q_IC, 'r-', 'LineWidth', 1.5);
h5 = plot(t_hr, -Q_HR, 'b-', 'LineWidth', 1.5);
h6 = plot(t_hr, Q_heat_out, 'g-', 'LineWidth', 2);
xlabel('Time (hours)'); ylabel('Heat Power (MW_{th})');
legend([h4, h5, h6], 'Q_{IC} (回收)', 'Q_{HR} (回热消耗)', 'Q_{heat} (对外供热)', 'Location', 'best');
title('(c) Thermal Power Flows');
xlim([0 24]); ylim auto;

% --- (d) HPT 压力与运行模式 ---
ax4 = subplot(3,2,4);
hold on; grid on;
yyaxis left;
plot(t_hr, P_HPT/1e6, 'Color', [0 0.6 0], 'LineWidth', 2.5);
yline(params.P_HPT_nom/1e6, 'r--', 'P_{max}', 'LineWidth', 1);
yline(params.P_LPT_nom/1e6, 'b--', 'P_{min}', 'LineWidth', 1);
ylabel('HPT Pressure (MPa)');
yyaxis right;
plot(t_hr, mode_hist, 'k-', 'LineWidth', 1);
ylabel('Mode (+1=Charge, -1=Discharge)');
ylim([-1.5 1.5]); yticks([-1 0 1]);
xlabel('Time (hours)');
title('(d) HPT Pressure & Operating Mode');
xlim([0 24]);

% --- (e) 可行性域 (Feasibility Domain) ---
ax5 = subplot(3,2,5);
hold on; grid on;

% 从仿真数据构建瞬时可行性域
beta1_eff = 1.185;  % 设计点
beta2_eff = 2.307;

for cyc = 1:n_cycles
    t_start_cyc = (cyc-1) * (charge_hours_per_cycle + idle_hours_per_cycle + ...
                   discharge_hours_per_cycle) * 3600;
    t_end_cyc = t_start_cyc + (charge_hours_per_cycle + discharge_hours_per_cycle) * 3600;

    idx = t_ode >= t_start_cyc & t_ode <= t_end_cyc;
    if any(idx)
        SOCg_avg = mean(SOC_gas(idx));
        SOCh_avg = mean(SOC_heat(idx));

        % 可行性域边界: W_max, Q_max 由 SOC 约束
        W_max = min(params.W_design, SOCg_avg / 100 * params.W_design);
        Q_max = min(W_max * beta2_eff, SOCh_avg / 100 * params.Q_HTV_capacity / 3600);

        % 简化多边形
        W_poly = [0, W_max, W_max, 0, 0];
        Q_poly = [0, 0, Q_max, Q_max*0.3, 0];
        fill(W_poly, Q_poly, [0.7 0.85 1], 'FaceAlpha', 0.3, 'EdgeColor', 'b', 'LineWidth', 1);

        % 工作点
        W_op = mean(W_comp(idx));
        Q_op = mean(Q_IC(idx));
        plot(W_op, Q_op, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
        text(W_op + 0.2, Q_op + 0.2, sprintf('Cyc%d', cyc), 'FontSize', 9);
    end
end
xlabel('Electric Power W (MW)'); ylabel('Heat Power Q (MW_{th})');
title('(e) Operational Feasibility Domain');
xlim([0 params.W_design * 1.2]); ylim auto;

% --- (f) 累计能量平衡 ---
ax6 = subplot(3,2,6);
hold on; grid on;

cum_Wc = cumtrapz(t_ode, W_comp) / 3600;    % MWh_e
cum_Wt = cumtrapz(t_ode, W_turb)  / 3600;
cum_Qic = cumtrapz(t_ode, Q_IC)   / 3600;
cum_Qhr = cumtrapz(t_ode, Q_HR)   / 3600;
cum_Qh  = cumtrapz(t_ode, Q_heat_out) / 3600;

plot(t_hr, cum_Wc, 'r-', 'LineWidth', 2);
plot(t_hr, cum_Wt, 'b-', 'LineWidth', 2);
plot(t_hr, cum_Qic, 'r--', 'LineWidth', 1.5);
plot(t_hr, cum_Qhr, 'b--', 'LineWidth', 1.5);
plot(t_hr, cum_Qh, 'g-', 'LineWidth', 1.5);
xlabel('Time (hours)'); ylabel('Cumulative Energy (MWh)');
legend('E_{charge}', 'E_{discharge}', 'Q_{IC}', 'Q_{HR}', 'Q_{heat}', 'Location', 'northwest');
title('(f) Cumulative Energy Balance');
xlim([0 24]); grid on;

sgtitle('CCES-CHP System: 24-Hour Multi-Cycle Dynamic Simulation', ...
       'FontSize', 16, 'FontWeight', 'bold');

saveas(gcf, '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/24h_simulation_results.png');

%% 7. 导出数据
save('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/output/24h_simulation_data.mat', ...
     't_ode', 't_hr', 'm_HPT', 'Q_HTV', 'm_LPT', 'P_HPT', 'P_LPT', ...
     'SOC_gas', 'SOC_heat', 'W_comp', 'W_turb', 'Q_IC', 'Q_HR', ...
     'Q_heat_out', 'mode_hist', 'E_charge_elec', 'E_disch_elec', ...
     'RTE_elec', 'RTE_combined');
fprintf('\n数据已导出至 24h_simulation_data.mat\n');
fprintf('图片已保存至 24h_simulation_results.png\n');

%% ========================================================================
%  系统动力学函数 — 含24h多循环调度逻辑
% ========================================================================
function [dx, W_comp, Q_IC, W_turb, Q_HR, Q_heat, mode] = ...
    system_dynamics(t, x, p, n_cycles, ch_hr, idle_hr, disch_hr, load_fac, t_span)

    % 状态
    m_HPT = x(1);  Q_HTV = x(2);  m_LPT = x(3);

    % 当前压力
    P_HPT_curr = m_HPT * p.Rg_CO2 * p.T_HPT_store / p.V_HPT;    % Pa
    P_LPT_curr = m_LPT * p.Rg_CO2 * p.T_amb / p.V_LPT;

    % SOC
    SOC_g = (P_HPT_curr - p.P_LPT_nom) / (p.P_HPT_nom - p.P_LPT_nom);
    SOC_h = Q_HTV / p.Q_HTV_capacity;

    % 周期调度逻辑
    cycle_dur = (ch_hr + idle_hr + disch_hr) * 3600;  % 不包括reserve
    t_mod = mod(t, cycle_dur);

    if t_mod < ch_hr * 3600
        mode = 1;   % 充电
    elseif t_mod < (ch_hr + idle_hr) * 3600
        mode = 0;   % 闲置
    else
        mode = -1;  % 放电
    end

    % 负荷因子 (当前时刻)
    [~, idx] = min(abs(t_span - t));
    lf = load_fac(min(idx, length(load_fac)));

    % 功率系数 (负荷跟随 + SOC约束)
    W_scale = max(0.3, min(1.0, lf));  % 最低30%出力

    % ==== 充电模式 ====
    if mode == 1 && SOC_g < 0.98 && SOC_h < 0.98
        % 压力约束: HPT不能超压
        max_m_dot_ch = (p.P_HPT_nom - P_HPT_curr) * p.V_HPT / (p.Rg_CO2 * p.T_HPT_store);
        max_m_dot_ch = max(0, max_m_dot_ch);

        W_C = min(p.W_design * W_scale, max_m_dot_ch / p.alpha1);
        W_C = max(0, W_C);

        m_dot    = p.alpha1 * W_C;
        Q_IC_act = p.beta1 * W_C;

        dm_HPT_dt  = m_dot;
        dm_LPT_dt  = -m_dot;
        dQ_HTV_dt  = Q_IC_act;

        W_comp = W_C;  Q_IC = Q_IC_act;
        W_turb = 0;    Q_HR = 0;    Q_heat = 0;

    % ==== 闲置模式 ====
    elseif mode == 0
        dm_HPT_dt = 0;  dm_LPT_dt = 0;  dQ_HTV_dt = 0;
        W_comp = 0;  Q_IC = 0;  W_turb = 0;  Q_HR = 0;  Q_heat = 0;

    % ==== 放电模式 ====
    elseif mode == -1 && SOC_g > 0.02 && SOC_h > 0.02
        % 压力约束: HPT不能低于LPT
        max_m_dot_dis = (P_HPT_curr - p.P_LPT_nom) * p.V_HPT / (p.Rg_CO2 * p.T_HPT_store);
        max_m_dot_dis = max(0, max_m_dot_dis);

        W_T = min(p.W_design * W_scale, max_m_dot_dis / p.alpha2);
        W_T = max(0, W_T);

        m_dot    = p.alpha2 * W_T;
        Q_HR_act = p.beta2 * W_T;

        % 对外供热 (回热剩余的20%可对外供给)
        Q_heat_act = Q_HR_act * 0.20;

        dm_HPT_dt  = -m_dot;
        dm_LPT_dt  = m_dot;
        dQ_HTV_dt  = -(Q_HR_act + Q_heat_act);

        W_comp = 0;  Q_IC = 0;
        W_turb = W_T;  Q_HR = Q_HR_act;
        Q_heat = Q_heat_act;

    % ==== SOC越限 → 强制闲置 ====
    else
        dm_HPT_dt = 0;  dm_LPT_dt = 0;  dQ_HTV_dt = 0;
        W_comp = 0;  Q_IC = 0;  W_turb = 0;  Q_HR = 0;  Q_heat = 0;
    end

    dx = [dm_HPT_dt; dQ_HTV_dt; dm_LPT_dt];
end
