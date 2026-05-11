% =========================================================================
% CCES-CHP 运行可行域分析程序
% 基于论文: "Study on the operational feasibility domain of combined
% heat and power generation system based on compressed carbon dioxide
% energy storage" - Energy 291 (2024) 130122
%
% 物性调用方法参考 cycle.m 中基于 REFPROP 的 getFluidProperty 语法
% =========================================================================

clc; clear; close all;

% 输出目录（保存所有图像）
outDir = fullfile(fileparts(mfilename('fullpath')), 'output_figures');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

% 静默运行: 图像直接保存到文件, 不弹出窗口
set(groot, 'DefaultFigureVisible', 'off');

% 学术期刊图形字体设置
% 不设置DefaultTextFontName和固定FontName,避免中文Windows系统MATLAB
% 渲染数学符号(β,α,η,下标)时出现方框。字体继承MATLAB默认(Helvetica/Arial),
% 此字体系列被国际学术期刊(Elsevier,Springer等)广泛接受
set(groot, 'DefaultAxesFontSize', 10);
set(groot, 'DefaultLegendFontSize', 8);
set(groot, 'DefaultLineLineWidth', 1.0);

% 统一样式参数模板(供各图使用)
LEGEND_FONT = {'FontSize', 8};
LABEL_FONT = {'FontSize', 10};
TITLE_FONT = {'FontSize', 11, 'FontWeight', 'bold'};
TEXT_FONT  = {'FontSize', 8};

% 学术期刊标准: 坐标轴标签不粗体, 仅标题用粗体
% 坐标轴字体: 10pt, 图例: 8pt, 标题: 11pt bold
% 字体: MATLAB默认(Helvetica) — 被Elsevier/Springer/ASME等期刊接受

%% ========================================================================
% 1. 系统边界条件与设计参数 (Table 1)
% =========================================================================
libLoc = 'D:\Program Files\REFPROP\'; % 请根据您电脑上的实际安装路径修改
Fluid = 'CO2';

% --- 环境与设计参数 ---
T_amb = 298;            % 环境温度 [K]
P_amb = 0.101;          % 环境压力 [MPa]
W_design = 10;          % 设计充/放电功率 [MW]
t_discharge_design = 5; % 设计放电时长 [h]

% --- 压力参数 ---
P_LPT = 0.102;          % LPT 压力 [MPa]
P_HPT = 6.80;           % HPT 压力 [MPa]

% --- 温度参数 ---
T_comp_in = 308;        % 各级压气机入口温度 [K]
T_turb_in = 483;        % 各级透平入口温度 [K]
T_cooler_out = 298;     % Cooler 出口温度 [K]
T_ATV = 298;            % 冷导热油罐温度 [K]
T_HTV = 495;            % 高温导热油罐温度 [K]
dT_min = 5;             % 换热器最小温差 [K]

% --- 效率参数 ---
eta_C_is = 0.85;        % 压气机等熵效率
eta_T_is = 0.88;        % 透平等熵效率
eta_motor = 0.98;       % 电机机械效率
eta_gen = 0.95;         % 发电机机械效率
n_poly = 1.3;           % 多变量指数 (CO2)
Rg = 0.1889;            % CO2 理想气体常数 [kJ/(kg·K)]

% --- 流量参数 (初始值来自 cycle.m 计算结果) ---
m_charge = 26.9;        % 充电过程质量流量 [kg/s]
m_discharge = 40.3;     % 放电过程质量流量 [kg/s]

% --- HPT 与 HTV 容量参数 ---
V_HPT = 500;            % HPT 容积 [m3] (假设值)
T_HPT = 298;            % HPT 温度 [K]
Q_HTV_upper = 150;      % HTV 储热上限 [MWh_th] (基于 50MWh 容量假设)
Q_HTV_lower = 0;        % HTV 储热下限 [MWh_th]
P_HPT_upper = 6.80;     % HPT 压力上限 [MPa]
P_HPT_lower = 0.12;     % HPT 压力下限 [MPa]

fprintf('====================================================================\n');
fprintf('    CCES-CHP 运行可行域分析程序 (基于 REFPROP 物性)\n');
fprintf('    参考: Energy 291 (2024) 130122\n');
fprintf('====================================================================\n\n');

%% ========================================================================
% 2. 热力学状态点计算 (15节点，参考 cycle.m 与论文 Appendix B)
% =========================================================================
fprintf('--- 正在计算 15 个热力学状态点 ---\n');
% 初始化状态点矩阵: [节点, T(K), P(MPa), h(kJ/kg), s(kJ/(kg*K)), m(kg/s)]
Num_States = 15;
States = zeros(Num_States, 6);
States(:, 1) = 1:Num_States;

% [节点 1 & 2]: LPT出口 -> C1入口 (环境初始态)
States(1, 2) = T_amb;  States(1, 3) = P_LPT;  States(1, 6) = m_charge;
States(1, 4) = getFluidProperty(libLoc, 'H', 'P', States(1,3)*1e6, 'T', States(1,2), Fluid, 1, 1, 'MASS BASE SI');
States(1, 5) = getFluidProperty(libLoc, 'S', 'P', States(1,3)*1e6, 'T', States(1,2), Fluid, 1, 1, 'MASS BASE SI');
States(2, 2:6) = States(1, 2:6);

% [节点 3]: C1出口 (等熵压缩 + 效率修正)
States(3, 3) = 0.90;  States(3, 6) = m_charge;
s3_is = States(2, 5);
h3_is = getFluidProperty(libLoc, 'H', 'P', States(3,3)*1e6, 'S', s3_is, Fluid, 1, 1, 'MASS BASE SI');
States(3, 4) = States(2, 4) + (h3_is - States(2, 4)) / eta_C_is;
States(3, 2) = getFluidProperty(libLoc, 'T', 'P', States(3,3)*1e6, 'H', States(3,4), Fluid, 1, 1, 'MASS BASE SI');
States(3, 5) = getFluidProperty(libLoc, 'S', 'P', States(3,3)*1e6, 'H', States(3,4), Fluid, 1, 1, 'MASS BASE SI');

% [节点 4]: IC1出口 -> C2入口
States(4, 2) = T_comp_in;  States(4, 3) = 0.85;  States(4, 6) = m_charge;
States(4, 4) = getFluidProperty(libLoc, 'H', 'P', States(4,3)*1e6, 'T', States(4,2), Fluid, 1, 1, 'MASS BASE SI');
States(4, 5) = getFluidProperty(libLoc, 'S', 'P', States(4,3)*1e6, 'T', States(4,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 5]: C2出口 (等熵压缩 + 效率修正)
States(5, 3) = 6.90;  States(5, 6) = m_charge;
s5_is = States(4, 5);
h5_is = getFluidProperty(libLoc, 'H', 'P', States(5,3)*1e6, 'S', s5_is, Fluid, 1, 1, 'MASS BASE SI');
States(5, 4) = States(4, 4) + (h5_is - States(4, 4)) / eta_C_is;
States(5, 2) = getFluidProperty(libLoc, 'T', 'P', States(5,3)*1e6, 'H', States(5,4), Fluid, 1, 1, 'MASS BASE SI');
States(5, 5) = getFluidProperty(libLoc, 'S', 'P', States(5,3)*1e6, 'H', States(5,4), Fluid, 1, 1, 'MASS BASE SI');

% [节点 6]: IC2出口 -> LHE入口
States(6, 2) = 309;  States(6, 3) = 6.85;  States(6, 6) = m_charge;
States(6, 4) = getFluidProperty(libLoc, 'H', 'P', States(6,3)*1e6, 'T', States(6,2), Fluid, 1, 1, 'MASS BASE SI');
States(6, 5) = getFluidProperty(libLoc, 'S', 'P', States(6,3)*1e6, 'T', States(6,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 7]: LHE出口 (冷却液化装入HPT)
States(7, 2) = T_amb;  States(7, 3) = P_HPT;  States(7, 6) = m_charge;
States(7, 4) = getFluidProperty(libLoc, 'H', 'P', States(7,3)*1e6, 'T', States(7,2), Fluid, 1, 1, 'MASS BASE SI');
States(7, 5) = getFluidProperty(libLoc, 'S', 'P', States(7,3)*1e6, 'T', States(7,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 8]: HPT出口
States(8, 2) = 296;  States(8, 3) = 6.65;  States(8, 6) = m_discharge;
States(8, 4) = getFluidProperty(libLoc, 'H', 'P', States(8,3)*1e6, 'T', States(8,2), Fluid, 1, 1, 'MASS BASE SI');
States(8, 5) = getFluidProperty(libLoc, 'S', 'P', States(8,3)*1e6, 'T', States(8,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 9]: 节流阀 V2 出口 (等焓节流 h9 = h8)
States(9, 3) = 6.60;  States(9, 6) = m_discharge;
States(9, 4) = States(8, 4);
States(9, 2) = getFluidProperty(libLoc, 'T', 'P', States(9,3)*1e6, 'H', States(9,4), Fluid, 1, 1, 'MASS BASE SI');
States(9, 5) = getFluidProperty(libLoc, 'S', 'P', States(9,3)*1e6, 'H', States(9,4), Fluid, 1, 1, 'MASS BASE SI');

% [节点 10]: EHE + HR1 加热后 -> T1入口
States(10, 2) = T_turb_in;  States(10, 3) = 6.50;  States(10, 6) = m_discharge;
States(10, 4) = getFluidProperty(libLoc, 'H', 'P', States(10,3)*1e6, 'T', States(10,2), Fluid, 1, 1, 'MASS BASE SI');
States(10, 5) = getFluidProperty(libLoc, 'S', 'P', States(10,3)*1e6, 'T', States(10,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 11]: T1 出口 (等熵膨胀 + 效率修正)
States(11, 3) = 0.70;  States(11, 6) = m_discharge;
s11_is = States(10, 5);
h11_is = getFluidProperty(libLoc, 'H', 'P', States(11,3)*1e6, 'S', s11_is, Fluid, 1, 1, 'MASS BASE SI');
States(11, 4) = States(10, 4) - eta_T_is * (States(10, 4) - h11_is);
States(11, 2) = getFluidProperty(libLoc, 'T', 'P', States(11,3)*1e6, 'H', States(11,4), Fluid, 1, 1, 'MASS BASE SI');
States(11, 5) = getFluidProperty(libLoc, 'S', 'P', States(11,3)*1e6, 'H', States(11,4), Fluid, 1, 1, 'MASS BASE SI');

% [节点 12]: HR2 加热后 -> T2入口
States(12, 2) = T_turb_in;  States(12, 3) = 0.65;  States(12, 6) = m_discharge;
States(12, 4) = getFluidProperty(libLoc, 'H', 'P', States(12,3)*1e6, 'T', States(12,2), Fluid, 1, 1, 'MASS BASE SI');
States(12, 5) = getFluidProperty(libLoc, 'S', 'P', States(12,3)*1e6, 'T', States(12,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 13]: T2 出口 (等熵膨胀 + 效率修正)
States(13, 3) = 0.12;  States(13, 6) = m_discharge;
s13_is = States(12, 5);
h13_is = getFluidProperty(libLoc, 'H', 'P', States(13,3)*1e6, 'S', s13_is, Fluid, 1, 1, 'MASS BASE SI');
States(13, 4) = States(12, 4) - eta_T_is * (States(12, 4) - h13_is);
States(13, 2) = getFluidProperty(libLoc, 'T', 'P', States(13,3)*1e6, 'H', States(13,4), Fluid, 1, 1, 'MASS BASE SI');
States(13, 5) = getFluidProperty(libLoc, 'S', 'P', States(13,3)*1e6, 'H', States(13,4), Fluid, 1, 1, 'MASS BASE SI');

% [节点 14]: AE-HE 换热出口
States(14, 2) = 303;  States(14, 3) = P_LPT;  States(14, 6) = m_discharge;
States(14, 4) = getFluidProperty(libLoc, 'H', 'P', States(14,3)*1e6, 'T', States(14,2), Fluid, 1, 1, 'MASS BASE SI');
States(14, 5) = getFluidProperty(libLoc, 'S', 'P', States(14,3)*1e6, 'T', States(14,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 15]: Cooler 出口 -> LPT回流
States(15, 2) = T_amb;  States(15, 3) = P_LPT;  States(15, 6) = m_discharge;
States(15, 4) = getFluidProperty(libLoc, 'H', 'P', States(15,3)*1e6, 'T', States(15,2), Fluid, 1, 1, 'MASS BASE SI');
States(15, 5) = getFluidProperty(libLoc, 'S', 'P', States(15,3)*1e6, 'T', States(15,2), Fluid, 1, 1, 'MASS BASE SI');

% CO2 临界点物性 (用于 T-s, p-h 图参考)
T_crit = 304.1;  P_crit = 7.38;
h_crit = getFluidProperty(libLoc, 'H', 'P', P_crit*1e6, 'T', T_crit, Fluid, 1, 1, 'MASS BASE SI');
s_crit = getFluidProperty(libLoc, 'S', 'P', P_crit*1e6, 'T', T_crit, Fluid, 1, 1, 'MASS BASE SI');

% 单位转换: REFPROP 'MASS BASE SI' 返回 H [J/kg], S [J/(kg·K)]
% 统一转换为 kJ 单位以匹配论文数据
States(:, 4) = States(:, 4) / 1000;   % J/kg  → kJ/kg
States(:, 5) = States(:, 5) / 1000;   % J/(kg·K) → kJ/(kg·K)
h_crit = h_crit / 1000;               % J/kg → kJ/kg
s_crit = s_crit / 1000;               % J/(kg·K) → kJ/(kg·K)

% CO2 饱和线数据 (用于 p-h, T-s 饱和曲线图)
T_triple = 216.6;  % CO2 三相点温度
N_sat = 60;
T_sat_range = linspace(T_triple, T_crit - 0.5, N_sat);
h_liq_sat = zeros(1, N_sat + 1);
h_vap_sat = zeros(1, N_sat + 1);
s_liq_sat = zeros(1, N_sat + 1);
s_vap_sat = zeros(1, N_sat + 1);
P_sat_arr = zeros(1, N_sat + 1);
for i = 1:N_sat
    P_sat_arr(i) = getFluidProperty(libLoc, 'P', 'T', T_sat_range(i), 'Q', 0, Fluid, 1, 1, 'MASS BASE SI') / 1e6;  % Pa → MPa
    h_liq_sat(i) = getFluidProperty(libLoc, 'H', 'T', T_sat_range(i), 'Q', 0, Fluid, 1, 1, 'MASS BASE SI') / 1000;
    h_vap_sat(i) = getFluidProperty(libLoc, 'H', 'T', T_sat_range(i), 'Q', 1, Fluid, 1, 1, 'MASS BASE SI') / 1000;
    s_liq_sat(i) = getFluidProperty(libLoc, 'S', 'T', T_sat_range(i), 'Q', 0, Fluid, 1, 1, 'MASS BASE SI') / 1000;
    s_vap_sat(i) = getFluidProperty(libLoc, 'S', 'T', T_sat_range(i), 'Q', 1, Fluid, 1, 1, 'MASS BASE SI') / 1000;
end
% 将临界点作为饱和穹顶的闭合点
P_sat_arr(N_sat + 1) = P_crit;
h_liq_sat(N_sat + 1) = h_crit;
h_vap_sat(N_sat + 1) = h_crit;
s_liq_sat(N_sat + 1) = s_crit;
s_vap_sat(N_sat + 1) = s_crit;
T_sat_range(N_sat + 1) = T_crit;

fprintf('状态点计算完成。\n\n');

%% ========================================================================
% 3. 输出状态点结果表 (论文 Appendix B)
% =========================================================================
fprintf('========================================================================================\n');
fprintf('               CCES-CHP 热力学状态点计算结果 (论文 Appendix B)\n');
fprintf('========================================================================================\n');
fprintf(' 节点 | 温度 T [K] | 压力 P [MPa] | 焓 h [kJ/kg]  | 熵 s [kJ/kg.K] | 流量 m [kg/s]\n');
fprintf('----------------------------------------------------------------------------------------\n');
for i = 1:Num_States
    fprintf('  %2d  |  %8.2f   |   %8.3f    |   %10.2f   |   %10.4f    |    %6.1f\n', ...
        States(i,1), States(i,2), States(i,3), States(i,4), States(i,5), States(i,6));
end
fprintf('========================================================================================\n\n');

%% ========================================================================
% 4. 核心性能指标计算 (论文 Table 2)
%    包括: 功、热、无量纲因子 beta(β)、比率参数 alpha(α)
% =========================================================================
fprintf('--- 计算核心性能指标 ---\n');

% 4.1 压气机与透平功率 (未计入机械效率) [MW]
W_C1_shaft = m_charge * (States(3,4) - States(2,4)) / 1000;  % C1 轴功
W_C2_shaft = m_charge * (States(5,4) - States(4,4)) / 1000;  % C2 轴功
W_T1_shaft = m_discharge * (States(10,4) - States(11,4)) / 1000;  % T1 轴功
W_T2_shaft = m_discharge * (States(12,4) - States(13,4)) / 1000;  % T2 轴功

% 4.2 计入机械效率后的电功率 [MW] (式 2, 5)
W_C1_E = W_C1_shaft / eta_motor;   % C1 电机耗电功率
W_C2_E = W_C2_shaft / eta_motor;   % C2 电机耗电功率
W_C_E  = W_C1_E + W_C2_E;          % 压缩总耗电功率 (式 2)
W_T1_E = W_T1_shaft * eta_gen;     % T1 发电功率
W_T2_E = W_T2_shaft * eta_gen;     % T2 发电功率
W_T_E  = W_T1_E + W_T2_E;          % 透平总发电功率 (式 5)

% 4.3 换热器热功率 [MW] (式 8, 10)
% 中冷器压缩热 (来自IC1 + IC2)
Q_IC1 = m_charge * (States(3,4) - States(4,4)) / 1000;   % IC1 热功率
Q_IC2 = m_charge * (States(5,4) - States(6,4)) / 1000;   % IC2 热功率
Q_IC  = Q_IC1 + Q_IC2;                                    % 总中冷器热功率 (式 8)

% 回热热交换器热回收
Q_HR1 = m_discharge * (States(10,4) - States(9,4)) / 1000;   % HR1 热功率
Q_HR2 = m_discharge * (States(12,4) - States(11,4)) / 1000;  % HR2 热功率
Q_HR  = Q_HR1 + Q_HR2;                                        % 总回热功率 (式 10)

% 膨胀后废热回收
Q_AE_HE = m_discharge * (States(13,4) - States(14,4)) / 1000;  % AE-HE 热功率

% 充放电时间 (论文 Table 2: 基于初始参数)
t_charge = 7.5;     % [h] 充电时间
t_discharge = 5.0;  % [h] 放电时间

% 4.4 无量纲因子 (论文式 18-21) — 瞬时功率比
beta1  = Q_IC / W_C_E;               % 压缩热/压缩电功率比 (式 18)
beta2  = Q_HR / W_T_E;               % 回热/透平发电比 (式 19)
alpha1 = m_charge / W_C_E;           % 压缩流量/压缩电功率 (式 20) [kg/(s·MW)]
alpha2 = m_discharge / W_T_E;        % 膨胀流量/透平发电 (式 21) [kg/(s·MW)]

% 4.5 热供应率 X 与热回馈率 Y (式 13-15)
% 注意: X, Y 基于全周期能量积分, 非瞬时功率比
% Y = ∫Q_HR dt / ∫Q_IC dt = (Q_HR·t_discharge) / (Q_IC·t_charge)
% X = 1 - Y
Y = (Q_HR * t_discharge) / (Q_IC * t_charge);
X = 1 - Y;

% 高温/低温供热功率 (从能量平衡推导, 初始工况 Q_HG_HE = 0)
Q_HG_HE = 0;  % 高温供热功率 [MW]
% 由全周期能量平衡 (式 12): Q_IC·t_charge = Q_HR·t_discharge + Q_LG-HE·t_discharge + Q_HG-HE·t_HG
% → Q_LG_HE = (X · Q_IC · t_charge) / t_discharge
Q_LG_HE = (X * Q_IC * t_charge) / t_discharge;  % 低温供热瞬时功率 [MW]

% 4.6 效率指标 (式 16-17)
eta_electricity = (W_T_E * t_discharge) / (W_C_E * t_charge) * 100;    % 电-电转换效率 (式 16)
eta_heating_HG = (Q_HG_HE * t_discharge) / (W_C_E * t_charge) * 100;   % 高温供热效率
eta_heating_LG = (Q_LG_HE * t_discharge) / (W_C_E * t_charge) * 100;   % 低温供热效率
eta_heating_AE = (Q_AE_HE * t_discharge) / (W_C_E * t_charge) * 100;   % 废热供热效率
eta_heating_total = eta_heating_HG + eta_heating_LG + eta_heating_AE;  % 总供热效率 (式 17)

%% ========================================================================
% 5. 输出性能结果表 (论文 Table 2)
% =========================================================================
fprintf('========================================================================================\n');
fprintf('               CCES-CHP 性能计算结果 (论文 Table 2)\n');
fprintf('========================================================================================\n');
fprintf(' 性能指标                           |  数值        |  单位\n');
fprintf('--------------------------------------------------------------------------------\n');
fprintf(' W_T,E  (透平总发电功率)            |  %8.2f     |  MW\n', W_T_E);
fprintf(' W_C,E  (压缩总耗电功率)            |  %8.2f     |  MW\n', W_C_E);
fprintf(' 充电时间                           |  %8.1f     |  h\n', t_charge);
fprintf(' 放电时间                           |  %8.1f     |  h\n', t_discharge);
fprintf(' m_C  (充电质量流量)                |  %8.1f     |  kg/s\n', m_charge);
fprintf(' m_T  (放电质量流量)                |  %8.1f     |  kg/s\n', m_discharge);
fprintf(' Q_IC1 (IC1 热功率)                |  %8.2f     |  MW\n', Q_IC1);
fprintf(' Q_IC2 (IC2 热功率)                |  %8.2f     |  MW\n', Q_IC2);
fprintf(' Q_HR1 (HR1 热功率)                |  %8.2f     |  MW\n', Q_HR1);
fprintf(' Q_HR2 (HR2 热功率)                |  %8.2f     |  MW\n', Q_HR2);
fprintf(' Q_HG-HE (高温供热功率)            |  %8.2f     |  MW\n', Q_HG_HE);
fprintf(' Q_LG-HE (低温供热功率)            |  %8.2f     |  MW\n', Q_LG_HE);
fprintf(' Q_AE-HE (废热供热功率)            |  %8.2f     |  MW\n', Q_AE_HE);
fprintf('--------------------------------------------------------------------------------\n');
fprintf(' β1 (压缩热/压缩电功率)            |  %8.2f     |  -\n', beta1);
fprintf(' β2 (回热/透平发电)                 |  %8.2f     |  -\n', beta2);
fprintf(' α1 (充电流量/电功率)              |  %8.2f     |  kg/(s·MW)\n', alpha1);
fprintf(' α2 (放电流量/电功率)              |  %8.2f     |  kg/(s·MW)\n', alpha2);
fprintf(' X  (热供应率)                      |  %8.1f     |  %%\n', X*100);
fprintf(' Y  (热回馈率)                      |  %8.1f     |  %%\n', Y*100);
fprintf('--------------------------------------------------------------------------------\n');
fprintf(' η_electricity  (电-电效率)         |  %8.1f     |  %%\n', eta_electricity);
fprintf(' η_heating,HG   (高温供热效率)      |  %8.1f     |  %%\n', eta_heating_HG);
fprintf(' η_heating,LG   (低温供热效率)      |  %8.1f     |  %%\n', eta_heating_LG);
fprintf(' η_heating,AE   (废热供热效率)      |  %8.1f     |  %%\n', eta_heating_AE);
fprintf(' η_heating,total(总供热效率)        |  %8.1f     |  %%\n', eta_heating_total);
fprintf(' 综合能量利用效率                   |  %8.1f     |  %%\n', eta_electricity + eta_heating_total);
fprintf('========================================================================================\n\n');

%% ========================================================================
% 6. 运行可行域构建 (论文 Section 3)
%    充电工况: 正斜率 +β1 → 功率越大, 压缩热越多, 供热能力越强
%    放电工况: 负斜率 -β2 → 功率越大, 回热消耗越多, 供热能力越弱
%             最大发电与最大供热不可兼得, 可行域为非矩形多边形
% =========================================================================
fprintf('--- 构建运行可行域 ---\n');

% 当前时刻初始化 (t=0时的初始SOC)
Q_HTV_0 = 0.5 * Q_HTV_upper;  % HTV 初始储热 [MWh_th]
P_HPT_0 = 0.5 * (P_HPT_upper + P_HPT_lower);  % HPT 初始压力 [MPa]

dt = 1.0;  % 单位调度周期 [h]

% --- 最大约束值 ---
W_C_upper = W_design;           % 充电功率上限 [MW]
W_T_upper = W_design;           % 放电功率上限 [MW]
Q_HG_LG_max = beta1 * W_C_upper; % 最大供热功率 [MW]

% 从 HTV 储热量换算的可用热功率 [MW]
Q_from_lower = max(0, (Q_HTV_0 - Q_HTV_lower) / dt);  % HTV下限约束下的零功率供热
Q_from_upper = max(0, (Q_HTV_upper - Q_HTV_0) / dt);   % HTV上限约束下的零功率供热

%% --- 6.1 充电-供热可行域 (式 28, Fig. 3) ---
% 充电热平衡: Q_HTV(t) = Q_HTV(t-1) + (β1·W_C - Q_heat)·Δt
% HTV下限约束 (供热上限): Q_heat ≤ β1·W_C + (Q_HTV(0) - Q_lower)/Δt
% HTV上限约束 (供热下限): Q_heat ≥ β1·W_C + (Q_HTV(0) - Q_upper)/Δt
% 正斜率 +β1: 充电功率越大, 压缩热越多, 可供热越多

fprintf('\n[充电-供热工况] 运行可行域 (式 28 / Fig. 3):\n');
fprintf('  约束斜率 β1 = +%.2f (正斜率: 充供电互补, 功率越大可供热越多)\n', beta1);

% 上边界线 (由HTV下限决定): Q = β1·W + Q_from_lower
% 下边界线 (由HTV上限决定): Q = max(0, β1·W - Q_from_upper)
% 交点计算 (用于构建多边形):
W_at_Qmax = max(0, (Q_HG_LG_max - Q_from_lower) / beta1);  % 上边界线与Qmax的交点
Q_at_Wmax_upper = min(Q_HG_LG_max, Q_from_lower + beta1 * W_C_upper);  % Wmax处的上边界
Q_at_Wmax_lower = max(0, Q_from_lower + beta1 * W_C_upper - Q_from_upper - Q_from_lower);
% 简化: 下边界 = max(0, β1·W + Q_from_lower - Q_HTV_upper/Δt)
Q_lower_at_0 = max(0, Q_from_lower - Q_HTV_upper / dt);
Q_lower_at_Wmax = max(0, Q_lower_at_0 + beta1 * W_C_upper);

% 构建可行域多边形 (按逆时针, y上限 = min(Q_HG_LG_max, 上边界), y下限 = max(0, 下边界))
% 顶点: (0,0) → (Wmax,0) → (Wmax, Q_at_Wmax_lower) → ... 沿下边界回到纵轴
% 实际构建: 由上下边界线和矩形边界 [0,Wmax]×[0,Qmax] 的交集构成

% 上边界有效线段 (clipped by Qmax and Wmax)
W_pts_upper = [0, min(W_at_Qmax, W_C_upper)];
Q_pts_upper = [min(Q_from_lower, Q_HG_LG_max), ...
               min(Q_HG_LG_max, Q_from_lower + beta1 * W_pts_upper(2))];

fprintf('  零功率最大供热: %.1f MW\n', Q_pts_upper(1));
fprintf('  最大功率最大供热: %.1f MW\n', Q_at_Wmax_upper);
fprintf('  最大供热所需最小功率: %.1f MW\n', W_at_Qmax);

%% --- 6.2 放电-供热可行域 (式 29, Fig. 4) ---
% 放电热平衡: Q_HTV(t) = Q_HTV(t-1) - (β2·W_T + Q_heat)·Δt
% HTV下限约束 (供热上限): Q_heat ≤ -β2·W_T + (Q_HTV(0) - Q_lower)/Δt
% HTV上限约束 (供热下限): Q_heat ≥ -β2·W_T + (Q_HTV(0) - Q_upper)/Δt
% 负斜率 -β2: 放电功率越大, 回热消耗越多, 可供热越少
%           最大发电与最大供热不可兼得！

fprintf('\n[放电-供热工况] 运行可行域 (式 29 / Fig. 4):\n');
fprintf('  约束斜率 β2 = -%.2f (负斜率: 电热竞争, 不可兼得最大值)\n', beta2);

% 上边界线 (由HTV下限决定): Q = -β2·W + Q_from_lower
% 下边界线 (由HTV上限决定): Q = max(0, -β2·W + Q_from_lower - Q_HTV_upper/Δt)
% 简化下边界: Q = max(0, -β2·W - Q_from_upper)
Q_lower_d_at_0 = max(0, Q_from_lower - Q_HTV_upper / dt);

% 关键交点:
W_T_at_Qmax = max(0, (Q_from_lower - Q_HG_LG_max) / beta2);  % 上边界线与Qmax的交点
W_T_at_Q0 = min(W_T_upper, Q_from_lower / beta2);  % 上边界线与横轴交点(最大功率)

Q_at_W0_upper = min(Q_from_lower, Q_HG_LG_max);  % 零功率时的上边界供热
Q_at_Wmax_upper = min(Q_HG_LG_max, max(0, Q_from_lower - beta2 * W_T_upper));  % 最大功率时供热(裁剪至Qmax)

fprintf('  零功率最大供热: %.1f MW\n', Q_at_W0_upper);
fprintf('  最大功率(%.0f MW)最大供热: %.1f MW  ← 不可同时取最大值!\n', W_T_upper, Q_at_Wmax_upper);
fprintf('  最大供热(%.0f MW)对应最大功率: %.1f MW\n', Q_HG_LG_max, min(W_T_upper, W_T_at_Qmax));
fprintf('  零供热对应最大功率: %.1f MW\n', min(W_T_upper, W_T_at_Q0));

%% ========================================================================
% 7. 绘制运行可行域图 (论文 Fig. 3, Fig. 4)
% =========================================================================

% --- 图1: 充电-供热工况运行可行域 (Fig. 3) ---
figure('Name', 'Feasibility Domain: Charge-Heat (Fig. 3)', 'Color', 'w', 'Position', [100, 100, 700, 550]);
hold on; grid on;
% 构建可行域: 矩形 [0,Wmax]x[0,Qmax] 与两条正斜率约束线的交集
b_upper_c = 8;  % 演示值: HTV储热较低时约束可见
b_lower_c = 8 - Q_HTV_upper / dt;
[p_cx, p_cy] = buildFeasiblePolygon(W_C_upper, Q_HG_LG_max, beta1, b_upper_c, b_lower_c);

fill(p_cx, p_cy, [0.85 0.95 1.0], 'EdgeColor', 'b', 'LineWidth', 2, 'FaceAlpha', 0.4);
% 绘制上边界约束线 (HTV下限, 斜率 +β1)
W_range = linspace(0, W_C_upper, 50);
Q_upper_bound = min(Q_HG_LG_max, 8 + beta1 * W_range);
plot(W_range, Q_upper_bound, 'r-', 'LineWidth', 2);

% 绘制下边界约束线 (HTV上限, 斜率 +β1)
Q_lower_bound = max(0, (8 - Q_HTV_upper/dt) + beta1 * W_range);
plot(W_range, Q_lower_bound, 'r--', 'LineWidth', 1.5);

% 标记多边形顶点
plot(p_cx(1:end-1), p_cy(1:end-1), 'ko', 'MarkerSize', 7, 'MarkerFaceColor', 'k');

xlabel('Charging Power W_{C,E} [MW]', 'FontSize', 10);
ylabel('Heating Power Q_{HG-HE}+Q_{LG-HE} [MW]', 'FontSize', 10);
title('Charging-Heating Feasibility Domain (Fig.3, slope +\beta_1)', 'FontSize', 11, 'FontWeight', 'bold');
legend({'Feasible Region', 'Upper bound (HTV lower)', 'Lower bound (HTV upper)'}, ...
    'Location', 'best', 'FontSize', 8);
xlim([-0.5, W_C_upper + 1.5]);
ylim([-0.5, Q_HG_LG_max + 2]);
set(gca, 'FontSize', 10);

exportgraphics(gcf, fullfile(outDir, 'Fig01_ChargeHeat_Feasibility.png'), 'Resolution', 300);

% --- 图2: 放电-供热工况运行可行域 (Fig. 4) ---
% 核心差异: 负斜率 -β2, 最大发电与最大供热不可兼得
figure('Name', 'Feasibility Domain: Discharge-Heat (Fig. 4)', 'Color', 'w', 'Position', [850, 100, 700, 550]);
hold on; grid on;

% 构建可行域: 矩形 [0,Wmax]x[0,Qmax] 与两条负斜率约束线的交集
% 负斜率 -eta_2: 电热竞争, 不可兼得
b_upper_d = 18;  % 演示值: 储热有限时电热竞争可见
b_lower_d = 18 - Q_HTV_upper / dt;
[pd_x, pd_y] = buildFeasiblePolygon(W_T_upper, Q_HG_LG_max, -beta2, b_upper_d, b_lower_d);

fill(pd_x, pd_y, [1.0 0.85 0.85], 'EdgeColor', 'r', 'LineWidth', 2, 'FaceAlpha', 0.4);
Q_d_upper = min(Q_HG_LG_max, max(0, 18 - beta2 * W_range));
plot(W_range, Q_d_upper, 'b-', 'LineWidth', 2.5);

% 绘制下边界约束线 (HTV上限, 斜率 -β2)
Q_d_lower = max(0, (18 - Q_HTV_upper/dt) - beta2 * W_range);
plot(W_range(W_range <= W_T_upper), Q_d_lower(1:length(W_range)), 'b--', 'LineWidth', 1.5);
% 检查可行域是否非矩形: 若右上角不可达, 标注不可达区域
Q_at_W0_d = min(Q_HG_LG_max, 18);
Q_at_Wmax_d = min(Q_HG_LG_max, max(0, 18 - beta2 * W_T_upper));
if Q_at_Wmax_d < Q_HG_LG_max && Q_at_Wmax_d > 0
W_at_Qmax_d = max(0, min(W_T_upper, (18 - Q_HG_LG_max) / beta2));
    unreach_x = [W_at_Qmax_d, W_T_upper, W_T_upper, W_at_Qmax_d];
    unreach_y = [Q_HG_LG_max, Q_HG_LG_max, Q_at_Wmax_d, Q_at_Wmax_d];
    fill(unreach_x, unreach_y, [0.9 0.9 0.9], 'EdgeColor', 'r', ...
        'LineWidth', 1.5, 'LineStyle', ':', 'FaceAlpha', 0.3);
    text((W_at_Qmax_d + W_T_upper)/2, (Q_HG_LG_max + Q_at_Wmax_d)/2, ...
        'INFEASIBLE', 'FontSize', 9, 'Color', 'r', 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center');
end

% 标记关键运行点
plot(W_T_upper, 0, 'bs', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
text(W_T_upper + 0.2, 0.5, 'Max Power', 'FontSize', 8, 'Color', 'b');
plot(0, Q_at_W0_d, 'rs', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
text(0.3, Q_at_W0_d + 0.3, 'Max Heat', 'FontSize', 8, 'Color', 'r');

xlabel('Discharging Power W_{T,E} [MW]', 'FontSize', 10);
ylabel('Heating Power Q_{HG-HE}+Q_{LG-HE} [MW]', 'FontSize', 10);
title('Discharging-Heating Feasibility Domain (Fig.4, slope -\beta_2)', 'FontSize', 11, 'FontWeight', 'bold');
legend({'Feasible Region', 'Upper bound (HTV lower)', 'Lower bound (HTV upper)', 'Infeasible'}, ...
    'Location', 'best', 'FontSize', 8);
xlim([-0.5, W_T_upper + 1.5]);
ylim([-0.5, Q_HG_LG_max + 3]);
set(gca, 'FontSize', 10);

% 图例标注: 负斜率含义
text(W_T_upper * 0.5, Q_HG_LG_max + 1.5, ...
    '\beta_2 < 0: 电热竞争, 最大发电与最大供热不可兼得', ...
    'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.6 0 0], ...
    'HorizontalAlignment', 'center');

exportgraphics(gcf, fullfile(outDir, 'Fig02_DischargeHeat_Feasibility.png'), 'Resolution', 300);

%% ========================================================================
% 8. 双 SOC 模型 (论文式 22, 23)
%    HTV 储热量 Q_HTV(t) 与 HPT 储气压力 P_HPT(t)
% =========================================================================
fprintf('\n--- 构建双 SOC 模型 (论文 Section 3.2.1) ---\n');

% 24小时调度模拟周期
N_hours = 24;
t_array = (1:N_hours)';  % 小时

% 初始化 SOC 数组
Q_HTV_array = zeros(N_hours, 1);   % HTV 储热量 [MWh_th]
P_HPT_array = zeros(N_hours, 1);   % HPT 压力 [MPa]
SOC_heat = zeros(N_hours, 1);      % 热 SOC [%]
SOC_gas  = zeros(N_hours, 1);      % 气 SOC [%]

Q_HTV_array(1) = Q_HTV_0;
P_HPT_array(1) = P_HPT_0;
SOC_heat(1) = Q_HTV_0 / Q_HTV_upper * 100;
SOC_gas(1)  = (P_HPT_0 - P_HPT_lower) / (P_HPT_upper - P_HPT_lower) * 100;

%% ========================================================================
% 9. 24小时调度模拟 (论文 Section 5)
%    模拟与 C-CHP、风电的联合调度
% =========================================================================
fprintf('--- 进行 24 小时调度模拟 ---\n');

% 9.1 定义负荷与风电数据 (参考论文 Fig. 8)
% 典型供暖日负荷数据
% 热负荷 [MW] (峰值约 41.5 MW)
Heat_Load = [38, 35, 32, 30, 29, 28, 28, 29, 31, 33, 36, 39, ...
             41.5, 41, 40, 38, 37, 35, 40, 42, 41.5, 40, 42, 40]';

% 电负荷 [MW] (峰值约 48 MW 场景B)
Elec_Load = [28, 22, 18, 16, 15, 14, 16, 18, 20, 22, 26, 48, ...
             48, 48, 45, 30, 28, 24, 32, 48, 48, 48, 48, 35]';

% 风电出力 [MW]
Wind_Power = [18, 16, 14, 12, 13, 12, 8, 6, 5, 4, 3, 2, ...
              2, 3, 4, 6, 10, 12, 8, 6, 5, 14, 16, 18]';

% 9.2 C-CHP 参数
CCHP_capacity = 30;       % C-CHP 容量 [MW]
CCHP_therm_ratio = 1.2;   % 热电比

% C-CHP 按"以热定电"模式运行
% 首先确定 C-CHP 的热出力 (最大 30*1.2 = 36 MW 热)
CCHP_heat_max = CCHP_capacity * CCHP_therm_ratio;  % 36 MW 热
CCHP_Heat = min(Heat_Load, CCHP_heat_max);  % C-CHP 供热
CCHP_Elec = CCHP_Heat / CCHP_therm_ratio;   % C-CHP 供电

% 9.3 计算 CCES-CHP 调度指令
% 热调度 = 热负荷 - C-CHP 供热
Heat_Dispatch = Heat_Load - CCHP_Heat;

% 电调度 = 电负荷 - C-CHP 供电 - 风电
Elec_Dispatch = Elec_Load - CCHP_Elec - Wind_Power;

% 正调度 = 需要充电 (存储多余电量), 负调度 = 需要放电 (补充缺口)
% 论文中: 正数表示需要充电, 负数表示需要放电

% 9.4 调度模拟
W_C_actual = zeros(N_hours, 1);   % 实际充电功率
W_T_actual = zeros(N_hours, 1);   % 实际放电功率
Q_heat_actual = zeros(N_hours, 1); % 实际供热功率
Operation_Mode = cell(N_hours, 1); % 运行模式记录

for t = 1:N_hours
    if t > 1
        % 前一时刻的 SOC 传递
        Q_HTV_array(t) = Q_HTV_array(t-1);
        P_HPT_array(t) = P_HPT_array(t-1);
    end

    % 确定调度模式
    if Elec_Dispatch(t) > 0
        % ---- 充电-供热模式 ----
        Operation_Mode{t} = 'Charging-Heating';

        % 充电功率受以下约束:
        % (1) 调度指令
        % (2) 最大充电功率 W_C_upper
        % (3) HTV 储热上限约束 (式 26)
        % (4) HPT 压力上限约束
        W_C_target = min(Elec_Dispatch(t), W_C_upper);

        % HTV 约束: Q_HTV(t) <= Q_HTV_upper
        W_C_HTV_limit = max(0, (Q_HTV_upper - Q_HTV_array(t)) / dt / beta1);
        % HPT 约束: P_HPT(t) <= P_HPT_upper
        W_C_HPT_limit = max(0, (P_HPT_upper - P_HPT_array(t)) * V_HPT / (Rg * T_HPT) / dt / alpha1 * 1000);

        W_C_actual(t) = min([W_C_target, W_C_HTV_limit, W_C_HPT_limit]);

        % 压缩热 = β1 * W_C (存入 HTV)
        Q_comp_heat = beta1 * W_C_actual(t);

        % 实际供热 (来自调度)
        if Heat_Dispatch(t) > 0
            Q_heat_actual(t) = min(Heat_Dispatch(t), Q_HG_LG_max);
            Q_heat_actual(t) = min(Q_heat_actual(t), Q_HTV_array(t) / dt);  % HTV 下限约束
        end

        % 维持 HTV 热平衡 (式 22 充电-供热分支)
        Q_HTV_array(t) = Q_HTV_array(t) + (Q_comp_heat - Q_heat_actual(t)) * dt;

        % 维持 HPT 压力平衡 (式 23 充电分支)
        delta_P = Rg * T_HPT / V_HPT * alpha1 * W_C_actual(t) / 1000 * dt;
        P_HPT_array(t) = P_HPT_array(t) + delta_P;

    elseif Elec_Dispatch(t) < 0
        % ---- 放电-供热模式 ----
        Operation_Mode{t} = 'Discharging-Heating';

        % 放电功率受以下约束:
        % (1) 调度指令 (取正值)
        % (2) 最大放电功率 W_T_upper
        % (3) HTV 储热下限约束 (式 27)
        % (4) HPT 压力下限约束
        W_T_target = min(abs(Elec_Dispatch(t)), W_T_upper);

        % HTV 约束: Q_HTV(t) >= Q_HTV_lower
        W_T_HTV_limit = max(0, (Q_HTV_array(t) - Q_HTV_lower) / dt / beta2);
        % HPT 约束: P_HPT(t) >= P_HPT_lower
        W_T_HPT_limit = max(0, (P_HPT_array(t) - P_HPT_lower) * V_HPT / (Rg * T_HPT) / dt / alpha2 * 1000);

        W_T_actual(t) = min([W_T_target, W_T_HTV_limit, W_T_HPT_limit]);

        % 回热消耗 = β2 * W_T (从 HTV 取出)
        Q_return_heat = beta2 * W_T_actual(t);

        % 实际供热
        if Heat_Dispatch(t) > 0
            Q_heat_actual(t) = min(Heat_Dispatch(t), Q_HG_LG_max);
            Q_heat_actual(t) = min(Q_heat_actual(t), ...
                (Q_HTV_array(t) - Q_return_heat * dt) / dt);  % 剩余热约束
        end

        % 维持 HTV 热平衡 (式 22 放电-供热分支)
        Q_HTV_array(t) = Q_HTV_array(t) - (Q_return_heat + Q_heat_actual(t)) * dt;

        % 维持 HPT 压力平衡 (式 23 放电分支)
        delta_P = Rg * T_HPT / V_HPT * alpha2 * W_T_actual(t) / 1000 * dt;
        P_HPT_array(t) = P_HPT_array(t) - delta_P;

    else
        % ---- 仅供热或待机 ----
        Operation_Mode{t} = 'Heating-Only';
        W_C_actual(t) = 0;
        W_T_actual(t) = 0;

        if Heat_Dispatch(t) > 0
            Q_heat_actual(t) = min(Heat_Dispatch(t), Q_HTV_array(t) / dt);
            Q_HTV_array(t) = Q_HTV_array(t) - Q_heat_actual(t) * dt;
        end
    end

    % 边界修正: 确保 SOC 在合理范围内
    Q_HTV_array(t) = max(Q_HTV_lower, min(Q_HTV_upper, Q_HTV_array(t)));
    P_HPT_array(t) = max(P_HPT_lower, min(P_HPT_upper, P_HPT_array(t)));

    % 更新 SOC 百分比
    SOC_heat(t) = Q_HTV_array(t) / Q_HTV_upper * 100;
    SOC_gas(t)  = (P_HPT_array(t) - P_HPT_lower) / (P_HPT_upper - P_HPT_lower) * 100;
end

% CCES-CHP 供电 = 放电 - 充电 (正 = 净供电)
CCES_Power = W_T_actual - W_C_actual;

fprintf('24小时调度模拟完成。\n');

%% ========================================================================
% 10. 绘制调度结果图
% =========================================================================
fprintf('--- 绘制调度结果图 ---\n');

% --- 图3: 负荷与风电曲线 (论文 Fig. 8) ---
figure('Name', 'Load and Wind Power Curves (Fig. 8)', 'Color', 'w', 'Position', [100, 100, 900, 500]);
hold on; grid on;
plot(t_array, Heat_Load, 'r-o', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'r');
plot(t_array, Elec_Load, 'b-s', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'b');
plot(t_array, Wind_Power, 'g-^', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'g');
xlabel('Time [h]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Power [MW]', 'FontSize', 10);
title('Heat Load, Electric Load & Wind Power (Fig. 8)', 'FontSize', 10, 'FontWeight', 'bold');
legend({'Heat Load', 'Electric Load', 'Wind Power'}, 'Location', 'best');
xlim([1, 24]); xticks(1:24);
set(gca, 'FontSize', 10);

exportgraphics(gcf, fullfile(outDir, 'Fig03_LoadWind.png'), 'Resolution', 300);

% --- 图4: CCES-CHP 热电调度与实际出力 (论文 Fig. 9) ---
figure('Name', 'CCES-CHP Dispatch and Actual Operation (Fig. 9)', 'Color', 'w', 'Position', [100, 100, 1000, 600]);

subplot(2,1,1);
hold on; grid on;
bar_colors_E = zeros(N_hours, 3);
for t = 1:N_hours
    if Elec_Dispatch(t) > 0
        bar_colors_E(t, :) = [0.3 0.6 0.9];  % 充电 - 蓝色
    else
        bar_colors_E(t, :) = [0.9 0.3 0.3];  % 放电 - 红色
    end
end
b1 = bar(t_array, Elec_Dispatch, 'FaceColor', 'flat');
b1.CData = bar_colors_E;
plot(t_array, W_C_actual, 'b--o', 'LineWidth', 1.5, 'MarkerSize', 4);
plot(t_array, -W_T_actual, 'r--s', 'LineWidth', 1.5, 'MarkerSize', 4);
xlabel('Time [h]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Electric Power [MW]', 'FontSize', 10, 'FontWeight', 'bold');
title('CCES-CHP Electric Dispatch & Actual Operation', 'FontSize', 11, 'FontWeight', 'bold');
legend({'Electric Dispatch', 'Actual Charging', 'Actual Discharging'}, 'Location', 'best');
xlim([0.5, 24.5]); xticks(1:24);

subplot(2,1,2);
hold on; grid on;
b2 = bar(t_array, Heat_Dispatch, 'FaceColor', [1.0 0.6 0.2]);
plot(t_array, Q_heat_actual, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'r');
xlabel('Time [h]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Heat Power [MW]', 'FontSize', 10, 'FontWeight', 'bold');
title('CCES-CHP Heat Dispatch & Actual Operation', 'FontSize', 11, 'FontWeight', 'bold');
legend({'Heat Dispatch', 'Actual Heating'}, 'Location', 'best');
xlim([0.5, 24.5]); xticks(1:24);

exportgraphics(gcf, fullfile(outDir, 'Fig04_DispatchOperation.png'), 'Resolution', 300);

% --- 图5: 综合能源系统电力平衡 (论文 Fig. 10) ---
figure('Name', 'Integrated Energy System: Electricity (Fig. 10)', 'Color', 'w', 'Position', [100, 100, 900, 500]);
hold on; grid on;

% 电力生产 (正)
bar(t_array, CCHP_Elec, 'FaceColor', [0.3 0.7 0.3]);     % C-CHP 发电
bar(t_array, Wind_Power, 'FaceColor', [0.2 0.8 0.2]);     % 风电
bar(t_array, W_T_actual, 'FaceColor', [1.0 0.5 0.5]);     % CCES 放电

% 电力消费 (负, 用负数表示)
bar(t_array, -CCES_Power, 'FaceColor', [0.5 0.5 0.5]);    % CCES 净出力
bar(t_array, -Elec_Load, 'FaceColor', [0.3 0.3 0.3]);     % 电负荷

xlabel('Time [h]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Electric Power [MW]', 'FontSize', 10, 'FontWeight', 'bold');
title('Integrated Energy System: Electricity Balance (Fig. 10)', 'FontSize', 11, 'FontWeight', 'bold');
legend({'C-CHP Gen.', 'Wind Power', 'CCES Discharging', 'CCES Charging', 'Electric Load'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 8);
xlim([0.5, 24.5]); xticks(1:24);
set(gca, 'FontSize', 10);

exportgraphics(gcf, fullfile(outDir, 'Fig05_ElectricityBalance.png'), 'Resolution', 300);

% --- 图6: 综合能源系统热力平衡 (论文 Fig. 11) ---
figure('Name', 'Integrated Energy System: Heat (Fig. 11)', 'Color', 'w', 'Position', [100, 100, 900, 500]);
hold on; grid on;

bar(t_array, CCHP_Heat, 'FaceColor', [0.3 0.7 0.3]);      % C-CHP 供热
bar(t_array, Q_heat_actual, 'FaceColor', [1.0 0.5 0.5]);   % CCES 供热
plot(t_array, Heat_Load, 'k--', 'LineWidth', 1.5);          % 热负荷

xlabel('Time [h]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Heat Power [MW]', 'FontSize', 10, 'FontWeight', 'bold');
title('Integrated Energy System: Heat Balance (Fig. 11)', 'FontSize', 11, 'FontWeight', 'bold');
legend({'C-CHP Heat', 'CCES Heat', 'Heat Load'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal');
xlim([0.5, 24.5]); xticks(1:24);
set(gca, 'FontSize', 10);

exportgraphics(gcf, fullfile(outDir, 'Fig06_HeatBalance.png'), 'Resolution', 300);

% --- 图7: 双 SOC 变化曲线 ---
figure('Name', 'Dual SOC Variation', 'Color', 'w', 'Position', [100, 100, 900, 450]);
hold on; grid on;
yyaxis left;
plot(t_array, SOC_heat, 'r-o', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'r');
ylabel('Heat SOC [%]', 'FontSize', 10);
ylim([0, 105]);

yyaxis right;
plot(t_array, SOC_gas, 'b-s', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'b');
ylabel('Gas SOC [%]', 'FontSize', 10);
ylim([0, 105]);

xlabel('Time [h]', 'FontSize', 10, 'FontWeight', 'bold');
title('CCES-CHP Dual SOC Model (Heat + Gas Storage)', 'FontSize', 11, 'FontWeight', 'bold');
legend({'Heat SOC (HTV)', 'Gas SOC (HPT)'}, 'Location', 'best');
xlim([1, 24]); xticks(1:24);
set(gca, 'FontSize', 10);

exportgraphics(gcf, fullfile(outDir, 'Fig07_DualSOC.png'), 'Resolution', 300);

% --- 图8: 24小时运行可行域变化 (论文 Fig. 12) ---
figure('Name', 'Feasibility Domain Evolution 24h (Fig. 12)', 'Color', 'w', 'Position', [50, 50, 1100, 500]);

% 选择4个代表性时刻
selected_hours = [1, 8, 15, 22];
for idx = 1:4
    t_h = selected_hours(idx);
    subplot(2, 2, idx);
    hold on; grid on;

    % 获取当前 SOC 状态
    if t_h == 1
        Q_HTV_current = Q_HTV_0;
        P_HPT_current = P_HPT_0;
    else
        Q_HTV_current = Q_HTV_array(t_h-1);
        P_HPT_current = P_HPT_array(t_h-1);
    end

    % 确定主导工况并构建对应的可行域多边形
    if Elec_Dispatch(t_h) > 0
        % 充电可行域: 正斜率 +eta_1
        W_max = W_C_upper;
        b_upper = max(0, (Q_HTV_current - Q_HTV_lower) / dt);
        b_lower = (Q_HTV_current - Q_HTV_upper) / dt;
        [px, py] = buildFeasiblePolygon(W_max, Q_HG_LG_max, beta1, b_upper, b_lower);
        dom_color = [0.85 0.95 1.0];  dom_edge = 'b';
        condition_str = 'Charge-Heat';
        op_W = W_C_actual(t_h);
        W_range_plot = linspace(0, W_max, 50);
        Q_line = min(Q_HG_LG_max, max(0, b_upper + beta1 * W_range_plot));
    else
        % 放电可行域: 负斜率 -eta_2, 最大发电与最大供热不可兼得
        W_max = W_T_upper;
        b_upper = max(0, (Q_HTV_current - Q_HTV_lower) / dt);
        b_lower = (Q_HTV_current - Q_HTV_upper) / dt;
        [px, py] = buildFeasiblePolygon(W_max, Q_HG_LG_max, -beta2, b_upper, b_lower);
        dom_color = [1.0 0.85 0.85];  dom_edge = 'r';
        condition_str = 'Discharge-Heat';
        op_W = W_T_actual(t_h);
        W_range_plot = linspace(0, W_max, 50);
        Q_line = min(Q_HG_LG_max, max(0, b_upper - beta2 * W_range_plot));
    end

    fill(px, py, dom_color, 'EdgeColor', dom_edge, ...
        'LineWidth', 1.5, 'FaceAlpha', 0.3);

    % 绘制约束线 (上边界)
    plot(W_range_plot, Q_line, 'k-', 'LineWidth', 2);

    % 标记当前运行点
    op_Q = Q_heat_actual(t_h);
    plot(op_W, op_Q, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');

    xlim([-0.5, W_max + 1.5]);
    ylim([-0.5, Q_HG_LG_max + 2]);
    xlabel('Electric Power [MW]', 'FontSize', 10);
    ylabel('Heating Power [MW]', 'FontSize', 10);
    title(sprintf('Hour %d (%s, SOC_{heat}=%.1f%%, SOC_{gas}=%.1f%%)', ...
        t_h, condition_str, SOC_heat(t_h), SOC_gas(t_h)), ...
        'FontSize', 10, 'FontWeight', 'bold');
    set(gca, 'FontSize', 10);
end
sgtitle('CCES-CHP Feasibility Domain Evolution (Fig. 12)', 'FontSize', 11, 'FontWeight', 'bold');

exportgraphics(gcf, fullfile(outDir, 'Fig08_24hFeasibility.png'), 'Resolution', 300);

% --- 图9: Heat-dependent vs Power-dependent 模式 (论文 Fig. 7) ---
% 放电工况: 负斜率 -β2, 最大发电与最大供热不可兼得
% 当调度指令落在原始可行域外时, 采用两种策略缩减运行范围:
%   Heat-dependent: 优先满足供热需求 → 缩减发电功率
%   Power-dependent: 优先满足发电需求 → 缩减供热功率
figure('Name', 'Heat/Power Dependent Modes (Fig. 7)', 'Color', 'w', 'Position', [150, 150, 700, 550]);
hold on; grid on;

% 使用演示储热值 (使约束线可见)
Q0_demo = 18;  % 零功率时可用热 [MW], 演示用较小值使约束生效
W_range_pd = linspace(0, W_T_upper, 50);

% 原始可行域 (灰色): 负斜率约束 Q ≤ -β2·W + Q0_demo
Q_orig_bound = min(Q_HG_LG_max, max(0, Q0_demo - beta2 * W_range_pd));
[pd_orig_x, pd_orig_y] = buildFeasiblePolygon(W_T_upper, Q_HG_LG_max, -beta2, Q0_demo, Q0_demo - Q_HTV_upper / dt);
fill(pd_orig_x, pd_orig_y, [0.85 0.85 0.85], 'EdgeColor', 'k', 'LineWidth', 1.5, 'FaceAlpha', 0.25);

% 约束线 (负斜率)
plot(W_range_pd, Q_orig_bound, 'k-', 'LineWidth', 2);

% --- Heat-dependent 模式 (红色): 固定供热需求 8 MW, 缩减发电 ---
Q_fixed_heat = 8;
W_heat_dep = max(0, min(W_T_upper, (Q0_demo - Q_fixed_heat) / beta2));
pd_hd_x = [0, W_heat_dep, W_heat_dep, 0, 0];
pd_hd_y = [0, 0, Q_fixed_heat, Q_fixed_heat, 0];
fill(pd_hd_x, pd_hd_y, [1.0 0.7 0.7], 'EdgeColor', 'r', 'LineWidth', 2, 'FaceAlpha', 0.4);

% --- Power-dependent 模式 (绿色): 固定发电需求 8 MW, 缩减供热 ---
W_fixed_power = 8;
Q_power_dep = max(0, min(Q_HG_LG_max, Q0_demo - beta2 * W_fixed_power));
pd_pd_x = [0, W_fixed_power, W_fixed_power, 0, 0];
pd_pd_y = [0, 0, Q_power_dep, Q_power_dep, 0];
fill(pd_pd_x, pd_pd_y, [0.7 1.0 0.7], 'EdgeColor', 'g', 'LineWidth', 2, 'FaceAlpha', 0.4);

% 标记工作点
plot(W_heat_dep, Q_fixed_heat, 'rs', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
plot(W_fixed_power, Q_power_dep, 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
text(W_heat_dep - 1.5, Q_fixed_heat + 0.6, ...
    {sprintf('Heat-dep.'), sprintf('(%.1fMW,%.0fMW)', W_heat_dep, Q_fixed_heat)}, ...
    'FontSize', 7, 'Color', 'r', 'FontWeight', 'bold');
text(W_fixed_power + 0.3, Q_power_dep - 1.0, ...
    {sprintf('Power-dep.'), sprintf('(%.0fMW,%.1fMW)', W_fixed_power, Q_power_dep)}, ...
    'FontSize', 7, 'Color', 'g', 'FontWeight', 'bold');

xlim([-0.5, W_T_upper + 1.5]);
ylim([-0.5, Q_HG_LG_max + 2]);
xlabel('Discharging Power W_{T,E} [MW]', 'FontSize', 10);
ylabel('Heating Power [MW]', 'FontSize', 10);
title('Heat/Power-dependent Modes (Fig.7)', 'FontSize', 11, 'FontWeight', 'bold');
legend({'Original Feasible', 'Constraint (-\beta_2)', ...
    sprintf('Heat-dep. (fix Q=%.0f MW)', Q_fixed_heat), ...
    sprintf('Power-dep. (fix W=%.0f MW)', W_fixed_power)}, ...
    'Location', 'best', 'FontSize', 8);
set(gca, 'FontSize', 10);

exportgraphics(gcf, fullfile(outDir, 'Fig09_HeatPowerDependent.png'), 'Resolution', 300);

%% ========================================================================
% 11. 可变工况分析 - 透平入口温度影响 (论文 Section 4.2)
% =========================================================================
fprintf('\n--- 可变工况分析: 透平入口温度影响 ---\n');

% 修正后的 β2 (式 31)
T_turb_in_range = 440:5:520;  % 透平入口温度范围
beta2_corrected = zeros(size(T_turb_in_range));
X_range = zeros(size(T_turb_in_range));

for i = 1:length(T_turb_in_range)
    T_in = T_turb_in_range(i);
    lambda = T_in / T_turb_in;  % 温度比 λ = T_in / T_in_ref

    % 式 (31): 修正 γ2 (β2)
    % γ2' = [1 - (1-λ)·T_HR-start / (ΣT_Tin - ΣT_Tout - T_HR-start)] · γ2
    num = (1 - lambda) * States(9,2);
    den = States(10,2) + States(12,2) - States(11,2) - States(9,2);
    beta2_corrected(i) = (1 - num / max(den, 1e-6)) * beta2;

    % 由式 (30) 反算 X
    X_range(i) = max(0, min(1, 1 - beta2_corrected(i) * alpha1 * eta_motor * eta_gen / (beta1 * alpha2)));
end

% --- 图10: 热供应率 X 随透平入口温度变化 ---
figure('Name', 'X and β_2 vs. Turbine Inlet Temperature', 'Color', 'w', 'Position', [150, 150, 700, 450]);
hold on; grid on;
yyaxis left;
plot(T_turb_in_range, X_range*100, 'b-o', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'b');
ylabel('Heat Supply Rate X [%]', 'FontSize', 10);
yyaxis right;
plot(T_turb_in_range, beta2_corrected, 'r-s', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'r');
ylabel('Corrected β_2 [-]', 'FontSize', 10);
xlabel('Turbine Inlet Temperature [K]', 'FontSize', 10);
title('X and β_2 vs. Turbine Inlet Temperature (Section 4.2.1)', 'FontSize', 11, 'FontWeight', 'bold');
legend({'X [%]', 'β_2'}, 'Location', 'best');
xlim([T_turb_in_range(1), T_turb_in_range(end)]);
set(gca, 'FontSize', 10);

exportgraphics(gcf, fullfile(outDir, 'Fig10_X_vs_Temp.png'), 'Resolution', 300);

% --- 图11: T-P 循环状态图 (储能/释能分左右对比) ---
figure('Name', 'CCES-CHP T-P Diagram', 'Color', 'w', 'Position', [100, 150, 1400, 550]);

T_charge = States(1:7, 2);
P_charge = States(1:7, 3);
T_discharge = States(8:15, 2);
P_discharge = States(8:15, 3);

% ---- 左图: 储能/充电过程 ----
subplot(1,2,1);
hold on; grid on; grid minor;

plot(T_charge, P_charge, '-ro', 'LineWidth', 2.5, 'MarkerSize', 9, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r');
plot(T_crit, P_crit, 'p', 'MarkerSize', 16, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');

labels_charge = {'1,2', '', '3', '4', '5', '6', '7'};
T_off_C =  [  -25,   0,   4,   4, -20,  18, -18];
P_mul_C =  [ 0.70,   0, 1.15,1.15,1.08,0.88,0.88];
for i = 1:length(T_charge)
    if i == 2, continue; end
    text(T_charge(i) + T_off_C(i), P_charge(i) * P_mul_C(i), labels_charge{i}, ...
        'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.7 0 0], ...
        'BackgroundColor', 'w', 'Margin', 1);
end
text(T_crit - 50, P_crit * 1.25, 'Critical Point', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0.6 0]);

set(gca, 'YScale', 'log');
yticks([0.1, 0.5, 1, 5, 10]);
yticklabels({'0.1', '0.5', '1.0', '5.0', '10.0'});
xlim([270, 520]);
ylim([0.08, 12]);

title('Charging Process (Compression/Liquefaction)', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Temperature T [K]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Pressure P [MPa]', 'FontSize', 10, 'FontWeight', 'bold');
set(gca, 'FontSize', 10, 'LineWidth', 1.2);
box on;

% ---- 右图: 释能/发电过程 ----
subplot(1,2,2);
hold on; grid on; grid minor;

plot(T_discharge, P_discharge, '--bs', 'LineWidth', 2.5, 'MarkerSize', 9, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'b');
plot(T_crit, P_crit, 'p', 'MarkerSize', 16, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');

labels_discharge = {'8', '9', '10', '11', '12', '13', '14', '15'};
T_off_D =  [  -18,  20,   4,   4,   4,   4,  20,   4];
P_mul_D =  [ 0.88,1.10,0.82,0.85,0.85,0.85,0.78,0.70];
for i = 1:length(T_discharge)
    text(T_discharge(i) + T_off_D(i), P_discharge(i) * P_mul_D(i), labels_discharge{i}, ...
        'FontSize', 8, 'FontWeight', 'bold', 'Color', [0 0 0.7], ...
        'BackgroundColor', 'w', 'Margin', 1);
end
text(T_crit - 50, P_crit * 1.25, 'Critical Point', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0.6 0]);

set(gca, 'YScale', 'log');
yticks([0.1, 0.5, 1, 5, 10]);
yticklabels({'0.1', '0.5', '1.0', '5.0', '10.0'});
xlim([270, 520]);
ylim([0.08, 12]);

title('Discharging Process (Expansion/Generation)', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Temperature T [K]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Pressure P [MPa]', 'FontSize', 10, 'FontWeight', 'bold');
set(gca, 'FontSize', 10, 'LineWidth', 1.2);
box on;

exportgraphics(gcf, fullfile(outDir, 'Fig11_TP_Diagram.png'), 'Resolution', 300);

% --- 图12: T-s (温度-熵) 循环状态图 (储能/释能分左右对比) ---
figure('Name', 'CCES-CHP T-s Diagram', 'Color', 'w', 'Position', [100, 150, 1400, 550]);

s_charge = States(1:7, 5);
s_discharge = States(8:15, 5);

% ---- 左图: 储能/充电过程 ----
subplot(1,2,1);
hold on; grid on;

plot(s_charge, T_charge, '-ro', 'LineWidth', 2.5, 'MarkerSize', 9, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r');
plot(s_crit, T_crit, 'p', 'MarkerSize', 16, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');

s_off_C = [-0.06, 0, 0.02, 0.02, 0.02, -0.08, 0.02];
T_off_Cs= [  -15, 0,   10,   -6,   10,  -12,  -12];
for i = 1:length(s_charge)
    if i == 1
        text(s_charge(i) + s_off_C(i), T_charge(i) + T_off_Cs(i), '1,2', ...
            'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.7 0 0], ...
            'BackgroundColor', 'w', 'Margin', 1);
    elseif i > 2
        text(s_charge(i) + s_off_C(i), T_charge(i) + T_off_Cs(i), labels_charge{i}, ...
            'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.7 0 0], ...
            'BackgroundColor', 'w', 'Margin', 1);
    end
end
text(s_crit - 0.18, T_crit + 15, 'Critical Point', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0.6 0]);

xlabel('Specific Entropy s [kJ/(kg.K)]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Temperature T [K]', 'FontSize', 10, 'FontWeight', 'bold');
title('Charging Process (Compression/Liquefaction)', 'FontSize', 11, 'FontWeight', 'bold');
set(gca, 'FontSize', 10, 'LineWidth', 1.2);
box on;

% ---- 右图: 释能/发电过程 ----
subplot(1,2,2);
hold on; grid on;

plot(s_discharge, T_discharge, '--bs', 'LineWidth', 2.5, 'MarkerSize', 9, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'b');
plot(s_crit, T_crit, 'p', 'MarkerSize', 16, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');

s_off_D = [ 0.02,-0.08, 0.02, 0.02,-0.08, 0.02, 0.02,-0.06];
T_off_Ds= [  -12,  -10,  -12,  -16,  -10,    8,  -16,   10];
for i = 1:length(s_discharge)
    text(s_discharge(i) + s_off_D(i), T_discharge(i) + T_off_Ds(i), labels_discharge{i}, ...
        'FontSize', 8, 'FontWeight', 'bold', 'Color', [0 0 0.7], ...
        'BackgroundColor', 'w', 'Margin', 1);
end
text(s_crit - 0.18, T_crit + 15, 'Critical Point', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0.6 0]);

xlabel('Specific Entropy s [kJ/(kg.K)]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Temperature T [K]', 'FontSize', 10, 'FontWeight', 'bold');
title('Discharging Process (Expansion/Generation)', 'FontSize', 11, 'FontWeight', 'bold');
set(gca, 'FontSize', 10, 'LineWidth', 1.2);
box on;

exportgraphics(gcf, fullfile(outDir, 'Fig12_Ts_Diagram.png'), 'Resolution', 300);

% --- 图13: p-h (压-焓) 循环状态图 (储能/释能分左右对比) ---
figure('Name', 'CCES-CHP p-h Diagram', 'Color', 'w', 'Position', [100, 150, 1400, 550]);

h_charge = States(1:7, 4);
h_discharge = States(8:15, 4);

% ---- 左图: 储能/充电过程 ----
subplot(1,2,1);
hold on; grid on;

plot(h_charge, P_charge, '-ro', 'LineWidth', 2.5, 'MarkerSize', 9, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r');
plot(h_crit, P_crit, 'p', 'MarkerSize', 16, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');

h_offset_C = [ -35,   0,   8,   8,   8, -40, -35];
P_mult_Ch  = [0.65,   0, 1.30,1.30,1.10,1.30,0.65];
for i = 1:length(h_charge)
    if i == 1
        text(h_charge(i) + h_offset_C(i), P_charge(i) * P_mult_Ch(i), '1,2', ...
            'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.7 0 0]);
    elseif i > 2
        text(h_charge(i) + h_offset_C(i), P_charge(i) * P_mult_Ch(i), labels_charge{i}, ...
            'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.7 0 0]);
    end
end
text(h_crit + 15, P_crit * 1.5, 'Critical Point', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0.6 0]);

set(gca, 'YScale', 'log');
yticks([0.1, 0.5, 1, 5, 10]);
yticklabels({'0.1', '0.5', '1.0', '5.0', '10.0'});
ylim([0.08, 12]);

xlabel('Specific Enthalpy h [kJ/kg]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Pressure P [MPa]', 'FontSize', 10, 'FontWeight', 'bold');
title('Charging Process (Compression/Liquefaction)', 'FontSize', 11, 'FontWeight', 'bold');
set(gca, 'FontSize', 10, 'LineWidth', 1.2);
box on;

% ---- 右图: 释能/发电过程 ----
subplot(1,2,2);
hold on; grid on;

plot(h_discharge, P_discharge, '--bs', 'LineWidth', 2.5, 'MarkerSize', 9, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'b');
plot(h_crit, P_crit, 'p', 'MarkerSize', 16, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');

h_offset_D = [   8, -40,    8,    8, -40,    8,   15,  -30];
P_mult_Dh  = [0.70,0.70, 0.80, 0.75, 0.88, 0.85, 0.65, 0.65];
for i = 1:length(h_discharge)
    text(h_discharge(i) + h_offset_D(i), P_discharge(i) * P_mult_Dh(i), labels_discharge{i}, ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', [0 0 0.7]);
end
text(h_crit + 15, P_crit * 1.5, 'Critical Point', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0.6 0]);

set(gca, 'YScale', 'log');
yticks([0.1, 0.5, 1, 5, 10]);
yticklabels({'0.1', '0.5', '1.0', '5.0', '10.0'});
ylim([0.08, 12]);

xlabel('Specific Enthalpy h [kJ/kg]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Pressure P [MPa]', 'FontSize', 10, 'FontWeight', 'bold');
title('Discharging Process (Expansion/Generation)', 'FontSize', 11, 'FontWeight', 'bold');
set(gca, 'FontSize', 10, 'LineWidth', 1.2);
box on;

exportgraphics(gcf, fullfile(outDir, 'Fig13_ph_Diagram.png'), 'Resolution', 300);

% --- 图S1: CO2 p-h 饱和曲线 (饱和液线 + 饱和汽线 + 两相区) ---
figure('Name', 'CO2 p-h Saturation Curve', 'Color', 'w', 'Position', [150, 150, 750, 600]);
hold on; grid on;

fill([h_liq_sat, fliplr(h_vap_sat)], [P_sat_arr, fliplr(P_sat_arr)], ...
    [0.85 0.92 1.0], 'FaceAlpha', 0.35, 'EdgeColor', 'none');
plot(h_liq_sat, P_sat_arr, 'b-', 'LineWidth', 2.5);
plot(h_vap_sat, P_sat_arr, 'r-', 'LineWidth', 2.5);
plot(h_crit, P_crit, 'p', 'MarkerSize', 16, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');
text(h_crit - 40, P_crit * 1.5, 'Critical Point', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0.6 0]);

set(gca, 'YScale', 'log');
yticks([0.1, 0.5, 1, 5, 10]);
yticklabels({'0.1', '0.5', '1.0', '5.0', '10.0'});
ylim([0.1, 12]);

xlabel('Specific Enthalpy h [kJ/kg]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Pressure P [MPa]', 'FontSize', 10, 'FontWeight', 'bold');
title('CO_2 p-h Saturation Curve', 'FontSize', 11, 'FontWeight', 'bold');
legend({'Two-Phase Region', 'Saturated Liquid', 'Saturated Vapor', 'Critical Point'}, ...
    'Location', 'best');
set(gca, 'FontSize', 10, 'LineWidth', 1.2);
box on;

exportgraphics(gcf, fullfile(outDir, 'FigS1_ph_Saturation.png'), 'Resolution', 300);

% --- 图S2: CO2 T-s 饱和曲线 (饱和液线 + 饱和汽线 + 两相区) ---
figure('Name', 'CO2 T-s Saturation Curve', 'Color', 'w', 'Position', [150, 150, 750, 600]);
hold on; grid on;

fill([s_liq_sat, fliplr(s_vap_sat)], [T_sat_range, fliplr(T_sat_range)], ...
    [0.85 0.92 1.0], 'FaceAlpha', 0.35, 'EdgeColor', 'none');
plot(s_liq_sat, T_sat_range, 'b-', 'LineWidth', 2.5);
plot(s_vap_sat, T_sat_range, 'r-', 'LineWidth', 2.5);
plot(s_crit, T_crit, 'p', 'MarkerSize', 16, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');
text(s_crit - 0.3, T_crit + 12, 'Critical Point', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0.6 0]);

xlabel('Specific Entropy s [kJ/(kg.K)]', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Temperature T [K]', 'FontSize', 10, 'FontWeight', 'bold');
title('CO_2 T-s Saturation Curve', 'FontSize', 11, 'FontWeight', 'bold');
legend({'Two-Phase Region', 'Saturated Liquid', 'Saturated Vapor', 'Critical Point'}, ...
    'Location', 'best');
set(gca, 'FontSize', 10, 'LineWidth', 1.2);
box on;

exportgraphics(gcf, fullfile(outDir, 'FigS2_Ts_Saturation.png'), 'Resolution', 300);

% --- 图12: 不同负荷比下的运行可行域变化 (论文 Fig. 12 比较) ---
figure('Name', 'Feasibility Domain: Load Ratio (Fig. 12 comparison)', 'Color', 'w', 'Position', [50, 50, 1100, 450]);

% Scenario A: 较低电负荷 (峰值 32 MW)
% Scenario B: 较高电负荷 (峰值 48 MW) - 默认已模拟
scenarios = {'Scenario A (Peak 32MW)', 'Scenario B (Peak 48MW)'};

for sc = 1:2
    subplot(1, 2, sc);
    hold on; grid on;

    % 选取代表性时刻
    hours_plot = [1, 8, 12, 15, 20, 23];
    colors = lines(length(hours_plot));

    for j = 1:length(hours_plot)
        t_h = hours_plot(j);
        if t_h == 1
            Q_cur = Q_HTV_0;
            P_cur = P_HPT_0;
        else
            Q_cur = Q_HTV_array(min(t_h-1, N_hours));
            P_cur = P_HPT_array(min(t_h-1, N_hours));
        end

        if sc == 1  % Scenario A: 较低电负荷, 更多储热
            W_max_use = W_T_upper;
            Q_cur_use = Q_cur * 1.2;
        else
            W_max_use = W_T_upper;
            Q_cur_use = Q_cur;
        end

        % 放电可行域: 负斜率 -eta_2
        b_upper = max(0, (Q_cur_use - Q_HTV_lower) / dt);
        b_lower = (Q_cur_use - Q_HTV_upper) / dt;
        [px_do, py_do] = buildFeasiblePolygon(W_max_use, Q_HG_LG_max, -beta2, b_upper, b_lower);

        plot(px_do, py_do, '-', 'Color', colors(j,:), ...
            'LineWidth', 2);
        % 标签沿多边形右边界垂直错开, 避免重叠
        x_label = max(px_do) + 0.2;
        y_label = max(py_do) * (1 - (j-1) * 0.12);
        text(x_label, y_label, sprintf('h%d', t_h), ...
            'FontSize', 8, 'Color', colors(j,:), 'FontWeight', 'bold');
    end

    xlim([-0.5, W_T_upper + 2]);
    ylim([-0.5, Q_HG_LG_max + 3]);
    xlabel('Electric Power [MW]', 'FontSize', 10);
    ylabel('Heating Power [MW]', 'FontSize', 10);
    title(scenarios{sc}, 'FontSize', 10, 'FontWeight', 'bold');
    set(gca, 'FontSize', 10);
end
sgtitle('Feasibility Domain under Different Load Ratios (Fig. 12)', 'FontSize', 11, 'FontWeight', 'bold');

exportgraphics(gcf, fullfile(outDir, 'Fig14_LoadRatio.png'), 'Resolution', 300);

%% ========================================================================
% 12. 输出总结
% =========================================================================
fprintf('\n====================================================================\n');
fprintf('    CCES-CHP 运行可行域分析程序 运行完毕\n');
fprintf('====================================================================\n');
fprintf('主要输出图形:\n');
fprintf('  1. 充电-供热运行可行域 (Fig. 3)\n');
fprintf('  2. 放电-供热运行可行域 (Fig. 4)\n');
fprintf('  3. 负荷与风电曲线 (Fig. 8)\n');
fprintf('  4. CCES-CHP调度与实际运行 (Fig. 9)\n');
fprintf('  5. 综合能源系统电力平衡 (Fig. 10)\n');
fprintf('  6. 综合能源系统热力平衡 (Fig. 11)\n');
fprintf('  7. 双SOC变化曲线\n');
fprintf('  8. 24小时运行可行域变化 (Fig. 12)\n');
fprintf('  9. Heat/Power Dependent模式 (Fig. 7)\n');
fprintf('  10. 热供应率随透平入口温度变化\n');
fprintf('  11. CCES-CHP T-P 循环状态图\n');
fprintf('  12. CCES-CHP T-s (温-熵) 循环状态图\n');
fprintf('  13. CCES-CHP p-h (压-焓) 循环状态图\n');
fprintf('  14. 不同负荷比下运行可行域比较\n');
fprintf('====================================================================\n');

% =========================================================================
% 辅助函数: 构建可行域多边形 (矩形与两条约束线的交集)
% =========================================================================
function [px, py] = buildFeasiblePolygon(W_max, Q_max, slope, b_upper, b_lower)
    % 矩形: W in [0, W_max], Q in [0, Q_max]
    % 上约束: Q <= slope*W + b_upper
    % 下约束: Q >= slope*W + b_lower
    %
    % 返回: 按逆时针排列的多边形顶点 [px, py]

    % 收集候选点: 矩形4角 + 约束线与矩形各边的交点
    pts_W = []; pts_Q = [];

    % 矩形四角
    corners_W = [0; W_max; W_max; 0];
    corners_Q = [0; 0; Q_max; Q_max];

    % 上约束线与矩形四边的交点
    % Q = slope*W + b_upper
    % 边1: W=0, Q in [0,Qmax]  -> W=0, Q=b_upper
    if b_upper >= 0 && b_upper <= Q_max
        pts_W(end+1) = 0; pts_Q(end+1) = b_upper;
    end
    % 边2: W=Wmax, Q in [0,Qmax] -> W=Wmax, Q=slope*Wmax+b_upper
    q_temp = slope * W_max + b_upper;
    if q_temp >= 0 && q_temp <= Q_max
        pts_W(end+1) = W_max; pts_Q(end+1) = q_temp;
    end
    % 边3: Q=Qmax, W in [0,Wmax] -> W=(Qmax-b_upper)/slope, Q=Qmax
    if abs(slope) > 1e-12
        w_temp = (Q_max - b_upper) / slope;
        if w_temp >= 0 && w_temp <= W_max
            pts_W(end+1) = w_temp; pts_Q(end+1) = Q_max;
        end
    end
    % 边4: Q=0, W in [0,Wmax] -> W=-b_upper/slope, Q=0
    if abs(slope) > 1e-12
        w_temp = -b_upper / slope;
        if w_temp >= 0 && w_temp <= W_max
            pts_W(end+1) = w_temp; pts_Q(end+1) = 0;
        end
    end

    % 下约束线与矩形四边的交点
    % Q = slope*W + b_lower
    % 边1: W=0
    if b_lower >= 0 && b_lower <= Q_max
        pts_W(end+1) = 0; pts_Q(end+1) = b_lower;
    end
    % 边2: W=Wmax
    q_temp = slope * W_max + b_lower;
    if q_temp >= 0 && q_temp <= Q_max
        pts_W(end+1) = W_max; pts_Q(end+1) = q_temp;
    end
    % 边3: Q=Qmax
    if abs(slope) > 1e-12
        w_temp = (Q_max - b_lower) / slope;
        if w_temp >= 0 && w_temp <= W_max
            pts_W(end+1) = w_temp; pts_Q(end+1) = Q_max;
        end
    end
    % 边4: Q=0
    if abs(slope) > 1e-12
        w_temp = -b_lower / slope;
        if w_temp >= 0 && w_temp <= W_max
            pts_W(end+1) = w_temp; pts_Q(end+1) = 0;
        end
    end

    % 筛选: 保留所有同时满足上下约束且在矩形内的点
    keep = false(size(pts_W));
    tol = 1e-10;  % 数值容差
    for k = 1:length(pts_W)
        w = pts_W(k); q = pts_Q(k);
        % 检查上约束: Q <= slope*W + b_upper + tol
        % 检查下约束: Q >= slope*W + b_lower - tol
        if q <= slope * w + b_upper + tol && q >= slope * w + b_lower - tol
            keep(k) = true;
        end
    end
    pts_W = pts_W(keep);
    pts_Q = pts_Q(keep);

    % 添加矩形的有效角点
    for k = 1:4
        w = corners_W(k); q = corners_Q(k);
        if q <= slope * w + b_upper + tol && q >= slope * w + b_lower - tol
            pts_W(end+1) = w;
            pts_Q(end+1) = q;
        end
    end

    % 去重 (容差1e-8)
    all_pts = [pts_W(:), pts_Q(:)];
    all_pts = uniquetol(all_pts, 1e-8, 'ByRows', true);

    if size(all_pts, 1) < 3
        % 退化为空或线段: 返回最小三角形
        px = [0; 0; 0.01]; py = [0; 0; 0.01];
        return;
    end

    % 按极角排序 (绕中心逆时针)
    center = mean(all_pts, 1);
    angles = atan2(all_pts(:,2) - center(2), all_pts(:,1) - center(1));
    [~, idx] = sort(angles);
    all_pts = all_pts(idx, :);

    % 闭合多边形
    px = [all_pts(:,1); all_pts(1,1)];
    py = [all_pts(:,2); all_pts(1,2)];
end
