# 期刊版改稿交接单（Applied Energy / ECM）

> 生成时间：2026-11-03 · 对应远端 `4afb182` 之后的增量
> 用法：在工作电脑上 `git pull` 后，按 §2 的顺序执行；正文改动在 §3 直接复制粘贴。
> 所有"期望值"都是我在本机（Python 3.12 / sklearn 1.9.1 / xgboost 3.4.1）实跑得到的，
> 你那边数值应在±0.5 个百分点、±0.05 以内；超出说明数据或版本不一致，先别改正文。

---

## 0. 两台机器怎么分工（先看这一节）

原则：**需要 REFPROP / MATLAB / draw.io 的只有三件事，其余都在我这边做。**

| # | 工作电脑（有 MATLAB + REFPROP） | 本机 / 我这边 |
|---|---|---|
| 1 | `design_sweep_multi` 多参数扫描 → `design_sweep_multi.csv` | 基于扫描结果做多参数泛化分析与新图 |
| 2 | `PaperReproduction` 重出 14 张图（Fig.4/5 去图内标题、β→γ） | 检查图片、必要时改图注 |
| 3 | 修正 drawio 旧数值 → 导出 `CCES_CHP_cycle.png` | 校验 Fig.1 路径可用 |
| 4 | （可选）`python ml_extension.py` 复核我的数值 | 正文替换 A–H、λ 敏感性、经济学模块 |
| 5 | `git add/commit/push` 回传 | `git pull` 后接着分析、写稿 |

工作电脑上**不必**装 Python 依赖：`ml_extension.py` 的产物（CSV/PNG）已在仓库里，复核是可选项。
反过来，本机没有 REFPROP，所以第 1–3 项只能你跑；跑完 push，我 `git pull` 就能接上。

### 回传协议

1. 工作电脑：`git pull` → 做完第 1–3 项 → `git add -A && git commit -m "..." && git push`
2. 回到这边：告诉我"已经 push"，我 `git pull`，然后继续 §4 的经济性与 §3 的正文替换
3. 若中途改了 MATLAB 脚本，请在 commit message 里写清改了哪个函数，避免我们两边改同一处

---

## 1. 这次为什么要改（三条已确认的结论）

| # | 结论 | 影响的原文 |
|---|---|---|
| C1 | 分类准确率应为 5 折交叉验证的 **100.00±0.01%（XGB）/ 99.74±0.11%（MLP）**；原稿 98.58% 是单次划分的偏差。边界回归 R² 是 **1.0000**（不是 0.9964） | §4.5 表 4 及其后一段、摘要、结论 2 |
| C2 | 特征重要性用 **TreeSHAP**：SOC_heat 41.5%、SOC_gas 25.1%、W 14.7%、mode 13.0%、Q 5.8%。原稿 gain 重要性里 mode 45.5% 属方法性偏差 | §4.2 表 3 及其后一段、结论 2 |
| C3 | **"放电 17→24 h" 是统计错误**：`np.sum(W>0)` 把充电小时也算进去了。按"放电时段内功率>0"重算为 **9→16 h**；按"任意非零功率小时"才是 17→24 h。供热 44.0→46.3 MWh（+5.2%）成立，但机制是**代理模型在边界附近偏保守**（把可行点判为不可行），从而把储热留到后面，不是原稿说的"电热动态最优分配" | §6.2 表 6、观察 1/3、§6.3 全部、摘要、结论 3 |
| C4 | 用 LP（HiGHS）求同一目标函数的**精确最优**：目标 82.868；规则调度 85.876（+3.63%）；ML 网格 86.041（+3.83%）。即网格贪心比规则调度还差一点，离最优差 3.8%。供热只有在 λ≥1 时才有正收益（44.0 / 48.0 / 52.0） | 新增 §5.4、新增 §6.5 |

**决策点**：C3/C4 会削弱"ML 优化调度"的卖点。建议的替代叙事是——ML 代理的价值在**推理速度与参数泛化**，调度增益必须**显式写进目标函数**；在同一目标下网格贪心距最优 3.8%，供热优先（λ≥1）时 ML 比规则多 9%、LP 再多 8%。这套说法站得住，且顺带回答了审稿人一定会问的 optimality gap。

---

## 2. 执行顺序

### Step 0 · 同步代码（工作电脑）

```bash
cd /path/to/CO2_energy_storage
git pull          # 需要拉到 ccc6659 及之后的提交
```

### Step 1 · MATLAB 多参数扫描（新增，约 3–10 min）

`cces_design_point.m` 已扩展为 `cces_design_point(Th, opts)`，`opts` 支持
`eta_c / eta_t / T_amb / P_HPT`，缺省行为与旧版完全一致（基准点仍为 γ₂=1.659）。
高压侧压力按 `P_HPT/6.80` 等比缩放——这是敏感性分析用的近似，正文需注明。

```matlab
cd('C:\path\to\CO2_energy_storage')
addpath('CCES_CHP_Simulink/src/ode');
design_sweep_multi        % 7×5×5 = 175 点，写 data/design_sweep_multi.csv
```

脚本自带基准回归：若 `gamma2` 偏离 1.659 超过 0.01 会直接 assert 失败，说明 REFPROP 或路径有问题，先修这个再往下走。

期望输出（末尾三行形如）：

```
baseline check: gamma1=1.205 gamma2=1.659 alpha1=2.762 alpha2=4.191
gamma2 range over the sweep : ...
alpha2 range over the sweep : ...
wrote 175 points (0 failed) to .../design_sweep_multi.csv
```

### Step 2 · 图件重制

**2a. Fig.1 系统流程图** —— drawio 源文件里是旧值，先改再导出：

| 位置（`CCES_CHP_Simulink/output/CCES_CHP_cycle.drawio`） | 旧 | 新 |
|---|---|---|
| `params_text` 文本框 | `β₁=1.23 β₂=2.31` | `γ₁=1.205 γ₂=1.659` |
| `params_text` 文本框 | `HPT=6228 m³` | `HPT=1280 m³ (943 t)` |
| `params_text` 文本框 | `压缩机功率: 9.55 MW_e (C1 4.90 + C2 4.65)` | `压缩机功率: 9.74 MW_e` |
| `params_text` 文本框 | `透平功率: 10.12 MW_e (T1 5.49 + T2 4.63)` | `透平功率: 9.62 MW_e` |
| `c1_label` / `c2_label` / `t1_label` / `t2_label` | 4.90 / 4.65 / 5.49 / 4.63 MW | 按新设计点重算后填（两级分配≈各半，请以 `cces_design_point` 的实际分级功为准） |
| `hpt_label` | `6228 m³` | `1280 m³` |
| `state_table` | 13 行状态点 | 用新设计点重算后覆盖（REFPROP 逐点） |

导出（需装 draw.io Desktop，`winget install JGraph.Draw`）：

```powershell
& "C:\Program Files\draw.io\draw.io.exe" --export --format png --scale 3 `
  --output "CCES_CHP_Simulink\output\CCES_CHP_cycle.png" `
  "CCES_CHP_Simulink\output\CCES_CHP_cycle.drawio"
```

导出后正文里的 `![Fig. 1](../CCES_CHP_Simulink/output/CCES_CHP_cycle.png)` 自动生效，记得删掉它上面那行 `<!-- TODO(Fig.1) ... -->` 注释。

**2b. Fig.4 / Fig.5 去掉图内标题、β→γ** —— 在 `CCES_CHP_Analysis/PaperReproduction.m`：

- 第 **461** 行：`title('Charging-Heating Feasibility Domain (Fig.3, slope +\beta_1)', ...)` → 整行删除
- 第 **510** 行：`title('Discharging-Heating Feasibility Domain (Fig.4, slope -\beta_2)', ...)` → 整行删除
- 同两个函数里，凡 `\beta_1` / `\beta_2` 的坐标轴或图例标签改为 `\gamma_1` / `\gamma_2`（期刊图内不应出现图号）

```matlab
cd CCES_CHP_Analysis; PaperReproduction     % 重出 14 张图
```

**2c.（可选）新增 Fig.9 / Fig.10** —— 已由 Python 生成，若决定放进正文直接引用：

- `ML_EnergyStorage_Optimization/data/fig_ml_models.png`（分类器 CV 对比）
- `ML_EnergyStorage_Optimization/data/fig_shap.png`（SHAP）
- `ML_EnergyStorage_Optimization/data/fig_dispatch_optimal.png`（三种策略功率与 SOC）
- `ML_EnergyStorage_Optimization/data/fig_lambda_sweep.png`（λ 敏感性）

### Step 3 · Python 复算（约 3 min）

```bash
python -m pip install --target .pylibs pandas scikit-learn xgboost matplotlib scipy
# Windows PowerShell:
$env:PYTHONPATH = "$PWD\.pylibs"; $env:MPLBACKEND = "Agg"; $env:MPLCONFIGDIR = "$PWD\.mplcache"
$env:JOBLIB_MULTIPROCESSING = "0"     # 沙箱/受限环境下必须，否则 joblib 起进程会失败

python ML_EnergyStorage_Optimization/src/ml_extension.py
python ML_EnergyStorage_Optimization/src/dispatch_optimal_milp.py
python ML_EnergyStorage_Optimization/src/dispatch_optimization.py   # 指标已修正
```

期望值（本机实测，用作对照）：

| 项 | 期望 |
|---|---|
| XGB / MLP / RF / HGB / ET / DT / LogReg | 100.00 / 99.74 / 99.96 / 99.96 / 99.90 / 96.22 / 82.01（%） |
| 消融：含 / 不含 SOC_gas | 100.00 / 90.68（−9.32 pp） |
| SHAP 占比 | 41.5 / 25.1 / 14.7 / 13.0 / 5.8（%） |
| LP / 规则 / 网格 目标值 | 82.868 / 85.876（+3.63%）/ 86.041（+3.83%） |
| λ=1 时供热 | 44.00 / 48.00 / 52.00 MWh |
| 修正后放电小时数 | 规则 9 h、ML 16 h（任意功率小时 17 / 24） |

### Step 4 · 改正文

按 §3 的 A–H 块替换。每块都给了**定位锚点**（原文的首句/末句）与**可直接粘贴的新文本**。建议顺序：A → B → C → D → E → F → G → **H 最后做，并按表内降序**。

### Step 5 · 校验（改完必做）

```bash
python - <<'PY'
import re, pathlib
p = pathlib.Path("ML_EnergyStorage_Optimization/paper_manuscript.md")
t = p.read_text(encoding="utf-8")
nums = re.findall(r"!\[Fig\. (\d)\]", t)
caps = re.findall(r"\*\*Fig\. (\d)\.", t)
print("images", nums, "\ncaptions", caps)
print("sequential:", nums == [str(i) for i in range(1, len(nums)+1)])
for stale in ["98.58", "0.9964", "0.4545", "17 to 24 hours", "+5.2%", "Table 6. 24-hour"]:
    print(f"stale '{stale}':", t.count(stale))
PY
```

要求：`sequential: True`；`98.58`、`0.9964`、`0.4545` 应为 0（若 §3 已全部替换）；`17 to 24 hours` 与 `+5.2%` 只应出现在已改写的新句子里。

### Step 6 · 提交

```bash
git add -A
git commit -m "docs(paper): journal revision — CV metrics, SHAP ranking, corrected discharge metric, LP optimality gap, lambda sweep"
git push
```

---

## 3. 正文替换块（可直接粘贴）

### A. §4.2 表 3 与后一段

**锚点**：从 `**Table 3. XGBoost feature importance ranking.**` 起，到 `...becomes the second most important feature once the limit is included.` 止，整段替换为：

```markdown
**Table 3. TreeSHAP attribution of the XGBoost classifier.**

| Feature | Mean abs SHAP | Share (%) | Physical interpretation |
|---------|-------------|-----------|------------------------|
| SOC_heat_pct | 4.37 | 41.5 | HTV thermal state — sets the constraint intercept |
| SOC_gas_pct | 2.64 | 25.1 | HPT liquid inventory — bounds power at the window ends |
| W_MW | 1.55 | 14.7 | Power setpoint — position along the constraint line |
| mode | 1.37 | 13.0 | Charge vs discharge — selects the constraint direction |
| Q_MW | 0.61 | 5.8 | Heat setpoint — vertical position in the domain |
| γ₁, γ₂, α₁, α₂ | 0.00 | 0.0 | Constant across the training set (fixed T_turb) |

Gain-based importance ranks the operating mode first (45.5 % in an earlier
evaluation), but gain rewards features that are split often and high-cardinality
binary splits are cheap to exploit. TreeSHAP measures the marginal contribution
to the prediction and instead ranks the two storage states first (41.5 % and
25.1 %), which matches the analytical structure of Section 3: the heat state sets
the intercept and the gas state bounds the power. The gas-side feature is the
decisive test of how much physics the constraint set carries: removing it from
the feature vector lowers the cross-validated accuracy from 100.00 % to 90.68 %
(a 9.3 percentage-point drop), whereas under the pre-revision constraint set it
contributed 0.0015 of the gain importance and changed nothing.
```

### B. §4.5 表 4 与后一段

**锚点**：从 `**Table 4. ML model performance summary.**` 起，到 `...so its regression is exact.` 止，整段替换为：

```markdown
**Table 4. Model performance under five-fold stratified cross-validation.**

| Model | Task | Metric | Value |
|-------|------|--------|-------|
| XGBoost | Feasibility classification | CV accuracy | **100.00 ± 0.01 %** |
| Random forest (300) | Feasibility classification | CV accuracy | 99.96 ± 0.02 % |
| Histogram gradient boosting | Feasibility classification | CV accuracy | 99.96 ± 0.04 % |
| MLP (128×64×32) | Feasibility classification | CV accuracy | 99.74 ± 0.11 % |
| Extra trees (300) | Feasibility classification | CV accuracy | 99.90 ± 0.04 % |
| Decision tree (depth 6) | Feasibility classification | CV accuracy | 96.22 ± 0.16 % |
| Logistic regression | Feasibility classification | CV accuracy | 82.01 ± 0.04 % |
| XGBoost | W_max regression | R² / RMSE | **1.0000** / 1e-4 MW |
| XGBoost | Q_max regression | R² / RMSE | **1.0000** / < 1e-4 MW |

Three observations follow. First, a linear classifier reaches only 82.01 %, which
is the quantitative statement that the feasible set is a polygon rather than a
half-space: no single hyperplane separates feasible from infeasible operating
points. Second, the two boundary regressors are reproduced exactly rather than
approximately, because W_max and Q_max are deterministic piecewise-linear
functions of the state (Section 3.3–3.4); a tree ensemble resolves them to the
label precision, and the earlier R² = 0.9964 reflected a single train/test split
with a shallower ensemble. Third, the MLP sits 0.26 pp below XGBoost: its smooth
activations round off the corners where the thermal, inventory and equipment
limits intersect.
```

### C. 新增 §5.4（放在 §5.3 的三条 bullet 之后、`---` 之前）

```markdown
### 5.4 Optimality of the grid search

The hour-by-hour policy is greedy: it maximises the instantaneous score without
regard to how the decision changes the state available to later hours. Because
every constraint and the objective are linear in (W, Q) once the mode is fixed by
the sign of the dispatch instruction, the same 24-hour problem can be solved
exactly as a linear programme. We solve it with HiGHS through SciPy, using the
same bounds, the same heat-storage recursion and the same objective, so the LP
value is a valid lower bound on the achievable tracking error.

**Table 5. Optimality gap of the dispatch policies (λ = 0.5).**

| Policy | Objective | Gap vs. LP | Heat (MWh) | Discharge (MWh) | Electrical tracking (%) |
|--------|-----------|-----------|-----------|-----------------|------------------------|
| Rule-based | 85.876 | +3.63 % | 44.00 | 66.6 | 62.8 |
| ML grid search (20×15) | 86.041 | +3.83 % | 46.29 | 66.3 | 62.7 |
| LP optimum | **82.868** | — | 14.74 | 84.3 | 71.0 |

Two results deserve emphasis. The grid search is 3.8 % away from the optimum of
its own objective, and at λ = 0.5 it does not beat the rule-based heuristic on
that objective. The reason is visible in the optimal solution: with electricity
weighted twice as heavily as heat, the LP discharges 84.3 MWh and delivers only
14.7 MWh of heat, i.e. the objective never asked for heat. The 5.2 % heat gain of
the heuristic is therefore not an optimisation result but a side effect of the
surrogate being conservative near the boundary, which preserves storage for later
hours. Section 6.5 turns this into a sensitivity study on λ.
```

### D. §6.2 表 6→7 与观察 1–3

**锚点**：从 `**Table 6. 24-hour dispatch performance comparison.**` 起，到 `...converting otherwise uncovered hours into delivered heat.` 止，整段替换为（表号改成 **7**，因为新增的 §5.4 表占用 Table 5）：

```markdown
**Table 7. 24-hour dispatch performance comparison.**

| Metric | Rule-based | ML-guided | Change |
|--------|-----------|-----------|--------|
| Total charge energy (MWh) | 66.0 | 66.0 | — |
| Total discharge energy (MWh) | 66.6 | 65.0 | −2.4 % |
| Total heat supply (MWh) | 44.0 | **46.3** | **+5.2 %** |
| Hours with active discharge (h) | 9 | **16** | **+78 %** |
| Hours with non-zero power (h) | 17 | 24 | +41 % |
| Terminal SOC_heat (%) | 0.2 | 0.2 | — |
| Electrical dispatch tracking rate (%) | 44.9 | 45.4 | +0.5 pp |

Two metrics are reported because an earlier version of this work conflated them:
"hours with active discharge" counts hours in which the dispatch instruction is a
discharge and the unit delivers positive power (9 → 16), whereas "hours with
non-zero power" also counts charging hours (17 → 24). The 17 → 24 claim in the
conference version referred to the second quantity.

Three observations:

**Observation 1 — Longer active discharge.** The rule-based policy exhausts the
HTV by hour 10 and then tracks only the remaining heat load; the ML-guided policy
keeps a positive discharge in 16 of the hours that call for one. Both policies end
the horizon essentially empty (0.2 %), so the difference is timing rather than a
reserved margin.

**Observation 2 — More heat, at the cost of discharge energy.** Total heat rises
from 44.0 to 46.3 MWh while total discharge falls by 2.4 %. The mechanism is not
an optimal allocation: the surrogate classifies some feasible operating points as
infeasible near the boundary, so the grid search picks lower power than the
analytic domain would allow (for example 0.53 MW instead of 3.68 MW at hour 5),
which leaves thermal energy for later hours. Section 6.5 shows what an explicit
weighting of heat delivers instead.

**Observation 3 — The heuristic is not optimal.** Under the same objective the
LP of Section 5.4 reaches 82.868 against 86.041 for the grid search, and the
rule-based heuristic is closer to the optimum than the grid search is. The
value of the surrogate therefore lies in inference speed and in parameter
generalisation, not in the search itself.
```

### E. §6.3 整节替换

**锚点**：从 `Analysis of the hour-by-hour dispatch decisions reveals three distinct strategies the ML optimization employs:` 起，到 `...rather than a designed margin.` 止，替换为：

```markdown
The hour-by-hour decisions reveal three mechanisms, and it matters which of them
is an optimisation result and which is an artefact of the surrogate.

#### Mechanism 1: Conservative boundary estimates

Near the constraint boundary the tree ensemble predicts infeasibility for points
that the analytic domain admits. Between hours 5 and 9 it selects 0.53 MW where
the analytic domain allows up to 3.7 MW; at hour 17 it selects 6.8 MW against an
admissible 10 MW. Every selected point lies inside the physical domain (0 of 24
violations were found on re-checking), so the trajectory is feasible, but the
conservatism acts as an implicit storage margin and is the actual source of the
5.2 % heat gain. A safety margin applied to the analytic constraint would produce
the same effect at no modelling cost, which is why the conference version's
attribution to "dynamic electric–thermal allocation" is withdrawn here.

#### Mechanism 2: Derating for duration

Because a fixed heat inventory is drained at γ₂W + Q, halving the power roughly
doubles the duration at which the unit can still deliver. Both the rule-based and
the ML-guided policies derate, but the rule-based policy derates only after the
HTV is nearly empty, whereas the surrogate derates early.

#### Mechanism 3: Charging sized to the next discharge segment

The ML-guided policy charges at hours 12–15 and 20–23, immediately before the
evening peak, and does not over-charge: the terminal SOC is 0.2 %. Over-charging
is excluded by the SOC upper bound, so this is a constraint property rather than
an optimisation insight.

The physical upper bound is unchanged: a full-power, full-heat discharge lasts
about 5.2 h, and the longer coverage is obtained by derating and by recharging,
not by violating the energy capacity.
```

### F. 新增 §6.5 + 原 §6.5 改号为 §6.6

在 `### 6.5 Discussion` 之前插入下面内容，并把原 `### 6.5 Discussion` 改为 `### 6.6 Discussion`（其下 6.5.1–6.5.4 四个小标题同步改为 6.6.1–6.6.4）：

```markdown
### 6.5 Sensitivity to the electric–thermal weight

The objective in Section 5.1 weights the electrical and thermal deviations by
λ = 0.5 without justification. Sweeping λ exposes how much of the reported
behaviour is a property of the system and how much is a property of the weight.

**Table 10. Delivered heat (MWh) versus the heat weight λ.**

| λ | Rule-based | ML grid search | LP optimum |
|---|-----------|----------------|-----------|
| 0 | 44.00 | 0.00 | 14.74 |
| 0.25 | 44.00 | 44.29 | 14.74 |
| 0.50 | 44.00 | 46.29 | 14.74 |
| 1.0 | 44.00 | 48.00 | 52.00 |
| 2.0 | 44.00 | 48.57 | 52.00 |
| 5.0 | 44.00 | 48.57 | 52.00 |

Three conclusions follow. The rule-based policy is insensitive to λ because it
never trades power against heat. The ML-guided policy improves monotonically up
to λ = 2 and saturates at 48.6 MWh. The LP optimum saturates at 52.0 MWh, 18 %
above the rule-based baseline, which is the headroom that a heat-aware objective
can actually capture. For λ ≥ 1 the optimum is also unchanged in the range
10–100 %, so a planner who wants maximum heat should weight it at least as
heavily as electricity; at λ = 0.5 the same optimum delivers 14.7 MWh, i.e. the
weight, not the physics, decides the outcome. Heat supply should therefore be
stated as a function of λ rather than as a single number.
```

### G. 摘要与结论

**G1. 摘要**（锚点：正文第 13 行整段 `Compressed carbon dioxide energy storage (CCES), as an emerging...` 到 `...rather than expanding the domain.`；整段替换为下面约 235 词的版本，Applied Energy 上限 250 词）：

```markdown
Compressed carbon dioxide energy storage with combined heat and power (CCES-CHP)
couples electrical, thermal and mass flows, so its operational feasibility domain
is a polygon in the power–heat plane whose position shifts with two state
variables. Building that domain from thermophysical property calls is too slow for
real-time dispatch. Surrogates are therefore trained on 38,720 samples generated
with REFPROP from a two-stage transcritical CO₂ cycle, using dimensionless
couplings γ₁/γ₂ and α₁/α₂ together with a dual state-of-charge formulation in
which the CO₂ liquid inventory, not the tank pressure, bounds the instantaneous
power. Under five-fold stratified cross-validation XGBoost classifies feasibility
at 100.00 ± 0.01 % and an MLP at 99.74 ± 0.11 %, against 82.01 % for a linear
classifier, and reproduces both domain boundaries exactly (R² = 1.0000). TreeSHAP
attributes 41.5 % of the prediction to the heat state and 25.1 % to the gas
inventory; removing the gas state costs 9.3 percentage points, confirming that the
inventory constraint is physically active. In a 24-hour case study the
surrogate-guided dispatch raises delivered heat from 44.0 to 46.3 MWh (+5.2 %) and
the hours with active discharge from 9 to 16, but an exact linear-programming
benchmark of the same objective places it 3.8 % from the optimum. A sweep of the
heat weight locates the genuine headroom: 48.6 MWh for the heuristic and 52.0 MWh
for the optimum, 18 % above the rule-based baseline. Turbine inlet temperature
raises efficiency and discharge duration rather than expanding the domain.
```

**G2. 结论 2**（锚点：`XGBoost and MLP models trained on 38,720 REFPROP-based samples reach 100% and 98.58% accuracy`）：改为

```markdown
2. XGBoost and MLP models trained on 38,720 REFPROP-based samples reach
   100.00 ± 0.01 % and 99.74 ± 0.11 % accuracy in feasibility classification
   under five-fold stratified cross-validation, against 82.01 % for a linear
   classifier; boundary regression reproduces W_max and Q_max exactly
   (R² = 1.0000). TreeSHAP attributes 41.5 % and 25.1 % of the prediction to the
   heat and gas states, and dropping the gas-side feature costs 9.3 percentage
   points, confirming that the dual-SOC coupling is physically active.
```

**G3. 结论 3**（锚点：`ML-optimized 24-hour dispatch extends discharge coverage from 17 to 24 hours (+41%)`）：改为

```markdown
3. ML-guided 24-hour dispatch raises delivered heat from 44.0 to 46.3 MWh
   (+5.2 %) and the number of hours with active discharge from 9 to 16, at the
   cost of 2.4 % less discharged energy and with the same terminal SOC (0.2 %).
   The gain stems from the conservatism of the surrogate near the boundary rather
   than from an optimal allocation: against an exact LP optimum of the same
   objective the grid search is 3.8 % worse and the rule-based heuristic is
   slightly better, so the surrogate's value lies in inference speed and
   parameter generalisation. A λ-sweep locates the genuine headroom: 48.6 MWh for
   the heuristic and 52.0 MWh for the optimum when heat is weighted at least as
   heavily as electricity.
```

### H. 既有表号顺移（按降序执行）

新增的 §5.4 表占用 Table 5，因此 §6 的四张表各后移一位。**从大到小**做，否则会连环覆盖：

| 顺序 | 原文 | 改为 |
|---|---|---|
| 1 | `**Table 8. Integrated feasible domain area at different SOC levels (MW²).**` | `**Table 9. ...**` |
| 2 | `**Table 7. Effect of turbine inlet temperature (REFPROP evaluation).**` | `**Table 8. ...**` |
| 3 | `**Table 5. 24-hour load and wind power data.**` | `**Table 6. ...**` |
| 4 | `presented in Fig. 7 and Table 6.`（§6.2 首句） | `presented in Fig. 7 and Table 7.` |

改完后表号序列应为：1、2、3、4、**5（新增·optimality gap）**、6（负荷数据）、7（调度对比）、8（温度效应）、9（可行域面积）、**10（新增·λ 敏感性）**、A1–A3。D 块里已把调度表写成 Table 7，不要再动。

---

## 4. 经济性分析：需要你填的参数

我下一步写 `src/economics.py`（LCOE、套利收益、回收期、λ 与电价的二维敏感性），需要下表数值。没有项目数据就写"用文献默认"，我按 2024–2025 年 CCES/CAES 文献取中位值并在正文标注来源区间。

| 参数 | 符号 | 你的值 | 备注 |
|---|---|---|---|
| 单位投资（储电侧） | $C_{cap}$ | | $/kW 或 $/kWh，注明口径 |
| 单位投资（储热侧） | $C_{th}$ | | $/kWh_th |
| 年运维费率 | $f_{O\&M}$ | | 占投资比例 /yr |
| 折现率 | $r$ | | |
| 系统寿命 | $N$ | | yr |
| 分时电价（峰/平/谷） | $p_e$ | | $/MWh，最好给 24 h 曲线 |
| 上网/售电电价 | $p_{sell}$ | | $/MWh |
| 热价 | $p_h$ | | $/MWh_th |
| 年运行天数 | — | | 或供暖季天数 |
| 碳价（可选） | $p_{CO_2}$ | | $/t |

---

## 5. 已知风险与说明

1. **MATLAB 侧改动我无法在此运行**：`cces_design_point.m` 与 `design_sweep_multi.m` 只做了静态检查。脚本第一件事就是基准回归（γ₂=1.659），跑不过就说明改动有问题，别继续。
2. **P_HPT 缩放是近似**：高压侧 6.90/6.85/6.65/6.60/6.50 MPa 按 `P_HPT/6.80` 等比缩放，低压侧固定。正文必须写成敏感性分析的近似假设，不能写成"重新设计"。
3. **Fig.1 的 state_table** 需要 REFPROP 逐点重算，我没法代算；`params_text` 里的四个功率也需要按 `cces_design_point` 的分级值填，不要用旧图里的 4.90/4.65/5.49/4.63。
4. **λ 的经济含义**：λ 目前是纯数学权重。若把电价写进目标函数，λ 应等于 $p_h/p_e$（同一时间尺度下），这句话建议写进 §6.5 结尾，能把"任意权重"的批评堵住。
5. 我这边的 `.pylibs`（353 MB）与 `.mplcache` 都已 gitignore，不会进仓库。
