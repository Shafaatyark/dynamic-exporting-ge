@#if co!=1
    [name='BC @{co}']
    exp(pc@{co}+c@{co}) + exp(px@{co}+x@{co}) + exp(q@{co})*b@{co} + phi*J@{co}*((b@{co}(-1)-bbar@{co})/(exp(pd@{co}+y@{co})))^2/2 = exp(w@{co}+l@{co}) + exp(r@{co}+k@{co}(-1)) + b@{co}(-1) + exp(pi@{co}) + t@{co} - T_rs@{co};
    %exp(pc@{co}+c@{co}) + exp(px@{co}+x@{co}) + exp(q@{co})*b@{co} + phi*J@{co}*((b@{co}(-1)-bbar@{co})/(exp(pd@{co}+y@{co})))^2/2 = exp(w@{co}+l@{co}) + exp(r@{co}+k@{co}(-1)) + b@{co}(-1) - fc@{co} + t@{co};
    [name = 'Arbitrage @{co}']
    q@{co}=q1;
    %b@{co}=bbar@{co};
@#else
    pc@{co} = 0;
@#endif
[name='Intratemporal @{co}']
%(Lbar@{co}-exp(l@{co})) = (1-mu)/mu*exp(c@{co}+pc@{co}-w@{co});
-ul@{co} = exp(uc@{co}+w@{co}-pc@{co})*(1-ttL@{co});
[name='Euler @{co}']
mu@{co} = bet*(exp(ucf@{co}-pc@{co}(+1))*((1-ttK@{co})*exp(r@{co}(+1))+ttK@{co}*del*exp(px@{co}(+1))) + mu@{co}(+1)*(1-del));
%exp(px@{co}) = exp(sdf@{co})*(exp(r@{co}(+1))+exp(px@{co}(+1))*(1-del));
[name='Euler 2 @{co}']
exp(uc@{co} + px@{co} - pc@{co})*(1-s@{co}) = mu@{co}*(1 - Psi@{co} - psi*uI@{co}*(uI@{co}+1));
[name='Capital Accumulation @{co}']
exp(x@{co})*(1-Psi@{co}) = exp(k@{co})-(1-del)*exp(k@{co}(-1));
[name='Domestic IG price @{co}']
exp(pd@{co}) = th/(th-1)*exp(1/(1-th)*n@{co})*mc@{co}/(1+s_sub@{co});
[name='Vd1 @{co}']
exp(vd@{co}) = exp(piNT@{co}) + ns*exp(sdf@{co}+vd@{co}(+1));
[name='N LoM @{co}']
exp(n@{co}) = ns*exp(n@{co}(-1)) + ns*exp(ne@{co}(-1));
[name = 'M @{co}']
exp(m@{co}) = alpm/((1-alpm)*alp)*exp(r@{co}+k@{co}(-1)-pm@{co});
[name = 'Lp @{co}']
exp(lp@{co}) = (1-alp)/alp*exp(r@{co}+k@{co}(-1)-w@{co});
[name = 'LMC @{co}']
exp(l@{co}) = exp(lp@{co}) + exp(lc@{co}) + fc@{co}/exp(w@{co});
[name = 'D @{co}']
exp(d@{co}) = exp(n@{co}+piNT@{co})/profit_factor@{co};
@#for co1 in countries
    @#if co1!=co
        [name= 'Threshold 0 @{co}@{co1}']
        kap0@{co}@{co1} = log(ns) + sdf@{co} + dvH@{co}@{co1}(+1) - w@{co};
        [name= 'Threshold H @{co}@{co1}']
        exp(w@{co} + kapH@{co}@{co1}) = ns*exp(sdf@{co})*(rho@{co}*exp(dvH@{co}@{co1}(+1)) + (1-rho@{co})*exp(dvL@{co}@{co1}(+1)));
        [name= 'Threshold L @{co}@{co1}']
        exp(w@{co} + kapL@{co}@{co1}) = ns*exp(sdf@{co})*(rho@{co}*exp(dvL@{co}@{co1}(+1)) + (1-rho@{co})*exp(dvH@{co}@{co1}(+1)));
        [name = 'Vx0 @{co}@{co1}']
        exp(vx0@{co}@{co1}) = -exp(w@{co})*int0@{co}@{co1}+ns*exp(sdf@{co})*(F0@{co}@{co1}*exp(dvH@{co}@{co1}(+1))+exp(vx0@{co}@{co1}(+1)));
        [name= 'Exporters H LoM @{co}@{co1}']
        exp(nH@{co}@{co1}) = ns*(exp(n0@{co}@{co1}(-1))*F0@{co}@{co1}lag + rho@{co}*exp(nH@{co}@{co1}(-1))*FH@{co}@{co1}lag + (1-rho@{co})*exp(nL@{co}@{co1}(-1))*FL@{co}@{co1}lag);
        [name= 'Exporters L LoM @{co}@{co1}']
        exp(nL@{co}@{co1}) = ns*(rho@{co}*exp(nL@{co}@{co1}(-1))*FL@{co}@{co1}lag + (1-rho@{co})*exp(nH@{co}@{co1}(-1))*FH@{co}@{co1}lag);
        [name= 'Exporters @{co}@{co1}']
        exp(n@{co}@{co1}) = exp(nH@{co}@{co1}) + exp(nL@{co}@{co1});
        [name = 'Nonexporters @{co}@{co1}']
        exp(n0@{co}@{co1}) = exp(n@{co})-exp(n@{co}@{co1});
        [name = 'dVH @{co}@{co1}']
        exp(dvH@{co}@{co1}) = exp(pi@{co}@{co1}H) - exp(w@{co})*(intH@{co}@{co1}-int0@{co}@{co1})
                +ns*exp(sdf@{co})*((rho@{co}*FH@{co}@{co1}-F0@{co}@{co1})*exp(dvH@{co}@{co1}(+1)) + (1-rho@{co})*FH@{co}@{co1}*exp(dvL@{co}@{co1}(+1)));
        [name = 'dVL @{co}@{co1}']
        exp(dvL@{co}@{co1}) = exp(pi@{co}@{co1}L) - exp(w@{co})*(intL@{co}@{co1}-int0@{co}@{co1})
                +ns*exp(sdf@{co})*(((1-rho@{co})*FL@{co}@{co1}-F0@{co}@{co1})*exp(dvH@{co}@{co1}(+1)) + rho@{co}*FL@{co}@{co1}*exp(dvL@{co}@{co1}(+1)));
        [name= 'Price c @{co}@{co1}']
        pc@{co}@{co1} = 1/(1-th)*(chic@{co}@{co1}-n@{co}) + pd@{co};
        [name= 'Price x @{co}@{co1}']
        px@{co}@{co1} = 1/(1-th)*(chix@{co}@{co1}-n@{co}) + pd@{co};
        [name= 'Price m @{co}@{co1}']
        pm@{co}@{co1} = 1/(1-th)*(chim@{co}@{co1}-n@{co}) + pd@{co};
        [name = 'Exports @{co}@{co1}']
        exp(ex@{co}@{co1}) = exp(pc@{co}@{co1}+c@{co}@{co1}) + exp(px@{co}@{co1}+x@{co}@{co1}) + exp(pm@{co}@{co1}+m@{co}@{co1});
        [name = 'Import spending @{co}@{co1}']
        ims@{co1}@{co} = tau@{co}@{co1} + ex@{co}@{co1};
        @#for go in goods
            [name = 'Elast @{go}@{co}@{co1}']
            elast@{go}@{co}@{co1} = -gam*tau@{co}@{co1} + (1-gam)/(1-th)*chi@{go}@{co}@{co1};
        @#endfor
    @#endif
@#endfor

[name = 'PC @{co}']
exp((1-gam)*pctilde@{co}) =
@#for co1 in countries
    +exp((1-gam)*(pc@{co1}@{co}+tau@{co1}@{co}))*J@{co1}
@#endfor
;

[name = 'PX @{co}']
exp((1-gam)*px@{co}) =
@#for co1 in countries
    +exp((1-gam)*(px@{co1}@{co}+tau@{co1}@{co}))*J@{co1}
@#endfor
;

[name = 'PM @{co}']
exp((1-gam)*pm@{co}) =
@#for co1 in countries
    +exp((1-gam)*(pm@{co1}@{co}+tau@{co1}@{co}))*J@{co1}
@#endfor
;

[name = 'KMC @{co}']
exp(k@{co}(-1)) =
@#for co1 in countries
    +exp(n@{co}@{co1}+k@{co}@{co1})
@#endfor
;

[name = 'T @{co}']
t@{co} =
@#for co1 in countries
    @#if co1!=co
        +((exp(tau@{co1}@{co})-1)*exp(ex@{co1}@{co}))
    @#endif
@#endfor
;

[name = 'Free Entry @{co}']
@#if free_entry==1
    exp(w@{co})*fe = ns*exp(sdf@{co})*(exp(vd@{co}(+1))
    @#for co1 in countries
        @#if co!=co1
            +exp(vx0@{co}@{co1}(+1))
        @#endif
    @#endfor
    );
@#else
    exp(ne@{co}) = exp(ness@{co});
@#endif


[name = 'Imports @{co}']
exp(im@{co}) =
@#for co1 in countries
    @#if co1!=co
        +exp(ex@{co1}@{co})
    @#endif
@#endfor
;

[name = 'Imports Spending @{co}']
exp(ims@{co}) =
@#for co1 in countries
    @#if co1!=co
        +exp(ims@{co}@{co1})
    @#endif
@#endfor
;

[name = 'Real Imports @{co}']
exp(rim@{co}) =
@#for co1 in countries
@#if co1!=co
    +(exp(pcss@{co1}@{co}+c@{co1}@{co})+exp(pxss@{co1}@{co}+x@{co1}@{co})+exp(pmss@{co1}@{co}+m@{co1}@{co}))
@#endif
@#endfor
;

[name = 'Y @{co}']
exp(y@{co}) = exp(pcss@{co}+c@{co})+exp(pxss@{co}+x@{co})
@#for co1 in countries
@#if co1!=co
    +(exp(pcss@{co}@{co1}+c@{co}@{co1})+exp(pxss@{co}@{co1}+x@{co}@{co1})+exp(pmss@{co}@{co1}+m@{co}@{co1}))-(exp(pcss@{co1}@{co}+c@{co1}@{co})+exp(pxss@{co1}@{co}+x@{co1}@{co})+exp(pmss@{co1}@{co}+m@{co1}@{co}))
@#endif
@#endfor
;

[name = 'RER @{co}']
rer@{co} = pcss@{co}-pc@{co}+(
@#for co1 in countries
    @#if co1!=co
        + (exp(ex@{co}@{co1}) + exp(tau@{co1}@{co}+ex@{co1}@{co}))*(pc@{co1}-pcss@{co1})
    @#endif
@#endfor
)/(
@#for co1 in countries
    @#if co1!=co
        + (exp(ex@{co}@{co1}) + exp(tau@{co1}@{co}+ex@{co1}@{co}))
    @#endif
@#endfor
);

[name = 'Domestic expenditure share @{co}']
exp(lambda@{co}) = (exp(n@{co}+piNT@{co})/profit_factor@{co})/(exp(pc@{co}+c@{co})-exp(w@{co}+lc@{co})+exp(px@{co}+x@{co})+exp(pm@{co}+m@{co})-t@{co});

@#for go in goods
    [name = 'Domestic expenditure share @{go} @{co}']
    exp(lambda@{go}@{co}) = 1/(1+gm@{go}@{co});
    [name = 'Asymmetries @{go} @{co}']
    exp(A@{go}@{co}) = (1+gx@{go}r@{co})/(1+gm@{go}r@{co});
    [name = 'Import weighted tariff @{go} @{co}']
    exp(X@{go}@{co}) = (1+gm@{go}@{co})/(1+gm@{go}r@{co});
@#endfor

[name = 'IMD @{co}']
exp(IMD@{co}) = (1-exp(lambda@{co}))/exp(lambda@{co});

[name = 'Effective labor tax @{co}']
ttL@{co} = ttL - shockL@{co}*t@{co}/exp(w@{co}+l@{co});

[name = 'Effective capital tax @{co}']
ttK@{co} = ttK - shockK@{co}*t@{co}/(exp(r@{co}+k@{co}(-1))-del*exp(px@{co}+k@{co}(-1))+exp(pi@{co}));

[name = 'Effective subsidy rate @{co}']
s@{co} = sI + shockX@{co}*t@{co}/exp(px@{co}+x@{co}) ;

[name = 'Transfer @{co}']   %%%Transfer in transition is defined by initial equilibrium tax rates and removing tariff revenue t@{co}. This equation using effective tax rates and rebating tariffs is identical and removes the need to specify two different versions of the transfer.
transfer@{co} = ttL@{co}*(exp(w@{co}+l@{co})) + ttK@{co}*exp(r@{co}+k@{co}(-1)) - ttK@{co}*del*exp(px@{co}+k@{co}(-1))+ ttK@{co}*exp(pi@{co}) + t@{co} - s@{co}*exp(px@{co}+x@{co});

[name = 'Net aggregate profits diagnostic @{co}']
Pi_H@{co} = exp(pi@{co});

[name = 'Revenue subsidy tax diagnostic @{co}']
T_rs_H@{co} = T_rs@{co};

[name='Endogenous discount factor']
edf@{co} = exp(sdf@{co});
