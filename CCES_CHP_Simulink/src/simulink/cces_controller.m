function [charge_cmd, discharge_cmd] = cces_controller(P_HPT, t)
    % CCES 控制器: 基于 HPT 压力和时间的充/放电指令
    % P_HPT: 当前 HPT 压力 [MPa]
    % t: 仿真时间 [s]
    % charge_cmd: 充电功率指令 [MW], 0 = 不充电
    % discharge_cmd: 放电功率指令 [MW], 0 = 不放电

    P_max = 6.80;  % MPa
    P_min = 0.12;

    % 简单调度: 24h周期, 0-7.5h充电, 12-17h放电
    cycle_h = mod(t / 3600, 24);

    if cycle_h < 7.5 && P_HPT < P_max - 0.1
        charge_cmd = 10;  discharge_cmd = 0;
    elseif cycle_h >= 12 && cycle_h < 17 && P_HPT > P_min + 0.1
        charge_cmd = 0;  discharge_cmd = 10;
    else
        charge_cmd = 0;  discharge_cmd = 0;
    end
end
