function res = run_mc_paper(p, cfg)
% run_mc_paper.m
% ---------------------------------------------------------
% Memory-light Monte Carlo runner.
% - Does NOT store Y_true / full algo objects per replication.
% - Stores only scalars/vectors needed for paper exhibits.
%
% Output:
%   res.p
%   res.rep{r}  (light replication metrics)
%   res.summary (means + SEs)
% ---------------------------------------------------------

if nargin<2 || isempty(cfg)
    cfg = paper_mc_defaults();
end

validate_params(p);
rng(p.seed);

res = struct();
res.p = p;
% NOTE (parfor): do not index into a struct field inside a parfor.
% Use a separate sliced variable, then assign back to res.
rep = cell(p.R,1);

thr = cfg.sparsity_thr;
usePar = isfield(cfg,'use_parallel') && cfg.use_parallel;

if usePar
    % Best-effort: do not crash if no pool is available.
    try
        pool = gcp('nocreate'); %#ok<NASGU>
        if isempty(pool)
            parpool('local');
        end
        % Make sure workers see this package (path propagation can be fragile).
        try
            srcdir = fileparts(mfilename('fullpath'));
            srcdir = strrep(srcdir, '''', '''''');
            pctRunOnAll(sprintf("addpath(genpath('%s'))", srcdir));
        catch
            % best-effort
        end
    catch
        usePar = false;
    end
end

if usePar
    parfor r=1:p.R
        rep{r} = one_replication_paper(p, r, thr);
    end
else
    for r=1:p.R
        rep{r} = one_replication_paper(p, r, thr);
    end
end

res.rep = rep;

res.summary = summarize_mc_paper(res.rep);
end
