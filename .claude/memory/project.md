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
- `CCES_CHP_Analysis/` — Cycle.m (steady-state REFPROP), PaperReproduction.m（论文复现 + 16 张图）
- `CCES_CHP_Simulink/src/ode/` — 主线 ODE（cces_design_point / cces_schedule / ode_dynamics / run_ode_simulation）
- `CCES_CHP_Simulink/src/ode/archive/` — 早期 ODE 版本（勿用）
- `CCES_CHP_Simulink/src/simulink/` — Simulink 模型（legacy，不维护）
- `CCES_CHP_Simulink/output/ode/` — 当前 4 张图（fig01~04）
- `CCES_CHP_Simulink/output/simulink/` — 旧路线输出，已失效，勿引用
- `ML_EnergyStorage_Optimization/` — ML 代理 + 24h 调度（2026-11 已按新 γ₂ 重生成并重训）
- `config_paths.m` — 跨平台 REFPROP 路径配置

## Active Files (the ones that matter)
- `cces_design_point.m` — 设计点单一真源：REFPROP 现算每 kg 功/热、α/γ、闭合时长、罐容
- `ode_dynamics.m` — 2 状态 ODE（HPT 储液质量 kg + HTV 蓄热 MJ），定压液态储罐
- `run_ode_simulation.m` — 21 天仿真 + 物理闭合校验（PASS/FAIL）+ 4 张图

## Current Design Point (Th = 483 K, REFPROP)
α1=2.762, α2=4.191, γ1=1.205, γ2=1.659, 充/放 7.587/5.0 h, 循环质量 754.4 t,
V_HPT=1280 m³（满液 943 t）, Q_HTV=150 MWh, Q_export=1.69 MW (X=9.2%), 电-电效率 65.9%。
闭合校验：质量漂移 0.56 kg/日、热量漂移 6.8e-5 MWh/日、无削峰。

## REFPROP
- Linux: `/opt/refprop/` (librefprop.so)
- MATLAB wrapper: `/home/lab206/code/Matlab/matlab-interface-refprop-coolprop-main/`
- 无显示环境下运行 MATLAB 需设 `MATLAB_PREFDIR` 到可写目录，否则启动即失败

Why: 三条线（Cycle / ODE / ML）曾经各写一份参数而漂移。现在 ODE 由 cces_design_point 统一供参；
ML 侧的 γ₂ 仍是旧的（2.307），重生成训练数据前不要拿 ML 结果与 ODE 对比。
