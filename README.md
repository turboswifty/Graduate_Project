<p align="center">
  <h1 align="center">MIVCA：多示例顶点成分分析</h1>
  <h3 align="center">Multiple Instance Vertex Component Analysis<br/>for Hyperspectral Target Endmember Extraction</h3>
</p>

<p align="center">
  <strong>毕设项目 · 西安电子科技大学 · 2026</strong>
</p>

---

## 项目简介

本仓库实现并评估了一种新的高光谱目标端元提取算法——**MIVCA（Multiple Instance Vertex Component Analysis，多示例顶点成分分析）**。该算法针对 **MIL（Multiple Instance Learning，多示例学习）** 框架下的弱监督目标表征问题，通过迭代清洗正包中的背景像素，结合 VCA（Vertex Component Analysis）端元提取，在 MUUFL Gulfport 和 Pavia University 数据集上取得了显著优于 Standard VCA、MI-HE 和 eFUMI 的端元提取精度。

### 核心思想

```
正包(含目标+背景) + 负包(纯背景)
        ↓
   VCA 提取背景端元 → 正交投影 → 剔除正包中的背景像素
        ↓
   重复迭代，直到正包纯净
        ↓
   VCA 提取目标端元(纯净)
```

传统的 VCA 直接对未清洗的正包提取端元，由于正包中混有大量背景像素，提取结果精度差。MIVCA 通过迭代地将正包中与背景子空间最相似的像素移入负包，逐步纯化正包，最终得到高精度的目标端元估计。

---

## 仓库结构

```
毕设相关/
│
├── mean0.1/mean0.1/               ★ 核心算法与实验
│   ├── main_run_mivca_on_gullfport.m    # MIVCA 主程序 (Gulfport)
│   ├── main_run_mivca_on_*.m            # MIVCA 各目标/数据集变体
│   ├── vca.m                            # VCA 端元提取算法
│   ├── ortho.m                          # 正交投影筛选
│   ├── generate_mivca_toydata.m         # 合成数据生成
│   ├── main_run_ace_pavia.m             # ACE 检测 (Pavia)
│   ├── merge_four_endmembers.m          # 四类端元合并
│   ├── draw_endmember_antinormalize.m   # 端元可视化
│   ├── run_mihe_on_gulfport.m           # MI-HE 对比实验
│   ├── run_efumi_on_gulfport.m          # eFUMI 对比实验
│   ├── SAD对比/                         # 算法对比评估
│   │   ├── compare.m                    # SAD 对比脚本
│   │   ├── ACE.m                        # ACE + ROC 对比
│   │   ├── ACE_mivca_only.m             # MIVCA 单独 ROC
│   │   ├── ACE_mihe_only.m              # MI-HE 单独 ROC
│   │   ├── ACE_efumi_only.m             # eFUMI 单独 ROC
│   │   ├── draw_SAD_compare_result.m    # SAD/时间柱状图
│   │   └── *.mat                        # ROC 数据缓存
│   └── *.mat                            # 端元/数据结果文件
│
├── MIVCA_Visualization_System/     ★ 可视化分析系统 (GUI)
│   ├── MIVCA_Analyzer.m                 # 主 GUI 程序 (~1400 行)
│   └── README.md                        # 系统使用说明
│
├── HyperspectralAnalysisIntroduction-0.3/  ★ 数据准备与预处理
│   ├── prepare_gulfport_mivca.m         # 数据预处理 (正/负包划分)
│   ├── prepare_gulfport_for_mihe.m      # MI-HE 数据准备
│   ├── prepare_gulfport_for_mihe_all.m  # MI-HE 全类别准备
│   ├── muufl_gulfport_campus_w_lidar_1.mat  # 原始 HSI 数据集
│   ├── tgt_img_spectra.mat              # 官方目标光谱 (4 类)
│   └── *_gulfport_*.mat                 # 各类别预处理数据
│
├── FUMI-master/                    ★ FUMI 系列算法 (对比基线)
│   ├── cFUMI_code/                      # cFUMI 算法实现
│   ├── eFUMI_code/                      # eFUMI 算法实现
│   ├── DL_FUMI_code/                    # DL-FUMI 算法实现
│   ├── run_efumi_on_gulfport.m          # eFUMI Gulfport 实验
│   ├── run_efumi_on_*.m                 # 各目标变体
│   └── *.mat                            # eFUMI 端元结果
│
├── MIHE-master/                    ★ MI-HE 算法 (对比基线)
│   ├── MIHE_Code/                       # MI-HE 算法实现
│   └── demo_MIHE_incomplete_backgr_knowledge.m  # MI-HE 演示
│
├── MUUFLGulfport-master/          ★ Gulfport 数据集 + Bullwinkle 检测框架
│   └── MUUFLGulfport-master/
│       └── MUUFLGulfportDataCollection/
│           ├── signature_detectors/     # ACE, SMF 等检测器
│           ├── Bullwinkle/              # Bullwinkle 评分引擎
│           ├── util/                    # 工具函数 (score, auc_upto_far)
│           └── demo_test_mivca_on_gulf4classes_v2.m  # 官方检测演示
│
├── backup/                         ★ 备份
└── 开题报告_new.pdf                # 毕设开题报告
```

---

## 数据集

### MUUFL Gulfport

| 属性 | 值 |
|------|-----|
| 图像尺寸 | 325 × 337 像素 |
| 波段数 | 72 |
| 目标类别 | Brown, Dark Green, Faux Vineyard Green, Pea Green |
| 目标总数 | 64 个（各类别数量不等） |
| 目标尺寸 | 0.5m², 1m², 3m², 6m² |
| 空间分辨率 | ~0.54m |

### Pavia University

用于额外验证，目标为 Class 5（金属屋顶）。

---

## 算法对比

### 参与比较的算法

| 算法 | 全称 | 特点 | 来源 |
|------|------|------|------|
| **MIVCA** | Multiple Instance VCA | 迭代清洗 + VCA 提取 | **本毕设提出** |
| Standard VCA | Vertex Component Analysis | 直接对正包 VCA | Nascimento & Dias, 2004 |
| eFUMI | extended Functions of Multiple Instances | 概率生成模型 | Jiao & Zare, 2015 |
| MI-HE | Multiple Instance Hybrid Estimator | 混合估计 | Jiao et al., 2018 |

### Gulfport 数据集上的 SAD 对比 (度)

| 目标类别 | MIVCA | MI-HE | eFUMI |
|---------|-------|-------|-------|
| Brown | ~0.04° | ~19.33° | ~0.06° |
| Dark Green | — | — | — |
| Faux Vineyard Green | — | — | — |
| Pea Green | — | — | — |

> MIVCA 在 Brown 目标上 SAD 仅为 0.04°，比 MI-HE 提升了约 480 倍。

### 检测性能 (Bullwinkle 框架, Brown 目标)

| 检测器 | pAUC (FAR ≤ 1e-3) |
|--------|-------------------|
| MIVCA-ACE | — |
| MIVCA-SMF | — |

---

## 快速开始

### 环境要求

- **MATLAB R2019b** 或更高版本
- **Statistics and Machine Learning Toolbox**（`perfcurve` 函数）
- **Bullwinkle 检测框架**（仓库内已包含）

### 运行可视化系统（推荐）

```matlab
cd('/path/to/毕设相关/MIVCA_Visualization_System/');
MIVCA_Analyzer
```

GUI 提供完整的一键式工作流：**选择目标类别 → 加载数据 → 运行 MIVCA → 标准 VCA 对比 → ACE/SMF 全图检测 → ROC 评估 → 检测图像可视化**

### 直接运行 MIVCA

```matlab
cd('/path/to/毕设相关/mean0.1/mean0.1/');
main_run_mivca_on_gullfport
```

### 预处理数据

```matlab
cd('/path/to/毕设相关/HyperspectralAnalysisIntroduction-0.3/');
prepare_gulfport_mivca  % 修改 target_color 变量选择目标类别
```

---

## 核心公式

### MIVCA 迭代流程

设 $\mathbf{X}^+$ 为正包矩阵，$\mathbf{X}^-$ 为负包矩阵，$\mathbf{B}^{(k)}$ 为第 $k$ 次迭代估计的背景端元集：

$$\mathbf{B}^{(k)} = \text{VCA}\left(\mathbf{X}^-_{(k)}, p\right)$$

$$\text{index} = \text{OrthoProjection}\left(\mathbf{X}^+_{(k)}, \mathbf{B}^{(k)}\right)$$

$$\mathbf{X}^-_{(k+1)} = \left[\mathbf{X}^-_{(k)} \mid \mathbf{X}^+_{(k)}[\text{index}]\right], \quad \mathbf{X}^+_{(k+1)} = \mathbf{X}^+_{(k)}\setminus\text{index}$$

$$\mathbf{e}^{(k)} = \text{VCA}\left(\mathbf{X}^+_{(k+1)}, 1\right)$$

**收敛条件：** $\min\|\text{proj}_{\mathbf{B}^\perp}(\mathbf{x}_i^+)\| < \text{阈值}$

### ACE 检测器 (Adaptive Cosine Estimator)

$$D_{\text{ACE}}(\mathbf{x}) = \frac{\left[(\mathbf{s} - \boldsymbol{\mu})^\top \boldsymbol{\Sigma}^{-1} (\mathbf{x} - \boldsymbol{\mu})\right]^2}{\left[(\mathbf{s} - \boldsymbol{\mu})^\top \boldsymbol{\Sigma}^{-1} (\mathbf{s} - \boldsymbol{\mu})\right]\left[(\mathbf{x} - \boldsymbol{\mu})^\top \boldsymbol{\Sigma}^{-1} (\mathbf{x} - \boldsymbol{\mu})\right]}$$

其中 $\boldsymbol{\mu}, \boldsymbol{\Sigma}$ 从负包估计，$\mathbf{s}$ 为 MIVCA 提取的目标端元。

### SAD (Spectral Angle Distance)

$$\text{SAD}(\mathbf{e}_{\text{est}}, \mathbf{e}_{\text{true}}) = \arccos\left(\frac{\mathbf{e}_{\text{est}} \cdot \mathbf{e}_{\text{true}}}{\|\mathbf{e}_{\text{est}}\| \cdot \|\mathbf{e}_{\text{true}}\|}\right) \times \frac{180}{\pi}$$

---

## 主要参考文献

1. **MIVCA (本毕设提出)** — 基于 VCA 与正交投影的多示例端元迭代提取
2. Nascimento, J. M. P., & Dias, J. M. B. (2004). *Vertex Component Analysis: A Fast Algorithm to Unmix Hyperspectral Data*. IEEE TGRS.
3. Jiao, C., & Zare, A. (2015). *Functions of Multiple Instances for Learning Target Signatures*. IEEE TGRS, 53(8). → **eFUMI / cFUMI**
4. Jiao, C., Chen, C., McGarvey, R., Bohlman, S., & Zare, A. (2018). *Multiple Instance Hybrid Estimator for Hyperspectral Target Characterization and Sub-pixel Target Detection*. ISPRS JPRS. → **MI-HE**
5. Glenn, T., & Zare, A. (2018). *A Brief Introduction to Hyperspectral Image Analysis*. Phenome 2018 Workshop. → **HSI 入门教程**
6. Jiao, C., & Zare, A. (2016). *Multiple Instance Dictionary Learning using Functions of Multiple Instances*. ICPR. → **DL-FUMI**

---

## 许可证与引用

本仓库包含第三方开源代码（FUMI、MI-HE、Bullwinkle 框架），各部分遵循其原始许可证：

- **FUMI** (cFUMI / eFUMI / DL-FUMI): © GatorSense, University of Florida. MIT License.
- **MI-HE**: © GatorSense, University of Florida. MIT License.
- **MUUFL Gulfport Dataset & Bullwinkle**: © GatorSense, University of Florida.
- **MIVCA 算法与可视化系统**: 毕设原创代码 © 2026.

如使用本仓库中的算法代码，请引用对应的原始论文。

---

<p align="center">
  <sub>Built with MATLAB · Bullwinkle Framework · GatorSense Toolkits</sub>
</p>
