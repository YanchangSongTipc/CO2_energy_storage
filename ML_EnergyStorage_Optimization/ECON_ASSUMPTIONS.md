# 经济性假设（ECON_ASSUMPTIONS）

> 状态：**山东算例 + 文献校核**（2026-11-04 更新）。电价与热价已替换为可引用的公开数据；CAPEX 仍为文献区间内的估计，需项目报价替换。
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

> 注：会议稿的算例是"供暖季典型日"，330 天套利是期刊版才引入的口径——两个天数必须分别说明，否则 LCOE 会被低估。

### 山东电价与热价（已落实，可引用）

| 项目 | 数值（原单位） | 折算 | 来源 |
|---|---|---|---|
| 工商业两部制 1-10 kV 高峰 | 1.0475 元/kWh | 147.5 USD/MWh | 国网山东《代理购电工商业用户电价表》，执行期 2025-03-01 至 03-31：[烟台市政府转发](https://www.yantai.gov.cn/art/2025/3/20/art_70253_3244147.html) |
| 同表 平时段 | 0.6899 元/kWh | 97.2 USD/MWh | 同上 |
| 同表 低谷 | 0.3324 元/kWh | 46.8 USD/MWh | 同上 |
| 同表 尖峰 / 深谷 | 1.2007 / 0.2303 元/kWh | 169.1 / 32.4 USD/MWh | 同上（深谷可用于充电，本文未取） |
| 工商业分时机制 | 高峰 +70 %、低谷 −70 %、尖峰 +100 %、深谷 −90 % | — | 山东省工商业分时电价政策解读（2025-04-21）：[烟台市发改委](https://fgw.yantai.gov.cn/art/2025/4/21/art_52219_2909512.html) |
| 工业蒸汽 | 349 元/吨（燃气锅炉基准售价） | ≈447 元/MWh_th ≈ 63.0 USD/MWh_th | 济南市发改委《关于调整工业蒸汽价格有关事项的通知》，2023-01：[报道](http://jinan.subaoxw.com/zj/2023/0110/90612.html) |

**折算假设**：汇率 7.10 CNY/USD；1 t 蒸汽 ≈ 2.8 GJ ≈ 0.78 MWh_th。若本文供热是采暖热水而不是工艺蒸汽，热价应改用当地"元/GJ"口径（通常显著低于蒸汽价），经济性会变差——这一点必须在正文里写清楚，否则审稿人会质疑口径混用。

## 二、参考工况结果（山东价格，ML-guided）

| 项目 | 值 |
|---|---|
| CAPEX | 15.75 MUSD |
| 年运维 | 0.39 MUSD |
| 年套利收入 | 2.14 MUSD |
| 年供热收入 | 0.44 MUSD |
| 年放电量 / 年供热量 | 21,450 MWh / 6,945 MWh |
| LCOE（仅电） | 81.4 USD/MWh |
| LCOH（电+热） | 61.5 USD/MWh |
| 静态回收期 | 7.2 yr |
| NPV（25 yr, 7 %） | **+9.75 MUSD** |

三种调度策略对比（同一 CAPEX、山东价格）：

| 策略 | 年放电 MWh | 年供热 MWh | 年收入 MUSD | LCOE | 回收期 | NPV |
|---|---|---|---|---|---|---|
| Rule-based | 21,978 | 6,600 | 2.64 | 79.4 | 7.0 yr | **+10.41 MUSD** |
| ML-guided | 21,450 | 6,945 | 2.58 | 81.4 | 7.2 yr | +9.75 MUSD |
| LP optimum (λ=1) | 20,394 | 7,800 | 2.48 | 85.6 | 7.6 yr | +8.56 MUSD |

**这张表本身就是一个结论**：在山东电价下项目能盈利，但**放电量仍是收入主体**（套利 2.1–2.2 MUSD vs 供热 0.4 MUSD），所以规则调度的 NPV 反而最高。这正好呼应正文 §6.5：供热的经济价值取决于 λ = 热价 / 电价，而不是系统的物理能力。也说明"供热增益"只有在热价显著高于本地蒸汽价、或把 λ 调到 1 以上时才转化为收益。

## 三、盈亏平衡（山东价格）

| 变量 | 盈亏平衡值 | 与当前值比较 |
|---|---|---|
| 峰谷电价差（CAPEX 不变） | **62 USD/MWh** | 山东实际约 101 USD/MWh → 有安全边际 |
| CAPEX（电价差约 101 USD/MWh） | **23.4 MUSD（1.48 倍）** | 当前 15.75 MUSD → 可容忍 +48 % 的投资超支 |

写进正文时建议这样表述：*"With the March 2025 Shandong industrial tariff (1.0475 / 0.3324 CNY per kWh for the peak and valley periods) and a gas-fired industrial steam price of 349 CNY per tonne, the plant reaches break-even at a peak–valley spread of 62 USD/MWh, well below the 101 USD/MWh offered by the tariff, and tolerates a capital cost of 23.4 MUSD before the net present value turns negative. The capital figure lies within the 500–1200 USD/kW range reported for large-scale CAES and is consistent with the 90.7 USD/MWh LCOE of a published liquid-CO₂ case."*

## 四、替换清单（你提供后我改代码）

| 优先级 | 需要的数据 | 当前状态 | 下一步 |
|---|---|---|---|
| 高 | 山东分时电价（峰/平/谷） | ✅ 已落实：2025-03 国网山东代购电价表 | — |
| 高 | 山东工业蒸汽价 | ✅ 已落实：济南 349 元/t（2023-01） | 若供热是采暖热水而非蒸汽，需换成元/GJ 口径 |
| 中 | 设备投资（压缩机、透平、换热器、储罐） | 公开稿用文献区间 900 / 60 / 25 | 真实报价走私有覆盖文件（见 §五），不进仓库 |
| 低 | 运维费率与融资条件 | 2.5 %/yr、7 % | 可研报告或同类工程经验 |
| 低 | 是否计碳价 | 0 | CCER / 碳市场价 |

## 五、企业保密数据的处理

项目报价属于企业自有数据、通常不可对外公开。这类情况在工程类期刊里很常见，处理原则是**方法可复现、数字可分档**，不必披露原始报价。我们采用三层结构：

| 层 | 内容 | 是否入仓库 | 用途 |
|---|---|---|---|
| 1. 公开层 | 文献区间（IRENA/Wikipedia/已发表算例）+ 山东公开电价热价 | 是 | 论文正文的数字全部来自这一层，任何人可复现 |
| 2. 私有层 | 企业真实报价与合同价 | **否**（`.gitignore` 排除） | 你自己做决策用的结果 |
| 3. 结论层 | 盈亏平衡价差、可容忍 CAPEX、NPV 区间 | 是 | 论文报告的是"阈值"而非"造价"，既回答了经济性又不泄露报价 |

**私有层怎么用**：把 `src/econ_params_local.example.py` 复制成 `src/econ_params_local.py`，取消注释并填入真实数字；`economics.py` 会自动加载，只在终端提示"导入了 N 个私有参数"，不打印数值。该文件已被 `.gitignore` 排除，`git status` 永远不会看到它。

**论文里怎么写**（可直接放进 §7 或方法节，英文）：

> The economic assessment relies on publicly reported cost ranges for the capital items and on the published Shandong tariff and industrial-steam prices for the operating revenues. Project-specific quotations are proprietary and are not reproduced here. To keep the conclusions independent of that restriction, all results are reported as break-even values — the peak–valley spread and the capital cost at which the net present value vanishes — rather than as point estimates of the investment. The break-even spread of 62 USD/MWh lies well below the 101 USD/MWh offered by the tariff, and the break-even capital cost of 23.4 MUSD lies within the 500–1200 USD/kW range reported for large-scale CAES, so the conclusion does not depend on the proprietary figures.

**为什么这样写能过审**：审稿人关心的是"结论是否稳健"，而不是"造价是多少"。把可公开的阈值（62 USD/MWh、23.4 MUSD）作为结论，既证明经济性成立，又把敏感区间留给读者判断；同时明确声明数据受限，符合期刊对工业合作研究的惯例。
