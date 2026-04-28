clc;clear all;close all;
rng(69);


load('positive_gulfport3.mat')
load('negative_gulfport3.mat')
load('E_t_gulfport3.mat')
addpath '/Users/jihao/毕设相关/mean0.1/mean0.1'
%tiqv=3;

% ==========================================
% 【核心修复】：强制转换为 double (双精度浮点数)
positive = double(positive);
negative = double(negative);
E_t = double(E_t); % 顺手把目标真实端元也转一下防患于未然
% ==========================================


tiqv = 15;



dist=zeros(1,1000);
jiao=zeros(1,1000);
%加一个E_vca_old
E_vca_old = [];
ma1_old = [];

start_time = tic;

for i=1:1000
    background=vca(negative,'Endmembers',tiqv);%X=[特征维度，像素数量]
    [index,ma1]=ortho(tiqv,[positive,background]);
    negative=[negative,positive(1:72,index)];
    positive(:,index)=[];
    [w,h]=size(positive);
    
    %[w1,h1]=size(index)
    
    
    % if h==h1
    % break
    % elseif h<8
    %     break
    % end
    if h<10
        disp(['正包数量不足8个，提前终止于第 ', num2str(i), ' 次迭代']);
        h
        break;
    end
    
    
    
    target=vca(positive,'Endmembers',1);%X=[特征维度，像素数量]
    %加入一个判断逻辑，判断正包算出来的端元要是没咋变，那么就停止迭代
    
    E_vca=target;

    %新增一个基于SAD的收敛判断逻辑
    % if ~isempty(E_vca_old)
    %     sad_diff = acos(dot(E_vca, E_vca_old)/(norm(E_vca)*norm(E_vca_old))) * 180/pi;
    % 
    %     if sad_diff < 1e-3
    %         disp(['算法达到稳定收敛！迭代停止于第 ', num2str(i), ' 次， 两次端元SAD差值为', num2str(sad_diff)]);
    %         break;
    %     end
    % end
    if ~isempty(ma1_old)
        if ma1 < ma1_old
            disp(['正包和背景有很好区分度了，可以停止迭代了。迭代停止于 ', num2str(i), ' 次'])
            elapsed = toc(start_time)
            fprintf("耗时为: %.2f 秒", elapsed)
            E_vca = E_vca_old;
            break;
        end
    end
    ma1_old = ma1 

    E_vca_old = E_vca;

    jiaodu=acos(dot(E_vca,E_t)/(norm(E_vca)*norm(E_t)))*180/pi
    jiao(i)=jiaodu;
    z =(E_vca-E_t).*(E_vca-E_t);
    jiaodu1 = sqrt(sum(z));
    dist(i)=jiaodu1;


end

save('end04_gulfport3_mivca.mat', 'E_vca');
disp('最终目标端元已成功保存至 end04.mat');

% --- 把这几行加到代码最后 ---
figure('Name', 'Convergence Curve'); % 新建一个窗口
plot(jiao(1:i-1)); % 画出误差曲线（只画实际跑的那几步）
title('算法收敛曲线 (MIVCA Convergence)');
xlabel('迭代次数 (Iterations)');
ylabel('角度误差 (SAD Error)');
grid on; % 加网格线好看点










% ================= 极简对比实验：Standard VCA =================
% 重新加载最原始的未被清洗的正包数据
load('/Users/jihao/毕设相关/HyperspectralAnalysisIntroduction-0.3/positive_gulfport.mat');
positive = double(positive);

% 直接对含有大量背景干扰的原始正包提取 1 个目标端元
E_standard_vca = vca(positive, 'Endmembers', 4); 

% 计算传统 VCA 提取结果与真实标签的角度误差
sad_standard = [];
for i = 1:4
    err = acos(dot(E_standard_vca(:, i), E_t) / (norm(E_standard_vca(:, i)) * norm(E_t))) * 180/pi;
    if i == 1
        sad_standard = err;
    end
    sad_standard = min(err, sad_standard);
end

disp(['我的 MIVCA 最终角度误差为: ', num2str(jiaodu)]);
disp(['传统不清洗的 VCA 角度误差为: ', num2str(sad_standard)]);
% ================================================================