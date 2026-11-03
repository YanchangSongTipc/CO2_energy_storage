"""
dispatch_optimal_milp.py
Optimality benchmark for the 24-h dispatch.

Two questions a journal reviewer will ask about the conference version:
  (1) how far is the 20x15 ML grid search from the true optimum?
  (2) the reported "+5.2 % heat" is a by-product of a tracking objective with an
      arbitrary weight lambda; what happens when lambda is varied?

Model (linear, heat storage is the only state):
    charge      S(t+1) = S(t) + gamma1*W(t) - Q(t)
    discharge   S(t+1) = S(t) - (gamma2*W(t) + Q(t))
    idle        S(t+1) = S(t) - Q(t)
    0 <= S(t) <= 150 MWh, S(0) = 75 MWh
    0 <= W(t) <= min(|Elec_Dispatch(t)|, 10)
    0 <= Q(t) <= max(0, min(Heat_Dispatch(t), 12.05))
objective  min sum_t |W(t) - Wt(t)| + lambda*|Q(t) - Qt(t)|

Outputs:
    ../data/dispatch_optimality.csv        one row per strategy at lambda = 0.5
    ../data/dispatch_lambda_sweep.csv      heat supply and tracking vs lambda
    ../data/fig_dispatch_optimal.png
    ../data/fig_lambda_sweep.png
"""

import os

import numpy as np
import pandas as pd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.optimize import linprog

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")

W_MAX, Q_MAX, S_MAX, DT = 10.0, 12.05, 150.0, 1.0
G1, G2 = 1.205, 1.659
ALPHA1, ALPHA2 = 2.762, 4.191
M_HPT, M_LOW, M_HIGH = 471.5, 94.3, 848.7
N, S0 = 24, 75.0

Heat_Load = np.array([38, 35, 32, 30, 29, 28, 28, 29, 31, 33, 36, 39,
                      41.5, 41, 40, 38, 37, 35, 40, 42, 41.5, 40, 42, 40])
Elec_Load = np.array([28, 22, 18, 16, 15, 14, 16, 18, 20, 22, 26, 48,
                      48, 48, 45, 30, 28, 24, 32, 48, 48, 48, 48, 35])
Wind_Power = np.array([18, 16, 14, 12, 13, 12, 8, 6, 5, 4, 3, 2,
                       2, 3, 4, 6, 10, 12, 8, 6, 5, 14, 16, 18])

CCHP_heat = np.minimum(Heat_Load, 30 * 1.2)
Heat_Dispatch = Heat_Load - CCHP_heat
Elec_Dispatch = Elec_Load - CCHP_heat / 1.2 - Wind_Power

charging = Elec_Dispatch > 0
discharging = Elec_Dispatch < 0
W_t = np.minimum(np.abs(Elec_Dispatch), W_MAX)
Q_t = np.clip(Heat_Dispatch, 0.0, Q_MAX)


def step_soc(S, W, Q, t):
    if charging[t]:
        return S + G1 * W - Q
    if discharging[t]:
        return S - (G2 * W + Q)
    return S - Q


# ------------------------------------------------------------- heuristics
def run_rule_based():
    S = S0
    W, Q, traj = np.zeros(N), np.zeros(N), [S0]
    for t in range(N):
        avail = S / DT
        if charging[t]:
            W[t] = min(W_t[t], max(0.0, (S_MAX - S) / DT / G1))
            Q[t] = min(Q_t[t], avail + G1 * W[t])
        elif discharging[t]:
            W[t] = min(W_t[t], max(0.0, avail / G2))
            Q[t] = min(Q_t[t], max(0.0, avail - G2 * W[t]))
        else:
            Q[t] = min(Q_t[t], avail)
        S = min(max(step_soc(S, W[t], Q[t], t), 0.0), S_MAX)
        traj.append(S)
    return W, Q, np.array(traj)


def in_domain(t, S, W, Q):
    if W < -1e-9 or Q < -1e-9 or W > W_t[t] + 1e-9 or Q > Q_t[t] + 1e-9:
        return False
    if charging[t]:
        if W > (M_HIGH - M_HPT) / (ALPHA1 * DT) + 1e-9:
            return False
        return (Q <= G1 * W + S / DT + 1e-9) and (Q >= G1 * W - (S_MAX - S) / DT - 1e-9)
    if discharging[t]:
        if W > (M_HPT - M_LOW) / (ALPHA2 * DT) + 1e-9:
            return False
        return Q <= S / DT - G2 * W + 1e-9
    return True


def run_grid(lam=0.5, n_w=20, n_q=15):
    S = S0
    W, Q, traj = np.zeros(N), np.zeros(N), [S0]
    for t in range(N):
        best, bW, bQ = -1e18, 0.0, 0.0
        for w in np.linspace(0, W_t[t], n_w):
            for q in np.linspace(0, Q_t[t], n_q):
                if in_domain(t, S, w, q):
                    score = -(abs(w - W_t[t]) + lam * abs(q - Q_t[t]))
                    if score > best:
                        best, bW, bQ = score, w, q
        W[t], Q[t] = bW, bQ
        S = min(max(step_soc(S, W[t], Q[t], t), 0.0), S_MAX)
        traj.append(S)
    return W, Q, np.array(traj)


# ------------------------------------------------------------------- exact LP
def run_lp(lam=0.5):
    """Exact optimum of the same objective via HiGHS."""
    iW, iQ, iS, iEW, iEQ = 0, N, 2 * N, 3 * N + 1, 4 * N + 1
    nv = 5 * N + 1

    c = np.zeros(nv)
    c[iEW:iEW + N] = 1.0
    c[iEQ:iEQ + N] = lam

    A_eq, b_eq = [], []
    row = np.zeros(nv); row[iS] = 1.0
    A_eq.append(row); b_eq.append(S0)
    for t in range(N):
        row = np.zeros(nv)
        row[iS + t + 1] = 1.0
        row[iS + t] = -1.0
        if charging[t]:
            row[iW + t] = -G1
            row[iQ + t] = 1.0
        elif discharging[t]:
            row[iW + t] = G2
            row[iQ + t] = 1.0
        else:
            row[iQ + t] = 1.0
        A_eq.append(row); b_eq.append(0.0)

    A_ub, b_ub = [], []
    for t in range(N):
        for sign in (1.0, -1.0):
            row = np.zeros(nv); row[iW + t] = sign; row[iEW + t] = -1.0
            A_ub.append(row); b_ub.append(sign * W_t[t])
            row = np.zeros(nv); row[iQ + t] = sign; row[iEQ + t] = -1.0
            A_ub.append(row); b_ub.append(sign * Q_t[t])

    bounds = ([(0.0, W_MAX)] * N + [(0.0, Q_MAX)] * N + [(0.0, S_MAX)] * (N + 1)
              + [(0.0, None)] * N + [(0.0, None)] * N)
    res = linprog(c, A_ub=np.array(A_ub), b_ub=np.array(b_ub),
                  A_eq=np.array(A_eq), b_eq=np.array(b_eq),
                  bounds=bounds, method="highs")
    if not res.success:
        raise RuntimeError(res.message)
    W = res.x[iW:iW + N]
    Q = res.x[iQ:iQ + N]
    S = res.x[iS:iS + N + 1]
    return W, Q, S, res.fun


def metrics(W, Q, S, lam):
    obj = float(np.sum(np.abs(W - W_t) + lam * np.abs(Q - Q_t)))
    # independent re-integration, guards against formulation slips
    S_chk, ok = S0, True
    for t in range(N):
        S_chk = step_soc(S_chk, W[t], Q[t], t)
        if abs(S_chk - S[t + 1]) > 1e-6:
            ok = False
    return {
        "objective": obj,
        "charge_MWh": float(np.sum(W[charging])),
        "discharge_MWh": float(np.sum(W[discharging])),
        "heat_MWh": float(np.sum(Q)),
        "electric_tracking_pct": float(100 * (1 - np.mean(np.abs(W - W_t) / (W_t + 1e-9)))),
        "discharge_hours": int(np.sum(W > 1e-3)),
        "terminal_SOC_pct": float(S[-1] / S_MAX * 100),
        "soc_balance_ok": ok,
    }


# ---------------------------------------------------------- lambda sweep
LAMBDAS = [0.0, 0.25, 0.5, 1.0, 2.0, 5.0]
sweep = []
for lam in LAMBDAS:
    for name, fn in (("Rule-based", lambda l=lam: run_rule_based()),
                     ("ML grid search", lambda l=lam: run_grid(l)),
                     ("LP optimum", lambda l=lam: run_lp(l))):
        out = fn()
        W, Q, S = (out[0], out[1], out[2])
        m = metrics(W, Q, S, lam)
        m.update({"strategy": name, "lambda": lam})
        sweep.append(m)

sw = pd.DataFrame(sweep)
print(sw[["lambda", "strategy", "heat_MWh", "discharge_MWh", "objective",
          "terminal_SOC_pct", "soc_balance_ok"]].to_string(index=False,
                                                           float_format=lambda v: f"{v:9.3f}"))

# ------------------------------------------------- base comparison (lam = 0.5)
base = sw[np.isclose(sw["lambda"], 0.5)].copy()
lp_obj = float(base.loc[base.strategy == "LP optimum", "objective"].iloc[0])
base["gap_vs_LP_pct"] = (base.objective - lp_obj) / lp_obj * 100
cols = ["strategy", "objective", "gap_vs_LP_pct", "charge_MWh", "discharge_MWh",
        "heat_MWh", "discharge_hours", "terminal_SOC_pct", "electric_tracking_pct"]
print("\n" + base[cols].to_string(index=False, float_format=lambda v: f"{v:9.3f}"))

base[cols].to_csv(os.path.join(DATA, "dispatch_optimality.csv"), index=False)
sw.drop(columns=["soc_balance_ok"]).to_csv(
    os.path.join(DATA, "dispatch_lambda_sweep.csv"), index=False)

# ------------------------------------------------------------------- figures
plt.rcParams.update({"font.size": 9, "axes.grid": True, "grid.alpha": 0.3,
                     "figure.dpi": 200, "savefig.bbox": "tight"})
hours = np.arange(N)

W_r, Q_r, S_r = run_rule_based()
W_g, Q_g, S_g = run_grid(0.5)
W_l, Q_l, S_l, _ = run_lp(0.5)

fig, axes = plt.subplots(2, 1, figsize=(6.4, 4.8), sharex=True)
ax = axes[0]
for W, style, lab in ((W_r, "-", "Rule-based"), (W_g, "-", "ML grid search"),
                      (W_l, "--", "LP optimum")):
    ax.step(hours, W, style, where="mid", label=lab)
ax.set_ylabel("power magnitude (MW)")
ax.legend(frameon=False, fontsize=8)
ax = axes[1]
for S, style, lab in ((S_r, "-", "Rule-based"), (S_g, "-", "ML grid search"),
                      (S_l, "--", "LP optimum")):
    ax.step(np.arange(N + 1), S / S_MAX * 100, style, where="post", label=lab)
ax.set_ylabel("heat SOC (%)")
ax.set_xlabel("hour")
ax.legend(frameon=False, fontsize=8)
fig.savefig(os.path.join(DATA, "fig_dispatch_optimal.png"))
plt.close(fig)

fig, ax = plt.subplots(figsize=(4.6, 3.0))
for name in ("Rule-based", "ML grid search", "LP optimum"):
    d = sw[sw.strategy == name]
    ax.plot(d["lambda"], d["heat_MWh"], marker="o", ms=3, label=name)
ax.set_xscale("symlog", linthresh=0.25)
ax.set_xlabel(r"objective weight $\lambda$ on heat deviation")
ax.set_ylabel("delivered heat (MWh)")
ax.legend(frameon=False, fontsize=8)
fig.savefig(os.path.join(DATA, "fig_lambda_sweep.png"))
plt.close(fig)

print("\nwrote dispatch_optimality.csv, dispatch_lambda_sweep.csv and 2 figures")
