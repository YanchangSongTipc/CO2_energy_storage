function [dx, W_comp, Q_IC, W_turb, Q_HR, T_heat, mode] = ode_dynamics(t, x)
% 两相储罐 ODE: HPT液态CO2 + 饱和压力模型
% x(1)=m_HPT [kg], x(2)=Q_HTV [MJ], x(3)=T_tank [K]
persistent lib Fluid T_sat_vec P_sat_vec V_HPT

if isempty(lib)
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
    cfg = config_paths();
    lib = cfg.REFPROP_LIB;  Fluid = 'CO2';
    V_HPT = 6228;
    % 预计算饱和曲线 (260-304K)
    T_sat_vec = (260:0.5:304)';
    P_sat_vec = zeros(size(T_sat_vec));
    for i = 1:length(T_sat_vec)
        P_sat_vec(i) = getFP(lib, 'P', 'T', T_sat_vec(i), 'Q', 0, Fluid);
    end
    fprintf('HPT两相模型: P_sat LUT %d pts (%.0f-%.0fK)\n', length(T_sat_vec), T_sat_vec(1), T_sat_vec(end));
end

m_HPT = x(1);  Q_HTV_MJ = x(2);  T_tank = x(3);

% 当前温度饱和压力 + 密度
T_clamp = max(260, min(304, T_tank));
P_sat_T = interp1(T_sat_vec, P_sat_vec, T_clamp, 'linear');
rho_liq_T = getFP(lib, 'D', 'T', T_clamp, 'Q', 0, Fluid);
rho_vap_T = getFP(lib, 'D', 'T', T_clamp, 'Q', 1, Fluid);

% ==== 两相压力: 有液时 P=P_sat(T), 排空时 P=mRT/V ====
m_sat_liq = rho_liq_T * V_HPT;
m_sat_vap = rho_vap_T * V_HPT;

if m_HPT >= m_sat_liq
    overfill = (m_HPT - m_sat_liq) / m_sat_liq;
    P_MPa = P_sat_T/1e6 + overfill * 1000;
elseif m_HPT > m_sat_vap * 0.05
    P_MPa = P_sat_T / 1e6;
else
    P_MPa = m_HPT * 188.9 * T_tank / V_HPT / 1e6;
end

% ==== 调度 (每日循环: 充电7.5h + 放电5h) ====
t_h = mod(t/3600, 24);
if t_h < 7.5;       mode = 1;   % 充电
elseif t_h < 11.5;   mode = 0;   % 待机
elseif t_h < 16.5;   mode = -1;  % 放电 (3h→5h)
else;                mode = 0;   % 待机
end

% ==== 约束条件 ====
Q_MWh = max(0, Q_HTV_MJ/3600);
P_ok_ch  = m_HPT < m_sat_liq * 0.995;    % 不满液时可充
P_ok_dis = m_HPT > m_sat_vap * 1.05;     % 有液相时可放
Q_ok_ch  = Q_MWh < 148;
Q_ok_dis = Q_MWh > 2;
T_heat = 298 + 185 * Q_MWh / (Q_MWh + 20);

W_design = 10;  % MW

if mode == 1 && P_ok_ch && Q_ok_ch
    % ===== 充电 =====
    alpha_ch = 2.744;  % kg/(s·MW)
    m_dot = alpha_ch * W_design;                    % 27.44 kg/s
    [w_comp_kJ, q_IC_kJ] = charge_per_kg(lib, Fluid);
    dm_HPT = m_dot;
    dQ_HTV = q_IC_kJ * m_dot / 1000;
    dT = (298 - T_tank) / 600;
    W_C_actual = m_dot * w_comp_kJ / 1000;         % ~9.74 MW
    W_comp = W_C_actual;  Q_IC = q_IC_kJ * m_dot / 1000;
    W_turb = 0;  Q_HR = 0;

elseif mode == -1 && P_ok_dis && Q_ok_dis
    % ===== 放电: 透平按设计额定功率运行 =====
    alpha_dis = 4.117;  % kg/(s·MW)
    W_T_design = 10.12; % MW (Cycle.m: T1 5.49 + T2 4.63)
    m_dot = alpha_dis * W_T_design;                % ~41.7 kg/s
    [w_turb_kJ, q_HR_kJ] = discharge_per_kg(lib, Fluid, T_tank, T_heat);
    dm_HPT = -m_dot;
    dQ_HTV = -q_HR_kJ * m_dot / 1000;
    dT = -m_dot * 3e-5;
    W_comp = 0;  Q_IC = 0;
    W_turb = W_T_design;  Q_HR = q_HR_kJ * m_dot / 1000;

else
    % ===== 待机: 环境回温 =====
    dm_HPT = 0;  dQ_HTV = 0;
    dT = (298 - T_tank) / 50000;
    W_comp = 0;  Q_IC = 0;  W_turb = 0;  Q_HR = 0;
end

dx = [dm_HPT; dQ_HTV; dT];
end

%% ==== 充电: 单位工质压缩机总功 + IC回收热 [kJ/kg] ====
function [w_comp, q_IC] = charge_per_kg(lib, Fluid)
persistent w_cached q_cached
if isempty(w_cached)
    eta_c = 0.85;
    h1  = getFP(lib, 'H', 'T', 298, 'P', 0.102e6, Fluid);
    s1  = getFP(lib, 'S', 'T', 298, 'P', 0.102e6, Fluid);
    h2is= getFP(lib, 'H', 'P', 0.90e6, 'S', s1, Fluid);
    h2  = h1 + (h2is - h1) / eta_c;
    w_c1 = (h2 - h1) / 1000;
    h3  = getFP(lib, 'H', 'T', 308, 'P', 0.85e6, Fluid);
    q_ic1 = (h2 - h3) / 1000;
    s3  = getFP(lib, 'S', 'T', 308, 'P', 0.85e6, Fluid);
    h4is= getFP(lib, 'H', 'P', 6.90e6, 'S', s3, Fluid);
    h4  = h3 + (h4is - h3) / eta_c;
    w_c2 = (h4 - h3) / 1000;
    h5  = getFP(lib, 'H', 'T', 309, 'P', 6.85e6, Fluid);
    q_ic2 = (h4 - h5) / 1000;
    w_cached = w_c1 + w_c2;
    q_cached = q_ic1 + q_ic2;
end
w_comp = w_cached;  q_IC = q_cached;
end

%% ==== 放电: 单位工质透平总功 + 回热消耗 [kJ/kg] ====
function [w_turb, q_HR] = discharge_per_kg(lib, Fluid, T_tank, T_heat)
    eta_t = 0.88;
    h_hpt  = getFP(lib, 'H', 'T', T_tank, 'P', 6.65e6, Fluid);
    h_t1in = getFP(lib, 'H', 'T', T_heat, 'P', 6.50e6, Fluid);
    q_preheat = (h_t1in - h_hpt) / 1000;
    s1  = getFP(lib, 'S', 'T', T_heat, 'P', 6.50e6, Fluid);
    h1is= getFP(lib, 'H', 'P', 0.70e6, 'S', s1, Fluid);
    h1out = h_t1in - eta_t * (h_t1in - h1is);
    w_t1 = (h_t1in - h1out) / 1000;
    h_t2in = getFP(lib, 'H', 'T', T_heat, 'P', 0.65e6, Fluid);
    q_reheat = (h_t2in - h1out) / 1000;
    s2  = getFP(lib, 'S', 'T', T_heat, 'P', 0.65e6, Fluid);
    h2is= getFP(lib, 'H', 'P', 0.12e6, 'S', s2, Fluid);
    h2out = h_t2in - eta_t * (h_t2in - h2is);
    w_t2 = (h_t2in - h2out) / 1000;
    w_turb = w_t1 + w_t2;
    q_HR = q_preheat + q_reheat;
end

%% ==== 封装 getFluidProperty ====
function val = getFP(lib, prop, varargin)
    args = [varargin, {1, 1, 'MASS BASE SI'}];
    val = getFluidProperty(lib, prop, args{:});
end
