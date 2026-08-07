function dege_run_from_json(request_json_file, output_json_file)
%DEGE_RUN_FROM_JSON Run a validated tariff-path simulation from JSON.
%
% This is an additive bridge for the web API. It initializes the current
% repository model, simulates user-specified tau21/tau12 paths through the
% existing Dynare template, and exports selected series as JSON.

try
    request = jsondecode(fileread(request_json_file));
    response = dege_run_request(request, output_json_file);
    response.status = 'ok';
    write_json(output_json_file, response);
catch ME
    response = struct();
    response.status = 'error';
    response.message = ME.message;
    response.identifier = ME.identifier;
    response.stack = compact_stack(ME);
    write_json(output_json_file, response);
    rethrow(ME);
end

end

function response = dege_run_request(request, output_json_file)
repo_root = find_repo_root();
model_dir = fullfile(repo_root, 'model');
oldpwd = pwd;
cleanup_pwd = onCleanup(@() cd(oldpwd));
cd(repo_root);

addpath(model_dir);
dege_configure_dynare();

job_dir = fileparts(output_json_file);
if isempty(job_dir)
    job_dir = tempdir;
end
scratch_dir = fullfile(job_dir, 'dynare-work');
prepare_dynare_scratch(model_dir, scratch_dir);

scenario = get_struct_field(request, 'scenario', struct());
parameters = get_struct_field(request, 'parameters', struct());
tariff_paths = get_struct_field(request, 'tariffPaths', struct());
variables = to_cellstr(get_struct_field(request, 'variables', {'tau21','tau12','c1','l1','y1','im1'}));

tau21_path_post = require_numeric_vector(tariff_paths, 'tau21');
tau12_path_post = require_numeric_vector(tariff_paths, 'tau12');
if numel(tau21_path_post) ~= numel(tau12_path_post)
    error('dege_web:PathLengthMismatch', 'tau21 and tau12 paths must have the same length.');
end

initial_tau21 = get_numeric_field(scenario, 'initialTau21', 1.0);
initial_tau12 = get_numeric_field(scenario, 'initialTau12', 1.0);
rebate_type = get_text_field(scenario, 'rebateType', 'lumpsum');
tariff_scope = get_text_field(scenario, 'tariffScope', 'unilateral');

model_overrides = build_model_overrides(parameters, initial_tau21, initial_tau12);
init = dege_01_initialize_model(model_overrides{:});
fields = fieldnames(init);

global bet del sig th gam v alpm ns tauij alpc bk ttL ttK sI revsub
for i = 1:numel(fields)
    eval([fields{i} ' = init.(fields{i});']);
end
target = init;

fprintf('DEGE_PROGRESS symmetric_steady_state\n');
dege_02_symmetric_ss
fprintf('DEGE_PROGRESS asymmetric_steady_state\n');
dege_04_asymmetric_ss
fprintf('DEGE_PROGRESS dynare_configuration\n');
dege_07_write_dynare_macros(scratch_dir, num_c, J, dynamic, target.free_entry, target);

publish_caller_workspace_to_base();
result = run_web_tariff_replay( ...
    tau21_path_post, tau12_path_post, initial_tau21, initial_tau12, ...
    rebate_type, tariff_scope, target, scratch_dir);

response = build_response(request, result, variables, target);
end

function result = run_web_tariff_replay(tau21_path_post, tau12_path_post, initial_tau21, initial_tau12, rebate_type, tariff_scope, model_init, scratch_dir)
tau21_path_post = double(tau21_path_post(:)');
tau12_path_post = double(tau12_path_post(:)');
if isempty(tau21_path_post) || any(~isfinite(tau21_path_post)) || any(tau21_path_post <= 0)
    error('dege_web:InvalidTau21', 'tau21 path must contain positive finite gross tariff levels.');
end
if isempty(tau12_path_post) || any(~isfinite(tau12_path_post)) || any(tau12_path_post <= 0)
    error('dege_web:InvalidTau12', 'tau12 path must contain positive finite gross tariff levels.');
end

T_sim = numel(tau21_path_post);
rebate_config = resolve_rebate_config(rebate_type, tariff_scope);
mod_template = fullfile(scratch_dir, 'dege_transition.mod');
[tpl_dir, ~, ~] = fileparts(mod_template);
tmp_base = 'dege_job';
tmp_mod = [tmp_base '.mod'];
tmp_mod_path = fullfile(tpl_dir, tmp_mod);

[tariff_shock_block, rebate_shock_block, endval_block] = build_web_dynare_blocks( ...
    tau21_path_post, tau12_path_post, rebate_config);
write_web_mod_with_shocks(mod_template, tmp_mod_path, ...
    tariff_shock_block, rebate_shock_block, endval_block, T_sim);

oldpwd = pwd;
cd(tpl_dir);
cleanup_pwd = onCleanup(@() cd(oldpwd));

evalin('base', 'clear M_ oo_ options_ internal_options_ ys0_ ex0_ bayestopt_ estim_params_');
fprintf('DEGE_PROGRESS perfect_foresight_transition\n');
evalc('dynare(tmp_mod, ''noclearall'', ''nolog'', ''nowarn'');');

M_replay = evalin('base', 'M_');
oo_replay = evalin('base', 'oo_');
metrics_replay = compute_metrics_from_dynare_outputs(M_replay, oo_replay, T_sim, model_init.pref);

result = struct();
result.M_replay = M_replay;
result.oo_replay = oo_replay;
result.metrics_replay = metrics_replay;
result.tau21_path_full = [initial_tau21 tau21_path_post];
result.tau12_path_full = [initial_tau12 tau12_path_post];
result.tau_path_post = tau21_path_post;
result.T_sim = T_sim;
result.initial_tau21 = initial_tau21;
result.initial_tau12 = initial_tau12;
result.rebate_type_used = rebate_config.type;
result.rebate_tag_used = rebate_config.tag;
result.rebate_shock_vars_used = rebate_config.shock_vars;
result.model_init = model_init;
end

function response = build_response(request, result, variables, model_init)
M = result.M_replay;
oo = result.oo_replay;
T_sim = result.T_sim;
need_len = T_sim + 2;

periods = 0:(need_len - 1);
if any(strcmp(variables, '*'))
    variables = [cellstr(M.exo_names); cellstr(M.endo_names)];
end
[series, missing] = extract_requested_series(M, oo, variables, need_len);

response = struct();
response.mode = 'live simulation';
response.engine = runtime_engine();
response.message = sprintf('Simulation completed through %s and Dynare.', response.engine);
response.scenario = get_struct_field(request, 'scenario', struct());
response.parameters = model_init;
response.periods = periods;
response.metrics = result.metrics_replay;
response.variables = build_variable_catalog(M, oo);
response.series = series;
response.missingVariables = missing;
response.rebateTypeUsed = result.rebate_type_used;
response.tariffPaths = struct( ...
    'tau21', result.tau21_path_full, ...
    'tau12', result.tau12_path_full);
end

function publish_caller_workspace_to_base()
vars = evalin('caller', 'whos');
skip = {'request','response','result','cleanup_pwd','oldpwd','job_dir','scratch_dir'};
for i = 1:numel(vars)
    name = vars(i).name;
    if any(strcmp(name, skip))
        continue
    end
    assignin('base', name, evalin('caller', name));
end
end

function [series, missing] = extract_requested_series(M, oo, variables, need_len)
series = struct();
missing = {};
endo_names = cellstr(M.endo_names);
exo_names = cellstr(M.exo_names);

for i = 1:numel(variables)
    name = variables{i};
    if isempty(name)
        continue
    end

    endo_idx = find(strcmp(name, endo_names), 1);
    exo_idx = find(strcmp(name, exo_names), 1);
    if ~isempty(endo_idx)
        raw = oo.endo_simul(endo_idx, :);
        raw = pad_or_trim(raw(:)', need_len);
        item = build_series_item(name, label_for_variable(name), 'endogenous', raw, is_log_like(name));
        series.(name) = item;
    elseif ~isempty(exo_idx)
        raw = oo.exo_simul(:, exo_idx)';
        raw = pad_or_trim(raw(:)', need_len);
        item = build_series_item(name, label_for_variable(name), 'exogenous', raw, starts_with(name, 'tau'));
        series.(name) = item;
    else
        missing{end + 1} = name; %#ok<AGROW>
    end
end
end

function item = build_series_item(name, label, type, raw, use_exp)
raw = double(raw(:)');
if use_exp
    level = exp(raw);
else
    level = raw;
end

if isempty(raw)
    log_change = [];
    pct_change = [];
else
    if use_exp
        log_change = raw - raw(1);
    else
        base = level(1);
        if abs(base) > 1e-12
            log_change = log(max(level, 1e-12)) - log(max(base, 1e-12));
        else
            log_change = level - base;
        end
    end
    base = level(1);
    if abs(base) > 1e-12
        pct_change = 100 .* (level ./ base - 1);
    else
        pct_change = zeros(size(level));
    end
end

item = struct();
item.name = name;
item.label = label;
item.type = type;
item.raw = raw;
item.level = level;
item.log_change = log_change;
item.percent_change = pct_change;
item.rate_percent = 100 .* (level - 1);
end

function catalog = build_variable_catalog(M, ~)
endo_names = cellstr(M.endo_names);
exo_names = cellstr(M.exo_names);
n = numel(endo_names) + numel(exo_names);
catalog = repmat(struct('name', '', 'label', '', 'type', '', 'defaultTransform', ''), n, 1);
k = 0;
for i = 1:numel(exo_names)
    k = k + 1;
    catalog(k).name = exo_names{i};
    catalog(k).label = label_for_variable(exo_names{i});
    catalog(k).type = 'exogenous';
    if starts_with(exo_names{i}, 'tau')
        catalog(k).defaultTransform = 'rate_percent';
    else
        catalog(k).defaultTransform = 'raw';
    end
end
for i = 1:numel(endo_names)
    k = k + 1;
    catalog(k).name = endo_names{i};
    catalog(k).label = label_for_variable(endo_names{i});
    catalog(k).type = 'endogenous';
    if is_log_like(endo_names{i})
        catalog(k).defaultTransform = 'log_change';
    else
        catalog(k).defaultTransform = 'raw';
    end
end
catalog = catalog(1:k);
end

function model_overrides = build_model_overrides(parameters, initial_tau21, initial_tau12)
defaults = dege_01_initialize_model();
model_overrides = {};
if isempty(parameters) || ~isstruct(parameters)
    parameters = struct();
end
fields = fieldnames(parameters);
for i = 1:numel(fields)
    name = fields{i};
    value = parameters.(name);
    if strcmp(name, 'oneElasticity')
        if logical(value)
            model_overrides = [model_overrides, {'1elast', true}]; %#ok<AGROW>
        end
    elseif strcmp(name, 'EffEcon')
        if logical(value)
            model_overrides = [model_overrides, {'EffEcon', true}]; %#ok<AGROW>
        end
    elseif strcmp(name, 'tauij')
        error('dege_web:ReservedParameter', 'tauij is controlled by scenario initial tariffs.');
    elseif isfield(defaults, name)
        model_overrides = [model_overrides, {name, value}]; %#ok<AGROW>
    else
        error('dege_web:UnknownParameter', 'Unknown model parameter: %s', name);
    end
end

tauij = [1 initial_tau12; initial_tau21 1];
model_overrides = [model_overrides, {'tauij', tauij}];
end

function [tariff_shock_block, rebate_shock_block, endval_block] = build_web_dynare_blocks(tau21_path_post, tau12_path_post, rebate_config)
T_sim = numel(tau21_path_post);
periods_str = format_dynare_list(1:T_sim, '%d', 20);
tau21_values = format_dynare_list(log(tau21_path_post), '%.15g', 6);
tau12_values = format_dynare_list(log(tau12_path_post), '%.15g', 6);

tariff_shock_block = sprintf([ ...
    '  var tau21;\n' ...
    '  periods %s;\n' ...
    '  values  %s;\n' ...
    '  var tau12;\n' ...
    '  periods %s;\n' ...
    '  values  %s;\n' ], periods_str, tau21_values, periods_str, tau12_values);

rebate_shock_block = '';
if ~isempty(rebate_config.shock_vars)
    ones_str = format_dynare_list(ones(1, T_sim), '%.15g', 20);
    for i = 1:numel(rebate_config.shock_vars)
        rebate_shock_block = [rebate_shock_block, sprintf([ ...
            '  var %s;\n' ...
            '  periods %s;\n' ...
            '  values  %s;\n' ], rebate_config.shock_vars{i}, periods_str, ones_str)]; %#ok<AGROW>
    end
end

shockX1 = double(any(strcmp(rebate_config.shock_vars, 'shockX1')));
shockX2 = double(any(strcmp(rebate_config.shock_vars, 'shockX2')));
shockL1 = double(any(strcmp(rebate_config.shock_vars, 'shockL1')));
shockL2 = double(any(strcmp(rebate_config.shock_vars, 'shockL2')));
shockK1 = double(any(strcmp(rebate_config.shock_vars, 'shockK1')));
shockK2 = double(any(strcmp(rebate_config.shock_vars, 'shockK2')));

endval_block = sprintf([ ...
    'endval;\n' ...
    '@#for co in countries\n' ...
    '    @#include "dege_terminal_values.mod"\n' ...
    '@#endfor\n' ...
    '  tau21 = %.15g;\n' ...
    '  tau12 = %.15g;\n' ...
    '  shockX1 = %.15g;\n' ...
    '  shockX2 = %.15g;\n' ...
    '  shockL1 = %.15g;\n' ...
    '  shockL2 = %.15g;\n' ...
    '  shockK1 = %.15g;\n' ...
    '  shockK2 = %.15g;\n' ...
    'end;\n' ...
    'steady;\n'], ...
    log(tau21_path_post(end)), log(tau12_path_post(end)), ...
    shockX1, shockX2, shockL1, shockL2, shockK1, shockK2);
end

function rebate_config = resolve_rebate_config(rebate_type, tariff_scope)
key = lower(regexprep(strtrim(to_char(rebate_type)), '[^a-z0-9]', ''));
scope = lower(regexprep(strtrim(to_char(tariff_scope)), '[^a-z0-9]', ''));
if ismember(scope, {'bilateral','global'})
    suffixes = {'1', '2'};
else
    suffixes = {'1'};
end

switch key
    case {'invsub', 'investment', 'investmentsubsidy', 'shockx', 'shockx1'}
        base = 'shockX';
        tag = 'InvSub';
        type = 'invsub';
    case {'labtax', 'labor', 'labortax', 'labour', 'labourtax', 'shockl', 'shockl1'}
        base = 'shockL';
        tag = 'LabTax';
        type = 'labtax';
    case {'captax', 'capital', 'capitaltax', 'shockk', 'shockk1'}
        base = 'shockK';
        tag = 'CapTax';
        type = 'captax';
    case {'lumpsum', 'lump', 'transfer', 'none', 'noshock'}
        base = '';
        tag = 'LumpSum';
        type = 'lumpsum';
    otherwise
        error('dege_web:UnknownRebateType', 'Unknown rebateType: %s', to_char(rebate_type));
end

shock_vars = {};
if ~isempty(base)
    for i = 1:numel(suffixes)
        shock_vars{end + 1} = [base suffixes{i}]; %#ok<AGROW>
    end
end

rebate_config = struct('type', type, 'tag', tag, 'shock_vars', {shock_vars});
end

function write_web_mod_with_shocks(template_file, out_file, tariff_shock_block, rebate_shock_block, endval_block, T_sim)
txt = fileread(template_file);
txt = regexprep(txt, 'perfect_foresight_setup\(periods=\d+\);', ...
    sprintf('perfect_foresight_setup(periods=%d);', T_sim));
txt = strrep(txt, '@TAU21_SHOCK_BLOCK@', tariff_shock_block);
txt = strrep(txt, '@REBATE_SHOCK_BLOCK@', rebate_shock_block);
txt = strrep(txt, '@SHOCKX1_BLOCK@', rebate_shock_block);
txt = strrep(txt, '@TAU21_ENDVAL_BLOCK@', endval_block);
if text_contains(txt, '@TAU21_SHOCK_BLOCK@') || text_contains(txt, '@REBATE_SHOCK_BLOCK@') ...
        || text_contains(txt, '@SHOCKX1_BLOCK@') || text_contains(txt, '@TAU21_ENDVAL_BLOCK@')
    error('dege_web:UnreplacedPlaceholder', 'Generated Dynare file still has an unreplaced placeholder.');
end
fid = fopen(out_file, 'w');
if fid < 0
    error('dege_web:TempFileOpenFailed', 'Could not write temporary Dynare file: %s', out_file);
end
fwrite(fid, txt);
fclose(fid);
end

function metrics = compute_metrics_from_dynare_outputs(M, oo, T_sim, pref)
c1_log = get_endo_series(oo, M.endo_names, 'c1');
l1_log = get_endo_series(oo, M.endo_names, 'l1');
if pref == 0
    [welf, ssUtil] = compute_welfare_from_paths( ...
        c1_log(1:(T_sim + 2)), l1_log(1:(T_sim + 2)), M, T_sim);
else
    % The source welfare-equivalent statistic is specific to pref == 0.
    % Do not report a misleading Cobb-Douglas equivalent for other switches.
    welf = [];
    ssUtil = [];
end

bet = get_param(M, 'bet');
ex21_log = get_endo_series(oo, M.endo_names, 'ex21');
y1_log = get_endo_series(oo, M.endo_names, 'y1');
tau21 = exp(get_exo_series(oo, M.exo_names, 'tau21'));
shockX1 = get_exo_series_or_default(oo, M.exo_names, 'shockX1', 0, T_sim + 2);

ex21 = exp(ex21_log(1:(T_sim + 2)));
y1 = exp(y1_log(1:(T_sim + 2)));
tau21 = tau21(1:(T_sim + 2));
shockX1 = shockX1(1:(T_sim + 2));
rev_raw = shockX1 .* (tau21 - 1) .* ex21;
rev_try = rev_raw ./ max(y1, 1e-12);
[~, revPV1_raw] = present_value_with_tail(rev_raw, bet, T_sim);
[~, revPV1_try] = present_value_with_tail(rev_try, bet, T_sim);

metrics = struct('welf', welf, 'ssUtil', ssUtil, ...
    'revPV1_raw', revPV1_raw, 'revPV1_try', revPV1_try);
end

function [welf, ssUtil] = compute_welfare_from_paths(c1_log, l1_log, M, T_sim)
bet = get_param(M, 'bet');
mu = get_param(M, 'mu');
sig = get_param(M, 'sig');
Lbar = get_param(M, 'Lbar1');
c = exp(c1_log(:)');
l = exp(l1_log(:)');
css = c(1);
lss = l(1);
c_tr = c(2:(T_sim + 1));
l_tr = l(2:(T_sim + 1));
cssT = c(T_sim + 2);
lssT = l(T_sim + 2);
leisure_tr = max(Lbar - l_tr, 1e-12);
u_tr = ((c_tr .^ mu) .* (leisure_tr .^ (1 - mu))) .^ (1 - sig) / (1 - sig);
uss = ((css ^ mu) * (max(Lbar - lss, 1e-12) ^ (1 - mu))) ^ (1 - sig) / (1 - sig);
ussT = ((cssT ^ mu) * (max(Lbar - lssT, 1e-12) ^ (1 - mu))) ^ (1 - sig) / (1 - sig);
weights = bet .^ (0:(T_sim - 1));
numer = (1 - bet) * sum(weights .* u_tr) + (bet ^ T_sim) * ussT;
welf = 100 * (((numer / uss) ^ (1 / (mu * (1 - sig)))) - 1);
ssUtil = 100 * (((ussT / uss) ^ (1 / (mu * (1 - sig)))) - 1);
end

function [pv_raw, pv_norm] = present_value_with_tail(y, bet, T_sim)
y = y(:)';
y_active = y(2:(T_sim + 1));
y_terminal = y(T_sim + 2);
disc = bet .^ (0:(T_sim - 1));
pv_raw = sum(disc .* y_active) + (bet ^ T_sim) * (y_terminal / (1 - bet));
pv_norm = (1 - bet) * pv_raw;
end

function x = get_endo_series(oo, name_matrix, vname)
idx = find(strcmp(vname, cellstr(name_matrix)), 1);
if isempty(idx)
    error('dege_web:MissingEndogenous', 'Endogenous variable %s not found.', vname);
end
x = oo.endo_simul(idx, :);
end

function x = get_exo_series(oo, name_matrix, vname)
idx = find(strcmp(vname, cellstr(name_matrix)), 1);
if isempty(idx)
    error('dege_web:MissingExogenous', 'Exogenous variable %s not found.', vname);
end
x = oo.exo_simul(:, idx)';
end

function x = get_exo_series_or_default(oo, name_matrix, vname, default_value, need_len)
idx = find(strcmp(vname, cellstr(name_matrix)), 1);
if isempty(idx)
    x = default_value * ones(1, need_len);
    return
end
x = oo.exo_simul(:, idx)';
x = pad_or_trim(x, need_len);
end

function val = get_param(M, pname)
idx = find(strcmp(pname, cellstr(M.param_names)), 1);
if isempty(idx)
    error('dege_web:MissingParameter', 'Parameter %s not found.', pname);
end
val = M.params(idx);
end

function tf = is_log_like(name)
raw_level_names = {'b1','b2','t1','t2','ttL1','ttL2','ttK1','ttK2','s1','s2', ...
    'transfer1','transfer2','edf1','edf2','mu1','mu2','Pi_H1','Pi_H2','T_rs_H1','T_rs_H2'};
tf = ~any(strcmp(name, raw_level_names));
end

function label = label_for_variable(name)
labels = containers.Map();
labels('tau21') = 'Home tariff on Foreign goods';
labels('tau12') = 'Foreign tariff on Home goods';
labels('c1') = 'Home consumption';
labels('l1') = 'Home labor';
labels('y1') = 'Home output';
labels('im1') = 'Home nominal imports';
labels('rim1') = 'Home real imports';
labels('ex12') = 'Home exports to Foreign';
labels('ex21') = 'Foreign exports to Home';
labels('w1') = 'Home wage';
labels('pc1') = 'Home consumption price';
labels('px1') = 'Home investment price';
labels('pm1') = 'Home materials price';
labels('k1') = 'Home capital';
labels('n1') = 'Home firm mass';
labels('s1') = 'Home subsidy rate';
labels('b1') = 'Home bonds/trade balance state';
labels('lambda1') = 'Home domestic expenditure share';
labels('IMD1') = 'Home import penetration';
if isKey(labels, name)
    label = labels(name);
else
    label = name;
end
end

function out = format_dynare_list(vals, fmt, chunk_size)
vals = vals(:)';
parts = cell(1, numel(vals));
for i = 1:numel(vals)
    parts{i} = sprintf(fmt, vals(i));
end
lines = {};
for i = 1:chunk_size:numel(parts)
    j = min(i + chunk_size - 1, numel(parts));
    lines{end + 1} = strjoin(parts(i:j), ' '); %#ok<AGROW>
end
out = strjoin(lines, sprintf('\n          '));
end

function x = pad_or_trim(x, need_len)
x = x(:)';
if numel(x) >= need_len
    x = x(1:need_len);
elseif ~isempty(x)
    x = [x, repmat(x(end), 1, need_len - numel(x))];
end
end

function value = require_numeric_vector(S, field_name)
if ~isstruct(S) || ~isfield(S, field_name)
    error('dege_web:MissingField', 'Missing field: %s', field_name);
end
value = double(S.(field_name)(:)');
if isempty(value) || any(~isfinite(value)) || any(value <= 0)
    error('dege_web:InvalidNumericVector', '%s must be positive and finite.', field_name);
end
end

function value = get_numeric_field(S, field_name, default_value)
if isstruct(S) && isfield(S, field_name) && ~isempty(S.(field_name))
    value = double(S.(field_name));
else
    value = default_value;
end
if ~isscalar(value) || ~isfinite(value) || value <= 0
    error('dege_web:InvalidNumericField', '%s must be a positive finite scalar.', field_name);
end
end

function value = get_text_field(S, field_name, default_value)
if isstruct(S) && isfield(S, field_name) && ~isempty(S.(field_name))
    value = to_char(S.(field_name));
else
    value = default_value;
end
end

function value = get_struct_field(S, field_name, default_value)
if isstruct(S) && isfield(S, field_name)
    value = S.(field_name);
else
    value = default_value;
end
end

function values = to_cellstr(value)
if iscell(value)
    values = cellfun(@(x) to_char(x), value, 'UniformOutput', false);
elseif ischar(value)
    values = {value};
else
    values = {};
end
end

function prepare_dynare_scratch(model_dir, scratch_dir)
if ~exist(scratch_dir, 'dir')
    mkdir(scratch_dir);
end
files = {
    'dege_transition.mod', ...
    'dege_dynare_setup.mod', ...
    'dege_params.mod', ...
    'dege_vars_params.mod', ...
    'dege_locals.mod', ...
    'dege_locals_trade.mod', ...
    'dege_equations.mod', ...
    'dege_initial_values.mod', ...
    'dege_terminal_values.mod'};
for i = 1:numel(files)
    source_file = fullfile(model_dir, files{i});
    if exist(source_file, 'file') ~= 2
        error('dege:dynare:MissingModelFile', ...
            'Required Dynare source file is missing: %s', source_file);
    end
    copyfile(source_file, fullfile(scratch_dir, files{i}));
end
end

function name = runtime_engine()
if exist('OCTAVE_VERSION', 'builtin') ~= 0
    name = 'GNU Octave';
else
    name = 'MATLAB';
end
end

function tf = starts_with(value, prefix)
value = to_char(value);
prefix = to_char(prefix);
tf = numel(value) >= numel(prefix) && strcmp(value(1:numel(prefix)), prefix);
end

function tf = text_contains(value, pattern)
tf = ~isempty(strfind(value, pattern)); %#ok<STREMP>
end

function value = to_char(raw)
if ischar(raw)
    value = raw;
elseif iscell(raw) && numel(raw) == 1
    value = to_char(raw{1});
else
    try
        value = char(raw);
    catch
        value = num2str(raw);
    end
end
end

function write_json(output_json_file, response)
out_dir = fileparts(output_json_file);
if ~isempty(out_dir) && ~isfolder(out_dir)
    mkdir(out_dir);
end
txt = jsonencode(response);
fid = fopen(output_json_file, 'w');
if fid < 0
    error('dege_web:JsonWriteFailed', 'Could not write output JSON: %s', output_json_file);
end
fwrite(fid, txt, 'char');
fclose(fid);
end

function stack = compact_stack(ME)
stack = repmat(struct('file', '', 'name', '', 'line', 0), numel(ME.stack), 1);
for i = 1:numel(ME.stack)
    stack(i).file = ME.stack(i).file;
    stack(i).name = ME.stack(i).name;
    stack(i).line = ME.stack(i).line;
end
end

function repo_root = find_repo_root()
here = fileparts(mfilename('fullpath'));
repo_root = fileparts(here);
if exist(fullfile(here, 'dege_01_initialize_model.m'), 'file') ~= 2
    error('dege_web:RepoRootNotFound', 'Could not locate the public model directory.');
end
end
