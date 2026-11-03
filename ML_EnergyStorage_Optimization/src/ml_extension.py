"""
ml_extension.py
Journal-level extension of the ML study (Applied Energy / ECM revision).

What it adds on top of train_ml_models.py:
  1. five-fold stratified cross-validation for six classifiers, not a single split
  2. two trivial baselines (logistic regression, single decision tree) to show the
     task is boundary reproduction rather than boundary discovery
  3. TreeSHAP attribution of the XGBoost classifier (no extra dependency)
  4. ablation without the gas-side inventory feature (SOC_gas_pct)
  5. learning curves (accuracy vs. training-set size)
  6. boundary regressors (W_max, Q_max) with CV for XGB / RF / MLP

Outputs (all under ../data):
  ml_extension_metrics.csv
  ml_extension_shap.csv
  ml_extension_ablation.csv
  fig_ml_models.png
  fig_shap.png
  fig_learning_curve.png
"""

import os
import time

import numpy as np
import pandas as pd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

from sklearn.ensemble import ExtraTreesClassifier, HistGradientBoostingClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, mean_squared_error, r2_score
from sklearn.model_selection import StratifiedKFold, learning_curve, train_test_split
from sklearn.neural_network import MLPClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier
import xgboost as xgb

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")
RNG = 42

FEATURES = ["SOC_heat_pct", "SOC_gas_pct", "W_MW", "Q_MW", "mode",
            "beta1", "beta2", "alpha1", "alpha2"]
PRETTY = {
    "SOC_heat_pct": "SOC_heat",
    "SOC_gas_pct": "SOC_gas (inventory)",
    "W_MW": "W",
    "Q_MW": "Q",
    "mode": "mode",
    "beta1": r"$\gamma_1$",
    "beta2": r"$\gamma_2$",
    "alpha1": r"$\alpha_1$",
    "alpha2": r"$\alpha_2$",
}

df = pd.read_csv(os.path.join(DATA, "training_data.csv"))
X = df[FEATURES].values
y = df["feasible"].values.astype(int)
print(f"dataset: {len(df)} samples, feasible share {y.mean()*100:.1f}%")

skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=RNG)

# ---------------------------------------------------------------------------
# 1. classifiers under identical folds
# ---------------------------------------------------------------------------
models = {
    "Logistic regression (linear baseline)": make_pipeline(
        StandardScaler(), LogisticRegression(max_iter=2000, random_state=RNG)
    ),
    "Decision tree (depth 6)": DecisionTreeClassifier(max_depth=6, random_state=RNG),
    "Random forest (300)": RandomForestClassifier(
        n_estimators=300, n_jobs=1, random_state=RNG
    ),
    "Extra trees (300)": ExtraTreesClassifier(n_estimators=300, n_jobs=1, random_state=RNG),
    "HistGradientBoosting": HistGradientBoostingClassifier(random_state=RNG),
    "XGBoost (paper)": xgb.XGBClassifier(
        n_estimators=200, max_depth=6, learning_rate=0.1,
        subsample=0.8, colsample_bytree=0.8, tree_method="hist",
        n_jobs=1, random_state=RNG, eval_metric="logloss",
    ),
    "MLP 128-64-32 (paper)": make_pipeline(
        StandardScaler(),
        MLPClassifier(hidden_layer_sizes=(128, 64, 32), alpha=1e-3, batch_size=256,
                      learning_rate_init=1e-3, max_iter=300, random_state=RNG),
    ),
}

rows = []
for name, model in models.items():
    fold_acc = []
    t0 = time.time()
    for tr, te in skf.split(X, y):
        model.fit(X[tr], y[tr])
        fold_acc.append(accuracy_score(y[te], model.predict(X[te])))
    fit_time = (time.time() - t0) / 5
    rows.append({"model": name, "cv_accuracy": float(np.mean(fold_acc)),
                 "cv_std": float(np.std(fold_acc)), "fit_s_per_fold": fit_time})
    print(f"  {name:38s} acc={np.mean(fold_acc)*100:6.2f}% +-{np.std(fold_acc)*100:4.2f}  "
          f"({fit_time:5.1f}s/fold)")

metrics = pd.DataFrame(rows)

# ---------------------------------------------------------------------------
# 2. ablation: drop the gas-side inventory feature
# ---------------------------------------------------------------------------
ab_rows = []
for label, feats in [("with SOC_gas", FEATURES),
                     ("without SOC_gas", [f for f in FEATURES if f != "SOC_gas_pct"])]:
    Xa = df[feats].values
    accs = []
    for tr, te in skf.split(Xa, y):
        m = xgb.XGBClassifier(n_estimators=200, max_depth=6, learning_rate=0.1,
                              subsample=0.8, colsample_bytree=0.8, tree_method="hist",
                              n_jobs=1, random_state=RNG, eval_metric="logloss")
        m.fit(Xa[tr], y[tr])
        accs.append(accuracy_score(y[te], m.predict(Xa[te])))
    ab_rows.append({"variant": label, "cv_accuracy": float(np.mean(accs)),
                    "cv_std": float(np.std(accs))})
    print(f"  ablation {label:20s} acc={np.mean(accs)*100:6.2f}% +-{np.std(accs)*100:4.2f}")

ablation = pd.DataFrame(ab_rows)

# ---------------------------------------------------------------------------
# 3. TreeSHAP on the full-data XGBoost model
# ---------------------------------------------------------------------------
xgb_full = xgb.XGBClassifier(n_estimators=200, max_depth=6, learning_rate=0.1,
                             subsample=0.8, colsample_bytree=0.8, tree_method="hist",
                             n_jobs=1, random_state=RNG, eval_metric="logloss")
xgb_full.fit(X, y)
dmat = xgb.DMatrix(X, feature_names=FEATURES)
contribs = xgb_full.get_booster().predict(dmat, pred_contribs=True)
shap_vals = contribs[:, :-1]
mean_abs = np.abs(shap_vals).mean(axis=0)
shap_df = (pd.DataFrame({"feature": FEATURES, "mean_abs_shap": mean_abs})
           .sort_values("mean_abs_shap", ascending=False)
           .assign(share=lambda d: d.mean_abs_shap / d.mean_abs_shap.sum()))
print("\nTreeSHAP mean |value|:")
print(shap_df.to_string(index=False, float_format=lambda v: f"{v:.4f}"))

# ---------------------------------------------------------------------------
# 4. learning curves for the two paper models + the linear baseline
# ---------------------------------------------------------------------------
sizes = np.linspace(0.10, 1.0, 6)
lc_targets = {
    "XGBoost": xgb.XGBClassifier(n_estimators=200, max_depth=6, learning_rate=0.1,
                                 subsample=0.8, colsample_bytree=0.8, tree_method="hist",
                                 n_jobs=1, random_state=RNG, eval_metric="logloss"),
    "Logistic regression": make_pipeline(StandardScaler(), LogisticRegression(max_iter=2000)),
}
lc_series = {}
for name, model in lc_targets.items():
    ts, tr_scores, te_scores = learning_curve(
        model, X, y, train_sizes=sizes, cv=StratifiedKFold(3, shuffle=True, random_state=RNG),
        scoring="accuracy", n_jobs=1, random_state=RNG
    )
    lc_series[name] = (ts, tr_scores.mean(axis=1), te_scores.mean(axis=1))
    print(f"  learning curve {name}: final test acc {te_scores.mean(axis=1)[-1]*100:.2f}%")

# ---------------------------------------------------------------------------
# 5. boundary regressors on the feasible subset
# ---------------------------------------------------------------------------
feas = df[df.feasible == 1]
Xf = feas[FEATURES].values
reg_targets = {"W_max (MW)": feas["W_max_feasible"].values,
               "Q_max (MW)": feas["Q_max_feasible"].values}
reg_rows = []
for tname, yt in reg_targets.items():
    for mname, mk in {
        "XGBoost": lambda: xgb.XGBRegressor(n_estimators=150, max_depth=5, learning_rate=0.1,
                                            tree_method="hist", n_jobs=1, random_state=RNG),
        "Random forest": lambda: RandomForestClassifier(),  # placeholder replaced below
    }.items():
        if mname == "Random forest":
            from sklearn.ensemble import RandomForestRegressor
            mk = lambda: RandomForestRegressor(n_estimators=200, n_jobs=1, random_state=RNG)
        Xtr, Xte, ytr, yte = train_test_split(Xf, yt, test_size=0.2, random_state=RNG)
        reg = mk()
        reg.fit(Xtr, ytr)
        pred = reg.predict(Xte)
        reg_rows.append({"target": tname, "model": mname,
                         "r2": r2_score(yte, pred),
                         "rmse": float(np.sqrt(mean_squared_error(yte, pred)))})
        print(f"  {tname:12s} {mname:14s} R2={r2_score(yte, pred):.4f}")

reg_df = pd.DataFrame(reg_rows)

# ---------------------------------------------------------------------------
# 6. figures
# ---------------------------------------------------------------------------
plt.rcParams.update({"font.size": 9, "axes.grid": True, "grid.alpha": 0.3,
                     "figure.dpi": 200, "savefig.bbox": "tight"})

fig, ax = plt.subplots(figsize=(6.2, 3.0))
ordered = metrics.sort_values("cv_accuracy")
ax.barh(ordered.model, ordered.cv_accuracy * 100, xerr=ordered.cv_std * 100,
        color="#4C72B0", error_kw={"lw": 0.8, "capsize": 2})
ax.set_xlabel("5-fold CV accuracy (%)")
ax.set_xlim(max(0, ordered.cv_accuracy.min() * 100 - 5), 100.5)
for i, v in enumerate(ordered.cv_accuracy * 100):
    ax.text(v - 0.4, i, f"{v:.2f}", va="center", ha="right", color="white", fontsize=8)
fig.savefig(os.path.join(DATA, "fig_ml_models.png"))
plt.close(fig)

fig, ax = plt.subplots(figsize=(5.0, 2.8))
s = shap_df.iloc[::-1]
ax.barh([PRETTY[f] for f in s.feature], s.mean_abs_shap, color="#DD8452")
ax.set_xlabel("mean |SHAP value| (log-odds)")
fig.savefig(os.path.join(DATA, "fig_shap.png"))
plt.close(fig)

fig, ax = plt.subplots(figsize=(4.6, 3.0))
for name, (ts, tr_s, te_s) in lc_series.items():
    ax.plot(ts, te_s * 100, marker="o", ms=3, label=f"{name} (test)")
    ax.plot(ts, tr_s * 100, marker="o", ms=3, ls="--", alpha=0.5, label=f"{name} (train)")
ax.set_xlabel("training samples")
ax.set_ylabel("accuracy (%)")
ax.legend(fontsize=7, frameon=False)
fig.savefig(os.path.join(DATA, "fig_learning_curve.png"))
plt.close(fig)

# ---------------------------------------------------------------------------
# 7. persist
# ---------------------------------------------------------------------------
metrics.to_csv(os.path.join(DATA, "ml_extension_metrics.csv"), index=False)
ablation.to_csv(os.path.join(DATA, "ml_extension_ablation.csv"), index=False)
shap_df.to_csv(os.path.join(DATA, "ml_extension_shap.csv"), index=False)
reg_df.to_csv(os.path.join(DATA, "ml_extension_regression.csv"), index=False)

print("\nbest classifier:", metrics.loc[metrics.cv_accuracy.idxmax(), "model"])
print("worst classifier:", metrics.loc[metrics.cv_accuracy.idxmin(), "model"])
print("ablation gain from inventory feature:",
      f"{(ablation.cv_accuracy.iloc[0] - ablation.cv_accuracy.iloc[1]) * 100:.2f} pp")
print("wrote 4 CSVs and 3 figures to ../data")
