% =========================================================================
% 综合评估报告：MIVCA 端元提取与 ACE 目标检测联调 (Gulfport 数据集)
% =========================================================================
clc; clear all; close all;

%% 1. 加载所有前置数据
disp('正在加载数据与端元...');
% 1. 加载原始高光谱数据
load('/Users/jihao/MUUFLGulfport-master/MUUFLGulfport-master/MUUFLGulfportDataCollection/muufl_gulfport_campus_w_lidar_1.mat'); 
% 2. 加载你在预处理时生成的真值掩码和标签
load('ground_truth_gulfport1.mat'); % 需要里面有 gt_mask_2d 和 labels_point
% 3. 加载真实端元
load('E_t_gulfport1.mat');
% 4. 加载 MIVCA 跑出来的估计端元
load('end04_gulfport3_mivca.mat'); % 假设你保存的变量叫 E_vca

%% 2. 数据准备与预处理
hsi_cube = double(hsi.Data);
[rows, cols, bands] = size(hsi_cube);
total_pixels = rows * cols;
X_2d = reshape(hsi_cube, total_pixels, bands)';

% 确保端元是列向量
E_t = double(E_t(:));
E_vca = double(E_vca(:));

%% 3. 端元光谱比较 (SAD 计算与归一化)
% 计算光谱角距离 (SAD)
sad_angle = acos(dot(E_vca, E_t) / (norm(E_vca) * norm(E_t))) * 180 / pi;
disp(['✅ MIVCA 提取端元 SAD 误差: ', num2str(sad_angle, '%.4f'), ' 度']);

% Min-Max 归一化，仅为了画图时对比形状趋势
E_t_norm = (E_t - min(E_t)) / (max(E_t) - min(E_t));
E_vca_norm = (E_vca - min(E_vca)) / (max(E_vca) - min(E_vca));

%% 4. 执行 ACE 目标检测算法 (使用官方 GatorSense 库)
disp('正在调用官方 ace_detector 进行探测...');

% 确保你的搜索路径里加了那个文件夹
addpath('/Users/jihao/MUUFLGulfport-master/MUUFLGulfport-master/MUUFLGulfportDataCollection/signature_detectors'); 

% 官方函数要求 hsi_img 是 3D 的，所以我们直接传 3D 的立方体
% 参数: (数据立方体, 端元列向量, mask留空, mu留空, siginv留空)
[ace_map, mu, siginv] = ace_detector(hsi_cube, E_vca, [], [], []);

% 把生成的二维打分图拉平，方便算 AUC
ace_scores = ace_map(:);

%% 5. 绘制顶会级四联图综合报告
disp('正在生成可视化报告图表...');
figure('Name', 'MIVCA & ACE Comprehensive Report', 'Position', [100, 100, 1000, 800]);

% --- 子图 1：端元对比图 ---
subplot(2, 2, 1);
plot(1:bands, E_t_norm, 'r-', 'LineWidth', 2); hold on;
plot(1:bands, E_vca_norm, 'b--', 'LineWidth', 2);
title(['光谱对比 (SAD: ', num2str(sad_angle, '%.2f'), '°)'], 'FontSize', 12, 'FontWeight', 'bold');
xlabel('波段 (Bands)'); ylabel('归一化反射率');
legend('真实端元 (Ground Truth)', 'MIVCA 估计端元', 'Location', 'best');
grid on;

% --- 子图 2：真实分布 (Ground Truth) ---
subplot(2, 2, 2);
% 我们用你在前一个脚本里保存的全图 2D 真值
imagesc(gt_mask_2d);
colormap(gca, gray);
axis image off;
title('真实目标分布 (Ground Truth)', 'FontSize', 12, 'FontWeight', 'bold');

% --- 子图 3：ACE 丰度热力图 ---
subplot(2, 2, 3);
imagesc(ace_map);
colormap(gca, jet); % 伪彩色热力图
colorbar;
axis image off;
title('ACE 目标检测热力图', 'FontSize', 12, 'FontWeight', 'bold');

% --- 子图 4：ROC 曲线与 AUC 计算 ---
subplot(2, 2, 4);
try
    % 准备一维的真实标签和预测得分
    gt_labels_1d = gt_mask_2d(:);
    
    % perfcurve 自动变换成百上千个阈值，算出完美曲线
    [X_roc, Y_roc, ~, AUC] = perfcurve(gt_labels_1d, ace_scores, 1);
    
    plot(X_roc, Y_roc, 'r-', 'LineWidth', 2.5); hold on;
    plot([0, 1], [0, 1], 'k--', 'LineWidth', 1); % 随机猜测对照线
    
    xlim([0 1]); ylim([0 1]);
    xlabel('假阳性率 (FPR)'); ylabel('真阳性率 (TPR)');
    title(['ROC 曲线 (AUC = ', num2str(AUC, '%.4f'), ')'], 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    disp(['✅ 全图 ACE 检测 AUC 达到: ', num2str(AUC, '%.4f')]);
catch
    text(0.2, 0.5, '需安装 Statistics Toolbox 绘制 ROC', 'Color', 'r', 'FontSize', 12);
    axis off;
end


% 添加总标题
sgtitle('MIVCA 端元提取与 ACE 目标检测综合评估报告 (Gulfport Campus)', 'FontSize', 16, 'FontWeight', 'bold');
disp('==================================================');
disp('实验运行完毕！截取该四子图可直接用于论文插图。');