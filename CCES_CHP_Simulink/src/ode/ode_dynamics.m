function [dx, W_comp, Q_IC, W_turb, Q_HR, T_heat, mode] = ode_dynamics(t, x)
% 两相HPT + 双罐导热油HTV
% x(1)=m_HPT [kg], x(2)=V_hot [m³], x(3)=T_tank [K]
persistent lib Fluid T_sat_vec P_sat_vec V_HPT rho_oil cp_oil T_hot T_cold V_total

if isempty(lib)
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
    cfg = config_paths();
    lib = cfg.REFPROP_LIB;  Fluid = 'CO2';
    V_HPT = 6228;
    T_sat_vec = (260:0.5:304)';  P_sat_vec = zeros(size(T_sat_vec));
    for i = 1:length(T_sat_vec)
        P_sat_vec(i) = getFP(lib, 'P', 'T', T_sat_vec(i), 'Q', 0, Fluid);
    end
    % 导热油: 双罐系统, 热罐~573K, 冷罐~298K
    T_hot  = 573;  T_cold = 298;  % K
    rho_oil = 850;  cp_oil = 2.5;  % kg/m³, kJ/(kg·K)
    V_total = 150*3600*1000 / (rho_oil * cp_oil * (T_hot - T_cold));  % MJ→kJ, ≈923 m³
    fprintf('双罐HTV: Th=%.0fK Tc=%.0fK, V_total=%.0f m3, rho*cp=%.0f kJ/m3K\n',...
        T_hot, T_cold, V_total, rho_oil*cp_oil);
    fprintf('HPT两相: P_sat LUT %dpts\n', length(T_sat_vec));
end

m_HPT = x(1);  V_hot = x(2);  T_tank = x(3);
V_hot = max(0, min(V_total, V_hot));

% HPT 压力
T_clamp = max(260, min(304, T_tank));
P_sat_T = interp1(T_sat_vec, P_sat_vec, T_clamp, 'linear');
rho_liq_T = getFP(lib, 'D', 'T', T_clamp, 'Q', 0, Fluid);
rho_vap_T = getFP(lib, 'D', 'T', T_clamp, 'Q', 1, Fluid);
m_sat_liq = rho_liq_T * V_HPT;
m_sat_vap = rho_vap_T * V_HPT;
if m_HPT >= m_sat_liq
    P_MPa = P_sat_T/1e6 + (m_HPT-m_sat_liq)/m_sat_liq*1000;
elseif m_HPT > m_sat_vap*0.05
    P_MPa = P_sat_T/1e6;
else
    P_MPa = m_HPT*188.9*T_tank/V_HPT/1e6;
end

% 调度
t_h = mod(t/3600, 24);
if t_h < 7.5;       mode = 1;
elseif t_h < 11.5;   mode = 0;
elseif t_h < 15.5;   mode = -1;  % 放电4h (热平衡)
else;                mode = 0;
end

% 约束
P_ok_ch  = m_HPT < m_sat_liq * 0.995;
P_ok_dis = m_HPT > m_sat_vap * 1.05;
Q_ok_ch  = V_hot < V_total * 0.90;
Q_ok_dis = V_hot > V_total * 0.10;
T_heat = T_hot;  % 恒温热油 → CO2 加热温度恒定为设计值

rho_cp = rho_oil * cp_oil;  % kJ/m³K

if mode == 1 && P_ok_ch && Q_ok_ch
    % ===== 充电: 冷油→IC→热罐 =====
    alpha_ch = 2.744;  m_dot = alpha_ch * 10;
    [~, q_IC_kJ] = charge_per_kg(lib, Fluid);
    Q_IC_MW = q_IC_kJ * m_dot / 1000;          % MW_th
    dm_HPT = m_dot;
    dV_hot = Q_IC_MW * 1000 / (rho_cp * (T_hot - T_cold));  % m³/s
    dT_tank = (298 - T_tank) / 600;
    W_comp = m_dot * charge_per_kg(lib, Fluid) / 1000;
    Q_IC = Q_IC_MW;  W_turb = 0;  Q_HR = 0;

elseif mode == -1 && P_ok_dis && Q_ok_dis
    % ===== 放电: 热油→再热器→冷罐 =====
    alpha_dis = 4.117;  W_T = 10.12;
    m_dot = alpha_dis * W_T;
    [~, q_HR_kJ] = discharge_per_kg(lib, Fluid, T_tank, T_heat);
    Q_HR_MW = q_HR_kJ * m_dot / 1000;
    dm_HPT = -m_dot;
    dV_hot = -Q_HR_MW * 1000 / (rho_cp * (T_hot - T_cold));
    dT_tank = -m_dot * 3e-5;
    W_comp = 0;  Q_IC = 0;
    W_turb = W_T;  Q_HR = Q_HR_MW;

else
    dm_HPT = 0;  dV_hot = 0;
    dT_tank = (298 - T_tank) / 50000;
    W_comp = 0;  Q_IC = 0;  W_turb = 0;  Q_HR = 0;
end

dx = [dm_HPT; dV_hot; dT_tank];
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
