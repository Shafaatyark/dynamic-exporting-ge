%Country specific parameters
parameters J@{co} fH@{co} fL@{co} f0@{co} z@{co} Lbar@{co} pcss@{co} pxss@{co} ness@{co} rho@{co};
J@{co} = @{Js[co]};
fH@{co} = f1(@{co});
fL@{co} = f1(@{co});
f0@{co} = f0(@{co});
z@{co} = log(z(@{co}));
Lbar@{co} = Lbar(@{co});
pcss@{co} = log(PC(@{co}));
pxss@{co} = log(PI(@{co}));
ness@{co} = log(Ne(@{co}));
rho@{co} = rho(@{co});
varexo bbar@{co} shockK@{co} shockL@{co} shockX@{co};

%Pair specific parameters and exogenous variables
@#for co1 in countries
    varexo tau@{co}@{co1};
    @#if co!=co1
        parameters xicH@{co}@{co1} ximH@{co}@{co1} xixH@{co}@{co1} xicL@{co}@{co1} ximL@{co}@{co1} xixL@{co}@{co1} pcss@{co}@{co1} pxss@{co}@{co1} pmss@{co}@{co1};
        xicH@{co}@{co1} = log(xicHij(@{co},@{co1}));
        ximH@{co}@{co1} = log(ximHij(@{co},@{co1}));
        xixH@{co}@{co1} = log(xixHij(@{co},@{co1}));
        xicL@{co}@{co1} = log(xicLij(@{co},@{co1}));
        ximL@{co}@{co1} = log(ximLij(@{co},@{co1}));
        xixL@{co}@{co1} = log(xixLij(@{co},@{co1}));
        pcss@{co}@{co1} = log(Pcij(@{co},@{co1}));
        pxss@{co}@{co1} = log(Pxij(@{co},@{co1}));
        pmss@{co}@{co1} = log(Pmij(@{co},@{co1}));
    @#endif
@#endfor

%Country specific variables
var c@{co} l@{co} x@{co} k@{co} b@{co} t@{co} m@{co} rer@{co}
    lp@{co} n@{co} vd@{co} im@{co} pc@{co} px@{co} pm@{co} w@{co}
    r@{co} pd@{co} ne@{co} y@{co} d@{co} ims@{co} lambda@{co} IMD@{co} mu@{co}
    ttL@{co} ttK@{co} s@{co} transfer@{co} edf@{co} rim@{co}
    Pi_H@{co} T_rs_H@{co};
@#for go in goods
    var lambda@{go}@{co} A@{go}@{co} X@{go}@{co};
@#endfor
% Pair specific variables
@#for co1 in countries
    @#if co!=co1
        var n@{co}@{co1} nH@{co}@{co1} nL@{co}@{co1} n0@{co}@{co1} ex@{co}@{co1} pc@{co}@{co1} px@{co}@{co1} pm@{co}@{co1} ims@{co}@{co1} elastc@{co}@{co1} elastx@{co}@{co1} elastm@{co}@{co1};
        var vx0@{co}@{co1} dvH@{co}@{co1} dvL@{co}@{co1} kap0@{co}@{co1} kapH@{co}@{co1} kapL@{co}@{co1};
    @#endif
@#endfor
