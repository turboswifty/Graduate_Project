% 选择 .mat 文件
[file, path] = uigetfile('*.mat', '选择包含光谱数据的 .mat 文件');
if isequal(file, 0)
    disp('用户取消选择。');
    return;
end
fullpath = fullfile(path, file);

% 加载文件（返回结构体）
data = load(fullpath);

% 获取结构体中所有字段名
fields = fieldnames(data);

% 找出第一个数值型变量（假设它是光谱数据）
numericField = '';
for i = 1:length(fields)
    if isnumeric(data.(fields{i}))
        numericField = fields{i};
        break;
    end
end

if isempty(numericField)
    error('文件中没有找到数值型变量。');
end

% 提取数据（假设是一个向量，如果不是，取其第一行或第一列）
spec = data.(numericField);
if size(spec, 1) > 1 && size(spec, 2) > 1
    warning('数据是二维矩阵，将使用第一行作为光谱。');
    spec = spec(:, 1);
else
    spec = spec(:)';  % 确保为行向量
end

% 假设横坐标是波段编号，长度为211（可根据实际调整）
nBands = 211;
x = 1:nBands;
if length(spec) < nBands
    warning('数据长度不足 %d，将绘制实际长度 %d 个点。', nBands, length(spec));
    x = 1:length(spec);
end

% 绘制光谱
figure('Name', '光谱示意图');
plot(x, spec(1:length(x)), 'r-', 'LineWidth', 1.5);
title('选取的.mat文件的画图结果');
xlabel('波段 (Bands)');
ylabel('反射率 (Normalized Reflectance)');
grid on;