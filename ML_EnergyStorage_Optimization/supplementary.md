# Supplementary Material

**Machine-learning construction and economic assessment of the operational
feasibility domain of a compressed CO2 energy storage combined heat and power system**

Yanchang Song, Zhentao Zhang, Junling Yang

This file contains the tables that are referred to in the main text but not printed there.
Table numbers are prefixed with S.

---

**Table S1. 24-hour load, electrical load and wind power.**

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

---

**Table S2. Integrated feasible-domain area at different SOC levels (MW²).**

| SOC_heat (%) | 483 K | 503 K | Change (%) |
|-------------|-------|-------|------------|
| 10 | 65.2 | 64.0 | −1.9 |
| 20 | 120.5 | 120.5 | 0 (equipment-limited) |
| 40 | 120.5 | 120.5 | 0 (equipment-limited) |
| 60 | 120.5 | 120.5 | 0 (equipment-limited) |
| 80 | 120.5 | 120.5 | 0 (equipment-limited) |

---

**Table S3. XGBoost classifier hyperparameters.**

| Parameter | Value |
|-----------|-------|
| n_estimators | 200 |
| max_depth | 6 |
| learning_rate | 0.1 |
| subsample | 0.8 |
| colsample_bytree | 0.8 |
| eval_metric | logloss (default) |

**Table S4. MLP classifier hyperparameters.**

| Parameter | Value |
|-----------|-------|
| hidden_layer_sizes | (128, 64, 32) |
| activation | ReLU |
| solver | Adam |
| alpha (L2 regularization) | 0.001 |
| batch_size | 256 |
| learning_rate | adaptive |
| max_iter | 300 |

**Table S5. Computational resources.**

| Component | Specification |
|-----------|--------------|
| Data generation | MATLAB R2024a + REFPROP v10.0 |
| ML training | Python 3.10, scikit-learn 1.7, XGBoost 3.2 |
| Training time (XGBoost) | < 5 s |
| Training time (MLP) | < 30 s |
| Inference time (24 h dispatch) | < 100 ms |

## S6. Component models of the CCES-CHP cycle

The two compressor stages and the two turbine stages are treated as polytropic machines with constant isentropic efficiencies, and the intercoolers, the reheaters and the evaporator as steady-flow heat exchangers. With N_C = N_T = 2 stages, a polytropic index n = 1.3, R_g = 0.1889 kJ kg⁻¹ K⁻¹, compressor and turbine isentropic efficiencies of 0.85 and 0.88, and motor and generator efficiencies of 0.98 and 0.95, the model used in the main text is:

**(S1) Compressor shaft power**

$$W_C(t) = \sum_{i=1}^{N_C} \frac{n R_g m_C(t) T_{C,i}^{in}}{n-1} \frac{(\beta_{C,i})^{\frac{n-1}{n}}-1}{\eta_{C,i}}$$

where m_C(t) is the CO₂ mass flow, T_{C,i}^{in} the inlet temperature of stage i and β_{C,i} its pressure ratio.

**(S2) Compressor electrical power**

$$W_{C,E}(t) = \frac{W_{C1}(t)}{\eta_{C,E}^1} + \frac{W_{C2}(t)}{\eta_{C,E}^2}$$

**(S3) Turbine shaft power**

$$W_T(t) = \sum_{i=1}^{N_T} \frac{n R_g m_T(t) T_{T,i}^{in}}{n-1} \left[1 - (\beta_{T,i})^{-\frac{n-1}{n}}\right] \eta_{T,i}$$

**(S4) Turbine electrical power**

$$W_{T,E}(t) = \eta_{T,E}^1 W_{T1}(t) + \eta_{T,E}^2 W_{T2}(t)$$

**(S5) Compression heat collected by the intercoolers**

$$Q_{IC}(t) = m_C(t) \left[\sum_{i=1}^{N_C-1} (h_{C,i}^{out} - h_{C,i+1}^{in}) + (h_{C,N_C}^{out} - h_{IC-end})\right]$$

**(S6) Reheat duty of HR1 and HR2**

$$Q_{HR}(t) = m_T(t) \left[\sum_{i=1}^{N_T-1} (h_{T,i+1}^{in} - h_{T,i}^{out}) + (h_{T,1}^{in} - h_{HR-start})\right]$$

Evaluated at the design point of Table 1, these relations give 9.74 MW of compression power, 9.62 MW of turbine output and 11.73 MW_th of recovered compression heat, which are the values used throughout the main text.

## S7. Dispatch algorithm

**Algorithm S1. ML-guided dispatch for each hour t.**

```
1. Read the current states: SOC_heat(t), SOC_gas(t)
2. Fix the mode and the targets:
   if Elec_Dispatch(t) > 0: mode = 0 (charge), W_target = min(Elec_Dispatch, 10),
                            Q_target = min(Heat_Dispatch, 12.05)
   else:                    mode = 1 (discharge), W_target = min(|Elec_Dispatch|, 10),
                            Q_target = min(Heat_Dispatch, 12.05)
3. Build the grid: W in linspace(0, W_target, 20), Q in linspace(0, Q_target, 15),
   i.e. 300 candidate points
4. Score every candidate with the classifier f_ML(SOC_heat, SOC_gas, W, Q, mode)
5. Keep the feasible candidate with the best objective value
6. Propagate SOC_heat(t+1) and SOC_gas(t+1) with the balances of Section 3.2
```

Steps 3–5 cost 300 classifier calls per hour, or 7,200 per day, which completes in milliseconds and is the reason the surrogate is used instead of the property-based domain construction.

## S8. Feasibility label and feature definitions

For every sampled (SOC_heat, SOC_gas, W, Q, mode) combination the feasibility label and the two boundary values are computed analytically from the constraint set of Section 3. The predicate is

```
feasible = (Q <= slope * W + b_upper) AND (Q >= slope * W + b_lower)
           AND (0 <= Q <= Q_max) AND (0 <= W <= W_design)
           AND (0 <= W <= W_inventory)

W_inventory = (m_upper - m) / (alpha_1 * dt)   charging
            = (m - m_lower) / (alpha_2 * dt)   discharging
```

with slope = +γ₁ and b_upper = (Q_HTV − Q_lower)/Δt during charging, and slope = −γ₂ and b_upper = (Q_HTV − Q_lower)/Δt during discharging. The two regression targets are the zero-heat maximum power (W_max, the smallest of the thermal, inventory and equipment limits) and the zero-power maximum heat (Q_max, the available heat divided by Δt).

| Item | Values |
|---|---|
| Features (9) | SOC_heat_pct, SOC_gas_pct, W_MW, Q_MW, mode, γ₁, γ₂, α₁, α₂ |
| Labels (3) | feasible (0/1), W_max_feasible (MW), Q_max_feasible (MW) |
| Samples | 16 × 11 × 11 × 10 × 2 = 38,720 |
| Train / test split | 80 / 20, stratified on the feasibility label |
