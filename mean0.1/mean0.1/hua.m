clc;clear all;close all;
load('../E_tjh')
load('end04')
% true_plot=plot(1:211,E_t,'r')
% hold on
% est_plot=plot(1:211,E_vca,'b')
% legend([true_plot est_plot],'真实标签','mivca','FontSize',12)


% === 绘图前进行 Min-Max 归一化 ===
% 将真实标签和提取的端元都拉伸到 [0, 1] 之间，只对比形状
E_t_plot = (E_t - min(E_t)) / (max(E_t) - min(E_t));
E_vca_plot = (E_vca - min(E_vca)) / (max(E_vca) - min(E_vca));


% E_t_plot = E_t;
% E_vca_plot = E_vca;

% === 重新画图 ===
figure('Name', 'Endmember Comparison'); 
plot(1:211, E_t_plot, 'r-', 'LineWidth', 1.5); hold on;
plot(1:211, E_vca_plot, 'b-', 'LineWidth', 1.5);
title('目标端元提取结果对比 (归一化后)');
xlabel('波段 (Bands)');
ylabel('归一化反射率 (Normalized Reflectance)');
legend('真实标签', 'MIVCA提取结果');
grid on;