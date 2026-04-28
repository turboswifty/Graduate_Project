% demo_brown_ace.m
% 用输入的 brown 端元进行 ACE 检测，画 ROC 曲线并计算 AUC
clc; clear all; close all;

addpath('util');
addpath('Bullwinkle');
addpath('signature_detectors');

%% ============ 输入：brown 端元 ============
% 方式1：直接指定 brown 端元向量（n_band x 1）
%   请将你的端元赋值给 brown_endmember，例如：
%   brown_endmember = your_extracted_endmember(:);
%
% 方式2：从数据集自带的 lab 光谱中提取 brown 签名
%   若未手动赋值，则默认从 lab 光谱中取 brown 签名作为示例

%load("end04_gulfport3_mivca.mat");
load("end04_gulfport.mat");
%load("end_efumi_gulfport.mat");
%load("end_mihe_gulfport.mat");
brown_endmember = E_vca;
%brown_endmember = E_mihe;
%brown_endmember = E_efumi_target;

if ~exist('brown_endmember','var')
    load tgt_img_spectra; % order: brown, dark green, faux vineyard green, pea green
    brown_endmember = tgt_img_spectra.spectra(:,1);
    fprintf('未提供 brown_endmember，已从图像GT光谱加载 brown 签名\n');
end

%% ============ 加载数据 ============
if ~exist('hsi','var') || ~exist('hsi_img','var')
    load muufl_gulfport_campus_w_lidar_1;
    %load muufl_gulfport_campus_3.mat;
    hsi_img = double(hsi.Data);
end

%% ============ ACE 检测 ============
ace_out = ace_detector(hsi_img, brown_endmember(:), hsi.valid_mask);

%% ============ Bullwinkle 评分（仅 brown 目标，所有尺寸） ============
filt_brown = { {'brown',[],[],[]} };

bw_params = BullwinkleParameters();
bw_params.Halo = 2;

score = score_hylid_perpixel(hsi, ace_out, filt_brown, 'ACE-Brown', ...
    'det_fig', 10, 'roc_fig', 11, 'bw_params', bw_params);

%% ============ 画 ROC 曲线 ============
figure(11); clf;
PlotBullwinkleRoc(score, 'ACE (Brown)');
title('ROC Curve - ACE Detection for Brown Target');

%% ============ 计算 AUC ============
max_far = 1e-3; % 计算 FAR <= 1e-3 范围内的 AUC，可根据需要调整
auc = auc_upto_far(max_far, score);
fprintf('AUC (FAR <= %.1e) = %.4f\n', max_far, auc);

% 也计算 FAR <= 1e-2 的 AUC 作为参考
max_far2 = 1e-2;
auc2 = auc_upto_far(max_far2, score);
fprintf('AUC (FAR <= %.1e) = %.4f\n', max_far2, auc2);
