# MIVCA 高光谱目标检测可视化分析系统

## 简介

本系统为毕业设计项目，提供完整的 MIVCA（Multiple Instance Vertex Component Analysis）算法可视化分析流程，用于 MUUFL Gulfport 高光谱数据集的目标检测与端元提取。

## 功能

1. **数据加载与预处理** — 从原始 .mat 文件加载 HSI 数据，自动划分正包/负包，匹配真实端元
2. **MIVCA 算法** — 迭代清洗正包 + VCA 端元提取，带收敛判断
3. **标准 VCA 对比** — 对未清洗的原始正包运行标准 VCA 作为基线
4. **ACE/SMF 全图检测 + Bullwinkle ROC 评估** — 使用官方 Bullwinkle 框架，在全图运行 ACE 和 SMF 检测器，目标级别评分，计算 pAUC (FAR <= 1e-3)
5. **检测图像可视化** — 全图 ACE 热力图 + 目标区域放大视图 + 检测统计
6. **多维度可视化** — 伪彩色图像、光谱对比、收敛曲线、ROC 曲线、SAD 柱状图

## 使用方法

1. 打开 MATLAB，切换到本目录
2. 运行 `MIVCA_Analyzer`
3. 在左侧控制面板选择目标类别（brown / dark green / faux vineyard green / pea green）
4. 调整算法参数（可选）
5. 点击按钮逐步执行，或点击「一键运行完整流程」

## 操作流程

```
选择类别 → 加载数据 → 运行 MIVCA → 标准 VCA 对比 → ACE/SMF 检测 + ROC + 检测图像
```

每个步骤完成后，对应的 Tab 页会自动更新可视化结果。

## 界面布局

- **左侧面板**: 控制区（类别选择、参数配置、操作按钮、结果摘要）
- **右侧 Tab 页**:
  - 数据概览 — 伪彩色图像 + 目标标注 + 统计信息
  - 端元光谱对比 — MIVCA vs Ground Truth vs Standard VCA
  - 收敛曲线 — SAD 误差随迭代变化
  - ACE检测 & ROC — Bullwinkle 框架 ROC 曲线 (PD vs FAR) + ACE 分数分布 + 检测指标
  - 检测图像 — 全图 ACE 热力图 + 4 个目标区域放大视图 + 统计
  - 算法对比总览 — SAD 柱状图 + 运行时间对比 + Bullwinkle pAUC

## ACE/SMF 检测流程 (Bullwinkle 官方框架)

1. 使用 MIVCA 提取的端元作为目标光谱
2. 调用 `ace_detector` / `smf_detector` 对全图逐像素检测
3. 调用 `score_hylid_perpixel` 进行 Bullwinkle 目标级别评分 (Halo=2m)
4. 计算 `auc_upto_far(1e-3)` 得到部分 AUC
5. 绘制 PD vs FAR ROC 曲线 (`PlotBullwinkleRoc`)
6. 同时计算子集 (正包+负包) 上的 perfcurve AUC 作为参考

## 参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| VCA 背景端元数 (tiqv) | 15 | 每次迭代从负包中提取的背景端元数量 |
| 最大迭代次数 | 1000 | MIVCA 最大迭代次数 |
| 背景像素采样数 | 100000 | 负包降采样数量 |
| 正包最小像素阈值 | 12 | 正包像素低于此值停止迭代 |

## 依赖

- MATLAB R2019b 或更高版本
- Statistics and Machine Learning Toolbox (perfcurve)
- Bullwinkle 官方检测框架 (`MUUFLGulfport-master/.../MUUFLGulfportDataCollection/`)
- 原始数据文件:
  - `muufl_gulfport_campus_w_lidar_1.mat`
  - `tgt_img_spectra.mat`
- 算法文件 (自动添加路径):
  - `vca.m`, `ortho.m` (位于 `mean0.1/mean0.1/`)

## 输出

所有结果保存在内存中，可通过 MATLAB 工作区查看:
- `state.E_mivca` — MIVCA 提取的目标端元
- `state.E_vca_standard` — 标准 VCA 提取的端元
- `state.jiao_history` — SAD 收敛历史
- `state.ace_det_img` — 全图 ACE 检测结果图像
- `state.bw_score_ace` — Bullwinkle ACE 评分结构体
- `state.pAUC_ace` — ACE 检测器 pAUC (FAR <= 1e-3)
- `state.pAUC_smf` — SMF 检测器 pAUC (FAR <= 1e-3)
