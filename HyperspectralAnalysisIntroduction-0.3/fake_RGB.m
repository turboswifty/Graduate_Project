clc; clear; close all;

% load the data
load('muufl_gulfport_campus_w_lidar_1.mat');

% extract the RGB
rgb_img = hsi.RGB;

% draw the image
figure;
imshow(rgb_img);
title('Gulfport Campus RGB Pseudo-image Image');
axis on;