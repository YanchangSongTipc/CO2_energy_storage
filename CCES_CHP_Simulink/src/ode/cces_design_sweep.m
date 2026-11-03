function T = cces_design_sweep(Th_list, outFile)
%CCES_DESIGN_SWEEP  扫描透平入口温度，输出 γ/α 与效率
%
%   T = cces_design_sweep(Th_list, outFile)
%   对每个 Th 调 cces_design_point（REFPROP 现算），供 Python 侧绘图使用，
%   避免在 Python 里手写 β₂(T) 之类的"估算值"。
%
%   输出列：Th_K, beta1, beta2, alpha1, alpha2, eta_elec_pct, eta_heat_pct

if nargin < 1 || isempty(Th_list), Th_list = 460:5:520; end
if nargin < 2, outFile = ''; end

n = numel(Th_list);
rows = zeros(n, 7);
for i = 1:n
    dp = cces_design_point(Th_list(i));
    rows(i,:) = [dp.Th, dp.gamma1, dp.gamma2, dp.alpha1, dp.alpha2, ...
                 dp.eta_elec_cycle, dp.eta_heat];
end

T = array2table(rows, 'VariableNames', ...
    {'Th_K','beta1','beta2','alpha1','alpha2','eta_elec_pct','eta_heat_pct'});

if ~isempty(outFile)
    writetable(T, outFile);
    fprintf('已写出 %s（%d 行）\n', outFile, n);
end

fprintf('\n  Th[K]   beta1   beta2   alpha1  alpha2  RTE%%   eta_heat%%\n');
for i = 1:n
    fprintf('  %5.0f   %.3f   %.3f   %.3f   %.3f   %.1f   %.1f\n', rows(i,:));
end
end
