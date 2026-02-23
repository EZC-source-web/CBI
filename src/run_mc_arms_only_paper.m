function res = run_mc_arms_only_paper(p, cfg)
% run_mc_arms_only_paper.m
% ---------------------------------------------------------
% Memory-light arms-only runner (no learning/policy).
% Stores only arm risks + oracle contextual benchmark.
% ---------------------------------------------------------

if nargin<2 || isempty(cfg)
    cfg = paper_mc_defaults();
end

validate_params(p);

res = struct();
res.p = p;
% NOTE (parfor): do not index into a struct field inside a parfor.
% Use a separate sliced variable, then assign back to res.
rep = cell(p.R,1);

usePar = isfield(cfg,'use_parallel') && cfg.use_parallel;
if usePar
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
        rep{r} = one_replication_arms_only_paper(p, r);
    end
else
    for r=1:p.R
        rep{r} = one_replication_arms_only_paper(p, r);
    end
end

res.rep = rep;

res.summary = summarize_mc_paper(res.rep);
end
