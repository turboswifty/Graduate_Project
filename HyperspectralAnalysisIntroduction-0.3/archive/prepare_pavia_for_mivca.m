% =========================================================================
% PaviaU 预处理：基于【矩形边界框 (Bounding Box)】的正负包切分
% =========================================================================
clc; clear all; close all;

%% 1. 加载数据
disp('正在加载 PaviaU 数据...');
load('PaviaU.mat');    
load('PaviaU_gt.mat'); 

hsi_cube = double(paviaU); 
[rows, cols, bands] = size(hsi_cube);
total_pixels = rows * cols;
hsi_2d = reshape(hsi_cube, total_pixels, bands)';

target_class = 5;  % 金属屋顶

%% 2. 【核心修改】：定义你的大矩形框 (Bounding Box)
% 请根据你截图里的位置，大致估算一下这个矩形框的行列范围
% 例如你截图里的那个区域大概在图的右侧中部
r_start = 95;  r_end = 314;  % 行的范围 (上下)
c_start = 66;  c_end = 223;  % 列的范围 (左右)

disp(['已设定矩形框区域：行 ', num2str(r_start), '-', num2str(r_end), '，列 ', num2str(c_start), '-', num2str(c_end)]);

% 收集矩形框内所有像素的索引，作为唯一的巨大正包！
pos_indices = [];
for rr = r_start : r_end
    for cc = c_start : c_end
        linear_idx = (cc - 1) * rows + rr;
        pos_indices = [pos_indices, linear_idx];
    end
end
positive = hsi_2d(:, pos_indices);

%% 3. 提取负包 (依然要严防死守，确保背景干净)
disp('正在提取负包...');
% 我们依然要把全图所有的 Class 5 排除在外，防止背景子空间被污染
all_indices = 1:total_pixels;
all_target_indices = find(paviaU_gt == target_class); 
neg_indices = setdiff(all_indices, all_target_indices); 

% 降采样 10000 个背景像素
num_bg_samples = 10000;
sampled_neg_indices = neg_indices(randperm(length(neg_indices), num_bg_samples));
negative = hsi_2d(:, sampled_neg_indices);

%% 4. 生成完美的对比标签
disp('正在生成标签...');
E_t = mean(hsi_2d(:, all_target_indices), 2); % 目标参考端元

eval_indices = [pos_indices(:)', sampled_neg_indices(:)']; 

% 初始化
labels_bag_full = zeros(1, total_pixels);
labels_point_full = zeros(1, total_pixels);

% (1) Bag 级弱标签：只要在矩形框内，统统视为 1
labels_bag_full(pos_indices) = 1; 

% (2) Point 级强标签：只有矩形框内真正是 Class 5 的像素，才是真实的 1！
for i = 1:length(pos_indices)
    idx = pos_indices(i);
    if paviaU_gt(idx) == target_class
        labels_point_full(idx) = 1;
    end
end

labels_bag = labels_bag_full(eval_indices);
labels_point = labels_point_full(eval_indices);

%% 5. 直观可视化你的矩形框
figure('Name', 'Bounding Box Validation', 'Position', [150, 150, 800, 400]);

% 画出你的矩形框覆盖了什么
subplot(1, 2, 1);
box_mask = zeros(rows, cols);
box_mask(r_start:r_end, c_start:c_end) = 1;
imagesc(box_mask);
colormap(gca, [0.9 0.9 0.9; 0.2 0.5 0.8]); % 蓝色矩形框
axis image off;
title('你划定的大矩形框 (Bag 级别标签)', 'FontSize', 12);

% 画出矩形框里面真正包含的目标
subplot(1, 2, 2);
real_targets_in_box = box_mask .* (paviaU_gt == target_class);
imagesc(real_targets_in_box);
colormap(gca, [0.9 0.9 0.9; 0.9 0.1 0.1]); % 红色真实目标
axis image off;
title('矩形框内的真实金属屋顶 (Point 级别真值)', 'FontSize', 12);


%% === 新增修改：保存所有 Class 5 像素的光谱 GT ===
disp('正在提取全图所有 Class 5 像素的光谱数据...');

% 1. 找到全图中所有 Class 5 的索引 (不再局限于矩形框)
all_class5_indices = find(paviaU_gt == target_class);

% 2. 提取这些像素对应的光谱数据
% hsi_2d 的维度是 [103 x 109525]，提取后得到 [103 x 数量]
all_class5_spectra = hsi_2d(:, all_class5_indices);

% 3. 保存到新文件
save('paviaU_class5_all_gt_spectra.mat', 'all_class5_spectra');

fprintf('✅ 已成功保存 %d 条 Class 5 真实光谱数据至 paviaU_class5_all_gt_spectra.mat\n', size(all_class5_spectra, 2));



%% 6. 保存
save('positive_pavia.mat', 'positive');
save('negative_pavia.mat', 'negative');
save('E_t_pavia.mat', 'E_t');
save('ground_truth_pavia.mat', 'labels_point', 'labels_bag');
disp('==================================================');
disp('✅ 矩形框正包切分完成！请直接用 MIVCA 主程序去跑！');