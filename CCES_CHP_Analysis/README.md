# CCES-CHP 运行可行域分析

基于压缩二氧化碳储能的冷热电联供系统（CCES-CHP）的运行可行域分析程序。

> 参考论文: Hao et al., "Study on the operational feasibility domain of combined heat and power generation system based on compressed carbon dioxide energy storage", *Energy* 291 (2024) 130122.

## 依赖环境

- MATLAB R2020a 或更高版本
- [REFPROP](https://www.nist.gov/srd/refprop) 物性数据库（需安装并配置路径）

## 文件说明

```
├── Cycle.m                  # 基础热力学循环计算（15 状态点）
├── PaperReproduction.m      # 主程序：完整论文复现
├── explain.md               # 所有输出图像的详细解释
├── output_figures/          # 生成的图像输出目录
└── pdf/                     # 参考论文 PDF
```

## 运行

1. 修改 `PaperReproduction.m` 第 42 行的 REFPROP 路径：
   ```matlab
   libLoc = 'D:\Program Files\REFPROP\';  % 改为你的安装路径
   ```
2. 在 MATLAB 中运行：
   ```matlab
   PaperReproduction
   ```

图像自动保存到 `output_figures/` 目录，不弹出窗口。

## 输出图像

| 图号 | 内容 | 论文对应 |
|------|------|----------|
| Fig01 | 充电-供热运行可行域 | Fig.3 |
| Fig02 | 放电-供热运行可行域（电热竞争） | Fig.4 |
| Fig03 | 负荷与风电出力曲线 | Fig.8 |
| Fig04 | CCES-CHP 调度指令 vs 实际响应 | Fig.9 |
| Fig05 | 综合能源系统电力平衡 | Fig.10 |
| Fig06 | 综合能源系统热力平衡 | Fig.11 |
| Fig07 | 双 SOC（热+气）24h 演化 | — |
| Fig08 | 24h 运行可行域动态演化 | Fig.12 |
| Fig09 | Heat/Power-dependent 降级调度模式 | Fig.7 |
| Fig10 | X 和 β₂ 随透平入口温度变化 | §4.2.1 |
| Fig11 | T-P 温-压循环状态图（储/释能分列） | — |
| Fig12 | T-s 温-熵循环图（含 CO₂ 饱和穹顶） | — |
| Fig13 | p-h 压-焓循环图（含 CO₂ 饱和穹顶） | — |
| Fig14 | 不同电负荷比下可行域比较 | Fig.12 |

详见 [explain.md](explain.md)。

## 关键技术点

- **单位处理**：`getFluidProperty` 的 `MASS BASE SI` 输入压力为 Pa、输出焓/熵为 J 单位，程序内统一转为 MPa 和 kJ
- **运行可行域**：充电工况约束斜率 +β1（电热互补），放电工况约束斜率 −β2（电热竞争，最大发电与最大供热不可兼得）
- **双 SOC 模型**：热存储（HTV 导热油）与气存储（HPT CO₂ 压力）通过 α1/α2/β1/β2 耦合演化
- **饱和穹顶**：T-s 和 p-h 图中叠加 CO₂ 气液平衡曲线，临界区采用加密温度点（ΔT 低至 0.05K）平滑闭合

## 系统参数

| 参数 | 数值 | 单位 |
|------|------|------|
| 设计充/放电功率 | 10 | MW |
| 充电时间 | 7.5 | h |
| 放电时间 | 5.0 | h |
| LPT 压力 | 0.102 | MPa |
| HPT 压力 | 6.80 | MPa |
| 压缩机等熵效率 | 0.85 | — |
| 透平等熵效率 | 0.88 | — |
| 充电质量流量 | 26.9 | kg/s |
| 放电质量流量 | 40.3 | kg/s |
| 高温储热上限 | 150 | MWh_th |
