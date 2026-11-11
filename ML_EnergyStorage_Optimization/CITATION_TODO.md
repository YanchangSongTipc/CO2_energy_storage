# 补引用清单（CITATION_TODO）

> 现状：全文 27 条参考文献，**27 条都已被引用、无孤儿文献**。
> 但 §7 经济性一节 **零引用**——所有成本、电价、热价数字都没有出处，这是审稿最可能被挑的地方。
> 本机无法联网检索（web search 未配置 key），因此这里只给"槽位 + 检索词"，不编造条目。

## 用法

1. 按下面每个槽位去 Scopus / Web of Science / Google Scholar 检索（检索词已给）；
2. 把 **DOI 或 完整题录** 贴回来（格式随意，我来统一成 Elsevier 数字风格）；
3. 我负责插入正文对应位置、编号、更新参考文献表。

---

## P1 · 必须有（无引用会被直接质疑）

### 槽位 1 — 资本成本区间（§7.1）

**原文**："We use the ranges reported for large-scale compressed-air and liquid-CO₂ storage:
900 USD/kW for the turbomachinery, 60 USD/kWh for the above-ground CO₂ inventory and
25 USD/kWh_th for the thermal store, giving 15.75 MUSD for the 10 MW/50 MWh unit."

需要 2–3 篇：CAES / LAES / CCES 的 techno-economic assessment，给出投资分解（USD/kW 与 USD/kWh）。

检索词：
- `compressed air energy storage techno-economic capital cost USD/kW 2023`
- `liquid air energy storage cost breakdown USD/kWh 2024`
- `compressed CO2 energy storage economic analysis capital cost`

### 槽位 2 — 山东分时电价（§7.1）

**原文**："1.0475 CNY/kWh in the peak period, 0.6899 in the flat, 0.3324 in the valley and
0.2303 in the deep valley … the provincial mechanism sets the peak at +70 %, the valley at −70 % …"

需要 1 篇：山东省发改委电价文件，或引用该政策的期刊/报告（写明文号与年份）。

检索词：`山东省 分时电价 政策 2025 尖峰 深谷`、`Shandong time-of-use electricity price policy 2025`。

### 槽位 3 — 工业蒸汽热价（§7.1）

**原文**："Heat is priced as gas-fired industrial steam at 349 CNY/t (Jinan, 2023), about 63 USD/MWh_th at 2.8 GJ/t."

需要 1 篇：济南/山东工业蒸汽价格或区域供热定价研究。

检索词：`济南 工业蒸汽 价格 2023 元/吨`、`industrial steam price China district heating 2023`。

### 槽位 4 — 折现率/寿命/O&M（§7.1）

**原文**："Operation and maintenance is 2.5 % of capital per year, the discount rate is 7 % and the lifetime 25 years."

需要 1–2 篇：储能项目经济性评价的通用假设（可与槽位 1 共用文献）。

---

## P2 · 强烈建议（决定"文献覆盖是否够新"）

### 槽位 5 — 引言第三段（CCES 设计研究）

**现状**：`[12–15]` 均为 2019–2022。建议补 1–2 篇 2023–2025 的 CCES 构型/优化论文。

检索词：`compressed CO2 energy storage system design optimization 2024 2025`

### 槽位 6 — 引言第四段（CCES 热电联产）

**现状**：`[17–19]` 之后直接跳到 Hao [20]。建议补 1–2 篇近三年的 CCES-CHP 运行/调度论文。

检索词：`compressed CO2 energy storage combined heat and power dispatch 2024`

### 槽位 7 — 引言第五段（可行域计算昂贵）

**原文**："the construction of the feasibility domain relies on full thermodynamic simulations that are
computationally expensive for real-time dispatch applications."

这是本文立论的前提，目前只靠 [20] 支撑。建议补 1–2 篇"可行域/运行域在线计算"的文献。

检索词：`operational feasible region real-time energy system optimization surrogate 2024`

### 槽位 8 — 引言第六段（ML 用于能源系统）

**现状**：`[21–24]` 偏旧且泛。建议补 2 篇 2023–2025 的：代理模型用于调度、或 RL/模仿学习用于储能调度。

检索词：`surrogate model energy system dispatch machine learning 2024`、
`reinforcement learning energy storage dispatch 2025`

---

## P3 · 可选

### 槽位 9 — §4.6 推理速度

**原文**："compared to a full REFPROP-based thermodynamic simulation requiring multiple property calls"

若有"代理模型 vs 物性计算"的耗时对比文献，引 1 篇即可；没有也不影响结论。

### 槽位 10 — §6.1 负荷/风电曲线

**现状**：未说明数据来源。建议要么引一篇典型日曲线来源，要么加一句
"profiles are synthesised from typical winter-day shapes reported in [x]"。

---

## 目标数量

| 类别 | 现在 | 目标 |
|---|---|---|
| 总数 | 27 | **40–45** |
| 2020 年以后 | 14 | ≥ 28 |
| 2023 年以后 | 3（[20] 等） | **8–10** |
| §7 经济性 | 0 | 4–6 |

补到 40 条左右、且 §7 每个数字都有出处，文献覆盖这一项就不会被挑。
