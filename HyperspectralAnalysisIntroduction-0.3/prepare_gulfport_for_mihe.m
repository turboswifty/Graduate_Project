% =========================================================================
% MUUFL Gulfport 数据预处理：专为 MIHE (Cell Array) 格式定制
% =========================================================================
clc; clear all; close all;
rng(42);

%% 1. 加载原始数据
disp('正在加载 MUUFL Gulfport 数据集...');
load('muufl_gulfport_campus_w_lidar_1.mat'); 
load('tgt_img_spectra.mat'); 

target_color = 'brown'; 

%% 2. 解析高光谱图像立方体 (转换为 double 防报错)
% 【极其关键】：MIHE 内部也调用了 svds 和 VCA，必须转为 double！
hsi_cube = double(hsi.Data); 
[rows, cols, bands] = size(hsi_cube);
total_pixels = rows * cols;
hsi_2d = reshape(hsi_cube, total_pixels, bands)';

%% 3. 构建正包 (Positive Bags) -> 直接存入 Cell 数组
gt = hsi.groundTruth;
num_targets = length(gt.Targets_Type);

pos_bags = {}; % 初始化正包 Cell 数组
pos_indices_all = []; % 用于记录所有正包像素，方便后面抠除背景

for i = 1:num_targets
    ct = strtrim(lower(gt.Targets_Type{i}));
    disp(ct);
end

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
        % 将当前这个目标的 5x5 窗口数据作为一个独立的包，塞进 Cell
        pos_bags{end+1} = hsi_2d(:, current_bag_indices);
        % 汇总所有正包索引
        pos_indices_all = [pos_indices_all, current_bag_indices];
    end
end
% 全局去重，仅用于提取纯背景
pos_indices_all = unique(pos_indices_all);

%% 4. 构建负包 (Negative Bags)
disp('正在提取并降采样负包...');
all_indices = 1:total_pixels;
neg_indices = setdiff(all_indices, pos_indices_all);

% 随机抽取 10000 个背景像素
num_bg_samples = 10000;
rand_idx = randperm(length(neg_indices), num_bg_samples);
sampled_neg_indices = neg_indices(rand_idx);

% 为了符合 MIL 的范式，我们将这 10000 个背景像素平分成 5 个负包
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

%% 5. 匹配真实端元
if strcmp(target_color, 'brown')
    E_t = double(tgt_img_spectra.spectra(:, 1)); 
elseif strcmp(target_color, 'dark_green')
    E_t = double(tgt_img_spectra.spectra(:, 2));
elseif strcmp(target_color, 'faux_vineyard_green')
    E_t = double(tgt_img_spectra.spectra(:, 3));
elseif strcmp(target_color, 'pea_green')
    E_t = double(tgt_img_spectra.spectra(:, 4));
end

%% 6. 保存数据
disp('正在保存为 MIHE 专属格式...');
save('mihe_data_gulfport.mat', 'pos_bags', 'neg_bags', 'E_t');
disp(['✅ 成功构建 ', num2str(length(pos_bags)), ' 个正包 (Cell)']);
disp(['✅ 成功构建 ', num2str(length(neg_bags)), ' 个负包 (Cell)']);