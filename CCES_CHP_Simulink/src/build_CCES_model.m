% =========================================================================
% build_CCES_model.m — 程序化构建 CCES-CHP Simulink 动态仿真模型
% =========================================================================

function build_CCES_model()
    model = 'CCES_CHP_System';

    if bdIsLoaded(model)
        close_system(model, 0);
    end
    new_system(model, 'Model');

    set_param(model, ...
        'Solver', 'ode45', 'MaxStep', '60', ...
        'StopTime', '86400', 'StartTime', '0', 'RelTol', '1e-4');

    %% 创建子系统层次 (所有路径字符串显式构建)
    p = @(sub) [model '/' sub];

    add_block('simulink/Ports & Subsystems/Subsystem', p('Charging_System'));
    add_block('simulink/Ports & Subsystems/Subsystem', p('Discharging_System'));
    add_block('simulink/Ports & Subsystems/Subsystem', p('Storage_Tanks'));
    add_block('simulink/Ports & Subsystems/Subsystem', p('Thermal_Oil_System'));
    add_block('simulink/Ports & Subsystems/Subsystem', p('Controller'));
    add_block('simulink/Ports & Subsystems/Subsystem', p('Results'));

    set_param(p('Charging_System'),    'Position', [150, 50, 450, 400]);
    set_param(p('Discharging_System'), 'Position', [150, 450, 450, 800]);
    set_param(p('Storage_Tanks'),      'Position', [550, 50, 850, 400]);
    set_param(p('Thermal_Oil_System'), 'Position', [550, 450, 850, 800]);
    set_param(p('Controller'),         'Position', [50, 250, 150, 550]);
    set_param(p('Results'),            'Position', [950, 250, 1200, 550]);

    %% 构建各子系统内部
    build_charging(p('Charging_System'));
    build_discharging(p('Discharging_System'));
    build_storage(p('Storage_Tanks'));
    build_thermal(p('Thermal_Oil_System'));
    build_control(p('Controller'));
    build_results(p('Results'));

    %% 保存
    save_system(model, '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/data/CCES_CHP_System');
    fprintf('CCES_CHP_System 构建完成。\n');
    open_system(model);
end

% ==================== 充电系统 ====================
function build_charging(parent)
    Simulink.SubSystem.deleteContents(parent);

    b = @(name) [parent '/' name];

    % 入口
    add_block('simulink/Ports & Subsystems/In1', b('cmd'));
    set_param(b('cmd'), 'Position', [50, 150, 80, 170], 'Port', '1');

    add_block('simulink/Sources/Constant', b('T_amb'));
    set_param(b('T_amb'), 'Position', [50, 250, 100, 270], 'Value', '298');
    add_block('simulink/Sources/Constant', b('P_amb'));
    set_param(b('P_amb'), 'Position', [50, 320, 100, 340], 'Value', '0.102e6');
    add_block('simulink/Sources/Constant', b('m_dot'));
    set_param(b('m_dot'), 'Position', [50, 390, 100, 410], 'Value', '26.9');

    % C1, IC1, C2, IC2, LHE
    add_block('simulink/Ports & Subsystems/Subsystem', b('C1'));
    set_param(b('C1'), 'Position', [180, 80, 320, 260]);
    build_comp(b('C1'), 0.90e6, 0.85);

    add_block('simulink/Ports & Subsystems/Subsystem', b('IC1'));
    set_param(b('IC1'), 'Position', [400, 80, 520, 220]);
    build_hex(b('IC1'), 308);

    add_block('simulink/Ports & Subsystems/Subsystem', b('C2'));
    set_param(b('C2'), 'Position', [600, 80, 740, 260]);
    build_comp(b('C2'), 6.90e6, 0.85);

    add_block('simulink/Ports & Subsystems/Subsystem', b('IC2'));
    set_param(b('IC2'), 'Position', [820, 80, 940, 220]);
    build_hex(b('IC2'), 309);

    add_block('simulink/Ports & Subsystems/Subsystem', b('LHE'));
    set_param(b('LHE'), 'Position', [1020, 80, 1140, 220]);
    build_hex(b('LHE'), 298);

    % 汇总
    add_block('simulink/Math Operations/Add', b('Sum_W'));
    set_param(b('Sum_W'), 'Position', [1250, 150, 1290, 200], 'Inputs', '++', 'IconShape', 'round');
    add_block('simulink/Math Operations/Add', b('Sum_Q'));
    set_param(b('Sum_Q'), 'Position', [1250, 250, 1290, 300], 'Inputs', '++', 'IconShape', 'round');

    % 出口
    add_block('simulink/Ports & Subsystems/Out1', b('P_out'));
    set_param(b('P_out'), 'Position', [1400, 200, 1430, 220], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('W_out'));
    set_param(b('W_out'), 'Position', [1400, 280, 1430, 300], 'Port', '2');
    add_block('simulink/Ports & Subsystems/Out1', b('Q_out'));
    set_param(b('Q_out'), 'Position', [1400, 360, 1430, 380], 'Port', '3');

    % 连线
    add_line(parent, 'T_amb/1', 'C1/1', 'autorouting', 'smart');
    add_line(parent, 'P_amb/1', 'C1/2', 'autorouting', 'smart');
    add_line(parent, 'm_dot/1', 'C1/3', 'autorouting', 'smart');
    add_line(parent, 'C1/1', 'IC1/1', 'autorouting', 'smart');
    add_line(parent, 'C1/2', 'IC1/2', 'autorouting', 'smart');
    add_line(parent, 'C1/4', 'IC1/3', 'autorouting', 'smart');
    add_line(parent, 'IC1/1', 'C2/1', 'autorouting', 'smart');
    add_line(parent, 'IC1/2', 'C2/2', 'autorouting', 'smart');
    add_line(parent, 'IC1/4', 'C2/3', 'autorouting', 'smart');
    add_line(parent, 'C2/1', 'IC2/1', 'autorouting', 'smart');
    add_line(parent, 'C2/2', 'IC2/2', 'autorouting', 'smart');
    add_line(parent, 'C2/4', 'IC2/3', 'autorouting', 'smart');
    add_line(parent, 'IC2/1', 'LHE/1', 'autorouting', 'smart');
    add_line(parent, 'IC2/2', 'LHE/2', 'autorouting', 'smart');
    add_line(parent, 'IC2/4', 'LHE/3', 'autorouting', 'smart');

    add_line(parent, 'C1/3', 'Sum_W/1', 'autorouting', 'smart');
    add_line(parent, 'C2/3', 'Sum_W/2', 'autorouting', 'smart');
    add_line(parent, 'IC1/3', 'Sum_Q/1', 'autorouting', 'smart');
    add_line(parent, 'IC2/3', 'Sum_Q/2', 'autorouting', 'smart');

    add_line(parent, 'LHE/2', 'P_out/1', 'autorouting', 'smart');
    add_line(parent, 'Sum_W/1', 'W_out/1', 'autorouting', 'smart');
    add_line(parent, 'Sum_Q/1', 'Q_out/1', 'autorouting', 'smart');

    set_param(parent, 'TreatAsAtomicUnit', 'on');
end

% ==================== 压缩器 ====================
function build_comp(parent, P_out, eta)
    Simulink.SubSystem.deleteContents(parent);
    b = @(name) [parent '/' name];

    add_block('simulink/Ports & Subsystems/In1', b('T_in'));
    set_param(b('T_in'), 'Position', [30, 60, 60, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('P_in'));
    set_param(b('P_in'), 'Position', [30, 110, 60, 130], 'Port', '2');
    add_block('simulink/Ports & Subsystems/In1', b('m_in'));
    set_param(b('m_in'), 'Position', [30, 160, 60, 180], 'Port', '3');

    % 物性通过 Interpreted MATLAB Fcn 调用 getFluidProperty
    add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', b('h_in'));
    set_param(b('h_in'), 'Position', [120, 50, 220, 90], ...
        'MATLABFcn', 'getFluidProperty(''/opt/refprop/'',''H'',''T'',u(1),''P'',u(2),''CO2'',1,1,''MASS BASE SI'')');

    add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', b('s_in'));
    set_param(b('s_in'), 'Position', [120, 110, 220, 150], ...
        'MATLABFcn', 'getFluidProperty(''/opt/refprop/'',''S'',''T'',u(1),''P'',u(2),''CO2'',1,1,''MASS BASE SI'')');

    % h_out_is = f(P_out, s_in)
    add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', b('h_is'));
    set_param(b('h_is'), 'Position', [300, 80, 420, 140], ...
        'MATLABFcn', 'getFluidProperty(''/opt/refprop/'',''H'',''P'',u(2),''S'',u(1),''CO2'',1,1,''MASS BASE SI'')');

    add_block('simulink/Sources/Constant', b('P_target'));
    set_param(b('P_target'), 'Value', num2str(P_out), 'Position', [300, 160, 340, 180]);

    % 实际出口焓: h_out = h_in + (h_is - h_in)/eta
    add_block('simulink/User-Defined Functions/Fcn', b('h_out'));
    set_param(b('h_out'), 'Position', [520, 80, 620, 140], ...
        'Expr', sprintf('u(1) + (u(2) - u(1))/%.4f', eta));

    % 出口温度: T_out = f(P_out, h_out)
    add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', b('T_out_c'));
    set_param(b('T_out_c'), 'Position', [700, 60, 820, 120], ...
        'MATLABFcn', 'getFluidProperty(''/opt/refprop/'',''T'',''P'',u(2),''H'',u(1),''CO2'',1,1,''MASS BASE SI'')');

    % 功率: W = m_dot * (h_out - h_in) / 1e6
    add_block('simulink/User-Defined Functions/Fcn', b('W_calc'));
    set_param(b('W_calc'), 'Position', [700, 150, 790, 210], ...
        'Expr', 'u(1) * (u(2) - u(3)) / 1e6');

    % 出口端口
    add_block('simulink/Ports & Subsystems/Out1', b('T_out'));
    set_param(b('T_out'), 'Position', [920, 60, 950, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('P_out'));
    set_param(b('P_out'), 'Position', [920, 110, 950, 130], 'Port', '2');
    add_block('simulink/Ports & Subsystems/Out1', b('W_out'));
    set_param(b('W_out'), 'Position', [920, 160, 950, 180], 'Port', '3');
    add_block('simulink/Ports & Subsystems/Out1', b('m_out'));
    set_param(b('m_out'), 'Position', [920, 210, 950, 230], 'Port', '4');

    % 连线
    add_line(parent, 'T_in/1', 'h_in/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 'h_in/2', 'autorouting', 'smart');
    add_line(parent, 'T_in/1', 's_in/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 's_in/2', 'autorouting', 'smart');
    add_line(parent, 's_in/1', 'h_is/1', 'autorouting', 'smart');
    add_line(parent, 'P_target/1', 'h_is/2', 'autorouting', 'smart');
    add_line(parent, 'h_in/1', 'h_out/1', 'autorouting', 'smart');
    add_line(parent, 'h_is/1', 'h_out/2', 'autorouting', 'smart');
    add_line(parent, 'h_out/1', 'T_out_c/1', 'autorouting', 'smart');
    add_line(parent, 'P_target/1', 'T_out_c/2', 'autorouting', 'smart');
    add_line(parent, 'm_in/1', 'W_calc/1', 'autorouting', 'smart');
    add_line(parent, 'h_out/1', 'W_calc/2', 'autorouting', 'smart');
    add_line(parent, 'h_in/1', 'W_calc/3', 'autorouting', 'smart');
    add_line(parent, 'T_out_c/1', 'T_out/1', 'autorouting', 'smart');
    add_line(parent, 'P_target/1', 'P_out/1', 'autorouting', 'smart');
    add_line(parent, 'W_calc/1', 'W_out/1', 'autorouting', 'smart');
    add_line(parent, 'm_in/1', 'm_out/1', 'autorouting', 'smart');
end

% ==================== 换热器 ====================
function build_hex(parent, T_out_target)
    Simulink.SubSystem.deleteContents(parent);
    b = @(name) [parent '/' name];

    add_block('simulink/Ports & Subsystems/In1', b('T_in'));
    set_param(b('T_in'), 'Position', [30, 60, 60, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('P_in'));
    set_param(b('P_in'), 'Position', [30, 120, 60, 140], 'Port', '2');
    add_block('simulink/Ports & Subsystems/In1', b('m_in'));
    set_param(b('m_in'), 'Position', [30, 180, 60, 200], 'Port', '3');

    % h_in = f(T,P)
    add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', b('h_in_fn'));
    set_param(b('h_in_fn'), 'Position', [120, 50, 240, 90], ...
        'MATLABFcn', 'getFluidProperty(''/opt/refprop/'',''H'',''T'',u(1),''P'',u(2),''CO2'',1,1,''MASS BASE SI'')');

    % h_out = f(T_target, P)
    add_block('simulink/Sources/Constant', b('T_target'));
    set_param(b('T_target'), 'Value', num2str(T_out_target), 'Position', [120, 130, 160, 150]);
    add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', b('h_out_fn'));
    set_param(b('h_out_fn'), 'Position', [200, 130, 320, 170], ...
        'MATLABFcn', 'getFluidProperty(''/opt/refprop/'',''H'',''T'',u(1),''P'',u(2),''CO2'',1,1,''MASS BASE SI'')');

    % Q = m_dot * abs(h_in - h_out) / 1e6
    add_block('simulink/User-Defined Functions/Fcn', b('Q_calc'));
    set_param(b('Q_calc'), 'Position', [400, 90, 500, 160], ...
        'Expr', 'abs(u(1) * (u(2) - u(3))) / 1e6');

    % 出口
    add_block('simulink/Ports & Subsystems/Out1', b('T_out'));
    set_param(b('T_out'), 'Position', [620, 60, 650, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('P_out'));
    set_param(b('P_out'), 'Position', [620, 120, 650, 140], 'Port', '2');
    add_block('simulink/Ports & Subsystems/Out1', b('Q_out'));
    set_param(b('Q_out'), 'Position', [620, 180, 650, 200], 'Port', '3');
    add_block('simulink/Ports & Subsystems/Out1', b('m_out'));
    set_param(b('m_out'), 'Position', [620, 240, 650, 260], 'Port', '4');

    % 连线
    add_line(parent, 'T_in/1', 'h_in_fn/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 'h_in_fn/2', 'autorouting', 'smart');
    add_line(parent, 'T_target/1', 'h_out_fn/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 'h_out_fn/2', 'autorouting', 'smart');
    add_line(parent, 'm_in/1', 'Q_calc/1', 'autorouting', 'smart');
    add_line(parent, 'h_in_fn/1', 'Q_calc/2', 'autorouting', 'smart');
    add_line(parent, 'h_out_fn/1', 'Q_calc/3', 'autorouting', 'smart');
    add_line(parent, 'T_target/1', 'T_out/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 'P_out/1', 'autorouting', 'smart');
    add_line(parent, 'Q_calc/1', 'Q_out/1', 'autorouting', 'smart');
    add_line(parent, 'm_in/1', 'm_out/1', 'autorouting', 'smart');
end

% ==================== 放电系统 ====================
function build_discharging(parent)
    Simulink.SubSystem.deleteContents(parent);
    b = @(name) [parent '/' name];

    add_block('simulink/Ports & Subsystems/In1', b('cmd'));
    set_param(b('cmd'), 'Position', [50, 150, 80, 170], 'Port', '1');

    add_block('simulink/Sources/Constant', b('T_in'));
    set_param(b('T_in'), 'Position', [50, 250, 100, 270], 'Value', '296');
    add_block('simulink/Sources/Constant', b('P_in'));
    set_param(b('P_in'), 'Position', [50, 320, 100, 340], 'Value', '6.65e6');
    add_block('simulink/Sources/Constant', b('m_dot'));
    set_param(b('m_dot'), 'Position', [50, 390, 100, 410], 'Value', '40.3');

    % T1, T2 透平
    add_block('simulink/Ports & Subsystems/Subsystem', b('Turbine1'));
    set_param(b('Turbine1'), 'Position', [250, 80, 400, 280]);
    build_turb(b('Turbine1'), 0.70e6, 0.88);

    add_block('simulink/Ports & Subsystems/Subsystem', b('Heater'));
    set_param(b('Heater'), 'Position', [480, 80, 600, 220]);
    build_hex(b('Heater'), 483);

    add_block('simulink/Ports & Subsystems/Subsystem', b('Turbine2'));
    set_param(b('Turbine2'), 'Position', [680, 80, 830, 280]);
    build_turb(b('Turbine2'), 0.12e6, 0.88);

    add_block('simulink/Ports & Subsystems/Subsystem', b('Cooler'));
    set_param(b('Cooler'), 'Position', [910, 80, 1030, 220]);
    build_hex(b('Cooler'), 298);

    % 汇总
    add_block('simulink/Math Operations/Add', b('Sum_W'));
    set_param(b('Sum_W'), 'Position', [1120, 150, 1160, 200], 'Inputs', '++', 'IconShape', 'round');
    add_block('simulink/Math Operations/Add', b('Sum_Q'));
    set_param(b('Sum_Q'), 'Position', [1120, 250, 1160, 300], 'Inputs', '++', 'IconShape', 'round');

    % 出口
    add_block('simulink/Ports & Subsystems/Out1', b('P_out'));
    set_param(b('P_out'), 'Position', [1280, 200, 1310, 220], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('W_out'));
    set_param(b('W_out'), 'Position', [1280, 280, 1310, 300], 'Port', '2');
    add_block('simulink/Ports & Subsystems/Out1', b('Q_out'));
    set_param(b('Q_out'), 'Position', [1280, 360, 1310, 380], 'Port', '3');

    % 连线
    add_line(parent, 'T_in/1', 'Turbine1/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 'Turbine1/2', 'autorouting', 'smart');
    add_line(parent, 'm_dot/1', 'Turbine1/3', 'autorouting', 'smart');
    add_line(parent, 'Turbine1/1', 'Heater/1', 'autorouting', 'smart');
    add_line(parent, 'Turbine1/2', 'Heater/2', 'autorouting', 'smart');
    add_line(parent, 'Turbine1/4', 'Heater/3', 'autorouting', 'smart');
    add_line(parent, 'Heater/1', 'Turbine2/1', 'autorouting', 'smart');
    add_line(parent, 'Heater/2', 'Turbine2/2', 'autorouting', 'smart');
    add_line(parent, 'Heater/4', 'Turbine2/3', 'autorouting', 'smart');
    add_line(parent, 'Turbine2/1', 'Cooler/1', 'autorouting', 'smart');
    add_line(parent, 'Turbine2/2', 'Cooler/2', 'autorouting', 'smart');
    add_line(parent, 'Turbine2/4', 'Cooler/3', 'autorouting', 'smart');

    add_line(parent, 'Turbine1/3', 'Sum_W/1', 'autorouting', 'smart');
    add_line(parent, 'Turbine2/3', 'Sum_W/2', 'autorouting', 'smart');
    add_line(parent, 'Sum_W/1', 'W_out/1', 'autorouting', 'smart');

    add_line(parent, 'Cooler/2', 'P_out/1', 'autorouting', 'smart');

    set_param(parent, 'TreatAsAtomicUnit', 'on');
end

% ==================== 透平 ====================
function build_turb(parent, P_out, eta)
    Simulink.SubSystem.deleteContents(parent);
    b = @(name) [parent '/' name];

    add_block('simulink/Ports & Subsystems/In1', b('T_in'));
    set_param(b('T_in'), 'Position', [30, 60, 60, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('P_in'));
    set_param(b('P_in'), 'Position', [30, 120, 60, 140], 'Port', '2');
    add_block('simulink/Ports & Subsystems/In1', b('m_in'));
    set_param(b('m_in'), 'Position', [30, 180, 60, 200], 'Port', '3');

    add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', b('h_in'));
    set_param(b('h_in'), 'Position', [120, 50, 220, 90], ...
        'MATLABFcn', 'getFluidProperty(''/opt/refprop/'',''H'',''T'',u(1),''P'',u(2),''CO2'',1,1,''MASS BASE SI'')');

    add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', b('s_in'));
    set_param(b('s_in'), 'Position', [120, 110, 220, 150], ...
        'MATLABFcn', 'getFluidProperty(''/opt/refprop/'',''S'',''T'',u(1),''P'',u(2),''CO2'',1,1,''MASS BASE SI'')');

    add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', b('h_is'));
    set_param(b('h_is'), 'Position', [300, 80, 420, 140], ...
        'MATLABFcn', 'getFluidProperty(''/opt/refprop/'',''H'',''P'',u(2),''S'',u(1),''CO2'',1,1,''MASS BASE SI'')');

    add_block('simulink/Sources/Constant', b('P_target'));
    set_param(b('P_target'), 'Value', num2str(P_out), 'Position', [300, 160, 340, 180]);

    add_block('simulink/User-Defined Functions/Fcn', b('h_out'));
    set_param(b('h_out'), 'Position', [520, 80, 620, 140], ...
        'Expr', sprintf('u(1) - %.4f * (u(1) - u(2))', eta));

    add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', b('T_out_c'));
    set_param(b('T_out_c'), 'Position', [700, 60, 820, 120], ...
        'MATLABFcn', 'getFluidProperty(''/opt/refprop/'',''T'',''P'',u(2),''H'',u(1),''CO2'',1,1,''MASS BASE SI'')');

    add_block('simulink/User-Defined Functions/Fcn', b('W_calc'));
    set_param(b('W_calc'), 'Position', [700, 150, 790, 210], ...
        'Expr', 'u(1) * (u(2) - u(3)) / 1e6');

    add_block('simulink/Ports & Subsystems/Out1', b('T_out'));
    set_param(b('T_out'), 'Position', [920, 60, 950, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('P_out'));
    set_param(b('P_out'), 'Position', [920, 120, 950, 140], 'Port', '2');
    add_block('simulink/Ports & Subsystems/Out1', b('W_out'));
    set_param(b('W_out'), 'Position', [920, 180, 950, 200], 'Port', '3');
    add_block('simulink/Ports & Subsystems/Out1', b('m_out'));
    set_param(b('m_out'), 'Position', [920, 240, 950, 260], 'Port', '4');

    add_line(parent, 'T_in/1', 'h_in/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 'h_in/2', 'autorouting', 'smart');
    add_line(parent, 'T_in/1', 's_in/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 's_in/2', 'autorouting', 'smart');
    add_line(parent, 's_in/1', 'h_is/1', 'autorouting', 'smart');
    add_line(parent, 'P_target/1', 'h_is/2', 'autorouting', 'smart');
    add_line(parent, 'h_in/1', 'h_out/1', 'autorouting', 'smart');
    add_line(parent, 'h_is/1', 'h_out/2', 'autorouting', 'smart');
    add_line(parent, 'h_out/1', 'T_out_c/1', 'autorouting', 'smart');
    add_line(parent, 'P_target/1', 'T_out_c/2', 'autorouting', 'smart');
    add_line(parent, 'm_in/1', 'W_calc/1', 'autorouting', 'smart');
    add_line(parent, 'h_in/1', 'W_calc/2', 'autorouting', 'smart');
    add_line(parent, 'h_out/1', 'W_calc/3', 'autorouting', 'smart');
    add_line(parent, 'T_out_c/1', 'T_out/1', 'autorouting', 'smart');
    add_line(parent, 'P_target/1', 'P_out/1', 'autorouting', 'smart');
    add_line(parent, 'W_calc/1', 'W_out/1', 'autorouting', 'smart');
    add_line(parent, 'm_in/1', 'm_out/1', 'autorouting', 'smart');
end

% ==================== 储罐 ====================
function build_storage(parent)
    Simulink.SubSystem.deleteContents(parent);
    b = @(name) [parent '/' name];

    add_block('simulink/Ports & Subsystems/In1', b('m_dot_in'));
    set_param(b('m_dot_in'), 'Position', [30, 60, 60, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('m_dot_out'));
    set_param(b('m_dot_out'), 'Position', [30, 140, 60, 160], 'Port', '2');

    % 净质量 = m_in - m_out
    add_block('simulink/Math Operations/Sum', b('net_m'));
    set_param(b('net_m'), 'Position', [150, 80, 180, 120], 'Inputs', '+-', 'IconShape', 'round');

    % 积分器: HPT质量
    add_block('simulink/Continuous/Integrator', b('mass'));
    set_param(b('mass'), 'Position', [280, 80, 330, 120], 'InitialCondition', '3.4e5');

    % P = m*R*T/V
    add_block('simulink/User-Defined Functions/Fcn', b('pressure'));
    set_param(b('pressure'), 'Position', [420, 80, 500, 120], ...
        'Expr', 'u * 188.9 * 298 / 6228 / 1e6');

    add_block('simulink/Ports & Subsystems/Out1', b('P_MPa'));
    set_param(b('P_MPa'), 'Position', [600, 80, 630, 100], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('mass_kg'));
    set_param(b('mass_kg'), 'Position', [600, 160, 630, 180], 'Port', '2');

    add_line(parent, 'm_dot_in/1', 'net_m/1', 'autorouting', 'smart');
    add_line(parent, 'm_dot_out/1', 'net_m/2', 'autorouting', 'smart');
    add_line(parent, 'net_m/1', 'mass/1', 'autorouting', 'smart');
    add_line(parent, 'mass/1', 'pressure/1', 'autorouting', 'smart');
    add_line(parent, 'pressure/1', 'P_MPa/1', 'autorouting', 'smart');
    add_line(parent, 'mass/1', 'mass_kg/1', 'autorouting', 'smart');
end

% ==================== 蓄热 ====================
function build_thermal(parent)
    Simulink.SubSystem.deleteContents(parent);
    b = @(name) [parent '/' name];

    add_block('simulink/Ports & Subsystems/In1', b('Q_in'));
    set_param(b('Q_in'), 'Position', [30, 60, 60, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('Q_out'));
    set_param(b('Q_out'), 'Position', [30, 140, 60, 160], 'Port', '2');

    add_block('simulink/Math Operations/Sum', b('net_Q'));
    set_param(b('net_Q'), 'Position', [150, 80, 180, 120], 'Inputs', '+-', 'IconShape', 'round');

    add_block('simulink/Continuous/Integrator', b('Q_store'));
    set_param(b('Q_store'), 'Position', [280, 80, 330, 120], 'InitialCondition', '270000');

    add_block('simulink/Ports & Subsystems/Out1', b('Q_MJ'));
    set_param(b('Q_MJ'), 'Position', [450, 80, 480, 100], 'Port', '1');

    add_line(parent, 'Q_in/1', 'net_Q/1', 'autorouting', 'smart');
    add_line(parent, 'Q_out/1', 'net_Q/2', 'autorouting', 'smart');
    add_line(parent, 'net_Q/1', 'Q_store/1', 'autorouting', 'smart');
    add_line(parent, 'Q_store/1', 'Q_MJ/1', 'autorouting', 'smart');
end

% ==================== 控制器 ====================
function build_control(parent)
    Simulink.SubSystem.deleteContents(parent);
    b = @(name) [parent '/' name];

    add_block('simulink/Ports & Subsystems/In1', b('P_HPT'));
    set_param(b('P_HPT'), 'Position', [30, 60, 60, 80], 'Port', '1');

    add_block('simulink/Sources/Clock', b('Clock'));
    set_param(b('Clock'), 'Position', [30, 140, 60, 160]);

    add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', b('logic'));
    set_param(b('logic'), 'Position', [180, 80, 330, 140], ...
        'MATLABFcn', 'cces_controller(u(1),u(2))');

    add_block('simulink/Ports & Subsystems/Out1', b('charge_cmd'));
    set_param(b('charge_cmd'), 'Position', [480, 60, 510, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('discharge_cmd'));
    set_param(b('discharge_cmd'), 'Position', [480, 140, 510, 160], 'Port', '2');

    add_line(parent, 'P_HPT/1', 'logic/1', 'autorouting', 'smart');
    add_line(parent, 'Clock/1', 'logic/2', 'autorouting', 'smart');
    add_line(parent, 'logic/1', 'charge_cmd/1', 'autorouting', 'smart');
    add_line(parent, 'logic/2', 'discharge_cmd/1', 'autorouting', 'smart');
end

% ==================== 结果显示 ====================
function build_results(parent)
    Simulink.SubSystem.deleteContents(parent);
    b = @(name) [parent '/' name];

    add_block('simulink/Ports & Subsystems/In1', b('W_comp'));
    set_param(b('W_comp'), 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('W_turb'));
    set_param(b('W_turb'), 'Port', '2');
    add_block('simulink/Ports & Subsystems/In1', b('P_HPT'));
    set_param(b('P_HPT'), 'Port', '3');
    add_block('simulink/Ports & Subsystems/In1', b('Q_HTV'));
    set_param(b('Q_HTV'), 'Port', '4');

    add_block('simulink/Sinks/Scope', b('Power'));
    set_param(b('Power'), 'Position', [200, 50, 500, 250], 'NumInputPorts', '2');
    add_block('simulink/Sinks/Scope', b('Storage'));
    set_param(b('Storage'), 'Position', [200, 300, 500, 500], 'NumInputPorts', '2');

    add_line(parent, 'W_comp/1', 'Power/1', 'autorouting', 'smart');
    add_line(parent, 'W_turb/1', 'Power/2', 'autorouting', 'smart');
    add_line(parent, 'P_HPT/1', 'Storage/1', 'autorouting', 'smart');
    add_line(parent, 'Q_HTV/1', 'Storage/2', 'autorouting', 'smart');
end
