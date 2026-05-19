% =========================================================================
% CCES_parameters.m — CCES-CHP 系统仿真参数定义
% =========================================================================

%% 工作流体与物性接口
params.Fluid = 'CO2';
params.libLoc = '/opt/refprop/';

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

%% 储罐参数
params.V_HPT = 500;         % HPT 容积 [m^3]
params.V_LPT = 2000;        % LPT 容积 [m^3]（低压侧容积更大）
params.Rg_CO2 = 188.9;      % CO2 气体常数 [J/(kg·K)] (与 Pa 单位一致)
params.T_HPT_store = 298;   % HPT 存储温度 [K]

%% 蓄热系统参数
params.Q_HTV_capacity = 150 * 3600;  % HTV 蓄热容量 [MJ_th] (=150 MWh_th)
params.Q_HTV_initial   = 50 * 3600;   % 初始蓄热量 [MJ_th]
params.T_HTV_max = 573;    % 导热油最高温度 [K]
params.T_ATV = 298;        % 冷导热油温度 [K]

%% 无量纲耦合系数（来自 Cycle.m 稳态设计点，全回路流量）
% α: 质量流量/电功率   β: 热量/电功率
% 注意: α 是全回路(压气机/透平)流量系数，非 HPT 净储/释流量
%       满功率时 m_dot_circuit = alpha*W_design (kg/s)
%       HPT 作为回路高压侧缓冲罐，约束了满功率持续时长
params.beta1  = 1.185;     % Q_IC / W_C_E = 压缩热/充电功率比
params.beta2  = 2.307;     % Q_HR / W_T_E = 回热/放电功率比
params.alpha1 = 2.744;     % m_charge / W_C_E = 2.744 kg/(s·MW) (全回路)
params.alpha2 = 4.117;     % m_discharge / W_T_E = 4.117 kg/(s·MW) (全回路)

%% 设计参数 (来自论文 Hao et al., Energy 2024)
params.W_design = 10;           % 设计充放电功率 [MW]
params.t_charge_design = 7.5;   % 设计充电时长 [h] (可用时间窗口)
params.t_discharge_design = 5.0;% 设计放电时长 [h] (可用时间窗口)

% HPT 储罐约束: 满功率 10MW 时 α1*W=27.4kg/s → 充满 ~36min
% 因此系统不能连续满功率运行 7.5h，功率必须被 HPT 压力约束调制
% 论文的可行性域方法正是用来处理这种功率-容量耦合约束

%% 仿真参数 (可自定义调度场景)
params.dt_sim = 60;        % 仿真时间步长 [s]
params.t_charge = 6 * 3600; % 预设充电时长 [s]
params.t_idle = 2 * 3600;   % 预设闲置时长 [s]
params.t_discharge = 6 * 3600; % 预设放电时长 [s]
params.t_total = params.t_charge + params.t_idle + params.t_discharge;
