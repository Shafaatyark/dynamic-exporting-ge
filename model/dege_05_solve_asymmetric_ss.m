function [F,tauij,Lbar,PC,FH,FL,F0,intkapH,intkapL,intkap0,Ne,Nij,NHij,NLij,W,Lc,Chat,PChat,K,I,Pcij,Pxij,Pmij,PI,PM,R,Lp,Lp_alt,M,Cij,Iij,Mij,piij,piNT,piijH,Pi,T,dVHij,dVLij,Vd1,Vx0,MC,psi,frisch,YN,IMN,NXY,B,AdjLag,xicLij,xixLij,ximLij,churn_ij,chicij,churnn_ij] = dege_05_solve_asymmetric_ss(y,target,num_c,dynamic)
%Solves a steady state for num_c countries with moments given by structure
%target. mt determines model type.

global bet del sig th gam v alpm ns alpc mu alp fe bk ttL ttK sI revsub

[L,N,C,Pd,PC,f0,f1,z,xiLH,rho,kij,kap0ij,xicHij,xixHij,ximHij,kapHij,kapLij,NHij,dVLij] = dege_06_extract_from_y(y,num_c);

tauij = target.Tau;
Lbar = target.Lbar;
J = target.J;
Jsq = diag(J);
% PC = ones(num_c,1);             %A normalization in SS since trade costs, and technology could yield any price vector; normalization does not matter for transitions

xicLij = xiLH.*xicHij;
xixLij = xiLH.*xixHij;
ximLij = xiLH.*ximHij;

if revsub==1
    s_sub = 1/(th-1);
else
    s_sub = 0;
end

profit_factor = (1+s_sub)/th;

FH = 1 - (1+v*kapHij./f1).^(-1/v);
FL = 1 - (1+v*kapLij./f1).^(-1/v);
F0 = 1 - (1+v*kap0ij./f0).^(-1/v);
intkapH = f1./(1-v).*(1-(1+v*kapHij./f1).^(-1/v).*(1+kapHij./f1));
intkapL = f1./(1-v).*(1-(1+v*kapLij./f1).^(-1/v).*(1+kapLij./f1));
intkap0 = f0./(1-v).*(1-(1+v*kap0ij./f0).^(-1/v).*(1+kap0ij./f0));
FH(Jsq==1)=0;
FL(Jsq==1)=0;
F0(Jsq==1)=0;
intkapH(Jsq==1)=0;
intkapL(Jsq==1)=0;
intkap0(Jsq==1)=0;

Ne = (1-ns)*N/ns;
NLij = ns*(1-rho).*NHij.*FH./(1-ns*rho.*FL);
Nij = NHij+NLij;
N0ij = N-Nij;
%     xicLij = (xiLH.*(xicHij.*(NHij./N).^(1/(1-th)).*tauij-1)+1)./((NLij./N).^(1/(1-th)).*tauij);
%     xixLij = (xiLH.*(xixHij.*(NHij./N).^(1/(1-th)).*tauij-1)+1)./((NLij./N).^(1/(1-th)).*tauij);
%     ximLij = (xiLH.*(ximHij.*(NHij./N).^(1/(1-th)).*tauij-1)+1)./((NLij./N).^(1/(1-th)).*tauij);
xicLij = xicLij-diag(diag(xicLij))+eye(num_c);
xixLij = xixLij-diag(diag(xixLij))+eye(num_c);
ximLij = ximLij-diag(diag(ximLij))+eye(num_c);
chicij = (xicHij.^(1-th).*NHij + xicLij.^(1-th).*NLij)./J;
chixij = (xixHij.^(1-th).*NHij + xixLij.^(1-th).*NLij)./J;
chimij = (ximHij.^(1-th).*NHij + ximLij.^(1-th).*NLij)./J;
chid = N./J;

if target.pref ==0
    uc = mu*((C.^mu).*(Lbar-L).^(1-mu)).^(-sig).*((Lbar-L)./C).^(1-mu);
    ul = -(1-mu)*((C.^mu).*(Lbar-L).^(1-mu)).^(-sig).*(C./(Lbar-L)).^mu;
    frisch = (Lbar-L)./L.*(1-mu*(1-sig))/sig;
elseif target.pref ==1
    uc = C.^(-sig);
    ul = -mu*Lbar.^(-1-1/target.frisch).*L.^(1/target.frisch);
    frisch = target.frisch;
elseif target.pref==2
    h = 1-mu*(L./Lbar.*C.^(bk/(1-bk))).^(1+1/target.frisch)/(1+1/target.frisch);
    uc = (C.*h).^(-sig).*(h - mu*(bk/(1-bk))*((L./Lbar.*C.^(bk/(1-bk))).^(1+1/target.frisch)));
    ul = -(C.*h).^(-sig).*(mu*((L./Lbar.*C.^(bk/(1-bk))).^(1+1/target.frisch)).*C./L);
    frisch = target.frisch;
end
%W = (1-mu)/mu*PC.*C./(Lbar-L);
W = (-ul.*PC./uc)./(1-ttL);
Lc = (1-alpc)*PC.*C./W;
Chat = (C.*Lc.^(alpc-1)).^(1/alpc);
PChat = alpc.*PC.*C./Chat;

zetacij = diag(((J-1).*diag(tauij.*(chicij./chid).^(1/(1-th))).^(1-gam) +1).^(1/(1-gam)));
zetaxij = diag(((J-1).*diag(tauij.*(chixij./chid).^(1/(1-th))).^(1-gam) +1).^(1/(1-gam)));
zetamij = diag(((J-1).*diag(tauij.*(chimij./chid).^(1/(1-th))).^(1-gam) +1).^(1/(1-gam)));
zetacij(Jsq==0) = tauij(Jsq==0);
zetaxij(Jsq==0) = tauij(Jsq==0);
zetamij(Jsq==0) = tauij(Jsq==0);
Scij = ((J-1).*diag(tauij.^(-gam/(1-gam)).*(chicij./chid).^(1/(1-th))).^(1-gam) +1)./(zetacij.^(1-gam));
Sxij = ((J-1).*diag(tauij.^(-gam/(1-gam)).*(chixij./chid).^(1/(1-th))).^(1-gam) +1)./(zetaxij.^(1-gam));
Smij = ((J-1).*diag(tauij.^(-gam/(1-gam)).*(chimij./chid).^(1/(1-th))).^(1-gam) +1)./(zetamij.^(1-gam));
Scij(Jsq==0) = zetacij(Jsq==0).^(-1);
Sxij(Jsq==0) = zetaxij(Jsq==0).^(-1);
Smij(Jsq==0) = zetamij(Jsq==0).^(-1);


chicijalt = chicij - diag(diag(chicij)) + diag(chid);
chixijalt = chixij - diag(diag(chixij)) + diag(chid);
chimijalt = chimij - diag(diag(chimij)) + diag(chid);
Nijalt = Nij - diag(diag(Nij))+diag(N);


K = sum(Nijalt.*kij,2);
I = del*K;
Pcij = (chicij./chid).^(1/(1-th)).*Pd;
Pmij = (chimij./chid).^(1/(1-th)).*Pd;
Pxij = (chixij./chid).^(1/(1-th)).*Pd;
Pcijalt = Pcij;
Pxijalt = Pxij;
Pmijalt = Pmij;
Pcijalt(Jsq~=0) = Pd;
Pxijalt(Jsq~=0) = Pd;
Pmijalt(Jsq~=0) = Pd;

Js = J.*ones(num_c);
Js = Js - diag(diag(Js)) + eye(num_c);
PI = (sum((zetaxij'.*Pxijalt').^(1-gam).*Js',2)).^(1/(1-gam));
PM = (sum((zetamij'.*Pmijalt').^(1-gam).*Js',2)).^(1/(1-gam));
R = PI*(1/bet - 1 + del*(1-ttK))./(1-ttK);

FC = W.*(sum(NHij.*intkapH + NLij.*intkapL + N0ij.*intkap0,2) + Ne.*fe);
Lp = L - Lc - FC./W;
Lp_alt = (R/alp).*((1-alp)./W).*K;
M = (R/(alp*(1-alpm))).*(alpm./PM).*K;

Cij = (zetacij.*Pcijalt./PChat.').^(-gam).*Js.*Chat';
Iij = (zetaxij.*Pxijalt./PI.').^(-gam).*Js.*I';
Mij = (zetamij.*Pmijalt./PM.').^(-gam).*Js.*M';

active_revij = Pcijalt.*Cij.*zetacij.*Scij + Pxijalt.*Iij.*zetaxij.*Sxij + Pmijalt.*Mij.*zetamij.*Smij;
active_nt_qty = Cij.*zetacij.^gam + Iij.*zetaxij.^gam + Mij.*zetamij.^gam;

revij_perfirm = active_revij ./ Nijalt;

piij = profit_factor .* revij_perfirm;

revNT_perfirm = (Pd./N) .* diag(active_nt_qty);
piNT = profit_factor .* revNT_perfirm;

Pi = sum(Nijalt.*piij,2)-FC;
IMPcii = diag(tauij.^(-gam).*Pcij.^(1-gam)).*(J-1).*(PChat.^gam).*Chat;
IMPcij = Pcijalt'.*Cij' -diag(diag(Pcijalt'.*Cij')) + diag(IMPcii);
IMPxii = diag(tauij.^(-gam).*Pxij.^(1-gam)).*(J-1).*(PI.^gam).*I;
IMPxij = Pxijalt'.*Iij' -diag(diag(Pxijalt'.*Iij')) + diag(IMPxii);
IMPmii = diag(tauij.^(-gam).*Pmij.^(1-gam)).*(J-1).*(PM.^gam).*M;
IMPmij = Pmijalt'.*Mij' -diag(diag(Pmijalt'.*Mij')) + diag(IMPmii);
IMPii = IMPcii+IMPmii+IMPxii;
IMPij = IMPcij+IMPxij+IMPmij;
T = sum((tauij'-1).*IMPij,2);
piijH = profit_factor .* (IMPcij'.*xicHij.^(1-th)./chicij ...
                        + IMPmij'.*ximHij.^(1-th)./chimij ...
                        + IMPxij'.*xixHij.^(1-th)./chixij) ./ J;

piijL = profit_factor .* (IMPcij'.*xicLij.^(1-th)./chicij ...
                        + IMPmij'.*ximLij.^(1-th)./chimij ...
                        + IMPxij'.*xixLij.^(1-th)./chixij) ./ J;

dVHij = (piijH - W.*(intkapH-intkap0) + ns*bet*FH.*(1-rho).*dVLij)./(1-ns*bet*(rho.*FH-F0));


Vd1 = piNT./(1-ns*bet);
Vx0 = (-intkap0.*W + ns*bet*F0.*dVHij)./(1-ns*bet);

MC = 1./z.*(W/((1-alp)*(1-alpm))).^((1-alp)*(1-alpm)).*(R/(alp*(1-alpm))).^(alp*(1-alpm)).*(PM/alpm).^alpm;
psi = MC.*(alp*(1-alpm))./R;
IMN = sum(IMPij,2);
EXN = sum(IMPij',2);
YN = PC.*C + PI.*I + EXN-IMN;
NXY = (EXN-IMN)./YN;
B = -NXY.*YN./(1-bet);


AdjLag = uc./PC.*PI;

% Per-country firm revenue (sum over destinations j for each source i).
% Must match Dynare's Locals.mod where Rev@{co} is country-specific and
% T_rs@{co} = s_sub@{co} * Rev@{co} enters the per-country BC. Using
% sum(sum(...)) gives the world total and over-counts T_rs by num_c when
% revsub=1, which leaves a non-zero residual in Dynare's initial steady.
REV = sum(active_revij, 2);
T_rs = s_sub * REV;

Pdres = Pd - chid.^(1/(1-th))*(th/(th-1)).*MC./(1+s_sub);
Cres = PChat - (sum((zetacij'.*Pcijalt').^(1-gam),2)).^(1/(1-gam));
Lres = PC.*C + PI.*I - (W.*L + R.*K + Pi + T + (1-bet).*B - T_rs);
Nres = W.*fe - ns*bet*(Vd1+sum(Vx0,2));

PCres = PC-1;
kres = kij - psi./(Nijalt./J).*(Cij.*chicijalt.^(1/(1-th)).*zetacij.*Scij + Iij.*chixijalt.^(1/(1-th)).*zetaxij.*Sxij + Mij.*chimijalt.^(1/(1-th)).*zetamij.*Smij)./J;
kap0res = W.*kap0ij - ns*bet*dVHij;
kap0res(Jsq==1) = kap0ij(Jsq==1)-1;
kapHres = W.*kapHij - ns*bet*(rho.*dVHij + (1-rho).*dVLij);
kapHres(Jsq==1) = kapHij(Jsq==1)-1;
kapLres = W.*kapLij - ns*bet*(rho.*dVLij + (1-rho).*dVHij);
kapLres(Jsq==1) = kapLij(Jsq==1)-1;

trade_tol = 1e-10;
target_Xshare = target.Xshare;
target_Mshare = target.Mshare;
if isscalar(target_Xshare)
    target_Xshare = target_Xshare*ones(num_c);
end
if isscalar(target_Mshare)
    target_Mshare = target_Mshare*ones(num_c);
end

% F(8) = xic - 1.4;
xicres = IMPij./YN - target.IMijY;
xicres(Jsq==1) = xicHij(Jsq==1)-1;
if target.trade_comp==1
    ximres = ximHij-xicHij;
    xixres = xixHij-xicHij;
    active_trade = abs(IMPij) > trade_tol;
    ximres(active_trade) = IMPmij(active_trade)./IMPij(active_trade) - target_Mshare(active_trade);
    xixres(active_trade) = IMPxij(active_trade)./IMPij(active_trade) - target_Xshare(active_trade);
elseif target.trade_comp==0
    xixres = xicHij-xixHij;
    ximres = ximHij-xicHij;
end
xixres(Jsq==1) = xixHij(Jsq==1)-1;
ximres(Jsq==1) = ximHij(Jsq==1)-1;
zres = [z(1) - 1; YN(2:end)./YN(1) - target.gdp(2:end)./target.gdp(1)];
f0res = 1-prod(1-Nij./N,2) - target.Nx;

inc_entij = (rho.*NHij.*FH + (1-rho).*NLij.*FL + (rho.*NLij.*FL + (1-rho).*NHij.*FH).*xiLH.^(1-th))./(F0.*(N0ij));
inc_shareij = inc_entij./(1+inc_entij);
inc_shareij(Jsq==1) = 0;
export_values = IMPij';
export_totals = sum(export_values,2);
exp_shareij = zeros(size(export_values));
active_export = abs(export_totals) > trade_tol;
exp_shareij(active_export,:) = export_values(active_export,:)./export_totals(active_export);
churn_ij = 1./(1+inc_entij);
churn_ij(Jsq==1) = 0;
f1res = sum(exp_shareij.*churn_ij,2) - target.churnx;

inc_entnij = (rho.*NHij.*FH + (1-rho).*NLij.*FL + rho.*NLij.*FL + (1-rho).*NHij.*FH)./(F0.*(N0ij));
incn_shareij = inc_entnij./(1+inc_entnij);
incn_shareij(Jsq==1) = 0;
churnn_ij = 1./(1+inc_entnij);
% churnn_ij = (F0.*ns.*(N0ij+Ne))./(NHij + NLij);
churnn_ij(Jsq==1) = 0;
xiLHres = sum(exp_shareij.*churnn_ij,2) - target.churnn;

ent_yij = NaN(num_c,num_c,5,2);
ent_yij(:,:,1,1) = ns*(N0ij+Ne).*F0;
ent_yij(:,:,1,2) = zeros(num_c);
for i=2:5
    ent_yij(:,:,i,1) = ns*(ent_yij(:,:,i-1,1).*rho.*FH + ent_yij(:,:,i-1,2).*(1-rho).*FL);
    ent_yij(:,:,i,2) = ns*(ent_yij(:,:,i-1,2).*rho.*FL + ent_yij(:,:,i-1,1).*(1-rho).*FH);
end
ent5_Hij = sum(ent_yij(:,:,:,1),3);
ent5_Lij = sum(ent_yij(:,:,:,2),3);
ent5_totalij = (ent5_Hij + ent5_Lij.*xiLH.^(1-th))./(NHij + NLij.*xiLH.^(1-th));
rhores = sum(exp_shareij.*ent5_totalij,2) - target.ent5_share;
if  dynamic==0
    kapLres = kapLij - kapHij;
    kapLres(Jsq==1) = kapLij(Jsq==1)-1;
    f1res = F0 - target.churnx./ns*target.Nx./(1-target.Nx);
    f1res = f1res(~eye(2));
    f0res = FL - (1-target.churnx)./ns;
    f0res = f0res(~eye(2));
    xiLHres = xiLH - 1;
    rhores = rho-0.5;
end
NHres = NHij - ns*(N0ij.*F0 + rho.*NHij.*FH + (1-rho).*NLij.*FL);
NHres(Jsq==1) = NHij(Jsq==1)-0;

dVLres = dVLij - (piijL - W.*(intkapL-intkap0) + ns*bet*(((1-rho).*FL-F0).*dVHij + rho.*FL.*dVLij));
dVLres(Jsq==1) = dVLij(Jsq==1)-0;

F = [Pdres; PCres; Cres; Lres; Nres; kres(:); kap0res(:); kapHres(:); kapLres(:); xicres(:); xixres(:); ximres(:); ...
        zres; f0res; f1res; xiLHres; rhores; NHres(:); dVLres(:)];




end
