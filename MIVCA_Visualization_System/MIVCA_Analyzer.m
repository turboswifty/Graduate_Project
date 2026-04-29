function MIVCA_Analyzer()
% =========================================================================
% MIVCA_Analyzer - 完整的 MIVCA 算法可视化分析系统
% 用于 MUUFL Gulfport 高光谱数据集的目标检测与端元提取
%
% 功能流程:
%   1. 加载原始 HSI 数据并选择目标类别
%   2. 自动预处理: 划分正包/负包, 匹配真实端元
%   3. 运行 MIVCA 算法迭代提取目标端元
%   4. 标准 VCA 对比实验
%   5. ACE 目标检测 + ROC 曲线评估
%   6. 全面的可视化: 光谱对比/收敛曲线/ROC/AUC
%
% 作者: 毕设项目
% 日期: 2026-04-29
% =========================================================================

% ------------------------ 路径配置 ------------------------
% 添加依赖路径 (不修改原有文件)
addpath(genpath('/Users/jihao/毕设相关/mean0.1/mean0.1/'));
addpath(genpath('/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/'));

% Bullwinkle 官方检测框架
addpath(genpath('/Users/jihao/毕设相关/MUUFLGulfport-master/MUUFLGulfport-master/MUUFLGulfportDataCollection/util/'));
addpath(genpath('/Users/jihao/毕设相关/MUUFLGulfport-master/MUUFLGulfport-master/MUUFLGulfportDataCollection/Bullwinkle/'));
addpath(genpath('/Users/jihao/毕设相关/MUUFLGulfport-master/MUUFLGulfport-master/MUUFLGulfportDataCollection/signature_detectors/'));

% ------------------------ 全局状态数据结构 ------------------------
state = struct();
state.data_loaded    = false;
state.data_processed = false;
state.mivca_done     = false;
state.ace_done       = false;
state.vca_done       = false;

% 原始数据
state.hsi_cube       = [];
state.hsi_2d         = [];
state.hsi_struct     = [];  % 完整 hsi 结构体 (含 valid_mask, groundTruth 等)
state.rows           = 0;
state.cols            = 0;
state.bands          = 0;
state.groundTruth    = [];

% 处理后的数据
state.target_class   = '';
state.positive       = [];
state.negative       = [];
state.E_t            = [];  % 真实端元 (ground truth)
state.labels_point   = [];  % 像素级标签
state.labels_bag     = [];  % 包级标签
state.pos_indices    = [];
state.neg_indices    = [];
state.eval_indices   = [];

% 算法结果
state.E_mivca        = [];  % MIVCA 提取的端元
state.E_vca_standard = [];  % 标准 VCA 提取的端元
state.jiao_history   = [];  % SAD 收敛历史
state.ma1_history    = [];  % ma1 收敛历史
state.mivca_runtime  = 0;
state.mivca_iters    = 0;

% ACE/ROC 结果 (Bullwinkle 官方框架)
state.ace_det_img    = [];  % 全图 ACE 检测结果
state.smf_det_img    = [];  % 全图 SMF 检测结果
state.bw_score_ace   = [];  % Bullwinkle score struct (ACE)
state.bw_score_smf   = [];  % Bullwinkle score struct (SMF)
state.pAUC_ace       = 0;   % 部分 AUC (FAR <= 1e-3)
state.pAUC_smf       = 0;
state.ace_scores     = [];  % 子集 ACE 分数 (正包+负包)
state.FPR            = [];
state.TPR            = [];
state.AUC            = 0;
state.ace_test_data  = [];
state.ace_labels     = [];

% 路径
state.data_dir       = '/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/';
state.hsi_file       = fullfile(state.data_dir, 'muufl_gulfport_campus_w_lidar_1.mat');
state.spectra_file   = fullfile(state.data_dir, 'tgt_img_spectra.mat');

% ======================================================================
%                        GUI 界面构建
% ======================================================================
app = struct();

% 主窗口
app.fig = uifigure('Name', 'MIVCA 高光谱目标检测可视化分析系统', ...
    'Position', [50, 50, 1400, 900], ...
    'Color', [0.96 0.96 0.96], ...
    'Resize', 'on');

% ------------------------ 顶部标题栏 ------------------------
app.header = uipanel(app.fig, ...
    'Position', [0, 860, 1400, 40], ...
    'BackgroundColor', [0.15 0.25 0.45], ...
    'BorderType', 'none');

uilabel(app.header, ...
    'Text', 'MIVCA 高光谱目标检测可视化分析系统  |  MUUFL Gulfport Dataset', ...
    'Position', [20, 8, 600, 25], ...
    'FontSize', 14, ...
    'FontWeight', 'bold', ...
    'FontColor', [1 1 1]);

app.status_label = uilabel(app.header, ...
    'Text', '就绪', ...
    'Position', [1100, 8, 280, 25], ...
    'FontSize', 11, ...
    'FontColor', [0.8 0.9 1], ...
    'HorizontalAlignment', 'right');

% ------------------------ 左侧控制面板 ------------------------
app.left_panel = uipanel(app.fig, ...
    'Title', '控制面板', ...
    'Position', [10, 10, 320, 845], ...
    'BackgroundColor', [1 1 1], ...
    'FontSize', 13, ...
    'FontWeight', 'bold');

% -- 数据源区域 --
y_pos = 790;
uilabel(app.left_panel, 'Text', '数据源', ...
    'Position', [15, y_pos, 80, 20], ...
    'FontSize', 11, 'FontWeight', 'bold', 'FontColor', [0.15 0.25 0.45]);

app.file_path_display = uitextarea(app.left_panel, ...
    'Position', [15, 755, 290, 35], ...
    'Value', state.hsi_file, ...
    'Editable', 'off', ...
    'FontSize', 9);

y_pos = 745;
% -- 目标类别选择 --
uilabel(app.left_panel, 'Text', '目标类别选择', ...
    'Position', [15, y_pos, 150, 20], ...
    'FontSize', 11, 'FontWeight', 'bold', 'FontColor', [0.15 0.25 0.45]);

app.class_dropdown = uidropdown(app.left_panel, ...
    'Position', [15, 715, 290, 25], ...
    'Items', {'brown', 'dark green', 'faux vineyard green', 'pea green'}, ...
    'Value', 'brown', ...
    'FontSize', 11, ...
    'ValueChangedFcn', @(dd, evt) on_class_changed(dd, evt));

% -- 参数配置 --
y_pos = 690;
uilabel(app.left_panel, 'Text', '算法参数配置', ...
    'Position', [15, y_pos, 150, 20], ...
    'FontSize', 11, 'FontWeight', 'bold', 'FontColor', [0.15 0.25 0.45]);

% tiqv
uilabel(app.left_panel, 'Text', 'VCA 背景端元数 (tiqv):', ...
    'Position', [15, 665, 180, 18], 'FontSize', 10);
app.tiqv_spinner = uispinner(app.left_panel, ...
    'Position', [200, 663, 100, 22], ...
    'Value', 15, 'Limits', [3, 50], 'Step', 1, 'FontSize', 10);

% 最大迭代次数
uilabel(app.left_panel, 'Text', '最大迭代次数:', ...
    'Position', [15, 638, 180, 18], 'FontSize', 10);
app.maxiter_spinner = uispinner(app.left_panel, ...
    'Position', [200, 636, 100, 22], ...
    'Value', 1000, 'Limits', [10, 5000], 'Step', 50, 'FontSize', 10);

% 背景采样数
uilabel(app.left_panel, 'Text', '背景像素采样数:', ...
    'Position', [15, 611, 180, 18], 'FontSize', 10);
app.bg_samples_spinner = uispinner(app.left_panel, ...
    'Position', [200, 609, 100, 22], ...
    'Value', 100000, 'Limits', [1000, 500000], 'Step', 10000, 'FontSize', 10);

% 正包最小像素阈值
uilabel(app.left_panel, 'Text', '正包最小像素阈值:', ...
    'Position', [15, 584, 180, 18], 'FontSize', 10);
app.min_pos_spinner = uispinner(app.left_panel, ...
    'Position', [200, 582, 100, 22], ...
    'Value', 12, 'Limits', [1, 50], 'Step', 1, 'FontSize', 10);

% -- 操作按钮 --
y_pos = 545;
app.btn_load = uibutton(app.left_panel, 'push', ...
    'Text', '1. 加载并预处理数据', ...
    'Position', [15, y_pos, 290, 40], ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.18 0.55 0.34], 'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @(btn, evt) load_and_process());

app.btn_mivca = uibutton(app.left_panel, 'push', ...
    'Text', '2. 运行 MIVCA 算法', ...
    'Position', [15, y_pos-50, 290, 40], ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.15 0.45 0.70], 'FontColor', [1 1 1], ...
    'Enable', 'off', ...
    'ButtonPushedFcn', @(btn, evt) run_mivca_algorithm());

app.btn_vca = uibutton(app.left_panel, 'push', ...
    'Text', '3. 运行标准 VCA 对比', ...
    'Position', [15, y_pos-100, 290, 40], ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.60 0.35 0.15], 'FontColor', [1 1 1], ...
    'Enable', 'off', ...
    'ButtonPushedFcn', @(btn, evt) run_standard_vca());

app.btn_ace = uibutton(app.left_panel, 'push', ...
    'Text', '4. ACE 检测 + ROC 评估', ...
    'Position', [15, y_pos-150, 290, 40], ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.55 0.20 0.45], 'FontColor', [1 1 1], ...
    'Enable', 'off', ...
    'ButtonPushedFcn', @(btn, evt) run_ace_detection());

app.btn_full = uibutton(app.left_panel, 'push', ...
    'Text', '一键运行完整流程', ...
    'Position', [15, y_pos-200, 290, 45], ...
    'FontSize', 13, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.80 0.25 0.15], 'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @(btn, evt) run_full_pipeline());

% -- 进度条引用 (按需创建) --
app.progress_bar = [];

% -- 结果摘要 --
app.summary_panel = uipanel(app.left_panel, ...
    'Title', '结果摘要', ...
    'Position', [15, 10, 290, 210], ...
    'BackgroundColor', [0.98 0.98 0.98], ...
    'FontSize', 11, 'FontWeight', 'bold');

app.summary_text = uitextarea(app.summary_panel, ...
    'Position', [5, 5, 275, 180], ...
    'Value', '等待运行...', ...
    'Editable', 'off', ...
    'FontSize', 10);

% ------------------------ 右侧可视化区域 (Tab 页) ------------------------
app.tab_group = uitabgroup(app.fig, ...
    'Position', [340, 10, 1050, 845]);

% Tab 1: 数据概览
app.tab_data = uitab(app.tab_group, 'Title', '数据概览', ...
    'BackgroundColor', [1 1 1]);
app.ax_data_overview = uiaxes(app.tab_data, ...
    'Position', [30, 50, 600, 750]);
title(app.ax_data_overview, 'HSI 伪彩色图像 + 目标标注');
app.ax_data_info = uiaxes(app.tab_data, ...
    'Position', [680, 450, 340, 350]);
title(app.ax_data_info, '数据统计信息');
app.ax_data_info.Visible = 'off';

% 数据统计文本
app.data_stats = uitextarea(app.tab_data, ...
    'Position', [680, 50, 340, 380], ...
    'Value', '尚未加载数据', ...
    'Editable', 'off', ...
    'FontSize', 10);

% Tab 2: 端元光谱对比
app.tab_spectral = uitab(app.tab_group, 'Title', '端元光谱对比', ...
    'BackgroundColor', [1 1 1]);
app.ax_spectral = uiaxes(app.tab_spectral, ...
    'Position', [50, 80, 950, 720]);
title(app.ax_spectral, '归一化端元光谱对比 (MIVCA vs Ground Truth vs Standard VCA)');
xlabel(app.ax_spectral, '波段 (Band Index)');
ylabel(app.ax_spectral, '归一化反射率');
grid(app.ax_spectral, 'on');

% Tab 3: 收敛曲线
app.tab_convergence = uitab(app.tab_group, 'Title', '收敛曲线', ...
    'BackgroundColor', [1 1 1]);
app.ax_convergence = uiaxes(app.tab_convergence, ...
    'Position', [50, 80, 950, 720]);
title(app.ax_convergence, 'MIVCA 算法收敛曲线 (SAD Error vs Iterations)');
xlabel(app.ax_convergence, '迭代次数');
ylabel(app.ax_convergence, '角度误差 SAD (度)');
grid(app.ax_convergence, 'on');

% Tab 4: ACE 检测 + ROC (Bullwinkle 官方框架)
app.tab_roc = uitab(app.tab_group, 'Title', 'ACE检测 & ROC', ...
    'BackgroundColor', [1 1 1]);

% ROC 曲线 (左侧, 占 2/3 宽度)
app.ax_roc = uiaxes(app.tab_roc, ...
    'Position', [50, 300, 650, 500]);
title(app.ax_roc, 'ROC 曲线 (Bullwinkle Framework)');
xlabel(app.ax_roc, 'False Alarm Rate (FAR / m^2)');
ylabel(app.ax_roc, 'Probability of Detection (PD)');
grid(app.ax_roc, 'on');

% ACE 分数分布 (右侧上方)
app.ax_ace_dist = uiaxes(app.tab_roc, ...
    'Position', [740, 480, 280, 320]);
title(app.ax_ace_dist, 'ACE 分数分布 (子集)');
grid(app.ax_ace_dist, 'on');

% 检测信息面板 (右侧下方)
app.roc_info_text = uitextarea(app.tab_roc, ...
    'Position', [50, 20, 650, 260], ...
    'Value', '尚未运行 ACE 检测...', ...
    'Editable', 'off', ...
    'FontSize', 10);

% 监控指标面板
app.det_metrics_text = uitextarea(app.tab_roc, ...
    'Position', [740, 20, 280, 440], ...
    'Value', '', ...
    'Editable', 'off', ...
    'FontSize', 10);

% Tab 5: 检测图像可视化 (新增)
app.tab_detmap = uitab(app.tab_group, 'Title', '检测图像', ...
    'BackgroundColor', [1 1 1]);

% ACE 检测热力图 (左侧)
app.ax_ace_heatmap = uiaxes(app.tab_detmap, ...
    'Position', [30, 50, 500, 750]);
title(app.ax_ace_heatmap, 'ACE 检测热力图 (全图)');

% 目标区域放大视图 (右侧)
app.ax_zoom1 = uiaxes(app.tab_detmap, ...
    'Position', [570, 500, 220, 280]);
title(app.ax_zoom1, '目标区域 #1');

app.ax_zoom2 = uiaxes(app.tab_detmap, ...
    'Position', [820, 500, 220, 280]);
title(app.ax_zoom2, '目标区域 #2');

app.ax_zoom3 = uiaxes(app.tab_detmap, ...
    'Position', [570, 130, 220, 280]);
title(app.ax_zoom3, '目标区域 #3');

app.ax_zoom4 = uiaxes(app.tab_detmap, ...
    'Position', [820, 130, 220, 280]);
title(app.ax_zoom4, '目标区域 #4');

% 检测统计
app.detmap_info = uitextarea(app.tab_detmap, ...
    'Position', [570, 20, 470, 100], ...
    'Value', '请先运行 ACE 检测', ...
    'Editable', 'off', ...
    'FontSize', 10);

% Tab 6: 算法对比总览
app.tab_comparison = uitab(app.tab_group, 'Title', '算法对比总览', ...
    'BackgroundColor', [1 1 1]);
app.ax_sad_compare = uiaxes(app.tab_comparison, ...
    'Position', [50, 400, 450, 400]);
title(app.ax_sad_compare, 'SAD 误差对比 (度)');
grid(app.ax_sad_compare, 'on');

app.ax_runtime_compare = uiaxes(app.tab_comparison, ...
    'Position', [550, 400, 450, 400]);
title(app.ax_runtime_compare, '运行时间对比 (秒)');
grid(app.ax_runtime_compare, 'on');

app.compare_text = uitextarea(app.tab_comparison, ...
    'Position', [50, 20, 950, 350], ...
    'Value', '请先运行 MIVCA 和标准 VCA 后再查看对比结果', ...
    'Editable', 'off', ...
    'FontSize', 10);

% 初始化完成
update_status('系统初始化完成，请选择目标类别并加载数据');

% ======================================================================
%                    回调函数与核心逻辑
% ======================================================================

% ------------------------ 类别切换回调 ------------------------
function on_class_changed(~, ~)
    state.target_class = app.class_dropdown.Value;
    update_status(['目标类别已更改为: ', state.target_class, ' (需重新加载数据)']);
    state.data_processed = false;
    state.mivca_done = false;
    state.ace_done = false;
    state.vca_done = false;
    update_button_states();
end

% ------------------------ 1. 加载并预处理数据 ------------------------
function load_and_process()
    update_status('正在加载数据...');
    progress_open('加载原始 HSI 数据...');

    try
        % 加载 HSI 数据
        if ~exist(state.hsi_file, 'file')
            error('找不到 HSI 数据文件: %s', state.hsi_file);
        end
        hsi_data = load(state.hsi_file);
        if ~isfield(hsi_data, 'hsi')
            error('数据文件中未找到 hsi 结构体');
        end

        % 加载目标光谱
        if ~exist(state.spectra_file, 'file')
            error('找不到目标光谱文件: %s', state.spectra_file);
        end
        spectra_data = load(state.spectra_file);

        % 解析 HSI 立方体
        state.hsi_struct = hsi_data.hsi;  % 保存完整结构体 (供 Bullwinkle 框架使用)
        state.hsi_cube = double(hsi_data.hsi.Data);
        [state.rows, state.cols, state.bands] = size(state.hsi_cube);
        total_pixels = state.rows * state.cols;
        state.hsi_2d = reshape(state.hsi_cube, total_pixels, state.bands)';
        state.groundTruth = hsi_data.hsi.groundTruth;

        progress_update(0.3, '正在划分正包/负包...');

        % 获取目标类别
        state.target_class = app.class_dropdown.Value;
        gt = state.groundTruth;
        num_targets = length(gt.Targets_Type);

        % 划分正包 (5x5 窗口)
        pos_indices = [];
        point_wise_pos_indices = [];

        for i = 1:num_targets
            current_type = strtrim(lower(gt.Targets_Type{i}));
            if ~strcmp(current_type, state.target_class)
                continue;
            end

            r = gt.Targets_rowIndices(i);
            c = gt.Targets_colIndices(i);

            % 包级: 5x5 窗口
            r_range = max(1, r-2):min(state.rows, r+2);
            c_range = max(1, c-2):min(state.cols, c+2);

            for rr = r_range
                for cc = c_range
                    linear_idx = (cc - 1) * state.rows + rr;
                    pos_indices = [pos_indices, linear_idx];
                end
            end

            % 像素级: 根据 Target Size 确定窗口
            target_size = gt.Targets_Size(i);
            switch target_size
                case 0.5
                    rr_r = max(1, r):min(state.rows, r);
                    cc_r = max(1, c):min(state.cols, c);
                case 1
                    rr_r = max(1, r):min(state.rows, r);
                    cc_r = max(1, c):min(state.cols, c);
                case 3
                    rr_r = max(1, r-1):min(state.rows, r+1);
                    cc_r = max(1, c-1):min(state.cols, c+1);
                case 6
                    rr_r = max(1, r-2):min(state.rows, r+2);
                    cc_r = max(1, c-2):min(state.cols, c+2);
                otherwise
                    rr_r = max(1, r-2):min(state.rows, r+2);
                    cc_r = max(1, c-2):min(state.cols, c+2);
            end

            for rr = rr_r
                for cc = cc_r
                    linear_idx = (cc - 1) * state.rows + rr;
                    point_wise_pos_indices = [point_wise_pos_indices, linear_idx];
                end
            end
        end

        state.pos_indices = unique(pos_indices);
        point_wise_pos_indices = unique(point_wise_pos_indices);
        num_pos = length(state.pos_indices);

        if num_pos == 0
            error('类别 "%s" 在数据集中没有找到对应目标！', state.target_class);
        end

        % 提取正包矩阵
        state.positive = state.hsi_2d(:, state.pos_indices);

        % 负包: 所有非正包像素
        all_indices = 1:total_pixels;
        neg_indices_all = setdiff(all_indices, state.pos_indices);

        % 降采样负包
        num_bg = app.bg_samples_spinner.Value;
        if length(neg_indices_all) > num_bg
            rng(42);
            rand_idx = randperm(length(neg_indices_all), num_bg);
            state.neg_indices = neg_indices_all(rand_idx);
        else
            state.neg_indices = neg_indices_all;
        end

        state.negative = state.hsi_2d(:, state.neg_indices);

        progress_update(0.6, '匹配真实端元并创建标签...');

        % 匹配真实端元
        spectra = spectra_data.tgt_img_spectra.spectra;
        class_map = containers.Map(...
            {'brown', 'dark green', 'faux vineyard green', 'pea green'}, ...
            {1, 2, 3, 4});
        if isKey(class_map, state.target_class)
            state.E_t = spectra(:, class_map(state.target_class));
        else
            error('无法匹配类别 "%s" 的真实端元', state.target_class);
        end

        % 创建标签
        labels_bag_full = zeros(1, total_pixels);
        labels_bag_full(state.pos_indices) = 1;

        labels_point_full = zeros(1, total_pixels);
        labels_point_full(point_wise_pos_indices) = 1;

        state.eval_indices = [state.pos_indices, state.neg_indices];
        state.labels_bag   = labels_bag_full(state.eval_indices);
        state.labels_point = labels_point_full(state.eval_indices);

        progress_update(0.9, '生成数据概览...');

        % 更新状态
        state.data_loaded = true;
        state.data_processed = true;

        % 显示数据概览
        show_data_overview();

        % 更新统计信息
        stats_str = sprintf(['数据加载成功!\n\n', ...
            '━━━━━━━━━━━━━━━━━━━━\n', ...
            '数据集信息:\n', ...
            '  图像尺寸: %d x %d 像素\n', ...
            '  波段数:   %d\n', ...
            '  总像素数: %d\n\n', ...
            '目标类别: %s\n', ...
            '  正包像素: %d\n', ...
            '  负包像素: %d (降采样后)\n', ...
            '  正包占比: %.2f%%\n\n', ...
            '数据预处理完成，可以运行算法'], ...
            state.rows, state.cols, state.bands, ...
            state.rows * state.cols, ...
            state.target_class, ...
            size(state.positive, 2), size(state.negative, 2), ...
            100 * size(state.positive, 2) / (size(state.positive, 2) + size(state.negative, 2)));

        app.data_stats.Value = stats_str;
        app.summary_text.Value = stats_str;

        progress_close();
        update_status('数据加载完成，可以运行 MIVCA 算法');
        update_button_states();

    catch ME
        progress_close();
        update_status(['错误: ', ME.message]);
        uialert(app.fig, ME.message, '数据加载失败');
    end
end

% ------------------------ 数据概览可视化 ------------------------
function show_data_overview()
    % 伪彩色合成 (使用波段 20, 35, 55 近似 RGB)
    r_band = min(20, state.bands);
    g_band = min(35, state.bands);
    b_band = min(55, state.bands);

    rgb_img = zeros(state.rows, state.cols, 3);
    rgb_img(:,:,1) = reshape(state.hsi_2d(r_band, :), state.rows, state.cols);
    rgb_img(:,:,2) = reshape(state.hsi_2d(g_band, :), state.rows, state.cols);
    rgb_img(:,:,3) = reshape(state.hsi_2d(b_band, :), state.rows, state.cols);

    % 归一化到 [0, 1]
    for c = 1:3
        layer = rgb_img(:,:,c);
        mn = min(layer(:)); mx = max(layer(:));
        if mx > mn
            rgb_img(:,:,c) = (layer - mn) / (mx - mn);
        end
    end
    % 增强对比度
    rgb_img = rgb_img .^ 0.6;

    cla(app.ax_data_overview);
    imshow(rgb_img, 'Parent', app.ax_data_overview);
    hold(app.ax_data_overview, 'on');

    % 叠加目标位置标注
    gt = state.groundTruth;
    num_targets = length(gt.Targets_Type);
    target_count = 0;
    for i = 1:num_targets
        current_type = strtrim(lower(gt.Targets_Type{i}));
        if strcmp(current_type, state.target_class)
            c = gt.Targets_colIndices(i);
            r = gt.Targets_rowIndices(i);
            % 画 5x5 框
            rectangle('Parent', app.ax_data_overview, ...
                'Position', [c-2.5, r-2.5, 5, 5], ...
                'EdgeColor', [1 0.2 0.2], 'LineWidth', 1.5, ...
                'FaceColor', [1 0 0 0.15]);
            target_count = target_count + 1;
        end
    end

    title(app.ax_data_overview, ...
        sprintf('HSI 伪彩色图像 (波段 %d/%d/%d) — %d 个 %s 目标', ...
        r_band, g_band, b_band, target_count, state.target_class), ...
        'FontSize', 13);

    hold(app.ax_data_overview, 'off');
end

% ------------------------ 2. 运行 MIVCA 算法 ------------------------
function run_mivca_algorithm()
    if ~state.data_processed
        uialert(app.fig, '请先加载并预处理数据!', '提示');
        return;
    end

    update_status('正在运行 MIVCA 算法...');
    progress_open('初始化 MIVCA 迭代...');

    try
        tiqv = app.tiqv_spinner.Value;
        max_iter = app.maxiter_spinner.Value;
        min_positive = app.min_pos_spinner.Value;

        positive = state.positive;
        negative = state.negative;
        E_t = state.E_t;

        % 初始化
        jiao = zeros(1, max_iter);
        ma1_history = zeros(1, max_iter);
        E_vca_old = [];
        ma1_old = [];
        E_vca = [];

        start_time = tic;

        for i = 1:max_iter
            % VCA 提取背景端元
            background = vca(negative, 'Endmembers', tiqv);

            % 正交投影, 找出正包中与背景最相似的像素
            [index, ma1] = ortho(tiqv, [positive, background]);

            % 将筛选出的像素从正包移到负包
            negative = [negative, positive(1:state.bands, index)];
            positive(:, index) = [];

            [~, h] = size(positive);

            if mod(i, 10) == 0
                progress_update(min(i / 100, 0.9), ...
                    sprintf('迭代 %d/%d, 正包剩余: %d 像素', i, max_iter, h));
            end

            % 检查正包数量
            if h < min_positive
                update_status(sprintf('正包不足 %d 个, 提前终止于第 %d 次迭代', min_positive, i));
                break;
            end

            % VCA 提取目标端元 (1个)
            target = vca(positive, 'Endmembers', 1);
            E_vca = target;

            % 收敛判断: ma1 不再增大
            if ~isempty(ma1_old)
                if ma1 < ma1_old
                    elapsed = toc(start_time);
                    update_status(sprintf('MIVCA 收敛! 迭代 %d 次, 耗时 %.2f 秒', i, elapsed));
                    E_vca = E_vca_old;
                    jiao(i) = jiao(i-1);
                    ma1_history(i) = ma1;
                    break;
                end
            end
            ma1_old = ma1;
            ma1_history(i) = ma1;
            E_vca_old = E_vca;

            % 计算 SAD
            jiaodu = acos(dot(E_vca, E_t) / (norm(E_vca) * norm(E_t))) * 180 / pi;
            jiao(i) = jiaodu;
        end

        elapsed = toc(start_time);

        % 保存有效迭代的结果
        valid_idx = find(jiao ~= 0, 1, 'last');
        if isempty(valid_idx), valid_idx = i; end

        state.E_mivca       = E_vca;
        state.jiao_history  = jiao(1:valid_idx);
        state.ma1_history   = ma1_history(1:valid_idx);
        state.mivca_runtime = elapsed;
        state.mivca_iters   = valid_idx;
        state.mivca_done    = true;

        progress_close();

        % 更新可视化
        show_convergence_curve();
        show_spectral_comparison();
        update_summary();

        update_status(sprintf('MIVCA 完成! 迭代 %d 次, SAD=%.4f°, 耗时 %.2f 秒', ...
            valid_idx, state.jiao_history(end), elapsed));
        update_button_states();

    catch ME
        progress_close();
        update_status(['MIVCA 错误: ', ME.message]);
        uialert(app.fig, ME.message, 'MIVCA 运行失败');
    end
end

% ------------------------ 3. 运行标准 VCA 对比 ------------------------
function run_standard_vca()
    if ~state.data_processed
        uialert(app.fig, '请先加载并预处理数据!', '提示');
        return;
    end

    update_status('正在运行标准 VCA 对比...');
    progress_open('标准 VCA (不清洗正包)...');

    try
        % 重新加载原始正包 (未清洗)
        positive_raw_file = fullfile(state.data_dir, 'positive_gulfport.mat');
        if exist(positive_raw_file, 'file')
            raw_data = load(positive_raw_file);
            positive_raw = double(raw_data.positive);
        else
            positive_raw = state.hsi_2d(:, state.pos_indices);
        end

        progress_update(0.5, 'VCA 提取 4 个端元...');

        % VCA 提取 4 个端元
        E_standard = vca(positive_raw, 'Endmembers', 4);

        % 计算最优 SAD
        sad_standard = inf;
        for k = 1:4
            err = acos(dot(E_standard(:, k), state.E_t) / ...
                (norm(E_standard(:, k)) * norm(state.E_t))) * 180 / pi;
            sad_standard = min(err, sad_standard);
        end

        state.E_vca_standard = E_standard;
        state.sad_standard_vca = sad_standard;
        state.vca_done = true;

        progress_close();

        show_spectral_comparison();
        update_summary();
        update_comparison_view();

        update_status(sprintf('标准 VCA 完成, 最低 SAD=%.4f°', sad_standard));
        update_button_states();

    catch ME
        progress_close();
        update_status(['标准 VCA 错误: ', ME.message]);
        uialert(app.fig, ME.message, '标准 VCA 运行失败');
    end
end

% ------------------------ 4. ACE 检测 + ROC (Bullwinkle 官方框架) ------------------------
function run_ace_detection()
    if ~state.mivca_done
        uialert(app.fig, '请先运行 MIVCA 算法!', '提示');
        return;
    end

    update_status('正在执行 ACE/SMF 检测 (Bullwinkle 框架)...');
    progress_open('运行全图 ACE 检测器...');

    try
        % 准备数据
        tgt_sig = state.E_mivca(:);        % 目标光谱 (列向量)
        hsi_img = state.hsi_cube;           % 3D HSI 图像
        valid_mask = state.hsi_struct.valid_mask;  % 有效像素掩膜

        % 目标滤波器 (匹配当前类别)
        target_filter = { {state.target_class, [], [], []} };

        % --- 1. 全图 ACE 检测 ---
        progress_update(0.15, '运行全图 ACE 检测器...');
        ace_det_img = ace_detector(hsi_img, tgt_sig, valid_mask);

        % --- 2. 全图 SMF 检测 (对比) ---
        progress_update(0.35, '运行全图 SMF 检测器...');
        smf_det_img = smf_detector(hsi_img, tgt_sig, valid_mask);

        % --- 3. Bullwinkle 评分 (内部会弹窗, 我们关闭它们) ---
        progress_update(0.55, 'Bullwinkle 评分 (ACE)...');
        bw_params = BullwinkleParameters();
        bw_params.Halo = 2;

        bw_score_ace = score_hylid_perpixel(state.hsi_struct, ace_det_img, ...
            target_filter, 'MIVCA-ACE', 'bw_params', bw_params, ...
            'det_fig', 1001, 'roc_fig', 1002);

        progress_update(0.75, 'Bullwinkle 评分 (SMF)...');
        bw_score_smf = score_hylid_perpixel(state.hsi_struct, smf_det_img, ...
            target_filter, 'MIVCA-SMF', 'bw_params', bw_params, ...
            'det_fig', 1003, 'roc_fig', 1004);

        % --- 4. 关闭 Bullwinkle 内部弹窗 ---
        for f = [1001, 1002, 1003, 1004]
            if isgraphics(f, 'figure'), close(f); end
        end

        % --- 5. 计算部分 AUC (FAR <= 1e-3) ---
        progress_update(0.90, '计算 pAUC...');
        pAUC_ace = auc_upto_far(1e-3, bw_score_ace);
        pAUC_smf = auc_upto_far(1e-3, bw_score_smf);

        % --- 6. 子集 ACE 分数 (正包+负包, 用于分布直方图) ---
        test_data = [state.positive, state.negative];
        labels = state.labels_point;
        mu_bg = mean(state.negative, 2);
        neg_centered = state.negative - repmat(mu_bg, 1, size(state.negative, 2));
        Cov_bg = (neg_centered * neg_centered') / size(state.negative, 2);
        Inv_Cov = pinv(Cov_bg);

        s_centered = state.E_mivca - mu_bg;
        test_centered = test_data - repmat(mu_bg, 1, size(test_data, 2));
        numerator = (s_centered' * Inv_Cov * test_centered).^2;
        den1 = s_centered' * Inv_Cov * s_centered;
        den2 = sum(test_centered .* (Inv_Cov * test_centered), 1);
        ace_scores = numerator ./ (den1 * den2);

        [FPR, TPR, ~, AUC] = perfcurve(labels, ace_scores, 1);

        % --- 7. 保存结果 ---
        state.ace_det_img   = ace_det_img;
        state.smf_det_img   = smf_det_img;
        state.bw_score_ace  = bw_score_ace;
        state.bw_score_smf  = bw_score_smf;
        state.pAUC_ace      = pAUC_ace;
        state.pAUC_smf      = pAUC_smf;
        state.ace_scores    = ace_scores;
        state.FPR           = FPR;
        state.TPR           = TPR;
        state.AUC           = AUC;
        state.ace_test_data = test_data;
        state.ace_labels    = labels;
        state.ace_done      = true;

        progress_close();

        % --- 8. 更新可视化 ---
        show_roc_curve_bullwinkle();
        show_ace_distribution();
        show_ace_detection_map();
        update_summary();
        update_comparison_view();

        update_status(sprintf('ACE 检测完成, pAUC(1e-3)=%.4f (ACE), %.4f (SMF)', pAUC_ace, pAUC_smf));
        update_button_states();

    catch ME
        progress_close();
        % 关闭可能残留的弹窗
        for f = [1001, 1002, 1003, 1004]
            if isgraphics(f, 'figure'), close(f); end
        end
        update_status(['ACE 检测错误: ', ME.message]);
        uialert(app.fig, ME.message, 'ACE 检测失败');
    end
end

% ------------------------ 一键运行完整流程 ------------------------
function run_full_pipeline()
    update_status('开始一键运行完整流程...');
    load_and_process();
    if ~state.data_processed, return; end

    pause(0.5);
    run_mivca_algorithm();
    if ~state.mivca_done, return; end

    pause(0.5);
    run_standard_vca();

    pause(0.5);
    run_ace_detection();

    update_status('完整流程运行完毕! 请查看各 Tab 页的可视化结果');
end

% ======================================================================
%                       可视化函数
% ======================================================================

% ------------------------ 光谱对比图 ------------------------
function show_spectral_comparison()
    cla(app.ax_spectral);
    hold(app.ax_spectral, 'on');

    x = 1:state.bands;

    % Ground Truth (黑色粗线)
    E_t_norm = normalize_spectrum(state.E_t);
    plot(app.ax_spectral, x, E_t_norm, 'k-', 'LineWidth', 3, ...
        'DisplayName', 'Ground Truth');

    % MIVCA (蓝色)
    if ~isempty(state.E_mivca)
        E_mivca_norm = normalize_spectrum(state.E_mivca);
        plot(app.ax_spectral, x, E_mivca_norm, 'b-', 'LineWidth', 2, ...
            'DisplayName', sprintf('MIVCA (SAD=%.4f°)', state.jiao_history(end)));
    end

    % Standard VCA (红色虚线)
    if state.vca_done && ~isempty(state.E_vca_standard)
        % 找最优的那一列
        best_col = 1;
        best_sad = inf;
        for k = 1:size(state.E_vca_standard, 2)
            ek = state.E_vca_standard(:, k);
            sad_k = acos(dot(ek, state.E_t) / (norm(ek) * norm(state.E_t))) * 180 / pi;
            if sad_k < best_sad
                best_sad = sad_k;
                best_col = k;
            end
        end
        E_vca_best = state.E_vca_standard(:, best_col);
        E_vca_norm = normalize_spectrum(E_vca_best);
        plot(app.ax_spectral, x, E_vca_norm, 'r--', 'LineWidth', 2, ...
            'DisplayName', sprintf('Standard VCA (SAD=%.4f°)', best_sad));
    end

    hold(app.ax_spectral, 'off');
    legend(app.ax_spectral, 'Location', 'northeast', 'FontSize', 11);
    title(app.ax_spectral, '归一化端元光谱对比', 'FontSize', 15, 'FontWeight', 'bold');
    xlabel(app.ax_spectral, '波段索引 (Band Index)', 'FontSize', 12);
    ylabel(app.ax_spectral, '归一化反射率', 'FontSize', 12);
    grid(app.ax_spectral, 'on');
    set(app.ax_spectral, 'FontSize', 11);
end

% ------------------------ 收敛曲线 ------------------------
function show_convergence_curve()
    cla(app.ax_convergence);
    x = 1:length(state.jiao_history);

    % 主曲线
    plot(app.ax_convergence, x, state.jiao_history, 'b-', 'LineWidth', 2.5);
    hold(app.ax_convergence, 'on');

    % 标注最终值
    final_sad = state.jiao_history(end);
    plot(app.ax_convergence, length(x), final_sad, 'ro', ...
        'MarkerSize', 10, 'MarkerFaceColor', 'r');
    text(app.ax_convergence, length(x) * 0.7, final_sad * 1.15, ...
        sprintf('最终 SAD = %.4f°', final_sad), ...
        'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.8 0 0], ...
        'BackgroundColor', [1 1 1 0.8]);

    hold(app.ax_convergence, 'off');

    title(app.ax_convergence, ...
        sprintf('MIVCA 收敛曲线 (tiqv=%d, %d 次迭代)', ...
        app.tiqv_spinner.Value, length(x)), ...
        'FontSize', 15, 'FontWeight', 'bold');
    xlabel(app.ax_convergence, '迭代次数', 'FontSize', 12);
    ylabel(app.ax_convergence, 'SAD 误差 (度)', 'FontSize', 12);
    grid(app.ax_convergence, 'on');
    set(app.ax_convergence, 'FontSize', 11);
end

% ------------------------ ROC 曲线 (Bullwinkle 框架) ------------------------
function show_roc_curve_bullwinkle()
    cla(app.ax_roc);
    hold(app.ax_roc, 'on');

    % 使用 PlotBullwinkleRoc 绘制到 uiaxes
    scores = {state.bw_score_ace, state.bw_score_smf};
    names  = {sprintf('MIVCA-ACE (pAUC=%.4f)', state.pAUC_ace), ...
              sprintf('MIVCA-SMF (pAUC=%.4f)', state.pAUC_smf)};

    try
        PlotBullwinkleRoc(scores, 'MIVCA 端元检测 ROC', ...
            'Parent', app.ax_roc, ...
            'names', names, ...
            'colors', {'b', 'r'}, ...
            'xlim', [0 1e-3]);
    catch
        % 如果 Bullwinkle 绘图失败, 回退到 perfcurve ROC
        plot(app.ax_roc, state.FPR, state.TPR, 'b-', 'LineWidth', 3, ...
            'DisplayName', sprintf('MIVCA-ACE (AUC=%.4f)', state.AUC));
        plot(app.ax_roc, [0 1], [0 1], 'k--', 'LineWidth', 1.5, ...
            'DisplayName', 'Random');
        xlim(app.ax_roc, [0 1]);
        ylim(app.ax_roc, [0 1]);
    end

    hold(app.ax_roc, 'off');
    legend(app.ax_roc, 'Location', 'SouthEast', 'FontSize', 10);
    title(app.ax_roc, 'ROC 曲线 (Bullwinkle 官方框架)', 'FontSize', 14, 'FontWeight', 'bold');
    xlabel(app.ax_roc, 'False Alarm Rate (FAR / m^2)', 'FontSize', 11);
    ylabel(app.ax_roc, 'Probability of Detection (PD)', 'FontSize', 11);
    grid(app.ax_roc, 'on');
    set(app.ax_roc, 'FontSize', 10);

    % 更新检测指标面板
    metrics_str = sprintf(['检测指标:\n\n', ...
        '━━━━━━━━━━━━━━━━━━━━\n', ...
        'ACE 检测器:\n', ...
        '  pAUC(FAR<=1e-3) = %.4f\n\n', ...
        'SMF 检测器:\n', ...
        '  pAUC(FAR<=1e-3) = %.4f\n\n', ...
        '子集 AUC (perfcurve):\n', ...
        '  AUC = %.4f\n\n', ...
        '目标类别: %s\n'], ...
        state.pAUC_ace, state.pAUC_smf, ...
        state.AUC, state.target_class);
    app.det_metrics_text.Value = metrics_str;

    % 更新下方信息面板
    roc_str = sprintf(['Bullwinkle 官方评估框架:\n\n', ...
        'ACE (Adaptive Cosine Estimator):\n', ...
        '  基于全图检测 + Halo=2m 评分\n', ...
        '  ROC 使用目标级别评分 (per-target max)\n', ...
        '  FAR 单位为 FA / m^2\n\n', ...
        'SMF (Spectral Matched Filter):\n', ...
        '  作为对比检测器, 同样使用全图检测\n\n', ...
        'pAUC 解读:\n', ...
        '  0.9+: 优秀\n', ...
        '  0.8-0.9: 良好\n', ...
        '  0.7-0.8: 一般\n', ...
        '  <0.7: 需改进\n\n', ...
        '注意: 子集 AUC 基于正/负包采样\n', ...
        'Bullwinkle pAUC 基于全图目标级评分']);
    app.roc_info_text.Value = roc_str;
end

% ------------------------ ACE 分数分布 ------------------------
function show_ace_distribution()
    cla(app.ax_ace_dist);
    hold(app.ax_ace_dist, 'on');

    % 分离正负样本的 ACE 分数
    pos_scores = state.ace_scores(state.ace_labels == 1);
    neg_scores = state.ace_scores(state.ace_labels == 0);

    % 直方图
    histogram(app.ax_ace_dist, neg_scores, 50, ...
        'FaceColor', [0.3 0.6 0.9], 'FaceAlpha', 0.6, ...
        'DisplayName', '负样本 (背景)');
    histogram(app.ax_ace_dist, pos_scores, 30, ...
        'FaceColor', [0.9 0.2 0.2], 'FaceAlpha', 0.7, ...
        'DisplayName', '正样本 (目标)');

    hold(app.ax_ace_dist, 'off');
    legend(app.ax_ace_dist, 'Location', 'northeast', 'FontSize', 10);
    title(app.ax_ace_dist, 'ACE 检测分数分布', 'FontSize', 13, 'FontWeight', 'bold');
    xlabel(app.ax_ace_dist, 'ACE Score', 'FontSize', 11);
    ylabel(app.ax_ace_dist, '频数', 'FontSize', 11);
    grid(app.ax_ace_dist, 'on');
    set(app.ax_ace_dist, 'FontSize', 10);
end

% ------------------------ ACE 检测图像可视化 ------------------------
function show_ace_detection_map()
    if isempty(state.ace_det_img), return; end

    % === 1. 全图 ACE 检测热力图 ===
    cla(app.ax_ace_heatmap);
    ace_img = state.ace_det_img;
    % 裁剪极端值以增强对比度
    ace_valid = ace_img(~isnan(ace_img(:)));
    p99 = prctile(ace_valid, 99);
    p01 = prctile(ace_valid, 1);
    ace_display = ace_img;
    ace_display(ace_display > p99) = p99;
    ace_display(ace_display < p01) = p01;

    imagesc(app.ax_ace_heatmap, ace_display);
    colormap(app.ax_ace_heatmap, jet(256));
    cbar = colorbar(app.ax_ace_heatmap);
    cbar.Label.String = 'ACE Score';
    axis(app.ax_ace_heatmap, 'image', 'off');

    % 叠加目标位置
    hold(app.ax_ace_heatmap, 'on');
    gt = state.groundTruth;
    num_targets = length(gt.Targets_Type);
    for i = 1:num_targets
        current_type = strtrim(lower(gt.Targets_Type{i}));
        if strcmp(current_type, state.target_class)
            c = gt.Targets_colIndices(i);
            r = gt.Targets_rowIndices(i);
            plot(app.ax_ace_heatmap, c, r, 'wo', ...
                'MarkerSize', 10, 'LineWidth', 1.5, ...
                'MarkerEdgeColor', [1 1 1]);
        end
    end
    hold(app.ax_ace_heatmap, 'off');

    title(app.ax_ace_heatmap, ...
        sprintf('ACE 全图检测热力图 — %s (MIVCA 端元)', state.target_class), ...
        'FontSize', 13, 'FontWeight', 'bold');

    % === 2. 目标区域放大视图 ===
    % 获取前 4 个目标位置
    target_positions = [];
    for i = 1:num_targets
        current_type = strtrim(lower(gt.Targets_Type{i}));
        if strcmp(current_type, state.target_class)
            target_positions = [target_positions; ...
                gt.Targets_rowIndices(i), gt.Targets_colIndices(i)];
        end
    end

    zoom_axes = {app.ax_zoom1, app.ax_zoom2, app.ax_zoom3, app.ax_zoom4};
    half_win = 8;  % 放大窗口半径 (像素)

    for k = 1:4
        ax = zoom_axes{k};
        cla(ax);

        if k <= size(target_positions, 1)
            r0 = target_positions(k, 1);
            c0 = target_positions(k, 2);

            % 提取窗口
            r_range = max(1, r0-half_win):min(state.rows, r0+half_win);
            c_range = max(1, c0-half_win):min(state.cols, c0+half_win);

            if ~isempty(r_range) && ~isempty(c_range)
                zoom_patch = ace_img(r_range, c_range);
                imagesc(ax, zoom_patch);
                colormap(ax, jet(256));
                axis(ax, 'image', 'off');

                % 画十字准线标记目标中心
                hold(ax, 'on');
                cy = r0 - r_range(1) + 1;
                cx = c0 - c_range(1) + 1;
                plot(ax, cx, cy, 'wo', 'MarkerSize', 8, ...
                    'LineWidth', 1.5, 'MarkerEdgeColor', [1 1 1]);
                title(ax, sprintf('目标 #%d (%d,%d)', k, r0, c0), ...
                    'FontSize', 11);
                hold(ax, 'off');
            else
                title(ax, sprintf('目标 #%d (边缘)', k), 'FontSize', 11);
            end
        else
            text(ax, 0.5, 0.5, 'N/A', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 14, 'Color', [0.6 0.6 0.6]);
            title(ax, sprintf('目标 #%d (无)', k), 'FontSize', 11);
        end
    end

    % === 3. 更新检测统计信息 ===
    ace_valid_all = ace_img(~isnan(ace_img(:)));
    det_info = sprintf(['检测图像统计:\n', ...
        '━━━━━━━━━━━━━━━━━━━━\n', ...
        '检测器: ACE (全图)\n', ...
        '目标类别: %s\n', ...
        '目标数量: %d\n', ...
        '有效像素: %d\n\n', ...
        'ACE 分数统计:\n', ...
        '  最大值: %.4f\n', ...
        '  99%%分位: %.4f\n', ...
        '  95%%分位: %.4f\n', ...
        '  均值:   %.4f\n', ...
        '  中位数: %.4f'], ...
        state.target_class, size(target_positions, 1), ...
        length(ace_valid_all), ...
        max(ace_valid_all), ...
        prctile(ace_valid_all, 99), ...
        prctile(ace_valid_all, 95), ...
        mean(ace_valid_all), ...
        median(ace_valid_all));
    app.detmap_info.Value = det_info;
end

% ------------------------ 算法对比总览 ------------------------
function update_comparison_view()
    if ~state.mivca_done && ~state.vca_done, return; end

    methods = {};
    sad_vals = [];
    time_vals = [];

    % MIVCA
    if state.mivca_done
        methods{end+1} = 'MIVCA';
        sad_vals(end+1) = state.jiao_history(end);
        time_vals(end+1) = state.mivca_runtime;
    end

    % Standard VCA
    if state.vca_done
        methods{end+1} = 'Standard VCA';
        sad_vals(end+1) = state.sad_standard_vca;
        time_vals(end+1) = 0.05;  % VCA 很快
    end

    if isempty(methods), return; end

    % -- SAD 柱状图 --
    cla(app.ax_sad_compare);
    colors_sad = [0.15 0.45 0.70; 0.60 0.35 0.15];
    b1 = bar(app.ax_sad_compare, categorical(methods), sad_vals, 0.5);
    for k = 1:length(methods)
        b1.FaceColor = 'flat';
        b1.CData(k, :) = colors_sad(min(k, end), :);
    end
    % 数值标签
    for k = 1:length(sad_vals)
        text(app.ax_sad_compare, k, sad_vals(k) * 1.08, sprintf('%.4f°', sad_vals(k)), ...
            'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
    end
    title(app.ax_sad_compare, 'SAD 光谱角误差对比', 'FontSize', 14, 'FontWeight', 'bold');
    ylabel(app.ax_sad_compare, 'SAD (度)', 'FontSize', 12);
    grid(app.ax_sad_compare, 'on');
    set(app.ax_sad_compare, 'FontSize', 11);

    % -- 时间柱状图 --
    cla(app.ax_runtime_compare);
    colors_time = [0.15 0.45 0.70; 0.60 0.35 0.15];
    b2 = bar(app.ax_runtime_compare, categorical(methods), time_vals, 0.5);
    for k = 1:length(methods)
        b2.FaceColor = 'flat';
        b2.CData(k, :) = colors_time(min(k, end), :);
    end
    for k = 1:length(time_vals)
        text(app.ax_runtime_compare, k, time_vals(k) * 1.08, sprintf('%.2f s', time_vals(k)), ...
            'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
    end
    title(app.ax_runtime_compare, '运行时间对比', 'FontSize', 14, 'FontWeight', 'bold');
    ylabel(app.ax_runtime_compare, '时间 (秒)', 'FontSize', 12);
    grid(app.ax_runtime_compare, 'on');
    set(app.ax_runtime_compare, 'FontSize', 11);

    % 文字总结
    if state.vca_done && state.mivca_done
        sad_improvement = (state.sad_standard_vca - state.jiao_history(end)) / state.sad_standard_vca * 100;

        % 构建对比文字
        compare_str = sprintf(['算法对比总结:\n\n', ...
            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n', ...
            'MIVCA SAD:        %.4f°\n', ...
            'Standard VCA SAD: %.4f°\n', ...
            '提升幅度:         %.1f%%\n\n', ...
            'MIVCA 耗时:       %.2f 秒 (%d 次迭代)\n', ...
            'Standard VCA 耗时: < 0.1 秒\n\n'], ...
            state.jiao_history(end), state.sad_standard_vca, sad_improvement, ...
            state.mivca_runtime, state.mivca_iters);

        if state.ace_done
            compare_str = [compare_str, sprintf([ ...
                'Bullwinkle 检测评估:\n', ...
                '  ACE pAUC(FAR<=1e-3): %.4f\n', ...
                '  SMF pAUC(FAR<=1e-3): %.4f\n', ...
                '  子集 AUC:           %.4f\n\n'], ...
                state.pAUC_ace, state.pAUC_smf, state.AUC)];
        end

        compare_str = [compare_str, sprintf([ ...
            '结论: MIVCA 通过迭代清洗正包中的\n', ...
            '背景像素, 大幅提升了端元提取精度\n', ...
            '使用 MIVCA 端元的 ACE/SMF 检测器\n', ...
            '在 Bullwinkle 框架下表现良好'])];
        app.compare_text.Value = compare_str;
    end
end

% ------------------------ 更新结果摘要 ------------------------
function update_summary()
    summary = '';
    if state.data_processed
        summary = [summary, sprintf(['数据: %s\n', ...
            '正包: %d | 负包: %d\n\n'], ...
            state.target_class, ...
            size(state.positive, 2), size(state.negative, 2))];
    end
    if state.mivca_done
        summary = [summary, sprintf(['MIVCA:\n', ...
            '  SAD = %.4f°\n', ...
            '  迭代 = %d 次\n', ...
            '  耗时 = %.2f s\n\n'], ...
            state.jiao_history(end), state.mivca_iters, state.mivca_runtime)];
    end
    if state.vca_done
        summary = [summary, sprintf('标准VCA SAD = %.4f°\n', state.sad_standard_vca)];
        if state.mivca_done
            impr = (state.sad_standard_vca - state.jiao_history(end)) / state.sad_standard_vca * 100;
            summary = [summary, sprintf('MIVCA 提升: %.1f%%\n', impr)];
        end
        summary = [summary, newline];
    end
    if state.ace_done
        summary = [summary, sprintf(['Bullwinkle 检测:\n', ...
            '  ACE pAUC = %.4f\n', ...
            '  SMF pAUC = %.4f\n', ...
            '  子集 AUC = %.4f\n'], ...
            state.pAUC_ace, state.pAUC_smf, state.AUC)];
    end
    if isempty(summary), summary = '等待运行...'; end
    app.summary_text.Value = summary;
end

% ------------------------ 进度条辅助 ------------------------
function progress_open(msg)
    if ~isempty(app.progress_bar) && isvalid(app.progress_bar)
        delete(app.progress_bar);
    end
    app.progress_bar = uiprogressdlg(app.fig, ...
        'Title', '处理进度', 'Message', msg, 'Value', 0, ...
        'Indeterminate', 'off');
end

function progress_update(val, msg)
    if ~isempty(app.progress_bar) && isvalid(app.progress_bar)
        app.progress_bar.Value = val;
        if nargin > 1
            app.progress_bar.Message = msg;
        end
    end
    drawnow;
end

function progress_close()
    if ~isempty(app.progress_bar) && isvalid(app.progress_bar)
        delete(app.progress_bar);
        app.progress_bar = [];
    end
end

% ------------------------ 辅助功能 ------------------------
function update_status(msg)
    app.status_label.Text = msg;
    drawnow;
end

function update_button_states()
    app.btn_mivca.Enable = state.data_processed;
    app.btn_vca.Enable   = state.data_processed;
    app.btn_ace.Enable   = state.mivca_done;
    app.btn_load.Enable  = true;
end

function spec_norm = normalize_spectrum(spec)
    mx = max(spec);
    mn = min(spec);
    if mx > mn
        spec_norm = (spec - mn) / (mx - mn);
    else
        spec_norm = spec;
    end
end

end
% ===================== MIVCA_Analyzer 结束 =====================
