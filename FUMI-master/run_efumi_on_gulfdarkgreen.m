% =========================================================================
% 在我们生成的模拟数据上运行 eFUMI 算法，并与 MIVCA 结果进行对比
% =========================================================================
clc; clear all; close all;
rng(69);

%% 1. 添加算法路径 (确保 MATLAB 能找到 eFUMI 的函数)
addpath('eFUMI_code');
addpath('cFUMI_code'); % eFUMI 内部调用了部分 cFUMI 的共有基础函数 (如归一化)

%% 2. 加载数据
disp('正在加载数据集...');
% 加载正负包数据
load('/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/positive_gulfport_darkgreen.mat');
load('/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/negative_gulfport_darkgreen.mat');
% 加载标签 (里面有 labels_bag 和 labels_point)
load('/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/ground_truth_gulfport_darkgreen.mat'); 
% 加载真实的红板岩端元 (注意你的文件名是 E_tjh)
load('/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/E_t_gulfport_darkgreen.mat'); 

%% 3. 数据预处理与拼装
disp('正在拼装 eFUMI 所需的矩阵 X...');
% eFUMI 需要所有数据拼成一个大矩阵 X = [特征维度 x 总像素数]
X = [positive, negative]; 

%% 4. 配置 eFUMI 算法参数
disp('配置 eFUMI 参数...');
parameters_eFUMI = eFUMI_parameters(); % 调用官方默认参数生成器
% 根据 Demo 里的设定，稍作微调以适应我们的数据 (参考 demo_FUMI_random_data_repeat_Fig_2.m)
parameters_eFUMI.u = 0.05;
parameters_eFUMI.M = 7;         % 端元总数：1个目标 + 3个背景 = 4
parameters_eFUMI.gammaconst = 5;
parameters_eFUMI.beta = 60;

%% 5. 运行 eFUMI 算法
start_time = tic;

disp('正在运行 eFUMI 算法 (迭代优化中，可能需要几分钟，请耐心等待)...');
% 注意：这里传入的是 labels_bag，保证是完全的弱监督多示例学习环境
[est_E_eFUMI, est_P_eFUMI] = eFUMI(X, labels_bag, parameters_eFUMI);

elapsed = toc(start_time);
fprintf("运行时间: %.2f 秒\n", elapsed)

% 官方归一化操作：将提取出来的端元缩放到 [0, 1] 范围内
% est_E_eFUMI = normalize(est_E_eFUMI, 1);
est_E_eFUMI = est_E_eFUMI;

%% 6. 提取目标端元并计算 SAD
% eFUMI 提取出的字典矩阵 est_E_eFUMI 中，第 1 列固定为目标端元
E_efumi_target = est_E_eFUMI(:, 1);

% 计算与真实端元 (E_tjh) 的光谱角距离 (SAD)
sad_efumi = acos(dot(E_efumi_target, E_t) / (norm(E_efumi_target) * norm(E_t))) * 180 / pi;

disp('--------------------------------------------------');
disp(['eFUMI 提取的目标端元与真实端元的 SAD 误差为: ', num2str(sad_efumi), ' 度']);
disp('--------------------------------------------------');

save('end_efumi_gulfport_darkgreen.mat', "E_efumi_target")

%% 7. 加载你的 MIVCA 结果做终极对比 (假设你之前存了 end04.mat)
try
    load('/Users/jihao/毕设相关/mean0.1/mean0.1/end04_gulfport_dark_green.mat'); % 加载你的 E_vca on gulfport dark green
    
    % 也对你的结果和真实标签做一次归一化，保证画图在一个尺度上
    % E_t_plot = (E_t - min(E_t)) / (max(E_t) - min(E_t));
    % E_vca_plot = (E_vca - min(E_vca)) / (max(E_vca) - min(E_vca));
    % E_efumi_plot = (E_efumi_target - min(E_efumi_target)) / (max(E_efumi_target) - min(E_efumi_target));
    E_t_plot = E_t;
    E_vca_plot = E_vca;
    E_efumi_plot = E_efumi_target;

    
    sad_mivca = acos(dot(E_vca, E_t) / (norm(E_vca) * norm(E_t))) * 180 / pi;
    disp(['你的 MI-VCA 误差为: ', num2str(sad_mivca), ' 度']);
    
    % === 画图大比拼 ===
    figure('Name', 'MIVCA vs eFUMI');
    plot(1:72, E_t_plot, 'r-', 'LineWidth', 2); hold on;
    plot(1:72, E_efumi_plot, 'g--', 'LineWidth', 2);
    plot(1:72, E_vca_plot, 'b-.', 'LineWidth', 2);
    
    title('多示例学习端元提取结果对比 (eFUMI vs MIVCA)');
    xlabel('波段 (Bands)');
    ylabel('归一化反射率 (Normalized Reflectance)');
    legend('真实标签 (Ground Truth)', 'eFUMI (顶级基线)', 'MI-VCA (你的算法)', 'FontSize', 12);
    grid on;
    
catch
    disp('未找到 end04.mat，仅绘制 eFUMI 和 真实标签 的对比图。');
    % 只有 eFUMI 的画图逻辑...
end