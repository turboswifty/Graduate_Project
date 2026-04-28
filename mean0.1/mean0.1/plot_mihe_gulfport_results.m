% =========================================================================
% 可视化 MIHE 在 Gulfport 四个类别上的端元提取结果（不做归一化）
% =========================================================================
clc; clear all; close all;

%% 1. 加载结果
load('end_mihe_gulfport_all.mat');  % 含 E_mihe_all, E_t_all, sad_all, target_colors

%% 2. 确定波段数
[bands, ~] = size(E_t_all{1});

%% 3. 四子图对比
figure('Name', 'MIHE on Gulfport - Endmember Comparison', 'Position', [100, 100, 1000, 700]);

for idx = 1:4
    subplot(2, 2, idx);

    E_t   = E_t_all{idx};
    E_mihe = E_mihe_all{idx};

    plot(1:bands, E_t,   'r-',  'LineWidth', 1.5); hold on;
    plot(1:bands, E_mihe, 'b--', 'LineWidth', 1.5);

    title_str = strrep(target_colors{idx}, '_', ' ');
    title_str(1) = upper(title_str(1));
    legend('Ground Truth', sprintf('MIHE (SAD: %.2f°)', sad_all(idx)), 'Location', 'best');
    title(title_str);
    xlabel('波段 (Band Index)');
    ylabel('反射率 (Reflectance)');
    grid on;
end

sgtitle('MIHE 端元提取结果 - Gulfport 四个类别');
