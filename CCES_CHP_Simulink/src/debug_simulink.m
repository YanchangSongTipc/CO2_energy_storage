% =========================================================================
% debug_simulink.m — CCES Simulink 模型调试与测试脚本
% =========================================================================

clc; clear; close all;

%% 1. 环境设置
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src')

%% 2. 前置检查
fprintf('========== 环境检查 ==========\n');

% REFPROP
try
    h = getFluidProperty('/opt/refprop/','H','P',0.102e6,'T',298,'CO2',1,1,'MASS BASE SI');
    fprintf('[OK] REFPROP: H(298K,0.102MPa)=%.1f kJ/kg\n', h/1000);
catch ME
    fprintf('[FAIL] REFPROP: %s\n', ME.message);
end

% 控制器
if exist('cces_controller.m', 'file')
    fprintf('[OK] cces_controller.m 已找到\n');
else
    fprintf('[FAIL] cces_controller.m 未找到\n');
end

% Simulink 模型
if bdIsLoaded('CCES_CHP_System')
    fprintf('[OK] CCES_CHP_System 已加载\n');
else
    fprintf('[INFO] CCES_CHP_System 未加载，请先运行 build_CCES_model\n');
end

%% 3. 构建模型（如需要）
if ~bdIsLoaded('CCES_CHP_System')
    fprintf('\n========== 构建模型 ==========\n');
    try
        build_CCES_model;
        fprintf('[OK] 模型构建成功\n');
    catch ME
        fprintf('[FAIL] 构建失败: %s\n', ME.message);
        return;
    end
end

%% 4. 配置仿真参数
fprintf('\n========== 仿真配置 ==========\n');

model = 'CCES_CHP_System';
stop_time = 600;  % 先跑 10 分钟测试

set_param(model, ...
    'Solver', 'ode45', ...
    'MaxStep', '30', ...
    'StopTime', num2str(stop_time), ...
    'StartTime', '0', ...
    'RelTol', '1e-5');

fprintf('[OK] Solver=ode45, StopTime=%ds, MaxStep=30s\n', stop_time);

%% 5. 添加信号记录（To Workspace）
fprintf('\n========== 添加信号记录 ==========\n');

% 清理旧记录块
ws_blocks = find_system(model, 'BlockType', 'ToWorkspace');
for i = 1:length(ws_blocks)
    delete_block(ws_blocks{i});
end

% 在顶层创建记录块
sig_root = model;
signals = {
    'W_comp_log',  'Charging/2';   % 充电功率 [MW]
    'W_turb_log',  'Discharging/2'; % 放电功率 [MW]
    'P_HPT_log',   'Storage/1';      % HPT 压力 [MPa]
    'Q_HTV_log',   'Thermal/1'; % HTV 蓄热 [MJ]
    'chg_cmd_log', 'Controller/1';         % 充电指令
    'dis_cmd_log', 'Controller/2';         % 放电指令
};

for i = 1:size(signals, 1)
    blk = [sig_root '/' signals{i,1}];
    try
        add_block('simulink/Sinks/To Workspace', blk);
    catch
        delete_block(blk);
        add_block('simulink/Sinks/To Workspace', blk);
    end
    set_param(blk, 'VariableName', signals{i,1});
    try add_line(sig_root, signals{i,2}, [signals{i,1} '/1']); catch, end
end

% 时间记录 (skip if exists)
try
    add_block('simulink/Sinks/To Workspace', [sig_root '/tout_log']);
    set_param([sig_root '/tout_log'], 'VariableName', 'tout_log');
catch
end
try
    add_block('simulink/Sources/Clock', [sig_root '/Clock_for_log']);
    add_line(sig_root, 'Clock_for_log/1', 'tout_log/1');
catch
end

fprintf('[OK] 已添加 %d 个信号记录块\n', size(signals,1));

%% 6. 运行仿真
fprintf('\n========== 仿真中 (%.0f s) ... ==========\n', stop_time);
t_start = tic;

try
    simOut = sim(model, 'SimulationMode', 'normal');
    elapsed = toc(t_start);
    fprintf('[OK] 仿真完成，耗时 %.1f 秒\n', elapsed);
catch ME
    fprintf('[FAIL] 仿真出错: %s\n', ME.message);
    fprintf('检查 Diagnostic Viewer 获取详细信息。\n');
    % 即使出错也尝试分析已记录的数据
end

%% 7. 结果分析
fprintf('\n========== 结果分析 ==========\n');

% 检查各变量是否存在于工作区
vars_to_check = {'W_comp_log', 'W_turb_log', 'P_HPT_log', 'Q_HTV_log', 'tout_log'};
all_ok = true;
for i = 1:length(vars_to_check)
    v = vars_to_check{i};
    if evalin('base', ['exist(''' v ''',''var'')'])
        val = evalin('base', [v '(end)']);
        fprintf('[OK] %s: last=%.4f\n', v, val);
    else
        fprintf('[MISS] %s 未记录（对应子系统可能未激活）\n', v);
        all_ok = false;
    end
end

%% 8. 绘图
if evalin('base', 'exist(''W_comp_log'',''var'')')
    figure('Name', 'Simulink Debug Results', 'Color', 'w', 'Position', [100, 80, 1200, 600]);

    subplot(2,2,1);
    hold on; grid on;
    t = evalin('base', 'tout_log');
    Wc = evalin('base', 'W_comp_log');
    Wt = evalin('base', 'W_turb_log');
    if length(Wc) == length(t)
        stairs(t/60, Wc, 'r', 'LineWidth', 1.5);
    end
    if length(Wt) == length(t)
        stairs(t/60, -Wt, 'b', 'LineWidth', 1.5);
    end
    xlabel('Time (min)'); ylabel('Power (MW)');
    legend('W_{comp}', 'W_{turb}', 'Location', 'best');
    title('Power');

    subplot(2,2,2);
    hold on; grid on;
    P = evalin('base', 'P_HPT_log');
    if length(P) == length(t)
        plot(t/60, P, 'g', 'LineWidth', 2);
        yline(6.80, 'r--'); yline(0.12, 'r--');
    end
    xlabel('Time (min)'); ylabel('P_{HPT} (MPa)');
    title('HPT Pressure');

    subplot(2,2,3);
    hold on; grid on;
    Q = evalin('base', 'Q_HTV_log');
    if length(Q) == length(t)
        plot(t/60, Q/3600, 'r', 'LineWidth', 2);
    end
    xlabel('Time (min)'); ylabel('Q_{HTV} (MWh_{th})');
    title('Thermal Storage');

    subplot(2,2,4);
    hold on; grid on;
    if exist('chg_cmd_log', 'var')
        cc = evalin('base', 'chg_cmd_log');
        dc = evalin('base', 'dis_cmd_log');
        if length(cc) == length(t)
            stairs(t/60, cc, 'r', 'LineWidth', 1);
            stairs(t/60, -dc, 'b', 'LineWidth', 1);
        end
    end
    xlabel('Time (min)'); ylabel('Command (MW)');
    legend('Charge', 'Discharge', 'Location', 'best');
    title('Controller Commands');

    sgtitle('CCES Simulink Debug Run', 'FontSize', 14, 'FontWeight', 'bold');
    fprintf('[OK] 图表已生成\n');
end

fprintf('\n========== 调试完成 ==========\n');
fprintf('提示:\n');
fprintf('  - 如果 W_comp/W_turb 恒为 0，检查 Controller 和子系统使能\n');
fprintf('  - 如果物性报错，检查 T,P 是否超出 CO2 有效范围\n');
fprintf('  - 仿真过慢: 增大 MaxStep，或使用预计算查找表\n');
fprintf('  - 用 slDebug(model) 进入 Simulink 调试器逐步执行\n');
