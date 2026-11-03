% =========================================================================
% CCES_parameters.m — CCES-CHP 系统仿真参数定义
%
% [已弃用] 当前主线参数请用 src/ode/cces_design_point.m（REFPROP 现算）。
% 本文件仅供 src/ode/archive/ 下的早期脚本引用，数值已与之对齐。
% =========================================================================

%% 工作流体与物性接口
params.Fluid = 'CO2';
addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
cfg = config_paths();
params.libLoc = cfg.REFPROP_LIB;

%% 设计点参数（来自 Cycle.m 标定工况，全部使用 SI 单位）
params.T_amb   = 298;         % 环境温度 [K]
params.P_amb   = 0.102e6;     % 环境压力 [Pa] = 0.102 MPa
params.m_charge_design = 26.9;    % 设计充电质量流量 [kg/s]
params.m_discharge_design = 40.3; % 设计放电质量流量 [kg/s]

%% 压气机参数
params.eta_c   = 0.85;      % 等熵效率
params.eta_motor = 0.98;    % 电机机械效率

%% 透平参数
params.eta_t   = 0.88;      % 等熵效率
params.eta_gen  = 0.95;     % 发电机效率

%% 换热器参数（设计点出口温度）
params.T_IC1_out = 308;     % IC1 出口温度 [K]
params.T_IC2_out = 309;     % IC2 出口温度 [K]
params.T_LHE_out = 298;     % LHE 出口温度 [K]
params.T_EHE_out = 483;     % EHE+HR1 出口温度 [K]
params.T_HR2_out = 483;     % HR2 出口温度 [K]
params.T_AEHE_out = 303;    % AE-HE 出口温度 [K]
params.T_cooler_out = 298;  % Cooler 出口温度 [K]

%% 压力参数 [Pa] — getFluidProperty 'MASS BASE SI' 要求使用 Pa
params.P_C1_out = 0.90e6;     % C1 出口 [Pa] = 0.90 MPa
params.P_IC1_out = 0.85e6;    % IC1 出口 (含压降)
params.P_C2_out = 6.90e6;     % C2 出口 [Pa] = 6.90 MPa
params.P_IC2_out = 6.85e6;    % IC2 出口
params.P_HPT_nom = 6.80e6;    % HPT 额定 [Pa] = 6.80 MPa
params.P_T1_in  = 6.50e6;     % T1 入口
params.P_T1_out = 0.70e6;     % T1 出口 [Pa] = 0.70 MPa
params.P_T2_in  = 0.65e6;     % T2 入口
params.P_T2_out = 0.12e6;     % T2 出口 [Pa] = 0.12 MPa
params.P_AEHE_out = 0.102e6;  % AE-HE 出口 [Pa]
params.P_LPT_nom = 0.102e6;   % LPT 额定 [Pa] = 0.102 MPa

%% 储罐参数（室温液态储存：V = m/ρ_l，不再用理想气体公式）
% m_full = alpha2*W*t_d/(SOC_max-SOC_min) = 4.191*10*5*3600/0.8 = 943 t
% V_HPT = 943000/ρ_l(298K,6.8MPa) ≈ 1280 m³
params.V_HPT = 1280;        % HPT 容积 [m^3]（定压液态，满液 943 t）
params.V_LPT = 10000;       % LPT 容积 [m^3] (低压侧需更大)
params.Rg_CO2 = 188.9;      % CO2 气体常数 [J/(kg·K)] (与 Pa 单位一致)
params.T_HPT_store = 298;   % HPT 存储温度 [K]

%% 蓄热系统参数
params.Q_HTV_capacity = 150 * 3600;  % HTV 蓄热容量 [MJ_th] (=150 MWh_th)
params.Q_HTV_initial   = 75 * 3600;   % 初始蓄热量 [MJ_th] (=75 MWh_th, 50% SOC)
params.T_HTV_max = 495;    % 导热油最高温度 [K]（论文 Table 1）
params.T_ATV = 298;        % 冷导热油温度 [K]

%% 无量纲耦合系数（来自 Cycle.m 稳态设计点，全回路流量）
% α: 质量流量/电功率   β: 热量/电功率
% 注意: α 是全回路(压气机/透平)流量系数，非 HPT 净储/释流量
%       满功率时 m_dot_circuit = alpha*W_design (kg/s)
%       HPT 作为回路高压侧缓冲罐，约束了满功率持续时长
params.beta1  = 1.205;     % Q_IC / W_C_E = 压缩热/充电功率比
params.beta2  = 1.659;     % Q_HR / W_T_E = 回热/放电功率比（不含 EHE 潜热）
params.alpha1 = 2.762;     % m_charge / W_C_E = kg/(s·MW)
params.alpha2 = 4.191;     % m_discharge / W_T_E = kg/(s·MW)

%% 设计参数 (来自论文 Hao et al., Energy 2024)
params.W_design = 10;           % 设计充放电功率 [MW]
params.t_charge_design = 7.5;   % 设计充电时长 [h] (可用时间窗口)
params.t_discharge_design = 5.0;% 设计放电时长 [h] (可用时间窗口)

% HPT 按 5 h 满功率放电标定：满液 943 t，10 MW 放电约 7.59 h 充满
% 运行窗口取 SOC 10%~90%，因此充放电时长由质量守恒反解（见 cces_design_point）

%% 仿真参数 (可自定义调度场景)
params.dt_sim = 60;        % 仿真时间步长 [s]
params.t_charge = 6 * 3600; % 预设充电时长 [s]
params.t_idle = 2 * 3600;   % 预设闲置时长 [s]
params.t_discharge = 6 * 3600; % 预设放电时长 [s]
params.t_total = params.t_charge + params.t_idle + params.t_discharge;
