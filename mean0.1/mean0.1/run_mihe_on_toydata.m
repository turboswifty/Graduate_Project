clc; clear all; close all;
rng(69);

% 1. 添加 MIHE 算法的代码路径
addpath('../../MIHE-master/MIHE_Code'); 

% 2. 加载你现有的拼接好的矩阵数据以及真实端元
load('positivejh.mat'); % 加载出 positive 矩阵
load('negativejh.mat'); % 加载出 negative 矩阵

% 【安全加载真实端元】防止里面装的变量名不匹配
temp = load('../E_tjh.mat');   
% 假设里面装的原本是 E_t，强行提出来赋给 E_t_true
E_t_true = temp.E_t; 

% 3. 将拼接好的矩阵重新切分成 MIHE 需要的"包 (Bags)" 格式 (Cell数组)
num_pos_bags = 15;
num_neg_bags = 5;
[bands, N_pos] = size(positive);
[~, N_neg] = size(negative);

pixels_per_pos = floor(N_pos / num_pos_bags);
pixels_per_neg = floor(N_neg / num_neg_bags);

% --- 构建正包 (1x15 的 cell 数组) ---
pos_bags = cell(1, num_pos_bags);
for i = 1:num_pos_bags
    start_idx = (i-1)*pixels_per_pos + 1;
    if i == num_pos_bags
        end_idx = N_pos; % 最后一个包装入所有剩余的像素
    else
        end_idx = i*pixels_per_pos;
    end
    pos_bags{i} = positive(:, start_idx:end_idx);
end

% --- 构建负包 (1x5 的 cell 数组) ---
neg_bags = cell(1, num_neg_bags);
for i = 1:num_neg_bags
    start_idx = (i-1)*pixels_per_neg + 1;
    if i == num_neg_bags
        end_idx = N_neg;
    else
        end_idx = i*pixels_per_neg;
    end
    neg_bags{i} = negative(:, start_idx:end_idx);
end

% 4. 加载并修改 MIHE 的参数
MIHE_para = MIHE_parameters();
MIHE_para.T = 1; % 提取 1 个目标端元
MIHE_para.M = 9; % 对应 3 个背景端元
MIHE_para.rho = 0.8;
MIHE_para.b = 5;
MIHE_para.beta = 5;
MIHE_para.lambda = 1e-3;

% 5. 运行 MIHE 核心算法
disp('正在运行 MIHE 算法，该算法运用了复杂的稀疏编码和优化，可能需要几分钟，请稍候...');
[D, D_initial, obj_func, obj_pos, obj_neg, obj_discrim] = MI_HE(pos_bags, neg_bags, MIHE_para);

% 6. 提取结果
E_mihe = D(:, 1:MIHE_para.T); 

% 7. 评估结果（计算 SAD 角度误差）
jiaodu_mihe = acos(dot(E_mihe, E_t_true) / (norm(E_mihe) * norm(E_t_true))) * 180 / pi;
disp('--------------------------------------------------');
disp(['MIHE 提取的目标端元与真实标签的角度误差为: ', num2str(jiaodu_mihe), ' 度']);
disp('--------------------------------------------------');

% 8. 可视化对比 (【修改点】：对真实光谱和提取光谱都进行归一化)
E_mihe_plot = (E_mihe - min(E_mihe)) / (max(E_mihe) - min(E_mihe));
E_t_plot = (E_t_true - min(E_t_true)) / (max(E_t_true) - min(E_t_true));

figure('Name', 'Target Endmember Comparison');
plot(E_t_plot, 'r-', 'LineWidth', 2); hold on;
plot(E_mihe_plot, 'b--', 'LineWidth', 2);
legend('真实端元 (Ground Truth)', 'MIHE 提取端元');
title('目标端元提取结果对比 (归一化)');
xlabel('波段 (Bands)');
ylabel('归一化反射率 (Normalized Reflectance)');
grid on;

% 9. 保存MIHE跑出来的端元结果
save('end_mihe.mat', 'E_mihe');
disp('MIHE得到的端元已成功保存到当前目录下的 end_mihe.mat 中');