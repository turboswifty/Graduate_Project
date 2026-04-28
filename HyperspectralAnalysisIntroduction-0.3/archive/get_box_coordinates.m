% =========================================================================
% 交互式获取矩形框 (Bounding Box) 坐标工具
% =========================================================================
clc; clear all; close all;

%% 1. 加载真值图
load('PaviaU_gt.mat'); 
target_class = 5; 
target_mask = (paviaU_gt == target_class);
[rows, cols] = size(paviaU_gt);

%% 2. 绘制高亮图像
figure('Name', '请在图上画框', 'Position', [200, 200, 600, 800]);
imagesc(target_mask);
colormap(gca, [0.9 0.9 0.9; 0.9 0.1 0.1]); % 灰底红字
axis image;
title('【交互操作】：请用鼠标在红色目标外围，按住左键拖拽画一个矩形框', 'FontSize', 12, 'Color', 'b');

%% 3. 呼叫 getrect 开启交互模式
disp('等待用户在图上画框...');
% getrect 会暂停程序，直到你在图上画完框松开鼠标
rect = getrect; % 返回格式为：[x_min, y_min, width, height]

%% 4. 坐标转换与边界保护
% 注意：MATLAB图像坐标系中，x 代表列 (col)，y 代表行 (row)
c_start = round(rect(1));              % 起始列
r_start = round(rect(2));              % 起始行
c_end   = round(rect(1) + rect(3));    % 结束列 = 起始列 + 宽度
r_end   = round(rect(2) + rect(4));    % 结束行 = 起始行 + 高度

% 防止你手抖画到图片外面去导致后续报错
r_start = max(1, r_start);
r_end   = min(rows, r_end);
c_start = max(1, c_start);
c_end   = min(cols, c_end);

%% 5. 打印最终结果，方便你直接复制
disp(' ');
disp('==================================================');
disp('✅ 坐标获取成功！请将下面这两行代码直接复制到你的预处理脚本中：');
disp('--------------------------------------------------');
fprintf('r_start = %d;  r_end = %d;\n', r_start, r_end);
fprintf('c_start = %d;  c_end = %d;\n', c_start, c_end);
disp('==================================================');

% 画个蓝框给你看看你选中的区域
hold on;
rectangle('Position', rect, 'EdgeColor', 'b', 'LineWidth', 2);



% ==================================================
% ✅ 坐标获取成功！请将下面这两行代码直接复制到你的预处理脚本中：
% --------------------------------------------------
% r_start = 95;  r_end = 314;
% c_start = 66;  c_end = 223;
% ==================================================

