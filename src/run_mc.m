function res = run_mc(p)
% run_mc.m
% ---------------------------------------------------------
% Main Monte Carlo entry point.
%
% Inputs:
%   p : parameter struct (see default_params.m)
%
% Outputs:
%   res.rep      : cell array of replication-level structs
%   res.summary  : aggregated summary (means and quantiles)
% ---------------------------------------------------------

validate_params(p);

rng(p.seed);

res = struct();
res.p = p;
res.rep = cell(p.R,1);

for r=1:p.R
    if p.verbose && mod(r, max(1,round(p.R/10)))==0
        fprintf('[MC] replication %d/%d\n', r, p.R);
    end
    res.rep{r} = one_replication(p, r);
end

res.summary = summarize_mc(res.rep);

end
