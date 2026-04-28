% =========================================================================
% 精美版算法性能对比图：MIVCA vs Mihe vs Efumi
% 优化重点：配色、布局、无框设计、字体美化
% =========================================================================
clc; clear; close all;

%% 1. 数据准备
methods = {'MIVCA', 'Mihe', 'Efumi'};
sad_values = [0.0405, 19.3329, 0.0582];
time_values = [1.4161, 861.50, 7.84];

% 转换为 Categorical 以固定顺序
cat_methods = categorical(methods);
cat_methods = reordercats(cat_methods, methods);

%% 2. 颜色定义 (采用现代学术色系)
color_main = [0.1216, 0.4667, 0.7059]; % 经典深蓝
color_sec  = [0.8510, 0.3255, 0.0980]; % 砖红/橙
bg_color   = [0.98, 0.98, 0.98];       % 极淡灰色背景

%% 3. 创建图形
fig = figure('Color', 'w', 'Position', [100, 100, 1000, 450]);

% --- 左侧：SAD 精度对比 ---
ax1 = subplot(1, 2, 1);
hold on;
b1 = bar(cat_methods, sad_values, 0.6, 'FaceColor', color_main, ...
    'EdgeColor', 'none', 'FaceAlpha', 0.85);

% 设置对数坐标并优化刻度
set(gca, 'YScale', 'log', 'YGrid', 'on', 'GridLineStyle', ':', 'GridColor', 'k', 'GridAlpha', 0.15);
ylabel('SAD (Radians)', 'FontSize', 12, 'FontName', 'Segoe UI');
title('Spectral Reconstruction Accuracy', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0.2 0.2 0.2]);

% 增加数值标签 (带背景的小气泡感)
for i = 1:length(sad_values)
    text(i, sad_values(i)*1.2, sprintf('%.4f', sad_values(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', ...
        'Color', color_main);
end
set(gca, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');

% --- 右侧：运行时间对比 ---
ax2 = subplot(1, 2, 2);
hold on;
b2 = bar(cat_methods, time_values, 0.6, 'FaceColor', color_sec, ...
    'EdgeColor', 'none', 'FaceAlpha', 0.85);

set(gca, 'YScale', 'log', 'YGrid', 'on', 'GridLineStyle', ':', 'GridColor', 'k', 'GridAlpha', 0.15);
ylabel('Execution Time (Seconds)', 'FontSize', 12, 'FontName', 'Segoe UI');
title('Computational Efficiency', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0.2 0.2 0.2]);

% 增加数值标签
for i = 1:length(time_values)
    val_str = ifelse(time_values(i) > 10, sprintf('%.1f', time_values(i)), sprintf('%.2f', time_values(i)));
    text(i, time_values(i)*1.2, val_str, ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', ...
        'Color', color_sec);
end
set(gca, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');

%% 4. 整体美化与细节微调
% 统一 Y 轴范围余量，避免标签被切掉
axes(ax1); yl1 = ylim; ylim([yl1(1), yl1(2)*5]);
axes(ax2); yl2 = ylim; ylim([yl2(1), yl2(2)*5]);

% 加上总标题
%
%sgtitle('Performance Benchmark: MIVCA Algorithm Evaluation', ...
%    'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Segoe UI');

% 导出预览 (可选)
% exportgraphics(fig, 'Refined_Comparison.pdf', 'ContentType', 'vector');

function s = ifelse(cond, s1, s2)
    if cond, s = s1; else, s = s2; end
end