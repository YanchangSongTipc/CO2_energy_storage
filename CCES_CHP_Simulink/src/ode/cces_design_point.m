function dp = cces_design_point(Th, opts)
%CCES_DESIGN_POINT  CCES-CHP 设计点与循环闭合参数的唯一来源
%
%   dp = cces_design_point(Th)  以透平入口温度 Th [K]（默认 483 K）为输入，
%   用 REFPROP 计算每 kg 工质的功/热，并给出满足下列两个闭合条件的
%   充放电时长与对外供热功率：
%
%       (1) 质量闭合   m_c*t_c = m_d*t_d                -> HPT 存量不漂移
%       (2) 热量闭合   Q_IC*t_c = (Q_HR+Q_export)*t_d   -> HTV 蓄热不漂移
%
%   三个调用方（ode_dynamics / run_ode_simulation / 绘图）共用本函数，
%   避免"参数各写一份"导致的漂移。
%
%   与论文的差异（有意为之）：
%     - 放电侧 EHE 的蒸发潜热单独列出，不计入 γ2（论文 2.1 节：先汽化再回热）
%     - 储罐按"定压室温液态"处理，储气 SOC 用液位（质量）表示，不用理想气体压力

if nargin < 1 || isempty(Th), Th = 483; end
if nargin < 2 || isempty(opts), opts = struct(); end

rootDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..');
addpath(rootDir);
cfg = config_paths();
lib = cfg.REFPROP_LIB;  Fluid = 'CO2';
g = @(varargin) getFluidProperty(lib, varargin{:}, Fluid, 1, 1, 'MASS BASE SI');

% ---------------- 设计常数（论文 Table 1） ----------------
dp.Th        = Th;      % 透平入口温度 [K]
dp.T_amb     = 298;     % 环境温度 / HPT 储存温度 [K]
dp.T_oil_hot = 495;     % HTV 导热油高温 [K]
dp.eta_c     = 0.85;    % 压气机等熵效率
dp.eta_t     = 0.88;    % 透平等熵效率
dp.eta_motor = 0.98;
dp.eta_gen   = 0.95;
dp.W_charge    = 10;    % MW
dp.W_discharge = 10;    % MW
dp.t_discharge = 5.0;   % h（设计放电时长）
dp.Q_HTV_cap   = 150;   % MWh_th
dp.P_HPT       = 6.80;  % MPa（定压液态储罐，由泵/背压维持）
dp.SOC_gas_min = 0.10;  % 储液下限（防抽空）
dp.SOC_gas_max = 0.90;  % 储液上限（防满罐）
dp.SOC_heat_0  = 0.30;  % HTV 初始 SOC（需留出整循环调节空间）

% ---------------- 可选覆盖（供 design_sweep_multi 做多参数扫描） ----------------
% 缺省时与旧行为完全一致；论文基准点 rP = 1。
if isfield(opts, 'eta_c'), dp.eta_c = opts.eta_c; end
if isfield(opts, 'eta_t'), dp.eta_t = opts.eta_t; end
if isfield(opts, 'T_amb'), dp.T_amb = opts.T_amb; end
if isfield(opts, 'P_HPT'), dp.P_HPT = opts.P_HPT; end
rP = dp.P_HPT / 6.80;   % 高压侧压力按 P_HPT 等比缩放

% ---------------- 充电侧：每 kg 工质 ----------------
h1 = g('H','P',0.102e6,'T',298);  s1 = g('S','P',0.102e6,'T',298);
h3is = g('H','P',0.90e6,'S',s1);  h3 = h1 + (h3is-h1)/dp.eta_c;
h4 = g('H','P',0.85e6,'T',308);   s4 = g('S','P',0.85e6,'T',308);
h5is = g('H','P',6.90e6*rP,'S',s4);  h5 = h4 + (h5is-h4)/dp.eta_c;
h6 = g('H','P',6.85e6*rP,'T',309);
dp.w_c  = ((h3-h1)+(h5-h4))/1000;      % kJ/kg 轴功
dp.q_IC = ((h3-h4)+(h5-h6))/1000;      % kJ/kg 压缩热

% ---------------- 放电侧：每 kg 工质 ----------------
h8 = g('H','P',6.65e6*rP,'T',296);  h9 = h8;               % V2 等焓节流
h10 = g('H','P',6.50e6*rP,'T',Th);
s10 = g('S','P',6.50e6*rP,'T',Th);
h11is = g('H','P',0.70e6,'S',s10);  h11 = h10 - dp.eta_t*(h10-h11is);
h12 = g('H','P',0.65e6,'T',Th);
s12 = g('S','P',0.65e6,'T',Th);
h13is = g('H','P',0.12e6,'S',s12);  h13 = h12 - dp.eta_t*(h12-h13is);

% EHE：节流后等压汽化 +5 K，热源为环境/低品位热，不属于回热（不计入 γ2）
P_EHE = 6.60e6*rP;
P_CRIT = 7.38e6;                       % CO2 临界压力
if P_EHE < P_CRIT
    T_EHE_sat = g('T','P',P_EHE,'Q',0);
    dp.T_EHE_out = T_EHE_sat + 5;
else
    % 高压侧超过临界压力时没有相变，EHE 退化为拟临界加热：
    % 出口温度取 Tc + 5 K，与亚临界侧（T_sat -> Tc）连续衔接。
    dp.T_EHE_out = 304.1 + 5;
end
h_EHE = g('H','P',P_EHE,'T',dp.T_EHE_out);
dp.q_EHE = (h_EHE - h9)/1000;                  % kJ/kg
dp.q_HR  = ((h10-h_EHE)+(h12-h11))/1000;       % kJ/kg 仅 HR1+HR2
dp.w_t   = ((h10-h11)+(h12-h13))/1000;         % kJ/kg 轴功

h14 = g('H','P',0.102e6,'T',303);
dp.q_AE_HE = (h13 - h14)/1000;                 % kJ/kg 膨胀后废热 (AE-HE)

% ---------------- 无量纲参数（论文式 18-21） ----------------
dp.w_cE   = dp.w_c/dp.eta_motor;
dp.w_tE   = dp.w_t*dp.eta_gen;
dp.alpha1 = 1000/dp.w_cE;      % kg/(s·MW)
dp.alpha2 = 1000/dp.w_tE;
dp.gamma1 = dp.q_IC/dp.w_cE;
dp.gamma2 = dp.q_HR/dp.w_tE;
dp.gamma_AE = dp.q_AE_HE/dp.w_tE;
dp.Q_max_heat = dp.gamma1*dp.W_charge;   % 设备供热上限 (论文 Q_HG-LG,max)

% ---------------- 循环闭合（质量 + 热量） ----------------
dp.m_charge    = dp.alpha1*dp.W_charge;                 % kg/s
dp.m_discharge = dp.alpha2*dp.W_discharge;              % kg/s
dp.M_cycle     = dp.m_discharge*dp.t_discharge*3600;    % kg/循环
dp.t_charge    = dp.M_cycle/(dp.m_charge*3600);         % h  ← 质量闭合
dp.Q_IC_rate   = dp.gamma1*dp.W_charge;                 % MW
dp.Q_HR_rate   = dp.gamma2*dp.W_discharge;              % MW
dp.Q_export    = (dp.Q_IC_rate*dp.t_charge - dp.Q_HR_rate*dp.t_discharge) ...
                 / dp.t_discharge;                      % MW ← 热量闭合
dp.X = dp.Q_export*dp.t_discharge/(dp.Q_IC_rate*dp.t_charge);  % 热供应率
dp.Y = 1 - dp.X;
dp.eta_elec_cycle = dp.W_discharge*dp.t_discharge ...
                    / (dp.W_charge*dp.t_charge)*100;    % 电-电效率 [%]
dp.eta_heat_LG = dp.X*dp.gamma1*100;                     % 低温供热效率 [%]
dp.eta_heat_AE = dp.gamma_AE*dp.W_discharge*dp.t_discharge ...
                 / (dp.W_charge*dp.t_charge)*100;        % 废热供热效率 [%]
dp.eta_heat    = dp.eta_heat_LG + dp.eta_heat_AE;        % 总供热效率 [%]

% ---------------- 储罐尺寸（由循环量反推） ----------------
dp.rho_l  = g('D','P',dp.P_HPT*1e6,'T',dp.T_amb);       % kg/m3
dp.m_full = dp.M_cycle/(dp.SOC_gas_max - dp.SOC_gas_min);
dp.V_HPT  = dp.m_full/dp.rho_l;
dp.m0     = dp.SOC_gas_min*dp.m_full;   % 周期从充电段开始, 故初值取下限

dp.rho_cp_oil  = 850*2.5;                               % kJ/(m3·K)
dp.dT_oil      = dp.T_oil_hot - dp.T_amb;
dp.V_HTV       = dp.Q_HTV_cap*3600*1000/(dp.rho_cp_oil*dp.dT_oil);
dp.Q_HTV_swing = dp.Q_IC_rate*dp.t_charge;              % MWh
% 初始 SOC 自适应：基准点仍为 0.30；当参数扫描使循环摆幅变大时，
% 自动下移起点，保证充电后不溢出（该值只影响初值，不影响 γ/α/η/X）。
dp.SOC_heat_0  = min(dp.SOC_heat_0, ...
                     max(0, (0.98*dp.Q_HTV_cap - dp.Q_HTV_swing)/dp.Q_HTV_cap));
dp.Q_HTV_0     = dp.SOC_heat_0*dp.Q_HTV_cap;
dp.Q_HTV_peak  = dp.Q_HTV_0 + dp.Q_HTV_swing;

% 自检：整循环热摆幅必须装得进 HTV
assert(dp.Q_HTV_swing <= 0.98*dp.Q_HTV_cap, ...
    'HTV 容量不足：循环热摆幅 %.1f MWh > 容量 %.1f MWh', ...
    dp.Q_HTV_swing, dp.Q_HTV_cap);

% ---------------- 24 h 调度分段 ----------------
dp.t_idle      = 24 - dp.t_charge - dp.t_discharge;
dp.t_idle_half = dp.t_idle/2;
end
