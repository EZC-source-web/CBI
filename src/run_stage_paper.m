function out = run_stage_paper(stage, p_override, cfg)
% run_stage_paper.m
% ---------------------------------------------------------
% Paper-grade stage runner.
% Similar to run_stage.m, but:
%   - uses run_mc_paper (memory-light) to avoid storing massive replication objects
%   - fixes factor loadings across replications via p.lambda_fixed
%   - writes raw outputs into out/raw/ with unique names
%
% Inputs:
%   stage      : integer 0..7
%   p_override : struct with parameters to override stage defaults
%   cfg        : paper MC config (paper_mc_defaults)
%
% Output:
%   out.stage, out.meta, out.path, out.res
% ---------------------------------------------------------

if nargin<2, p_override = struct(); end
if nargin<3 || isempty(cfg), cfg = paper_mc_defaults(); end

setup_paths();

[p, meta] = stage_config(stage);

% override
p = merge_structs(p, p_override);

% Re-apply DGP overrides after merging, so scripts can change p.dgp_id.
if isfield(p,'dgp_id') && ~isempty(p.dgp_id)
    p = apply_dgp(p, p.dgp_id);
end

% enforce a deterministic lambda across replications (and across stages with same (N,T)).
seed_lambda = 444 + 1000*p.T + 10*p.N;
rng(seed_lambda);
p.lambda_fixed = p.sigma_lambda * randn(p.N,1);

% raw output folder
raw_root = fullfile(cfg.out_root, 'raw');
if ~exist(raw_root,'dir'); mkdir(raw_root); end

cfgTag = sprintf('stage_%d_s%s_T%d_B%d_bins%d_%d_c%s', stage, p.scenario, p.T, p.B, p.n_bins_lambda, p.n_bins_time, num2tag(p.ucb_c));
outdir = fullfile(raw_root, cfgTag);
if ~exist(outdir,'dir'); mkdir(outdir); end

out = struct();
out.stage = stage;
out.meta = meta;
out.path = outdir;

% run
if ~meta.run_policy
    out.res = run_mc_arms_only_paper(p, cfg);
else
    out.res = run_mc_paper(p, cfg);
end

% save a light .mat
save(fullfile(outdir, 'res.mat'), 'out');

end

% ---------------- helpers ----------------
function p = merge_structs(p, q)
f = fieldnames(q);
for j=1:numel(f)
    p.(f{j}) = q.(f{j});
end
end

function t = num2tag(x)
% Convert number to filesystem-safe tag (e.g., 0.1 -> 0p1)
if isnan(x)
    t = 'NaN';
    return;
end
s = sprintf('%.6g', x);
s = strrep(s, '.', 'p');
s = strrep(s, '-', 'm');
t = s;
end
