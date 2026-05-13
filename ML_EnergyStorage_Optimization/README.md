# ML-CCES-CHP: 基于机器学习的 CCES-CHP 运行可行域优化

使用机器学习方法动态构建和优化压缩二氧化碳储能联供系统（CCES-CHP）的运行可行域。

> ICDIES 2026 投稿: *Research on the Operational Optimal Feasibility Domain of Compressed Carbon Dioxide Energy Storage Systems Based on Machine Learning*

## 依赖环境

- MATLAB R2020a+ + [REFPROP](https://www.nist.gov/srd/refprop)（数据生成）
- Python 3.10+ + scikit-learn + XGBoost（ML 训练与优化）

## 文件结构

```
ML_EnergyStorage_Optimization/
├── src/
│   ├── generate_training_data.m   # MATLAB: 批量生成训练数据 (38,720 样本)
│   ├── train_ml_models.py         # Python: 训练 XGBoost / MLP 模型
│   └── dispatch_optimization.py   # Python: 基于 ML 的 24h 优化调度
├── data/
│   ├── training_data.csv          # 38,720 条标注数据
│   └── dispatch_comparison.png    # 规则调度 vs ML 优化对比图
├── models/
│   ├── xgb_classifier.pkl         # XGBoost 可行性分类器 (100% acc)
│   ├── xgb_reg_Wmax.pkl           # W_max 边界回归 (R²=1.0)
│   ├── xgb_reg_Qmax.pkl           # Q_max 边界回归 (R²=1.0)
│   ├── mlp_classifier.pkl         # MLP 分类器 (99.77% acc)
│   └── scaler.pkl                 # 特征标准化器
└── pdf/
    └── ICDIES2026_Abstract_Template.pdf
```

## 运行流程

### 1. 生成训练数据

修改 `src/generate_training_data.m` 中的 REFPROP 路径，在 MATLAB 中运行：

```matlab
run('src/generate_training_data.m')
```

输出: `data/training_data.csv` (38,720 样本)

### 2. 训练 ML 模型

```bash
cd src
python train_ml_models.py
```

### 3. 优化调度

```bash
cd src
python dispatch_optimization.py
```

## ML 模型性能

| 模型 | 任务 | 性能 |
|------|------|------|
| XGBoost | 可行性二分类 | 准确率 100.00% |
| MLP (128×64×32) | 可行性二分类 | 准确率 99.77% |
| XGBoost | W_max 回归 | R² = 1.0000 |
| XGBoost | Q_max 回归 | R² = 1.0000 |

## 调度优化结果

| 指标 | 规则调度 | ML 优化 |
|------|---------|--------|
| 放电时长 | 15 h | **24 h** |
| 总供热量 | 43.0 MWh | **46.3 MWh** |
| 末态 SOC | 0.0% | **5.0%** |

## 方法概要

1. **参数化可行域**: 用无量纲因子 γ₁/γ₂ 和比率参数 α₁/α₂ 耦合电-热-质流关系
2. **双 SOC 约束**: 热存储 (HTV) + 气存储 (HPT) 联合约束边界
3. **ML 学习**: XGBoost + MLP 从热力学仿真数据中学习可行域映射
4. **优化调度**: 在 ML 预测的可行域内，网格搜索最优 (W, Q) 以最小化调度偏差

## 关联项目

- `../CCES_CHP_Analysis/` — 原始热力学模型与运行可行域分析（论文复现）
