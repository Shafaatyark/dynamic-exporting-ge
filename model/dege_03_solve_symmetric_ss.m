function [F,tau,Lbar,PC,FH,FL,F0,intkapH,intkapL,intkap0,Ne,Nx,N0,NL,W,Lc,Chat,PChat,K,I,PxC,PxI,PxM,PI,PM,R,Lp,Lp_alt,M,Cd,Id,Md,Cx,Ix,Mx,pidbar,pixbar,Pi,T,dVH,Vd1,Vx0,MC,psi,frisch,YN,IMN] = dege_03_solve_symmetric_ss(y,target,num_c,dynamic)
%Solves the symmetric steady state (all countries identical)
%SS vars: kap, L, N, C, Kx, Kd, Pd
global bet del sig th gam v alpm ns tauij alpc bk ttL ttK sI revsub
% global mu alp fe f0 f1 z xic xix xim
tau = 1.04;
Lbar = target.Lbar;

if revsub==1
    s_sub = 1/(th-1);
else
    s_sub = 0;
end

kap0 = exp(y(1));
L = exp(y(2));
N = exp(y(3));
C = exp(y(4));
Kx = exp(y(5));
Kd = exp(y(6));
Pd = exp(y(7));
mu = exp(y(8));
alp = exp(y(9));
fe = exp(y(10));
f0 = exp(y(11));
f1 = exp(y(12));
z = exp(y(13));
xicH = exp(y(14));
xixH = exp(y(15));
ximH = exp(y(16));
xiLH = exp(y(17));
kapH = exp(y(18));
kapL =exp(y(19));
NH = exp(y(20));
dVL = exp(y(21));
rho = exp(y(22));

% xicL = xiLH*(xicH-1)+1;
% xixL = xiLH*(xixH-1)+1;
% ximL = xiLH*(ximH-1)+1;


PC = 1;

%APY Distribution
% F1 = (kap./(f1.*v)).^(1./(v-1));
% F0 = (kap./(f0.*v)).^(1./(v-1));
% intkap1 = (kap./v).^(v./(v-1)).*f1.^(1./(1-v));
% intkap0 = (kap./v).^(v./(v-1)).*f0.^(1./(1-v));
% Generalized Pareto Distribution
FH = 1 - (1+v*kapH/f1)^(-1/v);
FL = 1 - (1+v*kapL/f1)^(-1/v);
F0 = 1 - (1+v*kap0/f0)^(-1/v);
intkapH = f1/(1-v)*(1-(1+v*kapH/f1)^(-1/v)*(1+kapH/f1));
intkapL = f1/(1-v)*(1-(1+v*kapL/f1)^(-1/v)*(1+kapL/f1));
intkap0 = f0/(1-v)*(1-(1+v*kap0/f0)^(-1/v)*(1+kap0/f0));
xicL = xiLH*xicH;
xixL = xiLH*xixH;
ximL = xiLH*ximH;


Ne = (1-ns)*N/ns;
NL = ns*(1-rho)*NH*FH/(1-ns*rho*FL);
Nx = NH+NL;
N0 = N-Nx;
chid = N;
%     xicL = (xiLH*(xicH*(NH./N)^(1/(1-th))*tau-1)+1)/((NL./N)^(1/(1-th))*tau);
%     xixL = (xiLH*(xixH*(NH./N)^(1/(1-th))*tau-1)+1)/((NL./N)^(1/(1-th))*tau);
%     ximL = (xiLH*(ximH*(NH./N)^(1/(1-th))*tau-1)+1)/((NL./N)^(1/(1-th))*tau);
chixc = xicH^(1-th)*NH + xicL^(1-th)*NL;
chixx = xixH^(1-th)*NH + xixL^(1-th)*NL;
chixm = ximH^(1-th)*NH + ximL^(1-th)*NL;
if target.pref ==0
    uc = mu*((C^mu)*(Lbar-L)^(1-mu))^(-sig)*((Lbar-L)/C)^(1-mu);
    ul = -(1-mu)*((C^mu)*(Lbar-L)^(1-mu))^(-sig)*(C/(Lbar-L))^mu;
    frisch = (Lbar-L)/L*(1-mu*(1-sig))/sig;
elseif target.pref ==1
    uc = C^(-sig);
    ul = -mu*Lbar^(-1-1/target.frisch)*L^(1/target.frisch);
    frisch = target.frisch;
elseif target.pref==2
    h = 1-mu*(L/Lbar*C^(bk/(1-bk)))^(1+1/target.frisch)/(1+1/target.frisch);
    uc = (C*h)^(-sig)*(h - mu*(bk/(1-bk))*((L/Lbar*C^(bk/(1-bk)))^(1+1/target.frisch)));
    ul = -(C*h)^(-sig)*(mu*((L/Lbar*C^(bk/(1-bk)))^(1+1/target.frisch))*C/L);
    frisch = target.frisch;
end
W = -ul*PC/(uc*(1-ttL));
%W = (1-mu)/mu*PC*C/(Lbar-L);
Lc = (1-alpc)*PC*C/W;
Chat = (C*Lc^(alpc-1))^(1/alpc);
PChat = alpc.*PC.*C/Chat;

K = N*Kd + Nx*Kx;
I = del*K;
PxC = (chixc/chid)^(1/(1-th))*Pd;
PxM = (chixm/chid)^(1/(1-th))*Pd;
PxI = (chixx/chid)^(1/(1-th))*Pd;

PI = (Pd^(1-gam) + (tau*PxI)^(1-gam)*(num_c-1))^(1/(1-gam));
PM = (Pd^(1-gam) + (tau*PxM)^(1-gam)*(num_c-1))^(1/(1-gam));
R = PI*(1/bet - 1 + del*(1-ttK))/(1-ttK);

FC = W*((num_c-1)*(N0*intkap0 + NH*intkapH + NL*intkapL) + Ne*fe);
Lp = L - Lc - FC/W;
Lp_alt = (R/alp)*((1-alp)/W)*K;
M = (R/(alp*(1-alpm)))*(alpm/PM)*K;

Cd = (Pd/PChat)^(-gam)*Chat;
Id = (Pd/PI)^(-gam)*I;
Ix = (tau*PxI/PI)^(-gam)*I*(num_c-1);
Md = (Pd/PM)^(-gam)*M;
Mx = (tau*PxM/PM)^(-gam)*M*(num_c-1);
Cx = (tau*PxC/PChat)^(-gam)*Chat*(num_c-1);

domestic_qty = Cd + Id + Md;
export_value = PxC*Cx + PxI*Ix + PxM*Mx;

rev_d_perfirm = Pd*domestic_qty/N;
rev_x_perfirm = export_value/Nx;

profit_factor = (1+s_sub)/th;

pidbar = profit_factor * rev_d_perfirm;
pixbar = profit_factor * rev_x_perfirm;

Pi = N*pidbar + Nx*pixbar - FC;
T = (tau-1)*export_value;

pixH = profit_factor *  (PxC*Cx*xicH^(1-th)/chixc + PxM*Mx*ximH^(1-th)/chixm + PxI*Ix*xixH^(1-th)/chixx);
pixL = profit_factor *  (PxC*Cx*xicL^(1-th)/chixc + PxM*Mx*ximL^(1-th)/chixm + PxI*Ix*xixL^(1-th)/chixx);
dVH = (pixH/(num_c-1) - W*(intkapH-intkap0)+ns*bet*FH*(1-rho)*dVL)/(1-ns*bet*(rho*FH-F0));


Vd1 = pidbar/(1-ns*bet);
Vx0 = (-intkap0*W + ns*bet*F0*dVH)/(1-ns*bet);


MC = 1/z*(W/((1-alp)*(1-alpm)))^((1-alp)*(1-alpm))*(R/(alp*(1-alpm)))^(alp*(1-alpm))*(PM/alpm)^alpm;
psi = MC*(alp*(1-alpm))/R;
YN = PC*C + PI*I;
IMN = export_value;
REV = Pd*domestic_qty + export_value;
T_rs = s_sub * REV;

F(1) = Pd - chid^(1/(1-th))*(th/(th-1))*MC/(1+s_sub);
F(2) = PChat - (Pd^(1-gam) + (tau*PxC)^(1-gam)*(num_c-1))^(1/(1-gam));
F(3) = PC*C + PI*I - (W*L + R*K + Pi + T - T_rs);
F(4) = W*fe - ns*bet*(Vd1+Vx0*(num_c-1));
F(5) = Kx - psi*(Cx*chixc^(1/(1-th)) + Ix*chixx^(1/(1-th)) + Mx*chixm^(1/(1-th)))/Nx;
F(6) = Kd - psi*chid^(1/(1-th))*(Cd+Id+Md)/N;
F(7) = W*kap0 - ns*bet*dVH;
F(8) = IMN/YN - target.IMY;
if target.trade_comp==1
    F(9) = PxI*Ix/export_value - target.Xshare;
    F(10) = PxM*Mx/export_value - target.Mshare;
elseif target.trade_comp==0
    F(9) = xixH-xicH;
    F(10) = xicH-ximH;
end
F(11) = z - 1;
% F(12) = mu - 0.33;
if target.elast_labor==1
    if target.pref==0
        F(12) = frisch - target.frisch;
    elseif target.pref>0
        F(12) = L/Lbar - 0.33;
    end
elseif target.elast_labor==0
    F(12) = L/Lbar - 0.999;
end
% F(13) = alp - 0.25;
F(13) = W*L/(W*L+R*K+Pi) - target.WLVA;
% F(14) = fe - 1.5;
F(14) = N - Lbar;
% F(15) = f0 - 100;
F(15) = 1-(1-Nx/N)^(num_c-1) - target.Nx;
% F(16) = f1 - .1;
inc_ent = (rho*NH*FH + (1-rho)*NL*FL + (rho*NL*FL + (1-rho)*NH*FH)*xiLH^(1-th))/(F0*(N0));
F(16) = 1/(inc_ent+1) - target.churnx;
inc_ent_n = (rho*NH*FH + (1-rho)*NL*FL + rho*NL*FL + (1-rho)*NH*FH)/(F0*(N0));
F(17) = 1/(inc_ent_n+1) - target.churnn;
F(18) = W*kapH - ns*bet*(rho*dVH+(1-rho)*dVL);
F(19) = W*kapL - ns*bet*(rho*dVL + (1-rho)*dVH);
F(20) = NH - ns*((N0)*F0 + rho*NH*FH + (1-rho)*NL*FL);
F(21) = dVL - (pixL/(num_c-1) - W*(intkapL-intkap0) + ns*bet*(((1-rho)*FL-F0)*dVH + rho*FL*dVL));

ent_y = NaN(5,2);
ent_y(1,1) = ns*(N0+Ne)*F0;
ent_y(1,2) = 0;
for i=2:5
    ent_y(i,1) = ns*(ent_y(i-1,1)*rho*FH + ent_y(i-1,2)*(1-rho)*FL);
    ent_y(i,2) = ns*(ent_y(i-1,2)*rho*FL + ent_y(i-1,1)*(1-rho)*FH);
end
ent5_H = sum(ent_y(:,1));
ent5_L = sum(ent_y(:,2));
ent5_total = (ent5_H + ent5_L*xiLH^(1-th))/(NH + NL*xiLH^(1-th));
F(22) = ent5_total - target.ent5;
if dynamic==0
    F(22) = rho-0.5;
end



end
