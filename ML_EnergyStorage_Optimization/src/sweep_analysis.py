"""
sweep_analysis.py
Analysis of the multi-parameter design sweep (Th x eta_t x P_HPT).

The sweep is produced by CCES_CHP_Simulink/src/ode/design_sweep_multi.m.
Points with X < 0 are heat-deficit operating points: the heat-closure solution
returns a negative external heat supply, i.e. the reheat duty alone already
exceeds the compression heat the cycle produces. They are physically
infeasible for a CHP unit and are excluded from the domain statistics; the
boundary they trace is itself a result (Section 6.4 of the manuscript).

Outputs (../data):
    sweep_summary.csv        one row per (eta_t, P_HPT) with fitted slopes
    fig_parameter_sweep.png  three-panel figure for the manuscript
"""

import os

import numpy as np
import pandas as pd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")

Q_MAX = 12.05          # MW, equipment heat limit
Q_HTV_10 = 0.10 * 150  # MWh available at SOC_heat = 10 %
W_MAX = 10.0           # MW, equipment power limit
M_USABLE = 754.4e3     # kg, 10-90 % HPT window
DT = 1.0

df = pd.read_csv(os.path.join(DATA, "design_sweep_multi.csv"))
print(f"{len(df)} points: Th {df.Th_K.min():.0f}-{df.Th_K.max():.0f} K, "
      f"eta_t {df.eta_t.min():.2f}-{df.eta_t.max():.2f}, "
      f"P_HPT {df.P_HPT_MPa.min():.1f}-{df.P_HPT_MPa.max():.1f} MPa")
df["heat_deficit"] = df["X_pct"] < 0
print(f"heat-deficit points: {df.heat_deficit.sum()} / {len(df)} "
      f"(Th >= {df.loc[df.heat_deficit, 'Th_K'].min():.0f} K)")


def domain_area(gamma2):
    """Area of the discharge domain at SOC_heat = 10 %, same definition as
    feasibility_comparison.py: area under Q = min(Q_max, Q_HTV/dt - gamma2*W)."""
    w = np.linspace(0.0, min(W_MAX, Q_HTV_10 / gamma2), 400)
    q = np.minimum(Q_MAX, np.maximum(0.0, Q_HTV_10 - gamma2 * w))
    return float(np.trapezoid(q, w))


def full_power_duration(alpha2):
    """Hours of full-power discharge supported by the usable inventory."""
    return M_USABLE / (alpha2 * W_MAX * 3600.0)


feas = df[~df.heat_deficit].copy()
feas["area_MW2"] = [domain_area(g) for g in feas.gamma2]
feas["duration_h"] = [full_power_duration(a) for a in feas.alpha2]

# ------------------------------------------------------------------ fit slopes
rows = []
for (eta, P), g in feas.groupby(["eta_t", "P_HPT_MPa"]):
    if g.Th_K.nunique() < 3:
        continue
    x = g.Th_K.values.astype(float)
    lg2 = np.log(g.gamma2.values)
    la2 = np.log(g.alpha2.values)
    s2 = np.polyfit(x, lg2, 1)[0] * 100      # %/K
    sa = np.polyfit(x, la2, 1)[0] * 100
    rows.append({"eta_t": eta, "P_HPT_MPa": P, "n": len(g),
                 "gamma2_460": float(g.loc[g.Th_K == g.Th_K.min(), "gamma2"].mean()),
                 "gamma2_520": float(g.loc[g.Th_K == g.Th_K.max(), "gamma2"].mean()),
                 "dln_gamma2_pct_per_K": float(s2),
                 "alpha2_460": float(g.loc[g.Th_K == g.Th_K.min(), "alpha2"].mean()),
                 "alpha2_520": float(g.loc[g.Th_K == g.Th_K.max(), "alpha2"].mean()),
                 "dln_alpha2_pct_per_K": float(sa),
                 "area_460": float(g.loc[g.Th_K == g.Th_K.min(), "area_MW2"].mean()),
                 "area_520": float(g.loc[g.Th_K == g.Th_K.max(), "area_MW2"].mean()),
                 "duration_460": float(g.loc[g.Th_K == g.Th_K.min(), "duration_h"].mean()),
                 "duration_520": float(g.loc[g.Th_K == g.Th_K.max(), "duration_h"].mean()),
                 "eta_elec_460": float(g.loc[g.Th_K == g.Th_K.min(), "eta_elec_pct"].mean()),
                 "eta_elec_520": float(g.loc[g.Th_K == g.Th_K.max(), "eta_elec_pct"].mean())})
summary = pd.DataFrame(rows).sort_values(["P_HPT_MPa", "eta_t"])
summary.to_csv(os.path.join(DATA, "sweep_summary.csv"), index=False)

print("\nslopes (%/K) and end points, feasible points only:")
print(summary[["eta_t", "P_HPT_MPa", "gamma2_460", "gamma2_520",
               "dln_gamma2_pct_per_K", "alpha2_460", "alpha2_520",
               "dln_alpha2_pct_per_K"]].to_string(index=False,
                                                   float_format=lambda v: f"{v:8.4f}"))

print(f"\ngamma2 over the whole feasible sweep: {feas.gamma2.min():.3f}-{feas.gamma2.max():.3f}")
print(f"alpha2 over the whole feasible sweep: {feas.alpha2.min():.3f}-{feas.alpha2.max():.3f}")
print(f"domain area at SOC 10 %: {feas.area_MW2.min():.1f}-{feas.area_MW2.max():.1f} MW^2")
print(f"full-power duration: {feas.duration_h.min():.2f}-{feas.duration_h.max():.2f} h")
print(f"eta_elec: {feas.eta_elec_pct.min():.1f}-{feas.eta_elec_pct.max():.1f} %")

base = feas[(feas.eta_t == 0.88)]
if len(base):
    print(f"\nbaseline eta_t = 0.88, eta_elec range: "
          f"{base.eta_elec_pct.min():.1f}-{base.eta_elec_pct.max():.1f} %")

# ------------------------------------------------------------------- figure
plt.rcParams.update({"font.size": 9, "axes.grid": True, "grid.alpha": 0.3,
                     "figure.dpi": 200, "savefig.bbox": "tight"})
fig, axes = plt.subplots(1, 3, figsize=(9.8, 3.0))
base_all = df[np.isclose(df.eta_t, 0.88)]
base_ok = base_all[~base_all.heat_deficit]

def panel(ax, col, ylabel):
    for P, g in base_all.groupby("P_HPT_MPa"):
        g = g.sort_values("Th_K")
        ok = g[~g.heat_deficit]
        bad = g[g.heat_deficit]
        ax.plot(ok.Th_K, ok[col], marker="o", ms=2.6, lw=1.0,
                label=f"{P:.1f} MPa")
        if len(bad):
            ax.plot(bad.Th_K, bad[col], ls="none", marker="o", ms=2.6,
                    mfc="none", mec="0.45", mew=0.8)
    ax.set_xlabel("turbine inlet temperature (K)")
    ax.set_ylabel(ylabel)

panel(axes[0], "gamma2", r"$\gamma_2$")
axes[0].legend(frameon=False, fontsize=6.5, title="P$_{HPT}$", title_fontsize=6.5,
               handlelength=1.2, borderaxespad=0.2)
panel(axes[1], "alpha2", r"$\alpha_2$ (kg s$^{-1}$ MW$^{-1}$)")

# (c) heat-deficit boundary: X vs Th, one line per P at eta_t = 0.88
ax = axes[2]
for P, g in base_all.groupby("P_HPT_MPa"):
    g = g.sort_values("Th_K")
    ax.plot(g.Th_K, g.X_pct, marker="o", ms=2.4, lw=1.0)
ax.axhline(0.0, color="k", lw=0.8, ls="--")
ax.fill_between([459, 521], -10, 0, color="tab:red", alpha=0.08)
ax.text(461, -8.0, "heat deficit\n(X < 0)", fontsize=7, color="tab:red")
ax.set_xlabel("turbine inlet temperature (K)")
ax.set_ylabel("heat supply ratio X (%)")
ax.set_ylim(-10, 40)
ax.set_xlim(459, 521)

fig.tight_layout()
fig.savefig(os.path.join(DATA, "fig_parameter_sweep.png"))
print("\nopen markers in (a),(b): heat-deficit points, excluded from the statistics")
print("wrote sweep_summary.csv and fig_parameter_sweep.png")
