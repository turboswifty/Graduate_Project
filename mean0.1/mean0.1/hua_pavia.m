clc; clear all; close all;

%% 1. 加载 PaviaU 的数据
% 【修复】：加载全图所有的 Class 5 真实光谱，而不是 gulfport 的 E_t！
load('/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/archive/paviaU_class5_all_gt_spectra.mat'); % 变量名: all_class5_spectra [103 x 像素数]
load('end04_pavia_mivca.mat');                  % 变量名: E_vca [103 x 1]

% 自动获取波段数 (PaviaU 应该是 103)
[bands, num_pixels] = size(all_class5_spectra); 

%% 2. === 进行 Min-Max 归一化 ===
% 对那几千条真实光谱【逐列】进行归一化，保证每一根都在 [0,1] 之间
gt_min = min(all_class5_spectra, [], 1);
gt_max = max(all_class5_spectra, [], 1);
gt_norm = (all_class5_spectra - gt_min) ./ (gt_max - gt_min);

% 归一化 MIVCA 提取的端元
E_vca_plot = (E_vca - min(E_vca)) / (max(E_vca) - min(E_vca));

% 顺便计算一下所有真实光谱的平均值，作为一条“基准线”
mean_gt_norm = mean(gt_norm, 2);

%% 3. === 高级可视化绘制 ===
figure('Name', 'Endmember Envelope Comparison', 'Position', [150, 150, 800, 500]); 
hold on;

% 【第一层：画所有的真实光谱】
% 直接传入矩阵，MATLAB 会画出每一列。颜色设置为极浅的粉色 [1, 0.8, 0.8]
% 这样几千根线叠在一起就会形成一个漂亮的“红色包络带”，不会喧宾夺主
plot(1:bands, gt_norm, 'Color', [1, 0.8, 0.8]); 

% 【第二层：画真值的平均准线】
% 用醒目的红色虚线标出这群真值的平均趋势，并记录句柄 h1 用于生成图例
h1 = plot(1:bands, mean_gt_norm, 'r--', 'LineWidth', 2.5);

% 【第三层：画你算法的提取结果】
% 用深蓝色实线画出 MIVCA 的结果，记录句柄 h2
h2 = plot(1:bands, E_vca_plot, 'b-', 'LineWidth', 2.5);

% (如果你以后跑了 MIHE，可以把 MIHE 的线加在这里作为第四层)

title('PaviaU 金属屋顶: 光谱包络带 vs MIVCA 提取结果', 'FontSize', 14);
xlabel('波段 (Bands)', 'FontSize', 12);
ylabel('归一化反射率 (Normalized Reflectance)', 'FontSize', 12);

% 图例只需要标注这两根核心粗线，不需要标那几千根浅色细线
legend([h1, h2], 'Class 5 真实平均光谱', 'MIVCA 提取端元', 'FontSize', 12, 'Location', 'best');
grid on;