%Parameters that do not vary across country
parameters bet phi psi del sig mu alpc gam th alp alpm ns fe v frisch bk ttL ttK sI revsub;
set_param_value('bet',bet);
if trade_bal == 2 | trade_bal == 3
    set_param_value('phi',100);
else
    set_param_value('phi',.0367^2);
end
%set_param_value('phi',100);
set_param_value('psi',psi_fric);
set_param_value('del',del);
set_param_value('sig',sig);
set_param_value('mu',mu);
set_param_value('alpc',alpc);
set_param_value('gam',gam);
set_param_value('th',th);
set_param_value('alp',alp);
set_param_value('alpm',alpm);
set_param_value('ns',ns);
set_param_value('fe',fe);
set_param_value('v',v);
set_param_value('frisch',frisch(1));
set_param_value('bk',bk);
set_param_value('ttL',ttL);
set_param_value('ttK',ttK);
set_param_value('sI',sI);
set_param_value('revsub',revsub);
