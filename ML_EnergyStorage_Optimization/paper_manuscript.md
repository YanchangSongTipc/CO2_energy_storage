# Research on the Operational Optimal Feasibility Domain of Compressed Carbon Dioxide Energy Storage Systems Based on Machine Learning

**Yanchang Song<sup>1</sup>, Zhentao Zhang<sup>1*</sup>, Junling Yang<sup>1</sup>**

<sup>1</sup> State Key Laboratory of Cryogenic Science and Technology, Technical Institute of Physics and Chemistry, Chinese Academy of Sciences, Beijing, China

<sup>*</sup> Corresponding author: zzt@mail.ipc.ac.cn

---

## Abstract

Compressed carbon dioxide energy storage with combined heat and power (CCES-CHP) couples electrical, thermal and mass flows, so its operational feasibility domain is a polygon in the power–heat plane whose position shifts with two state variables. Building that domain from thermophysical property calls is too slow for real-time dispatch. Surrogates are therefore trained on 38,720 samples generated with REFPROP from a two-stage transcritical CO₂ cycle, using dimensionless couplings γ₁/γ₂ and α₁/α₂ together with a dual state-of-charge formulation in which the CO₂ liquid inventory, not the tank pressure, bounds the instantaneous power. Under five-fold stratified cross-validation XGBoost classifies feasibility at 100.00 ± 0.01 % and an MLP at 99.74 ± 0.11 %, against 82.01 % for a linear classifier, and reproduces both domain boundaries exactly (R² = 1.0000). TreeSHAP attributes 41.5 % of the prediction to the heat state and 25.1 % to the gas inventory; removing the gas state costs 9.3 percentage points, confirming that the inventory constraint is physically active. In a 24-hour case study the surrogate-guided dispatch raises delivered heat from 44.0 to 46.3 MWh (+5.2 %) and the hours with active discharge from 9 to 16, but an exact linear-programming benchmark of the same objective places it 3.8 % from the optimum. A sweep of the heat weight locates the genuine headroom: 48.6 MWh for the heuristic and 52.0 MWh for the optimum, 18 % above the rule-based baseline. Turbine inlet temperature raises efficiency and discharge duration rather than expanding the domain.

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
2. XGBoost and MLP models reaching 100.00 ± 0.01 % and 99.74 ± 0.11 % accuracy under five-fold stratified cross-validation, against 82.01 % for a linear classifier, and exact reproduction of both domain boundaries (R² = 1.0000).
3. A dispatch framework that pairs the surrogate with an exact linear-programming benchmark: the grid-search heuristic delivers 46.3 MWh of heat against 44.0 MWh for the rule-based policy, yet sits 3.8 % from the optimum of its own objective, and a sweep of the heat weight shows the achievable gain rising from 46.3 to 48.6 MWh for the heuristic and from 14.7 to 52.0 MWh for the optimum.
4. A physically complete dual-SOC formulation in which the HPT liquid inventory bounds the instantaneous power; TreeSHAP attributes 25.1 % of the prediction to the gas-side state and removing it costs 9.3 percentage points of accuracy, confirming that the coupling is physically active rather than nominal.
5. A quantitative attribution of where the dispatch gain comes from: the conservatism of the surrogate near the constraint boundary, which preserves thermal storage for later hours, rather than an optimal electric–thermal allocation.

The remainder of this paper is organized as follows. Section 2 describes the CCES-CHP system and thermodynamic model. Section 3 presents the feasibility domain construction method. Section 4 details the ML methodology. Section 5 describes the dispatch optimization framework. Section 6 presents the case study and results. Section 7 concludes.

---

## 2. System Description and Thermodynamic Modeling

### 2.1 System Description

The CCES-CHP system schematic is shown in Fig. 1. The compression and expansion processes cannot be carried out simultaneously, while the heating process is relatively independent. Two operation modes are considered: charging-heating and discharging-heating.

In the energy storage process, low-valley electricity or curtailed renewable energy drives the compressors (C1, C2) to compress low-pressure CO₂ from the low-pressure tank (LPT) to a high-temperature, high-pressure state. The CO₂ is cooled by multi-stage compression and multi-stage cooling (IC1, IC2), then stored in the high-pressure tank (HPT) in the form of room-temperature liquid after liquefaction through the latent heat exchanger (LHE). The compression heat is absorbed by thermal oil from the ambient temperature thermal oil vessel (ATV) and stored in the high-temperature thermal oil vessel (HTV).

In the energy release process, liquid CO₂ flows out from the HPT, is throttled by a valve (V2), enters the evaporative heat exchanger (EHE) for complete vaporization, followed by multi-stage heat recovery heat exchangers (HR1, HR2) to absorb stored compression heat and raise the temperature. The supercritical CO₂ drives two-stage turbines (T1, T2) to generate electricity. The CO₂ from the turbine outlet is cooled by the after-expansion heat exchanger (AE-HE) and the cooler before returning to the LPT.

The high-temperature heat exchanger (HG-HE) and low-temperature heat exchanger (LG-HE) use the high and low-temperature thermal storage media to provide heat at different temperature grades to customers. The accompanying heat at the turbine outlet is also recovered, effectively improving the overall energy utilization efficiency.

![Fig. 1](../CCES_CHP_Simulink/output/CCES_CHP_cycle_en.png)

**Fig. 1. Schematic of the CCES-CHP system.** Charging and discharging share the LPT/HPT pair and the HTV thermal store; the compression heat recovered in IC1/IC2 supplies the reheat duties HR1/HR2 and the external heat load, while the evaporator (EHE) draws ambient/low-grade heat. LPT and HPT denote the low- and high-pressure CO₂ tanks and HTV the high-temperature thermal vessel; the numbered points refer to the state table in the figure.

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

The charging and discharging processes are plotted in the temperature–entropy plane in Fig. 2.

![Fig. 2](../CCES_CHP_Analysis/output_figures/Fig12_Ts_Diagram.png)

**Fig. 2. Temperature–entropy diagram of the CCES-CHP cycle with the CO₂ saturation dome.** State points 1–7 trace the charging process (compression, intercooling, liquefaction) and points 8–15 the discharging process (throttling, evaporation, reheat, expansion); the cycle stays on the vapour side of the dome.

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
| HPT volume | 1280 | m³ |
| HPT liquid inventory (usable window) | 943 (10–90%) | t |
| Charging mass flow rate | 26.9 | kg/s |
| Discharging mass flow rate | 40.3 | kg/s |

*These mass flow rates are the reference design values. Evaluated with the present property data they correspond to 9.74 MW of compression power and 9.62 MW of turbine output, which is the origin of the ratio parameters given in Section 3.1.*

### 2.4 Performance Evaluation

The system performance is evaluated through electrical energy conversion efficiency, total heating efficiency, and comprehensive energy utilization efficiency:

$$\eta_{electricity} = \frac{\int_{t_{discharge}} W_{T,E}(t) dt}{\int_{t_{charge}} W_{C,E}(t) dt}$$

$$\eta_{heating,total} = \frac{\int Q_{HG-HE}(t) dt + \int Q_{LG-HE}(t) dt + \int Q_{AE-HE}(t) dt}{\int W_{C,E}(t) dt}$$

Under the baseline design condition, the evaporative heat exchanger is resolved separately: it vaporizes the throttled liquid with ambient/low-grade heat (6.23 MW) before the CO₂ enters HR1, so that the stored compression heat covers only the superheating and reheat duties (9.65 MW and 6.31 MW). With all HTV heat used for turbine reheat (X = 9.3%, Y = 90.7%) the model gives η_electricity = 65.8%, η_heating,total = 25.4% (11.3% low-temperature and 14.2% after-expansion), and a comprehensive energy utilization efficiency of 91.3%. The residual differences from the reference design (66.7%, 21.4%) originate from the state-point details and the separate resolution of the evaporator.

---

## 3. Construction of the Operational Feasibility Domain

### 3.1 Definition of Dimensionless Coupling Parameters

To understand the interconversion relationship between compressor power consumption, compression heat, turbine power generation, and mass flow, four key dimensionless parameters are defined:

$$\gamma_1 = \frac{Q_{IC}(t)}{W_{C,E}(t)}$$

$$\gamma_2 = \frac{Q_{HR}(t)}{W_{T,E}(t)}$$

$$\alpha_1 = \frac{m_C(t)}{W_{C,E}(t)}$$

$$\alpha_2 = \frac{m_T(t)}{W_{T,E}(t)}$$

Where γ₁ characterizes the compression heat generated per unit charging power, γ₂ characterizes the reheat demand per unit discharging power, α₁ characterizes the charge mass flow per unit power, and α₂ characterizes the discharge mass flow per unit power.

At the baseline design condition (T_turb = 483 K), γ₁ = 1.205, γ₂ = 1.659, α₁ = 2.762 kg/(s·MW), α₂ = 4.191 kg/(s·MW). Note that γ₂ is evaluated with the EHE vaporization duty excluded, because that duty is supplied by ambient heat rather than by the HTV; including it would inflate γ₂ to 2.31 and produce a spurious heat deficit.

### 3.2 Dual State of Charge (SOC) Model

The state of charge (SOC) is an essential parameter reflecting the dynamic process of energy storage system operation. Since CCES-CHP charging and discharging involve coupled thermal conversion and mass storage, a dual SOC model is constructed on the HTV heat storage and the HPT CO₂ liquid inventory.

The heat storage SOC is described in terms of the HTV heat storage value:

$$Q_{HTV}(t) = \begin{cases}
Q_{HTV}(t-1) + [\gamma_1 W_{C,E}(t) - Q_{heat}(t)] \Delta t & \text{Charging-Heating} \\
Q_{HTV}(t-1) - [\gamma_2 W_{T,E}(t) + Q_{heat}(t)] \Delta t & \text{Discharging-Heating}
\end{cases}$$

The gas storage SOC is described by the CO₂ inventory of the HPT. After liquefaction in the LHE the working fluid is stored as room-temperature liquid, and the tank pressure (6.80 MPa) is maintained by the charging pump rather than by phase equilibrium; the tank pressure is therefore essentially constant and is not a state variable. The quantity that actually bounds operation is the liquid inventory:

$$m_{HPT}(t) = \begin{cases}
m_{HPT}(t-1) + \alpha_1 W_{C,E}(t) \Delta t & \text{Charging-Heating} \\
m_{HPT}(t-1) - \alpha_2 W_{T,E}(t) \Delta t & \text{Discharging-Heating}
\end{cases}$$

$$SOC_{gas}(t) = \frac{m_{HPT}(t)}{m_{HPT}^{full}}, \qquad m_{HPT}^{lower} \le m_{HPT}(t) \le m_{HPT}^{upper}$$

with $m_{HPT}^{full}$ = 943 t (1280 m³ of liquid CO₂ at 298 K and 6.80 MPa) and an operating window of 10–90% of the full charge. Unlike the ideal-gas relation $p = m R_g T / V$ adopted in [20] for the HPT, this inventory formulation is consistent with liquid storage: 754 t of CO₂ occupies about 1057 m³ as a liquid, whereas the same mass would require roughly 6000 m³ as a gas at 6.8 MPa.

The coupled evolution of the two SOCs under the periodic operating schedule is shown in Fig. 3.

![Fig. 3](../CCES_CHP_Simulink/output/ode/fig03_soc_heat.png)

**Fig. 3. Dual-SOC behaviour and HTV stored heat.** Left: the gas-side SOC (liquid level, 10–90%) and the heat-side SOC rise and fall in phase. Right: the HTV stored heat charges at 12.05 MW for 7.59 h and discharges at 18.28 MW for 5 h, returning to 45 MWh each cycle; the 150 MWh capacity is never reached.

### 3.3 Charging-Heating Feasibility Domain

Under the charging-heating condition, electrical energy consumed by the compressor is converted into thermal energy of the storage medium and potential pressure energy of CO₂. The HTV heat storage must satisfy:

$$Q_{HTV}^{lower} \leq Q_{HTV}(t) \leq Q_{HTV}^{upper}$$

$$0 \leq Q_{heat}(t) \leq Q_{heat}^{max}$$

The boundary of the charging feasibility domain is a polygon formed by the following constraint lines:

$$Q_{heat}(t) = \frac{Q_{HTV}(t-1) - Q_{HTV}^{lower}}{\Delta t} + \gamma_1 W_{C,E}(t) \quad \text{(lower bound)}$$

$$Q_{heat}(t) = \frac{Q_{HTV}(t-1) - Q_{HTV}^{upper}}{\Delta t} + \gamma_1 W_{C,E}(t) \quad \text{(upper bound)}$$

$$Q_{heat}(t) = Q_{heat}^{max} \quad \text{(equipment limit)}$$

$$W_{C,E}(t) = W_{C,E}^{upper} \quad \text{(power limit)}$$

$$W_{C,E}(t) \le \frac{m_{HPT}^{upper} - m_{HPT}(t-1)}{\alpha_1 \Delta t} \quad \text{(inventory limit)}$$

**Key characteristic**: The positive slope +γ₁ indicates electric-thermal **complementarity** during charging — higher charging power produces more compression heat, enabling greater heat supply. The inventory limit becomes active only when the tank approaches its upper bound (above about 89% SOC), where additional charging would overfill the HPT.

The resulting charging-heating domain is sketched in Fig. 4.

![Fig. 4](../CCES_CHP_Analysis/output_figures/Fig01_ChargeHeat_Feasibility.png)

**Fig. 4. Charging-heating feasibility domain.** The positive slope +γ₁ expresses electric-thermal complementarity: a larger charging power raises the heat supply ceiling. The lines are drawn for a representative available-heat level so that the sloped constraint falls inside the plotting window; at high SOC the domain degenerates to the equipment rectangle.

### 3.4 Discharging-Heating Feasibility Domain

Under the discharging-heating condition, the thermal energy of the storage medium and the potential pressure energy of CO₂ are converted into electrical power and direct heat supply. The boundary is determined by:

$$Q_{heat}(t) = \frac{Q_{HTV}(t-1) - Q_{HTV}^{lower}}{\Delta t} - \gamma_2 W_{T,E}(t) \quad \text{(upper bound)}$$

$$Q_{heat}(t) = \frac{Q_{HTV}(t-1) - Q_{HTV}^{upper}}{\Delta t} - \gamma_2 W_{T,E}(t) \quad \text{(lower bound)}$$

$$Q_{heat}(t) = Q_{heat}^{max}, \quad W_{T,E}(t) = W_{T,E}^{upper}$$

$$W_{T,E}(t) \le \frac{m_{HPT}(t-1) - m_{HPT}^{lower}}{\alpha_2 \Delta t} \quad \text{(inventory limit)}$$

**Key characteristic**: The negative slope −γ₂ indicates electric-thermal **competition** during discharging — power generation and heat supply compete for the same limited HTV stored energy. The upper-right corner (maximum power and maximum heat simultaneously) is infeasible.

The resulting discharging-heating domain is sketched in Fig. 5.

![Fig. 5](../CCES_CHP_Analysis/output_figures/Fig02_DischargeHeat_Feasibility.png)

**Fig. 5. Discharging-heating feasibility domain.** The negative slope −γ₂ expresses electric-thermal competition: power generation and heat supply draw on the same thermal budget, so the upper-right corner (simultaneous maxima) is infeasible. The lines are drawn for a representative available-heat level so that the sloped constraint falls inside the plotting window.

The zero-heat maximum power and zero-power maximum heat are:

$$W_{max} = \min\left[\frac{Q_{HTV}(t-1) - Q_{HTV}^{lower}}{\gamma_2 \Delta t},\ \frac{m_{HPT}(t-1) - m_{HPT}^{lower}}{\alpha_2 \Delta t},\ W_{T,E}^{upper}\right], \quad Q_{max} = \frac{Q_{HTV}(t-1) - Q_{HTV}^{lower}}{\Delta t}$$

The inventory limit is active only below about 16% SOC: a 943 t tank discharges 151 t in one hour at 10 MW, so the last hour of a deep discharge becomes inventory-limited while the rest of the domain remains thermal- or equipment-limited.

### 3.5 Effect of Operating Parameters on Feasibility Domain

The heat supply rate X, reflecting the ratio of high and low-temperature heat supply to total heat storage, is related to γ₁, γ₂, α₁, α₂ by:

$$X = 1 - \frac{\gamma_2 \alpha_1}{\gamma_1 \alpha_2}$$

which follows from the cycle energy balance $Q_{IC} t_c = Q_{HR} t_d + Q_{LG} t_d$ combined with the mass balance $\alpha_1 W_{C,E} t_c = \alpha_2 W_{T,E} t_d$. At the design point this gives X = 9.3%, consistent with the thermodynamic evaluation of Section 2.4. Because the dimensionless groups are already defined on electrical power, the motor and generator efficiencies must not be applied a second time in this expression.

The turbine inlet temperature affects the two couplings very differently. Evaluated directly from REFPROP, γ₂ changes only from 1.659 at 483 K to 1.691 at 503 K (+1.9%), because the reheat duty and the turbine work scale together, whereas α₂ falls from 4.191 to 3.993 kg/(s·MW) (−4.7%) as the specific work per kilogram of CO₂ increases. The approximate correction factor proposed in [20] implies a far stronger sensitivity (γ₂ ↓ 23%); that estimate is not adopted here, since the property-based evaluation shows the reheat coefficient to be nearly invariant with temperature. The consequence, quantified in Section 6.4, is that raising T_turb barely reshapes the feasibility domain, but it reduces the mass drawn per unit power and improves the electrical efficiency.

---

## 4. Machine Learning Methodology

### 4.1 Training Data Generation

The training data generation pipeline is implemented in MATLAB, utilizing REFPROP v10.0 for high-fidelity CO₂ property calculations across 15 thermodynamic state nodes. The design of experiments systematically samples the parameter space:

**Table 2. Parameter sampling scheme for training data.**

| Parameter | Range | Steps | Description |
|-----------|-------|-------|-------------|
| SOC_heat | 0–100% | 16 | HTV thermal storage state |
| SOC_gas | 0–100% | 11 | HPT liquid inventory (10–90% usable) |
| W | 0–10 MW | 11 | Power setpoint |
| Q | 0–12.05 MW | 10 | Heat supply setpoint (equipment limit γ₁·W_design) |
| Mode | 0, 1 | 2 | 0 = charge, 1 = discharge |

Total samples: 16 × 11 × 11 × 10 × 2 = **38,720**.

For each parameter combination, the feasibility label and boundary values are computed analytically from the constraint equations:

```
feasible = (Q ≤ slope × W + b_upper) ∧ (Q ≥ slope × W + b_lower)
           ∧ (0 ≤ Q ≤ Q_max) ∧ (0 ≤ W ≤ W_design) ∧ (0 ≤ W ≤ W_inventory)

W_inventory = (m_upper - m)/(α₁Δt)   charging
            = (m - m_lower)/(α₂Δt)   discharging
```

The inventory term is what makes the gas-side state informative: without it the feasibility label is independent of SOC_gas for every parameter combination, and the feature importance of SOC_gas collapses to 0.0015, which is what a purely thermal constraint set yields. With it, 2896 of the 3520 sampled (SOC_heat, SOC_gas, mode, W, Q) groups change their feasibility label across the gas axis.

**Features per sample**: SOC_heat_pct, SOC_gas_pct, W_MW, Q_MW, mode, γ₁, γ₂, α₁, α₂

**Labels per sample**: feasible (0/1), W_max_feasible (MW), Q_max_feasible (MW)

### 4.2 XGBoost Classifier for Feasibility Prediction

XGBoost (eXtreme Gradient Boosting) [21] is employed as the primary classification model for predicting the feasibility of a given (W, Q) operating point. The model hyperparameters are configured as follows: n_estimators = 200, max_depth = 6, learning_rate = 0.1, subsample = 0.8, colsample_bytree = 0.8.

The dataset is split 80/20 (30,976 training / 7,744 test) with stratification on the feasibility label. The feature importance analysis reveals the dominant factors governing feasibility:

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

### 4.3 XGBoost Regressors for Boundary Prediction

Two XGBoost regression models are trained to predict the feasibility domain boundaries: W_max_feasible (maximum feasible power at given SOC) and Q_max_feasible (maximum feasible heat at given SOC). These models are trained on the feasible subset of the data (31,549 samples). Hyperparameters: n_estimators = 150, max_depth = 5, learning_rate = 0.1.

### 4.4 MLP Neural Network for Benchmark Comparison

A multi-layer perceptron (MLP) neural network is trained as a benchmark model. Architecture: 3 hidden layers (128×64×32) with ReLU activation, trained using the Adam optimizer with adaptive learning rate, batch size 256, and maximum 300 epochs. Input features are standardized using StandardScaler.

### 4.5 Model Performance

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

### 4.6 Why Machine Learning?

While the feasibility constraints are analytically linear, the value of ML lies in three aspects:

1. **Inference speed**: A single XGBoost prediction traverses ~200 trees in microseconds, compared to a full REFPROP-based thermodynamic simulation requiring multiple property calls and iterative convergence.

2. **Generalization across parameter space**: Because γ₁, γ₂, α₁ and α₂ enter as input features, the same model architecture can be retrained on a T_turb sweep and then interpolate feasibility across continuous parameter variations without re-running the property-based simulation. The present study uses a single design point and reports the sweep separately in Section 6.4; multi-temperature training is left to future work.

3. **Seamless integration with optimization**: The trained model serves as a fast surrogate constraint that can be queried thousands of times inside a dispatch loop, enabling real-time decision-making.

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
   if Elec_Dispatch(t) > 0: mode = 0 (charge), W_target = min(Elec_Dispatch, 10), Q_target = min(Heat_Dispatch, 12.05)
   else: mode = 1 (discharge), W_target = min(|Elec_Dispatch|, 10), Q_target = min(Heat_Dispatch, 12.05)
3. Generate search grid: W ∈ linspace(0, W_target, 20), Q ∈ linspace(0, Q_target, 15) → 300 candidate points
4. Batch prediction: f_ML(SOC_h, SOC_g, W, Q, mode) for all 300 points
5. Select feasible point with best objective score
6. Update SOC_heat(t+1), SOC_gas(t+1) via thermal balance equations
```

The grid resolution of 20 × 15 = 300 points provides ~0.5 MW granularity for both W and Q, sufficient for practical dispatch decisions. The computational cost is 300 ML predictions per hour × 24 hours = 7,200 predictions, which completes in milliseconds.

### 5.3 Rule-Based Baseline

A rule-based dispatch strategy serves as the comparison baseline. The rule-based approach:
- Always attempts to fully track dispatch instructions
- Clips at equipment limits (W ≤ 10 MW, Q ≤ 12.05 MW)
- Checks HTV SOC constraints analytically without optimization
- Allocates W and Q independently without considering their coupled consumption of the shared thermal budget

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

---

## 6. Results and Discussion

### 6.1 Case Study Configuration

The case study considers an integrated energy system consisting of a 20 MW wind power unit, a 30 MW conventional CHP unit (heat-to-power ratio = 1.2), and a 10 MW/50 MWh CCES-CHP system. A typical day in the heating season is selected, with 24-hour profiles of electrical load, heat load, and wind power as shown in Fig. 6.

**Table 6. 24-hour load and wind power data.**

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

![Fig. 6](../CCES_CHP_Analysis/output_figures/Fig03_LoadWind.png)

**Fig. 6. 24-hour profiles of the electrical load, heat load and wind power.** Wind output peaks overnight, electrical load peaks at noon and in the evening, and the heat load peaks in the morning and evening, leaving charging windows overnight and at the midday trough.

### 6.2 Dispatch Optimization Results

The 24-hour dispatch comparison between rule-based and ML-optimized strategies is presented in Fig. 7 and Table 7.

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

![Fig. 7](data/dispatch_comparison.png)

**Fig. 7. Rule-based versus ML-guided 24-hour dispatch.** Top: electrical dispatch instruction and the achieved charging/discharging power. Middle: heat dispatch instruction and the achieved heat supply. Bottom: HTV thermal SOC. The ML-guided policy keeps a small discharge through hours 18–24 instead of collapsing at hour 17.

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

### 6.3 Where the Dispatch Gain Comes From

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

#### Physical Upper Bound

It is important to note that the full-power, full-heat continuous discharge is physically limited to approximately 5.2 hours:

$$t_{max} = \frac{Q_{HTV}^{upper}}{\gamma_2 \cdot W_{max} + Q_{max}} = \frac{150}{1.659 \times 10 + 12.05} \approx 5.2 \text{ h}$$

The 24-hour "continuous discharge" is achieved through strategic power derating and multiple charge-discharge cycles — not by violating the fundamental energy capacity constraint. This distinguishes the proposed approach from methods that claim to extend capacity without physical basis.

### 6.4 Effect of Turbine Inlet Temperature: Efficiency Rather than Domain Expansion

Beyond dispatch optimization within a fixed domain, the framework also quantifies how an operating parameter reshapes the domain. A property-based sweep shows that the turbine inlet temperature acts mainly on the mass coupling, not on the shape of the feasible region.

#### Mechanism

Two couplings depend on T_turb and they respond in opposite directions:

```
T_turb ↑ → specific work per kg CO₂ ↑ → α₂ ↓  (less mass per MW)      [strong: −4.7%]
          → reheat duty and turbine work scale together → γ₂ ≈ const  [weak:   +1.9%]
```

Because the discharge constraint slope is −γ₂, a near-invariant γ₂ means an almost unchanged (W, Q) domain. What changes is how long a given tank inventory lasts, which scales as 1/α₂.

#### Quantitative Results

**Table 8. Effect of turbine inlet temperature (REFPROP evaluation).**

| Quantity | 483 K (baseline) | 503 K | Change |
|----------|-----------------|-------|--------|
| γ₂ (reheat coefficient) | 1.659 | 1.691 | **+1.9%** |
| α₂ (kg/(s·MW)) | 4.191 | 3.993 | **−4.7%** |
| Maximum power at SOC_heat = 10% (MW) | 9.04 | 8.87 | −1.9% |
| Integrated domain area at SOC_heat = 10% (MW²) | 65.2 | 64.0 | **−1.9%** |
| Full-power discharge duration at fixed inventory (h) | 5.00 | 5.25 | **+5.0%** |
| Electricity-to-electricity efficiency (%) | 65.9 | 69.2 | +3.3 pp |

**Table 9. Integrated feasible domain area at different SOC levels (MW²).**

| SOC_heat (%) | 483 K | 503 K | Change (%) |
|-------------|-------|-------|------------|
| 10 | 65.2 | 64.0 | −1.9 |
| 20 | 120.5 | 120.5 | 0 (equipment-limited) |
| 40 | 120.5 | 120.5 | 0 (equipment-limited) |
| 60 | 120.5 | 120.5 | 0 (equipment-limited) |
| 80 | 120.5 | 120.5 | 0 (equipment-limited) |

At SOC ≥ 20% the discharge domain is bounded by the equipment limits rather than by the heat budget: even at 10 MW the thermal draw (16.6 MW) plus the maximum heat supply (12.05 MW) stays below the one-hour heat availability (30 MW at 20% SOC), so the domain is the full rectangle and the temperature change has no effect. The thermal constraint starts trimming the domain below about 19% SOC and the power limit below about 11% SOC; at 10% SOC a slightly larger γ₂ reduces the area by 1.9%.

The sweep is summarized in Fig. 8.

![Fig. 8](data/feasibility_domain_change.png)

**Fig. 8. Effect of the turbine inlet temperature on the feasibility domain.** Left: γ₂ and α₂ between 460 K and 520 K evaluated with REFPROP. Right: the discharging domain at SOC_heat = 10% for 483 K (grey) and 503 K (blue). The two boundaries nearly coincide; the temperature mainly changes the duration and the efficiency rather than the shape of the domain.

#### Multi-Parameter Sweep

The comparison above holds the isentropic efficiency and the storage pressure fixed. A 175-point design sweep (Th 460–520 K, η_t 0.84–0.92, P_HPT 6.0–7.6 MPa) shows which of the three knobs actually moves the couplings, and it also exposes a limit that the single-temperature study cannot see.

At fixed temperature and pressure, raising η_t from 0.84 to 0.92 lowers γ₂ by 5.7 % (1.670 → 1.574 at 460 K and 6.8 MPa), because less reheat is needed per unit of work. At fixed temperature and efficiency, raising P_HPT from 6.0 to 7.6 MPa raises γ₂ by 3.2 % (1.597 → 1.649). The temperature dependence is the weakest of the three, 0.09–0.11 %/K, i.e. +5–6 % over the 60 K span, which is the quantitative version of the near-invariance claimed in Section 6.4 above.

The discharge domain therefore moves by about ±7 %: its area at SOC_heat = 10 % lies between 60.3 and 69.7 MW² around the 65.2 MW² baseline, and α₂ spans 3.606–4.752 kg s⁻¹ MW⁻¹, which corresponds to 4.41–5.81 h of full-power discharge from the fixed tank inventory. The electrical efficiency spans 58.3–74.2 %.

The sweep also locates a feasibility boundary that the temperature-only study misses. At 32 of the 175 points the heat-closure solution returns a negative external heat supply (X < 0): the reheat duty alone exceeds the compression heat the cycle produces, so the unit can generate power but cannot deliver heat. These points are marked with open symbols in Fig. 9 and excluded from the statistics above. The deficit appears only above 500 K, and it is concentrated at low storage pressure: 13 of the 35 points at 6.0 MPa, 10 at 6.4 MPa, 7 at 6.8 MPa, 2 at 7.2 MPa and none at 7.6 MPa. For the baseline efficiency and pressure (η_t = 0.88, 6.8 MPa) the surplus vanishes at about 517 K.

This gives the turbine inlet temperature a sharper meaning than "efficiency lever". Raising Th from 460 K to 520 K converts a 16.5 % heat surplus into a 2.5 % deficit at the baseline pressure, so the operating envelope has an upper temperature bound imposed by the heat balance rather than by the turbine. Higher storage pressure relaxes that bound, because it enlarges the compression heat per unit of work.

The sweep is shown in Fig. 9.

![Fig. 9](data/fig_parameter_sweep.png)

**Fig. 9. Multi-parameter design sweep.** (a) γ₂ and (b) α₂ against turbine inlet temperature for the five storage pressures at η_t = 0.88; (c) heat supply ratio X for the same slice. Filled markers and solid lines are feasible CHP points; open markers are heat-deficit points (X < 0), which are excluded from the fitted statistics.

#### Physical Interpretation

Under discharge the constraint is

$$Q = -\gamma_2 \cdot W + \frac{Q_{HTV} - Q_{HTV}^{lower}}{\Delta t}$$

At W = 0: Q_max = (Q_HTV − Q_lower)/Δt, unaffected by γ₂.
At Q = 0: W_max = (Q_HTV − Q_lower)/(γ₂·Δt), inversely proportional to γ₂.

Since γ₂ rises slightly with temperature, W_max falls slightly and the domain contracts marginally rather than expanding. The genuine benefit of a higher turbine inlet temperature lies elsewhere: the electrical round-trip efficiency rises from 65.9% to 69.2%, and a given tank inventory supports a 5.0% longer full-power discharge.

#### Implication

Turbine inlet temperature should be selected as an efficiency and duration lever, not as a domain-expansion lever. This also corrects the strong sensitivity implied by the approximate correction factor of [20]: with the coefficient re-evaluated from REFPROP, γ₂ is nearly invariant over the 460–520 K range (1.620–1.717), so the associated “domain expansion” should not be claimed.

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
can actually capture. Since the optimum is saturated for every λ ≥ 1, a planner
who wants maximum heat should weight heat at least as heavily as electricity; at
λ = 0.5 the same optimum delivers 14.7 MWh, i.e. the weight, not the physics,
decides the outcome. Heat supply should therefore be reported as a function of λ
rather than as a single number. The three curves are plotted in Fig. 10.

![Fig. 10](data/fig_lambda_sweep.png)

**Fig. 10. Delivered heat versus the heat weight λ.** Rule-based (circles), ML grid search (squares) and LP optimum (triangles). The rule-based policy is independent of λ; the heuristic saturates at 48.6 MWh and the exact optimum at 52.0 MWh.

### 6.6 Discussion

#### 6.6.1 ML Accuracy and Its Physical Basis

The 100% classification accuracy is expected rather than surprising. The labels are generated by the constraint set itself, so the learning task is to reproduce a known piecewise-linear boundary rather than to discover an unknown one. What the exercise validates is that the surrogate represents that boundary exactly, and can therefore substitute for the property-based evaluation at inference time without loss of accuracy.

The MLP reaches 99.74 ± 0.11 % under the same five folds, with errors concentrated at the corners where the thermal, inventory and equipment limits intersect: the smooth activation rounds off precisely the non-smooth features of the boundary. XGBoost's axis-aligned splits reproduce those corners, which is why it reaches 100.00 %. The 82.01 % of the linear baseline is the complementary statement: the feasible set is an intersection of half-spaces, and no single hyperplane separates it.

#### 6.6.2 From Static Constraint to Controllable Variable

Traditional dispatch optimization treats the feasibility domain as a fixed constraint. The proposed framework transforms it into a controllable variable. The two-level optimization architecture — an outer loop over T_turb (altering α₂, and hence duration and efficiency) and an inner loop over (W, Q) within the domain — enables simultaneous parameter and dispatch optimization. This meta-optimization is made computationally feasible by the ML surrogate models, which provide instantaneous feasibility assessments across the parameter space.

#### 6.6.3 Practical Implications

The longer active discharge (9→16 h) and the increased heat supply (44.0→46.3 MWh, +5.2 %) have direct implications for integrated energy system operation. Specifically: (a) systems with higher renewable penetration benefit from longer energy shifting capability, (b) raising the turbine inlet temperature improves the electrical efficiency by 3.3 percentage points and lengthens the full-power discharge by 5 % at essentially unchanged domain shape, so parameter selection should be driven by efficiency rather than by an assumed domain expansion, (c) the 2.4 % reduction in discharged energy indicates that the same thermal budget is spread over more hours rather than that more energy is delivered, and (d) because the heat gain depends on the weight λ, a tariff-driven objective (λ = heat price / electricity price) is the natural way to make the dispatch economically meaningful.

#### 6.6.4 Limitations and Future Work

Several limitations warrant acknowledgment. First, the training data assumes fixed γ₁, γ₂ per simulation run; the multi-parameter sweep in Section 6.4 is the first step towards variable-parameter training, which would enable continuous optimisation of α₂ (and hence of the duration–efficiency trade-off) inside the dispatch loop. Second, the 20×15 grid search sits 3.8 % from the exact optimum of its own objective; because the problem is linear once the mode is fixed, replacing the heuristic with the LP — or with a receding-horizon MPC — is a modelling choice rather than a computational obstacle, and the gap reported here is the price of keeping the algorithm model-agnostic. Third, the economic objective (time-of-use electricity prices, heat tariffs) is not yet part of the optimisation, although Section 6.5 shows how the weight λ maps onto it. Fourth, multi-period look-ahead optimization (dynamic programming or model predictive control) could replace the greedy hour-by-hour approach, potentially yielding further improvements through inter-temporal coordination. Fifth, the gas-side inventory constraint binds only at the ends of the operating window (below about 16 % SOC on discharge, above about 89 % on charge), because the HPT is sized for five hours of full-power discharge (943 t, 1280 m³); systems with a smaller tank would exhibit stronger dual-SOC coupling over a wider SOC range.

---

## 7. Conclusion

This study presents a machine learning framework for dynamic construction and optimization of the operational feasibility domain of CCES-CHP systems. The main conclusions are:

1. A parameterized feasibility domain representation using dimensionless factors γ₁/γ₂ and ratio parameters α₁/α₂ effectively couples the electrical, thermal, and mass flow domains. The dual SOC model (thermal storage + CO₂ liquid inventory) establishes two-dimensional linear constraint boundaries that define the feasible operating region; the inventory term bounds the instantaneous power at the ends of the operating window and makes the gas-side state physically meaningful.

2. XGBoost and MLP models trained on 38,720 REFPROP-based samples reach
   100.00 ± 0.01 % and 99.74 ± 0.11 % accuracy in feasibility classification
   under five-fold stratified cross-validation, against 82.01 % for a linear
   classifier; boundary regression reproduces W_max and Q_max exactly
   (R² = 1.0000). TreeSHAP attributes 41.5 % and 25.1 % of the prediction to the
   heat and gas states, and dropping the gas-side feature costs 9.3 percentage
   points, confirming that the dual-SOC coupling is physically active.

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

4. A turbine inlet temperature sweep (483 K → 503 K) evaluated with REFPROP shows that γ₂ is nearly invariant (1.659 → 1.691), so the feasible domain area changes by only −1.9% even at low SOC. The real benefit of the higher temperature is a 4.7% reduction in the discharge mass flow per unit power, which extends the full-power discharge duration from 5.00 to 5.25 hours (+5.0%) and raises the electricity-to-electricity efficiency from 65.9% to 69.2%. Operating parameters should therefore be optimized for efficiency and duration rather than for domain expansion.

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
| eval_metric | logloss (default) |

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
| Data generation | MATLAB R2024a + REFPROP v10.0 |
| ML training | Python 3.10, scikit-learn 1.7, XGBoost 3.2 |
| Training time (XGBoost) | < 5 seconds |
| Training time (MLP) | < 30 seconds |
| Inference time (24h dispatch) | < 100 milliseconds |
