% =========================================================================
% 将 efumi 对 Gulfport 四个类别的端元结果合并为一个 [bands x 4] 的 mat 文件
% =========================================================================
clc; clear; close all;

%% 1. 配置四个类别的端元文件路径和变量名
% 请根据你的实际文件名修改下面的路径
% 格式: {文件名, 变量名, 类别标签}

% file_list = {
%     'end_brown.mat',         'E_brown',      'Brown';
%     'end_darkgreen.mat',     'E_darkgreen',  'DarkGreen';
%     'end_faux.mat',          'E_faux',       'FauxVineyardGreen';
%     'end_pea.mat',           'E_pea',        'PeaGreen';
% };

% 如果你四个文件里的变量名都叫 E_efumi_target，可以改成这样：
file_list = {
    'end_efumi_gulfport.mat',       'E_efumi_target',  'Brown';
    'end_efumi_gulfport_darkgreen.mat',   'E_efumi_target',  'DarkGreen';
    'end_efumi_gulfport_faux_vineyard_green.mat',        'E_efumi_target',  'FauxVineyardGreen';
    'end_efumi_gulfport_pea_green.mat',         'E_efumi_target',  'PeaGreen';
 };

n_classes = size(file_list, 1);
E_all = [];
labels = {};

%% 2. 逐个加载并拼接
disp('正在加载四个类别的端元 ...');
for i = 1:n_classes
    fname = file_list{i, 1};
    varname = file_list{i, 2};
    label = file_list{i, 3};
    
    if ~exist(fname, 'file')
        error('文件不存在: %s', fname);
    end
    
    data = load(fname);
    
    if ~isfield(data, varname)
        % 如果变量名不对，尝试自动探测第一个变量
        vars = fieldnames(data);
        fprintf('[%s] 未找到变量 "%s"，自动使用 "%s"\n', fname, varname, vars{1});
        varname = vars{1};
    end
    
    E_i = data.(varname);
    
    % 确保是列向量
    if isrow(E_i)
        E_i = E_i';
    end
    
    E_all = [E_all, E_i];  % 横向拼接
    labels{end+1} = label;
    
    fprintf('  ✅ %s: %s -> 大小 [%d x 1]\n', label, fname, length(E_i));
end

%% 3. 检查结果
disp(' ');
disp('----------------------------------------');
fprintf('合并后矩阵 E_efumi_gulfport4 大小: [%d x %d]\n', size(E_all, 1), size(E_all, 2));
disp('列顺序: ');
for i = 1:n_classes
    fprintf('  第 %d 列: %s\n', i, labels{i});
end
disp('----------------------------------------');

%% 4. 保存为 mat 文件
E_efumi_gulfport4 = E_all;  % 最终变量名
save('E_efumi_gulfport4all.mat', 'E_efumi_gulfport4', 'labels');
disp('已保存到: E_efumi_gulfport4all.mat');
disp('  包含: E_efumi_gulfport4 ([bands x 4]), labels (1x4 cell)');

%% 5. 可选：画图看看四个光谱
try
    figure('Name', 'efumi Gulfport 4-Class Endmembers', 'Position', [100 100 800 500]);
    colors = {'#8B4513', '#006400', '#9ACD32', '#90EE90'};  % brown, darkgreen, faux, pea
    for i = 1:n_classes
        plot(E_all(:,i), 'Color', colors{i}, 'LineWidth', 2); hold on;
    end
    legend(labels, 'Location', 'best');
    xlabel('Band Index'); ylabel('Reflectance');
    title('efumi Estimated Endmembers (Gulfport 4 Classes)');
    grid on;
catch
    % 如果画图失败也不影响保存
end

disp('完成！');
