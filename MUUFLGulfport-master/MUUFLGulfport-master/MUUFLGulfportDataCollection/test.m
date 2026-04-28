addpath('util');
addpath('Bullwinkle');
addpath('signature_detectors');




% load('Figure103_ROC_data.mat');
%   figure; hold on;
%   plot(ACE_SS.FAR, ACE_SS.PD, 'b-', 'LineWidth', 2);
%   plot(SMF_MAX.FAR, SMF_MAX.PD, 'r-', 'LineWidth', 2);


  % load('Figure103_score_backup.mat');
  % figure;
  % PlotBullwinkleRoc(score, 'detectors', 'xlim', [0 1e-3]);


  load('Figure103_ROC_data.mat');

  figure; hold on;
  plot(ACE_SS.FAR, ACE_SS.PD, 'r-', 'LineWidth', 2);
  plot(SMF_MAX.FAR, SMF_MAX.PD, 'm-', 'LineWidth', 2);  % 注意：SMF 用洋红色和原图一致

  xlim([0 0.001]);   % ← 这行必须加！不加就会得到你的"错误图"
  ylim([-0.01 1.01]);
  xlabel('FAR (FA/m^2)');
  ylabel('PD');
  legend('ACE', 'SMF');
  grid on;
