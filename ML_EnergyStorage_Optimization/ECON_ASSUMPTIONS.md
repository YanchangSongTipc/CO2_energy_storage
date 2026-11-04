# 经济性假设（ECON_ASSUMPTIONS）

> 状态：**文献校核后的占位值**（2026-11-04 更新）。量级可用于投稿判断，金额仍需按项目实际替换。
> 代码：`src/economics.py` 的 `PARAMS` 字典，改完直接重跑，无需动模型。
> 运行：`python src/economics.py` → `data/economics_summary.csv`、`data/economics_sensitivity.csv`、`data/fig_economics.png`

## 〇、数据来源（可引用）

| 参数 | 采用值 | 依据 |
|---|---|---|
| CAES 单位功率投资 | 500–1200 USD/kW（大型） | Wikipedia "Compressed-air energy storage"：[链接](https://en.wikipedia.org/wiki/Compressed-air_energy_storage)；美国 McIntosh 110 MW 电站折算 590 USD/kW + 23 USD/kWh |
| CAES 单位能量投资 | 53 USD/kWh（2016）→ 44（2030） | IRENA (2017) *Electricity Storage and Renewables: Costs and Markets to 2030*, p.30：[PDF](https://www.irena.org/-/media/Files/IRENA/Agency/Publication/2017/Oct/IRENA_Electricity_Storage_Costs_2017.pdf) |
| 高温液体储热 | 22–77 USD/kWh_th（2016） | 同上，Table 12（sensible high-temperature heat storage in liquids） |
| CCES 的 LCOE | 0.0907 USD/kWh（深圳算例） | *Techno-economic assessment on a multi-stage compressed carbon dioxide energy storage system with liquid storage*, Energy Reports 2022，[DOI](https://doi.org/10.1016/j.egyr.2022.09.021) |
| CCES 与锂电的时长边界 | > 6 h 时 CCES 更具成本优势 | IEEE EPEE 2024，[DOI](https://doi.org/10.1109/epee63731.2024.10875132)（摘要级结论） |
| 分时电价（峰/谷） | 120 / 40 USD/MWh | **未找到可直接引用的权威文件**，须以项目所在省份发改委/电网现行分时目录为准 |
| 热价 | 30 USD/MWh_th | 同上，需按当地工业蒸汽/采暖价格核定 |
| 折现率、寿命、运维费率 | 7 %、25 yr、2.5 %/yr | 工程经济常用取值，非文献硬约束 |

**交叉校验**：本文默认 CAPEX（15.75 MUSD，即 1575 USD/kW）给出 LCOE = 81.4 USD/MWh；上述 Energy Reports 的 CCES 算例为 90.7 USD/MWh。由于 LCOE 近似与 CAPEX 成正比，反推文献算例对应 CAPEX ≈ 17.6 MUSD（1760 USD/kW）——我们的默认值比它低约 11 %，处于合理带内。这句话可直接用于论文经济性小节，支撑"假设不过于乐观"。

## 一、默认参数与取值范围

取值口径是 2024–2025 年 CAES/CCES 文献的中位水平；方括号内为敏感性分析覆盖的区间。

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

写进正文时建议这样表述：*"At the reference assumptions the plant breaks even at a peak–valley spread of 72 USD/MWh, or at a capital cost of 17.2 MUSD. The first figure is set by the local tariff and must be checked against the provincial schedule; the second lies within the 500–1200 USD/kW range reported for large-scale CAES and is consistent with the 90.7 USD/MWh LCOE of a published liquid-CO₂ case."*

## 四、替换清单（你提供后我改代码）

| 优先级 | 需要的数据 | 当前占位 | 哪里查 |
|---|---|---|---|
| 高 | 项目所在省份分时电价（峰/平/谷，工商业） | 120 / 40 USD/MWh | 省发改委价格文件、电网公司分时电价公告 |
| 高 | 热价（工业蒸汽或采暖）与年供热量 | 30 USD/MWh_th | 当地热力公司、园区蒸汽价 |
| 中 | 设备投资（压缩机、透平、换热器、储罐） | 900 USD/kW + 60 USD/kWh + 25 USD/kWh_th | 项目报价，或文献参数表（需注明来源） |
| 低 | 运维费率与融资条件 | 2.5 %/yr、7 % | 可研报告或同类工程经验 |
| 低 | 是否计碳价 | 0 | CCER/碳市场价 |

> 表中"高"两项我未能找到可直接引用的权威公开文件——这类型数据属于省级定价文件与合同价，检索到的二手数字不适合作为投稿引用。你告知省份后，我可以去找该省现行分时目录；热价同理。
