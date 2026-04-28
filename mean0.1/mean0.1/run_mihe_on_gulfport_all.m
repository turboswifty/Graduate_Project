% =========================================================================
% 在 Gulfport 真实数据集上对全部四个类别运行 MIHE 算法
% 仿照 run_mihe_on_gulfport.m，不覆盖原文件
% =========================================================================
clc; clear all; close all;
rng(42);

%% 1. 添加 MIHE 代码路径
addpath('../../MIHE-master/MIHE_Code');

%% 2. 加载并修改 MIHE 参数（四个类别共用）
MIHE_para = MIHE_parameters();
MIHE_para.T = 1;
MIHE_para.M = 9;
MIHE_para.rho = 0.3;
MIHE_para.beta = 1;
MIHE_para.lambda = 5e-3;

%% 3. 定义四个类别及其数据文件
data_dir = '/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/';
target_colors = {'brown', 'dark_green', 'faux_vineyard_green', 'pea_green'};
data_files = {
    'mihe_data_gulfport_brown.mat',
    'mihe_data_gulfport_dark_green.mat',
    'mihe_data_gulfport_faux_vineyard_green.mat',
    'mihe_data_gulfport_pea_green.mat'
};
out_files = {
    'end_mihe_gulfport_brown.mat',
    'end_mihe_gulfport_dark_green.mat',
    'end_mihe_gulfport_faux_vineyard_green.mat',
    'end_mihe_gulfport_pea_green.mat'
};

% 存放结果的容器
E_mihe_all = cell(1, 4);
E_t_all = cell(1, 4);
sad_all = zeros(1, 4);

%% 4. 逐类别运行 MIHE
for idx = 1:length(target_colors)
    target_color = target_colors{idx};
    fprintf('\n==================================================\n');
    fprintf('========== 正在处理: %s ==========\n', target_color);
    fprintf('==================================================\n');

    % --- 4a. 加载数据 ---
    data_path = fullfile(data_dir, data_files{idx});
    fprintf('加载数据: %s\n', data_path);
    load(data_path);  % 包含 pos_bags, neg_bags, E_t

    % --- 4b. 运行 MIHE ---
    disp('运行 MIHE 算法...');
    start_time = tic;

    [D, D_initial, obj_func, obj_pos, obj_neg, obj_discrim] = ...
        MI_HE(pos_bags, neg_bags, MIHE_para);

    elapsed = toc(start_time);
    fprintf('MIHE 运行耗时: %.2f 秒\n', elapsed);

    % --- 4c. 提取目标端元并计算 SAD ---
    E_mihe = D(:, 1:MIHE_para.T);
    sad_mihe = acos(dot(E_mihe, E_t) / (norm(E_mihe) * norm(E_t))) * 180 / pi;
    fprintf('SAD 误差: %.4f 度\n', sad_mihe);

    % --- 4d. 保存 ---
    save(out_files{idx}, 'E_mihe');
    fprintf('已保存至: %s\n', out_files{idx});

    % --- 存储汇总 ---
    E_mihe_all{idx} = E_mihe;
    E_t_all{idx} = E_t;
    sad_all(idx) = sad_mihe;
end

%% 5. 保存汇总结果
save('end_mihe_gulfport_all.mat', 'E_mihe_all', 'E_t_all', 'sad_all', 'target_colors');
disp('==================================================');
disp('汇总结果已保存至: end_mihe_gulfport_all.mat');

%% 6. 汇总表格
fprintf('\n========== SAD 汇总 ==========\n');
for idx = 1:4
    fprintf('  %-25s  SAD = %.4f°\n', target_colors{idx}, sad_all(idx));
end

%% 7. 可视化：四子图对比
figure('Name', 'MIHE on Gulfport - All Four Classes');

for idx = 1:4
    subplot(2, 2, idx);

    E_t = E_t_all{idx};
    E_mihe = E_mihe_all{idx};

    % 归一化到 [0,1] 便于可视化
    E_mihe_plot = (E_mihe - min(E_mihe)) / (max(E_mihe) - min(E_mihe));
    E_t_plot = (E_t - min(E_t)) / (max(E_t) - min(E_t));

    [bands, ~] = size(E_t);
    plot(1:bands, E_t_plot, 'r-', 'LineWidth', 1.5); hold on;
    plot(1:bands, E_mihe_plot, 'b--', 'LineWidth', 1.5);
    legend('GT', sprintf('MIHE (SAD: %.1f°)', sad_all(idx)), 'Location', 'best');
    title(sprintf('MIHE - %s', strrep(target_colors{idx}, '_', ' ')));
    xlabel('波段 (Bands)');
    ylabel('归一化反射率');
    grid on;
end

sgtitle('MIHE 在 Gulfport 四个类别上的端元提取结果');
