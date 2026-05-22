function [dx, W_comp, Q_IC, W_turb, Q_HR, T_heat, mode] = ode_dynamics(t, x)
% REFPROP-based ODE: 每步精确计算物性
% x(1)=m_HPT [kg], x(2)=Q_HTV [MJ], x(3)=T_tank [K]
persistent lib Fluid

if isempty(lib)
    lib = '/opt/refprop/';  Fluid = 'CO2';
end

m_HPT = x(1);  Q_HTV_MJ = x(2);  T_tank = x(3);
P_MPa = m_HPT * 188.9 * T_tank / 6228 / 1e6;

% 调度
t_h = mod(t/3600, 24);
if t_h < 7.5;       mode = 1;
elseif t_h < 11.5;   mode = 0;
elseif t_h < 14.5;   mode = -1;
else;                mode = 0;
end

% 约束
Q_MWh = max(0, Q_HTV_MJ/3600);
P_ok_ch  = P_MPa < 6.70;
P_ok_dis = P_MPa > 0.22;
Q_ok_ch  = Q_MWh < 148;
Q_ok_dis = Q_MWh > 2;
T_heat = 298 + 185 * Q_MWh / (Q_MWh + 20);

W_design = 10;  % MW
dT = 0;  % default: no T change (will be overridden)

if mode == 1 && P_ok_ch && Q_ok_ch
    % ===== 充电: 压缩链 C1→IC1→C2→IC2→LHE =====
    [w_comp_kJ, q_IC_kJ] = charge_per_kg(lib, Fluid);
    m_dot = W_design * 1e6 / (w_comp_kJ * 1000);
    dm_HPT = m_dot;
    dQ_HTV = q_IC_kJ * m_dot / 1000;
    dT = (298 - T_tank) / 600;  % 快速热平衡: 流入298K液态CO2直接混合
    W_comp = W_design;  Q_IC = q_IC_kJ * m_dot / 1000;
    W_turb = 0;  Q_HR = 0;

elseif mode == -1 && P_ok_dis && Q_ok_dis
    % ===== 放电: 膨胀链 T1→Heater→T2 =====
    [w_turb_kJ, q_HR_kJ] = discharge_per_kg(lib, Fluid, T_tank, T_heat);
    W_T = W_design * w_turb_kJ / charge_per_kg(lib, Fluid);
    m_dot = W_T * 1e6 / (w_turb_kJ * 1000);
    dm_HPT = -m_dot;
    dQ_HTV = -q_HR_kJ * m_dot / 1000;
    % 蒸发降温: 液态CO2抽出→部分闪蒸→吸收潜热
    dT = -m_dot * 3e-5;  % K/s, ~3K/h降温
    W_comp = 0;  Q_IC = 0;
    W_turb = W_T;  Q_HR = q_HR_kJ * m_dot / 1000;

else
    dm_HPT = 0;  dQ_HTV = 0;
    dT = (298 - T_tank) / 50000;  % 环境回温, tau≈14h
    W_comp = 0;  Q_IC = 0;  W_turb = 0;  Q_HR = 0;
end

dx = [dm_HPT; dQ_HTV; dT];
end

%% 充电: 返回 [压缩机总功 kJ/kg, IC回收热 kJ/kg]
function [w_comp, q_IC] = charge_per_kg(lib, Fluid)
    persistent w_cached q_cached
    if isempty(w_cached)
        eta_c = 0.85;
        h1  = getFP(lib, 'H', 'T', 298, 'P', 0.102e6, Fluid);
        s1  = getFP(lib, 'S', 'T', 298, 'P', 0.102e6, Fluid);
        h2is= getFP(lib, 'H', 'P', 0.90e6, 'S', s1, Fluid);
        h2  = h1 + (h2is - h1) / eta_c;
        w_c1 = (h2 - h1) / 1000;  % kJ/kg
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

%% 放电: 返回 [透平总功 kJ/kg, 回热消耗 kJ/kg]
function [w_turb, q_HR] = discharge_per_kg(lib, Fluid, T_tank, T_heat)
    eta_t = 0.88;
    % EHE+HR1: T_tank → T_heat (加热到483K或Q-dependent)
    h_hpt  = getFP(lib, 'H', 'T', T_tank, 'P', 6.65e6, Fluid);
    h_t1in = getFP(lib, 'H', 'T', T_heat, 'P', 6.50e6, Fluid);
    q_preheat = (h_t1in - h_hpt) / 1000;
    % T1: T_heat, 6.50 MPa → 0.70 MPa
    s1  = getFP(lib, 'S', 'T', T_heat, 'P', 6.50e6, Fluid);
    h1is= getFP(lib, 'H', 'P', 0.70e6, 'S', s1, Fluid);
    h1out = h_t1in - eta_t * (h_t1in - h1is);
    w_t1 = (h_t1in - h1out) / 1000;
    % HR2: T1out → T_heat (再热)
    h_t2in = getFP(lib, 'H', 'T', T_heat, 'P', 0.65e6, Fluid);
    q_reheat = (h_t2in - h1out) / 1000;
    % T2: T_heat, 0.65 MPa → 0.12 MPa
    s2  = getFP(lib, 'S', 'T', T_heat, 'P', 0.65e6, Fluid);
    h2is= getFP(lib, 'H', 'P', 0.12e6, 'S', s2, Fluid);
    h2out = h_t2in - eta_t * (h_t2in - h2is);
    w_t2 = (h_t2in - h2out) / 1000;
    w_turb = w_t1 + w_t2;
    q_HR = q_preheat + q_reheat;
end

%% 封装 getFluidProperty (自动补全 mass=1, molar=0, 'MASS BASE SI')
function val = getFP(lib, prop, varargin)
    % varargin = {spec1, val1, spec2, val2, fluid}
    args = [varargin, {1, 1, 'MASS BASE SI'}];
    val = getFluidProperty(lib, prop, args{:});
end
