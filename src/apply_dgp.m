function p = apply_dgp(p, dgp_id)
% apply_dgp.m
% ---------------------------------------------------------
% Apply a DGP override from dgp_library.m to an existing parameter struct p.
%
% Philosophy:
%   - stage_config.m controls the *learning environment* (loss mode, delay,
%     nuisance schedule, etc.).
%   - dgp_library.m controls the *data environment* (panel DGP + missingness
%     + holdout design).
%
% This file is kept small on purpose: it just merges p with the cataloged
% overrides.
% ---------------------------------------------------------

if nargin<2 || isempty(dgp_id)
    return;
end

d = dgp_library(dgp_id);

% Apply overrides
ov = d.p_override;
f = fieldnames(ov);
for j=1:numel(f)
    p.(f{j}) = ov.(f{j});
end

% Stamp for reporting/debugging
p.dgp_id = d.id;
if ~isfield(p,'dgp_name') || isempty(p.dgp_name)
    p.dgp_name = d.name;
end

end
