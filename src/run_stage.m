function out = run_stage(stage, p_override)
% run_stage.m (v6)
% ---------------------------------------------------------
% Runs one pedagogical stage (0..6). Optionally override parameters.
%
% Usage:
%   addpath(genpath('cbi_mc_matlab'));
%   out = run_stage(2);                    % stage 2 with defaults
%   p = default_params(); p.N=80; ...;
%   out = run_stage(4, p);                % user-provided overrides
%
% Output:
%   out.stage, out.meta
%   out.res   : run_mc result(s)
%   out.path  : output folder where tables/figures are written
% ---------------------------------------------------------

setup_paths();

[p, meta] = stage_config(stage);

if nargin>=2 && ~isempty(p_override)
    p = merge_structs(p, p_override);
end

% Create output folder
outdir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', sprintf('stage_%d', stage));
if ~exist(outdir, 'dir'); mkdir(outdir); end

out = struct();
out.stage = stage;
out.meta = meta;
out.path = outdir;

if meta.multi_scenario
    scenarios = {'A','B','C','D'};
    res = struct();
    for s=1:numel(scenarios)
        ps = p;
        ps.scenario = scenarios{s};
        res.(scenarios{s}) = run_mc(ps);
    end
    out.res = res;
else
    if ~meta.run_policy
        out.res = run_mc_arms_only(p);
    else
        out.res = run_mc(p);
    end
end

% Export one table + one figure (minimum) for the stage
report_stage(out, outdir);

end

% --- helper: merge structs (p_override wins) ---
function p = merge_structs(p, q)
f = fieldnames(q);
for j=1:numel(f)
    p.(f{j}) = q.(f{j});
end
end

% --- helper: arms-only MC wrapper ---
function res = run_mc_arms_only(p)
validate_params(p);
rng(p.seed);

res = struct();
res.p = p;
res.rep = cell(p.R,1);

for r=1:p.R
    [Y_true, F_true, lambda_true] = simulate_panel(p, r); %#ok<NASGU>
    X = build_context(lambda_true, p.T);
    [M_final, ~] = draw_missingness(X, p, r);
    [M0, holdout] = apply_holdout(M_final, X, p, r);
    Y_obs_init = Y_true; Y_obs_init(~M0) = NaN;
    action_mask = get_action_mask(M0, holdout, p);

    algo = run_arms_only(Y_true, Y_obs_init, M0, action_mask, p);

    arm_mse = local_arm_mse(algo.yhat_store, Y_true(:), action_mask(:));
    rep = struct();
    rep.r = r;
    rep.arm_mse = arm_mse;
    rep.policy_mse = NaN;
    rep.final_regret = NaN;
    rep.riskhat_dr = NaN(1,4);
    rep.riskhat_ipw = NaN(1,4);
    rep.riskhat_or = NaN(1,4);
    rep.riskhat_pi_dr = NaN;
    rep.algo = algo;
    res.rep{r} = rep;
end

res.summary = summarize_mc(res.rep);
end

function arm_mse = local_arm_mse(yhat_store, ytrue, amask)
idx = find(amask);
K = size(yhat_store,2);
arm_mse = NaN(1,K);
for k=1:K
    err = yhat_store(idx,k) - ytrue(idx);
    arm_mse(k) = mean(err.^2);
end
end
