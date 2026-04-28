clc;clear all;close all;

load('../../mean0.1/mean0.1')
positive=[]
negative=[]
for i=1:15
    positive=[positive,cell2mat(dataBagged.dataBags(i))']
end
for i=16:20
        negative=[negative,cell2mat(dataBagged.dataBags(i))']
end
