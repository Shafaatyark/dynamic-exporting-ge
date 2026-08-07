%Initial guesses for parameters
if target.pref==0
    mu0 = 0.41;
elseif target.pref==1
    mu0 = 3.8;
elseif target.pref==2
    mu0 = 6.16;
end
alp0 = 0.17;
fe0 = 2.5;
f00 = 0.2791;
f10 = 0.0173;
z0 = 1;
xic0 = 2.42;
xix0 = 0.75;
xim0 = 2.5;
if target.trade_comp == 0
    xic0 = 2;
    xix0 = 2;
    xim0 = 2;
end
L0 = 0.33;
N0 = 1;
C0 = 0.0345;
Kx0 = 0.0073;
Kd0 = 0.0401;
Pd0 = 1.01;
NH0 = 0.2855;
dVL0 = 0.0116;
rho0 = 0.83;
xiLH0 = 0.69;
kap00 = 0.039;
kapH0 = 0.06;
kapL0 = 0.128;

y0 = log([kap00 L0 N0 C0 Kx0 Kd0 Pd0 mu0 alp0 fe0 f00 f10 z0 xic0 xix0 xim0 xiLH0 kapH0 kapL0 NH0 dVL0 rho0]);


%Solve for Steady State
[y,F,exitflag] = fsolve(@(y) dege_03_solve_symmetric_ss(y,target,num_c,dynamic),y0,optimset('Display','iter','MaxFunEvals',10000,'MaxIter',10000));

%If steady state is not solved, use homotopy
if exitflag<1
    %Start from the default parameters
    init_alt = dege_01_initialize_model();
    %Solve for the steady state using homotopy methods, changing the
    %parameter in h_steps linear steps from default to chosen parameter.
    h_steps = 6;
    for w=linspace(0,1,h_steps)
        for fn=1:numel(fields)
            if (~isequal(init.(fields{fn}), init_alt.(fields{fn}))) && (~ismember(fields{fn},{'dynamic','trade_comp','pref','elast_labor','trade_bal'}))
                assignin('caller', fields{fn}, w*init.(fields{fn})+(1-w)*init_alt.(fields{fn}));
                target.(fields{fn}) = w*init.(fields{fn})+(1-w)*init_alt.(fields{fn});
            end
        end
        if w==0
            [y,F,exitflag_homotopy] = fsolve(@(y) dege_03_solve_symmetric_ss(y,target,num_c,dynamic),y0,optimset('Display','iter','MaxFunEvals',10000,'MaxIter',10000));
        else
            [y,F,exitflag_homotopy] = fsolve(@(y) dege_03_solve_symmetric_ss(y,target,num_c,dynamic),y,optimset('Display','iter','MaxFunEvals',10000,'MaxIter',10000));
        end
        if exitflag_homotopy<1
            error('Symmetric steady state not solved using homotopy. Increase number of homotopy steps or try new parameters.')
        end
    end
end

global mu alp fe f;

Kap = exp(y(1));
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
Xic = exp(y(14));
Xix = exp(y(15));
Xim = exp(y(16));
Kap0 = Kap;
xiLH = exp(y(17));
KapH = exp(y(18));
KapL =exp(y(19));
NH = exp(y(20));
dVL = exp(y(21));
rho = exp(y(22));

%Get all other values.
[F,Tau,Lbar,PC,FH,FL,F0,intkapH,intkapL,intkap0,Ne,Nx,N0,NL,W,Lc,Chat,PChat,K,I,PxC,PxI,PxM,PI,PM,R,Lp,Lp_alt,M,Cd,Id,Md,Cx,Ix,Mx,pidbar,pixbar,Pi,T,dVH,Vd1,Vx0,MC,psi,frisch,YN,IMN] = dege_03_solve_symmetric_ss(y,target,num_c,dynamic);
