function [dx, W_comp, Q_IC, W_turb, Q_HR, T_heat, mode] = ode_dynamics(t, x)
%ODE_DYNAMICS  CCES-CHP 双 SOC 动态模型（质量 + 热量双重闭合）
%
%   状态量 x = [m_HPT (kg); Q_HTV (MJ)]
%       m_HPT : HPT 内液态 CO2 存量（定压 6.8 MPa、298 K 室温液态储存）
%       Q_HTV : HTV 蓄热量（MJ），容量 dp.Q_HTV_cap*3600
%
%   返回 dx = [dm/dt (kg/s); dQ/dt (MW)]，其余输出为瞬时功率 [MW]。
%
%   物理逻辑（每个 24 h 周期严格闭合，见 cces_design_point）：
%     充电   m_HPT += m_c*dt        Q_HTV += Q_IC*dt
%     放电   m_HPT -= m_d*dt        Q_HTV -= (Q_HR + Q_export)*dt
%     待机   不动作
%   由构造保证 m_c*t_c = m_d*t_d 且 Q_IC*t_c = (Q_HR+Q_export)*t_d，
%   因此存量与蓄热逐日回到同一数值，不靠"撞限幅"制造假稳态。

persistent dp_
if isempty(dp_)
    dp_ = cces_design_point(483);
end
p = dp_;

m = x(1);
Q = x(2);
mode = cces_schedule(mod(t/3600, 24), p);

eps_m = 1e-6*p.m_full;            % 数值容差: 防止恰好到达边界时被误判为越界
m_hi  = p.SOC_gas_max*p.m_full + eps_m;
m_lo  = p.SOC_gas_min*p.m_full - eps_m;
Q_hi  = p.Q_HTV_cap*3600 + 1e-3;
Q_lo  = -1e-3;

dm = 0; dQ = 0;
W_comp = 0; Q_IC = 0; W_turb = 0; Q_HR = 0;

switch mode
    case 1      % 充电：储液增加，压缩热进入 HTV
        if m < m_hi && Q < Q_hi
            dm =  p.m_charge;          % kg/s
            dQ =  p.Q_IC_rate;         % MW = MJ/s
            W_comp = p.W_charge;
            Q_IC   = p.Q_IC_rate;
        end
    case -1     % 放电：储液减少，回热 + 对外供热由 HTV 支出
        if m > m_lo && Q > Q_lo
            dm = -p.m_discharge;
            dQ = -(p.Q_HR_rate + p.Q_export);
            W_turb = p.W_discharge;
            Q_HR   = p.Q_HR_rate;
        end
    otherwise   % 待机
end

dx = [dm; dQ];
T_heat = p.T_oil_hot;
end
