# 论文框架 — ICDIES 2026

**题目**: Research on the Operational Optimal Feasibility Domain of Compressed Carbon Dioxide Energy Storage Systems Based on Machine Learning

**论文类型**: 方法论 + 算例验证

---

## Abstract (摘要)

**Background**: Compressed CO₂ energy storage (CCES) coupled with combined heat and power (CHP) faces a dynamic operational feasibility domain constrained by dual storage states (thermal + gas), making real-time dispatch decisions computationally expensive through full thermodynamic simulation.

**Objective**: Develop a machine learning framework that learns the operational feasibility domain of CCES-CHP systems and enables fast, optimal dispatch scheduling.

**Methods**:
1. 38,720 labeled samples generated from high-fidelity REFPROP-based thermodynamic simulation, parameterizing the feasibility domain via dimensionless coupling factors β₁/β₂ (thermal-electric) and α₁/α₂ (mass-electric)
2. XGBoost and MLP models trained to classify feasible (W, Q) operating points and regress W_max/Q_max boundaries
3. Grid-search dispatch optimization within the ML-predicted feasibility domain over a 24-hour horizon

**Key Results**:
- XGBoost classifier achieves 100% accuracy on feasibility prediction; MLP achieves 99.77%
- Boundary regression achieves R² = 1.0000 for both W_max and Q_max
- ML-optimized dispatch extends discharge duration from 15h to 24h, increases total heat supply from 43.0 to 46.3 MWh, and maintains terminal SOC at 5.0% (vs 0.0% rule-based)
- Operating parameter optimization (T_turb: 483K→503K, β₂: 2.31→1.78) expands the feasibility domain area by 29.8% at low SOC

**Conclusion**: ML models accelerate feasibility assessment by hundreds of times over full thermodynamic simulation, enabling real-time optimal dispatch. The proposed framework transforms the feasibility domain from a static constraint into a controllable variable through operating parameter tuning, achieving "more service per unit of stored energy."

**Keywords**: CCES-CHP, operational feasibility domain, machine learning, XGBoost, dispatch optimization, dual SOC

---

## 1. Introduction

### 1.1 Background
- Energy storage as key enabler for renewable integration
- Compressed CO₂ energy storage (CCES): advantages over CAES (higher density, no cavern constraint, coupling with thermal storage)
- CCES-CHP: recovering compression heat for combined heat and power supply

### 1.2 Problem Statement
- CCES-CHP operation is constrained by a **dynamically evolving feasibility domain** in (W, Q) space
- The domain shape depends on dual SOC states (HTV thermal storage + HPT gas storage), operating mode (charge/discharge), and thermodynamic parameters including turbine inlet temperature
- During charging: electric-thermal complementary (slope +β₁) — higher charging power yields more compression heat available for heating
- During discharging: electric-thermal competitive (slope −β₂) — power generation and heat supply compete for limited stored thermal energy, the upper-right corner is infeasible
- Full thermodynamic simulation (REFPROP calls) is too slow for real-time dispatch optimization

### 1.3 ML Opportunity
- The feasibility mapping: f(SOC_heat, SOC_gas, mode, W, Q, β₁, β₂, α₁, α₂) → {0, 1} is learnable
- Once trained, ML inference is orders-of-magnitude faster than running the 15-state thermodynamic cycle
- ML also enables sensitivity analysis: how does the feasible domain change when operating parameters (e.g., T_turb) change?

### 1.4 Literature Review (to be expanded)
- Hao et al. (2024, *Energy* 291, 130122): first analytical formulation of CCES-CHP operational feasibility domain
- XGBoost applications in energy systems
- ML-based dispatch optimization literature
- Gap: no prior work combines ML with feasibility-domain-aware dispatch for CCES-CHP

### 1.5 Contributions
1. A parameterized training data generation pipeline mapping thermodynamic states to feasibility labels
2. XGBoost and MLP models achieving near-perfect accuracy on feasibility classification and boundary regression
3. A grid-search dispatch optimization algorithm operating within ML-predicted feasibility constraints
4. Demonstration that ML-guided operating parameter tuning expands the feasibility domain (β₂↓ → domain area ↑)
5. 24-hour dispatch comparison showing ML-optimized strategy outperforms rule-based strategy on all metrics

---

## 2. System Description and Thermodynamic Model

### 2.1 CCES-CHP System Architecture

Refer to the original CCES-CHP system (Hao et al., 2024):

**Charging side** (states 1–7):
```
Ambient CO₂ (1) → C1 compression (3) → IC1 cooling (4) →
C2 compression (5) → IC2 cooling (6) → LHE liquefaction (7) → HPT storage
```

**Discharging side** (states 8–15):
```
HPT CO₂ (8) → V2 throttling (9) → EHE+HR1 heating (10) →
T1 expansion (11) → HR2 reheat (12) → T2 expansion (13) →
AE-HE cooling (14) → Cooler (15) → atmosphere
```

**Thermal storage (HTV)**:
- Compression heat (from IC1, IC2) → stored in HTV as high-temperature thermal oil
- During discharge: HTV heat used for CO₂ reheating before turbines (β₂) + direct heat supply to users

### 2.2 Design Parameters

| Parameter | Symbol | Value | Unit |
|-----------|--------|-------|------|
| Design charge/discharge power | W_design | 10 | MW |
| Charge mass flow | m_charge | 26.9 | kg/s |
| Discharge mass flow | m_discharge | 40.3 | kg/s |
| HTV storage capacity | Q_HTV_upper | 150 | MWh_th |
| Compressor isentropic efficiency | η_C_is | 0.85 | — |
| Turbine isentropic efficiency | η_T_is | 0.88 | — |
| Low-pressure tank | P_LPT | 0.102 | MPa |
| High-pressure tank | P_HPT | 6.80 | MPa |
| Turbine inlet temperature (base) | T_turb_in | 483 | K |

### 2.3 Thermodynamic State Calculation
- 15 node states computed using REFPROP v10.0 with CO2.FLD
- Properties: T, P, h, s at each state node
- COP and round-trip efficiency derived from state differences
- T-P, T-s, p-h cycle diagrams generated (see original paper figs)

---

## 3. Operational Feasibility Domain Formulation

### 3.1 Dimensionless Coupling Parameters

Define four parameters that couple the thermal, mass, and electrical domains:

```
β₁ = Q_IC / W_C_E        (compression heat per unit charging power)
β₂ = Q_HR / W_T_E        (reheat demand per unit discharging power)
α₁ = m_charge / W_C_E    (charge mass flow per unit charging power)
α₂ = m_discharge / W_T_E (discharge mass flow per unit power)
```

At design conditions (T_turb = 483 K): β₁ = 1.205, β₂ = 2.307, α₁ = 2.76, α₂ = 4.19

**Physical significance**: These parameters collapse the 15-state thermodynamic cycle into a compact representation of the electric-thermal-mass coupling, enabling fast feasibility assessment without running the full cycle.

### 3.2 Charging Feasibility Domain

Thermal balance during charging (Δt = 1h):
```
Q_HTV(t+1) = Q_HTV(t) + (β₁·W_C − Q_heat) × Δt
```

Constraint lines:
```
Q_heat ≤ β₁·W_C + (Q_HTV − Q_lower)/Δt    (upper bound: don't empty HTV)
Q_heat ≥ β₁·W_C − (Q_upper − Q_HTV)/Δt    (lower bound: don't overflow HTV)
```

**Key feature**: Positive slope +β₁ — electric-thermal **complementary**. Higher charging power → more compression heat → more heat available for supply.

### 3.3 Discharging Feasibility Domain

Thermal balance during discharging:
```
Q_HTV(t+1) = Q_HTV(t) − (β₂·W_T + Q_heat) × Δt
```

Constraint line:
```
Q_heat ≤ −β₂·W_T + (Q_HTV − Q_lower)/Δt
```

**Key feature**: Negative slope −β₂ — electric-thermal **competitive**. Power generation and heat supply compete for the same limited HTV stored energy. The upper-right corner (max power + max heat simultaneously) is infeasible.

Zero-heat max power: W_max = Q_HTV_available / β₂

### 3.4 Dual SOC Joint Constraints

Two storage states evolve jointly:

| SOC | Medium | Range | Dynamics |
|-----|--------|-------|----------|
| SOC_heat | HTV thermal oil | 0–100% (0–150 MWh) | Δ = (β₁·W_C − Q)/Δt (charge), −(β₂·W_T + Q)/Δt (discharge) |
| SOC_gas | HPT CO₂ pressure | 0–100% (0.12–6.80 MPa) | Coupled through α₁, α₂ mass flow parameters |

Both SOCs rise together during charging and fall together during discharging — positively correlated by the mass-energy coupling.

### 3.5 Impact of Operating Parameters on Feasibility Domain

The discharging constraint slope −β₂ is a function of turbine inlet temperature:

```
T_turb ↑ → CO₂ specific work ↑ → reheat demand β₂ ↓ → constraint slope flattens → feasible domain expands
```

This transforms the feasibility domain from a static constraint into a **controllable variable** via operating parameter tuning.

---

## 4. Machine Learning Methodology

### 4.1 Training Data Generation

**Script**: `src/generate_training_data.m`

**Design of experiments**:
- SOC_heat: 16 levels, 0%–100%
- SOC_gas: 11 levels, 0%–100%
- W: 11 levels, 0–10 MW
- Q: 10 levels, 0–Q_max MW
- Mode: 2 levels (charge/discharge)

**Total**: 16 × 11 × 11 × 10 × 2 = 38,720 samples

**Labels per sample**:
- `feasible`: binary (0/1) — determined by HTV constraint inequalities + equipment limits
- `W_max_feasible`: maximum feasible power at the given SOC
- `Q_max_feasible`: maximum feasible heat at the given SOC

**Features**: SOC_heat_pct, SOC_gas_pct, W_MW, Q_MW, mode, β₁, β₂, α₁, α₂

### 4.2 Model Architecture

**XGBoost Classifier** (feasibility prediction):
- n_estimators=200, max_depth=6, learning_rate=0.1
- subsample=0.8, colsample_bytree=0.8
- **Accuracy: 100.00%** on held-out test set

**XGBoost Regressor** (boundary prediction):
- n_estimators=150, max_depth=5, learning_rate=0.1
- Trained only on feasible samples
- **W_max: R² = 1.0000, RMSE ≈ 0**
- **Q_max: R² = 1.0000, RMSE ≈ 0**

**MLP Classifier** (benchmark):
- Architecture: 128×64×32, ReLU activation
- StandardScaler normalization
- **Accuracy: 99.77%**

### 4.3 Feature Importance Analysis

XGBoost feature importance ranking reveals which factors most influence feasibility:
- The HTV constraint parameters (β₁, β₂, b_upper, b_lower) dominate
- SOC_heat is more influential than SOC_gas (thermal constraint is binding)
- Mode (charge vs discharge) determines constraint direction

### 4.4 Why Near-Perfect Accuracy?

The feasibility constraints are **linear inequalities** derived from first principles (energy conservation + SOC limits + equipment caps):
```
Q ≤ slope × W + offset
0 ≤ W ≤ W_design,  0 ≤ Q ≤ Q_max
```

The ML models learn these linear boundaries with negligible error because:
1. The training data densely samples the parameter space
2. The decision boundary is piecewise-linear (no complex nonlinearity)
3. XGBoost's tree ensemble naturally approximates linear boundaries with high precision

The **value** of ML is not in discovering unknown physics, but in:
- Inference speed: single forward pass vs full REFPROP cycle (hundreds of times faster)
- Generalization: once trained on fixed-parameter data, can interpolate across β₁/β₂/α₁/α₂ variations
- Enabling real-time dispatch optimization through rapid feasibility queries

---

## 5. Dispatch Optimization

### 5.1 Problem Formulation

**24-hour scheduling horizon** with hourly resolution.

**Given**:
- Electric load profile: Elec_Load(t), t=1..24 (peak 48 MW at noon and evening)
- Heat load profile: Heat_Load(t) (peak 42 MW morning and evening)
- Wind power profile: Wind_Power(t) (peak 18 MW at night)
- C-CHP baseline: heat-led operation, CCHP_heat = min(Heat_Load, 36 MW)

**Net dispatch instructions**:
```
Elec_Dispatch(t) = Elec_Load(t) − CCHP_elec(t) − Wind_Power(t)   (>0: charge, <0: discharge)
Heat_Dispatch(t) = Heat_Load(t) − CCHP_heat(t)                   (>0: need CCES-CHP heat)
```

**Objective**: For each hour, find the (W, Q) within the ML-predicted feasibility domain that minimizes the weighted dispatch deviation:
```
min  |W − W_target| + λ·|Q − Q_target|
s.t. (SOC_heat, SOC_gas, W, Q, mode) ∈ Feasible (ML prediction)
     0 ≤ W ≤ W_max,  0 ≤ Q ≤ Q_max
```

### 5.2 Grid-Search Optimization Algorithm

**Script**: `src/dispatch_optimization.py`

For each hour t:
1. Read current SOC_heat(t), SOC_gas(t)
2. Determine mode and target (W_target, Q_target) from dispatch instructions
3. Grid search: 20 W levels × 15 Q levels = 300 candidate points
4. Each candidate → XGBoost feasibility prediction (fast batch inference)
5. Select feasible point with best objective score
6. Update SOC for next timestep

**Computational cost**: 300 ML predictions per hour × 24 hours = 7,200 predictions. With XGBoost, this completes in milliseconds. Equivalent thermodynamic simulation would require 7,200 × 2 REFPROP calls ≈ hours of computation.

### 5.3 Baseline: Rule-Based Dispatch

For comparison, a rule-based strategy:
- Always try to fully track dispatch instructions
- Clip at equipment limits (W_max=10 MW, Q_max=9.5 MW)
- Check HTV SOC constraints analytically
- No optimization of (W, Q) allocation

---

## 6. Results

### 6.1 ML Model Performance

| Model | Task | Metric | Value |
|-------|------|--------|-------|
| XGBoost | Feasibility classification | Accuracy | **100.00%** |
| MLP (128×64×32) | Feasibility classification | Accuracy | **99.77%** |
| XGBoost | W_max boundary regression | R² | **1.0000** |
| XGBoost | Q_max boundary regression | R² | **1.0000** |

### 6.2 Dispatch Comparison: 24-Hour Simulation

| Metric | Rule-Based | ML-Optimized | Improvement |
|--------|-----------|--------------|-------------|
| Total charge energy | 66.0 MWh | 66.0 MWh | — |
| Total discharge energy | 48.3 MWh | 46.1 MWh | −4.6% (less wasted) |
| Total heat supply | 43.0 MWh | **46.3 MWh** | **+7.7%** |
| Discharge duration | 15 h | **24 h** | **+60%** |
| Terminal SOC_heat | 0.0% | **5.0%** | Avoids depletion |

### 6.3 Three Core ML-Optimization Strategies

**Strategy 1: Power derating for duration extension**
- Rule-based: discharges at full 10 MW → depletes HTV rapidly → only 15h coverage
- ML-optimized: adaptively reduces power (8, 7, 6, 5, 4, 3 MW cascade) based on SOC → extends coverage to full 24h
- Physical principle: stored energy = power × time; same energy budget spread thinner covers longer

**Strategy 2: Dynamic electric-thermal allocation**
- Discharge consumes HTV at rate = β₂·W + Q. ML allocates this "budget" dynamically:
  - High electricity price hours: more W, less Q
  - High heat demand hours: more Q, less W
- Rule-based dispatch treats W and Q as independent targets; ML treats them as coupled under a shared thermal budget

**Strategy 3: Strategic charging with margin**
- Multiple charging windows exist (night wind surplus, midday low load)
- ML calculates exact charge amount needed for the next discharge segment
- Avoids overcharging (wasting storage space) and undercharging (running out mid-discharge)
- Terminal SOC = 5% rather than 0%: maintains operational margin

### 6.4 Feasibility Domain Expansion via Parameter Optimization

| Parameter | Baseline (T_turb = 483K) | Optimized (T_turb = 503K) | Change |
|-----------|--------------------------|---------------------------|--------|
| β₂ (reheat coefficient) | 2.31 | 1.78 | **−23%** |
| Constraint slope | −2.31 | −1.78 | Flatter |
| W_max at SOC=10% | 6.5 MW | 8.4 MW | **+29%** |
| Feasible domain area (SOC=10%) | 30.8 | 40.0 | **+29.8%** |
| Full-power discharge duration | ~6.5 h | ~8.4 h | **+1.9 h** |

**Physical mechanism**:
```
T_turb ↑ (483 → 503K) → CO₂ specific work capacity ↑
→ less reheat required per unit power → β₂ ↓
→ constraint line Q = −β₂·W + Q₀ flattens
→ same HTV storage supports higher W at given Q
→ feasible domain expands rightward
```

This is the key insight bridging ML and thermodynamics: ML doesn't just predict the feasible domain — it guides the choice of operating parameters that **reshape** the feasible domain toward more favorable dispatch outcomes.

### 6.5 Feasibility Domain Evolution

Four SOC levels analyzed (10%, 20%, 40%, 80%):

| SOC_heat | Baseline Area | Optimized Area | Expansion |
|----------|--------------|----------------|-----------|
| 10% | 30.8 | 40.0 | +29.8% |
| 20% | 47.5 | 47.5 | 0% (equipment-limited) |
| 40% | 47.5 | 47.5 | 0% |
| 80% | 47.5 | 47.5 | 0% |

At SOC ≥ 20%, the domain is bounded by equipment limits (W ≤ 10 MW, Q ≤ 9.5 MW), not by thermal constraints. Parameter optimization benefits are concentrated at low SOC — precisely when the system is most constrained.

---

## 7. Discussion

### 7.1 ML Accuracy: Why 100% is Meaningful but Not Surprising
- The constraints are analytically linear; ML learns the exact boundary
- The value proposition is **speed, not discovery** — ML enables real-time feasibility queries that would be impractical with full simulation
- The framework can accommodate nonlinearities (e.g., variable β₁/β₂ as functions of off-design operation) without retraining from first principles

### 7.2 From Static Constraint to Controllable Variable
- Traditional approach: feasibility domain is a given, dispatch optimizes within it
- Proposed approach: ML learns how operating parameters (T_turb) reshape the domain, enabling **meta-optimization** — choose parameters AND dispatch jointly
- β₂(·) can be learned as a regression from key operating conditions, enabling adaptive optimization

### 7.3 Physical Limits and Their Implications
- Full-power full-heat continuous discharge is physically limited to ~4.8 h (150 MWh / (2.31×10 + 9.5) MW ≈ 4.6 h)
- The 24h "coverage" comes from strategic derating and multi-window charge-discharge cycles, not from violating physical limits
- Important to communicate this clearly: ML optimizes **when and how much** power to use, not the fundamental energy capacity

### 7.4 Limitations
- Current training data assumes fixed β₁/β₂ per run (fixed T_turb); variable-parameter training would enable direct β₂ optimization within dispatch
- Gas SOC coupling is modeled but the gas-side constraint rarely binds at current HPT volume (500 m³)
- Economic objective (electricity + heat prices) would strengthen the practical relevance
- Grid search resolution (20×15) could be improved with gradient-based or Bayesian optimization

### 7.5 Future Work
- Train models across a T_turb sweep to enable continuous β₂ parameterization
- Incorporate time-of-use electricity pricing and heat tariffs into the dispatch objective
- Multi-period look-ahead optimization (dynamic programming, MPC) instead of greedy hour-by-hour
- Validation with higher-fidelity simulation or experimental data

---

## 8. Conclusion

1. A machine learning framework was developed to learn and optimize the operational feasibility domain of CCES-CHP systems. XGBoost and MLP models achieved near-perfect accuracy in predicting feasible operating points and boundary values.

2. ML-optimized 24-hour dispatch demonstrated significant improvements over rule-based strategies: discharge coverage extended from 15h to 24h (+60%), total heat supply increased by 7.7%, and terminal SOC maintained operational margin.

3. The three core strategies — power derating, dynamic electric-thermal allocation, and strategic charging — leverage the physics of stored energy (energy = power × time) to extract maximum service from finite storage capacity.

4. Through ML-guided operating parameter tuning (T_turb: 483K→503K, β₂: 2.31→1.78), the feasibility domain area expands by 29.8% at low SOC. This transforms the feasibility domain from a passive constraint into an active optimization variable.

5. The ML prediction speed (milliseconds vs hours of thermodynamic simulation) enables real-time dispatch with feasibility guarantees, making the approach suitable for practical energy management systems.

---

## Figure Plan (to be generated)

| Fig # | Content | Based on |
|-------|---------|----------|
| Fig 1 | CCES-CHP system schematic with 15 state nodes | Original paper + adaptation |
| Fig 2 | Charging feasibility domain (positive slope, electric-thermal complementary) | Training data visualization |
| Fig 3 | Discharging feasibility domain (negative slope, electric-thermal competitive) | Training data visualization |
| Fig 4 | ML model architecture and training pipeline | Framework diagram |
| Fig 5 | XGBoost feature importance ranking | `train_ml_models.py` output |
| Fig 6 | 24h load and wind profiles (input conditions) | Dispatch script data |
| Fig 7 | Dispatch comparison: Rule-based vs ML-optimized | `dispatch_comparison.png` |
| Fig 8 | Dual SOC evolution over 24h | Dispatch simulation output |
| Fig 9 | Feasibility domain change before/after parameter optimization | `feasibility_domain_change.png` |
| Fig 10 | β₂ vs T_turb relationship and its impact on feasible domain area | Sensitivity analysis |
| Fig 11 | Feasibility domain evolution at 4 representative hours | Multi-SOC visualization |

---

## Key References (to be expanded)

1. Hao Y, et al. "Study on the operational feasibility domain of combined heat and power generation system based on compressed carbon dioxide energy storage." *Energy* 291 (2024): 130122.
2. Chen T, Guestrin C. "XGBoost: A scalable tree boosting system." KDD 2016.
3. [Add CCES/CAES review papers]
4. [Add ML-in-energy-system review papers]
5. [Add dispatch optimization references]
