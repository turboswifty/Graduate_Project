% =========================================================================
% 综合评估报告：MIVCA 端元提取与 ACE 目标检测联调 (Gulfport 数据集)
% =========================================================================
clc; clear all; close all;

%% 0. 用户选项（加在最开头，clc 之后）
% =========================================================================
% 可选模式: 'full' = 四联图报告, 'roc_only' = 仅绘制并导出子图4 (ROC)
% =========================================================================
PLOT_MODE = 'full';      % <-- 改成 'roc_only' 即可只跑 ROC 子图

%% 1. 加载所有前置数据
disp('正在加载数据与端元...');
% 1. 加载原始高光谱数据
load('/Users/jihao/MUUFLGulfport-master/MUUFLGulfport-master/MUUFLGulfportDataCollection/muufl_gulfport_campus_3.mat'); 
% 2. 加载你在预处理时生成的真值掩码和标签
load('ground_truth_gulfport3.mat'); % 需要里面有 gt_mask_2d 和 labels_point
% 3. 加载真实端元
load('E_t_gulfport3.mat');
% 4. 加载 MIVCA 跑出来的估计端元
load('end04_gulfport1_mivca.mat'); % 假设你保存的变量叫 E_vca

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
%% 5. 绘制与导出（根据 PLOT_MODE 自动切换）
disp('正在生成可视化报告图表...');

if strcmpi(PLOT_MODE, 'full')
    % ==================== 模式 A：四联图 ====================
    figure('Name', 'MIVCA & ACE Comprehensive Report', 'Position', [100, 100, 1000, 800]);
    
    % --- 子图 1：端元对比 ---
    subplot(2, 2, 1);
    plot(1:bands, E_t_norm, 'r-', 'LineWidth', 2); hold on;
    plot(1:bands, E_vca_norm, 'b--', 'LineWidth', 2);
    title(['光谱对比 (SAD: ', num2str(sad_angle, '%.2f'), '°)'], 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('波段 (Bands)'); ylabel('归一化反射率');
    legend('真实端元 (Ground Truth)', 'MIVCA 估计端元', 'Location', 'best');
    grid on;
    
    % --- 子图 2：Ground Truth ---
    subplot(2, 2, 2);
    imagesc(gt_mask_2d);
    colormap(gca, gray); axis image off;
    title('真实目标分布 (Ground Truth)', 'FontSize', 12, 'FontWeight', 'bold');
    
    % --- 子图 3：ACE 热力图 ---
    subplot(2, 2, 3);
    imagesc(ace_map);
    colormap(gca, jet); colorbar; axis image off;
    title('ACE 目标检测热力图', 'FontSize', 12, 'FontWeight', 'bold');
    
    % --- 子图 4：官方 GatorSense ROC 曲线与 AUC 计算 ---
    subplot(2, 2, 4);
    
    % 确保添加了官方工具库路径 (请根据你的实际文件夹结构微调)
    addpath('/Users/jihao/MUUFLGulfport-master/MUUFLGulfport-master/MUUFLGulfportDataCollection/util'); 
    addpath('/Users/jihao/MUUFLGulfport-master/MUUFLGulfport-master/MUUFLGulfportDataCollection/Bullwinkle'); 
    
    try
        % 1. 准备官方打分函数所需的面具 (Masks)
        target_mask = gt_mask_2d;     % 目标真值区域
        bg_mask = ~gt_mask_2d;        % 纯背景区域 (全图剔除目标)
    
        % 2. 调用官方像素级打分函数，获取 检测概率(PD) 和 虚警率(FAR)
        % 官方返回的 far 和 pd 已经是按照阈值排序好的向量了
        [pd, far, thresholds] = score_hylid_perpixel(ace_map, target_mask, bg_mask);
    
        % 3. 计算部分 AUC (Partial AUC)
        % 这里我们设定一个阈值，比如只看虚警率在 10% (0.1) 以内的硬核实力
        % 如果你想看全图的 AUC，可以把 max_far 设为 1.0
        max_far = 0.1; 
        auc_official = auc_upto_far(far, pd, max_far);
        
        % 4. 官方标志性画法：对数坐标轴 (semilogx)
        % 注意：FAR 中可能含有 0，对数坐标下会报错或不显示，所以加上一个极小值 eps
        semilogx(far + eps, pd, 'r-', 'LineWidth', 2.5); hold on;
        
        % 限制 X 轴的显示范围，聚焦高价值区间 (10^-4 到 1)
        xlim([1e-4, 1]); 
        ylim([0 1.05]);
        
        % 使用官方标准的专业术语命名坐标轴
        xlabel('False Alarm Rate (FAR)', 'FontSize', 11, 'FontWeight', 'bold');
        ylabel('Probability of Detection (PD)', 'FontSize', 11, 'FontWeight', 'bold');
        title(['官方对数 ROC (pAUC_{<0.1} = ', num2str(auc_official, '%.4f'), ')'], 'FontSize', 12, 'FontWeight', 'bold');
        grid on;
        
        % 加上 X 轴底部的次级网格，使得对数刻度更明显
        set(gca, 'XMinorGrid', 'on'); 
    
    catch ME
        % 错误捕获：防止路径不对导致绘图失败
        text(1e-3, 0.5, '官方 util 库调用失败，请检查路径', 'Color', 'r', 'FontSize', 12);
        disp(ME.message);
        axis off;
    end
else
    % ==================== 模式 B：仅 ROC 子图 ====================
    figure('Name', 'ROC Curve Only', 'Position', [300, 300, 550, 500]);
    
    try
        gt_labels_1d = gt_mask_2d(:);
        [X_roc, Y_roc, ~, AUC] = perfcurve(gt_labels_1d, ace_scores, 1);
        
        plot(X_roc, Y_roc, 'r-', 'LineWidth', 2.5); hold on;
        plot([0, 1], [0, 1], 'k--', 'LineWidth', 1);
        xlim([0 1]); ylim([0 1]);
        xlabel('假阳性率 (FPR)', 'FontSize', 12); 
        ylabel('真阳性率 (TPR)', 'FontSize', 12);
        title(['ROC 曲线 (AUC = ', num2str(AUC, '%.4f'), ')'], 'FontSize', 14, 'FontWeight', 'bold');
        
        legend({'ACE 检测器', '随机猜测'}, 'Location', 'southeast', 'FontSize', 11);
        grid on;
        
        % 统一字体（Mac 用 STHeiti，Windows 可改 Microsoft YaHei）
        set(findall(gcf, '-property', 'FontName'), 'FontName', 'STHeiti');
        
        % 高清导出（PNG 无损，中文不丢失）
        exportgraphics(gcf, 'roc_only_600dpi.png', 'Resolution', 600);
        
        disp(['✅ ROC 单独绘制完成，AUC = ', num2str(AUC, '%.4f')]);
    catch
        text(0.2, 0.5, '需安装 Statistics Toolbox 绘制 ROC', 'Color', 'r', 'FontSize', 12);
        axis off;
    end
end

disp('==================================================');
disp('实验运行完毕！');