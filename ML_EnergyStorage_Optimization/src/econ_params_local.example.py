"""Private economic parameters — NOT committed (see .gitignore).

Copy this file to `econ_params_local.py` in the same directory and uncomment the
lines you want to override. The values are loaded by economics.py, are never
printed and never leave this machine; the published results stay reproducible
from the literature defaults alone.

Only keys that already exist in economics.PARAMS are consumed.
"""
# ruff: noqa
PARAMS = {
    # ---- capital cost (fill in from the project quotation) ----
    # "capex_power_usd_per_kW": 0.0,
    # "capex_energy_usd_per_kWh": 0.0,
    # "capex_thermal_usd_per_kWh_th": 0.0,

    # ---- tariffs actually contracted ----
    # "price_peak_usd_per_MWh": 0.0,
    # "price_valley_usd_per_MWh": 0.0,
    # "price_heat_usd_per_MWh_th": 0.0,

    # ---- financing ----
    # "opex_frac_per_year": 0.025,
    # "discount_rate": 0.07,
    # "life_years": 25,

    # ---- operating schedule ----
    # "operating_days_el": 330,
    # "operating_days_heat": 150,
}
