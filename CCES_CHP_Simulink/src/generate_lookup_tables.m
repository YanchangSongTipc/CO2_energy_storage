% =========================================================================
% generate_lookup_tables.m — 预计算 CO2 物性查找表用于 Simulink 仿真
% 基于 REFPROP 生成 T,P → h,s,rho 的二维网格表
% =========================================================================

addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')

libLoc = '/opt/refprop/';
Fluid  = 'CO2';

%% 1. 定义物性网格范围
% 温度网格 [K]: 覆盖 CO2 亚临界/跨临界典型区间
T_vec = [260:2:320, 325:5:550];  % 260-320K 细网格(临界区), 以上粗网格
T_vec = unique(T_vec);

% 压力网格 [MPa]: 覆盖 0.1-7.5 MPa
P_vec = [0.1:0.05:2.0, 2.1:0.2:5.0, 5.2:0.3:7.5];
P_vec = unique(P_vec);

nT = length(T_vec);
nP = length(P_vec);

fprintf('物性网格: %d T点 x %d P点 = %d 个状态点\n', nT, nP, nT*nP);

%% 2. 预分配查找表矩阵
H_table = zeros(nT, nP);    % 焓 [J/kg]
S_table = zeros(nT, nP);    % 熵 [J/(kg·K)]
D_table = zeros(nT, nP);    % 密度 [kg/m^3]
phase_table = zeros(nT, nP); % 相态标志 (1=气相, 0=液相, -1=超临界)

%% 3. 批量调用 REFPROP 填充查找表
fprintf('正在计算...');
tStart = tic;

for i = 1:nT
    for j = 1:nP
        try
            % 并行查询焓、熵、密度
            H_table(i,j) = getFluidProperty(libLoc, 'H', 'T', T_vec(i), 'P', P_vec(j), Fluid, 1, 1, 'MASS BASE SI');
            S_table(i,j) = getFluidProperty(libLoc, 'S', 'T', T_vec(i), 'P', P_vec(j), Fluid, 1, 1, 'MASS BASE SI');
            D_table(i,j) = getFluidProperty(libLoc, 'D', 'T', T_vec(i), 'P', P_vec(j), Fluid, 1, 1, 'MASS BASE SI');
        catch
            H_table(i,j) = NaN;
            S_table(i,j) = NaN;
            D_table(i,j) = NaN;
        end
    end
    if mod(i, 10) == 0
        fprintf(' %d/%d', i, nT);
    end
end
elapsed = toc(tStart);
fprintf('\n计算完成，耗时 %.1f 秒\n', elapsed);

%% 4. 保存查找表数据
save('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/data/REFPROP_lookup.mat', ...
     'T_vec', 'P_vec', 'H_table', 'S_table', 'D_table', 'nT', 'nP');

fprintf('查找表已保存至 REFPROP_lookup.mat\n');

%% 5. 验证：绘制 CO2 相态图确认网格覆盖
figure('Name', 'CO2 Property Lookup Grid Validation', 'Color', 'w');

subplot(221);
contourf(T_vec, P_vec, H_table'/1e3, 30); colorbar;
xlabel('Temperature (K)'); ylabel('Pressure (MPa)');
title('Enthalpy h (kJ/kg)');

subplot(222);
contourf(T_vec, P_vec, S_table'/1e3, 30); colorbar;
xlabel('Temperature (K)'); ylabel('Pressure (MPa)');
title('Entropy s (kJ/kg·K)');

subplot(223);
contourf(T_vec, P_vec, D_table', 30); colorbar;
set(gca, 'ColorScale', 'log');
xlabel('Temperature (K)'); ylabel('Pressure (MPa)');
title('Density \rho (kg/m^3) [log scale]');

subplot(224);
semilogy(T_vec, H_table(:, P_vec>=2 & P_vec<=7)'/1e3, 'LineWidth', 1);
xlabel('Temperature (K)'); ylabel('Enthalpy (kJ/kg)');
title('h(T) at P = 2-7 MPa');
legend(arrayfun(@(p) sprintf('%.1f MPa', p), P_vec(P_vec>=2 & P_vec<=7), 'UniformOutput', false), ...
       'Location', 'best', 'FontSize', 7);
grid on;

saveas(gcf, '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/data/lookup_grid_validation.png');
fprintf('验证图已保存\n');

%% 6. 关键状态点对照校验 (与 Cycle.m 结果对比)
fprintf('\n=== 关键状态点校验 ===\n');
fprintf('节点1 (298K,0.102MPa) H=%.1f J/kg (期望 ~506650)\n', ...
    interp2(P_vec, T_vec, H_table, 0.102, 298));
fprintf('节点5 (500K,6.9MPa)  H=%.1f J/kg (期望 ~695060)\n', ...
    interp2(P_vec, T_vec, H_table, 6.9, 500));
fprintf('节点7 (298K,6.8MPa)  H=%.1f J/kg (期望 ~506650)\n', ...
    interp2(P_vec, T_vec, H_table, 6.8, 298));
