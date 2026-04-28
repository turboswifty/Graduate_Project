clc;clear all;close all;


load('positive.mat')
load('negative')
tiqv=3
load('../E_t')


dist=zeros(1,1000)
jiao=zeros(1,1000)
for i=1:1000
background=vca(negative,'Endmembers',tiqv);%X=[特征维度，像素数量]
[index,mi]=ortho(tiqv,[positive,background]);
negative=[negative,positive(1:211,index)]
positive(:,index)=[]
[w,h]=size(positive)
[w1,h1]=size(index)


if h==h1
break
elseif h<8
    break
end



target=vca(positive,'Endmembers',1);%X=[特征维度，像素数量]
E_vca=target
jiaodu=acos(dot(E_vca,E_t)/(norm(E_vca)*norm(E_t)))*180/pi
jiao(i)=jiaodu
z =(E_vca-E_t).*(E_vca-E_t);
jiaodu1 = sqrt(sum(z));
dist(i)=jiaodu1


end