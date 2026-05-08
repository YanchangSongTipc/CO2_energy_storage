% =========================================================================
% CCES-CHP 论文复现计算 (Hao et al., 2024, Energy 291, 130122)
% "Study on the operational feasibility domain of combined heat and power
%  generation system based on compressed carbon dioxide energy storage"
%
% 参考 Cycle.m 中基于 REFPROP 的物性调用模式
% 复现论文中的热力学循环计算、无量纲参数、运行可行域分析及双SOC模型
% =========================================================================

clc; clear; close all;

%% =========================================================================
% 1. 系统边界条件与设计参数 (论文 Table 1)
% =========================================================================

% REFPROP 配置 (与Cycle.m一致)
libLoc = 'D:\Program Files\REFPROP\';
Fluid = 'CO2';

% 等熵效率 (论文 Table 1)
eta_c = 0.85;       % 压气机等熵效率
eta_t = 0.88;       % 透平等熵效率

% 机械效率 (论文 Table 1)
eta_CE_mech = 0.98; % 电动机机械效率
eta_TE_mech = 0.95; % 发电机机械效率

% 质量流量 (kg/s) (论文 Table 2)
m_charge = 26.9;
m_discharge = 40.3;

% 设计功率 (论文 Table 1)
W_design = 10; % MW (充/放电设计功率)

% 运行时间 (论文 Table 2)
t_charge = 7.5;  % h (充电时间)
t_discharge = 5; % h (放电时间)

% 储能容量
E_capacity = 50; % MWh

% 换热器能效 (论文参数: 最小换热温差 5K)
epsilon_IC = 0.90; % 中间冷却器能效 (根据最小温差5K估算)
T_ATV = 298;       % 冷导热油罐温度 (论文 Table 1)
T_HTV = 495;       % 热导热油罐温度 (论文 Table 1)

% 多变指数 (CO2, k≈1.29)
n_poly = 1.30;     % 多变指数 (论文中使用)

% 初始化状态点矩阵: [节点, T(K), P(MPa), h(kJ/kg), s(kJ/(kg*K)), m(kg/s)]
Num_States = 15;
States = zeros(Num_States, 6);
States(:, 1) = 1:Num_States;

fprintf('=========================================================================\n');
fprintf('  CCES-CHP 论文复现计算 (Hao et al., 2024)\n');
fprintf('=========================================================================\n\n');

%% =========================================================================
% 2. 储能/充电过程 (Charging Process) 热力学状态点计算
%    基于 REFPROP 物性调用，模式与 Cycle.m 完全一致
% =========================================================================
fprintf('--- 充电过程状态点计算 ---\n');

% [节点1 & 2]: LPT出口 -> 第一级压缩机C1入口 (环境初始态)
States(1, 2) = 298; States(1, 3) = 0.102; States(1, 6) = m_charge;
States(1, 4) = getFluidProperty(libLoc, 'H', 'P', States(1,3), 'T', States(1,2), Fluid, 1, 1, 'MASS BASE SI');
States(1, 5) = getFluidProperty(libLoc, 'S', 'P', States(1,3), 'T', States(1,2), Fluid, 1, 1, 'MASS BASE SI');
States(2, 2:6) = States(1, 2:6);

fprintf('  节点1: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg, s=%.4f kJ/(kg·K)\n', ...
    States(1,2), States(1,3), States(1,4), States(1,5));

% [节点3]: C1出口 (等熵压缩 + 效率修正)
States(3, 3) = 0.90; States(3, 6) = m_charge;
s3_is = States(2, 5);
h3_is = getFluidProperty(libLoc, 'H', 'P', States(3,3), 'S', s3_is, Fluid, 1, 1, 'MASS BASE SI');
States(3, 4) = States(2, 4) + (h3_is - States(2, 4)) / eta_c;
States(3, 2) = getFluidProperty(libLoc, 'T', 'P', States(3,3), 'H', States(3,4), Fluid, 1, 1, 'MASS BASE SI');
States(3, 5) = getFluidProperty(libLoc, 'S', 'P', States(3,3), 'H', States(3,4), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点3: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(3,2), States(3,3), States(3,4));

% [节点4]: IC1出口 -> C2入口 (等压冷却)
States(4, 2) = 308; States(4, 3) = 0.85; States(4, 6) = m_charge;
States(4, 4) = getFluidProperty(libLoc, 'H', 'P', States(4,3), 'T', States(4,2), Fluid, 1, 1, 'MASS BASE SI');
States(4, 5) = getFluidProperty(libLoc, 'S', 'P', States(4,3), 'T', States(4,2), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点4: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(4,2), States(4,3), States(4,4));

% [节点5]: C2出口 (等熵压缩 + 效率修正)
States(5, 3) = 6.90; States(5, 6) = m_charge;
s5_is = States(4, 5);
h5_is = getFluidProperty(libLoc, 'H', 'P', States(5,3), 'S', s5_is, Fluid, 1, 1, 'MASS BASE SI');
States(5, 4) = States(4, 4) + (h5_is - States(4, 4)) / eta_c;
States(5, 2) = getFluidProperty(libLoc, 'T', 'P', States(5,3), 'H', States(5,4), Fluid, 1, 1, 'MASS BASE SI');
States(5, 5) = getFluidProperty(libLoc, 'S', 'P', States(5,3), 'H', States(5,4), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点5: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(5,2), States(5,3), States(5,4));

% [节点6]: IC2出口 -> LHE入口
States(6, 2) = 309; States(6, 3) = 6.85; States(6, 6) = m_charge;
States(6, 4) = getFluidProperty(libLoc, 'H', 'P', States(6,3), 'T', States(6,2), Fluid, 1, 1, 'MASS BASE SI');
States(6, 5) = getFluidProperty(libLoc, 'S', 'P', States(6,3), 'T', States(6,2), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点6: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(6,2), States(6,3), States(6,4));

% [节点7]: LHE出口 (冷却液化装入HPT)
States(7, 2) = 298; States(7, 3) = 6.80; States(7, 6) = m_charge;
States(7, 4) = getFluidProperty(libLoc, 'H', 'P', States(7,3), 'T', States(7,2), Fluid, 1, 1, 'MASS BASE SI');
States(7, 5) = getFluidProperty(libLoc, 'S', 'P', States(7,3), 'T', States(7,2), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点7: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(7,2), States(7,3), States(7,4));

%% =========================================================================
% 3. 释能/发电过程 (Discharging Process) 热力学状态点计算
% =========================================================================
fprintf('\n--- 发电过程状态点计算 ---\n');

% [节点8]: HPT出口 -> 节流阀 V2
States(8, 2) = 296; States(8, 3) = 6.65; States(8, 6) = m_discharge;
States(8, 4) = getFluidProperty(libLoc, 'H', 'P', States(8,3), 'T', States(8,2), Fluid, 1, 1, 'MASS BASE SI');
States(8, 5) = getFluidProperty(libLoc, 'S', 'P', States(8,3), 'T', States(8,2), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点8: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(8,2), States(8,3), States(8,4));

% [节点9]: 节流阀 V2 出口 (等焓节流 h9 = h8)
States(9, 3) = 6.60; States(9, 6) = m_discharge;
States(9, 4) = States(8, 4);
States(9, 2) = getFluidProperty(libLoc, 'T', 'P', States(9,3), 'H', States(9,4), Fluid, 1, 1, 'MASS BASE SI');
States(9, 5) = getFluidProperty(libLoc, 'S', 'P', States(9,3), 'H', States(9,4), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点9: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(9,2), States(9,3), States(9,4));

% [节点10]: EHE + HR1 加热后 -> T1入口
States(10, 2) = 483; States(10, 3) = 6.50; States(10, 6) = m_discharge;
States(10, 4) = getFluidProperty(libLoc, 'H', 'P', States(10,3), 'T', States(10,2), Fluid, 1, 1, 'MASS BASE SI');
States(10, 5) = getFluidProperty(libLoc, 'S', 'P', States(10,3), 'T', States(10,2), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点10: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(10,2), States(10,3), States(10,4));

% [节点11]: T1 出口 (等熵膨胀 + 效率修正)
States(11, 3) = 0.70; States(11, 6) = m_discharge;
s11_is = States(10, 5);
h11_is = getFluidProperty(libLoc, 'H', 'P', States(11,3), 'S', s11_is, Fluid, 1, 1, 'MASS BASE SI');
States(11, 4) = States(10, 4) - eta_t * (States(10, 4) - h11_is);
States(11, 2) = getFluidProperty(libLoc, 'T', 'P', States(11,3), 'H', States(11,4), Fluid, 1, 1, 'MASS BASE SI');
States(11, 5) = getFluidProperty(libLoc, 'S', 'P', States(11,3), 'H', States(11,4), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点11: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(11,2), States(11,3), States(11,4));

% [节点12]: HR2 加热后 -> T2入口
States(12, 2) = 483; States(12, 3) = 0.65; States(12, 6) = m_discharge;
States(12, 4) = getFluidProperty(libLoc, 'H', 'P', States(12,3), 'T', States(12,2), Fluid, 1, 1, 'MASS BASE SI');
States(12, 5) = getFluidProperty(libLoc, 'S', 'P', States(12,3), 'T', States(12,2), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点12: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(12,2), States(12,3), States(12,4));

% [节点13]: T2 出口 (等熵膨胀 + 效率修正)
States(13, 3) = 0.12; States(13, 6) = m_discharge;
s13_is = States(12, 5);
h13_is = getFluidProperty(libLoc, 'H', 'P', States(13,3), 'S', s13_is, Fluid, 1, 1, 'MASS BASE SI');
States(13, 4) = States(12, 4) - eta_t * (States(12, 4) - h13_is);
States(13, 2) = getFluidProperty(libLoc, 'T', 'P', States(13,3), 'H', States(13,4), Fluid, 1, 1, 'MASS BASE SI');
States(13, 5) = getFluidProperty(libLoc, 'S', 'P', States(13,3), 'H', States(13,4), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点13: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(13,2), States(13,3), States(13,4));

% [节点14]: AE-HE 换热出口 -> Cooler入口
States(14, 2) = 303; States(14, 3) = 0.102; States(14, 6) = m_discharge;
States(14, 4) = getFluidProperty(libLoc, 'H', 'P', States(14,3), 'T', States(14,2), Fluid, 1, 1, 'MASS BASE SI');
States(14, 5) = getFluidProperty(libLoc, 'S', 'P', States(14,3), 'T', States(14,2), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点14: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(14,2), States(14,3), States(14,4));

% [节点15]: Cooler 冷却出口 -> LPT入口
States(15, 2) = 298; States(15, 3) = 0.102; States(15, 6) = m_discharge;
States(15, 4) = getFluidProperty(libLoc, 'H', 'P', States(15,3), 'T', States(15,2), Fluid, 1, 1, 'MASS BASE SI');
States(15, 5) = getFluidProperty(libLoc, 'S', 'P', States(15,3), 'T', States(15,2), Fluid, 1, 1, 'MASS BASE SI');

fprintf('  节点15: T=%.1f K, P=%.3f MPa, h=%.2f kJ/kg\n', States(15,2), States(15,3), States(15,4));

%% =========================================================================
% 4. 输出状态点计算结果表 (对应论文 Appendix B Table 1)
% =========================================================================
fprintf('\n');
fprintf('========================================================================================\n');
fprintf('  状态点计算结果汇总 (对应论文 Appendix B Table 1)\n');
fprintf('========================================================================================\n');
fprintf(' 节点 | 温度 T (K) | 压力 P (MPa) |  焓 h (kJ/kg)  | 熵 s (kJ/kg·K) | 流量 m (kg/s) \n');
fprintf('----------------------------------------------------------------------------------------\n');
for i = 1:Num_States
    fprintf('  %2d  |  %8.2f  |   %8.3f   |   %10.2f   |   %10.4f    |    %6.1f \n', ...
        States(i,1), States(i,2), States(i,3), States(i,4), States(i,5), States(i,6));
end
fprintf('========================================================================================\n\n');

%% =========================================================================
% 5. 压缩机与透平功率计算
% =========================================================================

% 轴功率 (论文 Eqs. 1, 4 中的 WC, WT — 不含机械效率)
W_C1_shaft = m_charge * (States(3,4) - States(2,4)) / 1000; % MW
W_C2_shaft = m_charge * (States(5,4) - States(4,4)) / 1000; % MW
W_T1_shaft = m_discharge * (States(10,4) - States(11,4)) / 1000; % MW
W_T2_shaft = m_discharge * (States(12,4) - States(13,4)) / 1000; % MW

% 电功率 (论文 Eqs. 2, 5 — 计入机械效率)
WC_E = (W_C1_shaft + W_C2_shaft) / eta_CE_mech; % MW
WT_E = (W_T1_shaft + W_T2_shaft) * eta_TE_mech; % MW

fprintf('--- 功率计算结果 ---\n');
fprintf('第一级压气机轴功: %.2f MW\n', W_C1_shaft);
fprintf('第二级压气机轴功: %.2f MW\n', W_C2_shaft);
fprintf('总压缩轴功:       %.2f MW\n', W_C1_shaft + W_C2_shaft);
fprintf('总压缩电功率 WC,E: %.2f MW\n\n', WC_E);

fprintf('第一级透平轴功: %.2f MW\n', W_T1_shaft);
fprintf('第二级透平轴功: %.2f MW\n', W_T2_shaft);
fprintf('总膨胀轴功:     %.2f MW\n', W_T1_shaft + W_T2_shaft);
fprintf('总透平电功率 WT,E: %.2f MW\n\n', WT_E);

%% =========================================================================
% 6. 换热功率计算 (论文 Eqs. 7-10)
% =========================================================================
fprintf('--- 换热功率计算 ---\n');

% 中间冷却器换热功率 IC1 和 IC2 (论文 Eq. 8)
% Q_IC = m_C * (h_Cout_i - h_Cin_i+1) + (h_Cout_NC - h_IC-end)
Q_IC1 = m_charge * (States(3,4) - States(4,4)) / 1000; % MW
Q_IC2 = m_charge * (States(5,4) - States(6,4)) / 1000; % MW
Q_IC_total = Q_IC1 + Q_IC2;

fprintf('IC1 换热功率 Q_IC1: %.2f MW\n', Q_IC1);
fprintf('IC2 换热功率 Q_IC2: %.2f MW\n', Q_IC2);
fprintf('总压缩热存储 Q_IC : %.2f MW\n', Q_IC_total);

% 回热换热器换热功率 HR1 和 HR2 (论文 Eq. 10)
% Q_HR = m_T * [(h_Tin_i+1 - h_Tout_i) + (h_Tin_1 - h_HR-start)]
Q_HR1 = m_discharge * (States(10,4) - States(11,4) + States(12,4) - States(9,4)) / 1000; % MW
% 更准确的计算:
Q_HR1_alt = m_discharge * (States(10,4) - States(9,4)) / 1000; % CO2在HR1中吸收的热量
Q_HR2 = m_discharge * (States(12,4) - States(11,4)) / 1000; % CO2在HR2中吸收的热量
Q_HR_total = Q_HR1_alt + Q_HR2;

fprintf('HR1 换热功率 Q_HR1: %.2f MW\n', Q_HR1_alt);
fprintf('HR2 换热功率 Q_HR2: %.2f MW\n', Q_HR2);
fprintf('总回热功率 Q_HR  : %.2f MW\n', Q_HR_total);

% 膨胀后换热器 AE-HE (论文 Eq. 17 中定义)
Q_AE_HE = m_discharge * (States(13,4) - States(14,4)) / 1000; % MW

% 冷却器 (Cooler)
Q_Cooler = m_discharge * (States(14,4) - States(15,4)) / 1000; % MW

fprintf('AE-HE 换热功率 Q_AE-HE: %.2f MW\n', Q_AE_HE);
fprintf('Cooler 换热功率 Q_Cooler: %.2f MW\n', Q_Cooler);

%% =========================================================================
% 7. 无量纲参数计算 γ1, γ2, α1, α2 (论文 Eqs. 18-21)
% =========================================================================
fprintf('\n--- 无量纲参数计算 (论文 3.1节) ---\n');

% γ1: 压缩过程中间冷却器换热功率与压缩机电功率之比 (Eq. 18)
gamma1 = Q_IC_total / WC_E;
fprintf('γ1 = Q_IC / WC,E = %.4f\n', gamma1);

% γ2: 膨胀过程回热换热器换热功率与透平发电功率之比 (Eq. 19)
gamma2 = Q_HR_total / WT_E;
fprintf('γ2 = Q_HR / WT,E = %.4f\n', gamma2);

% α1: 压缩过程质量流量与压缩机电功率之比 (Eq. 20)
alpha1 = m_charge / WC_E; % kg/(s·MW)
fprintf('α1 = m_C / WC,E = %.4f kg/(s·MW)\n', alpha1);

% α2: 膨胀过程质量流量与透平发电功率之比 (Eq. 21)
alpha2 = m_discharge / WT_E; % kg/(s·MW)
fprintf('α2 = m_T / WT,E = %.4f kg/(s·MW)\n', alpha2);

% 使用解析公式验证 γ1, γ2 (基于温度, 论文 Eqs. 18-19)
% 注意: 论文中温度形式的解析式与焓值形式在热力学上等价
% γ1 解析计算 (Eq. 18 温度形式, 基于cp等价)
T_Cout_1 = States(3,2); T_Cin_1 = States(2,2);
T_Cout_2 = States(5,2); T_Cin_2 = States(4,2);
T_IC_end = States(6,2);
% γ1 = [T_Cout_NC + Σ(T_Cout_i - T_Cin_{i+1})] / [Σ(T_Cout_i - T_Cin_i)]  (简化形式)
gamma1_temp = (T_Cout_1 + T_Cout_2 - T_Cin_2) / (T_Cout_1 - T_Cin_1 + T_Cout_2 - T_Cin_2);
fprintf('γ1 (温度比简化) = %.4f\n', gamma1_temp);

% γ2 解析计算 (Eq. 19 温度形式)
T_Tin_1 = States(10,2); T_Tout_1 = States(11,2);
T_Tin_2 = States(12,2); T_Tout_2 = States(13,2);
T_HR_start = States(9,2);
num_gamma2 = T_Tin_1 + T_Tin_2 - T_Tout_1 - T_HR_start;
den_gamma2 = (T_Tin_1 - T_Tout_1) + (T_Tin_2 - T_Tout_2);
gamma2_temp = num_gamma2 / den_gamma2;
fprintf('γ2 (温度比简化) = %.4f\n', gamma2_temp);

%% =========================================================================
% 8. 供热率 X 与回热率 Y (论文 Eqs. 13-15)
%    注意: X和Y定义基于能量积分(全周期), 不是瞬时功率比
%    Y = ∫Q_HR dt / ∫Q_IC dt, X = 1 - Y
% =========================================================================
fprintf('\n--- 供热率与回热率计算 (论文 2.3节) ---\n');

% 默认工况: 所有HTV热量用于回热, 高温供热为0
Q_HG_HE = 0;     % 高温供热功率 (MW)
t_HG = 0;        % 高温供热时间 (h)

% 全周期能量平衡 (Eq. 12):
%   Q_IC * t_charge = Q_HR * t_discharge + Q_HG-HE * t_HG + Q_LG-HE * t_discharge
E_IC_total = Q_IC_total * t_charge;      % 总压缩热存储 (MWh)
E_HR_total = Q_HR_total * t_discharge;   % 总回热能量 (MWh)

% Y: 回热率 (Eq. 14) — 基于全周期能量积分
Y = E_HR_total / E_IC_total;

% X: 供热率 (Eq. 13) — 基于全周期能量积分
X = 1 - Y;

% 低温供热功率 (从能量平衡推导)
% E_LG = E_IC_total - E_HR_total - Q_HG_HE * t_HG = X * E_IC_total
E_LG_total = X * E_IC_total;              % 低温供热总能量 (MWh)
Q_LG_HE = E_LG_total / t_discharge;       % 低温供热瞬时功率 (MW)

fprintf('压缩热总能量 E_IC = %.2f MWh (%.2f MW × %.1f h)\n', E_IC_total, Q_IC_total, t_charge);
fprintf('回热总能量 E_HR = %.2f MWh (%.2f MW × %.1f h)\n', E_HR_total, Q_HR_total, t_discharge);
fprintf('低温供热能量 E_LG = %.2f MWh\n', E_LG_total);
fprintf('\n');
fprintf('高温供热功率 Q_HG-HE = %.2f MW\n', Q_HG_HE);
fprintf('低温供热功率 Q_LG-HE = %.2f MW\n', Q_LG_HE);
fprintf('回热率 Y = %.4f (%.1f%%)\n', Y, Y*100);
fprintf('供热率 X = %.4f (%.1f%%)\n', X, X*100);
fprintf('验证 X + Y = %.4f (应为 1.0)\n', X + Y);

% 论文 Eq. 30: X 与 γ1, γ2, α1, α2 的关系
% X = 1 - (γ2·α1·η_CE·η_TE) / (γ1·α2)
X_analytic = 1 - (gamma2 * alpha1 * eta_CE_mech * eta_TE_mech) / (gamma1 * alpha2);
fprintf('X (解析验证 Eq.30) = %.4f\n', X_analytic);

%% =========================================================================
% 9. 性能指标计算 (论文 Eqs. 16-17)
% =========================================================================
fprintf('\n--- 性能指标计算 (论文 2.3节) ---\n');

% 电-电转换效率 (Eq. 16)
% η_electricity = ∫W_TCE dt / ∫W_CCE dt
eta_electricity = (WT_E * t_discharge) / (WC_E * t_charge);
fprintf('电-电转换效率 η_electricity = %.4f (%.1f%%)\n', eta_electricity, eta_electricity*100);

% 各供热效率 (Eq. 17)
% 注意: 各供热效率分母均为总充电电能 ∫W_CCE dt
E_input = WC_E * t_charge;  % 总输入电能 (MWh)
eta_heating_HG_HE = (Q_HG_HE * t_HG) / E_input;           % 高温供热
eta_heating_LG_HE = (Q_LG_HE * t_discharge) / E_input;    % 低温供热
eta_heating_AE_HE = (Q_AE_HE * t_discharge) / E_input;    % 膨胀后供热
eta_heating_total = eta_heating_HG_HE + eta_heating_LG_HE + eta_heating_AE_HE;

fprintf('高温供热效率 η_heating,HG-HE = %.4f (%.1f%%)\n', eta_heating_HG_HE, eta_heating_HG_HE*100);
fprintf('低温供热效率 η_heating,LG-HE = %.4f (%.1f%%)\n', eta_heating_LG_HE, eta_heating_LG_HE*100);
fprintf('膨胀后供热效率 η_heating,AE-HE = %.4f (%.1f%%)\n', eta_heating_AE_HE, eta_heating_AE_HE*100);
fprintf('总供热效率 η_heating,total = %.4f (%.1f%%)\n', eta_heating_total, eta_heating_total*100);

% 综合能源利用效率
eta_total = eta_electricity + eta_heating_total;
fprintf('综合能源利用效率 = %.4f (%.1f%%)\n', eta_total, eta_total*100);

%% =========================================================================
% 10. 运行可行域分析 (论文 第3节)
% =========================================================================
fprintf('\n--- 运行可行域分析 (论文 第3节) ---\n');

% 储能系统参数设定
Q_HTV_capacity = E_IC_total;     % HTV总储热容量 = 压缩热总能量 (MWh)
Q_HTV_lower = 0;                  % HTV储热下限 (MWh)
Q_HTV_upper = Q_HTV_capacity;     % HTV储热上限 (MWh)
Q_HG_LG_max = Q_IC_total;         % 最大供热功率 (MW), 不超过压缩热存储功率

% 充/放电功率上限
W_CCE_upper = W_design;  % 充电功率上限 (MW)
W_TCE_upper = W_design;  % 放电功率上限 (MW)

% 调度时间步长
dt = 1;  % 1小时

% 打印可行域参数
fprintf('HTV 储热容量: %.2f MWh\n', Q_HTV_capacity);
fprintf('HTV 储热下限: %.2f MWh\n', Q_HTV_lower);
fprintf('HTV 储热上限: %.2f MWh\n', Q_HTV_upper);
fprintf('最大供热功率: %.2f MW\n', Q_HG_LG_max);
fprintf('充电功率上限: %.2f MW\n', W_CCE_upper);
fprintf('放电功率上限: %.2f MW\n', W_TCE_upper);

%% =========================================================================
% 11. 双SOC模型 (论文 Eqs. 22-23)
%    热存储SOC基于HTV储热量, 气存储SOC基于HPT压力
% =========================================================================
fprintf('\n--- 双SOC模型 ---\n');

% HPT 参数
Rg_CO2 = 0.1889; % CO2 气体常数 (kJ/(kg·K))
T_HPT = 298;     % HPT 温度 (K)
% V_HPT 校准: 使得满充(7.5h×10MW)压力从~0.5MPa升至~6.8MPa
% 基于论文Eq.23的理想气体近似反算有效容积
dp_full = 6.8 - 0.5;  % 满充压差 (MPa)
dm_full = alpha1 * W_design * t_charge * 3600;  % 满充质量 (kg)
V_HPT = Rg_CO2 * T_HPT * dm_full / (dp_full * 1000);  % 有效容积 (m³)

fprintf('HPT 有效容积 (校准): %.0f m³\n', V_HPT);
fprintf('HPT 温度: %.0f K\n', T_HPT);
fprintf('满充质量变化: %.0f kg\n', dm_full);

% 模拟24小时运行
n_hours = 24;
SOC_heat = zeros(1, n_hours+1);  % 热存储SOC (MWh)
SOC_gas = zeros(1, n_hours+1);   % 气存储SOC = pHPT (MPa)
P_charge = zeros(1, n_hours);    % 充电功率 (MW)
P_discharge = zeros(1, n_hours); % 放电功率 (MW)
Q_heat_out = zeros(1, n_hours);  % 供热功率 (MW)

% 初始状态 (早晨开始, 部分储能)
SOC_heat(1) = 0.3 * Q_HTV_capacity;  % 初始30%热存储
SOC_gas(1) = 2.0;                      % 初始HPT压力 (MPa)

% 模拟负荷调度 (基于论文 Fig. 9 模式, 降低功率以适应HPT压力约束)
for t = 1:n_hours
    if t <= 8
        % 充电时段 (低电负荷): 储存低价电/弃风
        P_charge(t) = min(W_CCE_upper, 8 + 2*mod(t,2));
        P_discharge(t) = 0;
        Q_heat_out(t) = 1.5;  % 少量供热
    elseif t <= 11
        % 接近储满: 降低充电功率 (受HPT压力上限约束)
        P_charge(t) = 3;
        P_discharge(t) = 0;
        Q_heat_out(t) = 0.5;
    elseif t <= 15
        % 放电时段 (高电负荷)
        P_charge(t) = 0;
        P_discharge(t) = min(W_TCE_upper, 8 + 2*mod(t,2));
        Q_heat_out(t) = 2.5;
    elseif t <= 19
        % 再充电时段
        P_charge(t) = min(W_CCE_upper, 7);
        P_discharge(t) = 0;
        Q_heat_out(t) = 1.5;
    elseif t <= 21
        % 再放电时段 (晚高峰)
        P_charge(t) = 0;
        P_discharge(t) = min(W_TCE_upper, 9);
        Q_heat_out(t) = 3.0;
    else
        % 夜间充电
        P_charge(t) = min(W_CCE_upper, 6);
        P_discharge(t) = 0;
        Q_heat_out(t) = 1.0;
    end

    % 检查HPT压力约束: 如果压力接近上限, 限制充电; 接近下限, 限制放电
    if SOC_gas(t) > 6.0 && P_charge(t) > 0
        P_charge(t) = min(P_charge(t), 3);  % 降低充电功率
    end
    if SOC_gas(t) < 1.5 && P_discharge(t) > 0
        P_discharge(t) = min(P_discharge(t), 3);  % 降低放电功率
    end

    % 热存储SOC更新 (Eq. 22)
    if P_charge(t) > 0
        % 充电-供热工况: 蓄热
        SOC_heat(t+1) = SOC_heat(t) + (gamma1 * P_charge(t) - Q_heat_out(t)) * dt;
    else
        % 放电-供热工况: 放热
        SOC_heat(t+1) = SOC_heat(t) - (gamma2 * P_discharge(t) + Q_heat_out(t)) * dt;
    end

    % 热存储约束
    SOC_heat(t+1) = max(Q_HTV_lower, min(Q_HTV_upper, SOC_heat(t+1)));

    % 气存储SOC更新 (Eq. 23)
    if P_charge(t) > 0
        SOC_gas(t+1) = SOC_gas(t) + (Rg_CO2 * T_HPT / V_HPT) * alpha1 * P_charge(t) * dt * 3600 / 1000;
    else
        SOC_gas(t+1) = SOC_gas(t) - (Rg_CO2 * T_HPT / V_HPT) * alpha2 * P_discharge(t) * dt * 3600 / 1000;
    end

    % HPT压力约束
    SOC_gas(t+1) = max(0.5, min(6.8, SOC_gas(t+1)));
end

%% =========================================================================
% 12. 运行可行域坐标图绘制 (论文 Figs. 3-4, Eqs. 28-29)
% =========================================================================

% 选取两个典型时刻绘制可行域
% 时刻 t: Q_HTV(t-1) 取不同值展示可行域变化

% 图1: 充电-供热工况可行域 (论文 Fig. 3, Eq. 28)
Q_HTV_prev_charge = [0.3, 0.5, 0.7] * Q_HTV_capacity;  % 不同初始储热状态

figure('Name', 'Operational Feasibility Domain - Charging-Heating', ...
       'Color', 'w', 'Position', [100, 100, 800, 650]);
hold on; grid on; box on;

colors_charge = lines(length(Q_HTV_prev_charge));

for idx = 1:length(Q_HTV_prev_charge)
    Q_prev = Q_HTV_prev_charge(idx);

    % 构建可行域边界 (Eq. 28)
    % x轴: 充电功率 WC,E, y轴: 供热功率 Q_HG+Q_LG

    % 节点A: (0, (Q_HTV(t-1) - Q_lower)/dt)
    nodeA_x = 0;
    nodeA_y = max(0, (Q_prev - Q_HTV_lower) / dt);

    % 节点B: x由y上限确定
    nodeB_y = min(Q_HG_LG_max, nodeA_y + gamma1 * W_CCE_upper);
    nodeB_x = (nodeB_y - nodeA_y) / gamma1;

    % 节点C: (W_upper, y_C)
    nodeC_x = W_CCE_upper;
    nodeC_y = min(Q_HG_LG_max, nodeA_y + gamma1 * W_CCE_upper);

    % 节点D: x由HTV上限确定
    nodeD_y = max(0, (Q_prev - Q_HTV_upper) / dt + gamma1 * W_CCE_upper);
    nodeD_x = W_CCE_upper;

    % 节点E: (0, y_E) 对应HTV上限约束
    nodeE_y = max(0, (Q_prev - Q_HTV_upper) / dt);
    nodeE_x = 0;

    % 构建多边形顶点 (按逆时针)
    poly_x = [nodeA_x, nodeB_x, nodeC_x, nodeD_x, nodeE_x, nodeA_x];
    poly_y = [nodeA_y, nodeB_y, nodeC_y, nodeD_y, nodeE_y, nodeA_y];

    % 绘制可行域
    fill(poly_x, poly_y, colors_charge(idx,:), 'FaceAlpha', 0.15, ...
         'EdgeColor', colors_charge(idx,:), 'LineWidth', 2);

    % 标注节点
    plot(nodeA_x, nodeA_y, 'o', 'Color', colors_charge(idx,:), ...
         'MarkerSize', 8, 'MarkerFaceColor', colors_charge(idx,:));
    plot(nodeB_x, nodeB_y, 'o', 'Color', colors_charge(idx,:), ...
         'MarkerSize', 8, 'MarkerFaceColor', colors_charge(idx,:));
    plot(nodeC_x, nodeC_y, 'o', 'Color', colors_charge(idx,:), ...
         'MarkerSize', 8, 'MarkerFaceColor', colors_charge(idx,:));
    plot(nodeD_x, nodeD_y, 'o', 'Color', colors_charge(idx,:), ...
         'MarkerSize', 8, 'MarkerFaceColor', colors_charge(idx,:));
    plot(nodeE_x, nodeE_y, 'o', 'Color', colors_charge(idx,:), ...
         'MarkerSize', 8, 'MarkerFaceColor', colors_charge(idx,:));
end

xlabel('Charging Power W_{C,E} (MW)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Heating Power Q_{HG-HE} + Q_{LG-HE} (MW)', 'FontSize', 13, 'FontWeight', 'bold');
title('Operational Feasibility Domain — Charging-Heating Condition (论文 Fig.3)', ...
      'FontSize', 14, 'FontWeight', 'bold');
legend(arrayfun(@(x) sprintf('Q_{HTV}(t-1)=%.0f MWh', x), Q_HTV_prev_charge, ...
                'UniformOutput', false), ...
       'Location', 'best', 'FontSize', 11);
xlim([0, W_CCE_upper * 1.15]);
ylim([0, Q_HG_LG_max * 1.15]);
set(gca, 'FontSize', 12, 'LineWidth', 1.2);

% 在图上标出节点字母
text(nodeA_x + 0.3, nodeA_y + 0.3, 'A', 'FontSize', 11, 'FontWeight', 'bold');
text(nodeB_x + 0.3, nodeB_y + 0.3, 'B', 'FontSize', 11, 'FontWeight', 'bold');
text(nodeC_x - 0.8, nodeC_y + 0.3, 'C', 'FontSize', 11, 'FontWeight', 'bold');
text(nodeD_x - 0.8, nodeD_y + 0.3, 'D', 'FontSize', 11, 'FontWeight', 'bold');
text(nodeE_x + 0.3, nodeE_y + 0.3, 'E', 'FontSize', 11, 'FontWeight', 'bold');

%% 图2: 放电-供热工况可行域 (论文 Fig. 4, Eq. 29)
Q_HTV_prev_discharge = [0.4, 0.6, 0.8] * Q_HTV_capacity;

figure('Name', 'Operational Feasibility Domain - Discharging-Heating', ...
       'Color', 'w', 'Position', [100, 100, 800, 650]);
hold on; grid on; box on;

colors_discharge = lines(length(Q_HTV_prev_discharge));

for idx = 1:length(Q_HTV_prev_discharge)
    Q_prev = Q_HTV_prev_discharge(idx);

    % 构建可行域边界 (Eq. 29)
    % x轴: 放电功率 WT,E, y轴: 供热功率 Q_HG+Q_LG

    % 节点A: (0, Q_HG_LG_max)
    nodeA_x = 0;
    nodeA_y = Q_HG_LG_max;

    % 节点B: (x_B, Q_HG_LG_max)
    nodeB_y = Q_HG_LG_max;
    nodeB_x = (Q_prev - Q_HTV_lower + dt * Q_HG_LG_max) / (dt * gamma2);
    nodeB_x = min(nodeB_x, W_TCE_upper);

    % 节点C: (W_upper, y_C) 对应HTV上限约束
    nodeC_x = W_TCE_upper;
    nodeC_y = max(0, (Q_prev - Q_HTV_upper) / dt + gamma2 * W_TCE_upper);

    % 节点D: (W_upper, 0)
    nodeD_x = W_TCE_upper;
    nodeD_y = 0;

    % 构建多边形
    poly_x = [nodeA_x, nodeB_x, nodeC_x, nodeD_x, nodeA_x];
    poly_y = [nodeA_y, nodeB_y, nodeC_y, nodeD_y, nodeA_y];

    % 确保x坐标非递减
    [poly_x, sort_idx] = sort(poly_x);
    poly_y = poly_y(sort_idx);
    % 闭合多边形
    poly_x = [poly_x, poly_x(1)];
    poly_y = [poly_y, poly_y(1)];

    fill(poly_x, poly_y, colors_discharge(idx,:), 'FaceAlpha', 0.15, ...
         'EdgeColor', colors_discharge(idx,:), 'LineWidth', 2);
end

xlabel('Discharging Power W_{T,E} (MW)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Heating Power Q_{HG-HE} + Q_{LG-HE} (MW)', 'FontSize', 13, 'FontWeight', 'bold');
title('Operational Feasibility Domain — Discharging-Heating Condition (论文 Fig.4)', ...
      'FontSize', 14, 'FontWeight', 'bold');
legend(arrayfun(@(x) sprintf('Q_{HTV}(t-1)=%.0f MWh', x), Q_HTV_prev_discharge, ...
                'UniformOutput', false), ...
       'Location', 'best', 'FontSize', 11);
xlim([0, W_TCE_upper * 1.15]);
ylim([0, Q_HG_LG_max * 1.15]);
set(gca, 'FontSize', 12, 'LineWidth', 1.2);

%% =========================================================================
% 13. 双SOC演化曲线 (论文 Fig. 2 框架)
% =========================================================================
time_axis = 0:n_hours;

figure('Name', 'Dual SOC Evolution', 'Color', 'w', ...
       'Position', [100, 100, 1000, 500]);

% 子图1: 热存储SOC
subplot(1,2,1);
hold on; grid on; box on;

yyaxis left;
fill([time_axis, fliplr(time_axis)], ...
     [zeros(1, n_hours+1), fliplr(SOC_heat)], ...
     [0.8 0.2 0.2], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
plot(time_axis, SOC_heat, 'r-', 'LineWidth', 2.5);
yline(Q_HTV_upper, 'r--', 'Q^{upper}_{HTV}', 'LineWidth', 1.5, 'LabelOrientation', 'horizontal');
yline(Q_HTV_lower, 'r:', 'Q^{lower}_{HTV}', 'LineWidth', 1.5, 'LabelOrientation', 'horizontal');
ylabel('Heat Storage Q_{HTV} (MWh)', 'FontSize', 12, 'FontWeight', 'bold');

yyaxis right;
bar(1:n_hours, P_charge, 'FaceColor', [0.2 0.4 0.8], 'FaceAlpha', 0.5);
bar(1:n_hours, -P_discharge, 'FaceColor', [0.8 0.4 0.2], 'FaceAlpha', 0.5);
ylabel('Power (MW)', 'FontSize', 12, 'FontWeight', 'bold');

xlabel('Time (h)', 'FontSize', 12, 'FontWeight', 'bold');
title('Heat Storage SOC & Charge/Discharge Power', 'FontSize', 13, 'FontWeight', 'bold');
xlim([0, n_hours]);
set(gca, 'FontSize', 11);

% 子图2: 气存储SOC
subplot(1,2,2);
hold on; grid on; box on;

yyaxis left;
fill([time_axis, fliplr(time_axis)], ...
     [zeros(1, n_hours+1), fliplr(SOC_gas)], ...
     [0.2 0.2 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
plot(time_axis, SOC_gas, 'b-', 'LineWidth', 2.5);
yline(6.8, 'b--', 'p^{max}_{HPT}=6.8 MPa', 'LineWidth', 1.5, 'LabelOrientation', 'horizontal');
yline(0.5, 'b:', 'p^{min}_{HPT}=0.5 MPa', 'LineWidth', 1.5, 'LabelOrientation', 'horizontal');
ylabel('HPT Pressure p_{HPT} (MPa)', 'FontSize', 12, 'FontWeight', 'bold');

yyaxis right;
bar(1:n_hours, Q_heat_out, 'FaceColor', [0.8 0.2 0.2], 'FaceAlpha', 0.5);
ylabel('Heating Power (MW)', 'FontSize', 12, 'FontWeight', 'bold');

xlabel('Time (h)', 'FontSize', 12, 'FontWeight', 'bold');
title('Gas Storage SOC & Heating Power', 'FontSize', 13, 'FontWeight', 'bold');
xlim([0, n_hours]);
set(gca, 'FontSize', 11);

sgtitle('CCES-CHP Dual SOC Model Evolution (论文 Eqs.22-23)', ...
        'FontSize', 15, 'FontWeight', 'bold');

%% =========================================================================
% 14. T-P 循环状态图 (与 Cycle.m 一致, 加上运行可行域参考)
% =========================================================================
figure('Name', 'CCES-CHP T-P Diagram with Feasibility Domain Reference', ...
       'Color', 'w', 'Position', [150, 150, 1200, 550]);

% 左侧: T-P 图
subplot(1,2,1);
hold on; grid on; grid minor;

T_charge = States(1:7, 2);
P_charge = States(1:7, 3);
T_discharge = States(8:15, 2);
P_discharge = States(8:15, 3);

% 绘制充电过程 (红线)
p1 = plot(T_charge, P_charge, '-ro', 'LineWidth', 2.5, 'MarkerSize', 9, ...
          'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r');

% 绘制放电过程 (蓝虚线)
p2 = plot(T_discharge, P_discharge, '--bs', 'LineWidth', 2.5, 'MarkerSize', 9, ...
          'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'b');

% CO2 临界点
T_crit = 304.1; P_crit = 7.38;
p3 = plot(T_crit, P_crit, 'p', 'MarkerSize', 16, ...
          'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');

% 节点标注
labels_charge = {'1', '2', '3', '4', '5', '6', '7'};
for i = 1:length(T_charge)
    if i == 1
        text(T_charge(i) - 15, P_charge(i) * 1.15, '1,2', 'FontSize', 10, ...
             'FontWeight', 'bold', 'Color', [0.7 0 0]);
    elseif i > 2
        text(T_charge(i) + 4, P_charge(i) * 1.15, labels_charge{i}, 'FontSize', 10, ...
             'FontWeight', 'bold', 'Color', [0.7 0 0]);
    end
end

labels_discharge = {'8', '9', '10', '11', '12', '13', '14', '15'};
for i = 1:length(T_discharge)
    if i == 7 || i == 8
        text(T_discharge(i) + 4, P_discharge(i) * 0.75, labels_discharge{i}, ...
             'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0 0.7]);
    else
        text(T_discharge(i) + 4, P_discharge(i) * 0.85, labels_discharge{i}, ...
             'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0 0.7]);
    end
end

text(T_crit - 45, P_crit * 1.3, 'Critical Point', 'FontSize', 11, ...
     'FontWeight', 'bold', 'Color', [0 0.6 0]);

set(gca, 'YScale', 'log');
yticks([0.1, 0.5, 1, 5, 10]);
yticklabels({'0.1', '0.5', '1.0', '5.0', '10.0'});
xlim([280, 520]);
ylim([0.08, 12]);

title('CCES-CHP Thermodynamic Cycle (T-P Diagram)', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Temperature T (K)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Pressure P (MPa)', 'FontSize', 13, 'FontWeight', 'bold');
legend([p1, p2, p3], {'Charging (Compression/Liquefaction)', ...
                      'Discharging (Expansion/Generation)', ...
                      'CO_2 Critical Point'}, ...
       'Location', 'southeast', 'FontSize', 10, 'Box', 'on');
set(gca, 'FontSize', 11, 'LineWidth', 1.2);

% 右侧: 关键参数汇总显示
subplot(1,2,2);
axis off;
text_str = {
    '\bf\fontsize{13} CCES-CHP 论文复现结果汇总';
    '';
    '\fontsize{11} \bf 一、状态点参数 (15节点)';
    '  充电过程: 节点1-7, 放电过程: 节点8-15';
    '  详见控制台输出表格';
    '';
    '\fontsize{11} \bf 二、无量纲参数';
    sprintf('  γ_1 = Q_{IC}/W_{C,E} = %.2f', gamma1);
    sprintf('  γ_2 = Q_{HR}/W_{T,E} = %.2f', gamma2);
    sprintf('  α_1 = m_C/W_{C,E} = %.2f kg/(s·MW)', alpha1);
    sprintf('  α_2 = m_T/W_{T,E} = %.2f kg/(s·MW)', alpha2);
    '';
    '\fontsize{11} \bf 三、功率与换热';
    sprintf('  压缩电功率 W_{C,E} = %.2f MW', WC_E);
    sprintf('  透平电功率 W_{T,E} = %.2f MW', WT_E);
    sprintf('  压缩热 Q_{IC,total} = %.2f MW', Q_IC_total);
    sprintf('  回热 Q_{HR,total} = %.2f MW', Q_HR_total);
    sprintf('  高温供热 Q_{HG-HE} = %.2f MW', Q_HG_HE);
    sprintf('  低温供热 Q_{LG-HE} = %.2f MW', Q_LG_HE);
    sprintf('  膨胀后供热 Q_{AE-HE} = %.2f MW', Q_AE_HE);
    '';
    '\fontsize{11} \bf 四、性能指标';
    sprintf('  电-电转换效率 η_{elec} = %.1f%%', eta_electricity*100);
    sprintf('  总供热效率 η_{heat,total} = %.1f%%', eta_heating_total*100);
    sprintf('  综合能效 = %.1f%%', eta_total*100);
    sprintf('  回热率 Y = %.1f%%', Y*100);
    sprintf('  供热率 X = %.1f%%', X*100);
    '';
    '\fontsize{11} \bf 五、运行可行域 (见图1, 2)';
    '  充电-供热可行域: 论文Eq.28, Fig.3';
    '  放电-供热可行域: 论文Eq.29, Fig.4';
    '';
    '\fontsize{11} \bf 六、双SOC模型 (见图3)';
    '  热存储SOC + 气存储SOC演化';
};

for i = 1:length(text_str)
    text(0, 1 - i*0.032, text_str{i}, 'Units', 'normalized', ...
         'FontSize', 10, 'VerticalAlignment', 'top', 'Interpreter', 'tex');
end

%% =========================================================================
% 15. 负荷调度与实际运行功率曲线 (论文 Fig. 9 风格)
% =========================================================================
figure('Name', 'Dispatch and Actual Operation', 'Color', 'w', ...
       'Position', [150, 150, 1000, 600]);

% 子图1: 电功率调度与响应
subplot(2,1,1);
hold on; grid on; box on;

% 模拟负荷曲线 (基于论文 Fig. 8-9)
elec_load = [18, 15, 12, 10, 12, 15, 20, 25, 28, 30, 32, 35, ...
             38, 40, 38, 35, 30, 28, 35, 40, 42, 38, 30, 22];
wind_power = [14, 12, 10, 8, 6, 8, 10, 12, 10, 8, 6, 8, ...
              10, 12, 14, 12, 10, 8, 15, 18, 16, 12, 10, 14];
% 净负荷 (正=需充电/储能, 负=需放电/释能)
P_dispatch = wind_power - elec_load;

% CCES-CHP实际响应
P_CCES_actual = zeros(1, 24);
for i = 1:24
    if P_dispatch(i) > 0
        % 充电: 受上限约束
        P_CCES_actual(i) = min(P_dispatch(i), W_CCE_upper);
    else
        % 放电
        P_CCES_actual(i) = max(P_dispatch(i), -W_TCE_upper);
    end
end

% 绘制
t = 1:24;
bar(t, P_dispatch, 'FaceColor', [0.6 0.6 0.6], 'FaceAlpha', 0.5, ...
    'DisplayName', 'Power Dispatch');
plot(t, P_CCES_actual, 'b-o', 'LineWidth', 2.5, 'MarkerSize', 7, ...
     'MarkerFaceColor', 'b', 'DisplayName', 'CCES-CHP Actual');
yline(W_CCE_upper, 'r--', 'W^{upper}_{C,E}', 'LineWidth', 1.5, ...
      'DisplayName', 'Charge Limit');
yline(-W_TCE_upper, 'r--', '-W^{upper}_{T,E}', 'LineWidth', 1.5, ...
      'DisplayName', 'Discharge Limit');
yline(0, 'k-', 'LineWidth', 1);

xlabel('Time (h)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Electric Power (MW)', 'FontSize', 12, 'FontWeight', 'bold');
title('CCES-CHP Electric Power Dispatch and Actual Response (论文 Fig.9)', ...
      'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9);
xlim([0.5, 24.5]);
set(gca, 'FontSize', 11);

% 子图2: 热功率调度与响应
subplot(2,1,2);
hold on; grid on; box on;

heat_load = [30, 25, 20, 18, 15, 18, 22, 25, 28, 30, 32, 35, ...
             38, 40, 42, 38, 35, 30, 38, 42, 40, 38, 32, 28];
C_CHP_heat = min(heat_load, 30);  % C-CHP最大供热30MW
Q_heat_dispatch = heat_load - C_CHP_heat;  % CCES-CHP需补充的热量

bar(t, Q_heat_dispatch, 'FaceColor', [0.8 0.4 0.2], 'FaceAlpha', 0.5, ...
    'DisplayName', 'Heat Dispatch');
plot(t, Q_heat_out, 'r-o', 'LineWidth', 2.5, 'MarkerSize', 7, ...
     'MarkerFaceColor', 'r', 'DisplayName', 'CCES-CHP Actual Heating');

xlabel('Time (h)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Heat Power (MW)', 'FontSize', 12, 'FontWeight', 'bold');
title('CCES-CHP Heat Power Dispatch and Actual Response', ...
      'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9);
xlim([0.5, 24.5]);
set(gca, 'FontSize', 11);

sgtitle('CCES-CHP 24-Hour Operation Simulation', 'FontSize', 15, 'FontWeight', 'bold');

%% =========================================================================
% 16. 结果一致性校验 (与论文 Table 2 对比)
% =========================================================================
fprintf('\n=======================================================================\n');
fprintf('  结果一致性校验 (与论文 Table 2 对比)\n');
fprintf('=======================================================================\n');
fprintf('  %-30s | %12s | %12s | %10s\n', '参数', '本文计算值', '论文Table 2', '偏差');
fprintf('  -------------------------------------------------------------------\n');

% 对比数据 (论文 Table 2 数值)
paper_ref = struct(...
    'WT_E', 10, ...
    'WC_E', 10, ...
    'gamma1', 1.16, ...
    'gamma2', 1.59, ...
    'alpha1', 2.69, ...
    'alpha2', 4.03, ...
    'QIC1', 4.86, ...
    'QIC2', 6.78, ...
    'QHR1', 9.47, ...
    'QHR2', 6.41, ...
    'QHG_HE', 0, ...
    'QLG_HE', 1.37, ...
    'QAE_HE', 1.85, ...
    'eta_elec', 66.7, ...
    'eta_heat_total', 21.4, ...
    'X', 9.0, ...
    'Y', 91.0);

calc_ref = struct(...
    'WT_E', WT_E, ...
    'WC_E', WC_E, ...
    'gamma1', gamma1, ...
    'gamma2', gamma2, ...
    'alpha1', alpha1, ...
    'alpha2', alpha2, ...
    'QIC1', Q_IC1, ...
    'QIC2', Q_IC2, ...
    'QHR1', Q_HR1_alt, ...
    'QHR2', Q_HR2, ...
    'QHG_HE', Q_HG_HE, ...
    'QLG_HE', Q_LG_HE, ...
    'QAE_HE', Q_AE_HE, ...
    'eta_elec', eta_electricity*100, ...
    'eta_heat_total', eta_heating_total*100, ...
    'X', X*100, ...
    'Y', Y*100);

fields = fieldnames(paper_ref);
for i = 1:length(fields)
    f = fields{i};
    calc_val = calc_ref.(f);
    paper_val = paper_ref.(f);
    if paper_val ~= 0
        deviation = abs(calc_val - paper_val) / abs(paper_val) * 100;
    else
        deviation = abs(calc_val - paper_val);
    end
    fprintf('  %-30s | %12.2f | %12.2f | %8.2f%%\n', f, calc_val, paper_val, deviation);
end
fprintf('=======================================================================\n\n');

fprintf('复现计算完成! 所有图表已生成。\n');
