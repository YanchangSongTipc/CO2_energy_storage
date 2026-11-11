function [ok, info] = cces_feasible_dyn(dp, m0_Mg, Q0_MWh, W, Qh, mode, H)
%CCES_FEASIBLE_DYN  以恒定 (W, Qh) 连续运行 H 小时，检查全程是否越界
%
%   [ok, info] = cces_feasible_dyn(dp, m0_t, Q0_MWh, W, Qh, mode, H)
%
%   输入（与 cces_design_point 的单位一致）
%     dp      : cces_design_point 的结构体
%     m0_t    : HPT 储液量 [t]
%     Q0_MWh  : HTV 蓄热量 [MWh]
%     W       : 充/放电功率 [MW]（恒值）
%     Qh      : 对外供热功率 [MW]（恒值，从 HTV 支出）
%     mode    : +1 充电, -1 放电
%     H       : 时长 [h]
%
%   输出
%     ok      : 全程满足 m∈[m_lo,m_hi]、Q∈[0,cap] 则为 true
%     info    : 结构体，含终止原因、越界时刻、最小余量
%
%   动力学（与 ode_dynamics 一致，只是把 W 从设计值放开为任意值）：
%     充电  dm/dt = +alpha1*W      dQ/dt = +gamma1*W - Qh
%     放电  dm/dt = -alpha2*W      dQ/dt = -(gamma2*W + Qh)
%
%   注意：恒定输入下 m(t)、Q(t) 对 t 单调，越界必发生在终点；
%   这里仍按步长推进，便于以后换成与状态相关的效率/压力。

if nargin < 7 || isempty(H), H = 1; end

m_lo = dp.SOC_gas_min*dp.m_full/1000;     % t
m_hi = dp.SOC_gas_max*dp.m_full/1000;     % t
Q_lo = 0;                                  % MWh
Q_hi = dp.Q_HTV_cap;                       % MWh

if mode > 0
    dm =  dp.alpha1*W/1000;                % t/h  (alpha 单位 kg/(s·MW))
    dQ =  dp.gamma1*W - Qh;                % MWh/h
else
    dm = -dp.alpha2*W/1000;
    dQ = -(dp.gamma2*W + Qh);
end

nStep = max(1, ceil(H/0.25));
dt = H/nStep;
m = m0_Mg;  Q = Q0_MWh;

ok = true;
info.reason = 'ok';
info.t_break = NaN;
info.m_margin = inf;
info.Q_margin = inf;

for k = 1:nStep
    m = m + dm*dt;
    Q = Q + dQ*dt;
    info.m_margin = min(info.m_margin, min(m - m_lo, m_hi - m));
    info.Q_margin = min(info.Q_margin, min(Q - Q_lo, Q_hi - Q));
    if m < m_lo - 1e-9
        ok = false; info.reason = 'inventory low';  info.t_break = k*dt; break
    elseif m > m_hi + 1e-9
        ok = false; info.reason = 'inventory high'; info.t_break = k*dt; break
    elseif Q < Q_lo - 1e-9
        ok = false; info.reason = 'heat low';       info.t_break = k*dt; break
    elseif Q > Q_hi + 1e-9
        ok = false; info.reason = 'heat high';      info.t_break = k*dt; break
    end
end
info.W = W;  info.Qh = Qh;  info.mode = mode;  info.H = H;
end
