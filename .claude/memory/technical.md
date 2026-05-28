---
name: cces-technical-insights
description: CCES-CHP thermodynamic model key technical findings
metadata: 
  node_type: memory
  type: project
  originSessionId: 945c4aa2-4c7a-4678-84ce-03129b00d6a9
---

# CCES-CHP Technical Insights

## Alpha Coefficient Derivation
α = m_dot / W = 1000 / Δh_specific [kg/(s·MW)] — NOT empirical, derived from power equation.
- α_ch = 2.744 (compressor: 355 kJ/kg)
- α_dis = 4.117 (turbine: 251 kJ/kg at 483K)
- α_dis > α_ch because w_turb < w_comp (isentropic losses)

## Heat Balance Problem
At Th=483K: q_IC=436 kJ/kg, q_HR=541 kJ/kg. Ratio=1.24.
- Mass balance and heat balance CANNOT be simultaneously achieved with fixed α and T_heat.
- For heat balance at rated power: need external heat OR lower T_heat (~405K where q_HR≈436).
- For mass+heat balance with rated power: turbine must drop to ~8.6 MW.

## HPT Model Evolution
1. Ideal gas P=mRT/V → rejected (two-phase physics)
2. Two-phase P=P_sat(T) → accepted
3. Temperature drift debate → resolved: T returns to ambient each cycle, no net drift
4. Current: P=P_sat(T_tank), T_tank varies ±10K during charge/discharge

## HTV Model Evolution
1. Empirical T_heat = f(Q) → rejected
2. Single-tank variable T → T_heat varies, turbine power unstable
3. Two-tank (hot 573K/cold 298K) → T_heat constant, but q_HR >> q_IC
4. Current: Two-tank Th=483K, accepts constraint-bounded operation

## Energy Balance Closure
Turbine exit (361K) → Cooler → Compressor inlet (298K, 0.102MPa).
56 kJ/kg rejected to environment. Cycle IS closed thermodynamically.
RTE per kg = 251/355 = 70.8% (matches Cycle.m).

## Key Physical Constraints
1. P_ok_ch = m_HPT < m_sat_liq × 0.995 (HPT not overfilled)
2. P_ok_dis = m_HPT > m_sat_vap × 1.05 (HPT has liquid)
3. Q_ok_ch = V_hot < 0.90 V_total (hot tank not full)
4. Q_ok_dis = V_hot > 0.10 V_total (hot tank not empty)

## Cross-Platform
`config_paths.m` in root handles Windows/Ubuntu REFPROP path switching.

Why: This conversation uncovered fundamental thermodynamic constraints (heat-mas imbalance, α derivation, two-phase HPT physics) that future sessions must understand to continue work.
