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
