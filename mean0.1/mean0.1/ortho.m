function [indice,ma1] = ortho(tiqvduan,R)

y=R;
[h,w]=size(y);
duan=y(:,w-(tiqvduan-1):w);
shimi=[];
for i=1:tiqvduan
if i==1
shimo=repmat(sqrt(sum(duan(:,i).*duan(:,i),1)),[h 1]);
first_duan=duan(:,i)./shimo;
shimi=[shimi,first_duan];
else
tou=duan(:,i)'*shimi   ;
k=repmat(tou,[h 1]) ;
alltou=k.*shimi;
alltou=sum(alltou,2);
first_duan=duan(:,i)-alltou;
shimo=repmat(sqrt(sum(first_duan.*first_duan,1)),[h 1]);
first_duan=first_duan./shimo;
mo=(first_duan'*shimi);
k=find(mo>0.0001);
shimi=[shimi,first_duan];
end
end
%上述内容是创建背景空间，每一个基都是一个背景方向
y=y(:,1:w-tiqvduan);
xishu=y'*shimi;
allmo=[];
[h,w]=size(y);
%这里求的是正包的所有例子在施密特正交基的坐标
%for i=1:w
%allmo=[allmo,y(:,i)-sum(repmat(xishu(i,:),[h,1]).*shimo,2)]
%end
allmo1=xishu*shimi';
allmo=y-allmo1';
mo=sqrt(sum(allmo.*allmo,1));

ma1=min(mo)
ma2=max(mo);
indice = find(mo<(ma1+(ma2-ma1)/5));


return;

