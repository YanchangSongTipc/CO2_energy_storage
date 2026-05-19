# CCES-CHP Simulink 动态仿真项目

基于 REFPROP 物性数据的压缩二氧化碳储能热电联供 (CCES-CHP) 系统动态仿真。

## 目录结构

```
CCES_CHP_Simulink/
├── src/                           # 源代码
│   ├── CCES_parameters.m          # 系统参数定义 (SI单位)
│   ├── generate_lookup_tables.m   # REFPROP 物性查找表预计算
│   ├── build_CCES_model.m         # Simulink 程序化构建框架
│   ├── run_paper_dispatch.m       # ★ 论文负荷曲线24h调度仿真
│   ├── run_full_simulation.m      # 自定义多循环24h方案
│   └── run_dynamic_simulation.m   # ODE45 基础动态仿真
├── output/                        # 仿真结果输出
│   ├── paper_dispatch_results.png # 论文负荷8面板综合图
│   ├── paper_dispatch_data.mat
│   ├── 24h_simulation_results.png
│   ├── 24h_simulation_data.mat
│   ├── dynamic_simulation_results.png
│   └── simulation_results.mat
└── data/                          # 生成数据
    ├── REFPROP_lookup.mat         # CO2物性预计算查找表
    └── lookup_grid_validation.png
```

## 系统概述

模拟 CCES-CHP 系统 24 小时动态运行，包含：

- **双 SOC 模型**: 气体 SOC (HPT 压力) + 热量 SOC (HTV 蓄热)
- **耦合系数**: α (质量流量-功率), β (热量-功率)
- **物理约束**: HPT 储罐压力上下限, HTV 蓄热容量约束
- **调度模式**: 充电-供热 / 放电-供热 / 仅供热

## 环境依赖

- MATLAB R2020a+
- REFPROP 10 (Linux 通过 CMake 编译的 `librefprop.so`)
- MATLAB REFPROP 接口 (MathWorks FileExchange #180324)

## 快速开始

```matlab
% 1. 添加路径
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')

% 2. 运行论文负荷曲线24h调度仿真
run_paper_dispatch

% 3. 或运行自定义多循环方案
run_full_simulation
```

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| W_design | 10 MW | 设计充放电功率 |
| β₁ | 1.185 | 压缩热/充电功率比 |
| β₂ | 2.307 | 回热/放电功率比 |
| α₁ | 2.744 kg/(s·MW) | 充电质量流量系数 |
| α₂ | 4.117 kg/(s·MW) | 放电质量流量系数 |
| V_HPT | 500 m³ | 高压储罐容积 |
| Q_HTV | 150 MWh_th | 蓄热容量 |

## 仿真结果

基于论文负荷曲线的24h调度：
- 电力往返效率: 83.3%
- 总充电量: 12.01 MWh / 总放电量: 10.01 MWh
- 总供热量: 52.00 MWh_th
- HPT 压力范围: 0.12 - 6.80 MPa

## 注意事项

- `getFluidProperty` 的 `'MASS BASE SI'` 单位制要求压力为 **Pa**
- HPT 储罐是快速缓冲 (~30分钟充满), HTV 蓄热是长时间尺度储能
- Simulink 模型框架需配合查找表生成器使用
