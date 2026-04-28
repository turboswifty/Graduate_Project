% =========================================================================
% PaviaU 数据集空间分布可视化脚本 (重点观察特定类别的连通性)
% =========================================================================
clc; clear all; close all;

%% 1. 加载真值数据
disp('正在加载 PaviaU 真值数据...');
try
    load('PaviaU_gt.mat'); % 请确保该文件在当前工作目录下
catch
    error('未找到 PaviaU_gt.mat 文件，请检查路径是否正确！');
end

%% 2. 设定要观察的目标类别
% PaviaU 类别参考:
% 1:沥青(Asphalt), 2:草地(Meadows), 3:碎石(Gravel), 4:树木(Trees), 
% 5:金属屋顶(Metal sheets), 6:裸土(Bare Soil), 7:沥青屋顶(Bitumen), 
% 8:自锁砖(Bricks), 9:阴影(Shadows)
target_class = 5; 

%% 3. 生成二值掩码 (Binary Mask)
% 矩阵中等于 target_class 的位置设为 1 (逻辑真)，其余设为 0 (逻辑假)
target_mask = (paviaU_gt == target_class);

% 统计像素总数
num_pixels = sum(target_mask(:));
disp(['✅ 类别 ', num2str(target_class), ' 共有 ', num2str(num_pixels), ' 个像素点。']);

%% 4. 可视化绘制
% 创建一个较宽的绘图窗口以便并排显示两张图
figure('Name', ['PaviaU Class ', num2str(target_class), ' Distribution'], 'Position', [100, 100, 900, 500]);

% --- 子图 1：标准黑白二值图 ---
subplot(1, 2, 1);
imagesc(target_mask);
colormap(gca, gray); % 使用灰度映射：0为黑(背景)，1为白(目标)
axis image off; % 保持图像真实的物理长宽比 (610x340)，关闭坐标轴刻度更清爽
title(['Class ', num2str(target_class), ' 分布 (二值图)'], 'FontSize', 12);

% --- 子图 2：红色高亮显示 (极其适合放在论文或PPT中) ---
subplot(1, 2, 2);
imagesc(target_mask);
% 自定义颜色映射表 (Colormap)：第一行是背景色，第二行是目标色
custom_cmap = [0.9 0.9 0.9;  % 背景设为浅灰色 (不刺眼)
               0.9 0.1 0.1]; % 目标设为醒目的红色
colormap(gca, custom_cmap);
axis image off;
title(['Class ', num2str(target_class), ' 分布 (红色连通域)'], 'FontSize', 12);

% 添加全局总标题
sgtitle(['Pavia University 数据集 - 类别 ', num2str(target_class), ' (金属屋顶) 空间分布'], 'FontSize', 15, 'FontWeight', 'bold');