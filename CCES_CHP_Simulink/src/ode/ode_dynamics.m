function [dx, W_comp, Q_IC, W_turb, Q_HR, T_heat, mode] = ode_dynamics(t, x)
% 两相HPT + 双罐导热油HTV (质量+能量平衡)
% x(1)=m_HPT [kg], x(2)=V_hot [m³], x(3)=T_tank [K]
persistent lib Fluid T_sat_vec P_sat_vec V_HPT rho_oil cp_oil T_hot T_cold V_total alpha

if isempty(lib)
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
    cfg = config_paths();
    lib = cfg.REFPROP_LIB;  Fluid = 'CO2';
    V_HPT = 6228;
    T_sat_vec = (260:0.5:304)';  P_sat_vec = zeros(size(T_sat_vec));
    for i = 1:length(T_sat_vec)
        P_sat_vec(i) = getFP(lib, 'P', 'T', T_sat_vec(i), 'Q', 0, Fluid);
    end
    T_hot=573; T_cold=298;  rho_oil=850; cp_oil=2.5;
    V_total = 150*3600*1000 / (rho_oil * cp_oil * (T_hot-T_cold));
    alpha = 2.744;  % kg/(s·MW), 充放共用 → 质量平衡
    fprintf('双罐HTV: V=%.0fm3, α=%.3f (充放同值→质量平衡)\n', V_total, alpha);
    fprintf('HPT两相: P_sat LUT %dpts\n', length(T_sat_vec));
end

m_HPT = x(1);  V_hot = max(0, min(V_total, x(2)));  T_tank = x(3);

% HPT 两相压力
Tc = max(260, min(304, T_tank));
Ps = interp1(T_sat_vec, P_sat_vec, Tc, 'linear');
rl = getFP(lib, 'D', 'T', Tc, 'Q', 0, Fluid);
rv = getFP(lib, 'D', 'T', Tc, 'Q', 1, Fluid);
m_sat_liq = rl * V_HPT;  m_sat_vap = rv * V_HPT;
if m_HPT >= m_sat_liq,      P_MPa = Ps/1e6 + (m_HPT-m_sat_liq)/m_sat_liq*1000;
elseif m_HPT > m_sat_vap*0.05, P_MPa = Ps/1e6;
else,                         P_MPa = m_HPT*188.9*T_tank/V_HPT/1e6;
end

% 调度: 充电5h + 放电5h (质量平衡: α*Wc*tc ≈ α*Wt*td)
% Wc≈9.74 MW, Wt=10.12 MW, 相等时长→质量近平衡
t_h = mod(t/3600, 24);
if     t_h < 5;    mode = 1;    % 充电5h
elseif t_h < 10;   mode = 0;    % 闲置5h
elseif t_h < 15;   mode = -1;   % 放电5h
else;               mode = 0;   % 闲置9h
end

% 约束
P_ok_ch  = m_HPT < m_sat_liq * 0.995;
P_ok_dis = m_HPT > m_sat_vap * 1.05;
Q_ok_ch  = V_hot < V_total * 0.90;
Q_ok_dis = V_hot > V_total * 0.10;
T_heat = T_hot;  % 恒温573K
rho_cp = rho_oil * cp_oil;
W_design = 10;  W_T_design = 10.12;

if mode == 1 && P_ok_ch && Q_ok_ch
    % ===== 充电 =====
    m_dot = alpha * W_design;                     % kg/s
    [~, q_IC_kJ] = charge_per_kg(lib, Fluid);
    Q_IC_MW = q_IC_kJ * m_dot / 1000;
    dm_HPT = m_dot;
    dV_hot = Q_IC_MW * 1000 / (rho_cp * (T_hot-T_cold));
    dT_tank = (298 - T_tank) / 600;
    W_comp = m_dot * charge_per_kg(lib, Fluid) / 1000;
    Q_IC = Q_IC_MW;  W_turb = 0;  Q_HR = 0;

elseif mode == -1 && P_ok_dis && Q_ok_dis
    % ===== 放电 (透平额定功率, W_T=10.12MW) =====
    m_dot = alpha * W_T_design;                   % kg/s, 同α
    [~, q_HR_kJ] = discharge_per_kg(lib, Fluid, T_tank, T_heat);
    Q_HR_MW = q_HR_kJ * m_dot / 1000;
    dm_HPT = -m_dot;
    dV_hot = -Q_HR_MW * 1000 / (rho_cp * (T_hot-T_cold));
    dT_tank = -m_dot * 3e-5;
    W_comp = 0;  Q_IC = 0;
    W_turb = W_T_design;  Q_HR = Q_HR_MW;

else
    dm_HPT = 0;  dV_hot = 0;
    dT_tank = (298 - T_tank) / 50000;
    W_comp = 0;  Q_IC = 0;  W_turb = 0;  Q_HR = 0;
end

dx = [dm_HPT; dV_hot; dT_tank];
end

%% charge_per_kg (cached)
function [w_comp, q_IC] = charge_per_kg(lib, Fluid)
persistent w_cached q_cached
if isempty(w_cached)
    eta_c=0.85;
    h1=getFP(lib,'H','T',298,'P',0.102e6,Fluid);
    s1=getFP(lib,'S','T',298,'P',0.102e6,Fluid);
    h2is=getFP(lib,'H','P',0.90e6,'S',s1,Fluid);
    h2=h1+(h2is-h1)/eta_c;  w_c1=(h2-h1)/1000;
    h3=getFP(lib,'H','T',308,'P',0.85e6,Fluid);  q_ic1=(h2-h3)/1000;
    s3=getFP(lib,'S','T',308,'P',0.85e6,Fluid);
    h4is=getFP(lib,'H','P',6.90e6,'S',s3,Fluid);
    h4=h3+(h4is-h3)/eta_c;  w_c2=(h4-h3)/1000;
    h5=getFP(lib,'H','T',309,'P',6.85e6,Fluid);  q_ic2=(h4-h5)/1000;
    w_cached=w_c1+w_c2;  q_cached=q_ic1+q_ic2;
end
w_comp=w_cached;  q_IC=q_cached;
end

%% discharge_per_kg
function [w_turb, q_HR] = discharge_per_kg(lib, Fluid, T_tank, T_heat)
    eta_t=0.88;
    h_hpt=getFP(lib,'H','T',T_tank,'P',6.65e6,Fluid);
    h_t1in=getFP(lib,'H','T',T_heat,'P',6.50e6,Fluid);
    q_preheat=(h_t1in-h_hpt)/1000;
    s1=getFP(lib,'S','T',T_heat,'P',6.50e6,Fluid);
    h1is=getFP(lib,'H','P',0.70e6,'S',s1,Fluid);
    h1out=h_t1in-eta_t*(h_t1in-h1is);  w_t1=(h_t1in-h1out)/1000;
    h_t2in=getFP(lib,'H','T',T_heat,'P',0.65e6,Fluid);
    q_reheat=(h_t2in-h1out)/1000;
    s2=getFP(lib,'S','T',T_heat,'P',0.65e6,Fluid);
    h2is=getFP(lib,'H','P',0.12e6,'S',s2,Fluid);
    h2out=h_t2in-eta_t*(h_t2in-h2is);  w_t2=(h_t2in-h2out)/1000;
    w_turb=w_t1+w_t2;  q_HR=q_preheat+q_reheat;
end

function val = getFP(lib, prop, varargin)
    args = [varargin, {1, 1, 'MASS BASE SI'}];
    val = getFluidProperty(lib, prop, args{:});
end
