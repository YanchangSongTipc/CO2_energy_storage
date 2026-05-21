% =========================================================================
% debug_simulink.m — CCES Simulink 模型快速调试
% =========================================================================

clc; clear; close all;

%% 1. 环境
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src')
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src/simulink')


model = 'CCES_CHP_System';

%% 2. 构建
fprintf('========== 构建模型 ==========\n');
try
    build_CCES_model;
    fprintf('[OK] 构建成功\n');
catch ME
    fprintf('[FAIL] %s\n', ME.message);
    return;
end

%% 3. 加载查找表
fprintf('\n========== 加载查找表 ==========\n');
lut_file = '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/data/REFPROP_lookup.mat';
data = load(lut_file);
mw = get_param(model, 'ModelWorkspace');
for f = fieldnames(data)'
    mw.assignin(f{1}, data.(f{1}));
    assignin('base', f{1}, data.(f{1}));
end
fprintf('[OK] 查找表已加载\n');

%% 4. 短时间编译检查
fprintf('\n========== 编译检查 ==========\n');
set_param(model, 'StopTime', '10', 'MaxStep', '1');

try
    % 只编译不运行
    set_param(model, 'SimulationCommand', 'update');
    fprintf('[OK] 模型编译通过!\n');
catch ME
    fprintf('[FAIL] 编译错误:\n');
    fprintf('  %s\n', ME.message);
    % 尝试获取更多错误信息
    diag = sldiagviewer;
    fprintf('  请检查 Diagnostic Viewer\n');
    return;
end

%% 5. 添加输出端口用于数据记录
fprintf('\n========== 添加输出端口 ==========\n');
% 给各子系统 Outport 挂 scope 以便调试
all_scopes = find_system(model, 'BlockType', 'Scope');
fprintf('  已存在 Scope: %d 个\n', length(all_scopes));

%% 6. 运行 60 秒仿真
fprintf('\n========== 运行仿真 (60s) ==========\n');
set_param(model, 'StopTime', '60', 'MaxStep', '10');
t_start = tic;
try
    simOut = sim(model, 'CaptureErrors', 'on');
    t_elapsed = toc(t_start);
    fprintf('[OK] 仿真完成 (%.1f s)\n', t_elapsed);
catch ME
    fprintf('[FAIL] 仿真错误: %s\n', ME.message);
    fprintf('完整错误信息:\n');
    for i = 1:length(ME.cause)
        fprintf('  cause{%d}: %s\n', i, ME.cause{i}.message);
    end
    return;
end

%% 7. 读取 scope 数据
fprintf('\n========== Scope 数据 ==========\n');
scopes = find_system(model, 'BlockType', 'Scope');
for i = 1:length(scopes)
    name = get_param(scopes{i}, 'Name');
    try
        % 获取 scope 数据
        scopeConfig = get_param(scopes{i}, 'ScopeConfiguration');
        ds = scopeConfig.DataLogging;
        fprintf('  %s: %s\n', name, ds);
    catch
    end
end
