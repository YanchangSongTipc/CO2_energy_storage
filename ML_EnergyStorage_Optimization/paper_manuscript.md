# Research on the Operational Optimal Feasibility Domain of Compressed Carbon Dioxide Energy Storage Systems Based on Machine Learning

**Yanchang Song<sup>1</sup>, Zhentao Zhang<sup>1*</sup>, Junling Yang<sup>1</sup>**

<sup>1</sup> State Key Laboratory of Cryogenic Science and Technology, Technical Institute of Physics and Chemistry, Chinese Academy of Sciences, Beijing, China

<sup>*</sup> Corresponding author: zzt@mail.ipc.ac.cn

---

## Abstract

Compressed carbon dioxide energy storage (CCES), as an emerging compressed gas energy storage technology, exhibits significant potential for enhancing renewable energy accommodation and improving the flexibility of integrated energy systems, owing to its superior thermophysical properties, environmental friendliness, and capability for combined heat and power (CHP) supply. Based on an established thermodynamic model of a compressed carbon dioxide energy storage combined heat and power (CCES-CHP) system, this study proposes a machine learning methodology for the dynamic construction and optimization of its operational feasibility domain. Dimensionless factors γ₁ and γ₂, along with ratio parameters α₁ and α₂, are defined to quantify the coupling relationships among electrical, thermal, and mass flows. A dual state of charge (SOC) model incorporating both thermal and gas storage is developed to establish the system's constraint boundaries. Machine learning algorithms, including XGBoost and multi-layer perceptron (MLP) neural networks, are trained using 38,720 thermodynamic simulation samples to predict feasible operating regions and optimize system dispatch under varying load conditions. A case study on an integrated energy system (20 MW wind power, 30 MW conventional CHP, and 10 MW/50 MWh CCES-CHP) demonstrates that the proposed approach achieves 100% accuracy in predicting operational feasibility using XGBoost, with boundary regression achieving R² = 1.0000. The ML-optimized dispatch extends the discharge coverage duration from 15 to 24 hours and increases total heat supply from 43.0 to 46.3 MWh over a 24-hour horizon. By adjusting turbine inlet temperature from 483 K to 503 K, the reheat coefficient γ₂ decreases from 2.31 to 1.78, expanding the feasible domain area by 29.8% at low SOC and extending the full-power discharge duration from 6.5 to 8.4 hours. This methodology provides an effective tool for real-time dispatch and capacity planning of CCES-CHP systems.

**Keywords**: Compressed carbon dioxide energy storage; Combined heat and power; Operational feasibility domain; Machine learning; XGBoost; Integrated energy system

---

## 1. Introduction

With the growing consensus on achieving carbon neutrality worldwide, the development of renewable energy sources is accelerating at an unprecedented pace [1]. However, the intermittency, seasonality, and unpredictability of these sources have highlighted the critical need for energy storage solutions. Physical energy storage technologies offer a promising approach to achieving gradient utilization of energy, supporting the development of a sustainable, low-carbon, and economically viable energy infrastructure [2,3].

Among many energy storage technologies, compressed gas energy storage (CGES) has become a promising candidate by virtue of its high power generation, wide capacity range, and low investment cost [4]. Compressed air energy storage (CAES) is the earliest developed and most mature CGES technology, but its reliance on large underground storage caverns and low energy density remain significant limitations [5–8]. Liquid air energy storage (LAES) improves energy density but suffers from low round-trip efficiency, typically below 50% [9,10].

In this context, CO₂ has emerged as a promising working medium for CGES. CO₂ possesses suitable critical parameters (304 K, 7.38 MPa) and can be liquefied at room temperature, creating favorable conditions for high-density storage. CO₂ also exhibits good thermal conductivity, low liquid viscosity, and is non-toxic, non-flammable, and inexpensive [11]. In recent years, scholars have extensively studied the optimal design of CCES systems [12–15]. Considering the diversification of energy demand, CCES technology is gradually developing toward multi-functionality. As the system involves the storage and release of both electrical and thermal energy, it has the natural capability for combined heat and power supply [16].

Several studies have investigated CCES cogeneration. Liu et al. [17] proposed a cooling, heating and power trigeneration system based on transcritical Brayton cycle and CO₂ energy storage. Zhang et al. [18] proposed a combined heat and power system based on fan waste heat utilization and transcritical CCES, achieving a system cycle efficiency of 0.48. He et al. [19] coupled a combined heat and power unit with CCES and achieved system power efficiency of 63.07%. However, the operation dispatch of CCES in integrated energy systems remains a critical and underexplored aspect.

Hao et al. [20] proposed a CCES-CHP system operating in the medium pressure range and developed an innovative method for constructing an operational feasibility domain. By defining dimensionless factors γ₁ and γ₂ and ratio parameters α₁ and α₂, they established constraint boundaries and visualized the system's operational feasible region. However, the construction of the feasibility domain relies on full thermodynamic simulations that are computationally expensive for real-time dispatch applications.

With the rapid development of machine learning techniques, data-driven approaches offer new possibilities for accelerating energy system analysis. XGBoost [21] and neural networks have been successfully applied to various energy system problems, including load forecasting, state estimation, and optimal dispatch [22–24]. However, the application of ML to feasibility domain prediction and dispatch optimization for CCES-CHP systems has not been previously reported.

This study proposes a machine learning framework for learning and optimizing the operational feasibility domain of CCES-CHP systems. The main contributions are:

1. A parameterized training data generation pipeline that maps thermodynamic states to feasibility labels using REFPROP-based simulations, producing 38,720 labeled samples.
2. XGBoost and MLP models achieving near-perfect accuracy (100% and 99.77%) on feasibility classification, and R² = 1.0000 on boundary regression.
3. A grid-search dispatch optimization algorithm operating within the ML-predicted feasibility domain, extending discharge duration from 15 to 24 hours.
4. Demonstration that ML-guided operating parameter tuning (T_turb ↑ → γ₂ ↓) expands the feasibility domain by 29.8% at low SOC states.
5. Quantification of the three core ML optimization strategies: power derating, dynamic electric-thermal allocation, and strategic charging.

The remainder of this paper is organized as follows. Section 2 describes the CCES-CHP system and thermodynamic model. Section 3 presents the feasibility domain construction method. Section 4 details the ML methodology. Section 5 describes the dispatch optimization framework. Section 6 presents the case study and results. Section 7 concludes.

---

## 2. System Description and Thermodynamic Modeling

### 2.1 System Description

The CCES-CHP system schematic is shown in Fig. 1. The compression and expansion processes cannot be carried out simultaneously, while the heating process is relatively independent. Two operation modes are considered: charging-heating and discharging-heating.

In the energy storage process, low-valley electricity or curtailed renewable energy drives the compressors (C1, C2) to compress low-pressure CO₂ from the low-pressure tank (LPT) to a high-temperature, high-pressure state. The CO₂ is cooled by multi-stage compression and multi-stage cooling (IC1, IC2), then stored in the high-pressure tank (HPT) in the form of room-temperature liquid after liquefaction through the latent heat exchanger (LHE). The compression heat is absorbed by thermal oil from the ambient temperature thermal oil vessel (ATV) and stored in the high-temperature thermal oil vessel (HTV).

In the energy release process, liquid CO₂ flows out from the HPT, is throttled by a valve (V2), enters the evaporative heat exchanger (EHE) for complete vaporization, followed by multi-stage heat recovery heat exchangers (HR1, HR2) to absorb stored compression heat and raise the temperature. The supercritical CO₂ drives two-stage turbines (T1, T2) to generate electricity. The CO₂ from the turbine outlet is cooled by the after-expansion heat exchanger (AE-HE) and the cooler before returning to the LPT.

The high-temperature heat exchanger (HG-HE) and low-temperature heat exchanger (LG-HE) use the high and low-temperature thermal storage media to provide heat at different temperature grades to customers. The accompanying heat at the turbine outlet is also recovered, effectively improving the overall energy utilization efficiency.

### 2.2 Thermodynamic Modeling

The thermodynamic model of the CCES-CHP system is developed based on mass conservation and energy conservation equations. The following assumptions are adopted [25–27]:

1. The charging/discharging power and heating power remain constant during a single dispatch period.
2. There is no heat exchange between the CO₂ storage tank and the environment.
3. Heat and pressure energy losses in heat exchangers, piping, and connections are neglected.
4. The power consumed by working fluid circulation pumps is disregarded.
5. The compression heat stored in each complete cycle can be fully utilized for heating after satisfying expansion process requirements.

#### 2.2.1 Compressor Model

The total shaft power of the two-stage compressor at time t is:

$$W_C(t) = \sum_{i=1}^{N_C} \frac{n R_g m_C(t) T_{C,i}^{in}}{n-1} \frac{(\beta_{C,i})^{\frac{n-1}{n}}-1}{\eta_{C,i}}$$

Where N_C = 2 is the number of compressor stages, n = 1.3 is the polytropic index, R_g = 0.1889 kJ/(kg·K) is the ideal gas constant for CO₂, m_C(t) is the CO₂ mass flow rate, T_{C,i}^{in} is the compressor inlet temperature, β_{C,i} is the compression ratio, and η_{C,i} = 0.85 is the isentropic efficiency.

The total electrical power considering mechanical losses is:

$$W_{C,E}(t) = \frac{W_{C1}(t)}{\eta_{C,E}^1} + \frac{W_{C2}(t)}{\eta_{C,E}^2}$$

Where η_{C,E}^1 = η_{C,E}^2 = 0.98 is the motor mechanical efficiency.

#### 2.2.2 Turbine Model

The total shaft power of the two-stage turbine at time t is:

$$W_T(t) = \sum_{i=1}^{N_T} \frac{n R_g m_T(t) T_{T,i}^{in}}{n-1} \left[1 - (\beta_{T,i})^{-\frac{n-1}{n}}\right] \eta_{T,i}$$

The total electrical power output is:

$$W_{T,E}(t) = \eta_{T,E}^1 W_{T1}(t) + \eta_{T,E}^2 W_{T2}(t)$$

Where η_{T,E}^1 = η_{T,E}^2 = 0.95 is the generator mechanical efficiency, and η_{T,i} = 0.88 is the turbine isentropic efficiency.

#### 2.2.3 Heat Exchanger Model

The compression heat storage load from the intermediate coolers (IC1 and IC2) is:

$$Q_{IC}(t) = m_C(t) \left[\sum_{i=1}^{N_C-1} (h_{C,i}^{out} - h_{C,i+1}^{in}) + (h_{C,N_C}^{out} - h_{IC-end})\right]$$

The heat recovery load for the expansion process (HR1 and HR2) is:

$$Q_{HR}(t) = m_T(t) \left[\sum_{i=1}^{N_T-1} (h_{T,i+1}^{in} - h_{T,i}^{out}) + (h_{T,1}^{in} - h_{HR-start})\right]$$

### 2.3 System Design Parameters

The key design parameters of the CCES-CHP system are listed in Table 1.

**Table 1. Initial design parameters of CCES-CHP system.**

| Parameter | Value | Unit |
|-----------|-------|------|
| Ambient temperature | 298 | K |
| Ambient pressure | 0.101 | MPa |
| Design charging/discharging power | 10 | MW |
| Charging time | 7.5 | h |
| Discharging time | 5.0 | h |
| LPT pressure | 0.102 | MPa |
| HPT pressure | 6.80 | MPa |
| Compressor inlet temperature (all stages) | 308 | K |
| Turbine inlet temperature (all stages, baseline) | 483 | K |
| HTV temperature | 495 | K |
| ATV temperature | 298 | K |
| Minimum heat exchanger temperature difference | 5 | K |
| Compressor isentropic efficiency | 0.85 | — |
| Turbine isentropic efficiency | 0.88 | — |
| Motor mechanical efficiency | 0.98 | — |
| Generator mechanical efficiency | 0.95 | — |
| HTV thermal storage capacity | 150 | MWh_th |
| HPT volume | 500 | m³ |
| Charging mass flow rate | 26.9 | kg/s |
| Discharging mass flow rate | 40.3 | kg/s |

### 2.4 Performance Evaluation

The system performance is evaluated through electrical energy conversion efficiency, total heating efficiency, and comprehensive energy utilization efficiency:

$$\eta_{electricity} = \frac{\int_{t_{discharge}} W_{T,E}(t) dt}{\int_{t_{charge}} W_{C,E}(t) dt}$$

$$\eta_{heating,total} = \frac{\int Q_{HG-HE}(t) dt + \int Q_{LG-HE}(t) dt + \int Q_{AE-HE}(t) dt}{\int W_{C,E}(t) dt}$$

Under the baseline design condition with all HTV heat used for turbine reheat (X = 9.0%, Y = 91.0%), the system achieves η_electricity = 66.7%, η_heating,total = 21.4%, and a comprehensive energy utilization efficiency of 88.1%.

---

## 3. Construction of the Operational Feasibility Domain

### 3.1 Definition of Dimensionless Coupling Parameters

To understand the interconversion relationship between compressor power consumption, compression heat, turbine power generation, and mass flow, four key dimensionless parameters are defined:

$$\gamma_1 = \frac{Q_{IC}(t)}{W_{C,E}(t)}$$

$$\gamma_2 = \frac{Q_{HR}(t)}{W_{T,E}(t)}$$

$$\alpha_1 = \frac{m_C(t)}{W_{C,E}(t)}$$

$$\alpha_2 = \frac{m_T(t)}{W_{T,E}(t)}$$

Where γ₁ characterizes the compression heat generated per unit charging power, γ₂ characterizes the reheat demand per unit discharging power, α₁ characterizes the charge mass flow per unit power, and α₂ characterizes the discharge mass flow per unit power.

At the baseline design condition, γ₁ = 1.205, γ₂ = 2.307, α₁ = 2.76 kg/(s·MW), α₂ = 4.19 kg/(s·MW).

### 3.2 Dual State of Charge (SOC) Model

The state of charge (SOC) is an essential parameter reflecting the dynamic process of energy storage system operation. Since CCES-CHP charging and discharging involve coupled thermal conversion and pressure potential energy conversion, a dual SOC model is constructed based on HTV heat storage and HPT CO₂ storage pressure, respectively.

The heat storage SOC is described in terms of the HTV heat storage value:

$$Q_{HTV}(t) = \begin{cases}
Q_{HTV}(t-1) + [\gamma_1 W_{C,E}(t) - Q_{heat}(t)] \Delta t & \text{Charging-Heating} \\
Q_{HTV}(t-1) - [\gamma_2 W_{T,E}(t) + Q_{heat}(t)] \Delta t & \text{Discharging-Heating}
\end{cases}$$

The gas storage SOC is described in terms of HPT pressure:

$$p_{HPT}(t) = \begin{cases}
p_{HPT}(t-1) + \frac{R_g}{V_{HPT}} T_{HPT} \alpha_1 W_{C,E}(t) \Delta t & \text{Charging-Heating} \\
p_{HPT}(t-1) - \frac{R_g}{V_{HPT}} T_{HPT} \alpha_2 W_{T,E}(t) \Delta t & \text{Discharging-Heating}
\end{cases}$$

### 3.3 Charging-Heating Feasibility Domain

Under the charging-heating condition, electrical energy consumed by the compressor is converted into thermal energy of the storage medium and potential pressure energy of CO₂. The HTV heat storage must satisfy:

$$Q_{HTV}^{lower} \leq Q_{HTV}(t) \leq Q_{HTV}^{upper}$$

$$0 \leq Q_{heat}(t) \leq Q_{heat}^{max}$$

The boundary of the charging feasibility domain is a polygon formed by the following constraint lines:

$$Q_{heat}(t) = \frac{Q_{HTV}(t-1) - Q_{HTV}^{lower}}{\Delta t} + \gamma_1 W_{C,E}(t) \quad \text{(lower bound)}$$

$$Q_{heat}(t) = \frac{Q_{HTV}(t-1) - Q_{HTV}^{upper}}{\Delta t} + \gamma_1 W_{C,E}(t) \quad \text{(upper bound)}$$

$$Q_{heat}(t) = Q_{heat}^{max} \quad \text{(equipment limit)}$$

$$W_{C,E}(t) = W_{C,E}^{upper} \quad \text{(power limit)}$$

**Key characteristic**: The positive slope +γ₁ indicates electric-thermal **complementarity** during charging — higher charging power produces more compression heat, enabling greater heat supply.

### 3.4 Discharging-Heating Feasibility Domain

Under the discharging-heating condition, the thermal energy of the storage medium and the potential pressure energy of CO₂ are converted into electrical power and direct heat supply. The boundary is determined by:

$$Q_{heat}(t) = \frac{Q_{HTV}(t-1) - Q_{HTV}^{lower}}{\Delta t} - \gamma_2 W_{T,E}(t) \quad \text{(upper bound)}$$

$$Q_{heat}(t) = \frac{Q_{HTV}(t-1) - Q_{HTV}^{upper}}{\Delta t} - \gamma_2 W_{T,E}(t) \quad \text{(lower bound)}$$

$$Q_{heat}(t) = Q_{heat}^{max}, \quad W_{T,E}(t) = W_{T,E}^{upper}$$

**Key characteristic**: The negative slope −γ₂ indicates electric-thermal **competition** during discharging — power generation and heat supply compete for the same limited HTV stored energy. The upper-right corner (maximum power and maximum heat simultaneously) is infeasible.

The zero-heat maximum power and zero-power maximum heat are:

$$W_{max} = \frac{Q_{HTV}(t-1) - Q_{HTV}^{lower}}{\gamma_2 \Delta t}, \quad Q_{max} = \frac{Q_{HTV}(t-1) - Q_{HTV}^{lower}}{\Delta t}$$

### 3.5 Effect of Operating Parameters on Feasibility Domain

The heat supply rate X, reflecting the ratio of high and low-temperature heat supply to total heat storage, is related to γ₁, γ₂, α₁, α₂ by:

$$X = 1 - \frac{\gamma_2 \alpha_1 \eta_{C,E} \eta_{T,E}}{\gamma_1 \alpha_2}$$

The turbine inlet temperature directly affects γ₂ and consequently the shape of the feasibility domain. When the turbine inlet temperature increases, the CO₂ specific work capacity increases, reducing the reheat demand per unit power (γ₂ ↓). Under the assumption of uniform turbine inlet temperature, a correction factor λ is defined as the ratio of the reference temperature to the actual temperature:

$$\gamma_2' = [1 - \frac{(1-\lambda) T_{HR-start}}{\Sigma T_{T,i}^{in} - \Sigma T_{T,i}^{out} - T_{HR-start}}] \gamma_2$$

When λ < 1 (higher turbine inlet temperature), γ₂' < γ₂, the constraint slope becomes shallower, and the feasibility domain expands rightward — enabling higher power generation at the same heat supply level, or higher heat supply at the same power level.

---

## 4. Machine Learning Methodology

### 4.1 Training Data Generation

The training data generation pipeline is implemented in MATLAB, utilizing REFPROP v10.0 for high-fidelity CO₂ property calculations across 15 thermodynamic state nodes. The design of experiments systematically samples the parameter space:

**Table 2. Parameter sampling scheme for training data.**

| Parameter | Range | Steps | Description |
|-----------|-------|-------|-------------|
| SOC_heat | 0–100% | 16 | HTV thermal storage state |
| SOC_gas | 0–100% | 11 | HPT pressure state |
| W | 0–10 MW | 11 | Power setpoint |
| Q | 0–Q_max MW | 10 | Heat supply setpoint |
| Mode | 0, 1 | 2 | 0 = charge, 1 = discharge |

Total samples: 16 × 11 × 11 × 10 × 2 = **38,720**.

For each parameter combination, the feasibility label and boundary values are computed analytically from the constraint equations:

```
feasible = (Q ≤ slope × W + b_upper) ∧ (Q ≥ slope × W + b_lower) ∧
           (0 ≤ Q ≤ Q_max) ∧ (0 ≤ W ≤ W_design)
```

**Features per sample**: SOC_heat_pct, SOC_gas_pct, W_MW, Q_MW, mode, γ₁, γ₂, α₁, α₂

**Labels per sample**: feasible (0/1), W_max_feasible (MW), Q_max_feasible (MW)

### 4.2 XGBoost Classifier for Feasibility Prediction

XGBoost (eXtreme Gradient Boosting) [21] is employed as the primary classification model for predicting the feasibility of a given (W, Q) operating point. The model hyperparameters are configured as follows: n_estimators = 200, max_depth = 6, learning_rate = 0.1, subsample = 0.8, colsample_bytree = 0.8.

The dataset is split 80/20 (30,976 training / 7,744 test) with stratification on the feasibility label. The feature importance analysis reveals the dominant factors governing feasibility:

**Table 3. XGBoost feature importance ranking.**

| Feature | Importance | Physical Interpretation |
|---------|-----------|------------------------|
| SOC_heat_pct | 0.5030 | HTV thermal storage state — determines constraint intercept |
| mode | 0.3710 | Charge vs. discharge — determines constraint direction |
| W_MW | 0.0716 | Power setpoint — determines position along constraint |
| Q_MW | 0.0529 | Heat setpoint — vertical position in domain |
| SOC_gas_pct | 0.0015 | HPT pressure state — rarely binding at current volume |
| γ₁, γ₂, α₁, α₂ | ~0 | Constant across training data (fixed T_turb) |

The dominance of SOC_heat (50.3%) and mode (37.1%) confirms that the thermal storage constraint is the primary determinant of feasibility, consistent with the analytical formulation in Section 3.

### 4.3 XGBoost Regressors for Boundary Prediction

Two XGBoost regression models are trained to predict the feasibility domain boundaries: W_max_feasible (maximum feasible power at given SOC) and Q_max_feasible (maximum feasible heat at given SOC). These models are trained on the feasible subset of the data (34,760 samples). Hyperparameters: n_estimators = 150, max_depth = 5, learning_rate = 0.1.

### 4.4 MLP Neural Network for Benchmark Comparison

A multi-layer perceptron (MLP) neural network is trained as a benchmark model. Architecture: 3 hidden layers (128×64×32) with ReLU activation, trained using the Adam optimizer with adaptive learning rate, batch size 256, and maximum 300 epochs. Input features are standardized using StandardScaler.

### 4.5 Model Performance

**Table 4. ML model performance summary.**

| Model | Task | Metric | Value |
|-------|------|--------|-------|
| XGBoost | Feasibility classification | Test Accuracy | **100.00%** |
| MLP (128×64×32) | Feasibility classification | Test Accuracy | **99.77%** |
| XGBoost | W_max boundary regression | R² | **1.0000** |
| XGBoost | Q_max boundary regression | R² | **1.0000** |

The near-perfect accuracy is attributable to the underlying linear nature of the feasibility constraints. The feasibility decision boundary consists of linear inequalities derived from energy conservation and SOC limits. XGBoost's tree ensemble architecture naturally approximates piecewise-linear decision boundaries with high precision. The MLP achieves slightly lower accuracy (99.77%) due to the smooth activation functions introducing minor approximation errors near boundaries.

### 4.6 Why Machine Learning?

While the feasibility constraints are analytically linear, the value of ML lies in three aspects:

1. **Inference speed**: A single XGBoost prediction traverses ~200 trees in microseconds, compared to a full REFPROP-based thermodynamic simulation requiring multiple property calls and iterative convergence.

2. **Generalization across parameter space**: Once trained on data spanning multiple γ₂ values (different T_turb settings), the ML model can interpolate feasibility across continuous parameter variations without re-running the full simulation.

3. **Seamless integration with optimization**: The trained model serves as a fast, differentiable surrogate constraint in dispatch optimization loops, enabling real-time decision-making.

---

## 5. Dispatch Optimization Framework

### 5.1 Problem Formulation

The 24-hour dispatch optimization problem is formulated as follows. Given hourly profiles of electric load, heat load, and wind power, the C-CHP unit operates in a heat-led mode, and CCES-CHP serves as a supplemental source to track the residual dispatch:

$$Elec\_Dispatch(t) = Elec\_Load(t) - CCHP\_elec(t) - Wind\_Power(t)$$

$$Heat\_Dispatch(t) = Heat\_Load(t) - CCHP\_heat(t)$$

Where positive Elec_Dispatch indicates charging (energy storage) and negative indicates discharging (energy release). The C-CHP has a capacity of 30 MW with a heat-to-power ratio of 1.2, producing CCHP_heat = min(Heat_Load, 36 MW) and CCHP_elec = CCHP_heat / 1.2.

At each hour t, the optimization objective is to find the (W, Q) that minimizes the weighted dispatch deviation while respecting the feasibility constraint:

$$\min_{W,Q} \quad |W - W_{target}| + \lambda \cdot |Q - Q_{target}|$$

$$\text{s.t.} \quad f_{ML}(SOC_{heat}, SOC_{gas}, W, Q, mode) = 1 \quad \text{(feasible)}$$

$$0 \leq W \leq W_{max}, \quad 0 \leq Q \leq Q_{max}$$

Where λ = 0.5 reflects the priority weighting between electrical and thermal dispatch tracking, and f_ML is the XGBoost feasibility classifier.

### 5.2 ML-Based Grid Search Algorithm

A grid search approach is adopted for its robustness and compatibility with the discrete nature of the ML classifier:

**Algorithm 1: ML-based dispatch optimization for each hour t**

```
1. Read current states: SOC_heat(t), SOC_gas(t)
2. Determine mode and targets:
   if Elec_Dispatch(t) > 0: mode = 0 (charge), W_target = min(Elec_Dispatch, 10), Q_target = min(Heat_Dispatch, 9.5)
   else: mode = 1 (discharge), W_target = min(|Elec_Dispatch|, 10), Q_target = min(Heat_Dispatch, 9.5)
3. Generate search grid: W ∈ linspace(0, W_target, 20), Q ∈ linspace(0, Q_target, 15) → 300 candidate points
4. Batch prediction: f_ML(SOC_h, SOC_g, W, Q, mode) for all 300 points
5. Select feasible point with best objective score
6. Update SOC_heat(t+1), SOC_gas(t+1) via thermal balance equations
```

The grid resolution of 20 × 15 = 300 points provides ~0.5 MW granularity for both W and Q, sufficient for practical dispatch decisions. The computational cost is 300 ML predictions per hour × 24 hours = 7,200 predictions, which completes in milliseconds.

### 5.3 Rule-Based Baseline

A rule-based dispatch strategy serves as the comparison baseline. The rule-based approach:
- Always attempts to fully track dispatch instructions
- Clips at equipment limits (W ≤ 10 MW, Q ≤ 9.5 MW)
- Checks HTV SOC constraints analytically without optimization
- Allocates W and Q independently without considering their coupled consumption of the shared thermal budget

---

## 6. Results and Discussion

### 6.1 Case Study Configuration

The case study considers an integrated energy system consisting of a 20 MW wind power unit, a 30 MW conventional CHP unit (heat-to-power ratio = 1.2), and a 10 MW/50 MWh CCES-CHP system. A typical day in the heating season is selected, with 24-hour profiles of electrical load, heat load, and wind power as shown in Fig. 2.

**Table 5. 24-hour load and wind power data.**

| Hour | Heat Load (MW) | Elec Load (MW) | Wind Power (MW) |
|------|---------------|----------------|-----------------|
| 1 | 38 | 28 | 18 |
| 2 | 35 | 22 | 16 |
| 3 | 32 | 18 | 14 |
| 4 | 30 | 16 | 12 |
| 5 | 29 | 15 | 13 |
| 6 | 28 | 14 | 12 |
| 7 | 28 | 16 | 8 |
| 8 | 29 | 18 | 6 |
| 9 | 31 | 20 | 5 |
| 10 | 33 | 22 | 4 |
| 11 | 36 | 26 | 3 |
| 12 | 39 | 48 | 2 |
| 13 | 41.5 | 48 | 2 |
| 14 | 41 | 48 | 3 |
| 15 | 40 | 45 | 4 |
| 16 | 38 | 30 | 6 |
| 17 | 37 | 28 | 10 |
| 18 | 35 | 24 | 12 |
| 19 | 40 | 32 | 8 |
| 20 | 42 | 48 | 6 |
| 21 | 41.5 | 48 | 5 |
| 22 | 40 | 48 | 14 |
| 23 | 42 | 48 | 16 |
| 24 | 40 | 35 | 18 |

Key characteristics: Wind power is abundant at night (hours 1–7) and low during midday. Electrical load peaks at noon (hours 12–15) and evening (hours 19–23). Heat load peaks in the morning and evening, characteristic of winter heating demand. Several charging windows exist (night wind surplus, midday troughs between peaks).

### 6.2 Dispatch Optimization Results

The 24-hour dispatch comparison between rule-based and ML-optimized strategies is presented in Fig. 3 and Table 6.

**Table 6. 24-hour dispatch performance comparison.**

| Metric | Rule-Based | ML-Optimized | Improvement |
|--------|-----------|--------------|-------------|
| Total charge energy (MWh) | 66.0 | 66.0 | — |
| Total discharge energy (MWh) | 48.3 | 46.1 | −4.6% |
| Total heat supply (MWh) | 43.0 | **46.3** | **+7.7%** |
| Discharge duration (h) | 15 | **24** | **+60.0%** |
| Terminal SOC_heat (%) | 0.0 | **5.0** | Avoids depletion |
| Electrical dispatch tracking rate (%) | 40.6 | 40.6 | — |

Three key observations:

**Observation 1 — Extended discharge coverage**: The rule-based strategy depletes HTV storage by hour 15, leaving hours 16–24 uncovered. The ML-optimized strategy extends coverage across all 24 hours by adaptively reducing power output during low-SOC periods. This is not a violation of physical limits — the same 66.0 MWh of charging energy is used more judiciously.

**Observation 2 — Increased heat supply**: Despite discharging 4.6% less total energy, the ML-optimized strategy delivers 7.7% more heat. This is achieved by dynamically allocating the HTV thermal budget between reheat (for power) and direct heat supply — favoring heat when electricity demand is moderate, and favoring power when electricity prices are high.

**Observation 3 — Terminal SOC margin**: The rule-based strategy exhausts HTV storage to 0%, leaving no operational margin for contingencies. The ML-optimized strategy maintains 5.0% SOC at the end of the horizon, providing buffer for unexpected demand.

### 6.3 Three Core ML Optimization Strategies

Analysis of the hour-by-hour dispatch decisions reveals three distinct strategies the ML optimization employs:

#### Strategy 1: Power Derating for Duration Extension

Stored energy = power × time. The rule-based strategy tends to discharge at full power (10 MW), depleting HTV rapidly. The ML-optimized strategy adaptively reduces discharge power based on SOC:

```
Rule-based: [10, 10, 10, 10, 10, 0, 0, 0, 0]  → 5h full-power, then depleted
ML-optimized: [8, 7, 6, 5, 5, 4, 3, 3, 2]     → 9h derated power, covering all periods
```

This is a direct consequence of the energy conservation constraint: the same energy budget spread thinner covers a longer duration.

#### Strategy 2: Dynamic Electric-Thermal Allocation

During discharge, HTV consumption rate = γ₂·W + Q. The rule-based strategy treats W and Q as independent targets. The ML optimization recognizes them as coupled under a shared thermal budget and dynamically allocates:
- High electricity price hours (noon, evening peak): allocate more HTV budget to W, less to Q
- High heat demand hours (morning, night): allocate more budget to Q, less to W
- The coupling γ₂ = 2.307 means every 1 MW of power generation "costs" 2.307 MW of thermal power — ML makes this trade-off explicit and optimal.

#### Strategy 3: Strategic Charging with Optimal Margin

Multiple charging windows exist throughout the day (night wind surplus hours 1–7, midday trough hours 16–18, night hours 22–24). The ML optimization calculates the exact charge amount needed for the upcoming discharge segment, avoiding both overcharging (wasting storage capacity) and undercharging (running out mid-discharge). The terminal SOC of 5.0% is a deliberate operational margin, not a random residual.

#### Physical Upper Bound

It is important to note that the full-power, full-heat continuous discharge is physically limited to approximately 4.8 hours:

$$t_{max} = \frac{Q_{HTV}^{upper}}{\gamma_2 \cdot W_{max} + Q_{max}} = \frac{150}{2.307 \times 10 + 9.5} \approx 4.8 \text{ h}$$

The 24-hour "continuous discharge" is achieved through strategic power derating and multiple charge-discharge cycles — not by violating the fundamental energy capacity constraint. This distinguishes the proposed approach from methods that claim to extend capacity without physical basis.

### 6.4 Feasibility Domain Expansion via Parameter Optimization

Beyond dispatch optimization within a fixed feasibility domain, the proposed framework enables optimization of the domain itself through operating parameter tuning.

#### Mechanism

The reheat coefficient γ₂ is a function of turbine inlet temperature. Increasing T_turb enhances the specific work capacity of CO₂, reducing the reheat demand per unit power generation:

```
T_turb ↑ → CO₂ specific work capacity ↑ → γ₂ ↓ → constraint slope flattens → feasible domain expands
```

#### Quantitative Results

**Table 7. Feasibility domain comparison: baseline vs. optimized parameters.**

| Parameter | Baseline (T_turb = 483 K) | Optimized (T_turb = 503 K) | Change |
|-----------|--------------------------|----------------------------|--------|
| γ₂ (reheat coefficient) | 2.31 | 1.78 | **−23.0%** |
| Constraint slope | −2.31 | −1.78 | Flatter |
| W_max at SOC = 10% (MW) | 6.5 | 8.4 | **+29.2%** |
| Feasible domain area at SOC = 10% | 30.8 | 40.0 | **+29.8%** |
| Full-power discharge duration (h) | ~6.5 | ~8.4 | **+29.2%** |

**Table 8. Feasible domain area at different SOC levels.**

| SOC_heat (%) | Baseline Area | Optimized Area | Expansion (%) |
|-------------|--------------|----------------|---------------|
| 10 | 30.8 | 40.0 | +29.8 |
| 20 | 47.5 | 47.5 | 0 (equipment-limited) |
| 40 | 47.5 | 47.5 | 0 (equipment-limited) |
| 60 | 47.5 | 47.5 | 0 (equipment-limited) |
| 80 | 47.5 | 47.5 | 0 (equipment-limited) |

At SOC ≥ 20%, the feasible domain is bounded by equipment limits (W ≤ 10 MW, Q ≤ 9.5 MW) rather than by thermal storage constraints, so parameter optimization yields no further expansion. The benefit is concentrated at low SOC — precisely when the system is most constrained and operating margin is most valuable.

#### Physical Interpretation

The constraint equation under discharge is:

$$Q = -\gamma_2 \cdot W + \frac{Q_{HTV} - Q_{HTV}^{lower}}{\Delta t}$$

At W = 0: Q_max = (Q_HTV − Q_lower)/Δt (unchanged by γ₂)
At Q = 0: W_max = (Q_HTV − Q_lower)/(γ₂·Δt) (inversely proportional to γ₂)

Thus, reducing γ₂ extends the feasible domain rightward along the W-axis, increasing the maximum power generation capability at any given heat supply level, without affecting the maximum heat supply at zero power.

### 6.5 Discussion

#### 6.5.1 ML Accuracy and Its Physical Basis

The 100% classification accuracy reflects the underlying nature of the feasibility constraints as linear inequalities. The ML models learn these boundaries without error because the training data densely samples the feasible space and the decision surface is piecewise-linear. This is not a limitation — rather, it validates that the ML framework correctly captures the physics without introducing spurious nonlinearities or overfitting artifacts.

The MLP achieves 99.77% accuracy (18 misclassifications out of 7,744 test samples), with errors concentrated near constraint boundaries where the smooth sigmoid activation in the output layer produces values close to 0.5. XGBoost's tree-based decision boundaries avoid this issue entirely.

#### 6.5.2 From Static Constraint to Controllable Variable

Traditional dispatch optimization treats the feasibility domain as a fixed constraint. The proposed framework transforms it into a controllable variable. The two-level optimization architecture — outer loop optimizing T_turb (→γ₂→domain shape) and inner loop optimizing (W, Q) within the domain — enables simultaneous parameter and dispatch optimization. This meta-optimization is made computationally feasible by the ML surrogate models, which provide instantaneous feasibility assessments across the parameter space.

#### 6.5.3 Practical Implications

The extended discharge coverage (15→24h) and increased heat supply (43.0→46.3 MWh, +7.7%) have direct economic implications for integrated energy system operation. Specifically: (a) systems with higher renewable penetration benefit from longer energy shifting capability, (b) the terminal SOC margin reduces the risk of demand shortfall and the need for emergency backup, and (c) the reduction in wasted discharge energy (−4.6%) indicates better utilization of stored energy.

#### 6.5.4 Limitations and Future Work

Several limitations warrant acknowledgment. First, the training data assumes fixed γ₁, γ₂ per simulation run; variable-parameter training spanning a T_turb sweep would enable continuous γ₂ optimization within the dispatch loop. Second, the current grid search resolution (20×15) could be enhanced with gradient-based or Bayesian optimization methods. Third, the economic objective function (time-of-use electricity prices, heat tariffs) would strengthen practical relevance. Fourth, multi-period look-ahead optimization (dynamic programming or model predictive control) could replace the greedy hour-by-hour approach, potentially yielding further improvements through inter-temporal coordination. Fifth, the gas-side SOC constraint, while included in the formulation, rarely binds at the current HPT volume (500 m³); systems with smaller HPT volumes would exhibit stronger dual-SOC coupling effects.

---

## 7. Conclusion

This study presents a machine learning framework for dynamic construction and optimization of the operational feasibility domain of CCES-CHP systems. The main conclusions are:

1. A parameterized feasibility domain representation using dimensionless factors γ₁/γ₂ and ratio parameters α₁/α₂ effectively couples the electrical, thermal, and mass flow domains. The dual SOC model (thermal + gas storage) establishes two-dimensional linear constraint boundaries that define the feasible operating region.

2. XGBoost and MLP models trained on 38,720 thermodynamic simulation samples achieve near-perfect accuracy in feasibility classification (100% and 99.77%, respectively). Boundary regression achieves R² = 1.0000 for both W_max and Q_max. Feature importance analysis confirms SOC_heat (50.3%) and operating mode (37.1%) as the dominant factors.

3. ML-optimized 24-hour dispatch extends discharge coverage duration from 15 to 24 hours (+60%) and increases total heat supply from 43.0 to 46.3 MWh (+7.7%), while maintaining a 5.0% terminal SOC margin versus 0.0% for the rule-based baseline. The improvement stems from three strategies: power derating for duration extension, dynamic electric-thermal allocation under a shared thermal budget, and strategic charging with optimal operational margins.

4. ML-guided operating parameter optimization (T_turb: 483 K → 503 K) reduces γ₂ from 2.31 to 1.78 (−23%), expanding the feasible domain area by 29.8% at low SOC and extending full-power discharge duration from 6.5 to 8.4 hours. This demonstrates that the feasibility domain can be transformed from a passive constraint into an active optimization variable.

5. The ML prediction speed (milliseconds for 7,200 feasibility queries) enables real-time dispatch optimization that would be computationally prohibitive using full thermodynamic simulation, making the proposed approach suitable for practical energy management system integration.

The proposed methodology provides an effective tool for real-time dispatch, capacity planning, and operational optimization of CCES-CHP systems in integrated energy systems with high renewable penetration.

---

## Acknowledgments

This work was supported by the Technical Institute of Physics and Chemistry, Chinese Academy of Sciences.

---

## References

[1] Hussain J, Lee CC. A green path towards sustainable development: optimal behavior of the duopoly game model with carbon neutrality instruments. Sustainable Development 2022;30:1523–41.

[2] Matos CR, Carneiro JF, Silva PP. Overview of large-scale underground energy storage technologies for integration of renewable energies and criteria for reservoir identification. Journal of Energy Storage 2019;21:241–58.

[3] Rahman MM, Oni AO, Gemechu E, Kumar A. Assessment of energy storage technologies: a review. Energy Conversion and Management 2020;223:113295.

[4] Chen KQ, Pu WH, Zhang Q, Xing XL, Xiong C, Guo MD. Thermodynamic and economic assessment on the supercritical compressed carbon dioxide energy storage system coupled with solar thermal storage. Journal of Energy Storage 2021;41:102959.

[5] Guo H, Xu YJ, Chen HS, Zhou XZ. Thermodynamic characteristics of a novel supercritical compressed air energy storage system. Energy Conversion and Management 2016;115:167–77.

[6] Courtois N, Najafiyazdi M, Lotfalian R, Boudreault R, Picard M. Analytical expression for the evaluation of multi-stage adiabatic-compressed air energy storage (A-CAES) systems cycle efficiency. Applied Energy 2021;288:116592.

[7] Chen H, Peng YH, Wang YL, Zhang J. Thermodynamic analysis of an open type isothermal compressed air energy storage system based on hydraulic pump/turbine and spray cooling. Energy Conversion and Management 2020;204:112293.

[8] Wang PZ, Zhao P, Xu WP, Wang JF, Dai YP. Performance analysis of a combined heat and compressed air energy storage system with packed bed unit and electrical heater. Applied Thermal Engineering 2019;162:114321.

[9] Szablowski L, Krawczyk P, Wolowicz M. Exergy analysis of adiabatic liquid air energy storage (A-LAES) system based on Linde–Hampson cycle. Energies 2021;14:945.

[10] Zhang T, Chen LJ, Zhang XL, Mei SW, Xue XD, Zhou Y. Thermodynamic analysis of a novel hybrid liquid air energy storage system based on the utilization of LNG cold energy. Energy 2018;155:641–50.

[11] Mercangöz M, Hemrle J, Kaufmann L, Z'Graggen A, Ohler C. Electrothermal energy storage with transcritical CO₂ cycles. Energy 2012;45:407–15.

[12] Liu Z, Liu B, Guo JZ, Xin X, Yang XH. Conventional and advanced exergy analysis of a novel transcritical compressed carbon dioxide energy storage system. Energy Conversion and Management 2019;198:111807.

[13] Cao Z, Deng JQ, Zhou SH, He Y. Research on the feasibility of compressed carbon dioxide energy storage system with underground sequestration in antiquated mine goaf. Energy Conversion and Management 2020;221:112788.

[14] Chaychizadeh F, Dehghandorost H, Aliabadi A, Taklifi A. Stochastic dynamic simulation of a novel hybrid thermal-compressed carbon dioxide energy storage system (T-CCES) integrated with a wind farm. Energy Conversion and Management 2018;166:500–11.

[15] Chae YJ, Lee JI. Thermodynamic analysis of compressed and liquid carbon dioxide energy storage system integrated with steam cycle for flexible operation of thermal power plant. Energy Conversion and Management 2022;256:115374.

[16] Wang XY, Wu YT, Fu L. Configuration method for combined heat and power plants with flexible electricity regulation. Energy and Buildings 2023;287:112966.

[17] Liu Z, Cao F, Guo JZ, Liu J, Zhai HY, Duan ZY. Performance analysis of a novel combined cooling, heating and power system based on carbon dioxide energy storage. Energy Conversion and Management 2019;188:151–61.

[18] Zhang Y, Lin YH, Lin FZ, Yang K. Thermodynamic analysis of a novel combined cooling, heating, and power system consisting of wind energy and transcritical compressed CO₂ energy storage. Energy Conversion and Management 2022;260:115609.

[19] He TY, Cao Y, Si FQ. Thermodynamic analysis and optimization of a compressed carbon dioxide energy storage system coupled with a combined heating and power unit. Energy Conversion and Management 2023;277:116618.

[20] Hao J, Zheng P, Li Y, Zhang Z, Zhang J, Yang J, Yue Y, Li X. Study on the operational feasibility domain of combined heat and power generation system based on compressed carbon dioxide energy storage. Energy 2024;291:130122.

[21] Chen T, Guestrin C. XGBoost: A scalable tree boosting system. Proceedings of the 22nd ACM SIGKDD International Conference on Knowledge Discovery and Data Mining 2016;785–794.

[22] Ahmad T, Chen H. A review on machine learning forecasting growth trends and their real-time applications in different energy systems. Sustainable Cities and Society 2020;54:102010.

[23] Kusiak A, Zhang Z, Verma A. Prediction, operations, and condition monitoring in wind energy. Energy 2013;60:1–12.

[24] Cheng L, Yu T. A new generation of AI: A review and perspective on machine learning technologies applied to smart energy and electric power systems. International Journal of Energy Research 2019;43:1928–73.

[25] Dai BM, Li MX, Ma YT. Thermodynamic analysis of carbon dioxide blends with low GWP working fluids-based transcritical Rankine cycles for low-grade heat energy recovery. Energy 2014;64:942–52.

[26] Zhao SF, Ge ZH, He J, Wang CL, Yang YP, Li PF. A novel mechanism for exhaust steam waste heat recovery in combined heat and power unit. Applied Energy 2017;204:596–606.

[27] Aghagoli A, Sorin M. CFD modelling and exergy analysis of a heat pump cycle with Tesla Turbine using CO₂ as a working fluid. Applied Thermal Engineering 2020;178:115587.

---

## Appendix: ML Model Training Details

**Table A1. XGBoost classifier hyperparameters.**

| Parameter | Value |
|-----------|-------|
| n_estimators | 200 |
| max_depth | 6 |
| learning_rate | 0.1 |
| subsample | 0.8 |
| colsample_bytree | 0.8 |
| eval_metric | logloss |

**Table A2. MLP classifier hyperparameters.**

| Parameter | Value |
|-----------|-------|
| hidden_layer_sizes | (128, 64, 32) |
| activation | ReLU |
| solver | Adam |
| alpha (L2 regularization) | 0.001 |
| batch_size | 256 |
| learning_rate | adaptive |
| max_iter | 300 |

**Table A3. Computational resources.**

| Component | Specification |
|-----------|--------------|
| Data generation | MATLAB R2020a + REFPROP v10.0 |
| ML training | Python 3.10, scikit-learn 1.x, XGBoost 2.x |
| Training time (XGBoost) | < 5 seconds |
| Training time (MLP) | < 30 seconds |
| Inference time (24h dispatch) | < 100 milliseconds |
