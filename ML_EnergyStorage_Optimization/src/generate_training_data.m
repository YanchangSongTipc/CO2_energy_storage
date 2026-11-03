% =========================================================================
% generate_training_data.m
% 为 ML 模型生成 CCES-CHP 运行可行域训练数据
%
% 设计参数与物性全部来自 cces_design_point.m（唯一真源），本脚本不再重复
% 15 状态点计算，避免与 Cycle / ODE 两条线漂移。
%
% 可行性约束（Δt = 1 h；W 单位 MW，m 单位 t，Q 单位 MWh）：
%   充电 mode = 0
%       Q <=  γ1·W + Q_HTV/Δt            储热下限：不能供出多于存量的热
%       Q >=  γ1·W + (Q_HTV-Q_cap)/Δt    储热上限：不能把 HTV 充满
%       m  + α1·W·Δt <= m_full           HPT 不溢罐
%   放电 mode = 1
%       Q <= -γ2·W + Q_HTV/Δt
%       Q >= -γ2·W + (Q_HTV-Q_cap)/Δt
%       m  - α2·W·Δt >= 0                HPT 不抽空
%   公共  0 <= W <= W_design, 0 <= Q <= Q_max_heat
%
% 与旧版的差别：
%   1) γ2 由 2.307 改为 1.659（EHE 蒸发热不再计入回热）
%   2) 新增 HPT 质量约束 —— SOC_gas 第一次真正参与可行域
%      （旧版 3520 个状态组里 SOC_gas 对标签影响为 0）
%   3) Q 上限统一为 Q_max_heat = γ1·W_design（旧版训练集 12.05 / 调度 9.5 混用）
%   4) 用 m_HPT_t 取代恒为 6.8 的 P_HPT_MPa；效率列改为设计点实算值
% =========================================================================

clc; clear; close all;

here     = fileparts(mfilename('fullpath'));
rootDir  = fullfile(here, '..', '..');
addpath(rootDir);
addpath(fullfile(rootDir, 'CCES_CHP_Simulink', 'src', 'ode'));

dp = cces_design_point(483);
dt = 1.0;                                   % 调度步长 [h]

fprintf('=== CCES-CHP 训练数据生成 ===\n');
fprintf('γ1=%.3f  γ2=%.3f  α1=%.3f  α2=%.3f kg/(s·MW)\n', ...
        dp.gamma1, dp.gamma2, dp.alpha1, dp.alpha2);
fprintf('Q_max_heat=%.2f MW  m_full=%.1f t  V_HPT=%.0f m3  Q_HTV_cap=%.0f MWh\n', ...
        dp.Q_max_heat, dp.m_full/1000, dp.V_HPT, dp.Q_HTV_cap);
fprintf('η_elec=%.1f%%  η_heat=%.1f%% (LG %.1f + AE %.1f)\n\n', ...
        dp.eta_elec_cycle, dp.eta_heat, dp.eta_heat_LG, dp.eta_heat_AE);

% ---------------- 采样网格 ----------------
SOC_h_vals = linspace(0, 100, 16)';
SOC_g_vals = linspace(0, 100, 11)';
W_vals     = linspace(0, dp.W_charge, 11)';
Q_vals     = linspace(0, dp.Q_max_heat, 10)';

outFile = fullfile(here, '..', 'data', 'training_data.csv');
fid = fopen(outFile, 'w');
fprintf(fid, ['mode,SOC_heat_pct,SOC_gas_pct,Q_HTV_MWh,m_HPT_t,W_MW,Q_MW,' ...
              'feasible,W_max_feasible,Q_max_feasible,' ...
              'beta1,beta2,alpha1,alpha2,eta_elec_pct,eta_heat_pct\n']);

count = 0;  nfeas = 0;
n_state = 0;  n_state_hpt = 0;   % 统计: 有多少状态组受 HPT 质量限制

for s_h = 1:numel(SOC_h_vals)
    SOC_h = SOC_h_vals(s_h);
    Q_HTV = SOC_h/100*dp.Q_HTV_cap;
    b_up  =  Q_HTV/dt;                       % W=0 时的最大供热
    b_lo  = (Q_HTV - dp.Q_HTV_cap)/dt;       % 受罐容限制的下限（负值）

    for s_g = 1:numel(SOC_g_vals)
        SOC_g = SOC_g_vals(s_g);
        m = SOC_g/100*dp.m_full;             % kg

        for mode = 0:1
            if mode == 0
                slope  = dp.gamma1;
                W_mass = (dp.m_full - m)/(dp.alpha1*3600*dt);   % 溢罐限制
                W_heat = (dp.Q_max_heat - b_lo)/slope;          % 保证存在可行 Q
            else
                slope  = -dp.gamma2;
                W_mass = m/(dp.alpha2*3600*dt);                 % 抽空限制
                W_heat = b_up/(-slope);                         % Q=0 时的最大功率
            end

            W_max_feas = min([dp.W_charge, max(0,W_mass), max(0,W_heat)]);
            Q_max_feas = min(dp.Q_max_heat, max(0, b_up));

            n_state = n_state + 1;
            if max(0,W_mass) < min(dp.W_charge, max(0,W_heat))
                n_state_hpt = n_state_hpt + 1;
            end

            for w = 1:numel(W_vals)
                W = W_vals(w);
                for q = 1:numel(Q_vals)
                    Q = Q_vals(q);

                    feasible = (W <= dp.W_charge      + 1e-12) && ...
                               (W <= max(0,W_mass)    + 1e-12) && ...
                               (Q >= 0) && (Q <= dp.Q_max_heat + 1e-12) && ...
                               (Q <= slope*W + b_up   + 1e-12) && ...
                               (Q >= slope*W + b_lo   - 1e-12);

                    fprintf(fid, ['%d,%.4f,%.4f,%.4f,%.3f,%.4f,%.4f,%d,' ...
                                  '%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f,%.2f\n'], ...
                        mode, SOC_h, SOC_g, Q_HTV, m/1000, W, Q, feasible, ...
                        W_max_feas, Q_max_feas, ...
                        dp.gamma1, dp.gamma2, dp.alpha1, dp.alpha2, ...
                        dp.eta_elec_cycle, dp.eta_heat);

                    count = count + 1;
                    nfeas = nfeas + feasible;
                end
            end
        end
    end
end
fclose(fid);

fprintf('样本 %d，可行 %d（%.1f%%）\n', count, nfeas, nfeas/count*100);
fprintf('受 HPT 质量约束的状态组 %d / %d（%.0f%%）\n', ...
        n_state_hpt, n_state, n_state_hpt/n_state*100);
fprintf('输出: %s\n', outFile);
