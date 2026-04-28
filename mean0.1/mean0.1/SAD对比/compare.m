% =========================================================================
% 多示例学习端元提取算法统一对比评估脚本 (SAD 计算与可视化)
% =========================================================================
clc; clear all; close all;

%% 1. 安全加载真实端元 (Ground Truth)
disp('正在加载真实端元 (Ground Truth) ...');
try
    temp_gt = load('E_tjh.mat');
    E_true = temp_gt.E_t; % 提取出真正的变量名 E_t
    load("wavelength.mat");

catch
    error('未找到真实端元文件 ../E_tjh.mat，请检查路径！');
end

%% 2. 动态加载各算法的提取结果
% 初始化存储容器
methods = {};      % 存储算法名称
endmembers = [];   % 存储提取出的端元矩阵 (按列排布)
sads = [];         % 存储计算出的 SAD 值

% -- (1) 加载你的算法 MIVCA --
try
    temp_mivca = load('end04.mat');
    E_mivca = temp_mivca.E_vca;
    methods{end+1} = 'MIVCA (Ours)';
    endmembers = [endmembers, E_mivca];
    disp(' -> 成功加载 MIVCA 结果');
catch
    disp(' -> [跳过] 未找到 MIVCA 的结果文件 end04.mat');
end

% -- (2) 加载 MIHE 算法 --
try
    % temp_mihe = load('end_mihe.mat');
    temp_mihe = load('/Users/jihao/毕设相关/mean0.1/mean0.1/end_mihe.mat');
    E_mihe = temp_mihe.E_mihe;
    methods{end+1} = 'MI-HE';
    endmembers = [endmembers, E_mihe];
    disp(' -> 成功加载 MIHE 结果');
catch
    disp(' -> [跳过] 未找到 MIHE 的结果文件 end_mihe.mat');
end

% -- (3) 加载 eFUMI 算法 (假设你把它保存为 end_efumi.mat，变量名叫 E_efumi) --
% 如果你还没有保存，可以在 eFUMI 脚本最后加上： save('end_efumi.mat', 'E_efumi_target');
try
    temp_efumi = load('end_efumi.mat');
    % 注意：这里的变量名要换成你实际保存时的名字
    % 如果你保存的是整个矩阵，记得只取第一列，例如 temp_efumi.est_E_eFUMI(:,1)
    E_efumi = temp_efumi.E_efumi_target; 
    methods{end+1} = 'eFUMI';
    endmembers = [endmembers, E_efumi];
    disp(' -> 成功加载 eFUMI 结果');
catch
    disp(' -> [跳过] 未找到 eFUMI 的结果文件 end_efumi.mat');
end

% 可以继续在这里复制上面的 block，添加诸如 VCA 等其他对比算法...


%% 3. 计算 SAD (光谱角距离) 并输出表格
disp(' ');
disp('==================================================');
disp('   算法名称          SAD 误差 (度)');
disp('--------------------------------------------------');

for i = 1:length(methods)
    E_est = endmembers(:, i);
    % SAD 核心计算公式 (单位：度)
    sad_val = acos(dot(E_est, E_true) / (norm(E_est) * norm(E_true))) * 180 / pi;
    sads = [sads, sad_val];
    
    % 格式化打印到控制台
    fprintf('   %-15s |  %.4f°\n', methods{i}, sad_val);
end
disp('==================================================');

%% 4. 绘制终极对比图 (自带 Min-Max 归一化)
if isempty(methods)
    disp('没有成功加载任何算法结果，不进行绘图。');
    return;
end

figure('Name', 'Endmember Comparison', 'Position', [100, 100, 800, 500]);

% 先画真实端元 (加粗黑色实线，作为基准)
E_true_norm = (E_true - min(E_true)) / (max(E_true) - min(E_true));
plot(wavelength, E_true_norm, 'k-', 'LineWidth', 2.5);
hold on;

% 定义一组好看且好区分的线条样式和颜色
line_styles = {'r--', 'b-.', 'g:', 'm--', 'c-.'};

% 循环画出各个算法的端元
for i = 1:length(methods)
    E_est = endmembers(:, i);
    % 归一化，剥离尺度差异，只对比形状
    E_est_norm = (E_est - min(E_est)) / (max(E_est) - min(E_est));
    % E_est_norm = E_est;
    
    % 选取颜色和线型
    style = line_styles{mod(i-1, length(line_styles)) + 1};
    plot(wavelength, E_est_norm, style, 'LineWidth', 2);
end

% 图表美化设置
legend_labels = ['Ground Truth', methods];
legend(legend_labels, 'Location', 'northeast', 'FontSize', 11);
title('各算法提取目标端元结果对比', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('波段 (Bands)', 'FontSize', 12);
ylabel('归一化反射率 (Normalized Reflectance)', 'FontSize', 12);
set(gca, 'FontSize', 11); % 设置坐标轴字体大小
grid on;