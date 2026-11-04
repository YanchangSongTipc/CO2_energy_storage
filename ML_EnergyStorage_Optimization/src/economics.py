"""
economics.py
Economic assessment skeleton for the CCES-CHP case study.

Every price and cost below is a PLACEHOLDER taken from the mid-range of recent
CAES/CCES literature (see ECON_ASSUMPTIONS.md). Replace them with project data
in the PARAMS block; the model itself does not change.

The module is deliberately decoupled from the dispatch simulator: it consumes
the daily energy quantities that the dispatch scripts already produce, so the
economics can be re-run for any (rule / ML / LP) strategy or any lambda without
re-solving the dispatch.

Outputs (../data):
    economics_summary.csv        per strategy at the reference assumptions
    economics_sensitivity.csv    LCOE vs capital cost, payback vs price spread
    fig_economics.png            two-panel figure
"""

import os

import numpy as np
import pandas as pd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")

# ---------------------------------------------------------------- assumptions
# TODO: replace with project data; see ECON_ASSUMPTIONS.md for the full source list.
# Literature anchors for the defaults:
#   - large-scale CAES: 500-1200 USD/kW; McIntosh plant 590 USD/kW + 23 USD/kWh
#     (Wikipedia, "Compressed-air energy storage")
#   - CAES energy cost 53 USD/kWh (2016) -> 44 by 2030; sensible liquid thermal
#     storage 22-77 USD/kWh_th (IRENA 2017, Electricity Storage and Renewables,
#     p.30 and Table 12)
#   - published liquid-CO2 CCES case: LCOE 0.0907 USD/kWh
#     (Energy Reports 2022, doi:10.1016/j.egyr.2022.09.021)
# Grid tariffs and heat prices are project-specific and are NOT sourced here.
PARAMS = {
    "P_el_design_MW": 10.0,        # CCES-CHP electrical rating
    "E_el_MWh": 50.0,              # electrical storage capacity
    "E_th_MWh": 150.0,             # HTV thermal capacity
    "capex_power_usd_per_kW": 900.0,    # [500, 1200] CAES range
    "capex_energy_usd_per_kWh": 60.0,   # [23, 100]  above-ground vessel premium
    "capex_thermal_usd_per_kWh_th": 25.0,  # [22, 77] IRENA Table 12
    "opex_frac_per_year": 0.025,   # [0.015, 0.04]
    "discount_rate": 0.07,         # [0.05, 0.10]
    "life_years": 25,
    # Shandong, March 2025: SGCC aggregated purchase tariff, industrial two-part
    # 1-10 kV: peak 1.0475, flat 0.6899, valley 0.3324 CNY/kWh (deep valley 0.2303).
    # Converted at 7.10 CNY/USD.
    "price_peak_usd_per_MWh": 147.5,     # 1.0475 CNY/kWh
    "price_valley_usd_per_MWh": 46.8,    # 0.3324 CNY/kWh
    # Jinan (Shandong) gas-fired industrial steam: 349 CNY/t (Jan 2023 notice);
    # 1 t of steam ~ 0.78 MWh_th, i.e. ~447 CNY/MWh_th.
    "price_heat_usd_per_MWh_th": 63.0,
    "price_co2_usd_per_t": 0.0,        # optional
    "co2_kg_per_MWh": 0.0,             # avoided emissions, if counted
    "operating_days_el": 330,          # arbitrage days per year
    "operating_days_heat": 150,        # heating-season days per year
}

# --------------------------------------------------------------- private input
# Project quotations are usually confidential. Copy econ_params_local.example.py to
# econ_params_local.py (gitignored) and fill in the real numbers there: they are
# loaded here, are never printed and never enter the repository. Everything in this
# file stays at the public literature values, so the published results remain
# reproducible from the paper alone.
_local = os.path.join(HERE, "econ_params_local.py")
overrides = {}
if os.path.exists(_local):
    import importlib.util

    spec = importlib.util.spec_from_file_location("econ_params_local", _local)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    overrides = {k: v for k, v in getattr(mod, "PARAMS", {}).items() if k in PARAMS}
    PARAMS.update(overrides)
    print(f"[economics] {len(overrides)} private parameter(s) loaded from "
          f"{os.path.basename(_local)}; their values are masked in all output")

# daily energy quantities from dispatch_optimality.csv / Table 7
STRATEGIES = {
    "Rule-based": {"charge_MWh": 66.0, "discharge_MWh": 66.6, "heat_MWh": 44.0},
    "ML-guided": {"charge_MWh": 66.0, "discharge_MWh": 65.0, "heat_MWh": 46.3},
    "LP optimum (lambda=1)": {"charge_MWh": 66.0, "discharge_MWh": 61.8, "heat_MWh": 52.0},
}


def crf(rate, years):
    """Capital recovery factor."""
    return rate * (1 + rate) ** years / ((1 + rate) ** years - 1)


def capex(p):
    return (p["capex_power_usd_per_kW"] * p["P_el_design_MW"] * 1e3
            + p["capex_energy_usd_per_kWh"] * p["E_el_MWh"] * 1e3
            + p["capex_thermal_usd_per_kWh_th"] * p["E_th_MWh"] * 1e3)


def assess(p, daily):
    days_el = p["operating_days_el"]
    days_heat = p["operating_days_heat"]
    cap = capex(p)
    opex = p["opex_frac_per_year"] * cap

    e_dis = daily["discharge_MWh"] * days_el
    e_ch = daily["charge_MWh"] * days_el
    q = daily["heat_MWh"] * days_heat

    rev_arb = (e_dis * p["price_peak_usd_per_MWh"]
               - e_ch * p["price_valley_usd_per_MWh"])
    rev_heat = q * p["price_heat_usd_per_MWh_th"]
    rev_co2 = (e_dis * p["co2_kg_per_MWh"] / 1000.0 * p["price_co2_usd_per_t"])
    rev = rev_arb + rev_heat + rev_co2

    annual_cost = crf(p["discount_rate"], p["life_years"]) * cap + opex
    lcoe = annual_cost / e_dis if e_dis else float("nan")          # $/MWh delivered
    lcoh = annual_cost / (e_dis + q) if (e_dis + q) else float("nan")
    net = rev - opex
    payback = cap / net if net > 0 else float("inf")
    npv = -cap + sum(net / (1 + p["discount_rate"]) ** k
                     for k in range(1, p["life_years"] + 1))
    return {
        "capex_MUSD": cap / 1e6,
        "opex_MUSD_per_year": opex / 1e6,
        "revenue_arbitrage_MUSD_per_year": rev_arb / 1e6,
        "revenue_heat_MUSD_per_year": rev_heat / 1e6,
        "revenue_total_MUSD_per_year": rev / 1e6,
        "annual_discharge_MWh": e_dis,
        "annual_heat_MWh": q,
        "LCOE_usd_per_MWh": lcoe,
        "LCOH_usd_per_MWh": lcoh,
        "simple_payback_years": payback,
        "NPV_MUSD": npv / 1e6,
    }


rows = []
for name, daily in STRATEGIES.items():
    r = assess(PARAMS, daily)
    r["strategy"] = name
    rows.append(r)
summary = pd.DataFrame(rows)[
    ["strategy", "capex_MUSD", "opex_MUSD_per_year", "revenue_arbitrage_MUSD_per_year",
     "revenue_heat_MUSD_per_year", "revenue_total_MUSD_per_year", "annual_discharge_MWh",
     "annual_heat_MWh", "LCOE_usd_per_MWh", "LCOH_usd_per_MWh",
     "simple_payback_years", "NPV_MUSD"]]
summary.to_csv(os.path.join(DATA, "economics_summary.csv"), index=False)

print("reference assumptions:")
for k in ("capex_power_usd_per_kW", "capex_energy_usd_per_kWh",
          "capex_thermal_usd_per_kWh_th", "price_peak_usd_per_MWh",
          "price_valley_usd_per_MWh", "price_heat_usd_per_MWh_th",
          "operating_days_el", "operating_days_heat", "discount_rate", "life_years"):
    shown = "private (masked)" if k in overrides else PARAMS[k]
    print(f"  {k:32s} {shown}")
print()
print(summary.to_string(index=False, float_format=lambda v: f"{v:9.2f}"))
if overrides:
    print(f"\nNOTE: {len(overrides)} parameter(s) came from the private override file. "
          "The figures above are for internal use only and must not be published "
          "until they are replaced by the literature values.")

# --------------------------------------------------------------- sensitivity
spread_ref = PARAMS["price_peak_usd_per_MWh"] - PARAMS["price_valley_usd_per_MWh"]
price_spreads = sorted({40, 60, 80, 100, 120, 140, round(spread_ref)})
capex_mults = [0.7, 0.85, 1.0, 1.15, 1.3, 1.5, 1.7, 2.0]
sens_rows = []
for mult in capex_mults:
    p = dict(PARAMS)
    for k in ("capex_power_usd_per_kW", "capex_energy_usd_per_kWh",
              "capex_thermal_usd_per_kWh_th"):
        p[k] *= mult
    for spread in price_spreads:
        p["price_peak_usd_per_MWh"] = p["price_valley_usd_per_MWh"] + spread
        r = assess(p, STRATEGIES["ML-guided"])
        sens_rows.append({"capex_multiplier": mult, "price_spread_usd_per_MWh": spread,
                          "LCOE_usd_per_MWh": r["LCOE_usd_per_MWh"],
                          "payback_years": r["simple_payback_years"],
                          "NPV_MUSD": r["NPV_MUSD"]})
sens = pd.DataFrame(sens_rows)
sens.to_csv(os.path.join(DATA, "economics_sensitivity.csv"), index=False)

# ------------------------------------------------------------- break-even
ref = sens[np.isclose(sens.capex_multiplier, 1.0)].sort_values("price_spread_usd_per_MWh")
be_spread = (float(np.interp(0.0, ref.NPV_MUSD.values, ref.price_spread_usd_per_MWh.values))
             if (ref.NPV_MUSD.min() < 0 < ref.NPV_MUSD.max()) else float("nan"))
ref2 = sens[np.isclose(sens.price_spread_usd_per_MWh, round(spread_ref))].sort_values("capex_multiplier")
be_mult = (float(np.interp(0.0, ref2.NPV_MUSD.values[::-1], ref2.capex_multiplier.values[::-1]))
           if (ref2.NPV_MUSD.min() < 0 < ref2.NPV_MUSD.max()) else float("nan"))
print(f"\nbreak-even peak-valley spread at reference CAPEX : {be_spread:.0f} USD/MWh "
      f"(reference spread {spread_ref:.0f})")
print(f"break-even CAPEX multiplier at reference spread  : {be_mult:.2f} "
      f"({be_mult * capex(PARAMS) / 1e6:.1f} MUSD)")

# ------------------------------------------------------------------- figure
plt.rcParams.update({"font.size": 9, "axes.grid": True, "grid.alpha": 0.3,
                     "figure.dpi": 200, "savefig.bbox": "tight"})
fig, axes = plt.subplots(1, 2, figsize=(8.4, 3.0))

ax = axes[0]
for mult in capex_mults:
    d = sens[sens.capex_multiplier == mult]
    ax.plot(d.price_spread_usd_per_MWh, d.LCOE_usd_per_MWh, marker="o", ms=3,
            label=f"CAPEX x{mult:g}")
ax.set_xlabel("peak-valley price spread (USD/MWh)")
ax.set_ylabel("LCOE (USD/MWh)")
ax.legend(frameon=False, fontsize=7)

ax = axes[1]
for mult in capex_mults:
    d = sens[sens.capex_multiplier == mult]
    ax.plot(d.price_spread_usd_per_MWh, d.payback_years, marker="o", ms=3)
ax.set_xlabel("peak-valley price spread (USD/MWh)")
ax.set_ylabel("simple payback (years)")
ax.set_ylim(0, 40)

fig.tight_layout()
fig.savefig(os.path.join(DATA, "fig_economics.png"))
print("\nwrote economics_summary.csv, economics_sensitivity.csv, fig_economics.png")
