% =========================================================================
% MIVCA 端元 + ACE 目标检测 (Gulfport Campus 3) — 官方标准流程
% 使用官方 ace_detector (协方差矩阵) + Bullwinkle 评分 + auc_upto_far
% =========================================================================
clc; clear; close all;

%% 0. 路径设置 — 添加官方工具箱
% =========================================================================
base_dir = 'E:\MUUFL gulfport\MUUFLGulfport-master\MUUFLGulfport-master\MUUFLGulfportDataCollection';
addpath(fullfile(base_dir, 'util'));
addpath(fullfile(base_dir, 'Bullwinkle'));
addpath(fullfile(base_dir, 'signature_detectors'));

%% 1. 加载数据
% =========================================================================
disp('正在加载数据...');

% 加载高光谱数据 (官方 .mat 格式，包含 hsi 结构体)
load(fullfile(base_dir, 'muufl_gulfport_campus_3.mat'));

% 加载 MIVCA 估计端元 (brown)
load('end04_gulfport1_mivca.mat');  % 变量名 E_vca

% 加载真实端元 (用于 SAD 比较，可选)
load('E_t_gulfport3.mat');  % 变量名 E_t

%% 2. 端元光谱比较 (SAD)
% =========================================================================
E_t   = double(E_t(:));
E_vca = double(E_vca(:));

sad_angle = acos(dot(E_vca, E_t) / (norm(E_vca) * norm(E_t))) * 180 / pi;
disp(['MIVCA 端元 SAD 误差: ', num2str(sad_angle, '%.4f'), ' 度']);

%% 3. 准备目标端元
% =========================================================================
% 使用 MIVCA 提取的端元作为 ACE 的目标签名
tgt_sig = E_vca;

%% 4. 运行官方 ACE 检测器
% =========================================================================
disp('正在运行 ACE 检测器 (协方差矩阵版本)...');
hsi_img    = double(hsi.Data);
valid_mask = hsi.valid_mask;

% 调用官方 ace_detector: 内部用 cov + 减均值
ace_out = ace_detector(hsi_img, tgt_sig, valid_mask);

%% 5. Bullwinkle 评分
% =========================================================================
disp('正在进行 Bullwinkle 评分...');

% 定义目标过滤器 — 仅对 brown 目标评分
filt_brown = { {'brown', [], [], []} };

% 也可选：所有常规目标
% filt_all = { {{'brown','pea green','dark green','faux vineyard green'}, [], [], []} };

% 运行评分 (内部自动从 hsi.groundTruth 构建正负样本)
bw_score = score_hylid_perpixel(hsi, ace_out, filt_brown, 'ACE (MIVCA-brown)', ...
    'det_fig', 10, 'roc_fig', 11);

%% 6. 计算 AUC
% =========================================================================
FAR_LIMIT = 1e-3;  % FAR 上限 (FA/m^2)，可按需调整
auc_val = auc_upto_far(FAR_LIMIT, bw_score);
disp(['ACE AUC (FAR <= ', num2str(FAR_LIMIT), '): ', num2str(auc_val, '%.4f')]);

%% 7. ROC 曲线绘制
% =========================================================================
figure('Name', 'ROC Curve (Bullwinkle)', 'Position', [300 300 600 500]);
PlotBullwinkleRoc(bw_score, 'ACE (MIVCA-brown)', 'xlim', [-1e-5 FAR_LIMIT]);

%% 8. 保存结果
% =========================================================================
result.bw_score  = bw_score;
result.auc       = auc_val;
result.far_limit = FAR_LIMIT;
result.sad       = sad_angle;
result.ace_map   = ace_out;

save('E:\迅雷下载\gulfport3_ace_auc_result.mat', 'result');
disp('结果已保存至 gulfport3_ace_auc_result.mat');
disp('==================================================');
disp('实验运行完毕！');
