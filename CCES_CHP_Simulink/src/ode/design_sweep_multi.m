function design_sweep_multi(outFile)
%DESIGN_SWEEP_MULTI  多参数设计点扫描（透平温度 × 透平等熵效率 × HPT 压力）
%
%   为期刊版补齐"参数泛化"这一节：论文会议版只做了 Th 的单变量扫描，
%   这里把 eta_t 与 P_HPT 一起扫，供 ML 训练与敏感性分析使用。
%
%   用法（在仓库根目录）：
%       addpath('CCES_CHP_Simulink/src/ode');
%       design_sweep_multi
%       design_sweep_multi('ML_EnergyStorage_Optimization/data/design_sweep_multi.csv')
%
%   输出列：Th_K, eta_t, P_HPT_MPa, gamma1, gamma2, alpha1, alpha2,
%           eta_elec_pct, eta_heat_pct, X_pct, Q_max_heat_MW,
%           m_full_t, V_HPT_m3, t_charge_h
%
%   说明：P_HPT 改变时，高压侧状态点压力按 P_HPT/6.80 等比缩放（见
%   cces_design_point 中的 rP），低压侧与中间压力保持不变。这是敏感性
%   分析用的近似，不替代逐点重新设计。

rootDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..');
addpath(rootDir);
addpath(fullfile(rootDir, 'CCES_CHP_Simulink', 'src', 'ode'));

if nargin < 1 || isempty(outFile)
    outFile = fullfile(rootDir, 'ML_EnergyStorage_Optimization', 'data', ...
                       'design_sweep_multi.csv');
end

ThList    = 460:10:520;      % K
etaTList  = 0.84:0.02:0.92;  % -
PList     = 6.0:0.5:8.0;     % MPa

% ---- 基准点回归检查：默认参数必须复现论文的 gamma2 = 1.659 ----
dp0 = cces_design_point(483);
fprintf('baseline check: gamma1=%.3f gamma2=%.3f alpha1=%.3f alpha2=%.3f\n', ...
        dp0.gamma1, dp0.gamma2, dp0.alpha1, dp0.alpha2);
assert(abs(dp0.gamma2 - 1.659) < 0.01, ...
    'baseline gamma2 drifted to %.4f, expected 1.659', dp0.gamma2);

rows = zeros(numel(ThList)*numel(etaTList)*numel(PList), 14);
k = 0;
nFail = 0;
for Th = ThList
    for etaT = etaTList
        for P = PList
            opts = struct('eta_t', etaT, 'P_HPT', P);
            try
                dp = cces_design_point(Th, opts);
            catch err
                nFail = nFail + 1;
                fprintf('  skip Th=%.0f eta_t=%.2f P=%.2f : %s\n', Th, etaT, P, err.message);
                continue
            end
            k = k + 1;
            rows(k, :) = [Th, etaT, P, dp.gamma1, dp.gamma2, dp.alpha1, dp.alpha2, ...
                          dp.eta_elec_cycle, dp.eta_heat, dp.X*100, dp.Q_max_heat, ...
                          dp.m_full/1000, dp.V_HPT, dp.t_charge];
        end
    end
end
rows = rows(1:k, :);

T = array2table(rows, 'VariableNames', ...
    {'Th_K', 'eta_t', 'P_HPT_MPa', 'gamma1', 'gamma2', 'alpha1', 'alpha2', ...
     'eta_elec_pct', 'eta_heat_pct', 'X_pct', 'Q_max_heat_MW', ...
     'm_full_t', 'V_HPT_m3', 't_charge_h'});

if exist(fileparts(outFile), 'dir') ~= 7
    mkdir(fileparts(outFile));
end
writetable(T, outFile);
fprintf('wrote %d points (%d failed) to %s\n', height(T), nFail, outFile);

% ---- 快速汇总：给出为论文写敏感性小节需要的三个数 ----
g2 = T.gamma2; a2 = T.alpha2;
fprintf('\ngamma2 range over the sweep : %.3f ... %.3f (%.1f%%)\n', ...
        min(g2), max(g2), 100*(max(g2)-min(g2))/min(g2));
fprintf('alpha2 range over the sweep : %.3f ... %.3f (%.1f%%)\n', ...
        min(a2), max(a2), 100*(max(a2)-min(a2))/min(a2));
fprintf('eta_elec range              : %.1f%% ... %.1f%%\n', ...
        min(T.eta_elec_pct), max(T.eta_elec_pct));
end
