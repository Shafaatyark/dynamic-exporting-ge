@#include "dege_dynare_setup.mod"

@TAU21_ENDVAL_BLOCK@

shocks;
@REBATE_SHOCK_BLOCK@
@TAU21_SHOCK_BLOCK@
end;

perfect_foresight_setup(periods=600);
perfect_foresight_solver(maxit=50);
