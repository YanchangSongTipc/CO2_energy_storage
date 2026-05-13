"""
dispatch_optimization.py
基于 ML 模型的 CCES-CHP 24h 优化调度
比较: 规则调度 vs ML优化调度
"""

import pickle
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import os

# =========================================================================
# 1. 加载 ML 模型
# =========================================================================
model_dir = os.path.join('..', 'models')
with open(os.path.join(model_dir, 'xgb_classifier.pkl'), 'rb') as f:
    clf = pickle.load(f)

# =========================================================================
# 2. 系统参数
# =========================================================================
W_max = 10.0          # 最大充/放电功率 [MW]
Q_max = 9.5           # 最大供热功率 [MW]
Q_HTV_upper = 150.0   # HTV 储热上限 [MWh]
Q_HTV_lower = 0.0     # HTV 储热下限
dt = 1.0              # 调度步长 [h]
beta1 = 1.205         # 来自热力学模型
beta2 = 2.307
t_charge_design = 7.5
t_discharge_design = 5.0

# =========================================================================
# 3. 24h 负荷与风电数据 (与 PaperReproduction 一致)
# =========================================================================
N_hours = 24
Heat_Load = np.array([38, 35, 32, 30, 29, 28, 28, 29, 31, 33, 36, 39,
                      41.5, 41, 40, 38, 37, 35, 40, 42, 41.5, 40, 42, 40])
Elec_Load = np.array([28, 22, 18, 16, 15, 14, 16, 18, 20, 22, 26, 48,
                      48, 48, 45, 30, 28, 24, 32, 48, 48, 48, 48, 35])
Wind_Power = np.array([18, 16, 14, 12, 13, 12, 8, 6, 5, 4, 3, 2,
                       2, 3, 4, 6, 10, 12, 8, 6, 5, 14, 16, 18])

# C-CHP (以热定电)
CCHP_cap = 30; CCHP_ratio = 1.2
CCHP_heat = np.minimum(Heat_Load, CCHP_cap * CCHP_ratio)
CCHP_elec = CCHP_heat / CCHP_ratio

# 净调度指令
Heat_Dispatch = Heat_Load - CCHP_heat
Elec_Dispatch = Elec_Load - CCHP_elec - Wind_Power
# >0: 需充电, <0: 需放电

# =========================================================================
# 4. ML 可行性预测函数
# =========================================================================
def predict_feasibility(SOC_h, SOC_g, W, Q, mode):
    """用 XGBoost 预测 (W,Q) 在给定 SOC 下是否可行"""
    features = np.array([[SOC_h, SOC_g, W, Q, mode,
                          beta1, beta2, 2.76, 4.19]])  # alpha1, alpha2 ~const
    return clf.predict(features)[0]

def find_optimal_dispatch_ml(SOC_h, SOC_g, elec_dispatch, heat_dispatch):
    """在 ML 预测的可行域内找最优调度点"""
    if elec_dispatch > 0:
        mode = 0  # 充电
        W_target = min(elec_dispatch, W_max)
        Q_target = min(heat_dispatch, Q_max)
    else:
        mode = 1  # 放电
        W_target = min(abs(elec_dispatch), W_max)
        Q_target = min(heat_dispatch, Q_max)

    # 网格搜索最优 (W, Q)
    best_W, best_Q = 0.0, 0.0
    best_score = -1e9

    for W in np.linspace(0, W_target, 20):
        for Q in np.linspace(0, Q_target, 15):
            if predict_feasibility(SOC_h, SOC_g, W, Q, mode):
                # 目标: 最大化跟踪调度指令 (最小化偏差)
                if elec_dispatch > 0:
                    score = -(abs(W - W_target) + 0.5 * abs(Q - Q_target))
                else:
                    score = -(abs(W - W_target) + 0.5 * abs(Q - Q_target))
                if score > best_score:
                    best_score = score
                    best_W, best_Q = W, Q

    return best_W, best_Q, mode

# =========================================================================
# 5. 24h 调度模拟: ML优化 vs 规则调度
# =========================================================================
# 规则调度 (Rule-based)
SOC_h_rule = np.zeros(N_hours + 1); SOC_h_rule[0] = 50.0
W_rule = np.zeros(N_hours); Q_rule = np.zeros(N_hours)

for t in range(N_hours):
    SOC = SOC_h_rule[t]
    Q_HTV = SOC / 100 * Q_HTV_upper

    if Elec_Dispatch[t] > 0:  # 充电
        b_upper = max(0, (Q_HTV - Q_HTV_lower) / dt)
        W_max_feas = min(Elec_Dispatch[t], W_max)
        # HTV约束
        W_htv = max(0, (Q_HTV_upper - Q_HTV) / dt / beta1)
        W_rule[t] = min(W_max_feas, W_htv)
        Q_rule[t] = min(Heat_Dispatch[t], Q_max)
        Q_rule[t] = min(Q_rule[t], b_upper + beta1 * W_rule[t])
        dQ = beta1 * W_rule[t] - Q_rule[t]
    elif Elec_Dispatch[t] < 0:  # 放电
        b_upper = max(0, (Q_HTV - Q_HTV_lower) / dt)
        W_max_feas = min(abs(Elec_Dispatch[t]), W_max)
        W_htv = max(0, (Q_HTV - Q_HTV_lower) / dt / beta2)
        W_rule[t] = min(W_max_feas, W_htv)
        Q_rule[t] = min(Heat_Dispatch[t], Q_max)
        Q_rule[t] = min(Q_rule[t], max(0, b_upper - beta2 * W_rule[t]))
        dQ = -(beta2 * W_rule[t] + Q_rule[t])
    else:
        dQ = -min(Heat_Dispatch[t], Q_HTV / dt)

    SOC_h_rule[t+1] = max(0, min(100, SOC + dQ / Q_HTV_upper * 100))

# ML优化调度
SOC_h_ml = np.zeros(N_hours + 1); SOC_h_ml[0] = 50.0
W_ml = np.zeros(N_hours); Q_ml = np.zeros(N_hours)

for t in range(N_hours):
    W_ml[t], Q_ml[t], mode = find_optimal_dispatch_ml(
        SOC_h_ml[t], 50.0, Elec_Dispatch[t], Heat_Dispatch[t])

    if mode == 0:  # 充电
        dQ = beta1 * W_ml[t] - Q_ml[t]
    else:  # 放电
        dQ = -(beta2 * W_ml[t] + Q_ml[t])

    SOC_h_ml[t+1] = max(0, min(100, SOC_h_ml[t] + dQ / Q_HTV_upper * 100))

# =========================================================================
# 6. 结果可视化
# =========================================================================
fig, axes = plt.subplots(3, 1, figsize=(12, 10))

t = np.arange(1, N_hours + 1)

# 电力
ax = axes[0]
ax.bar(t, Elec_Dispatch, color='lightgray', alpha=0.5, label='Elec Dispatch')
ax.plot(t, W_rule, 'b-o', ms=5, label='Rule-based')
ax.plot(t, W_ml, 'r-s', ms=5, label='ML-Optimized')
ax.plot(t, -W_rule * (Elec_Dispatch < 0), 'b--o', ms=3, alpha=0.3)
ax.axhline(y=W_max, color='k', ls='--', alpha=0.3)
ax.axhline(y=-W_max, color='k', ls='--', alpha=0.3)
ax.set_ylabel('Power [MW]')
ax.legend(loc='best', fontsize=8)
ax.set_title('CCES-CHP 24h Dispatch: Rule-based vs ML-Optimized')
ax.grid(True, alpha=0.3)

# 供热
ax = axes[1]
ax.bar(t, Heat_Dispatch, color='orange', alpha=0.3, label='Heat Dispatch')
ax.plot(t, Q_rule, 'b-o', ms=5, label='Rule-based')
ax.plot(t, Q_ml, 'r-s', ms=5, label='ML-Optimized')
ax.set_ylabel('Heat [MW]')
ax.legend(loc='best', fontsize=8)
ax.grid(True, alpha=0.3)

# SOC 演化
ax = axes[2]
ax.plot(t, SOC_h_rule[:N_hours], 'b-o', ms=5, label='Rule-based SOC')
ax.plot(t, SOC_h_ml[:N_hours], 'r-s', ms=5, label='ML-Optimized SOC')
ax.fill_between(t, 0, 100, color='green', alpha=0.05)
ax.axhline(y=0, color='r', ls='--', alpha=0.5)
ax.axhline(y=100, color='r', ls='--', alpha=0.5)
ax.set_xlabel('Time [h]')
ax.set_ylabel('Heat SOC [%]')
ax.legend(loc='best', fontsize=8)
ax.grid(True, alpha=0.3)

plt.tight_layout()
out_path = os.path.join('..', 'data', 'dispatch_comparison.png')
plt.savefig(out_path, dpi=150)
print(f'调度对比图已保存: {out_path}')

# =========================================================================
# 7. 性能指标对比
# =========================================================================
E_charge_rule = np.sum(W_rule * (Elec_Dispatch > 0))
E_discharge_rule = np.sum(W_rule * (Elec_Dispatch < 0))
E_charge_ml = np.sum(W_ml * (Elec_Dispatch > 0))
E_discharge_ml = np.sum(W_ml * (Elec_Dispatch < 0))

Q_total_rule = np.sum(Q_rule)
Q_total_ml = np.sum(Q_ml)

print('\n=== 调度性能对比 ===')
print(f'{"指标":25s} {"规则调度":>12s} {"ML优化":>12s}')
print('-' * 50)
print(f'{"总充电量 [MWh]":25s} {E_charge_rule:12.1f} {E_charge_ml:12.1f}')
print(f'{"总放电量 [MWh]":25s} {E_discharge_rule:12.1f} {E_discharge_ml:12.1f}')
print(f'{"总供热量 [MWh]":25s} {Q_total_rule:12.1f} {Q_total_ml:12.1f}')
print(f'{"放电时长 [h]":25s} {np.sum(W_rule>0):12.0f} {np.sum(W_ml>0):12.0f}')
print(f'{"末态 SOC [%]":25s} {SOC_h_rule[-1]:12.1f} {SOC_h_ml[-1]:12.1f}')

# 调度指令跟踪率
track_elec_rule = 1 - np.mean(np.abs(W_rule - np.abs(Elec_Dispatch)) / (np.abs(Elec_Dispatch) + 1e-6))
track_elec_ml = 1 - np.mean(np.abs(W_ml - np.abs(Elec_Dispatch)) / (np.abs(Elec_Dispatch) + 1e-6))
print(f'{"电调度跟踪率":25s} {track_elec_rule*100:11.1f}% {track_elec_ml*100:11.1f}%')
