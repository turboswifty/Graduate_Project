% =========================================================================
% MIHE 端元 ACE 检测 ROC 计算与导出脚本
% 只计算并保存 MIHE 预测端元的 ROC 数据，方便他人复用绘图
% =========================================================================
clc; clear all; close all;

%% 1. 加载数据
disp('正在加载数据 ...');
try
    load('positivejh.mat');
    load('negativejh.mat');
    try
        load('ground_truthjh.mat');
    catch
        load('ground_truth.mat');
    end

    % 加载 MIHE 端元结果
    % temp_mihe = load('end_mihe.mat');
    temp_mihe = load('/Users/jihao/毕设相关/mean0.1/mean0.1/end_mihe.mat');
    E_mihe = temp_mihe.E_mihe;

    % 拼装测试集
    test_data = [positive, negative];

    if iscolumn(labels_point)
        labels_point = labels_point';
    end
catch ME
    error('加载数据失败: %s', ME.message);
end

%% 2. 从负包估计背景统计量
disp('估计背景统计量 ...');
mu_bg = mean(negative, 2);
neg_centered = negative - repmat(mu_bg, 1, size(negative, 2));
Cov_bg = (neg_centered * neg_centered') / size(negative, 2);
Inv_Cov = pinv(Cov_bg);

%% 3. 计算 ACE 检测分数
disp('计算 ACE 检测分数 ...');
test_centered = test_data - repmat(mu_bg, 1, size(test_data, 2));

% 分母公共部分: x' * Sigma^-1 * x
den2 = sum(test_centered .* (Inv_Cov * test_centered), 1);

% 目标端元去均值
s_centered = E_mihe - mu_bg;
weight_vector = s_centered' * Inv_Cov;

% ACE 分数
numerator = (weight_vector * test_centered).^2;
den1 = weight_vector * s_centered;
ace_scores = numerator ./ (den1 * den2);

%% 4. 计算 ROC 曲线与 AUC
disp('计算 ROC 与 AUC ...');
[FPR, TPR, ~, AUC] = perfcurve(labels_point, ace_scores, 1);

fprintf('MIHE 端元 ACE 检测 AUC = %.4f\n', AUC);

%% 5. 保存为 mat 文件，方便他人复用绘图
save('ROC_MIHE_ACE.mat', 'FPR', 'TPR', 'AUC', 'ace_scores', 'labels_point', 'E_mihe', 'mu_bg');
disp('已保存 ROC 数据到 ROC_MIHE_ACE.mat');
disp('  包含变量: FPR, TPR, AUC, ace_scores, labels_point, E_mihe, mu_bg');

%% 6. 画图（只画 MIHE）
figure('Name', 'MIHE ACE ROC', 'Position', [150, 150, 600, 500]);
plot(FPR, TPR, 'b-', 'LineWidth', 2.5); hold on;
plot([0, 1], [0, 1], 'k--', 'LineWidth', 1);

xlim([0 1]); ylim([0 1]);
xlabel('False Positive Rate (FPR)', 'FontSize', 12);
ylabel('True Positive Rate (TPR)', 'FontSize', 12);
title(sprintf('MIHE ACE Detection ROC (AUC = %.4f)', AUC), 'FontSize', 13, 'FontWeight', 'bold');
legend({'MIHE ACE', 'Random Guess'}, 'Location', 'SouthEast', 'FontSize', 11);
grid on;
set(gca, 'FontSize', 11);

disp('完成！');
