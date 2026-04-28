% =========================================================================
% MUUFL Gulfport 数据集预处理脚本：无缝对接 MIVCA
% =========================================================================
clc; clear all; close all;
rng(42);

%% 1. 加载原始数据
disp('正在加载 MUUFL Gulfport 数据集...');
% 请根据你实际的文件名修改这里
load('muufl_gulfport_campus_w_lidar_1.mat'); % 假设加载后工作区里有 hsi 这个结构体
load('tgt_img_spectra.mat'); % 加载那 4 个官方纯净光谱

%% 2. 设定我们要提取的目标类型
% 你可以随时修改这个变量来测试不同的目标 ('brown', 'dark_green', 'faux_vineyard_green', 'pea_green')
%target_color = 'faux vineyard green';
%target_color = 'dark green';
%target_color = 'brown';
target_color = 'pea green';
disp(['当前设定的提取目标为: ', target_color]);

%% 3. 解析高光谱图像立方体 (Data Cube)
hsi_cube = hsi.Data; 
[rows, cols, bands] = size(hsi_cube);
total_pixels = rows * cols;

% 将 3D 立方体拉平成 2D 矩阵: [波段数 x 总像素数] (72 x 109525)
hsi_2d = reshape(hsi_cube, total_pixels, bands)';

%% 4. 根据坐标和 Targets_type 划分正负包
gt = hsi.groundTruth;
num_targets = length(gt.Targets_Type);

pos_indices = []; % 用于存放正包的像素索引

% 遍历所有的 64 个目标标注点
for i = 1:num_targets
    % 获取当前目标的类型（统一转小写并去除空格，防止格式不匹配）
    current_type = strtrim(lower(gt.Targets_Type{i}));
    
    % 如果是我们要找的目标类型
    if strcmp(current_type, target_color)
        % 获取目标的中心行列坐标
        r = gt.Targets_rowIndices(i);
        c = gt.Targets_colIndices(i);
        
        % 按照 FUMI 论文设定：以目标为中心，划定 5x5 的矩形区域作为正包
        % 使用 max 和 min 防止坐标越界跑到图像外面去
        r_range = max(1, r-2) : min(rows, r+2);
        c_range = max(1, c-2) : min(cols, c+2);
        
        % 遍历这个 5x5 窗口内的所有像素，将它们的二维坐标转换为一维线性索引
        for rr = r_range
            for cc = c_range
                % MATLAB 的线性索引计算公式：(列数-1)*总行数 + 行数
                linear_idx = (cc - 1) * rows + rr;
                pos_indices = [pos_indices, linear_idx];
            end
        end
    end
end

% 去除可能重复的索引（以防两个目标靠得太近，5x5 窗口重叠）
pos_indices = unique(pos_indices);

%% 5. 提取 positive 和 negative 矩阵
disp('正在提取 positive 和 negative 矩阵...');

% 正包矩阵：直接根据索引抠出来
positive = hsi_2d(:, pos_indices);

% 负包索引：所有不在正包里的像素都是负包
all_indices = 1:total_pixels;
neg_indices = setdiff(all_indices, pos_indices);

% 【降采样负包】：真实的负包有将近 10 万个像素，直接跑 VCA 会非常慢。
% 我们随机抽取 10000 个背景像素作为代表，这对构建背景子空间已经完全足够了！
num_bg_samples = 1000000;
% 如果负包总数大于我们需要采样的数量，则随机打乱抽取
if length(neg_indices) > num_bg_samples
    rand_idx = randperm(length(neg_indices), num_bg_samples);
    sampled_neg_indices = neg_indices(rand_idx);
else
    sampled_neg_indices = neg_indices;
end

negative = hsi_2d(:, sampled_neg_indices);

%% 6. 匹配对应的真实端元 (Ground Truth Spectrum)
disp('正在匹配真实端元...');
% 注意：tgt_img_spectra.mat 里具体叫什么名字，你需要根据实际情况修改
% 假设里面有 tgt_brown, tgt_dark_green 等变量
if strcmp(target_color, 'brown')
    E_t = tgt_img_spectra.spectra(:, 1); 
elseif strcmp(target_color, 'dark green')
    E_t = tgt_img_spectra.spectra(:, 2);
elseif strcmp(target_color, 'faux vineyard green')
    E_t = tgt_img_spectra.spectra(:, 3);
elseif strcmp(target_color, 'pea green')
    E_t = tgt_img_spectra.spectra(:, 4);
else
    disp('未找到对应的官方光谱，E_t 设定为空。');
    E_t = [];
end

%% 7. 为了后面算 AUC，顺手生成一张 Ground Truth 标签向量
% 我们需要一张长达 109525 的 0-1 向量，方便后续的对比脚本
labels_bag = zeros(1, total_pixels);
labels_bag(pos_indices) = 1; % 把包含目标的正包区域全标为 1
% 还需要labels_bag
point_wise_pos_indices = [];
labels_point = zeros(1, total_pixels);
gt = hsi.groundTruth;
for i = 1:num_targets
    current_type = strtrim(lower(gt.Targets_Type{i}));

    if strcmp(current_type, target_color)
        % 获取目标的中心行列坐标
        r = gt.Targets_rowIndices(i);
        c = gt.Targets_colIndices(i);

        % 按照 FUMI 论文设定：以目标为中心，划定 5x5 的矩形区域作为正包
        % 使用 max 和 min 防止坐标越界跑到图像外面去
        switch gt.Targets_Size(i)
            case 0.5
                r_range = max(1, r) : min(rows, r);
                c_range = max(1, c) : min(cols, c);

            case 1
                r_range = max(1, r) : min(rows, r);
                c_range = max(1, c) : min(cols, c);

            case 3
                r_range = max(1, r-1) : min(rows, r+1);
                c_range = max(1, c-1) : min(cols, c+1);

            case 6
                r_range = max(1, r-2) : min(rows, r+2);
                c_range = max(1, c-2) : min(cols, c+2);

        end
        for rr = r_range
            for cc = c_range
                % MATLAB 的线性索引计算公式：(列数-1)*总行数 + 行数
                linear_idx = (cc - 1) * rows + rr;
                point_wise_pos_indices = [point_wise_pos_indices, linear_idx];
            end
        end
    end
end
labels_point(point_wise_pos_indices) = 1;

% =========================================================
% 【核心修正】：裁剪标签，使其与 positive 和 negative 矩阵严格一一对应！
% 把正包索引和我们抽样的10000个负包索引拼起来
eval_indices = [pos_indices, sampled_neg_indices];

% 从 109525 的全图标签中，单独抽出这 10375 个参与运算的像素的标签
labels_point = labels_point(eval_indices);
labels_bag = labels_bag(eval_indices);
% =========================================================
%% 8. 保存文件！
disp('正在保存数据...');
save('positive_gulfport_pea_green.mat', 'positive');
save('negative_gulfport_pea_green.mat', 'negative');
save('E_t_gulfport_pea_green.mat', 'E_t');
save('ground_truth_gulfport_pea_green.mat', 'labels_point', "labels_bag");

disp('==================================================');
disp(['✅ 成功提取 ', num2str(length(pos_indices)), ' 个正包像素']);
disp(['✅ 成功抽取 ', num2str(length(sampled_neg_indices)), ' 个负包像素']);
disp('现在可以去跑 MIVCA 主程序了！记得修改主程序里的 tiqv 为 7~15。');
disp('==================================================');