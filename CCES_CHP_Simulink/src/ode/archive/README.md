# Archive — 早期 ODE 版本

核心逻辑已整合到 `../ode_dynamics.m` + `../run_ode_simulation.m`。

| 文件 | 说明 | 当前替代 |
|------|------|---------|
| run_dynamic_simulation.m | α/β 集总参数, 不用 REFPROP | ode_dynamics (REFPROP 实时) |
| run_full_simulation.m | 24h 多循环, 可行性域 | run_ode_simulation (21天) |
| run_paper_dispatch.m | 论文负荷曲线 24h 调度 | run_ode_simulation |
| run_tank_thermal.m | HPT 蒸发降温详细模型 | ode_dynamics (T_tank 简化) |
