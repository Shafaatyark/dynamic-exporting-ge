function [init] = dege_01_initialize_model(varargin)
%Initializes model with chosen parameters and assigns default parameters
%where none are assigned by the user. Use name-value overrides, e.g.
%dege_01_initialize_model('gam',4), or call dege_01_initialize_model() for defaults.
%Suite flags such as dege_01_initialize_model('EffEcon',true) expand to several
%model parameter overrides before explicit individual overrides are applied.
%Primitives default parameters
init.num_c = 2;                  %number of countries in final calibration.
init.J = ones(init.num_c,1);
init.dynamic = 1;                %1 - heterogeneneous firms and exporter dynamics (Bench)                            %0 - representative firm
init.trade_bal = 0;              %0 - noncontingent bond, SS imbalances (Bench)
                            %1 - noncontingent bond, SS balanced
                            %2 - financial autarky, trade balanced
                            %3 - financial autarky, SS imbalances
init.free_entry = 1;             %0 - fixed entry
                            %1 - free entry (Bench)
init.trade_comp = 1;             %0 - intensity of trade same for all goods
                            %1 - intensity matches data (Bench)
init.elast_labor = 1;            %0 - inelastic labor (L=0.99)
                            %1 - Elastic labor (Bench)
init.pref = 0;                   %0 - CD (Bench)
                            %1 - MaCurdy (1981)
                            %2 - Boppart Krusell (2020)

%Steady State Targets default parameters
init.Nx = 0.2;          %Export participation - 20% of firms export
%Important moments for benchmark
init.churnx = 0.05;    %Average churning across countries.
%Important moments for ELC
init.churnn = 0.15;
% inc_share_data = (1-.248)^(1/5);  %Matching contribution of new exporters in last five years from the data. Sensitivity. Change name in model results.
init.GOVA = 2;         %Gross output relative to value added for capital and intermediate goods
init.GOVAc = 2;      %Gross output to value added for consumption goods
init.WLVA = 0.6;        %Labor share of value added
init.RKVA = 0.165;
init.gdp = 1;
init.Lbar = 1;
init.IMY = .15;
init.Xshare = .2;
init.Mshare = .6;
init.Cshare = .2;


%Parameters default values
%External parameters
init.bet = 0.96;     %discount factor - Sims RBC notes says .98 without adjusting for growth. https://www3.nd.edu/~esims1/rbc_model_grad.pdf Need higher beta to get a higher investment rate (PI*I/PY~17%)
% bet = 0.98;
init.del = 0.1;      %capital stock depreciation
init.sig = 1.001;
init.frisch=2;
init.th = 6;         %elasticity of substitution between varieties within source. markup = th/(th-1)
init.gam = 4;        %elasticity of substitution between bundles from different sources
init.bk = 0.2;       %The parameter v from Boppart Krusell (2020)
init.v=0.6494047;    %From Mix (2023)

%Internal parameters
init.ns = 0.98;      %Set to match incumbent share for firms (see AC 2014)
init.tauij = [1 1.04;
    1.04 1];
init.ttL = 0.272;
init.ttK = 0.147;
init.sI = 0;
init.psi_fric = 0.4;             %Need investment frictions in the static exporter model.  Apply for all models.
init.revsub = 0;     % if switches to 1, revenue subsidy fixes away markups

if nargin > 0
    suite_params = struct();
    if nargin == 1 && isstruct(varargin{1})
        user_params = varargin{1};
        % Expand supported suite flags before applying explicit overrides.
        if isfield(user_params,'EffEcon')
            if isequal(user_params.EffEcon,true)
                suite_params.revsub = 1;
                suite_params.ttK = 0;
                suite_params.ttL = 0;
            end
            user_params = rmfield(user_params,'EffEcon');
        end
    else
        if mod(nargin,2) ~= 0
            error('dege:initialize:InvalidInputs', ...
                'Use dege_01_initialize_model(''param'',value,...) with name-value pairs.');
        end
        user_params = struct();
        for i = 1:2:nargin
            % Parse suite flags separately because names like "1elast" are not valid struct fields.
            param_name = varargin{i};
            if ~ischar(param_name)
                try
                    param_name = char(param_name);
                catch
                end
            end
            if ~ischar(param_name)
                error('dege:initialize:InvalidParameterName', ...
                    'Parameter names must be character vectors or scalar strings.');
            end
            param_value = varargin{i+1};
            if strcmp(param_name,'EffEcon')
                if isequal(param_value,true)
                    suite_params.revsub = 1;
                    suite_params.ttK = 0;
                    suite_params.ttL = 0;
                end
            elseif strcmp(param_name,'1elast')
                if isequal(param_value,true)
                    suite_params.dynamic = 0;
                    suite_params.trade_comp = 0;
                    suite_params.free_entry = 0;
                end
            else
                if ~isvarname(param_name)
                    error('dege:initialize:InvalidParameterName', ...
                        'Parameter name "%s" is not a valid model parameter or suite flag.', param_name);
                end
                user_params.(param_name) = param_value;
            end
        end
    end

    % Suite defaults are applied first so explicit individual params can overwrite them.
    suite_fields = fieldnames(suite_params);
    for i = 1:numel(suite_fields)
        init.(suite_fields{i}) = suite_params.(suite_fields{i});
    end

    fields = fieldnames(user_params);
    for i = 1:numel(fields)
        if strcmp(fields{i},'none')
            continue
        end
        init.(fields{i}) = user_params.(fields{i});
    end
end

%Initialize other variables that depend on user inputs

init.ent5 = 8.0585707*init.churnx;     %Share of exports contributed by firms with up to five years of tenure.  Constant comes from Mexican data.
init.alpm = (init.GOVA-1).*init.th./(init.GOVA.*(init.th-1));    %materials share in CD production. Set to make gross output to value added equal to data for investment and material goods.
init.alpc = (init.GOVAc-1)/(init.GOVAc*(1-1/init.GOVA));        %material share in final consumption production.

if init.pref==1
    init.frisch = 0.5;         %Macurdy (1981) preferences with frisch and IES from Heathcote, Storesletten, Violante (2014)
    init.sig = 1.7;
end
if init.dynamic==0
    init.Nx = 0.999;
    init.ns = 0.9991;
    init.churnn = init.ns*.998*(1-init.Nx)/init.Nx;
    init.churnx = init.churnn;
    init.ent5 = nan;
end
if init.GOVA == init.GOVAc
    init.alpc = .9999;
end





end
