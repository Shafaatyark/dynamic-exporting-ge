if num_c ~= 2
    error('dege:asymmetric:UnsupportedCountryCount', ...
        'The public simulator supports exactly two countries.');
end

target.gdp = target.gdp*ones(num_c,1);
target.Lbar = target.Lbar*ones(num_c,1);
target.IMY = target.IMY*ones(num_c,1);
target.Xshare = target.Xshare*ones(num_c);
target.Mshare = target.Mshare*ones(num_c);
target.Cshare = target.Cshare*ones(num_c);
target.ent5_share = target.ent5;


target.Tau = tauij;
target.J = J;
target.IMijY = target.IMY./(num_c-(target.J==1)).*ones(num_c);
target.IMijY(diag(target.J)==1) = zeros(sum(target.J==1),1);



f00 = f0*ones(num_c,1);
f10 = f1*ones(num_c,1);
z0 = z*ones(num_c,1);
xic0 = Xic*ones(num_c);
xix0 = Xix*ones(num_c);
xim0 = Xim*ones(num_c);
kap0 = Kap*ones(num_c);
L0 = L*ones(num_c,1);
N0 = N*ones(num_c,1);
C0 = C*ones(num_c,1);
k0 = Kx/(num_c-1)*ones(num_c);
k0 = k0 - diag(diag(k0)) + eye(num_c)*Kd;
Pd0 = Pd*ones(num_c,1);
PC0 = PC*ones(num_c,1);
kap00 = Kap0*ones(num_c);
kapH0 = KapH*ones(num_c);
kapL0 = KapL*ones(num_c);
xiLH0 = xiLH*ones(num_c,1);
rho0 = rho*ones(num_c,1);
NH0 = NH*ones(num_c);
dVL0 = dVL*ones(num_c);

y0 = log([L0; N0; C0; Pd0; PC0; f00; f10; z0; xiLH0; rho0; k0(:); kap00(:); xic0(:); xix0(:); xim0(:); kapH0(:); kapL0(:); NH0(:); dVL0(:)]);

[y,F] = fsolve(@(x) dege_05_solve_asymmetric_ss(x,target,num_c,dynamic),y0,optimset('Display','iter','MaxFunEvals',10000,'MaxIter',10000));

[L,N,C,Pd,PC,f0,f1,z,xiLH,rho,kij,kap0ij,xicHij,xixHij,ximHij,kapHij,kapLij,NHij,dVLij] = dege_06_extract_from_y(y,num_c);
[F,tauij,Lbar,PC,FH,FL,F0,intkapH,intkapL,intkap0,Ne,Nij,NHij,NLij,W,Lc,Chat,PChat,K,I,Pcij,Pxij,Pmij,PI,PM,R,Lp,Lp_alt,M,Cij,Iij,Mij,piij,piNT,piijH,Pi,T,dVHij,dVLij,Vd1,Vx0,MC,psi,frisch,YN,IMN,NXY,B,AdjLag,xicLij,xixLij,ximLij,churn_ij,chicij,churnn_ij] = dege_05_solve_asymmetric_ss(y,target,num_c,dynamic);


Jsq = diag(J);
IMij = target.IMijY .* YN;
IM = sum(IMij,2);
EX = sum(IMij',2);
