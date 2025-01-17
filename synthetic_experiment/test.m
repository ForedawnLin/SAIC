clc 
clear all

%%%%%%% synthetic data generation %%%%%%%
data_gen=relation();

%%% randomly generate observable parameters %%%
randseed ;
n_sample=1000;
H2O=rand(n_sample,1);
T=rand(n_sample,1)*10/3+10;
C_N2C=rand(n_sample,1)/10;
C_N2A=rand(n_sample,1)/10+1.05;
P_H2=rand(n_sample,1)*1000+300;
P_air=rand(n_sample,1)*1000+500;

trainNum=ceil(0.8*n_sample); 

H2O_train=H2O(1:trainNum);
T_train=T(1:trainNum);
C_N2C_train=C_N2C(1:trainNum);
C_N2A_train=C_N2A(1:trainNum);
P_H2_train=P_H2(1:trainNum);
P_air_train=P_air(1:trainNum);


%n_sample=800;



%% generat N2 result %%
for i=1:trainNum
N2_train(i)=data_gen.data_generation_static(H2O_train(i),T_train(i),C_N2C_train(i),C_N2A_train(i),P_H2_train(i),P_air_train(i)); 
end 
N2_train=N2_train';
obs_values=[H2O_train T_train C_N2C_train C_N2A_train P_H2_train P_air_train N2_train]' ;  




%%% create BN %%% 
%%% A: H20 B:T C:CN2C D:CN2A E:PressureC  F:PressureA
A=1;B=2;C=3;D=4;E=5;F=6;
G=7;H=8;I=9;J=10;K=11;
n_node=11;
ns=ones(1,n_node); 


dag=zeros(n_node); 

dag(A,G)=1;
dag(B,G)=1; 
dag(C,H)=1;
dag(D,H)=1;
dag(E,I)=1;
dag(B,I)=1;
dag(F,J)=1;
dag(B,J)=1;
dag(G,K)=1;
dag(H,K)=1;
dag(I,K)=1;
dag(J,K)=1;

bnet=mk_bnet(dag,ns,'discrete',[],'observed',[A B C D E F K]); 
seed=0; 
rand('state',seed); 

bnet.CPD{A}=root_CPD(bnet,A);
bnet.CPD{B}=root_CPD(bnet,B);
bnet.CPD{C}=root_CPD(bnet,C);
bnet.CPD{D}=root_CPD(bnet,D);
bnet.CPD{E}=root_CPD(bnet,E);
bnet.CPD{F}=root_CPD(bnet,F);
bnet.CPD{G}=gaussian_CPD(bnet,G,'mean',[0.5],'cov',[0.01]);
bnet.CPD{H}=gaussian_CPD(bnet,H,'mean',[0.5],'cov',[0.01]);
bnet.CPD{I}=gaussian_CPD(bnet,I,'mean',[0.5],'cov',[0.01]);
bnet.CPD{J}=gaussian_CPD(bnet,J,'mean',[0.5],'cov',[0.01]);
bnet.CPD{K}=gaussian_CPD(bnet,K,'mean',[0.5],'cov',[0.01]);
% 
% 
% 
% 
% %%% create samples for BN %%%
samples=cell(n_node,trainNum); 

for i=1:trainNum
    samples([1 2 3 4 5 6 11],i)=num2cell(obs_values(:,i));
    samples{7 ,i}=[];
    samples{8 ,i}=[];
    samples{9 ,i}=[];
    samples{10 ,i}=[];
end 


engine=jtree_inf_engine(bnet); 
max_iter=1000; 
[bnet2,LLtrace]=learn_params_em(engine,samples,max_iter);
%plot(LLtrace,'x-');






%%%% Infernece %%%% 

engine=jtree_inf_engine(bnet2); 
evidence=cell(1,n_node); 



H2O_test=H2O(n_sample-trainNum:end);
T_test=T(n_sample-trainNum:end);
C_N2C_test=C_N2C(n_sample-trainNum:end);
C_N2A_test=C_N2A(n_sample-trainNum:end);
P_H2_test=P_H2(n_sample-trainNum:end);
P_air_test=P_air(n_sample-trainNum:end);

testNum=n_sample-trainNum;


for i=1:testNum
evidence{A}=H2O_test(i);
evidence{B}=T_test(i);
evidence{C}=C_N2C_test(i);
evidence{D}=C_N2A_test(i);
evidence{E}=P_H2_test(i);
evidence{F}=P_air_test(i);

[engine,ll]=enter_evidence(engine,evidence); 
marg=marginal_nodes(engine,K);
y_pred(i)=marg.mu;
N2_test(i)=data_gen.data_generation_static(H2O_test(i),T_test(i),C_N2C_test(i),C_N2A_test(i),P_H2_test(i),P_air_test(i)); 
end 


figure (2)
hold on 
plot(1:testNum,N2_test,'b'); 
plot(1:testNum,y_pred,'r');
title("Inlcude causality") 
xlabel('sequence number') 
ylabel('value') 
legend('Ground truth','Prediction')
hold off 
MAE=sum(abs(y_pred-N2_test))/testNum;

%%% ends %%%

