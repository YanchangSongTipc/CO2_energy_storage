function [mode, seg] = cces_schedule(th, dp)
%CCES_SCHEDULE  24 h 调度分段
%   输入 th 为一天内的小时数 [0,24)，dp 为 cces_design_point 的结果。
%   mode: 1 = 充电, 0 = 待机, -1 = 放电

t1 = dp.t_charge;
t2 = t1 + dp.t_idle_half;
t3 = t2 + dp.t_discharge;

if th < t1
    mode = 1;   seg = 'charge';
elseif th < t2
    mode = 0;   seg = 'idle';
elseif th < t3
    mode = -1;  seg = 'discharge';
else
    mode = 0;   seg = 'idle';
end
end
