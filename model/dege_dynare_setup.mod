@#include "dege_macros.txt"
@#define exporter = ["H","L","0"]
@#define goods = ["c","x","m"]

@#include "dege_params.mod"
@#for co in countries
    @#include "dege_vars_params.mod"
@#endfor


model;
@#for co in countries
    #lc@{co} = log(exp(pc@{co}+c@{co}-w@{co})*(1-alpc));
    #ctilde@{co} = (1/alpc)*(c@{co}+(alpc-1)*lc@{co});
    #pctilde@{co} = log(alpc) + pc@{co} + c@{co} - ctilde@{co};
@#endfor
@#for co in countries
    @#include "dege_locals.mod"
@#endfor
@#for co in countries
    @#include "dege_locals_trade.mod"
@#endfor
@#for co in countries
        @#include "dege_equations.mod"
@#endfor
[name = 'BMC']
@#for co in countries
    +b@{co}
@#endfor
=0;
end;

initval;
@#for co in countries
    @#include "dege_initial_values.mod"
@#endfor
end;
resid;
%model_diagnostics;
steady;
%check;
