---
name: cces-chp-project
description: CCES-CHP compressed CO2 energy storage simulation project structure and status
metadata: 
  node_type: memory
  type: project
  originSessionId: 945c4aa2-4c7a-4678-84ce-03129b00d6a9
---

# CCES-CHP Project Overview

## Directory Structure
- `CCES_CHP_Analysis/` — Cycle.m (steady-state REFPROP), PaperReproduction.m
- `CCES_CHP_Simulink/src/ode/` — Main ODE simulation (ode_dynamics.m + run_ode_simulation.m)
- `CCES_CHP_Simulink/src/ode/archive/` — Earlier ODE versions
- `CCES_CHP_Simulink/src/simulink/` — Simulink model (legacy, not maintained)
- `CCES_CHP_Simulink/output/ode/` — Simulation figures and data
- `config_paths.m` — Cross-platform (Windows/Ubuntu) REFPROP path config

## Active Files (the ones that matter)
- `ode_dynamics.m` — 3-state ODE: HPT mass, HTV state, tank temperature
- `run_ode_simulation.m` — 21-day simulation, 3-panel figure output

## REFPROP
- Linux: `/opt/refprop/` (librefprop.so)
- MATLAB wrapper: `/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/`

## Key Commit
Last working state: commit `c0f65f8` — Th=483K, α_ch=2.744, α_dis=4.117, charge 8h, discharge 4h

Why: The project structure is complex with both ODE and Simulink approaches. New sessions should know which files are active vs. archived.
