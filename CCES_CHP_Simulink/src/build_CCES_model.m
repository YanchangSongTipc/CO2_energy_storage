% =========================================================================
% build_CCES_model.m — CCES-CHP Simulink 模型 (2-D Lookup Table)
% 使用预计算 REFPROP 查找表替代 Interpreted MATLAB Fcn 块
% 解决信号维度传播问题，支持编译和代码生成
% =========================================================================

function build_CCES_model()
    model = 'CCES_CHP_System';
    if bdIsLoaded(model), close_system(model, 0); end
    new_system(model, 'Model');

    set_param(model, 'Solver', 'ode45', 'MaxStep', '30', ...
        'StopTime', '86400', 'StartTime', '0', 'RelTol', '1e-4');

    % 加载查找表到 Model Workspace
    if ~exist('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/data/REFPROP_lookup.mat', 'file')
        error('请先运行 generate_lookup_tables.m 和 generate_reverse_lookup.m');
    end
    data = load('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/data/REFPROP_lookup.mat');
    mw = get_param(model, 'ModelWorkspace');
    for f = fieldnames(data)'
        mw.assignin(f{1}, data.(f{1}));
    end

    p = @(sub) [model '/' sub];

    % 创建顶层子系统
    add_block('simulink/Ports & Subsystems/Subsystem', p('Charging'));
    add_block('simulink/Ports & Subsystems/Subsystem', p('Discharging'));
    add_block('simulink/Ports & Subsystems/Subsystem', p('Storage'));
    add_block('simulink/Ports & Subsystems/Subsystem', p('Thermal'));
    add_block('simulink/Ports & Subsystems/Subsystem', p('Controller'));
    add_block('simulink/Ports & Subsystems/Subsystem', p('Results'));

    set_param(p('Charging'),    'Position', [100, 40, 450, 380]);
    set_param(p('Discharging'), 'Position', [100, 420, 450, 760]);
    set_param(p('Storage'),     'Position', [550, 40, 900, 380]);
    set_param(p('Thermal'),     'Position', [550, 420, 900, 760]);
    set_param(p('Controller'),  'Position', [40, 230, 140, 570]);
    set_param(p('Results'),     'Position', [960, 230, 1120, 570]);

    % 构建内部
    build_charging(p('Charging'));
    build_discharging(p('Discharging'));
    build_storage(p('Storage'));
    build_thermal(p('Thermal'));
    build_control(p('Controller'));
    build_results(p('Results'));

    % 顶层闭环连线: Controller → Gains → Storage/Thermal
    % 耦合系数 Gain 块
    add_block('simulink/Math Operations/Gain', [model '/alpha1_gain']);
    set_param([model '/alpha1_gain'], 'Gain', '2.744', 'Position', [50, 100, 90, 130]);
    add_block('simulink/Math Operations/Gain', [model '/alpha2_gain']);
    set_param([model '/alpha2_gain'], 'Gain', '2.744', 'Position', [50, 170, 90, 200]);
    add_block('simulink/Math Operations/Gain', [model '/beta1_gain']);
    set_param([model '/beta1_gain'], 'Gain', '1.185', 'Position', [50, 240, 90, 270]);
    add_block('simulink/Math Operations/Gain', [model '/beta2_gain']);
    set_param([model '/beta2_gain'], 'Gain', '2.307', 'Position', [50, 310, 90, 340]);
    % Q 量纲 MJ→MWh
    add_block('simulink/Math Operations/Gain', [model '/Q_MWh_gain']);
    set_param([model '/Q_MWh_gain'], 'Gain', '1/3600', 'Position', [60, 500, 100, 530]);

    % Controller cmd → Gains → Storage/Thermal
    add_line(model, 'Controller/1', 'alpha1_gain/1');
    add_line(model, 'alpha1_gain/1', 'Storage/1');
    add_line(model, 'Controller/2', 'alpha2_gain/1');
    add_line(model, 'alpha2_gain/1', 'Storage/2');
    add_line(model, 'Controller/1', 'beta1_gain/1');
    add_line(model, 'beta1_gain/1', 'Thermal/1');
    add_line(model, 'Controller/2', 'beta2_gain/1');
    add_line(model, 'beta2_gain/1', 'Thermal/2');
    add_line(model, 'Controller/1', 'Charging/1');
    add_line(model, 'Controller/2', 'Discharging/1');
    % HPT罐温→放电入口: T从Storage馈入Discharging替代固定296K
    add_line(model, 'Storage/3', 'Discharging/2');

    % === 功率门控: W * (cmd > 0) 使非激活时段功率为0 ===
    add_block('simulink/Math Operations/Product', [model '/gate_Wc']);
    set_param([model '/gate_Wc'], 'Inputs', '2', 'Position', [60, 400, 110, 440]);
    add_block('simulink/Math Operations/Product', [model '/gate_Wt']);
    set_param([model '/gate_Wt'], 'Inputs', '2', 'Position', [60, 470, 110, 510]);

    % Controller cmd → gate (先除10归一化, 乘10还原功率)
    add_block('simulink/Math Operations/Gain', [model '/norm_c']);
    set_param([model '/norm_c'], 'Gain', '0.1', 'Position', [60, 360, 90, 380]);
    add_block('simulink/Math Operations/Gain', [model '/norm_d']);
    set_param([model '/norm_d'], 'Gain', '0.1', 'Position', [60, 430, 90, 450]);

    try add_line(model, 'Controller/1', 'norm_c/1'); catch; end
    try add_line(model, 'norm_c/1', 'gate_Wc/1'); catch; end
    try add_line(model, 'Charging/2', 'gate_Wc/2'); catch; end

    add_line(model, 'Controller/2', 'norm_d/1');
    try add_line(model, 'norm_d/1', 'gate_Wt/1'); catch; end
    try add_line(model, 'Discharging/1', 'gate_Wt/2'); catch; end

    % === 反馈: Storage→Controller(P), Q_MWh→Controller(Q) ===
    add_line(model, 'Storage/1', 'Controller/1');
    try delete_line(model, 'Q_MWh_gain/1', 'Controller/2'); catch; end
    add_line(model, 'Q_MWh_gain/1', 'Controller/2');

    % 子系统输出 → Results (门控后的信号)
    try add_line(model, 'gate_Wc/1', 'Results/1'); catch; end
    try add_line(model, 'gate_Wt/1', 'Results/2'); catch; end
    try add_line(model, 'Storage/1', 'Results/3'); catch; end
    % (Q_HTV 现在通过 Q_MWh_gain 转换后进入 Results, 不再直连)

    % 根级 Outport (门控后)
    for j = 1:4
        oname = sprintf('Out%d', j);
        add_block('simulink/Ports & Subsystems/Out1', [model '/' oname]);
    end
    try add_line(model, 'gate_Wc/1', 'Out1/1'); catch; end
    try add_line(model, 'gate_Wt/1', 'Out2/1'); catch; end
    try add_line(model, 'Storage/1', 'Out3/1'); catch; end
    % Q_MWh_gain → Results & Out4
    add_line(model, 'Thermal/1', 'Q_MWh_gain/1');
    try delete_line(model, 'Q_MWh_gain/1', 'Results/4'); catch; end
    add_line(model, 'Q_MWh_gain/1', 'Results/4');
    try delete_line(model, 'Q_MWh_gain/1', 'Out4/1'); catch; end
    add_line(model, 'Q_MWh_gain/1', 'Out4/1');
    set_param(model, 'SaveOutput', 'on', 'OutputSaveName', 'yout');

    save_system(model, '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/data/CCES_CHP_System');
    fprintf('CCES_CHP_System 构建完成（2-D LUT版本）。\n');
    open_system(model);
end

% ==================== helper: 2-D LUT block ====================
function blk = add_lut2d(varargin)
    % add_lut2d(parent, name, table, bp1, bp2, pos)
    p = varargin{1}; n = varargin{2}; t = varargin{3}; b1 = varargin{4}; b2 = varargin{5}; pos = varargin{6};
    blk = add_block('simulink/Lookup Tables/2-D Lookup Table', [p '/' n]);
    set_param(blk, 'Position', pos);
    set_param(blk, 'Table', t);
    set_param(blk, 'BreakpointsForDimension1', b1);
    set_param(blk, 'BreakpointsForDimension2', b2);
    % 使用默认线性插值
end

% ==================== helper: Fcn block ====================
function blk = add_fcn(parent, name, expr, pos)
    blk = add_block('simulink/User-Defined Functions/Fcn', [parent '/' name]);
    set_param(blk, 'Position', pos, 'Expr', expr);
end

% ==================== helper: source constant ====================
function blk = add_const(parent, name, val, pos)
    blk = add_block('simulink/Sources/Constant', [parent '/' name]);
    set_param(blk, 'Position', pos, 'Value', val);
    set_param(blk, 'OutDataTypeStr', 'Inherit: Inherit from ''Constant value''');
end

% ==================== 充电系统 ====================
function build_charging(parent)
    Simulink.SubSystem.deleteContents(parent);
    b = @(n) [parent '/' n];

    add_block('simulink/Ports & Subsystems/In1', b('cmd'));
    set_param(b('cmd'), 'Position', [30, 90, 60, 110], 'Port', '1');
    add_const(parent, 'T_in', '298',       [30, 160, 80, 180]);
    add_const(parent, 'P_in', '0.102e6',   [30, 210, 80, 230]);
    add_const(parent, 'm_dot', '26.9',     [30, 260, 80, 280]);

    % ----- C1: compressor -----
    add_block('simulink/Ports & Subsystems/Subsystem', b('C1'));
    set_param(b('C1'), 'Position', [180, 60, 330, 300]);
    build_comp(b('C1'), 0.90e6, 0.85);

    % ----- IC1: intercooler -----
    add_block('simulink/Ports & Subsystems/Subsystem', b('IC1'));
    set_param(b('IC1'), 'Position', [420, 60, 540, 200]);
    build_hex(b('IC1'), 308);

    % ----- C2: compressor -----
    add_block('simulink/Ports & Subsystems/Subsystem', b('C2'));
    set_param(b('C2'), 'Position', [630, 60, 780, 300]);
    build_comp(b('C2'), 6.90e6, 0.85);

    % ----- IC2: intercooler -----
    add_block('simulink/Ports & Subsystems/Subsystem', b('IC2'));
    set_param(b('IC2'), 'Position', [870, 60, 990, 200]);
    build_hex(b('IC2'), 309);

    % ----- LHE -----
    add_block('simulink/Ports & Subsystems/Subsystem', b('LHE'));
    set_param(b('LHE'), 'Position', [1080, 60, 1200, 200]);
    build_hex(b('LHE'), 298);

    % 汇总
    add_block('simulink/Math Operations/Add', b('Sum_W'));
    set_param(b('Sum_W'), 'Position', [1300, 100, 1340, 150], 'Inputs', '++', 'IconShape', 'round');
    add_block('simulink/Math Operations/Add', b('Sum_Q'));
    set_param(b('Sum_Q'), 'Position', [1300, 200, 1340, 250], 'Inputs', '++', 'IconShape', 'round');

    add_block('simulink/Ports & Subsystems/Out1', b('P_out'));
    set_param(b('P_out'), 'Position', [1440, 120, 1470, 140], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('W_out'));
    set_param(b('W_out'), 'Position', [1440, 180, 1470, 200], 'Port', '2');
    add_block('simulink/Ports & Subsystems/Out1', b('Q_out'));
    set_param(b('Q_out'), 'Position', [1440, 240, 1470, 260], 'Port', '3');

    % 连线
    add_line(parent, 'T_in/1', 'C1/1'); add_line(parent, 'P_in/1', 'C1/2');
    add_line(parent, 'm_dot/1', 'C1/3');
    add_line(parent, 'C1/1', 'IC1/1'); add_line(parent, 'C1/2', 'IC1/2'); add_line(parent, 'C1/4', 'IC1/3');
    add_line(parent, 'IC1/1', 'C2/1'); add_line(parent, 'IC1/2', 'C2/2'); add_line(parent, 'IC1/4', 'C2/3');
    add_line(parent, 'C2/1', 'IC2/1'); add_line(parent, 'C2/2', 'IC2/2'); add_line(parent, 'C2/4', 'IC2/3');
    add_line(parent, 'IC2/1', 'LHE/1'); add_line(parent, 'IC2/2', 'LHE/2'); add_line(parent, 'IC2/4', 'LHE/3');
    add_line(parent, 'C1/3', 'Sum_W/1'); add_line(parent, 'C2/3', 'Sum_W/2');
    add_line(parent, 'IC1/3', 'Sum_Q/1'); add_line(parent, 'IC2/3', 'Sum_Q/2');
    add_line(parent, 'LHE/2', 'P_out/1');
    add_line(parent, 'Sum_W/1', 'W_out/1'); add_line(parent, 'Sum_Q/1', 'Q_out/1');
end

% ==================== 压缩器 (2-D LUT 版本) ====================
function build_comp(parent, P_out, eta)
    Simulink.SubSystem.deleteContents(parent);
    b = @(n) [parent '/' n];

    add_block('simulink/Ports & Subsystems/In1', b('T_in'));
    set_param(b('T_in'), 'Position', [30, 60, 60, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('P_in'));
    set_param(b('P_in'), 'Position', [30, 120, 60, 140], 'Port', '2');
    add_block('simulink/Ports & Subsystems/In1', b('m_in'));
    set_param(b('m_in'), 'Position', [30, 180, 60, 200], 'Port', '3');

    % h_in = H(T_in, P_in)
    add_lut2d(parent, 'h_in', 'H_table', 'T_vec', 'P_vec', [110, 50, 200, 90]);
    % s_in = S(T_in, P_in)
    add_lut2d(parent, 's_in', 'S_table', 'T_vec', 'P_vec', [110, 110, 200, 150]);
    % h_is = H(P_out, s_in)  — Breakpoint1=S_PS_vec, Breakpoint2=P_PS_vec
    add_lut2d(parent, 'h_is', 'H_PS_table', 'S_PS_vec', 'P_PS_vec', [290, 65, 390, 120]);
    add_const(parent, 'P_target', num2str(P_out), [290, 160, 330, 180]);

    % h_out = h_in + (h_is - h_in) / eta  [2-input → Mux → Fcn]
    add_block('simulink/Signal Routing/Mux', b('mx1'));
    set_param(b('mx1'), 'Inputs', '2', 'Position', [450, 55, 465, 105]);
    add_fcn(parent, 'h_out', sprintf('u(1)+(u(2)-u(1))/%.4f', eta), [500, 50, 590, 100]);

    % T_out = T(P_out, h_out)
    add_lut2d(parent, 'T_out_lut', 'T_PH_table', 'H_PH_vec', 'P_PH_vec', [660, 50, 760, 110]);

    % W = m*(h_in - h_out)/1e6  [3-input → Mux → Fcn]
    add_block('simulink/Signal Routing/Mux', b('mx2'));
    set_param(b('mx2'), 'Inputs', '3', 'Position', [660, 140, 675, 200]);
    add_fcn(parent, 'W_calc', 'abs(u(1)*(u(2)-u(3)))/1e6', [710, 140, 790, 190]);

    add_block('simulink/Ports & Subsystems/Out1', b('T_out'));
    set_param(b('T_out'), 'Position', [850, 50, 880, 70], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('P_out'));
    set_param(b('P_out'), 'Position', [850, 110, 880, 130], 'Port', '2');
    add_block('simulink/Ports & Subsystems/Out1', b('W_out'));
    set_param(b('W_out'), 'Position', [850, 170, 880, 190], 'Port', '3');
    add_block('simulink/Ports & Subsystems/Out1', b('m_out'));
    set_param(b('m_out'), 'Position', [850, 230, 880, 250], 'Port', '4');

    % 连线
    add_line(parent, 'T_in/1', 'h_in/1'); add_line(parent, 'P_in/1', 'h_in/2');
    add_line(parent, 'T_in/1', 's_in/1'); add_line(parent, 'P_in/1', 's_in/2');
    add_line(parent, 's_in/1', 'h_is/1'); add_line(parent, 'P_target/1', 'h_is/2');
    add_line(parent, 'h_in/1', 'mx1/1'); add_line(parent, 'h_is/1', 'mx1/2');
    add_line(parent, 'mx1/1', 'h_out/1');
    add_line(parent, 'h_out/1', 'T_out_lut/1'); add_line(parent, 'P_target/1', 'T_out_lut/2');
    add_line(parent, 'm_in/1', 'mx2/1');
    add_line(parent, 'h_in/1', 'mx2/2'); add_line(parent, 'h_out/1', 'mx2/3');
    add_line(parent, 'mx2/1', 'W_calc/1');
    add_line(parent, 'T_out_lut/1', 'T_out/1'); add_line(parent, 'P_target/1', 'P_out/1');
    add_line(parent, 'W_calc/1', 'W_out/1'); add_line(parent, 'm_in/1', 'm_out/1');
end

% ==================== 换热器 ====================
function build_hex(parent, T_out_target)
    Simulink.SubSystem.deleteContents(parent);
    b = @(n) [parent '/' n];

    add_block('simulink/Ports & Subsystems/In1', b('T_in'));
    set_param(b('T_in'), 'Position', [30, 60, 60, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('P_in'));
    set_param(b('P_in'), 'Position', [30, 130, 60, 150], 'Port', '2');
    add_block('simulink/Ports & Subsystems/In1', b('m_in'));
    set_param(b('m_in'), 'Position', [30, 200, 60, 220], 'Port', '3');

    add_lut2d(parent, 'h_in_lut', 'H_table', 'T_vec', 'P_vec', [120, 50, 210, 90]);
    add_lut2d(parent, 'h_out_lut', 'H_table', 'T_vec', 'P_vec', [120, 120, 210, 160]);
    add_const(parent, 'T_target', num2str(T_out_target), [120, 190, 160, 210]);

    % Q = abs(m*(h_in - h_out))/1e6
    add_block('simulink/Signal Routing/Mux', b('mx'));
    set_param(b('mx'), 'Inputs', '3', 'Position', [300, 80, 315, 160]);
    add_fcn(parent, 'Q_calc', 'abs(u(1)*(u(2)-u(3)))/1e6', [350, 80, 440, 150]);

    add_block('simulink/Ports & Subsystems/Out1', b('T_out'));
    set_param(b('T_out'), 'Position', [560, 50, 590, 70], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('P_out'));
    set_param(b('P_out'), 'Position', [560, 110, 590, 130], 'Port', '2');
    add_block('simulink/Ports & Subsystems/Out1', b('Q_out'));
    set_param(b('Q_out'), 'Position', [560, 170, 590, 190], 'Port', '3');
    add_block('simulink/Ports & Subsystems/Out1', b('m_out'));
    set_param(b('m_out'), 'Position', [560, 230, 590, 250], 'Port', '4');

    add_line(parent, 'T_in/1', 'h_in_lut/1'); add_line(parent, 'P_in/1', 'h_in_lut/2');
    add_line(parent, 'T_target/1', 'h_out_lut/1'); add_line(parent, 'P_in/1', 'h_out_lut/2');
    add_line(parent, 'm_in/1', 'mx/1');
    add_line(parent, 'h_in_lut/1', 'mx/2'); add_line(parent, 'h_out_lut/1', 'mx/3');
    add_line(parent, 'mx/1', 'Q_calc/1');
    add_line(parent, 'T_target/1', 'T_out/1'); add_line(parent, 'P_in/1', 'P_out/1');
    add_line(parent, 'Q_calc/1', 'Q_out/1'); add_line(parent, 'm_in/1', 'm_out/1');
end

% ==================== 放电系统 ====================
function build_discharging(parent)
    Simulink.SubSystem.deleteContents(parent);
    b = @(n) [parent '/' n];

    add_block('simulink/Ports & Subsystems/In1', b('cmd'));
    set_param(b('cmd'), 'Position', [30, 90, 60, 110], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('T_HPT_in'));
    set_param(b('T_HPT_in'), 'Position', [30, 160, 60, 180], 'Port', '2');
    add_const(parent, 'P_in', '6.65e6',    [30, 210, 80, 230]);
    add_const(parent, 'm_dot', '26.9',     [30, 260, 80, 280]);

    add_block('simulink/Ports & Subsystems/Subsystem', b('T1'));
    set_param(b('T1'), 'Position', [240, 60, 390, 300]);
    build_turb(b('T1'), 0.70e6, 0.88);

    add_block('simulink/Ports & Subsystems/Subsystem', b('Heater'));
    set_param(b('Heater'), 'Position', [480, 60, 600, 200]);
    build_hex(b('Heater'), 483);

    add_block('simulink/Ports & Subsystems/Subsystem', b('T2'));
    set_param(b('T2'), 'Position', [690, 60, 840, 300]);
    build_turb(b('T2'), 0.12e6, 0.88);

    add_block('simulink/Ports & Subsystems/Subsystem', b('Cooler'));
    set_param(b('Cooler'), 'Position', [930, 60, 1050, 200]);
    build_hex(b('Cooler'), 298);

    add_block('simulink/Math Operations/Add', b('Sum_W'));
    set_param(b('Sum_W'), 'Position', [1140, 100, 1180, 150], 'Inputs', '++', 'IconShape', 'round');

    add_block('simulink/Ports & Subsystems/Out1', b('W_out'));
    set_param(b('W_out'), 'Position', [1280, 120, 1310, 140], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('P_out'));
    set_param(b('P_out'), 'Position', [1280, 200, 1310, 220], 'Port', '2');

    add_line(parent, 'T_HPT_in/1', 'T1/1'); add_line(parent, 'P_in/1', 'T1/2'); add_line(parent, 'm_dot/1', 'T1/3');
    add_line(parent, 'T1/1', 'Heater/1'); add_line(parent, 'T1/2', 'Heater/2'); add_line(parent, 'T1/4', 'Heater/3');
    add_line(parent, 'Heater/1', 'T2/1'); add_line(parent, 'Heater/2', 'T2/2'); add_line(parent, 'Heater/4', 'T2/3');
    add_line(parent, 'T2/1', 'Cooler/1'); add_line(parent, 'T2/2', 'Cooler/2'); add_line(parent, 'T2/4', 'Cooler/3');
    add_line(parent, 'T1/3', 'Sum_W/1'); add_line(parent, 'T2/3', 'Sum_W/2');
    add_line(parent, 'Sum_W/1', 'W_out/1');
    add_line(parent, 'Cooler/2', 'P_out/1');
end

% ==================== 透平 ====================
function build_turb(parent, P_out, eta)
    Simulink.SubSystem.deleteContents(parent);
    b = @(n) [parent '/' n];

    add_block('simulink/Ports & Subsystems/In1', b('T_in'));
    set_param(b('T_in'), 'Position', [30, 60, 60, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('P_in'));
    set_param(b('P_in'), 'Position', [30, 120, 60, 140], 'Port', '2');
    add_block('simulink/Ports & Subsystems/In1', b('m_in'));
    set_param(b('m_in'), 'Position', [30, 180, 60, 200], 'Port', '3');

    add_lut2d(parent, 'h_in', 'H_table', 'T_vec', 'P_vec', [110, 50, 200, 90]);
    add_lut2d(parent, 's_in', 'S_table', 'T_vec', 'P_vec', [110, 110, 200, 150]);
    add_lut2d(parent, 'h_is', 'H_PS_table', 'S_PS_vec', 'P_PS_vec', [290, 65, 390, 120]);
    add_const(parent, 'P_target', num2str(P_out), [290, 160, 330, 180]);

    add_block('simulink/Signal Routing/Mux', b('mx1'));
    set_param(b('mx1'), 'Inputs', '2', 'Position', [450, 55, 465, 105]);
    add_fcn(parent, 'h_out', sprintf('u(1)-%.4f*(u(1)-u(2))', eta), [500, 50, 590, 100]);

    add_lut2d(parent, 'T_out_lut', 'T_PH_table', 'H_PH_vec', 'P_PH_vec', [660, 50, 760, 110]);

    add_block('simulink/Signal Routing/Mux', b('mx2'));
    set_param(b('mx2'), 'Inputs', '3', 'Position', [660, 140, 675, 200]);
    add_fcn(parent, 'W_calc', 'abs(u(1)*(u(2)-u(3)))/1e6', [710, 140, 790, 190]);

    add_block('simulink/Ports & Subsystems/Out1', b('T_out'));
    set_param(b('T_out'), 'Position', [850, 50, 880, 70], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('P_out'));
    set_param(b('P_out'), 'Position', [850, 110, 880, 130], 'Port', '2');
    add_block('simulink/Ports & Subsystems/Out1', b('W_out'));
    set_param(b('W_out'), 'Position', [850, 170, 880, 190], 'Port', '3');
    add_block('simulink/Ports & Subsystems/Out1', b('m_out'));
    set_param(b('m_out'), 'Position', [850, 230, 880, 250], 'Port', '4');

    add_line(parent, 'T_in/1', 'h_in/1'); add_line(parent, 'P_in/1', 'h_in/2');
    add_line(parent, 'T_in/1', 's_in/1'); add_line(parent, 'P_in/1', 's_in/2');
    add_line(parent, 's_in/1', 'h_is/1'); add_line(parent, 'P_target/1', 'h_is/2');
    add_line(parent, 'h_in/1', 'mx1/1'); add_line(parent, 'h_is/1', 'mx1/2');
    add_line(parent, 'mx1/1', 'h_out/1');
    add_line(parent, 'h_out/1', 'T_out_lut/1'); add_line(parent, 'P_target/1', 'T_out_lut/2');
    add_line(parent, 'm_in/1', 'mx2/1');
    add_line(parent, 'h_in/1', 'mx2/2'); add_line(parent, 'h_out/1', 'mx2/3');
    add_line(parent, 'mx2/1', 'W_calc/1');
    add_line(parent, 'T_out_lut/1', 'T_out/1'); add_line(parent, 'P_target/1', 'P_out/1');
    add_line(parent, 'W_calc/1', 'W_out/1'); add_line(parent, 'm_in/1', 'm_out/1');
end

% ==================== 储罐 (T=298K恒定, P=mRT/V) ====================
function build_storage(parent)
    Simulink.SubSystem.deleteContents(parent);
    b = @(n) [parent '/' n];

    add_block('simulink/Ports & Subsystems/In1', b('m_dot_in'));
    set_param(b('m_dot_in'), 'Position', [30, 60, 60, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('m_dot_out'));
    set_param(b('m_dot_out'), 'Position', [30, 150, 60, 170], 'Port', '2');

    add_block('simulink/Math Operations/Sum', b('net_m'));
    set_param(b('net_m'), 'Position', [130, 80, 160, 120], 'Inputs', '+-', 'IconShape', 'round');
    add_block('simulink/Continuous/Integrator', b('mass'));
    set_param(b('mass'), 'Position', [230, 80, 280, 120], ...
        'InitialCondition', '383000');

    % P = m*R*T/V, T=298K constant
    add_fcn(parent, 'pressure', 'u*188.9*298/6228/1e6', [380, 80, 460, 120]);

    add_block('simulink/Ports & Subsystems/Out1', b('P_MPa'));
    set_param(b('P_MPa'), 'Position', [560, 60, 590, 80], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('m_kg'));
    set_param(b('m_kg'), 'Position', [560, 130, 590, 150], 'Port', '2');
    add_block('simulink/Ports & Subsystems/Out1', b('T_out'));
    set_param(b('T_out'), 'Position', [560, 200, 590, 220], 'Port', '3');

    % T constant = 298K
    add_block('simulink/Sources/Constant', b('T_const'));
    set_param(b('T_const'), 'Value', '298', 'Position', [380, 180, 420, 200]);

    add_line(parent, 'm_dot_in/1', 'net_m/1'); add_line(parent, 'm_dot_out/1', 'net_m/2');
    add_line(parent, 'net_m/1', 'mass/1');
    add_line(parent, 'mass/1', 'pressure/1');
    add_line(parent, 'pressure/1', 'P_MPa/1');
    add_line(parent, 'mass/1', 'm_kg/1');
    add_line(parent, 'T_const/1', 'T_out/1');
end

% ==================== 蓄热 ====================
function build_thermal(parent)
    Simulink.SubSystem.deleteContents(parent);
    b = @(n) [parent '/' n];

    add_block('simulink/Ports & Subsystems/In1', b('Q_in'));
    set_param(b('Q_in'), 'Position', [30, 80, 60, 100], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('Q_out'));
    set_param(b('Q_out'), 'Position', [30, 180, 60, 200], 'Port', '2');

    add_block('simulink/Math Operations/Sum', b('net_Q'));
    set_param(b('net_Q'), 'Position', [150, 100, 180, 140], 'Inputs', '+-', 'IconShape', 'round');

    add_block('simulink/Continuous/Integrator', b('Q_store'));
    set_param(b('Q_store'), 'Position', [280, 100, 330, 140], ...
        'InitialCondition', '270000');  % 75 MWh_th = 270000 MJ (50% SOC)

    add_block('simulink/Ports & Subsystems/Out1', b('Q_MJ'));
    set_param(b('Q_MJ'), 'Position', [460, 80, 490, 100], 'Port', '1');

    add_line(parent, 'Q_in/1', 'net_Q/1'); add_line(parent, 'Q_out/1', 'net_Q/2');
    add_line(parent, 'net_Q/1', 'Q_store/1');
    add_line(parent, 'Q_store/1', 'Q_MJ/1');
end

% ==================== 控制器 (时间+P+Q三重约束) ====================
function build_control(parent)
    Simulink.SubSystem.deleteContents(parent);
    b = @(n) [parent '/' n];

    % 反馈输入
    add_block('simulink/Ports & Subsystems/In1', b('P_fb'));
    set_param(b('P_fb'), 'Position', [30, 30, 60, 50], 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('Q_fb'));
    set_param(b('Q_fb'), 'Position', [30, 80, 60, 100], 'Port', '2');

    % Charge Pulse: 0-7.5h
    add_block('simulink/Sources/Pulse Generator', b('chg_pulse'));
    set_param(b('chg_pulse'), 'Position', [100, 40, 170, 80], ...
        'Amplitude', '10', 'Period', '86400', ...
        'PulseWidth', '31.25', 'PhaseDelay', '0');

    % Discharge Pulse: 12-15h (3h, 可持续)
    add_block('simulink/Sources/Pulse Generator', b('dis_pulse'));
    set_param(b('dis_pulse'), 'Position', [100, 200, 170, 240], ...
        'Amplitude', '10', 'Period', '86400', ...
        'PulseWidth', '12.50', 'PhaseDelay', '43200');

    % P constraints
    add_block('simulink/Sources/Constant', b('P_max'));
    set_param(b('P_max'), 'Value', '6.70', 'Position', [60, 115, 80, 135]);
    add_block('simulink/Logic and Bit Operations/Relational Operator', b('chg_P_ok'));
    set_param(b('chg_P_ok'), 'Position', [100, 105, 130, 125], 'Operator', '<');
    add_block('simulink/Sources/Constant', b('P_min'));
    set_param(b('P_min'), 'Value', '0.22', 'Position', [60, 145, 80, 165]);
    add_block('simulink/Logic and Bit Operations/Relational Operator', b('dis_P_ok'));
    set_param(b('dis_P_ok'), 'Position', [100, 145, 130, 165], 'Operator', '>');

    % Q constraints: charge OK if Q < 150, discharge OK if Q > 0
    add_block('simulink/Sources/Constant', b('Q_max'));
    set_param(b('Q_max'), 'Value', '150', 'Position', [60, 175, 80, 195]);
    add_block('simulink/Logic and Bit Operations/Relational Operator', b('chg_Q_ok'));
    set_param(b('chg_Q_ok'), 'Position', [100, 175, 130, 195], 'Operator', '<');
    add_block('simulink/Sources/Constant', b('Q_min'));
    set_param(b('Q_min'), 'Value', '0', 'Position', [60, 205, 80, 225]);
    add_block('simulink/Logic and Bit Operations/Relational Operator', b('dis_Q_ok'));
    set_param(b('dis_Q_ok'), 'Position', [100, 205, 130, 225], 'Operator', '>');

    % 3-input Product gates: pulse * P_ok * Q_ok
    add_block('simulink/Math Operations/Product', b('chg_gate'));
    set_param(b('chg_gate'), 'Inputs', '3', 'Position', [190, 40, 230, 90]);
    add_block('simulink/Math Operations/Product', b('dis_gate'));
    set_param(b('dis_gate'), 'Inputs', '3', 'Position', [190, 190, 230, 240]);

    add_block('simulink/Ports & Subsystems/Out1', b('charge_cmd'));
    set_param(b('charge_cmd'), 'Position', [300, 40, 330, 60], 'Port', '1');
    add_block('simulink/Ports & Subsystems/Out1', b('discharge_cmd'));
    set_param(b('discharge_cmd'), 'Position', [300, 190, 330, 210], 'Port', '2');

    % 连线
    add_line(parent, 'P_fb/1', 'chg_P_ok/1');
    add_line(parent, 'P_max/1', 'chg_P_ok/2');
    add_line(parent, 'P_fb/1', 'dis_P_ok/1');
    add_line(parent, 'P_min/1', 'dis_P_ok/2');
    add_line(parent, 'Q_fb/1', 'chg_Q_ok/1');
    add_line(parent, 'Q_max/1', 'chg_Q_ok/2');
    add_line(parent, 'Q_fb/1', 'dis_Q_ok/1');
    add_line(parent, 'Q_min/1', 'dis_Q_ok/2');
    add_line(parent, 'chg_pulse/1', 'chg_gate/1');
    add_line(parent, 'chg_P_ok/1', 'chg_gate/2');
    add_line(parent, 'chg_Q_ok/1', 'chg_gate/3');
    add_line(parent, 'chg_gate/1', 'charge_cmd/1');
    add_line(parent, 'dis_pulse/1', 'dis_gate/1');
    add_line(parent, 'dis_P_ok/1', 'dis_gate/2');
    add_line(parent, 'dis_Q_ok/1', 'dis_gate/3');
    add_line(parent, 'dis_gate/1', 'discharge_cmd/1');
end

% ==================== 结果显示 ====================
function build_results(parent)
    Simulink.SubSystem.deleteContents(parent);
    b = @(n) [parent '/' n];

    add_block('simulink/Ports & Subsystems/In1', b('W_comp')); set_param(b('W_comp'), 'Port', '1');
    add_block('simulink/Ports & Subsystems/In1', b('W_turb'));  set_param(b('W_turb'),  'Port', '2');
    add_block('simulink/Ports & Subsystems/In1', b('P_HPT'));   set_param(b('P_HPT'),   'Port', '3');
    add_block('simulink/Ports & Subsystems/In1', b('Q_HTV'));   set_param(b('Q_HTV'),   'Port', '4');

    % Power Scope: W_comp + W_turb
    add_block('simulink/Sinks/Scope', b('PowerScope'));
    set_param(b('PowerScope'), 'Position', [200, 40, 500, 240], 'NumInputPorts', '2');

    % Storage Scope: P_HPT (MPa) + Q_HTV (MWh) — 量纲对齐
    add_block('simulink/Math Operations/Gain', b('Q_to_MWh'));
    set_param(b('Q_to_MWh'), 'Gain', '1/3600', 'Position', [80, 320, 120, 350]);
    add_block('simulink/Sinks/Scope', b('StorageScope'));
    set_param(b('StorageScope'), 'Position', [200, 280, 500, 480], 'NumInputPorts', '2');

    add_line(parent, 'W_comp/1', 'PowerScope/1'); add_line(parent, 'W_turb/1', 'PowerScope/2');
    add_line(parent, 'Q_HTV/1', 'Q_to_MWh/1');
    add_line(parent, 'P_HPT/1', 'StorageScope/1');
    add_line(parent, 'Q_to_MWh/1', 'StorageScope/2');
end
