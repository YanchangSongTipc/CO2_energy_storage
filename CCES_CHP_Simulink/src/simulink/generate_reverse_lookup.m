% =========================================================================
% generate_reverse_lookup.m — 从已有 H(T,P)/S(T,P) 生成反向查找表
% 用于 Simulink 2-D Lookup Table 块: T(P,H) 和 H(P,S)
% =========================================================================

fprintf('加载现有查找表...\n');
load(fullfile(fileparts(mfilename('fullpath')), '../../..', 'data/REFPROP_lookup.mat'));

%% 1. 定义反向表网格
% H(P,S) — 等熵过程: 给定 P_out 和 s_in, 返回 h_is
% 用等间距的 S 网格
S_min = min(S_table(:));  S_max = max(S_table(:));
nS = 80;
S_PS_vec = linspace(S_min, S_max, nS);

% P 网格与正向表一致
P_PS_vec = P_vec;

H_PS_table = zeros(nS, length(P_PS_vec));

fprintf('生成 H(P,S) 反向表 (%d x %d)...\n', nS, length(P_PS_vec));
for i = 1:nS
    s_target = S_PS_vec(i);
    for j = 1:length(P_PS_vec)
        p_target = P_PS_vec(j);
        % 在 T 方向上搜索: S(T, P_target) - s_target = 0
        s_at_T = interp1(P_vec, S_table', p_target)';
        [~, idx] = min(abs(s_at_T - s_target));
        if idx > 1 && idx < length(T_vec)
            % 线性插值 T
            frac = (s_target - s_at_T(idx)) / (s_at_T(idx+1) - s_at_T(idx) + eps);
            T_guess = T_vec(idx) + frac * (T_vec(idx+1) - T_vec(idx));
            T_guess = max(T_vec(1), min(T_vec(end), T_guess));
            H_PS_table(i,j) = interp2(P_vec, T_vec, H_table, p_target, T_guess, 'linear');
        else
            H_PS_table(i,j) = H_table(idx, j);
        end
    end
    if mod(i, 20) == 0, fprintf('  %d/%d\n', i, nS); end
end

%% 2. T(P,H) — 反查温度: 给定 P 和 h, 返回 T
H_min = min(H_table(:)); H_max = max(H_table(:));
nH = 80;
H_PH_vec = linspace(H_min, H_max, nH);
P_PH_vec = P_vec;

T_PH_table = zeros(nH, length(P_PH_vec));

fprintf('生成 T(P,H) 反向表 (%d x %d)...\n', nH, length(P_PH_vec));
for i = 1:nH
    h_target = H_PH_vec(i);
    for j = 1:length(P_PH_vec)
        p_target = P_PH_vec(j);
        h_at_T = interp1(P_vec, H_table', p_target)';
        [~, idx] = min(abs(h_at_T - h_target));
        if idx > 1 && idx < length(T_vec)
            frac = (h_target - h_at_T(idx)) / (h_at_T(idx+1) - h_at_T(idx) + eps);
            T_guess = T_vec(idx) + frac * (T_vec(idx+1) - T_vec(idx));
            T_PH_table(i,j) = max(T_vec(1), min(T_vec(end), T_guess));
        else
            T_PH_table(i,j) = T_vec(idx);
        end
    end
    if mod(i, 20) == 0, fprintf('  %d/%d\n', i, nH); end
end

%% 3. 保存
save(fullfile(fileparts(mfilename('fullpath')), '../../..', 'data/REFPROP_lookup.mat'), ...
     'T_vec', 'P_vec', 'H_table', 'S_table', 'D_table', 'nT', 'nP', ...
     'S_PS_vec', 'P_PS_vec', 'H_PS_table', ...
     'H_PH_vec', 'P_PH_vec', 'T_PH_table', '-append');

fprintf('反向查找表已追加到 REFPROP_lookup.mat\n');
fprintf('  变量: H_PS_table(%dx%d), T_PH_table(%dx%d)\n', nS, length(P_PS_vec), nH, length(P_PH_vec));
