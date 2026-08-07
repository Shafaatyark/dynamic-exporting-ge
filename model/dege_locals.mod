%%%%%%%%%%%%%%%%%%%%%%%%%%% Local Variables (paths not reported) %%%%%%%%%%

@#if pref==0
    #uc@{co} = log( mu*((1-mu)/mu)^((1-mu)*(1-sig))*exp(-sig*c@{co}+(1-mu)*(1-sig)*(-w@{co}+pc@{co}))  );
    #ucf@{co} = log( mu*((1-mu)/mu)^((1-mu)*(1-sig))*exp(-sig*c@{co}(+1)+(1-mu)*(1-sig)*(-w@{co}(+1)+pc@{co}(+1)))  );
    #ul@{co} = -(1-mu)*exp(mu*(1-sig)*c@{co})*(Lbar@{co}-exp(l@{co}))^( -(sig*(1-mu) + mu));
@#endif
@#if pref==1
    #uc@{co} = -sig*c@{co};
    #ucf@{co} = -sig*c@{co}(+1);
    #ul@{co} = -mu*Lbar@{co}^(-1-1/frisch)*exp(l@{co})^(1/frisch);
@#endif
@#if pref==2
    #h@{co} = log( 1-mu*exp((1+1/frisch)*(l@{co}-log(Lbar@{co})+(bk/(1-bk))*c@{co}))/(1+1/frisch));
    #hf@{co} = log( 1-mu*exp((1+1/frisch)*(l@{co}(+1)-log(Lbar@{co})+(bk/(1-bk))*c@{co}(+1)))/(1+1/frisch));
    #uc@{co} = log( exp(-sig*(c@{co}+h@{co}))*(exp(h@{co}) - mu*(bk/(1-bk))*exp((1+1/frisch)*(l@{co}-log(Lbar@{co})+(bk/(1-bk))*c@{co})))    );
    #ucf@{co} = log( exp(-sig*(c@{co}(+1)+hf@{co}))*(exp(hf@{co}) - mu*(bk/(1-bk))*exp((1+1/frisch)*(l@{co}(+1)-log(Lbar@{co})+(bk/(1-bk))*c@{co}(+1))))    );
    #ul@{co} = -exp(-sig*(c@{co}(+1)+hf@{co}))*mu*exp((1+1/frisch)*(l@{co}-log(Lbar@{co})+(bk/(1-bk))*c@{co}) + c@{co}-l@{co});
@#endif
#sdf@{co} = log(bet*exp(ucf@{co}-uc@{co}+ pc@{co} - pc@{co}(+1)));
%#sdf@{co} = log(bet*exp(sig*(c@{co}-c@{co}(+1)) + (1-mu)*(1-sig)*(w@{co}-pc@{co}+pc@{co}(+1)-w@{co}(+1))+ pc@{co} - pc@{co}(+1)));
%#ucf@{co} = log( mu*((1-mu)/mu)^((1-mu)*(1-sig))*exp(-sig*c@{co}(+1)+(1-mu)*(1-sig)*(-w@{co}(+1)+pc@{co}(+1)))  );
%#uc@{co} = log( mu*((1-mu)/mu)^((1-mu)*(1-sig))*exp(-sig*c@{co}+(1-mu)*(1-sig)*(-w@{co}+pc@{co}))  );
#q@{co} = log(exp(sdf@{co})*(1-phi/(exp(2*(pd@{co}+y@{co})))*(b@{co}-bbar@{co})));
%#q@{co} = log(bet);
#mc@{co} = 1/exp(z@{co})*(exp(r@{co})/(alp*(1-alpm)))^(alp*(1-alpm))*(exp(w@{co})/((1-alp)*(1-alpm)))^((1-alp)*(1-alpm))*(exp(pm@{co})/alpm)^(alpm);
#psi@{co} = mc@{co}*alp*(1-alpm)/exp(r@{co});
#uI@{co}  = exp(x@{co})/(del*exp(k@{co}(-1))) - 1;
#Psi@{co} = psi/2*(uI@{co})^2;
#c@{co}@{co} = log(  exp(-gam*(pd@{co}-pctilde@{co})+ctilde@{co})  );
#x@{co}@{co} = log(  exp(-gam*(pd@{co}-px@{co})+x@{co})  );
#m@{co}@{co} = log(  exp(-gam*(pd@{co}-pm@{co})+m@{co})  );
#chic@{co}@{co} = n@{co};
#chix@{co}@{co} = n@{co};
#chim@{co}@{co} = n@{co};
% revenue subsidy rate
#s_sub@{co} = revsub * (1/(th-1));
#profit_factor@{co} = (1+s_sub@{co})/th;

#k@{co}@{co} = log(  psi@{co}*exp(th/(1-th)*(n@{co}-log(J@{co})))*(exp(c@{co}@{co}) + exp(x@{co}@{co}) + exp(m@{co}@{co}))/J@{co}  );
#pi@{co}@{co} = log( profit_factor@{co}*exp(pd@{co}-n@{co})*(exp(c@{co}@{co}) + exp(x@{co}@{co}) + exp(m@{co}@{co}))  );
#pc@{co}@{co} = pd@{co};
#px@{co}@{co} = pd@{co};
#pm@{co}@{co} = pd@{co};
@#for co1 in countries
    @#if co!=co1
        #chic@{co}@{co1} = log( exp((1-th)*xicH@{co}@{co1} + nH@{co}@{co1}) + exp((1-th)*xicL@{co}@{co1} + nL@{co}@{co1}) );
        #chix@{co}@{co1} = log( exp((1-th)*xixH@{co}@{co1} + nH@{co}@{co1}) + exp((1-th)*xixL@{co}@{co1} + nL@{co}@{co1}) );
        #chim@{co}@{co1} = log( exp((1-th)*ximH@{co}@{co1} + nH@{co}@{co1}) + exp((1-th)*ximL@{co}@{co1} + nL@{co}@{co1}) );
        #c@{co}@{co1} = log( exp(-gam*(tau@{co}@{co1}+pc@{co}@{co1} - pctilde@{co1}) + ctilde@{co1})  );
        #x@{co}@{co1} = log( exp(-gam*(tau@{co}@{co1}+px@{co}@{co1} - px@{co1}) + x@{co1})  );
        #m@{co}@{co1} = log( exp(-gam*(tau@{co}@{co1}+pm@{co}@{co1} - pm@{co1}) + m@{co1})  );
        #k@{co}@{co1} = log(  psi@{co}*exp(-n@{co}@{co1})*(exp(c@{co}@{co1} + 1/(1-th)*chic@{co}@{co1}) + exp(x@{co}@{co1} + 1/(1-th)*chix@{co}@{co1}) + exp(m@{co}@{co1} + 1/(1-th)*chim@{co}@{co1}))/J@{co}  );
        #pi@{co}@{co1} = log( profit_factor@{co}*exp(-n@{co}@{co1})*(exp(pc@{co}@{co1}+c@{co}@{co1}) + exp(px@{co}@{co1}+x@{co}@{co1}) + exp(pm@{co}@{co1}+m@{co}@{co1}))  );
        #pi@{co}@{co1}H = log( profit_factor@{co}*(exp(pc@{co}@{co1}+c@{co}@{co1}+(1-th)*xicH@{co}@{co1}-chic@{co}@{co1}) + exp(px@{co}@{co1}+x@{co}@{co1}+(1-th)*xixH@{co}@{co1}-chix@{co}@{co1}) + exp(pm@{co}@{co1}+m@{co}@{co1}+(1-th)*ximH@{co}@{co1}-chim@{co}@{co1}))  );
        #pi@{co}@{co1}L = log( profit_factor@{co}*(exp(pc@{co}@{co1}+c@{co}@{co1}+(1-th)*xicL@{co}@{co1}-chic@{co}@{co1}) + exp(px@{co}@{co1}+x@{co}@{co1}+(1-th)*xixL@{co}@{co1}-chix@{co}@{co1}) + exp(pm@{co}@{co1}+m@{co}@{co1}+(1-th)*ximL@{co}@{co1}-chim@{co}@{co1}))  );
        @#for ex in exporter
            #F@{ex}@{co}@{co1} = 1 - (1+v/f@{ex}@{co}*exp(kap@{ex}@{co}@{co1}))^(-1/v);
            #F@{ex}@{co}@{co1}lag = 1 - (1+v/f@{ex}@{co}*exp(kap@{ex}@{co}@{co1}(-1)))^(-1/v);
            #int@{ex}@{co}@{co1} = f@{ex}@{co}/(1-v)*(1 - (1+v/f@{ex}@{co}*exp(kap@{ex}@{co}@{co1}))^(-1/v)*(1+exp(kap@{ex}@{co}@{co1})/f@{ex}@{co}));
        @#endfor
        #pcalt@{co}@{co1} = pc@{co}@{co1} ;
        #pxalt@{co}@{co1} = px@{co}@{co1} ;
        #pmalt@{co}@{co1} = pm@{co}@{co1} ;
        #Jalt@{co}@{co1} = J@{co};
        #zetac@{co}@{co1} = tau@{co}@{co1};
        #zetax@{co}@{co1} = tau@{co}@{co1};
        #zetam@{co}@{co1} = tau@{co}@{co1};
        #fc@{co}@{co1} = (exp(w@{co})*(exp(nH@{co}@{co1})*intH@{co}@{co1} + exp(nL@{co}@{co1})*intL@{co}@{co1} + exp(n0@{co}@{co1})*int0@{co}@{co1}));
    @#else
        #fc@{co}@{co1} = 0;
        #n@{co}@{co1} = n@{co};
    @#endif
@#endfor
#piNT@{co} = pi@{co}@{co};

#fc@{co} =
@#for co1 in countries
    +fc@{co}@{co1}
@#endfor
+exp(w@{co}+ne@{co})*fe
;

#pi@{co} = log(
@#for co1 in countries
    +exp(n@{co}@{co1}+pi@{co}@{co1})
@#endfor
-fc@{co});

% total revenue subsidy
#Rev@{co}= exp(pd@{co})*(exp(c@{co}@{co}) + exp(x@{co}@{co}) + exp(m@{co}@{co}))
@#for co1 in countries
    @#if co1!=co
        +(exp(pc@{co}@{co1}+c@{co}@{co1}) + exp(px@{co}@{co1}+x@{co}@{co1}) + exp(pm@{co}@{co1}+m@{co}@{co1}))
    @#endif
@#endfor
;

#T_rs@{co} = s_sub@{co}*Rev@{co};
