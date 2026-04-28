% 脚本：显示两个 .mat 文件的内容
% 通过文件选择对话框选取两个文件，然后展示每个文件中的变量

% 选择第一个 .mat 文件
[file1, path1] = uigetfile('*.mat', '选择第一个 .mat 文件');
if isequal(file1, 0)
    disp('用户取消选择，脚本结束。');
    return;
end
fullpath1 = fullfile(path1, file1);

% 选择第二个 .mat 文件
[file2, path2] = uigetfile('*.mat', '选择第二个 .mat 文件');
if isequal(file2, 0)
    disp('用户取消选择，脚本结束。');
    return;
end
fullpath2 = fullfile(path2, file2);

% 辅助函数：显示变量的基本信息
function display_variable_info(varName, varValue)
    fprintf('  变量 %s：大小 %s\n', varName, mat2str(size(varValue)));
    if isnumeric(varValue) || islogical(varValue)
        fprintf('      前几个元素：\n');
        % 显示最多 5x5 的子矩阵
        sub = varValue(1:min(5, end), 1:min(5, end));
        disp(sub);
    elseif ischar(varValue) || isstring(varValue)
        fprintf('      内容：%s\n', char(varValue));
    elseif isstruct(varValue)
        fprintf('      结构体，字段：%s\n', strjoin(fieldnames(varValue), ', '));
    elseif iscell(varValue)
        fprintf('      元胞数组，大小 %s\n', mat2str(size(varValue)));
    else
        fprintf('      类型：%s\n', class(varValue));
    end
end

% 加载并显示第一个文件
disp(' ');
disp(['加载文件：', fullpath1]);
data1 = load(fullpath1);
fields1 = fieldnames(data1);
fprintf('第一个文件包含 %d 个变量：\n', length(fields1));
for i = 1:length(fields1)
    display_variable_info(fields1{i}, data1.(fields1{i}));
end

% 加载并显示第二个文件
disp(' ');
disp(['加载文件：', fullpath2]);
data2 = load(fullpath2);
fields2 = fieldnames(data2);
fprintf('第二个文件包含 %d 个变量：\n', length(fields2));
for i = 1:length(fields2)
    display_variable_info(fields2{i}, data2.(fields2{i}));
end

disp('脚本执行完毕。');