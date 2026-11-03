# CCES-CHP 动态仿真（ODE 主线 / Simulink 存档）

基于 REFPROP 物性数据的压缩二氧化碳储能热电联供（CCES-CHP）系统动态仿真。

主线已从 Simulink 迁移到 ODE（`src/ode/`），Simulink 模型保留在 `src/simulink/`，仅供查阅。

## 目录结构

```
CCES_CHP_Simulink/
├── src/
│   ├── CCES_parameters.m              # 早期集总参数（已弃用，仅 archive 引用）
│   ├── ode/                           # ★ 当前主线
│   │   ├── cces_design_point.m        # 设计点单一真源：REFPROP 算 α/γ/时长/容量
│   │   ├── cces_schedule.m            # 24 h 调度分段（充/待/放/待）
│   │   ├── ode_dynamics.m             # 双 SOC ODE（质量 + 热量双重闭合）
│   │   ├── run_ode_simulation.m       # ★ 21 天仿真 + 闭合校验 + 4 张图
│   │   ├── cces_design_sweep.m        # 透平入口温度扫描 → data/design_sweep.csv
│   │   └── archive/                   # 早期 ODE 版本（已被上面的替换）
│   └── simulink/                      # 旧 Simulink 路线（不维护）
│       ├── build_CCES_model.m
│       ├── generate_lookup_tables.m
│       └── ...
├── output/ode/                        # ★ 当前输出
│   ├── fig01_pressure_temp.png        # HPT 储液状态与定压说明
│   ├── fig02_power_energy.png         # 功率时序 + 累积能量
│   ├── fig03_soc_heat.png             # 双 SOC + HTV 蓄热
│   └── fig04_closure.png              # 逐日质量/热量闭合校验
└── data/                              # REFPROP 查找表（仅 Simulink 路线用）
```

## 物理模型（与旧版的关键差别）

1. **EHE 单独拆分**：节流后的液态 CO₂ 先经 EHE 等压汽化（+5 K 过热），再进入 HR1/HR2。
   EHE 热量来自环境/低品位热，不计入 γ₂。旧版把这段潜热并入回热，使 γ₂ 由 1.59 虚高到 2.31。
2. **HPT 为定压室温液态储罐**：状态量是储液质量，压力由泵/背压维持 6.8 MPa，
   储气 SOC = 液位。旧版按理想气体（6228 m³、P = mRT/V）建模，与"室温液态储存"自相矛盾。
3. **双重闭合**：充电时长由质量守恒反解（`m_c·t_c = m_d·t_d`），对外供热由热量守恒反解
   （`Q_IC·t_c = (Q_HR+Q_export)·t_d`）。因此逐日回到同一状态，不靠"撞限幅"制造假稳态。

## 环境依赖

- MATLAB R2020a+，REFPROP 10（Linux 下 `librefprop.so`）
- MATLAB REFPROP 接口（MathWorks FileExchange #180324）

## 快速开始

```matlab
addpath('/home/lab206/code/CO2_energy_storage/CCES_CHP_Simulink/src/ode')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox')
addpath('/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/toolbox/internal')

run_ode_simulation        % 21 天仿真 + 闭合校验，图输出到 output/ode/
```

`run_ode_simulation` 会打印设计点、闭合校核（PASS/FAIL）和逐日明细；
换透平入口温度只需改 `cces_design_point(Th)` 的入参，其余参数自动跟随。

## 关键参数（REFPROP 实测，Th = 483 K）

| 参数 | 值 | 说明 |
|------|-----|------|
| W_design | 10 / 10 MW | 设计充/放电功率 |
| t_charge / t_discharge | 7.59 / 5.00 h | 充电时长由质量闭合反解 |
| α₁ / α₂ | 2.762 / 4.191 kg/(s·MW) | 质量流量系数 |
| γ₁ / γ₂ | 1.205 / 1.659 | 压缩热、回热与电功率之比（γ₂ 不含 EHE） |
| m_c / m_d | 27.62 / 41.91 kg/s | 充/放质量流量 |
| V_HPT | 1280 m³（满液 943 t） | 定压液态储罐，SOC 10%~90% |
| Q_HTV | 150 MWh_th（1290 m³ 导热油） | 495 K 高温 / 298 K 低温，SOC 30%~91% |
| Q_export | 1.69 MW | 对外供热，由热量闭合反解（X = 9.2%） |

## 仿真结果（21 天，21 个完全相同的周期）

| 指标 | 数值 |
|------|------|
| 电-电效率 | **65.9%**（E_dis 1050.0 / E_ch 1593.2 MWh） |
| 质量闭合 | 每日漂移 max 0.56 kg（相对 7.4×10⁻⁷） |
| 热量闭合 | 每日漂移 max 6.8×10⁻⁵ MWh（相对 7.4×10⁻⁷） |
| 段内截断 | 0（功率从未被限幅削峰） |
| 储液 SOC | 10.0% ~ 90.0% |
| 蓄热 SOC | 30.0% ~ 90.9% |
| 供热分配 | Q_IC 1919.1 = 回热 1741.9 + 对外 177.2 MWh（残差 0.035 MWh） |

逐日明细（前 7 天，后 14 天同值）：

```
 Day  Δm[kg]   ΔQ[MWh]   E_ch   E_dis   Q_in   Q_out   Q_HTV_end
  1     -0.29    -0.0000    75.9    50.0    91.4    91.4     45.0
  2     -0.16    -0.0000    75.9    50.0    91.4    91.4     45.0
  ...
```

## 注意事项

- `getFluidProperty` 的 `'MASS BASE SI'` 单位制要求压力为 **Pa**
- HPT 是 5 h 级储能罐（943 t 满液），不是"30 分钟缓冲"
- 与论文 Eq.23（理想气体压力）的差异见「物理模型」第 2 条，写论文时需说明
