# ML-CCES-CHP: 基于机器学习的 CCES-CHP 运行可行域优化

使用机器学习方法构建压缩二氧化碳储能联供系统（CCES-CHP）的运行可行域，并用于 24 h 优化调度。

> ICDIES 2026 投稿: *Research on the Operational Optimal Feasibility Domain of Compressed Carbon Dioxide Energy Storage Systems Based on Machine Learning*

## 依赖环境

- MATLAB R2020a+ + [REFPROP](https://www.nist.gov/srd/refprop)（数据生成、设计点扫描）
- Python 3.10+ + pandas / scikit-learn / XGBoost / matplotlib

本机若无这些包，可临时装到工作区（已 gitignore，约 1.1 GB）：

```bash
python3 -m pip install --target .pylibs pandas scikit-learn xgboost matplotlib
export PYTHONPATH=$PWD/.pylibs
```

## 文件结构

```
ML_EnergyStorage_Optimization/
├── src/
│   ├── generate_training_data.m   # MATLAB: 生成训练数据（调用 cces_design_point）
│   ├── train_ml_models.py         # Python: 训练 XGBoost / MLP
│   ├── dispatch_optimization.py   # Python: 24 h 规则调度 vs ML 调度
│   └── feasibility_comparison.py  # Python: 透平入口温度对可行域的影响
├── data/
│   ├── training_data.csv          # 38,720 条标注数据
│   ├── design_sweep.csv           # 460~520 K 的 γ/α 扫描（MATLAB 生成）
│   ├── dispatch_comparison.png
│   └── feasibility_domain_change.png
├── models/                        # 5 个 pkl
└── pdf/
```

## 运行流程

```matlab
% 1. 生成训练数据（需 REFPROP）
addpath('../CCES_CHP_Simulink/src/ode')
generate_training_data
```

```bash
# 2. 训练（在 src/ 下执行）
python train_ml_models.py
# 3. 调度对比
python dispatch_optimization.py
# 4. 温度敏感性
python feasibility_comparison.py
```

## 2026-11 数据重构（重要）

旧版数据存在三个问题，现已修正：

| 问题 | 旧 | 新 |
|---|---|---|
| γ₂ 含 EHE 蒸发潜热 | 2.307 | **1.659** |
| Q 上限不统一 | 训练 12.05 / 调度 9.5 | **统一 12.05**（γ₁·W_design） |
| SOC_gas 对标签无影响 | 3520 组中 0 组受影响 | **2896/3520 组受影响** |

新增的 HPT 质量约束来自 `cces_design_point` 的 α₁/α₂ 与满液量：

```
充电:  m + α₁·W·Δt ≤ m_full     放电:  m − α₂·W·Δt ≥ 0
```

因为储罐按 5 h 满功率标定，该约束在 SOC_gas > ~87%（充电）或 < ~16%（放电）时才起作用，
但这正是旧版完全缺失的物理边界（旧版在 10% SOC 仍认为可以 10 MW 放电）。

数据集同时把恒定的 `P_HPT_MPa` 换成 `m_HPT_t`，效率列改为设计点实算值（65.9% / 25.3%）。

## ML 模型性能（重训后）

| 模型 | 任务 | 性能 |
|------|------|------|
| XGBoost | 可行性二分类 | 准确率 100.00% |
| MLP (128×64×32) | 可行性二分类 | 准确率 98.58% |
| XGBoost | W_max 回归 | R² = 0.9964（RMSE 0.076 MW） |
| XGBoost | Q_max 回归 | R² = 1.0000 |

特征重要性（XGBoost 分类器）：

| 特征 | 重要性 |
|------|--------|
| mode | 0.4545 |
| **SOC_gas_pct** | **0.2376**（旧数据仅 0.0015） |
| SOC_heat_pct | 0.1998 |
| W_MW | 0.0744 |
| Q_MW | 0.0337 |
| γ₁/γ₂/α₁/α₂ | ~0（训练集中为常数） |

> 注意：标签仍由约束方程解析生成，因此 100% 准确率是可预期的——ML 的价值在于
> **替代 REFPROP 实时查询**与参数泛化，而不是"发现"未知边界。论文表述建议按此定位。

## 调度优化结果（重跑后）

| 指标 | 规则调度 | ML 优化 |
|------|---------|--------|
| 总充电量 | 66.0 MWh | 66.0 MWh |
| 总放电量 | 66.6 MWh | 65.0 MWh |
| 总供热量 | 44.0 MWh | **46.3 MWh（+5.2%）** |
| 放电时长 | 17 h | **24 h** |
| 末态 SOC | 0.0% | 0.2% |
| 电调度跟踪率 | 44.9% | 45.4% |

> 与旧版结论的差别：末态 SOC 不再是 5.0% 的"安全裕量"，ML 的优势体现在
> **覆盖全部 24 h 且多供热 5.2%**，论文里"末态 SOC 5%"的说法需要改写。

## 温度敏感性（修正后）

`feasibility_comparison.py` 旧版手写 `beta2_opt = 1.78`，据此得出"可行域 +23%、
放电 5 h→8 h"。REFPROP 实测（`design_sweep.csv`）：

| 项目 | 483 K | 503 K | 变化 |
|------|-------|-------|------|
| γ₂ | 1.659 | 1.691 | +1.9% |
| α₂ | 4.191 | 3.993 | −4.7% |
| 可行域面积（SOC 10%） | 65.2 | 64.0 | **−1.9%** |
| 同等储液放电时长 | 5.00 h | 5.25 h | **+5.0%** |
| 电-电效率 | 65.9% | 69.2% | +3.3 pt |

结论：升温的真实收益是"同样储液多放 5% + 电效率 +3.3 pt"，
不是可行域扩大 23%。论文 6.4 节已按此改写。

## 关联项目

- `../CCES_CHP_Analysis/` — 论文复现（16 张图）
- `../CCES_CHP_Simulink/src/ode/` — 动态仿真；`cces_design_point.m` 是本项目参数的唯一来源
