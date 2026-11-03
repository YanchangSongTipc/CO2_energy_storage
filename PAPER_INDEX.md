# 论文与图件索引（PAPER_INDEX）

给协作者 / 换机器时用的入口文件。仓库根目录，2026-11 修订。

---

## 一、文档在哪

| 文档 | 路径 | 说明 |
|---|---|---|
| **正文** | [ML_EnergyStorage_Optimization/paper_manuscript.md](ML_EnergyStorage_Optimization/paper_manuscript.md) | ICDIES 2026 投稿稿，Markdown，约 700 行，已内嵌 8 图 |
| 修订记录 | [ML_EnergyStorage_Optimization/DATA_REVISION.md](ML_EnergyStorage_Optimization/DATA_REVISION.md) | 旧值 → 新值对照，改稿依据 |
| 早期框架 | [ML_EnergyStorage_Optimization/paper_framework.md](ML_EnergyStorage_Optimization/paper_framework.md) | 规划稿，**数值已作废**，仅供结构参考 |
| ML 流程与指标 | [ML_EnergyStorage_Optimization/README.md](ML_EnergyStorage_Optimization/README.md) | 数据生成 → 训练 → 调度 |
| ODE 模型说明 | [CCES_CHP_Simulink/README.md](CCES_CHP_Simulink/README.md) | 双 SOC 模型、闭合条件、结果表 |

## 二、图的说明文档在哪

| 说明文档 | 覆盖的图 |
|---|---|
| [CCES_CHP_Analysis/explain.md](CCES_CHP_Analysis/explain.md) | 复现图 Fig01–Fig14 的逐图解释（16 KB） |
| [CCES_CHP_Simulink/output/ode/FIGURES.md](CCES_CHP_Simulink/output/ode/FIGURES.md) | ODE 仿真 fig01–fig04 |
| [ML_EnergyStorage_Optimization/data/figures_explanation.md](ML_EnergyStorage_Optimization/data/figures_explanation.md) | dispatch_comparison / feasibility_domain_change |

## 三、正文图号 → 实际文件

正文已内嵌 8 张图（Markdown 图片引用，路径相对 `ML_EnergyStorage_Optimization/`），图号按出现顺序排列：

| 正文 | 内容 | 对应文件 | 状态 |
|---|---|---|---|
| Fig. 1 | 系统流程图 | [CCES_CHP_cycle.drawio](CCES_CHP_Simulink/output/CCES_CHP_cycle.drawio) | **待导出**：drawio 内仍是旧值（β₂=2.31、HPT 6228 m³、9.55/10.12 MW），先改成 γ₂=1.659、1280 m³/943 t、9.74/9.62 MW，再导出 PNG 到同目录 |
| Fig. 2 | T–s 循环图（含饱和穹顶） | [Fig12_Ts_Diagram.png](CCES_CHP_Analysis/output_figures/Fig12_Ts_Diagram.png) | 已内嵌 |
| Fig. 3 | 双 SOC 与 HTV 蓄热 | [fig03_soc_heat.png](CCES_CHP_Simulink/output/ode/fig03_soc_heat.png) | 已内嵌 |
| Fig. 4 | 充电可行域（斜率 +γ₁） | [Fig01_ChargeHeat_Feasibility.png](CCES_CHP_Analysis/output_figures/Fig01_ChargeHeat_Feasibility.png) | 已内嵌；演示参数 b=8，图内标题仍是旧符号 β₁，需重出 |
| Fig. 5 | 放电可行域（斜率 −γ₂） | [Fig02_DischargeHeat_Feasibility.png](CCES_CHP_Analysis/output_figures/Fig02_DischargeHeat_Feasibility.png) | 已内嵌；演示参数 b=18，图内标题仍是旧符号 β₂，需重出 |
| Fig. 6 | 负荷与风电曲线 | [Fig03_LoadWind.png](CCES_CHP_Analysis/output_figures/Fig03_LoadWind.png) | 已内嵌 |
| Fig. 7 | 规则 vs ML 调度 | [dispatch_comparison.png](ML_EnergyStorage_Optimization/data/dispatch_comparison.png) | 已内嵌 |
| Fig. 8 | 温度扫描（γ₂ 近常数、α₂ 下降） | [feasibility_domain_change.png](ML_EnergyStorage_Optimization/data/feasibility_domain_change.png) | 已内嵌 |

其余可选用图见 [CCES_CHP_Analysis/README.md](CCES_CHP_Analysis/README.md) 的图号对照表。

## 四、重新生成

```matlab
% 复现图（14 张）
cd CCES_CHP_Analysis;  PaperReproduction

% ODE 图（4 张）
addpath('CCES_CHP_Simulink/src/ode');  run_ode_simulation

% 训练数据 + 温度扫描
addpath('CCES_CHP_Simulink/src/ode');  generate_training_data
cces_design_sweep(460:10:520, 'ML_EnergyStorage_Optimization/data/design_sweep.csv')
```

```bash
# ML 两张图（需要 pandas/scikit-learn/xgboost/matplotlib）
cd ML_EnergyStorage_Optimization/src
python train_ml_models.py
python dispatch_optimization.py
python feasibility_comparison.py
```

## 五、当前关键数值（防止再引用旧值）

| 项目 | 值 |
|---|---|
| γ₁ / γ₂ | 1.205 / **1.659**（γ₂ 不含 EHE 潜热；旧值 2.307 作废） |
| α₁ / α₂ | 2.762 / 4.191 kg/(s·MW) |
| HPT | 定压液态，1280 m³，满液 943 t，SOC 10–90% |
| Q 上限 | 12.05 MW（= γ₁·W_design） |
| 复现结果 | X=9.3%、Y=90.7%、η_elec=65.8%、η_heat=25.4% |
| ML 模型 | XGB 100%、MLP 98.58%、W_max R²=0.9964 |
| 调度 | 17→24 h、44.0→46.3 MWh、末态 SOC 0.0→0.2% |
| 温度扫描 | γ₂ 1.659→1.691、面积 −1.9%、时长 5.00→5.25 h、效率 65.9→69.2% |

## 六、在另一台电脑上使用 DSH

```bash
git clone git@github.com:YanchangSongTipc/CO2_energy_storage.git
cd CO2_energy_storage
dsh            # 启动 DeepSeek Harness
```

进入 DSH 后，可直接说：

> 读 PAPER_INDEX.md，然后打开 ML_EnergyStorage_Optimization/paper_manuscript.md，
> 图件说明在 CCES_CHP_Analysis/explain.md 和 ML_EnergyStorage_Optimization/data/figures_explanation.md

或指定要处理的任务，例如：

> 按 PAPER_INDEX.md 第三节，把 Fig. 2 和 Fig. 3 插入 paper_manuscript.md 对应位置，
> 并检查全文数字是否与第五节一致

> 把 paper_manuscript.md 转成 Word/LaTeX 投稿格式，图按第三节映射重命名为 Fig1/Fig2/Fig3
