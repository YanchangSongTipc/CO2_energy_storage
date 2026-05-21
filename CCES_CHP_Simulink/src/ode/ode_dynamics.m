function [dx, W_comp, Q_IC, W_turb, Q_HR, T_heat, mode] = ode_dynamics(t, x)
    m_HPT = x(1);  Q_HTV = x(2);
    P_MPa = m_HPT * 188.9 * 298 / 6228 / 1e6;

    % 调度
    t_h = mod(t/3600, 24);
    if t_h >= 0 && t_h < 7.5
        mode = 1;
    elseif t_h >= 12 && t_h < 15
        mode = -1;
    else
        mode = 0;
    end

    % 约束
    P_ok_ch  = P_MPa < 6.70;
    P_ok_dis = P_MPa > 0.22;
    Q_MWh = max(0, Q_HTV/3600);
    Q_ok_ch  = Q_MWh < 148;
    Q_ok_dis = Q_MWh > 2;

    T_heat = 298 + 185 * Q_MWh / (Q_MWh + 20);
    W_design = 10;
    alpha = 2.744;
    beta1 = 1.185;
    beta2 = 2.307;

    if mode == 1 && P_ok_ch && Q_ok_ch
        m_dot = alpha * W_design;
        dm_HPT = m_dot;  dQ_HTV = beta1 * W_design;
        W_comp = W_design;  Q_IC = beta1 * W_design;
        W_turb = 0;         Q_HR = 0;
    elseif mode == -1 && P_ok_dis && Q_ok_dis
        W_T = W_design * 0.70;  % 热力学效率
        m_dot = alpha * W_T;
        dm_HPT = -m_dot;  dQ_HTV = -beta2 * W_T;
        W_comp = 0;  Q_IC = 0;
        W_turb = W_T;  Q_HR = beta2 * W_T;
    else
        dm_HPT = 0;  dQ_HTV = 0;
        W_comp = 0;  Q_IC = 0;  W_turb = 0;  Q_HR = 0;
    end
    dx = [dm_HPT; dQ_HTV];
end
