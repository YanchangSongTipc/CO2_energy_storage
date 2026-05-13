% =========================================================================
% generate_training_data.m
% 为 ML 模型生成 CCES-CHP 运行可行域训练数据
% 输入: SOC状态 + 功率组合
% 输出: 可行性标签 + 系统性能指标
% =========================================================================

clc; clear; close all;

%% 1. REFPROP 配置与系统参数 (与 PaperReproduction 一致)
libLoc = 'D:\Program Files\REFPROP\';
Fluid = 'CO2';

% 设计参数
T_amb = 298;  P_amb = 0.101;  P_LPT = 0.102;  P_HPT = 6.80;
T_comp_in = 308;  T_turb_in = 483;  T_cooler_out = 298;
T_ATV = 298;  T_HTV = 495;  dT_min = 5;
eta_C_is = 0.85;  eta_T_is = 0.88;
eta_motor = 0.98;  eta_gen = 0.95;
n_poly = 1.3;  Rg = 0.1889;
m_charge = 26.9;  m_discharge = 40.3;
W_design = 10;
t_charge = 7.5;  t_discharge = 5.0;

% HPT 与 HTV 容量
V_HPT = 500;  T_HPT = 298;
Q_HTV_upper = 150;  Q_HTV_lower = 0;
P_HPT_upper = 6.80;  P_HPT_lower = 0.12;

fprintf('=== CCES-CHP 训练数据生成 ===\n');

%% 2. 热力学状态点计算 (15节点, 仅计算一次)
Num_States = 15;
States = zeros(Num_States, 6);
States(:, 1) = 1:Num_States;

States(1, 2) = T_amb;  States(1, 3) = P_LPT;  States(1, 6) = m_charge;
States(1, 4) = getFluidProperty(libLoc, 'H', 'P', States(1,3)*1e6, 'T', States(1,2), Fluid, 1, 1, 'MASS BASE SI');
States(1, 5) = getFluidProperty(libLoc, 'S', 'P', States(1,3)*1e6, 'T', States(1,2), Fluid, 1, 1, 'MASS BASE SI');
States(2, 2:6) = States(1, 2:6);

States(3, 3) = 0.90;  States(3, 6) = m_charge;
s3_is = States(2, 5);
h3_is = getFluidProperty(libLoc, 'H', 'P', States(3,3)*1e6, 'S', s3_is, Fluid, 1, 1, 'MASS BASE SI');
States(3, 4) = States(2, 4) + (h3_is - States(2, 4)) / eta_C_is;
States(3, 2) = getFluidProperty(libLoc, 'T', 'P', States(3,3)*1e6, 'H', States(3,4), Fluid, 1, 1, 'MASS BASE SI');
States(3, 5) = getFluidProperty(libLoc, 'S', 'P', States(3,3)*1e6, 'H', States(3,4), Fluid, 1, 1, 'MASS BASE SI');

States(4, 2) = T_comp_in;  States(4, 3) = 0.85;  States(4, 6) = m_charge;
States(4, 4) = getFluidProperty(libLoc, 'H', 'P', States(4,3)*1e6, 'T', States(4,2), Fluid, 1, 1, 'MASS BASE SI');
States(4, 5) = getFluidProperty(libLoc, 'S', 'P', States(4,3)*1e6, 'T', States(4,2), Fluid, 1, 1, 'MASS BASE SI');

States(5, 3) = 6.90;  States(5, 6) = m_charge;
s5_is = States(4, 5);
h5_is = getFluidProperty(libLoc, 'H', 'P', States(5,3)*1e6, 'S', s5_is, Fluid, 1, 1, 'MASS BASE SI');
States(5, 4) = States(4, 4) + (h5_is - States(4, 4)) / eta_C_is;
States(5, 2) = getFluidProperty(libLoc, 'T', 'P', States(5,3)*1e6, 'H', States(5,4), Fluid, 1, 1, 'MASS BASE SI');
States(5, 5) = getFluidProperty(libLoc, 'S', 'P', States(5,3)*1e6, 'H', States(5,4), Fluid, 1, 1, 'MASS BASE SI');

States(6, 2) = 309;  States(6, 3) = 6.85;  States(6, 6) = m_charge;
States(6, 4) = getFluidProperty(libLoc, 'H', 'P', States(6,3)*1e6, 'T', States(6,2), Fluid, 1, 1, 'MASS BASE SI');
States(6, 5) = getFluidProperty(libLoc, 'S', 'P', States(6,3)*1e6, 'T', States(6,2), Fluid, 1, 1, 'MASS BASE SI');

States(7, 2) = T_amb;  States(7, 3) = P_HPT;  States(7, 6) = m_charge;
States(7, 4) = getFluidProperty(libLoc, 'H', 'P', States(7,3)*1e6, 'T', States(7,2), Fluid, 1, 1, 'MASS BASE SI');
States(7, 5) = getFluidProperty(libLoc, 'S', 'P', States(7,3)*1e6, 'T', States(7,2), Fluid, 1, 1, 'MASS BASE SI');

States(8, 2) = 296;  States(8, 3) = 6.65;  States(8, 6) = m_discharge;
States(8, 4) = getFluidProperty(libLoc, 'H', 'P', States(8,3)*1e6, 'T', States(8,2), Fluid, 1, 1, 'MASS BASE SI');
States(8, 5) = getFluidProperty(libLoc, 'S', 'P', States(8,3)*1e6, 'T', States(8,2), Fluid, 1, 1, 'MASS BASE SI');

States(9, 3) = 6.60;  States(9, 6) = m_discharge;
States(9, 4) = States(8, 4);
States(9, 2) = getFluidProperty(libLoc, 'T', 'P', States(9,3)*1e6, 'H', States(9,4), Fluid, 1, 1, 'MASS BASE SI');
States(9, 5) = getFluidProperty(libLoc, 'S', 'P', States(9,3)*1e6, 'H', States(9,4), Fluid, 1, 1, 'MASS BASE SI');

States(10, 2) = T_turb_in;  States(10, 3) = 6.50;  States(10, 6) = m_discharge;
States(10, 4) = getFluidProperty(libLoc, 'H', 'P', States(10,3)*1e6, 'T', States(10,2), Fluid, 1, 1, 'MASS BASE SI');
States(10, 5) = getFluidProperty(libLoc, 'S', 'P', States(10,3)*1e6, 'T', States(10,2), Fluid, 1, 1, 'MASS BASE SI');

States(11, 3) = 0.70;  States(11, 6) = m_discharge;
s11_is = States(10, 5);
h11_is = getFluidProperty(libLoc, 'H', 'P', States(11,3)*1e6, 'S', s11_is, Fluid, 1, 1, 'MASS BASE SI');
States(11, 4) = States(10, 4) - eta_T_is * (States(10, 4) - h11_is);
States(11, 2) = getFluidProperty(libLoc, 'T', 'P', States(11,3)*1e6, 'H', States(11,4), Fluid, 1, 1, 'MASS BASE SI');
States(11, 5) = getFluidProperty(libLoc, 'S', 'P', States(11,3)*1e6, 'H', States(11,4), Fluid, 1, 1, 'MASS BASE SI');

States(12, 2) = T_turb_in;  States(12, 3) = 0.65;  States(12, 6) = m_discharge;
States(12, 4) = getFluidProperty(libLoc, 'H', 'P', States(12,3)*1e6, 'T', States(12,2), Fluid, 1, 1, 'MASS BASE SI');
States(12, 5) = getFluidProperty(libLoc, 'S', 'P', States(12,3)*1e6, 'T', States(12,2), Fluid, 1, 1, 'MASS BASE SI');

States(13, 3) = 0.12;  States(13, 6) = m_discharge;
s13_is = States(12, 5);
h13_is = getFluidProperty(libLoc, 'H', 'P', States(13,3)*1e6, 'S', s13_is, Fluid, 1, 1, 'MASS BASE SI');
States(13, 4) = States(12, 4) - eta_T_is * (States(12, 4) - h13_is);
States(13, 2) = getFluidProperty(libLoc, 'T', 'P', States(13,3)*1e6, 'H', States(13,4), Fluid, 1, 1, 'MASS BASE SI');
States(13, 5) = getFluidProperty(libLoc, 'S', 'P', States(13,3)*1e6, 'H', States(13,4), Fluid, 1, 1, 'MASS BASE SI');

States(14, 2) = 303;  States(14, 3) = P_LPT;  States(14, 6) = m_discharge;
States(14, 4) = getFluidProperty(libLoc, 'H', 'P', States(14,3)*1e6, 'T', States(14,2), Fluid, 1, 1, 'MASS BASE SI');
States(14, 5) = getFluidProperty(libLoc, 'S', 'P', States(14,3)*1e6, 'T', States(14,2), Fluid, 1, 1, 'MASS BASE SI');

States(15, 2) = T_amb;  States(15, 3) = P_LPT;  States(15, 6) = m_discharge;
States(15, 4) = getFluidProperty(libLoc, 'H', 'P', States(15,3)*1e6, 'T', States(15,2), Fluid, 1, 1, 'MASS BASE SI');
States(15, 5) = getFluidProperty(libLoc, 'S', 'P', States(15,3)*1e6, 'T', States(15,2), Fluid, 1, 1, 'MASS BASE SI');

% 临界点
T_crit = 304.1;  P_crit = 7.38;
h_crit = getFluidProperty(libLoc, 'H', 'P', P_crit*1e6, 'T', T_crit, Fluid, 1, 1, 'MASS BASE SI');
s_crit = getFluidProperty(libLoc, 'S', 'P', P_crit*1e6, 'T', T_crit, Fluid, 1, 1, 'MASS BASE SI');

% 单位转换
States(:, 4) = States(:, 4) / 1000;
States(:, 5) = States(:, 5) / 1000;
h_crit = h_crit / 1000;  s_crit = s_crit / 1000;

fprintf('状态点计算完成。\n');

%% 3. 计算定常无量纲参数 (β1, β2, α1, α2)
W_C1_shaft = m_charge * (States(3,4) - States(2,4)) / 1000;
W_C2_shaft = m_charge * (States(5,4) - States(4,4)) / 1000;
W_T1_shaft = m_discharge * (States(10,4) - States(11,4)) / 1000;
W_T2_shaft = m_discharge * (States(12,4) - States(13,4)) / 1000;

W_C_E = (W_C1_shaft + W_C2_shaft) / eta_motor;
W_T_E = (W_T1_shaft + W_T2_shaft) * eta_gen;

Q_IC = m_charge * (States(3,4) - States(4,4) + States(5,4) - States(6,4)) / 1000;
Q_HR = m_discharge * (States(10,4) - States(9,4) + States(12,4) - States(11,4)) / 1000;

beta1 = Q_IC / W_C_E;
beta2 = Q_HR / W_T_E;
alpha1 = m_charge / W_C_E;
alpha2 = m_discharge / W_T_E;
Q_HG_LG_max = beta1 * W_design;

fprintf('β1=%.3f, β2=%.3f, α1=%.3f, α2=%.3f\n', beta1, beta2, alpha1, alpha2);

%% 4. 参数空间采样
dt = 1.0;
W_max = W_design;
Q_max = Q_HG_LG_max;

% SOC 采样范围
SOC_heat_vals = linspace(0, 100, 16)';       % 16 步: 0% ~ 100%
SOC_gas_vals  = linspace(0, 100, 11)';        % 11 步
W_vals        = linspace(0, W_max, 11)';      % 11 步: 0~10 MW
Q_vals        = linspace(0, Q_max, 10)';      % 10 步: 0~Q_max

N_total = length(SOC_heat_vals) * length(SOC_gas_vals) * ...
          length(W_vals) * length(Q_vals) * 2;  % ×2 for charge/discharge
fprintf('总样本数: %d\n', N_total);

%% 5. 批量计算并写 CSV
outFile = '..\data\training_data.csv';
fid = fopen(outFile, 'w');
fprintf(fid, ['mode,SOC_heat_pct,SOC_gas_pct,Q_HTV_MWh,P_HPT_MPa,' ...
    'W_MW,Q_MW,feasible,W_max_feasible,Q_max_feasible,' ...
    'beta1,beta2,alpha1,alpha2,eta_elec_pct,eta_heat_pct\n']);

count = 0;
for s_h = 1:length(SOC_heat_vals)
    SOC_h = SOC_heat_vals(s_h);
    Q_HTV = SOC_h / 100 * Q_HTV_upper;

    for s_g = 1:length(SOC_gas_vals)
        SOC_g = SOC_gas_vals(s_g);
        P_HPT = P_HPT_lower + SOC_g / 100 * (P_HPT_upper - P_HPT_lower);

        % 为每个 SOC 状态计算约束参数
        b_upper = max(0, (Q_HTV - Q_HTV_lower) / dt);

        for mode = 0:1  % 0=充电, 1=放电
            if mode == 0
                slope = beta1;
                W_bound = W_max;
            else
                slope = -beta2;
                W_bound = W_max;
            end

            b_lower = (Q_HTV - Q_HTV_upper) / dt;

            for w = 1:length(W_vals)
                W_val = W_vals(w);
                if W_val > W_bound, continue; end

                for q = 1:length(Q_vals)
                    Q_val = Q_vals(q);

                    % 可行性判断
                    feasible = (Q_val <= slope * W_val + b_upper + 1e-10) && ...
                               (Q_val >= slope * W_val + b_lower - 1e-10) && ...
                               (Q_val >= 0) && (Q_val <= Q_max) && ...
                               (W_val >= 0) && (W_val <= W_bound);

                    % 该 SOC 下的最大可行 W 和 Q
                    Q_max_feas = min(Q_max, max(0, b_upper));  % W=0 时的最大供热
                    if mode == 0
                        W_max_feas = W_bound;
                    else
                        W_max_feas = min(W_bound, max(0, b_upper / beta2));
                    end

                    % 效率 (近似, 基于设计工况)
                    eta_elec = 66.7;
                    eta_heat = 21.4;

                    fprintf(fid, '%d,%.1f,%.1f,%.2f,%.3f,', ...
                        mode, SOC_h, SOC_g, Q_HTV, P_HPT);
                    fprintf(fid, '%.2f,%.2f,%d,%.2f,%.2f,', ...
                        W_val, Q_val, feasible, W_max_feas, Q_max_feas);
                    fprintf(fid, '%.3f,%.3f,%.3f,%.3f,%.1f,%.1f\n', ...
                        beta1, beta2, alpha1, alpha2, eta_elec, eta_heat);

                    count = count + 1;
                end
            end
        end

        % 进度
        if mod(s_h, 4) == 0 && s_g == 1
            fprintf('  SOC_heat=%d%% 完成, 已生成 %d 样本\n', SOC_h, count);
        end
    end
end

fclose(fid);
fprintf('\n数据生成完成! 总计 %d 样本 → %s\n', count, outFile);
