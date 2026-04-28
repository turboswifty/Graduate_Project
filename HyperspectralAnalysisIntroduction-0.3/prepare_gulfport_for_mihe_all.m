% =========================================================================
% MUUFL Gulfport 数据预处理：为 MIHE 生成全部四个类别的 Cell Array 数据集
% 基于 prepare_gulfport_for_mihe.m 改造，不覆盖原文件
% =========================================================================
clc; clear all; close all;
rng(42);

%% 1. 加载原始数据
disp('正在加载 MUUFL Gulfport 数据集...');
load('muufl_gulfport_campus_w_lidar_1.mat');
load('tgt_img_spectra.mat');

%% 2. 解析高光谱图像立方体
hsi_cube = double(hsi.Data);
[rows, cols, bands] = size(hsi_cube);
total_pixels = rows * cols;
hsi_2d = reshape(hsi_cube, total_pixels, bands)';

%% 3. 定义四个目标类别及其对应的端元索引
target_colors = {'brown', 'dark green', 'faux vineyard green', 'pea green'};
spectra_indices = [1, 2, 3, 4];  % 对应 tgt_img_spectra.spectra 的列

gt = hsi.groundTruth;
num_targets = length(gt.Targets_Type);

%% 4. 逐类别生成 MIHE 数据集
for color_idx = 1:length(target_colors)
    target_color = target_colors{color_idx};
    fprintf('\n========== 正在处理: %s ==========\n', target_color);

    % --- 4a. 构建正包 Cell 数组 ---
    pos_bags = {};
    pos_indices_all = [];

    for i = 1:num_targets
        current_type = strtrim(lower(gt.Targets_Type{i}));
        if strcmp(current_type, target_color)
            r = gt.Targets_rowIndices(i);
            c = gt.Targets_colIndices(i);

            r_range = max(1, r-2) : min(rows, r+2);
            c_range = max(1, c-2) : min(cols, c+2);

            current_bag_indices = [];
            for rr = r_range
                for cc = c_range
                    linear_idx = (cc - 1) * rows + rr;
                    current_bag_indices = [current_bag_indices, linear_idx];
                end
            end
            pos_bags{end+1} = hsi_2d(:, current_bag_indices);
            pos_indices_all = [pos_indices_all, current_bag_indices];
        end
    end
    pos_indices_all = unique(pos_indices_all);
    fprintf('  正包数量: %d\n', length(pos_bags));

    % --- 4b. 构建负包 Cell 数组 ---
    all_indices = 1:total_pixels;
    neg_indices = setdiff(all_indices, pos_indices_all);

    num_bg_samples = 10000;
    if length(neg_indices) > num_bg_samples
        rand_idx = randperm(length(neg_indices), num_bg_samples);
        sampled_neg_indices = neg_indices(rand_idx);
    else
        sampled_neg_indices = neg_indices;
    end

    % 将背景像素均分成 5 个负包
    neg_bags = {};
    num_neg_bags = 5;
    pixels_per_neg = floor(num_bg_samples / num_neg_bags);

    for i = 1:num_neg_bags
        start_idx = (i-1)*pixels_per_neg + 1;
        if i == num_neg_bags
            end_idx = num_bg_samples;
        else
            end_idx = i*pixels_per_neg;
        end
        current_neg_idx = sampled_neg_indices(start_idx:end_idx);
        neg_bags{end+1} = hsi_2d(:, current_neg_idx);
    end

    % --- 4c. 匹配真实端元 ---
    E_t = double(tgt_img_spectra.spectra(:, spectra_indices(color_idx)));

    % --- 4d. 保存 ---
    % 文件名中的空格替换为下划线
    safe_name = strrep(target_color, ' ', '_');
    save_name = ['mihe_data_gulfport_', safe_name, '.mat'];
    save(save_name, 'pos_bags', 'neg_bags', 'E_t');
    fprintf('  已保存至: %s\n', save_name);
end

disp('==================================================');
disp('全部四个类别的 MIHE 数据集已生成完毕！');
disp('生成文件:');
disp('  mihe_data_gulfport_brown.mat');
disp('  mihe_data_gulfport_dark_green.mat');
disp('  mihe_data_gulfport_faux_vineyard_green.mat');
disp('  mihe_data_gulfport_pea_green.mat');
disp('==================================================');
