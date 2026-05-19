% =========================================================================
% build_CCES_model.m — 程序化构建 CCES-CHP Simulink 动态仿真模型
% 使用预计算 REFPROP 查找表进行快速物性插值
% =========================================================================

function build_CCES_model()
    %% 0. 前置检查
    if ~bdIsLoaded('CCES_CHP_System')
        % 创建新模型
        new_system('CCES_CHP_System', 'Model');
    else
        warning('模型 CCES_CHP_System 已加载，将重建...');
        close_system('CCES_CHP_System', 0);
        new_system('CCES_CHP_System', 'Model');
    end

    % 加载查找表
    if ~exist('../data/REFPROP_lookup.mat', 'file')
        error('请先运行 generate_lookup_tables.m 生成物性查找表');
    end
    load('../data/REFPROP_lookup.mat', 'T_vec', 'P_vec', 'H_table', 'S_table');

    %% 1. 模型全局设置
    set_param('CCES_CHP_System', ...
        'Solver', 'ode45', ...
        'MaxStep', '60', ...
        'StopTime', '86400', ...
        'StartTime', '0', ...
        'RelTol', '1e-4');

    %% 2. 加载系统参数到 Model Workspace
    CCES_parameters;
    mw = get_param('CCES_CHP_System', 'ModelWorkspace');
    mw.assignin('params', params);
    mw.assignin('T_vec', T_vec);
    mw.assignin('P_vec', P_vec);
    mw.assignin('H_table', H_table);
    mw.assignin('S_table', S_table);

    %% 3. 创建顶层子系统
    % --- 3a. 压缩机组 (Compressors + Intercoolers + LHE) ---
    charge_sys = add_block('simulink/Ports & Subsystems/Subsystem', ...
        'CCES_CHP_System/Charging_System');
    set_param(charge_sys, 'Position', [150, 50, 450, 400]);
    build_charging_subsystem(charge_sys);

    % --- 3b. 膨胀机组 (Throttle + Heaters + Turbines + AE-HE + Cooler) ---
    discharge_sys = add_block('simulink/Ports & Subsystems/Subsystem', ...
        'CCES_CHP_System/Discharging_System');
    set_param(discharge_sys, 'Position', [150, 450, 450, 800]);
    build_discharging_subsystem(discharge_sys);

    % --- 3c. 储罐动态模型 ---
    storage_sys = add_block('simulink/Ports & Subsystems/Subsystem', ...
        'CCES_CHP_System/Storage_Tanks');
    set_param(storage_sys, 'Position', [550, 50, 850, 400]);
    build_storage_subsystem(storage_sys);

    % --- 3d. 蓄热系统动态模型 ---
    thermal_sys = add_block('simulink/Ports & Subsystems/Subsystem', ...
        'CCES_CHP_System/Thermal_Oil_System');
    set_param(thermal_sys, 'Position', [550, 450, 850, 800]);
    build_thermal_subsystem(thermal_sys);

    % --- 3e. 控制器 ---
    ctrl_sys = add_block('simulink/Ports & Subsystems/Subsystem', ...
        'CCES_CHP_System/Controller');
    set_param(ctrl_sys, 'Position', [50, 250, 150, 550]);
    build_controller_subsystem(ctrl_sys);

    % --- 3f. 结果汇总与显示 ---
    results_sys = add_block('simulink/Ports & Subsystems/Subsystem', ...
        'CCES_CHP_System/Results_Display');
    set_param(results_sys, 'Position', [950, 250, 1200, 550]);
    build_results_subsystem(results_sys);

    %% 4. 顶层信号连线
    % 控制器 -> 充放电系统
    add_line('CCES_CHP_System', 'Controller/1', 'Charging_System/1', 'autorouting', 'smart');
    add_line('CCES_CHP_System', 'Controller/2', 'Discharging_System/1', 'autorouting', 'smart');
    add_line('CCES_CHP_System', 'Controller/3', 'Storage_Tanks/3', 'autorouting', 'smart');
    add_line('CCES_CHP_System', 'Controller/4', 'Thermal_Oil_System/4', 'autorouting', 'smart');

    % 储罐压力反馈到控制器
    % (需要手动连线或使用 GoTo/From 信号)
    add_line('CCES_CHP_System', 'Storage_Tanks/1', 'Controller/5', 'autorouting', 'smart');

    %% 5. 保存模型
    save_system('CCES_CHP_System', ...
        '/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/data/CCES_CHP_System');
    fprintf('CCES_CHP_System Simulink 模型构建完成。\n');
    open_system('CCES_CHP_System');
end

%% ======================= 子系统构建函数 =======================

function build_charging_subsystem(parent)
    % 充电系统: C1 → IC1 → C2 → IC2 → LHE
    % 输入: mode_ctrl, 输出: m_dot_out, P_out, T_out, W_comp_total, Q_IC_total

    % 入口端口
    in1 = add_block('simulink/Ports & Subsystems/In1', [parent '/mode_in']);
    set_param(in1, 'Position', [50, 150, 80, 170], 'Port', '1');

    % 环境入口 T_amb, P_amb
    T_amb = add_block('simulink/Sources/Constant', [parent '/T_amb']);
    set_param(T_amb, 'Position', [50, 250, 100, 270], 'Value', '298');

    P_amb = add_block('simulink/Sources/Constant', [parent '/P_amb']);
    set_param(P_amb, 'Position', [50, 320, 100, 340], 'Value', '0.102');

    m_charge = add_block('simulink/Sources/Constant', [parent '/m_charge']);
    set_param(m_charge, 'Position', [50, 390, 100, 410], 'Value', '26.9');

    % ===== Compressor C1 =====
    c1 = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/C1']);
    set_param(c1, 'Position', [200, 100, 350, 280]);
    build_compressor_model(c1, 0.90, 0.85);  % P_out_target, eta

    % ===== Intercooler IC1 =====
    ic1 = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/IC1']);
    set_param(ic1, 'Position', [430, 100, 560, 250]);
    build_cooler_model(ic1, 308);  % T_out_target

    % ===== Compressor C2 =====
    c2 = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/C2']);
    set_param(c2, 'Position', [640, 100, 790, 280]);
    build_compressor_model(c2, 6.90, 0.85);

    % ===== Intercooler IC2 =====
    ic2 = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/IC2']);
    set_param(ic2, 'Position', [870, 100, 1000, 250]);
    build_cooler_model(ic2, 309);

    % ===== LHE =====
    lhe = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/LHE']);
    set_param(lhe, 'Position', [1080, 100, 1210, 250]);
    build_cooler_model(lhe, 298);

    % 功率和热量汇总
    add_w_sum = add_block('simulink/Math Operations/Add', [parent '/Sum_W_comp']);
    set_param(add_w_sum, 'Position', [1300, 150, 1330, 190], 'Inputs', '++', 'IconShape', 'round');

    add_q_sum = add_block('simulink/Math Operations/Add', [parent '/Sum_Q_IC']);
    set_param(add_q_sum, 'Position', [1300, 220, 1330, 260], 'Inputs', '++', 'IconShape', 'round');

    % 出口端口
    out_m = add_block('simulink/Ports & Subsystems/Out1', [parent '/m_out']);
    set_param(out_m, 'Position', [1450, 150, 1480, 170], 'Port', '1');
    out_P = add_block('simulink/Ports & Subsystems/Out1', [parent '/P_out']);
    set_param(out_P, 'Position', [1450, 200, 1480, 220], 'Port', '2');
    out_T = add_block('simulink/Ports & Subsystems/Out1', [parent '/T_out']);
    set_param(out_T, 'Position', [1450, 250, 1480, 270], 'Port', '3');
    out_W = add_block('simulink/Ports & Subsystems/Out1', [parent '/W_comp']);
    set_param(out_W, 'Position', [1450, 300, 1480, 320], 'Port', '4');
    out_Q = add_block('simulink/Ports & Subsystems/Out1', [parent '/Q_IC']);
    set_param(out_Q, 'Position', [1450, 350, 1480, 370], 'Port', '5');

    % 连线 (简化表示，实际需要详细连线)
    add_line(parent, 'T_amb/1', 'C1/2', 'autorouting', 'smart');
    add_line(parent, 'P_amb/1', 'C1/3', 'autorouting', 'smart');
    add_line(parent, 'm_charge/1', 'C1/4', 'autorouting', 'smart');
    add_line(parent, 'C1/1', 'IC1/1', 'autorouting', 'smart');
    add_line(parent, 'C1/2', 'IC1/2', 'autorouting', 'smart');
    add_line(parent, 'C1/5', 'IC1/3', 'autorouting', 'smart');
    add_line(parent, 'IC1/1', 'C2/1', 'autorouting', 'smart');
    add_line(parent, 'IC1/2', 'C2/2', 'autorouting', 'smart');
    add_line(parent, 'IC1/4', 'C2/3', 'autorouting', 'smart');
    add_line(parent, 'C2/1', 'IC2/1', 'autorouting', 'smart');
    add_line(parent, 'C2/2', 'IC2/2', 'autorouting', 'smart');
    add_line(parent, 'C2/5', 'IC2/3', 'autorouting', 'smart');
    add_line(parent, 'IC2/1', 'LHE/1', 'autorouting', 'smart');
    add_line(parent, 'IC2/2', 'LHE/2', 'autorouting', 'smart');
    add_line(parent, 'IC2/4', 'LHE/3', 'autorouting', 'smart');

    add_line(parent, 'C1/4', 'Sum_W_comp/1', 'autorouting', 'smart');
    add_line(parent, 'C2/4', 'Sum_W_comp/2', 'autorouting', 'smart');
    add_line(parent, 'IC1/3', 'Sum_Q_IC/1', 'autorouting', 'smart');
    add_line(parent, 'IC2/3', 'Sum_Q_IC/2', 'autorouting', 'smart');

    add_line(parent, 'LHE/3', 'm_out/1', 'autorouting', 'smart');
    add_line(parent, 'LHE/2', 'P_out/1', 'autorouting', 'smart');
    add_line(parent, 'LHE/1', 'T_out/1', 'autorouting', 'smart');
    add_line(parent, 'Sum_W_comp/1', 'W_comp/1', 'autorouting', 'smart');
    add_line(parent, 'Sum_Q_IC/1', 'Q_IC/1', 'autorouting', 'smart');

    % 使能子系统: 仅在充电模式激活
    set_param(parent, 'TreatAsAtomicUnit', 'on');
end

function build_compressor_model(parent, P_out_target, eta)
    % 压缩器模型: 输入 T_in, P_in, P_out_target, m_dot → T_out, W
    % 等熵效率法: h_out = h_in + (h_out_is - h_in)/eta
    Simulink.SubSystem.deleteContents(parent);

    in_T = add_block('simulink/Ports & Subsystems/In1', [parent '/T_in']);
    set_param(in_T, 'Position', [30, 80, 60, 100], 'Port', '1');
    in_P = add_block('simulink/Ports & Subsystems/In1', [parent '/P_in']);
    set_param(in_P, 'Position', [30, 130, 60, 150], 'Port', '2');
    in_m = add_block('simulink/Ports & Subsystems/In1', [parent '/m_dot']);
    set_param(in_m, 'Position', [30, 180, 60, 200], 'Port', '3');

    % 物性查找: h_in = f(T_in, P_in)
    h_lut = add_block('simulink/Lookup Tables/2-D Lookup Table', [parent '/h_LUT']);
    set_param(h_lut, 'Position', [120, 70, 180, 120], ...
        'Table', 'H_table', 'BreakpointsForDimension1', 'T_vec', ...
        'BreakpointsForDimension2', 'P_vec', ...
        'InterpolationMethod', 'Linear point-slope');

    s_lut = add_block('simulink/Lookup Tables/2-D Lookup Table', [parent '/s_LUT']);
    set_param(s_lut, 'Position', [120, 140, 180, 190], ...
        'Table', 'S_table', 'BreakpointsForDimension1', 'T_vec', ...
        'BreakpointsForDimension2', 'P_vec', ...
        'InterpolationMethod', 'Linear point-slope');

    % 理想出口焓: 用 MATLAB Function 做 (P_out, s_in) → h_is 查找
    h_is_fcn = add_block('simulink/User-Defined Functions/MATLAB Function', [parent '/h_is_calc']);
    set_param(h_is_fcn, 'Position', [250, 100, 340, 200]);
    % MATLAB Function 内容将在后面设置

    % 实际出口焓计算
    h_out_calc = add_block('simulink/User-Defined Functions/Fcn', [parent '/h_out_calc']);
    set_param(h_out_calc, 'Position', [400, 100, 470, 160], ...
        'Expr', 'u(1) + (u(2) - u(1)) / eta');

    % 出口温度反向查找: T_out = f(P_out, h_out)
    T_out_fcn = add_block('simulink/User-Defined Functions/MATLAB Function', [parent '/T_out_calc']);
    set_param(T_out_fcn, 'Position', [400, 200, 490, 300]);

    % 功率计算
    W_calc = add_block('simulink/User-Defined Functions/Fcn', [parent '/W_calc']);
    set_param(W_calc, 'Position', [550, 100, 620, 160], ...
        'Expr', 'u(1) * (u(2) - u(3)) / 1e6');  % MW = kg/s * J/kg * 1e-6

    % 输出
    out_T = add_block('simulink/Ports & Subsystems/Out1', [parent '/T_out']);
    set_param(out_T, 'Position', [700, 80, 730, 100], 'Port', '1');
    out_P = add_block('simulink/Ports & Subsystems/Out1', [parent '/P_out']);
    set_param(out_P, 'Position', [700, 130, 730, 150], 'Port', '2');
    out_W = add_block('simulink/Ports & Subsystems/Out1', [parent '/W']);
    set_param(out_W, 'Position', [700, 180, 730, 200], 'Port', '3');
    out_Q = add_block('simulink/Ports & Subsystems/Out1', [parent '/Q_IC']);
    set_param(out_Q, 'Position', [700, 230, 730, 250], 'Port', '4');
    out_m = add_block('simulink/Ports & Subsystems/Out1', [parent '/m_out']);
    set_param(out_m, 'Position', [700, 280, 730, 300], 'Port', '5');

    % 内部连线
    add_line(parent, 'T_in/1', 'h_LUT/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 'h_LUT/2', 'autorouting', 'smart');
    add_line(parent, 'T_in/1', 's_LUT/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 's_LUT/2', 'autorouting', 'smart');
    add_line(parent, 'h_LUT/1', 'h_out_calc/1', 'autorouting', 'smart');
    add_line(parent, 'h_LUT/1', 'W_calc/3', 'autorouting', 'smart');
    add_line(parent, 'm_dot/1', 'W_calc/1', 'autorouting', 'smart');

    set_param(parent, 'Position', [0, 0, 750, 320]);
end

function build_cooler_model(parent, T_out_target)
    % 冷却器/换热器模型: 等压冷却至目标温度
    Simulink.SubSystem.deleteContents(parent);

    in_T = add_block('simulink/Ports & Subsystems/In1', [parent '/T_in']);
    in_P = add_block('simulink/Ports & Subsystems/In1', [parent '/P_in']);
    in_m = add_block('simulink/Ports & Subsystems/In1', [parent '/m_dot']);

    set_param(in_T, 'Port', '1'); set_param(in_P, 'Port', '2'); set_param(in_m, 'Port', '3');

    % h_in 查找
    h_in_lut = add_block('simulink/Lookup Tables/2-D Lookup Table', [parent '/h_in_LUT']);
    set_param(h_in_lut, 'Table', 'H_table', ...
        'BreakpointsForDimension1', 'T_vec', 'BreakpointsForDimension2', 'P_vec');

    % h_out 查找
    h_out_lut = add_block('simulink/Lookup Tables/2-D Lookup Table', [parent '/h_out_LUT']);
    set_param(h_out_lut, 'Table', 'H_table', ...
        'BreakpointsForDimension1', 'T_vec', 'BreakpointsForDimension2', 'P_vec');

    T_const = add_block('simulink/Sources/Constant', [parent '/T_target']);
    set_param(T_const, 'Value', num2str(T_out_target));

    % Q = m_dot * (h_in - h_out)
    Q_calc = add_block('simulink/User-Defined Functions/Fcn', [parent '/Q_calc']);
    set_param(Q_calc, 'Expr', 'abs(u(1) * (u(2) - u(3)) / 1e6)');

    % 输出
    out_T = add_block('simulink/Ports & Subsystems/Out1', [parent '/T_out']);
    out_P = add_block('simulink/Ports & Subsystems/Out1', [parent '/P_out']);
    out_Q = add_block('simulink/Ports & Subsystems/Out1', [parent '/Q']);
    out_m = add_block('simulink/Ports & Subsystems/Out1', [parent '/m_out']);
    set_param(out_T, 'Port', '1'); set_param(out_P, 'Port', '2');
    set_param(out_Q, 'Port', '3'); set_param(out_m, 'Port', '4');

    add_line(parent, 'T_in/1', 'h_in_LUT/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 'h_in_LUT/2', 'autorouting', 'smart');
    add_line(parent, 'T_target/1', 'h_out_LUT/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 'h_out_LUT/2', 'autorouting', 'smart');
    add_line(parent, 'm_dot/1', 'Q_calc/1', 'autorouting', 'smart');
    add_line(parent, 'h_in_LUT/1', 'Q_calc/2', 'autorouting', 'smart');
    add_line(parent, 'h_out_LUT/1', 'Q_calc/3', 'autorouting', 'smart');

    add_line(parent, 'T_target/1', 'T_out/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 'P_out/1', 'autorouting', 'smart');
    add_line(parent, 'Q_calc/1', 'Q/1', 'autorouting', 'smart');
    add_line(parent, 'm_dot/1', 'm_out/1', 'autorouting', 'smart');
end

function build_discharging_subsystem(parent)
    % 放电系统: Throttle → EHE+HR1 → T1 → HR2 → T2 → AE-HE → Cooler
    Simulink.SubSystem.deleteContents(parent);

    % 简化实现: 使用增益块近似膨胀过程，输出功率和状态

    in_mode = add_block('simulink/Ports & Subsystems/In1', [parent '/mode_in']);
    set_param(in_mode, 'Port', '1');

    % HPT 入口条件
    T_hpt_in = add_block('simulink/Sources/Constant', [parent '/T_HPT_in']);
    set_param(T_hpt_in, 'Value', '296');
    P_hpt_in = add_block('simulink/Sources/Constant', [parent '/P_HPT_in']);
    set_param(P_hpt_in, 'Value', '6.65');
    m_disch = add_block('simulink/Sources/Constant', [parent '/m_discharge']);
    set_param(m_disch, 'Value', '40.3');

    % ===== 节流阀 V2 (等焓) =====
    throttle = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/V2_Throttle']);
    build_throttle_model(throttle);

    % ===== EHE + HR1 =====
    heater1 = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/EHE_HR1']);
    build_heater_model(heater1, 483, 6.50);

    % ===== Turbine T1 =====
    t1 = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/T1']);
    build_turbine_model(t1, 0.70, 0.88);

    % ===== HR2 =====
    heater2 = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/HR2']);
    build_heater_model(heater2, 483, 0.65);

    % ===== Turbine T2 =====
    t2 = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/T2']);
    build_turbine_model(t2, 0.12, 0.88);

    % ===== AE-HE + Cooler =====
    aeh = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/AEHE']);
    build_cooler_model(aeh, 303);
    cooler = add_block('simulink/Ports & Subsystems/Subsystem', [parent '/Cooler']);
    build_cooler_model(cooler, 298);

    % 功率汇总
    sum_W = add_block('simulink/Math Operations/Add', [parent '/Sum_W_turb']);
    set_param(sum_W, 'Inputs', '++', 'IconShape', 'round');
    sum_Q = add_block('simulink/Math Operations/Add', [parent '/Sum_Q_HR']);
    set_param(sum_Q, 'Inputs', '++', 'IconShape', 'round');

    % 出口
    out_m = add_block('simulink/Ports & Subsystems/Out1', [parent '/m_out']); set_param(out_m, 'Port', '1');
    out_T = add_block('simulink/Ports & Subsystems/Out1', [parent '/T_out']); set_param(out_T, 'Port', '2');
    out_P = add_block('simulink/Ports & Subsystems/Out1', [parent '/P_out']); set_param(out_P, 'Port', '3');
    out_W = add_block('simulink/Ports & Subsystems/Out1', [parent '/W_turb']); set_param(out_W, 'Port', '4');
    out_Q = add_block('simulink/Ports & Subsystems/Out1', [parent '/Q_HR']); set_param(out_Q, 'Port', '5');

    % 连线
    add_line(parent, 'T_HPT_in/1', 'V2_Throttle/1', 'autorouting', 'smart');
    add_line(parent, 'P_HPT_in/1', 'V2_Throttle/2', 'autorouting', 'smart');
    add_line(parent, 'm_discharge/1', 'V2_Throttle/3', 'autorouting', 'smart');
    add_line(parent, 'V2_Throttle/1', 'EHE_HR1/1', 'autorouting', 'smart');
    add_line(parent, 'V2_Throttle/2', 'EHE_HR1/2', 'autorouting', 'smart');
    add_line(parent, 'V2_Throttle/4', 'EHE_HR1/3', 'autorouting', 'smart');
    add_line(parent, 'EHE_HR1/1', 'T1/1', 'autorouting', 'smart');
    add_line(parent, 'EHE_HR1/3', 'T1/2', 'autorouting', 'smart');
    add_line(parent, 'EHE_HR1/5', 'T1/3', 'autorouting', 'smart');
    add_line(parent, 'T1/1', 'HR2/1', 'autorouting', 'smart');
    add_line(parent, 'T1/3', 'HR2/2', 'autorouting', 'smart');
    add_line(parent, 'T1/5', 'HR2/3', 'autorouting', 'smart');
    add_line(parent, 'HR2/1', 'T2/1', 'autorouting', 'smart');
    add_line(parent, 'HR2/3', 'T2/2', 'autorouting', 'smart');
    add_line(parent, 'HR2/5', 'T2/3', 'autorouting', 'smart');
    add_line(parent, 'T2/1', 'AEHE/1', 'autorouting', 'smart');
    add_line(parent, 'T2/3', 'AEHE/2', 'autorouting', 'smart');
    add_line(parent, 'T2/5', 'AEHE/3', 'autorouting', 'smart');
    add_line(parent, 'AEHE/1', 'Cooler/1', 'autorouting', 'smart');
    add_line(parent, 'AEHE/2', 'Cooler/2', 'autorouting', 'smart');
    add_line(parent, 'AEHE/4', 'Cooler/3', 'autorouting', 'smart');

    add_line(parent, 'T1/4', 'Sum_W_turb/1', 'autorouting', 'smart');
    add_line(parent, 'T2/4', 'Sum_W_turb/2', 'autorouting', 'smart');
    add_line(parent, 'EHE_HR1/4', 'Sum_Q_HR/1', 'autorouting', 'smart');
    add_line(parent, 'HR2/4', 'Sum_Q_HR/2', 'autorouting', 'smart');

    add_line(parent, 'Cooler/4', 'm_out/1', 'autorouting', 'smart');
    add_line(parent, 'Cooler/1', 'T_out/1', 'autorouting', 'smart');
    add_line(parent, 'Cooler/2', 'P_out/1', 'autorouting', 'smart');
    add_line(parent, 'Sum_W_turb/1', 'W_turb/1', 'autorouting', 'smart');
    add_line(parent, 'Sum_Q_HR/1', 'Q_HR/1', 'autorouting', 'smart');

    set_param(parent, 'TreatAsAtomicUnit', 'on');
end

function build_turbine_model(parent, P_out_target, eta)
    % 透平模型: 等熵膨胀 + 效率修正
    Simulink.SubSystem.deleteContents(parent);

    in_T = add_block('simulink/Ports & Subsystems/In1', [parent '/T_in']); set_param(in_T, 'Port', '1');
    in_P = add_block('simulink/Ports & Subsystems/In1', [parent '/P_in']); set_param(in_P, 'Port', '2');
    in_m = add_block('simulink/Ports & Subsystems/In1', [parent '/m_dot']); set_param(in_m, 'Port', '3');

    % 物性查找
    h_lut = add_block('simulink/Lookup Tables/2-D Lookup Table', [parent '/h_in_LUT']);
    set_param(h_lut, 'Table', 'H_table', ...
        'BreakpointsForDimension1', 'T_vec', 'BreakpointsForDimension2', 'P_vec');

    s_lut = add_block('simulink/Lookup Tables/2-D Lookup Table', [parent '/s_in_LUT']);
    set_param(s_lut, 'Table', 'S_table', ...
        'BreakpointsForDimension1', 'T_vec', 'BreakpointsForDimension2', 'P_vec');

    % 膨胀计算: h_out = h_in - eta*(h_in - h_is)
    h_out_calc = add_block('simulink/User-Defined Functions/Fcn', [parent '/h_out_calc']);
    set_param(h_out_calc, 'Expr', 'u(1) - eta * (u(1) - u(2))');

    % 功率
    W_calc = add_block('simulink/User-Defined Functions/Fcn', [parent '/W_calc']);
    set_param(W_calc, 'Expr', 'u(1) * (u(2) - u(3)) / 1e6');

    P_target = add_block('simulink/Sources/Constant', [parent '/P_target']);
    set_param(P_target, 'Value', num2str(P_out_target));

    % 输出
    out_T = add_block('simulink/Ports & Subsystems/Out1', [parent '/T_out']); set_param(out_T, 'Port', '1');
    out_P = add_block('simulink/Ports & Subsystems/Out1', [parent '/P_out']); set_param(out_P, 'Port', '2');
    out_W = add_block('simulink/Ports & Subsystems/Out1', [parent '/W']); set_param(out_W, 'Port', '3');
    out_Q = add_block('simulink/Ports & Subsystems/Out1', [parent '/Q_HR_ext']); set_param(out_Q, 'Port', '4');
    out_m = add_block('simulink/Ports & Subsystems/Out1', [parent '/m_out']); set_param(out_m, 'Port', '5');

    % 连线
    add_line(parent, 'T_in/1', 'h_in_LUT/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 'h_in_LUT/2', 'autorouting', 'smart');
    add_line(parent, 'T_in/1', 's_in_LUT/1', 'autorouting', 'smart');
    add_line(parent, 'P_in/1', 's_in_LUT/2', 'autorouting', 'smart');
    add_line(parent, 'h_in_LUT/1', 'h_out_calc/1', 'autorouting', 'smart');
    add_line(parent, 'h_in_LUT/1', 'W_calc/2', 'autorouting', 'smart');
    add_line(parent, 'm_dot/1', 'W_calc/1', 'autorouting', 'smart');
    add_line(parent, 'P_target/1', 'P_out/1', 'autorouting', 'smart');
    add_line(parent, 'm_dot/1', 'm_out/1', 'autorouting', 'smart');
end

function build_throttle_model(parent)
    Simulink.SubSystem.deleteContents(parent);
    in_T = add_block('simulink/Ports & Subsystems/In1', [parent '/T_in']); set_param(in_T, 'Port', '1');
    in_P = add_block('simulink/Ports & Subsystems/In1', [parent '/P_in']); set_param(in_P, 'Port', '2');
    in_m = add_block('simulink/Ports & Subsystems/In1', [parent '/m_dot']); set_param(in_m, 'Port', '3');

    P_out_const = add_block('simulink/Sources/Constant', [parent '/P_out_target']);
    set_param(P_out_const, 'Value', '6.60');  % ~0.05 MPa 压降

    out_T = add_block('simulink/Ports & Subsystems/Out1', [parent '/T_out']); set_param(out_T, 'Port', '1');
    out_P = add_block('simulink/Ports & Subsystems/Out1', [parent '/P_out']); set_param(out_P, 'Port', '2');
    out_h = add_block('simulink/Ports & Subsystems/Out1', [parent '/h_out']); set_param(out_h, 'Port', '3');
    out_m = add_block('simulink/Ports & Subsystems/Out1', [parent '/m_out']); set_param(out_m, 'Port', '4');

    add_line(parent, 'P_out_target/1', 'P_out/1', 'autorouting', 'smart');
    add_line(parent, 'm_dot/1', 'm_out/1', 'autorouting', 'smart');
    add_line(parent, 'T_in/1', 'T_out/1', 'autorouting', 'smart');  % 等焓近似
end

function build_heater_model(parent, T_out_target, P_out_target)
    % 加热器模型: 等压加热
    build_cooler_model(parent, T_out_target);
    % 加热器和冷却器使用相同模型 (等压热交换)，仅方向相反
end

function build_storage_subsystem(parent)
    % 储罐动态模型 — HPT + LPT 质量/压力演变
    Simulink.SubSystem.deleteContents(parent);

    in_m_in = add_block('simulink/Ports & Subsystems/In1', [parent '/m_dot_in']); set_param(in_m_in, 'Port', '1');
    in_m_out = add_block('simulink/Ports & Subsystems/In1', [parent '/m_dot_out']); set_param(in_m_out, 'Port', '2');
    in_mode = add_block('simulink/Ports & Subsystems/In1', [parent '/mode']); set_param(in_mode, 'Port', '3');

    % HPT 质量积分
    net_mass = add_block('simulink/Math Operations/Sum', [parent '/net_flow']);
    set_param(net_mass, 'Inputs', '+-', 'IconShape', 'round');

    hpt_int = add_block('simulink/Continuous/Integrator', [parent '/HPT_mass']);
    set_param(hpt_int, 'InitialCondition', 'params.V_HPT * 500 / (params.Rg_CO2 * 298)');

    % P = m*R*T/V
    P_calc = add_block('simulink/User-Defined Functions/Fcn', [parent '/P_HPT']);
    set_param(P_calc, 'Expr', 'u * 0.1889 * 298 / 500');

    P_to_MPa = add_block('simulink/Math Operations/Gain', [parent '/to_MPa']);
    set_param(P_to_MPa, 'Gain', '1e-3');

    % LPT 同理
    lpt_int = add_block('simulink/Continuous/Integrator', [parent '/LPT_mass']);
    set_param(lpt_int, 'InitialCondition', 'params.V_LPT * 5 / (params.Rg_CO2 * 298)');

    P_lpt_calc = add_block('simulink/User-Defined Functions/Fcn', [parent '/P_LPT']);
    set_param(P_lpt_calc, 'Expr', 'u * 0.1889 * 298 / 2000');

    P_lpt_MPa = add_block('simulink/Math Operations/Gain', [parent '/to_MPa_LPT']);
    set_param(P_lpt_MPa, 'Gain', '1e-3');

    % 输出
    out_P_hpt = add_block('simulink/Ports & Subsystems/Out1', [parent '/P_HPT']); set_param(out_P_hpt, 'Port', '1');
    out_P_lpt = add_block('simulink/Ports & Subsystems/Out1', [parent '/P_LPT']); set_param(out_P_lpt, 'Port', '2');
    out_m_hpt = add_block('simulink/Ports & Subsystems/Out1', [parent '/m_HPT']); set_param(out_m_hpt, 'Port', '3');

    add_line(parent, 'm_dot_in/1', 'net_flow/1', 'autorouting', 'smart');
    add_line(parent, 'm_dot_out/1', 'net_flow/2', 'autorouting', 'smart');
    add_line(parent, 'net_flow/1', 'HPT_mass/1', 'autorouting', 'smart');
    add_line(parent, 'HPT_mass/1', 'P_HPT/1', 'autorouting', 'smart');
    add_line(parent, 'P_HPT/1', 'to_MPa/1', 'autorouting', 'smart');
    add_line(parent, 'to_MPa/1', 'P_HPT/1', 'autorouting', 'smart');
end

function build_thermal_subsystem(parent)
    % 蓄热系统动态 — HTV 热量平衡
    Simulink.SubSystem.deleteContents(parent);

    in_Q_IC = add_block('simulink/Ports & Subsystems/In1', [parent '/Q_IC']); set_param(in_Q_IC, 'Port', '1');
    in_Q_HR = add_block('simulink/Ports & Subsystems/In1', [parent '/Q_HR']); set_param(in_Q_HR, 'Port', '2');
    in_Q_heat = add_block('simulink/Ports & Subsystems/In1', [parent '/Q_heat']); set_param(in_Q_heat, 'Port', '3');
    in_mode = add_block('simulink/Ports & Subsystems/In1', [parent '/mode']); set_param(in_mode, 'Port', '4');

    net_Q = add_block('simulink/Math Operations/Sum', [parent '/net_heat']);
    set_param(net_Q, 'Inputs', '+--', 'IconShape', 'round');

    htv_int = add_block('simulink/Continuous/Integrator', [parent '/Q_HTV']);
    set_param(htv_int, 'InitialCondition', 'params.Q_HTV_initial');

    Q_to_MWh = add_block('simulink/Math Operations/Gain', [parent '/to_MWh']);
    set_param(Q_to_MWh, 'Gain', '1/3600');

    out_Q = add_block('simulink/Ports & Subsystems/Out1', [parent '/Q_HTV']); set_param(out_Q, 'Port', '1');
    out_SOC = add_block('simulink/Ports & Subsystems/Out1', [parent '/SOC_heat']); set_param(out_SOC, 'Port', '2');

    add_line(parent, 'Q_IC/1', 'net_heat/1', 'autorouting', 'smart');
    add_line(parent, 'Q_HR/1', 'net_heat/2', 'autorouting', 'smart');
    add_line(parent, 'Q_heat/1', 'net_heat/3', 'autorouting', 'smart');
    add_line(parent, 'net_heat/1', 'Q_HTV/1', 'autorouting', 'smart');
    add_line(parent, 'Q_HTV/1', 'to_MWh/1', 'autorouting', 'smart');
    add_line(parent, 'Q_HTV/1', 'Q_HTV/1', 'autorouting', 'smart');
end

function build_controller_subsystem(parent)
    % 充放电控制器: 基于时间和 SOC 切换模式
    Simulink.SubSystem.deleteContents(parent);

    clock_block = add_block('simulink/Sources/Clock', [parent '/Clock']);

    mode_switch = add_block('simulink/User-Defined Functions/MATLAB Function', [parent '/ChargeDischargeLogic']);
    set_param(mode_switch, 'Position', [200, 100, 350, 250]);

    % 模式输出: 1 = charge, -1 = discharge, 0 = idle
    out_mode = add_block('simulink/Ports & Subsystems/Out1', [parent '/mode']); set_param(out_mode, 'Port', '1');
    out_charge_en = add_block('simulink/Ports & Subsystems/Out1', [parent '/charge_enable']); set_param(out_charge_en, 'Port', '2');
    out_disch_en = add_block('simulink/Ports & Subsystems/Out1', [parent '/discharge_enable']); set_param(out_disch_en, 'Port', '3');
    out_heat_en = add_block('simulink/Ports & Subsystems/Out1', [parent '/heat_enable']); set_param(out_heat_en, 'Port', '4');
    in_P_hpt = add_block('simulink/Ports & Subsystems/In1', [parent '/P_HPT_fb']); set_param(in_P_hpt, 'Port', '5');

    add_line(parent, 'Clock/1', 'ChargeDischargeLogic/1', 'autorouting', 'smart');
    add_line(parent, 'P_HPT_fb/1', 'ChargeDischargeLogic/2', 'autorouting', 'smart');
    add_line(parent, 'ChargeDischargeLogic/1', 'mode/1', 'autorouting', 'smart');
    add_line(parent, 'ChargeDischargeLogic/2', 'charge_enable/1', 'autorouting', 'smart');
    add_line(parent, 'ChargeDischargeLogic/3', 'discharge_enable/1', 'autorouting', 'smart');
    add_line(parent, 'ChargeDischargeLogic/4', 'heat_enable/1', 'autorouting', 'smart');
end

function build_results_subsystem(parent)
    Simulink.SubSystem.deleteContents(parent);

    % 汇总结果并用 scope 和 to workspace 输出
    in_W_c = add_block('simulink/Ports & Subsystems/In1', [parent '/W_comp']); set_param(in_W_c, 'Port', '1');
    in_W_t = add_block('simulink/Ports & Subsystems/In1', [parent '/W_turb']); set_param(in_W_t, 'Port', '2');
    in_P = add_block('simulink/Ports & Subsystems/In1', [parent '/P_HPT']); set_param(in_P, 'Port', '3');
    in_Q = add_block('simulink/Ports & Subsystems/In1', [parent '/Q_HTV']); set_param(in_Q, 'Port', '4');

    % Scope 显示
    scope_pwr = add_block('simulink/Sinks/Scope', [parent '/Power_Scope']);
    set_param(scope_pwr, 'Position', [200, 50, 500, 300], 'NumInputPorts', '2');

    scope_storage = add_block('simulink/Sinks/Scope', [parent '/Storage_Scope']);
    set_param(scope_storage, 'Position', [200, 350, 500, 600], 'NumInputPorts', '2');

    % To Workspace
    ws_Wc = add_block('simulink/Sinks/To Workspace', [parent '/W_comp_ws']);
    set_param(ws_Wc, 'VariableName', 'W_comp_hist');
    ws_Wt = add_block('simulink/Sinks/To Workspace', [parent '/W_turb_ws']);
    set_param(ws_Wt, 'VariableName', 'W_turb_hist');
    ws_P = add_block('simulink/Sinks/To Workspace', [parent '/P_HPT_ws']);
    set_param(ws_P, 'VariableName', 'P_HPT_hist');
    ws_Q = add_block('simulink/Sinks/To Workspace', [parent '/Q_HTV_ws']);
    set_param(ws_Q, 'VariableName', 'Q_HTV_hist');
    ws_t = add_block('simulink/Sinks/To Workspace', [parent '/t_ws']);
    set_param(ws_t, 'VariableName', 't_hist');

    add_line(parent, 'W_comp/1', 'Power_Scope/1', 'autorouting', 'smart');
    add_line(parent, 'W_turb/1', 'Power_Scope/2', 'autorouting', 'smart');
    add_line(parent, 'P_HPT/1', 'Storage_Scope/1', 'autorouting', 'smart');
    add_line(parent, 'Q_HTV/1', 'Storage_Scope/2', 'autorouting', 'smart');
end
