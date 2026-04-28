% =========================================================================
% 在 Gulfport 真实数据集上运行 MIHE 算法
% =========================================================================
clc; clear all; close all;
rng(42);

%% 1. 添加 MIHE 代码路径
% 注意：请根据你的实际文件夹结构微调路径
addpath('../../MIHE-master/MIHE_Code'); 

%% 2. 加载刚刚生成的 MIHE 专属 Cell 数据
disp('正在加载数据...');
load('/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/mihe_data_gulfport.mat'); % 里面包含 pos_bags, neg_bags, E_t

%% 3. 加载并修改 MIHE 的参数
MIHE_para = MIHE_parameters();
MIHE_para.T = 1;  % 提取 1 个目标端元

% 【关键调整】：为了和 eFUMI 以及 MIVCA 保持公平，大幅提高背景端元数
% 真实场景背景极其复杂，M 设为 15 左右比较合适
MIHE_para.M = 9; 

%% 4. 运行 MIHE 核心算法
disp('==================================================');
disp('正在运行 MIHE 算法...');
disp('注意：该算法包含复杂的稀疏编码，在 72 波段真实数据上较慢，请耐心等待');
start_time = tic;

% MIHE 接收 Cell 数组格式的包数据
[D, D_initial, obj_func, obj_pos, obj_neg, obj_discrim] = MI_HE(pos_bags, neg_bags, MIHE_para);

elapsed = toc(start_time);
fprintf("MIHE 运行耗时: %.2f 秒\n", elapsed);
disp('==================================================');

%% 5. 提取结果与计算误差
E_mihe = D(:, 1:MIHE_para.T); % 第 1 列是目标端元

% 计算 SAD (光谱角距离)
sad_mihe = acos(dot(E_mihe, E_t) / (norm(E_mihe) * norm(E_t))) * 180 / pi;

disp(['MIHE 提取的目标端元 SAD 误差为: ', num2str(sad_mihe), ' 度']);

% 保存结果，供后续 ROC 画图大比拼使用
save('end_mihe_gulfport.mat', 'E_mihe');

%% 6. 可视化对比
E_mihe_plot = (E_mihe - min(E_mihe)) / (max(E_mihe) - min(E_mihe));
E_t_plot = (E_t - min(E_t)) / (max(E_t) - min(E_t));

figure('Name', 'MIHE on Gulfport');
[bands, ~] = size(E_t);
plot(1:bands, E_t_plot, 'r-', 'LineWidth', 2); hold on;
plot(1:bands, E_mihe_plot, 'b--', 'LineWidth', 2);
legend('真实端元 (Ground Truth)', sprintf('MIHE 提取端元 (SAD: %.1f°)', sad_mihe));
title('MIHE 真实场景提取结果对比');
xlabel('波段 (Bands)');
ylabel('归一化反射率 (Normalized Reflectance)');
grid on;