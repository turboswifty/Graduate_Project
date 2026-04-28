% =========================================================================
% MI-VCA 模拟高光谱数据集生成脚本 (严格基于论文 Table 1, 公式 5, 6)
% =========================================================================
clc; clear all; close all;

disp('=== 开始生成高光谱模拟数据集 ===');

%% 1. 加载或生成端元 (Endmembers)
% 尝试加载真实的红板岩目标端元 E_t
try
    load('../E_t.mat'); 
    disp('成功加载真实目标端元 E_t');
catch
    disp('未找到 E_t.mat，将自动生成一个模拟的红板岩目标端元...');
    E_t = 0.5 + 0.3 * sin(linspace(0, 3*pi, 211))'; % 模拟一个 211 维的曲线
end

% 模拟生成 3 个不同的背景端元 (对应 Verde Antique, Phyllite, Pyroxenite)
% (因为缺失原始ASTER库，这里用平滑曲线模拟，保证它们与目标正交度足够)
L = length(E_t); % 波段数，应为 211
D_bg = zeros(L, 3);
D_bg(:,1) = 0.4 + 0.2 * cos(linspace(0, 4*pi, L))';
D_bg(:,2) = 0.3 + 0.1 * sin(linspace(0, 5*pi, L))' + 0.1 * cos(linspace(0, 2*pi, L))';
D_bg(:,3) = 0.6 - 0.2 * exp(-linspace(0, 5, L))';
D_bg = max(0, min(1, D_bg)); % 保证背景反射率值在合理范围 [0, 1]

%% 2. 实验参数设置 (严格对应论文 Table 1)
num_pos_bags = 15;     % 正包数量
num_neg_bags = 5;      % 负包数量
pixels_per_bag = 500;  % 每个包的像素数
target_in_pos = 200;   % 正包中的目标像素数
bg_in_pos = 300;       % 正包中的纯背景像素数

alpha_mean = 0.1;      % 目标平均丰度 (论文设定的 10%)
k = 2;                 % 生成混合像元时，随机选取的背景端元数量
C = 2;                 % 狄利克雷分布的方差控制参数 (论文中的 alpha_Dir = 2)
snr_dB = 35;           % 信噪比 35dB

% 狄利克雷分布参数计算 (对应修改后的公式 6)
% Target-pixel 的 alpha (1个目标维度 + k个背景维度)
alpha_target_pixel = C * [alpha_mean, (1 - alpha_mean)/k, (1 - alpha_mean)/k]; 
% Background-pixel 的 alpha (纯 3 个背景混合，目标维度为 0，此处直接设为 3 个背景平分)
alpha_bg_pixel = C * [1/3, 1/3, 1/3]; 

%% 3. 生成训练数据 (Positive 和 Negative 矩阵)
clean_positive = [];
clean_negative = [];

disp('正在生成正包数据 (Positive Bags) ...');
for i = 1:num_pos_bags
    % (a) 生成 200 个 Target-pixels
    % 随机从 3 个背景中选 k=2 个与目标进行混合
    bg_idx = randperm(3, k); 
    M_target = [E_t, D_bg(:, bg_idx)]; % 混合端元矩阵 [211波段 x 3种端元]
    
    % 利用 Gamma 分布生成满足“和为1”约束的 Dirichlet 丰度矩阵 [200 x 3]
    y = gamrnd(repmat(alpha_target_pixel, target_in_pos, 1), 1);
    a_target = y ./ sum(y, 2);
    target_pixels = M_target * a_target'; % 矩阵相乘得到像素光谱 [211 x 200]
    
    % (b) 生成 300 个 Background-pixels
    y = gamrnd(repmat(alpha_bg_pixel, bg_in_pos, 1), 1);
    a_bg = y ./ sum(y, 2);
    bg_pixels = D_bg * a_bg'; % [211 x 300]
    
    % 将当前正包的 500 个像素横向拼接至 positive 矩阵
    clean_positive = [clean_positive, target_pixels, bg_pixels];
end

disp('正在生成负包数据 (Negative Bags) ...');
for i = 1:num_neg_bags
    % 负包内 500 个像素全是 Background-pixels
    y = gamrnd(repmat(alpha_bg_pixel, pixels_per_bag, 1), 1);
    a_bg = y ./ sum(y, 2);
    bg_pixels = D_bg * a_bg'; % [211 x 500]
    
    clean_negative = [clean_negative, bg_pixels];
end

%% 4. 生成单独的测试数据 (供后续 ACE 计算 AUC 和画 ROC 曲线使用)
disp('正在生成测试集数据 (Test Data) ...');
clean_test_data = [];
test_labels = []; % 1 表示含目标的 Target-pixel, 0 表示纯背景
for i = 1:5 % 生成 5 个包大小的测试集
    % 200 个含目标的像素
    bg_idx = randperm(3, k); 
    M_target = [E_t, D_bg(:, bg_idx)];
    y = gamrnd(repmat(alpha_target_pixel, target_in_pos, 1), 1);
    a_target = y ./ sum(y, 2);
    t_pix = M_target * a_target';
    
    % 300 个纯背景像素
    y = gamrnd(repmat(alpha_bg_pixel, bg_in_pos, 1), 1);
    a_bg = y ./ sum(y, 2);
    b_pix = D_bg * a_bg';
    
    clean_test_data = [clean_test_data, t_pix, b_pix];
    % 记录真实标签：前200个是1，后300个是0
    test_labels = [test_labels, ones(1, target_in_pos), zeros(1, bg_in_pos)]; 
end

%% 5. 手写添加 35dB 高斯白噪声 (不依赖外部信号处理工具箱)
disp('正在添加 35dB 环境高斯白噪声 ...');
% 定义加噪匿名函数
add_noise = @(clean_sig, snr) clean_sig + ...
    sqrt( (sum(clean_sig(:).^2) / numel(clean_sig)) / (10^(snr / 10)) ) * randn(size(clean_sig));

positive = add_noise(clean_positive, snr_dB);
negative = add_noise(clean_negative, snr_dB);
test_data = add_noise(clean_test_data, snr_dB);

%% 6. 保存数据，无缝衔接主程序
disp('正在保存数据到 .mat 文件 ...');
save('positivejh.mat', 'positive');
save('negativejh.mat', 'negative');
save('test_data.mat', 'test_data', 'test_labels'); % 保存测试集和靶标

disp('=== 数据集生成完毕！你可以直接运行你的主程序了 ===');