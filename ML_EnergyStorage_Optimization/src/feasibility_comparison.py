"""
feasibility_comparison.py
对比: 固定透平入口温度 vs ML优化调节透平入口温度后的可行域变化

核心逻辑:
- 提高透平入口温度 → 单位CO2做功增强 → β2下降 → 同样发电消耗回热减少
- → 储热更多留给供热 → 可行域向"更多供热"方向扩展
- → 放电时长从5h延长到8h (论文核心结论)
"""

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import os

# =========================================================================
# 1. 系统参数
# =========================================================================
W_max = 10.0
Q_max = 9.5
Q_HTV_upper = 150.0
Q_HTV_lower = 0.0
dt = 1.0

# β2 随透平入口温度 T_turb 变化 (基于论文 Eq.31)
# T_turb=483K (基准) → β2≈2.31 (回热多, 供热少)
# T_turb=503K (优化) → β2≈1.78 (回热少, 供热多)
T_turb_base = 483.0   # 基准透平入口温度 [K]
T_turb_opt  = 503.0   # ML优化后透平入口温度 [K]
beta2_base  = 2.31    # 基准 β2
beta2_opt   = 1.78    # 优化后 β2 (由论文 Eq.31 估算)
beta1       = 1.21

# =========================================================================
# 2. 可行域对比: 不同 SOC 状态下
# =========================================================================
SOC_levels = [20, 40, 60, 80]  # 四个 SOC 水平

fig, axes = plt.subplots(2, 2, figsize=(12, 10))

for idx, SOC_h in enumerate(SOC_levels):
    ax = axes[idx // 2, idx % 2]
    Q_HTV = SOC_h / 100 * Q_HTV_upper
    b_upper = max(0, (Q_HTV - Q_HTV_lower) / dt)  # W=0时的最大供热
    b_lower = (Q_HTV - Q_HTV_upper) / dt

    # 基准可行域 (灰色, β2_base)
    W_vals = np.linspace(0, W_max, 100)
    Q_bound_base = np.minimum(Q_max, np.maximum(0, b_upper - beta2_base * W_vals))
    ax.fill_between(W_vals, 0, Q_bound_base, color='gray', alpha=0.25, label='Baseline (T=483K)')
    ax.plot(W_vals, Q_bound_base, 'k-', lw=2, label=f'β₂={beta2_base:.2f}')

    # ML优化后可行域 (蓝色, β2_opt)
    Q_bound_opt = np.minimum(Q_max, np.maximum(0, b_upper - beta2_opt * W_vals))
    ax.fill_between(W_vals, 0, Q_bound_opt, color='blue', alpha=0.20, label='ML-Optimized (T=503K)')
    ax.plot(W_vals, Q_bound_opt, 'b-', lw=2, label=f'β₂={beta2_opt:.2f}')

    # 标注扩展区域
    ax.fill_between(W_vals, Q_bound_base, Q_bound_opt, color='cyan', alpha=0.30, label='Expanded Region')

    # 标注 Max Heat 和 Max Power 点
    Q_max_base = min(Q_max, b_upper)
    W_max_base = min(W_max, b_upper / beta2_base)
    W_max_opt  = min(W_max, b_upper / beta2_opt)

    ax.plot(0, Q_max_base, 'ko', ms=8)
    ax.plot(W_max_base, 0, 'ko', ms=8)
    ax.plot(W_max_opt, 0, 'bo', ms=8, mfc='b')

    ax.set_xlim(-0.5, W_max + 1.0)
    ax.set_ylim(-0.5, Q_max + 2.0)
    ax.set_xlabel('Discharging Power [MW]')
    ax.set_ylabel('Heating Power [MW]')
    ax.set_title(f'SOC_heat = {SOC_h}% (Q_HTV = {Q_HTV:.0f} MWh)')
    ax.legend(fontsize=7, loc='upper right')
    ax.grid(True, alpha=0.3)

fig.suptitle('Feasible Domain: Baseline vs ML-Optimized (Turbine Inlet Temp Adjusted)',
             fontsize=13, fontweight='bold')
plt.tight_layout()

out_dir = os.path.join('..', 'data')
os.makedirs(out_dir, exist_ok=True)
plt.savefig(os.path.join(out_dir, 'feasibility_domain_change.png'), dpi=150)
print('可行域对比图已保存')

# =========================================================================
# 3. 定量分析
# =========================================================================
print('\n=== 可行域面积变化分析 ===')
print(f'{"SOC":>5s} {"基准面积":>10s} {"优化面积":>10s} {"增幅":>8s} {"基准Wmax":>10s} {"优化Wmax":>10s}')
print('-' * 60)

for SOC_h in [10, 20, 30, 40, 50, 60, 70, 80]:
    Q_HTV = SOC_h / 100 * Q_HTV_upper
    b_upper = max(0, (Q_HTV - Q_HTV_lower) / dt)

    area_base = 0.5 * min(W_max, b_upper/beta2_base) * min(Q_max, b_upper)
    area_opt  = 0.5 * min(W_max, b_upper/beta2_opt)  * min(Q_max, b_upper)

    Wmax_base = min(W_max, max(0, b_upper / beta2_base))
    Wmax_opt  = min(W_max, max(0, b_upper / beta2_opt))

    change = (area_opt - area_base) / (area_base + 1e-6) * 100
    print(f'{SOC_h:4.0f}% {area_base:9.1f} {area_opt:9.1f} {change:+7.1f}% {Wmax_base:9.1f} {Wmax_opt:9.1f}')

# =========================================================================
# 4. 放电时长分析
# =========================================================================
print('\n=== 放电时长对比 (满功率10MW, 零供热) ===')
discharge_rates = {
    'Baseline (483K)': beta2_base * W_max,
    'ML-Optimized (503K)': beta2_opt * W_max,
    'ML-Optimized (483K→503K)': (beta2_base - beta2_opt) * W_max,  # 节省的回热功率
}

for label, rate in discharge_rates.items():
    hours = Q_HTV_upper / (rate + 1e-6)
    print(f'  {label}: 消耗率={rate:.1f} MW, 放电时长≈{hours:.1f} h')
