
function [X,P,labels_bag,labels_point]= demo_generate_synthetic_data()

% This function generates synthetic data following definition of multiple instance learning problem

% REFERENCE :
% C. Jiao, A. Zare, 
% Functions of Multiple Instances for Learning Target Signatures,? 
% IEEE transactions on Geoscience and Remote Sensing, Vol. 53, No. 8, Aug. 2015, DOI: 10.1109/TGRS.2015.2406334
%
% SYNTAX: [X,P,labels_bag,labels_point]= demo_generate_synthetic_data()

% Inputs:
%    None
%
%Outputs:
%   X - dataset in column vectors
%   P - proportion set in column vectors
%   labels_bag - bag level label per data point
%   labels_point - instance level label per data point

% Author: Changzhe Jiao, Alina Zare
% University of Missouri, Department of Electrical and Computer Engineering
% Email Address: cjr25@mail.missouri.edu; zarea@missouri.edu


addpath('..\gen_synthetic_data_code')
addpath('..\synthetic_data')

load('E_truth')

E_t=E_truth(:,1); %set target endmember
E_minus=E_truth(:,2:4); %set background endmembers
num_pbags=15; % No. of positive bag
num_nbags=5; % No. of negative bag
num_points=500; % No. of points in each bag
n_tar=200; % No. of target points in each positive bag
N_b=2; % minimum No. of background constituent background endmember in target point
Pt_mean=0.1; % mean target porportion value in target points
sigma=2; %parameter controlling variance of Dirichlet distribution
expect_SdB=35; % data noise level

[X,P,labels_bag,labels_point]=gen_multi_tar_mixed_data(E_t,E_minus,num_pbags,num_nbags,num_points,n_tar,N_b,Pt_mean,sigma,expect_SdB);
labels_bag=reshape(labels_bag',1,(num_pbags+num_nbags)*num_points);
labels_point=reshape(labels_point',1,(num_pbags+num_nbags)*num_points);


% === 提取你的 positive 和 negative 矩阵 ===
% 计算正包占据的总像素数 (15个包 * 500个像素 = 7500)
pos_pixel_count = num_pbags * num_points;

% 切片提取
positive = X(:, 1:pos_pixel_count); 
negative = X(:, pos_pixel_count+1:end); 

% 保存为 .mat 文件，供你的 MIVCA 主程序无缝调用
save('positivejh.mat', 'positive');
save('negativejh.mat', 'negative');
% 顺便把标签也保存下来，以后算 AUC 会用到
save('ground_truthjh.mat', 'labels_point', 'labels_bag'); 

disp('官方数据集生成完毕！并已拆分为 positive.mat 和 negative.mat');










