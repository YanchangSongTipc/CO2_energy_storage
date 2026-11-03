# 经济性假设（ECON_ASSUMPTIONS）

> 状态：**占位默认值**，用于把模型跑通与确定投稿所需的量级；等你有项目数据或指定文献来源后替换。
> 代码：`src/economics.py` 的 `PARAMS` 字典，改完直接重跑，无需动模型。
> 运行：`python src/economics.py` → `data/economics_summary.csv`、`data/economics_sensitivity.csv`、`data/fig_economics.png`

## 一、默认参数与取值范围

取值口径是 2024–2025 年 CAES/CCES 文献的中位水平；方括号内为我们在敏感性分析里覆盖的区间。

| 参数 | 键名 | 默认值 | 区间 | 说明 |
|---|---|---|---|---|
| 电功率等级 | `P_el_design_MW` | 10 | — | 论文 Table 1 |
| 储电容量 | `E_el_MWh` | 50 | — | 10 MW / 5 h |
| 储热容量 | `E_th_MWh` | 150 | — | HTV |
| 单位功率投资 | `capex_power_usd_per_kW` | 900 | [700, 1500] | 压缩机+透平+发电机 |
| 储电单位投资 | `capex_energy_usd_per_kWh` | 60 | [30, 100] | 高压罐+储液 |
| 储热单位投资 | `capex_thermal_usd_per_kWh_th` | 25 | [15, 40] | 导热油+罐体 |
| 年运维费率 | `opex_frac_per_year` | 0.025 | [0.015, 0.04] | 占 CAPEX |
| 折现率 | `discount_rate` | 0.07 | [0.05, 0.10] | |
| 寿命 | `life_years` | 25 | — | |
| 峰时电价 | `price_peak_usd_per_MWh` | 120 | [90, 180] | |
| 谷时电价 | `price_valley_usd_per_MWh` | 40 | [20, 60] | |
| 热价 | `price_heat_usd_per_MWh_th` | 30 | [20, 45] | |
| 套利运行天数 | `operating_days_el` | 330 | — | 全年除检修 |
| 供热运行天数 | `operating_days_heat` | 150 | — | 供暖季 |

> 注：会议稿的算例是"供暖季典型日"，365 天套利是期刊版才引入的口径——两个天数必须分别说明，否则 LCOE 会被低估。

## 二、参考工况结果（默认参数，ML-guided）

| 项目 | 值 |
|---|---|
| CAPEX | 15.75 MUSD |
| 年运维 | 0.39 MUSD |
| 年套利收入 | 1.70 MUSD |
| 年供热收入 | 0.21 MUSD |
| 年放电量 / 年供热量 | 21,450 MWh / 6,945 MWh |
| LCOE（仅电） | 81.4 USD/MWh |
| LCOH（电+热） | 61.5 USD/MWh |
| 静态回收期 | 10.4 yr |
| NPV（25 yr, 7%） | +1.93 MUSD |

三种调度策略对比（同一 CAPEX）：

| 策略 | 年放电 MWh | 年供热 MWh | LCOE | 回收期 | NPV |
|---|---|---|---|---|---|
| Rule-based | 21,978 | 6,600 | 79.4 | 10.0 yr | +2.55 MUSD |
| ML-guided | 21,450 | 6,945 | 81.4 | 10.4 yr | +1.93 MUSD |
| LP optimum (λ=1) | 20,394 | 7,800 | 85.6 | 11.1 yr | +0.76 MUSD |

**这张表本身就是一个结论**：在"套利为主、热价为 30 USD/MWh_th"的假设下，多供热换不来收益——放电量才是收入主体，所以规则调度的 NPV 反而最高。这正好呼应正文 §6.5 的论点：**供热的经济价值取决于 λ = 热价 / 电价**，而不是系统的物理能力。

## 三、盈亏平衡

| 变量 | 盈亏平衡值 |
|---|---|
| 峰谷电价差（CAPEX 不变） | **72 USD/MWh** |
| CAPEX 乘数（电价差 80 USD/MWh 不变） | **1.10**（即 17.2 MUSD） |

写进正文时建议这样表述：*"At the reference assumptions the plant breaks even at a peak–valley spread of 72 USD/MWh, or at a capital cost of 17.2 MUSD; both lie within the ranges reported for adiabatic CAES of comparable size."* —— 引用文献来源需要你确认，我没有替你选定具体文献。

## 四、替换清单（你提供后我改代码）

1. 真实投资估算（设备清单或 EPC 报价）→ 替换三个 CAPEX 键
2. 项目所在地分时电价曲线 → 替换 peak/valley，或给我 24 h 曲线我改成逐时
3. 热价（工业蒸汽/采暖）与年供热量
4. 运维合同费率、贷款条件（若要做 LCOE 的融资口径）
5. 是否计碳价（`price_co2_usd_per_t` 现在是 0）
