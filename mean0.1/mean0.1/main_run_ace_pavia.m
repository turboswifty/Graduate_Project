% =========================================================================
% PaviaU 综合目标检测：基于 MIVCA 端元的 ACE 算法全图探测与评估
% =========================================================================
clc; clear all; close all;

%% 1. 加载数据
disp('正在加载高光谱数据、真值与端元...');
load('/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/archive/PaviaU.mat');         % 加载原图 paviaU
load('/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/archive/PaviaU_gt.mat');      % 加载真值 paviaU_gt
load('end04_pavia_mivca.mat');    % 加载你的 MIVCA 端元 E_vca

% 数据类型强转，防止矩阵运算报错
X_cube = double(paviaU);
[rows, cols, bands] = size(X_cube);
total_pixels = rows * cols;

% 拉平成 2D 矩阵：[波段数 x 像素数]
X_2d = reshape(X_cube, total_pixels, bands)';

% 强制端元为列向量
d = E_vca(:); 

%% 2. 严谨的全局 ACE 算法实现 (Vectorized 向量化加速)
disp('正在计算全图背景统计矩阵...');

% (1) 计算全局自相关矩阵 R (Correlation Matrix)
R = (X_2d * X_2d') / total_pixels;

% (2) 计算 R 的逆矩阵
% 高光谱波段高度相关，R 极易变成奇异矩阵(Singular Matrix)。
% 我们使用广义逆 pinv，或者加入微小的对角线加载防止报错
R_inv = pinv(R); 

disp('正在执行 ACE 目标检测投影...');
% (3) ACE 核心公式计算
% 公式: D_ACE = (d' * R_inv * x)^2 / [(d' * R_inv * d) * (x' * R_inv * x)]
% 为了处理几十万像素，必须使用矩阵向量化计算

R_inv_d = R_inv * d; % 提前算好 R^-1 * d

% 计算分子 (Numerator)
num = (R_inv_d' * X_2d).^2; 

% 计算分母 (Denominator)
den1 = d' * R_inv_d; % 标量
den2 = sum(X_2d .* (R_inv * X_2d), 1); % 1xN 向量，等价于计算每个像素的 x' * R^-1 * x

% 计算最终 ACE 分数，加入 eps 防止除零溢出
ace_score_1d = num ./ (den1 .* den2 + eps);

% (4) 将 1D 打分重新映射回 2D 空间尺寸
ace_map = reshape(ace_score_1d, rows, cols);

%% 3. 获取 Ground Truth 以供对比
target_class = 5; % 金属屋顶
gt_mask = (paviaU_gt == target_class);

%% 4. 生成顶级学术可视化图表
disp('正在生成综合评估可视化报告...');

figure('Name', 'MIVCA + ACE Target Detection Report', 'Position', [100, 150, 1200, 450]);

% --- 子图 1：Ground Truth (真实分布) ---
subplot(1, 3, 1);
imagesc(gt_mask);
colormap(gca, gray);
axis image off;
title('Ground Truth (真实金属屋顶分布)', 'FontSize', 12, 'FontWeight', 'bold');

% --- 子图 2：ACE 热力图 (算法检测结果) ---
subplot(1, 3, 2);
imagesc(ace_map);
% 使用 jet 伪彩色：越红代表得分越高(越像目标)，越蓝代表得分越低(背景)
colormap(gca, jet); 
colorbar; 
axis image off;
title('ACE 丰度热力图 (MIVCA 端元驱动)', 'FontSize', 12, 'FontWeight', 'bold');

% --- 子图 3：ROC 曲线与 AUC 定量评估 ---
subplot(1, 3, 3);
try
    % 使用 MATLAB 自带的 perfcurve 绘制 ROC
    labels = gt_mask(:);
    scores = ace_score_1d(:);
    [X_roc, Y_roc, ~, AUC] = perfcurve(labels, scores, 1);
    
    plot(X_roc, Y_roc, 'r-', 'LineWidth', 2.5);
    hold on;
    plot([0, 1], [0, 1], 'k--', 'LineWidth', 1); % 随机猜测基准线
    
    xlim([0 1]); ylim([0 1]);
    xlabel('假阳性率 (False Positive Rate)', 'FontSize', 11);
    ylabel('真阳性率 (True Positive Rate)', 'FontSize', 11);
    title(['ROC 曲线 (AUC = ', num2str(AUC, '%.4f'), ')'], 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
catch
    % 如果用户的 MATLAB 没装统计工具箱，提供降级提示
    text(0.1, 0.5, '需要 Statistics and Machine Learning Toolbox 来绘制 ROC', 'Color', 'r', 'FontSize', 10);
    axis off;
end

sgtitle('MIVCA 端元全局检测评估 (Pavia University)', 'FontSize', 16, 'FontWeight', 'bold');
disp('✅ ACE 探测完成！请查看弹出的图表。');