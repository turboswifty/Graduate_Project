% =========================================================================
% 多示例端元提取算法统一评估脚本：基于 ACE 的 ROC 曲线与 AUC 对比
% =========================================================================
clc; clear all; close all;

%% 1. 加载测试数据与背景数据
disp('正在加载数据 (positive, negative, ground_truth) ...');
try
    % 加载你在 FUMI 生成脚本中保存的数据
    % 如果你保存的文件名带 'jh'，请自行修改为 positivejh.mat 等
    load('positivejh.mat'); 
    load('negativejh.mat'); 
    
    % 加载标签 (里面必须有 labels_point 这个像素级 Ground Truth 变量)
    try
        load('ground_truthjh.mat'); 
    catch
        load('ground_truth.mat'); % 兼容没有 jh 的命名
    end
    
    % 拼装测试集大矩阵: [15个正包的像素, 5个负包的像素]
    test_data = [positive, negative]; 
    
    % 确保 labels_point 是一维行向量，且长度与 test_data 列数一致
    if iscolumn(labels_point)
        labels_point = labels_point';
    end
catch
    error('加载数据失败！请确保当前目录下有 positive/negative/ground_truth 数据。');
end

%% 2. 估计 ACE 所需的背景统计量 (根据论文: estimated from negative instance)
disp('正在从负包 (Negative Bags) 中估计背景协方差矩阵 ...');
mu_bg = mean(negative, 2); % 计算背景均值 [211 x 1]
neg_centered = negative - repmat(mu_bg, 1, size(negative, 2));
Cov_bg = (neg_centered * neg_centered') / size(negative, 2); % 协方差矩阵
Inv_Cov = pinv(Cov_bg); % 使用伪逆防止奇异矩阵报错

%% 3. 动态加载各算法的端元结果
% 初始化存储容器
methods = {};      
endmembers = [];   

% -- 加载真实端元 (Ground Truth) --
try
    temp_gt = load('E_tjh.mat');
    methods{end+1} = 'Ground Truth (E_t)';
    endmembers = [endmembers, temp_gt.E_t];
catch
    disp(' -> [跳过] 未找到真实端元 ../E_tjh.mat');
end

% -- 加载 MIVCA --
try
    temp_mivca = load('end04.mat');
    methods{end+1} = 'MIVCA (Ours)';
    endmembers = [endmembers, temp_mivca.E_vca];
catch
    disp(' -> [跳过] 未找到 MIVCA 的结果 end04.mat');
end

% -- 加载 MIHE --
try
    temp_mihe = load('end_mihe.mat');
    methods{end+1} = 'MI-HE';
    endmembers = [endmembers, temp_mihe.E_mihe];
catch
    disp(' -> [跳过] 未找到 MIHE 的结果 end_mihe.mat');
end

% -- 加载 eFUMI --
try
    temp_efumi = load('end_efumi.mat');
    methods{end+1} = 'eFUMI';
    endmembers = [endmembers, temp_efumi.E_efumi_target];
catch
    disp(' -> [跳过] 未找到 eFUMI 的结果 end_efumi.mat');
end

if isempty(methods)
    error('没有找到任何端元结果，无法进行 ACE 检测！');
end

%% 4. 执行 ACE 检测并计算 ROC / AUC
disp(' ');
disp('==================================================');
disp('   算法名称          检测 AUC 值');
disp('--------------------------------------------------');

% 准备画图
figure('Name', 'ROC Curves Comparison', 'Position', [150, 150, 800, 600]);
hold on;
line_styles = {'k-', 'r-', 'b-', 'g-', 'm-', 'c-'}; % 线条样式 (真实端元固定黑色)
line_widths = [2.5, 3, 2, 2, 2, 2]; % 真实端元画粗一点
legend_text = {};

% 中心化测试数据 (为了提速，放在循环外面算一次即可)
test_centered = test_data - repmat(mu_bg, 1, size(test_data, 2));
% ACE 分母的一部分 (测试数据项)
den2 = sum(test_centered .* (Inv_Cov * test_centered), 1); 

for i = 1:length(methods)
    E_est = endmembers(:, i);
    
    % --- 计算 ACE 分数 ---
    s_centered = E_est - mu_bg;
    weight_vector = s_centered' * Inv_Cov; 
    
    % 分子: (s^T * Cov^-1 * x)^2
    numerator = (weight_vector * test_centered).^2;
    % 分母: (s^T * Cov^-1 * s) * (x^T * Cov^-1 * x)
    den1 = weight_vector * s_centered; 
    
    ace_scores = numerator ./ (den1 * den2); % 最终的 ACE 响应值向量
    
    % --- 使用 perfcurve 计算 FPR, TPR 和 AUC ---
    % 第三个参数 1 表示我们把 labels_point 里的 1 视为正类目标
    [FPR, TPR, ~, AUC] = perfcurve(labels_point, ace_scores, 1);
    
    % 打印到控制台
    fprintf('   %-15s |  %.4f\n', methods{i}, AUC);
    
    % --- 画 ROC 曲线 ---
    plot(FPR, TPR, line_styles{i}, 'LineWidth', line_widths(i));
    
    % 拼接图例文字 (附带 AUC)
    legend_text{i} = sprintf('%s (AUC=%.4f)', methods{i}, AUC);
end
disp('==================================================');

%% 5. 完善图表设置
% 画一条随机瞎猜的参考线 (对角线)
plot([0, 1], [0, 1], 'k--', 'LineWidth', 1);
legend_text{end+1} = 'Random Guess (AUC=0.5000)';

title('各多示例算法端元提取后的 ACE 目标检测 ROC 曲线', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('假阳性率 / False Positive Rate (FPR)', 'FontSize', 12);
ylabel('真阳性率 / True Positive Rate (TPR)', 'FontSize', 12);
legend(legend_text, 'Location', 'SouthEast', 'FontSize', 11);
grid on;
set(gca, 'FontSize', 11);