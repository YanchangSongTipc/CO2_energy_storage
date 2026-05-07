% =========================================================================
% CCES-CHP 高精度热力学循环计算模型 (基于 REFPROP 物性调用修正版)
% 适配特定的 getFluidProperty 语法结构
% =========================================================================

clc; clear; close all;

%% 1. 系统边界条件与设计参数
libLoc = 'D:\Program Files\REFPROP\'; % 请根据您电脑上的实际安装路径修改
Fluid = 'CO2';

eta_c = 0.85;       % 压气机等熵效率
eta_t = 0.88;       % 透平机等熵效率

% 质量流量 (kg/s)
m_charge = 26.9;    
m_discharge = 40.3; 

% 初始化状态点矩阵: [节点, T(K), P(MPa), h(kJ/kg), s(kJ/(kg*K)), m(kg/s)]
Num_States = 15;
States = zeros(Num_States, 6);
States(:, 1) = 1:Num_States;

%% 2. 储能/充电过程 (Charging Process) 计算
% [节点 1 & 2]: LPT出口 -> C1入口 (环境初始态)
States(1, 2) = 298; States(1, 3) = 0.102; States(1, 6) = m_charge;
States(1, 4) = getFluidProperty(libLoc, 'H', 'P', States(1,3), 'T', States(1,2), Fluid, 1, 1, 'MASS BASE SI');
States(1, 5) = getFluidProperty(libLoc, 'S', 'P', States(1,3), 'T', States(1,2), Fluid, 1, 1, 'MASS BASE SI');
States(2, 2:6) = States(1, 2:6);

% [节点 3]: C1出口 (等熵压缩 + 效率修正)
States(3, 3) = 0.90; States(3, 6) = m_charge;
s3_is = States(2, 5); % 理想等熵过程熵不变
h3_is = getFluidProperty(libLoc, 'H', 'P', States(3,3), 'S', s3_is, Fluid, 1, 1, 'MASS BASE SI'); % 理想出口焓
States(3, 4) = States(2, 4) + (h3_is - States(2, 4)) / eta_c; % 实际出口焓 (等熵效率公式)
States(3, 2) = getFluidProperty(libLoc, 'T', 'P', States(3,3), 'H', States(3,4), Fluid, 1, 1, 'MASS BASE SI'); % 反查实际温度
States(3, 5) = getFluidProperty(libLoc, 'S', 'P', States(3,3), 'H', States(3,4), Fluid, 1, 1, 'MASS BASE SI');

% [节点 4]: IC1出口 -> C2入口 (等压/微压降冷却)
States(4, 2) = 308; States(4, 3) = 0.85; States(4, 6) = m_charge;
States(4, 4) = getFluidProperty(libLoc, 'H', 'P', States(4,3), 'T', States(4,2), Fluid, 1, 1, 'MASS BASE SI');
States(4, 5) = getFluidProperty(libLoc, 'S', 'P', States(4,3), 'T', States(4,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 5]: C2出口 (等熵压缩 + 效率修正)
States(5, 3) = 6.90; States(5, 6) = m_charge;
s5_is = States(4, 5);
h5_is = getFluidProperty(libLoc, 'H', 'P', States(5,3), 'S', s5_is, Fluid, 1, 1, 'MASS BASE SI');
States(5, 4) = States(4, 4) + (h5_is - States(4, 4)) / eta_c;
States(5, 2) = getFluidProperty(libLoc, 'T', 'P', States(5,3), 'H', States(5,4), Fluid, 1, 1, 'MASS BASE SI');
States(5, 5) = getFluidProperty(libLoc, 'S', 'P', States(5,3), 'H', States(5,4), Fluid, 1, 1, 'MASS BASE SI');

% [节点 6]: IC2出口 -> LHE入口
States(6, 2) = 309; States(6, 3) = 6.85; States(6, 6) = m_charge;
States(6, 4) = getFluidProperty(libLoc, 'H', 'P', States(6,3), 'T', States(6,2), Fluid, 1, 1, 'MASS BASE SI');
States(6, 5) = getFluidProperty(libLoc, 'S', 'P', States(6,3), 'T', States(6,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 7]: LHE出口 (冷却液化装入HPT)
States(7, 2) = 298; States(7, 3) = 6.80; States(7, 6) = m_charge;
States(7, 4) = getFluidProperty(libLoc, 'H', 'P', States(7,3), 'T', States(7,2), Fluid, 1, 1, 'MASS BASE SI');
States(7, 5) = getFluidProperty(libLoc, 'S', 'P', States(7,3), 'T', States(7,2), Fluid, 1, 1, 'MASS BASE SI');

%% 3. 释能/发电过程 (Discharging Process) 计算
% [节点 8]: HPT出口 -> 节流阀 V2
States(8, 2) = 296; States(8, 3) = 6.65; States(8, 6) = m_discharge;
States(8, 4) = getFluidProperty(libLoc, 'H', 'P', States(8,3), 'T', States(8,2), Fluid, 1, 1, 'MASS BASE SI');
States(8, 5) = getFluidProperty(libLoc, 'S', 'P', States(8,3), 'T', States(8,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 9]: 节流阀 V2 出口 (等焓节流膨胀过程 h9 = h8)
States(9, 3) = 6.60; States(9, 6) = m_discharge;
States(9, 4) = States(8, 4); % 等焓过程
States(9, 2) = getFluidProperty(libLoc, 'T', 'P', States(9,3), 'H', States(9,4), Fluid, 1, 1, 'MASS BASE SI');
States(9, 5) = getFluidProperty(libLoc, 'S', 'P', States(9,3), 'H', States(9,4), Fluid, 1, 1, 'MASS BASE SI');

% [节点 10]: EHE + HR1 加热后 -> T1入口
States(10, 2) = 483; States(10, 3) = 6.50; States(10, 6) = m_discharge;
States(10, 4) = getFluidProperty(libLoc, 'H', 'P', States(10,3), 'T', States(10,2), Fluid, 1, 1, 'MASS BASE SI');
States(10, 5) = getFluidProperty(libLoc, 'S', 'P', States(10,3), 'T', States(10,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 11]: T1 出口 (等熵膨胀 + 效率修正)
States(11, 3) = 0.70; States(11, 6) = m_discharge;
s11_is = States(10, 5); % 理想等熵过程
h11_is = getFluidProperty(libLoc, 'H', 'P', States(11,3), 'S', s11_is, Fluid, 1, 1, 'MASS BASE SI');
States(11, 4) = States(10, 4) - eta_t * (States(10, 4) - h11_is); % 实际出口焓
States(11, 2) = getFluidProperty(libLoc, 'T', 'P', States(11,3), 'H', States(11,4), Fluid, 1, 1, 'MASS BASE SI');
States(11, 5) = getFluidProperty(libLoc, 'S', 'P', States(11,3), 'H', States(11,4), Fluid, 1, 1, 'MASS BASE SI');

% [节点 12]: HR2 加热后 -> T2入口
States(12, 2) = 483; States(12, 3) = 0.65; States(12, 6) = m_discharge;
States(12, 4) = getFluidProperty(libLoc, 'H', 'P', States(12,3), 'T', States(12,2), Fluid, 1, 1, 'MASS BASE SI');
States(12, 5) = getFluidProperty(libLoc, 'S', 'P', States(12,3), 'T', States(12,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 13]: T2 出口 (等熵膨胀 + 效率修正)
States(13, 3) = 0.12; States(13, 6) = m_discharge;
s13_is = States(12, 5); 
h13_is = getFluidProperty(libLoc, 'H', 'P', States(13,3), 'S', s13_is, Fluid, 1, 1, 'MASS BASE SI');
States(13, 4) = States(12, 4) - eta_t * (States(12, 4) - h13_is);
States(13, 2) = getFluidProperty(libLoc, 'T', 'P', States(13,3), 'H', States(13,4), Fluid, 1, 1, 'MASS BASE SI');
States(13, 5) = getFluidProperty(libLoc, 'S', 'P', States(13,3), 'H', States(13,4), Fluid, 1, 1, 'MASS BASE SI');

% [节点 14]: AE-HE 换热出口 -> Cooler入口
States(14, 2) = 303; States(14, 3) = 0.102; States(14, 6) = m_discharge;
States(14, 4) = getFluidProperty(libLoc, 'H', 'P', States(14,3), 'T', States(14,2), Fluid, 1, 1, 'MASS BASE SI');
States(14, 5) = getFluidProperty(libLoc, 'S', 'P', States(14,3), 'T', States(14,2), Fluid, 1, 1, 'MASS BASE SI');

% [节点 15]: Cooler 冷却出口 -> LPT入口回流
States(15, 2) = 298; States(15, 3) = 0.102; States(15, 6) = m_discharge;
States(15, 4) = getFluidProperty(libLoc, 'H', 'P', States(15,3), 'T', States(15,2), Fluid, 1, 1, 'MASS BASE SI');
States(15, 5) = getFluidProperty(libLoc, 'S', 'P', States(15,3), 'T', States(15,2), Fluid, 1, 1, 'MASS BASE SI');

%% 4. 输出计算结果表
fprintf('========================================================================================\n');
fprintf('                CCES-CHP 循环高精度热力学状态点 (基于 REFPROP)\n');
fprintf('========================================================================================\n');
fprintf(' 节点 | 温度 T (K) | 压力 P (MPa) |  焓 h (kJ/kg)  | 熵 s (kJ/kg·K) | 流量 m (kg/s) \n');
fprintf('----------------------------------------------------------------------------------------\n');
for i = 1:Num_States
    fprintf('  %2d  |  %8.2f  |   %8.3f   |   %10.2f   |   %10.4f    |    %6.1f \n', ...
        States(i,1), States(i,2), States(i,3), States(i,4), States(i,5), States(i,6));
end
fprintf('========================================================================================\n\n');

%% 5. 压缩机与透平实际功率校验计算 (MW)
W_C1 = m_charge * (States(3,4) - States(2,4)) / 1000;
W_C2 = m_charge * (States(5,4) - States(4,4)) / 1000;
W_T1 = m_discharge * (States(10,4) - States(11,4)) / 1000;
W_T2 = m_discharge * (States(12,4) - States(13,4)) / 1000;

fprintf('--- 核心部件功率校核 (未计入机械效率) ---\n');
fprintf('第一级压气机耗功: %.2f MW\n', W_C1);
fprintf('第二级压气机耗功: %.2f MW\n', W_C2);
fprintf('总压缩耗功:       %.2f MW\n\n', W_C1 + W_C2);

fprintf('第一级透平发电功: %.2f MW\n', W_T1);
fprintf('第二级透平发电功: %.2f MW\n', W_T2);
fprintf('总透平发电功:     %.2f MW\n', W_T1 + W_T2);

%% 6. 循环状态 T-P 图可视化 (基于 REFPROP 计算结果)
% 创建宽屏高分辨率画布
figure('Name', 'CCES-CHP T-P Diagram (REFPROP)', 'Color', 'w', 'Position', [150, 150, 900, 600]);
hold on; grid on;
grid minor; % 开启次级网格以适应对数坐标

% 提取充放电阶段的温度和压力数据
T_charge = States(1:7, 2);
P_charge = States(1:7, 3);
T_discharge = States(8:15, 2);
P_discharge = States(8:15, 3);

% 绘制储能/压缩过程轨迹 (红线，带黑色边缘的红色圆点)
p1 = plot(T_charge, P_charge, '-ro', 'LineWidth', 2.5, 'MarkerSize', 9, ...
          'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r');

% 绘制释能/膨胀过程轨迹 (蓝虚线，带黑色边缘的蓝色方块)
p2 = plot(T_discharge, P_discharge, '--bs', 'LineWidth', 2.5, 'MarkerSize', 9, ...
          'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'b');

% 绘制 CO2 临界点作为参考 (绿星)
T_crit = 304.1; P_crit = 7.38;
p3 = plot(T_crit, P_crit, 'p', 'MarkerSize', 16, ...
          'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');

%% 7. 动态添加节点文本标注
% 充电节点标号 (1-7)
labels_charge = {'1', '2', '3', '4', '5', '6', '7'};
for i = 1:length(T_charge)
    % 对于节点1和2因为坐标相同，做一点特殊处理防止重叠
    if i == 1
        text(T_charge(i) - 15, P_charge(i) * 1.15, '1,2', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.7 0 0]);
    elseif i > 2
        text(T_charge(i) + 4, P_charge(i) * 1.15, labels_charge{i}, 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.7 0 0]);
    end
end

% 放电节点标号 (8-15)
labels_discharge = {'8', '9', '10', '11', '12', '13', '14', '15'};
for i = 1:length(T_discharge)
    % 节点 14 和 15 距离较近，调整文字偏移
    if i == 7 || i == 8
        text(T_discharge(i) + 4, P_discharge(i) * 0.75, labels_discharge{i}, 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0 0.7]);
    else
        text(T_discharge(i) + 4, P_discharge(i) * 0.85, labels_discharge{i}, 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0 0.7]);
    end
end

% 临界点专门标注
text(T_crit - 45, P_crit * 1.3, 'Critical Point', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0.6 0]);

%% 8. 坐标轴格式化与图例设置
% 将Y轴设置为对数坐标系 (二氧化碳储能循环必备)
set(gca, 'YScale', 'log');

% 手动设置整齐的对数刻度标识
yticks([0.1, 0.5, 1, 5, 10]);
yticklabels({'0.1', '0.5', '1.0', '5.0', '10.0'});

% 设置坐标轴留白范围
xlim([280, 520]);
ylim([0.08, 12]);

% 轴标签与标题
title('CCES-CHP Thermodynamic Cycle (T-P Diagram) - REFPROP', 'FontSize', 16, 'FontWeight', 'bold');
xlabel('Temperature T (K)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Pressure P (MPa)', 'FontSize', 14, 'FontWeight', 'bold');

% 添加图例
legend([p1, p2, p3], {'Charging Process (压缩/液化阶段)', ...
                      'Discharging Process (膨胀/发电阶段)', ...
                      'CO_2 Critical Point (临界点)'}, ...
       'Location', 'southeast', 'FontSize', 12, 'Box', 'on');

% 统一设置全局坐标系字体格式
set(gca, 'FontSize', 12, 'LineWidth', 1.2);
box on;