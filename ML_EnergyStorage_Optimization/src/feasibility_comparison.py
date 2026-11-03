"""
feasibility_comparison.py
透平入口温度对放电可行域 / 放电时长的影响

数据来源：data/design_sweep.csv，由 MATLAB 侧 cces_design_sweep.m 调用
cces_design_point（REFPROP 现算）生成，Python 端不再手写任何 β₂(T) 估算值。

修正说明（原版本的两个错误）：
  1) 旧版直接令 beta2_opt = 1.78（"由论文 Eq.31 估算"）。REFPROP 实测
     β₂ 在 483→503 K 只从 1.659 变到 1.686（+1.6%），不存在 2.31→1.78 的下降。
  2) 由此得出的"可行域扩大 23%、放电时长 5 h→8 h(+60%)"不成立。
  真实机制是：升温使单位功率所需质量流量 α₂ 下降（4.19→3.99，−4.8%），
  同样储液量可多放电约 5%，同时电效率上升约 2.8 个百分点。
"""

import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, '..', 'data')

# =========================================================================
# 1. 读取设计点扫描表
# =========================================================================
sweep = pd.read_csv(os.path.join(DATA, 'design_sweep.csv'))
print('设计点扫描（REFPROP）:')
print(sweep.to_string(index=False))

def at(T):
    return sweep.iloc[(sweep.Th_K - T).abs().argmin()]

base = at(483.0)
opt = at(503.0)

# =========================================================================
# 2. 系统常数（与 cces_design_point 一致）
# =========================================================================
W_max = 10.0          # MW
Q_max = 12.05         # MW  = γ1·W_design
Q_HTV = 15.0          # MWh = 10% SOC：只有低 SOC 时储热约束才真正限制可行域
dt = 1.0              # h
M_usable = 754400.0   # kg  设计循环质量（5 h × α₂ × 10 MW）

def domain_area(beta2):
    """放电可行域面积 ∫ min(Q_max, Q_HTV/Δt − β2·W) dW"""
    b_up = Q_HTV / dt
    W_lim = min(W_max, b_up / beta2)
    W = np.linspace(0.0, W_lim, 2000)
    Q = np.minimum(Q_max, np.maximum(0.0, b_up - beta2 * W))
    return np.trapz(Q, W)

def duration(alpha2):
    """同等储液量、满功率放电能持续多久 [h]"""
    return M_usable / (alpha2 * W_max * 3600.0)

# =========================================================================
# 3. 定量对比
# =========================================================================
rows = []
for _, r in sweep.iterrows():
    rows.append((r.Th_K, r.beta2, r.alpha2, r.eta_elec_pct,
                 domain_area(r.beta2), duration(r.alpha2)))

print('\n Th[K]  beta2  alpha2  可行域面积   同等储液放电时长   RTE%')
print('-' * 66)
for T, b2, a2, rte, area, dur in rows:
    print(f' {T:5.0f}  {b2:.3f}  {a2:.3f}   {area:8.1f} MWh     {dur:5.2f} h      {rte:5.1f}')

d_area = (domain_area(opt.beta2) - domain_area(base.beta2)) / domain_area(base.beta2) * 100
d_dur = (duration(opt.alpha2) - duration(base.alpha2)) / duration(base.alpha2) * 100
d_b2 = (opt.beta2 - base.beta2) / base.beta2 * 100
d_a2 = (opt.alpha2 - base.alpha2) / base.alpha2 * 100

print('\n=== 483 K -> 503 K ===')
print(f'  beta2 : {base.beta2:.3f} -> {opt.beta2:.3f}  ({d_b2:+.1f}%)')
print(f'  alpha2: {base.alpha2:.3f} -> {opt.alpha2:.3f}  ({d_a2:+.1f}%)')
print(f'  可行域面积(SOC 10%): {domain_area(base.beta2):.1f} -> {domain_area(opt.beta2):.1f} MWh ({d_area:+.1f}%)')
print('  注：SOC=50% 时 β₂·W_max = 16.9 MW < Q_HTV/Δt = 75 MW，可行域被设备上限')
print('      Q_max 截成矩形，与 β₂ 无关；电热竞争只在低 SOC（<~15%）出现。')
print(f'  同等储液放电时长: {duration(base.alpha2):.2f} -> {duration(opt.alpha2):.2f} h ({d_dur:+.1f}%)')
print(f'  电-电效率: {base.eta_elec_pct:.1f}% -> {opt.eta_elec_pct:.1f}%')
print('\n结论：升温带来的是"同等储液约多放 5% + 电效率 +3.3 pt"，')
print('      而不是此前假设的可行域扩大 23% / 放电时长 +60%。')

# =========================================================================
# 4. 绘图
# =========================================================================
fig, axes = plt.subplots(1, 2, figsize=(13, 5))

ax = axes[0]
ax.plot(sweep.Th_K, sweep.beta2, 'o-', color='#c0392b', lw=2)
ax.axvline(483, color='gray', ls='--', alpha=0.6)
ax.axvline(503, color='gray', ls='--', alpha=0.6)
ax.set_xlabel('Turbine inlet temperature [K]')
ax.set_ylabel(r'$\gamma_2$ [-]', color='#c0392b')
ax.tick_params(axis='y', labelcolor='#c0392b')
ax2 = ax.twinx()
ax2.plot(sweep.Th_K, sweep.alpha2, 's-', color='#2c3e50', lw=2)
ax2.set_ylabel(r'$\alpha_2$ [kg/(s$\cdot$MW)]', color='#2c3e50')
ax2.tick_params(axis='y', labelcolor='#2c3e50')
ax.set_title(r'$\gamma_2$ nearly flat, $\alpha_2$ falls with T')
ax.grid(alpha=0.3)

ax = axes[1]
b_up = Q_HTV / dt
W = np.linspace(0, W_max, 400)
for r, color, lab in [(base, '#7f8c8d', f'483 K ($\\gamma_2$={base.beta2:.3f})'),
                      (opt, '#2980b9', f'503 K ($\\gamma_2$={opt.beta2:.3f})')]:
    Qb = np.minimum(Q_max, np.maximum(0, b_up - r.beta2 * W))
    ax.fill_between(W, 0, Qb, color=color, alpha=0.25)
    ax.plot(W, Qb, color=color, lw=2, label=lab)
ax.set_xlabel(r'Discharging power $W_{T,E}$ [MW]')
ax.set_ylabel('Heating power [MW]')
ax.set_title(f'Feasible domain at SOC=10% (area change {d_area:+.1f}%)')
ax.legend(loc='upper right', fontsize=9)
ax.grid(alpha=0.3)
ax.set_xlim(0, W_max)
ax.set_ylim(0, Q_max + 2)

fig.suptitle('Effect of turbine inlet temperature: REFPROP values, not an estimate',
             fontsize=12, fontweight='bold')
plt.tight_layout()
out = os.path.join(DATA, 'feasibility_domain_change.png')
plt.savefig(out, dpi=150)
print(f'\n图已保存: {out}')
