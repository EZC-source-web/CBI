function dgp = dgp_library(dgp_id)
% dgp_library.m  (v7)
% ---------------------------------------------------------
% Central catalog of paper-grade DGPs for the CBI Monte Carlo.
%
% Robustness note:
%   This file avoids MATLAB line-continuation ("...") inside struct
%   constructors. Some MATLAB setups can raise "Invalid expression" errors
%   when comments or delimiters are combined with "..." in name/value lists.
%

% Econometric motivation (high-level):
%   Dynamic factor model with ragged edge / staggered releases and
%   arbitrary missingness patterns, as in nowcasting and large-panel macro.
%   Suggested citations to justify this DGP family:
%     - Bai & Ng (2002, Econometrica) — large approximate factor models.
%     - Giannone, Reichlin & Small (2008, JME) — nowcasting with ragged edge.
%     - Banbura & Modugno (2014, JAE) — factor models with arbitrary missingness.
%     - Rubin (1976, Biometrika) and Wooldridge (2007, JoE) — missing data + IPW logic.
%     - Kasy & Sautmann (2021, Econometrica) — learning in waves (batching).

% Interface:
%   d = dgp_library()            -> returns all DGP structs
%   d = dgp_library('DFM_CTX_STRONG') -> returns one DGP
%
% Each DGP:
%   .id, .name, .scenario
%   .p_override : struct of parameter overrides applied on top of defaults
%   .expected   : qualitative expectation (win/fail + mechanism)
% ---------------------------------------------------------

% Preallocate (keeps the file readable)
d = repmat(struct('id','', 'name','', 'scenario','', 'p_override',struct(), 'expected',''), 5, 1);

% =========================================================
% (1) No-context baseline
% =========================================================
d(1).id       = 'DFM_NO_CONTEXT';
d(1).name     = 'Homogeneous dynamic factor model (no contextual value)';
d(1).scenario = 'A';

o = struct();
o.scenario        = 'A';
o.phi             = 0.7;
o.sigma_eps       = 1.0;
o.target_obs_rate = 0.60;
o.holdout_mode    = 'random';
d(1).p_override = o;

d(1).expected = [ ...
    'Oracle(ctx) coincides with Best(static). ', ...
    'Used as a sanity check: any gains must come from exploration noise only.' ...
];

% =========================================================
% (2) Moderate context: weak heterogeneity (bridge)
% =========================================================
d(2).id       = 'DFM_CTX_MODERATE';
d(2).name     = 'Two-regime factor model with mild heterogeneity (bridge)';
d(2).scenario = 'E';

o = struct();
o.scenario        = 'E';
o.phi_idio_high   = 0.90;
o.phi_idio_low    = 0.20;
o.sigma_idio      = 0.80;
o.target_obs_rate = 0.60;
o.holdout_mode    = 'random';
d(2).p_override = o;

d(2).expected = [ ...
    'Context matters but only weakly: in short horizons, exploration + batching can dominate. ', ...
    'Bridge DGP (Stage 6) that is intentionally hard.' ...
];

% =========================================================
% (3) Strong context: clear arm switch (main)
% =========================================================
d(3).id       = 'DFM_CTX_STRONG';
d(3).name     = 'Two-regime factor model with strong heterogeneity (main)';
d(3).scenario = 'E2';

o = struct();
o.scenario          = 'E2';
o.phi_idio_high     = 0.98;
o.phi_idio_low      = 0.05;
o.sigma_idio_high   = 2.0;
o.sigma_idio_low    = 0.2;
o.lambda_scale_high = 0.5;
o.lambda_scale_low  = 2.0;
o.target_obs_rate   = 0.60;
o.holdout_mode      = 'random';
d(3).p_override = o;

d(3).expected = [ ...
    'Genuine contextual value: a feasible policy should beat Best(static) for large T. ', ...
    'Failure is expected only under severe sparsity / fragmentation or very aggressive exploration.' ...
];

% =========================================================
% (4) Strong context + sparse decision set (failure mode)
% =========================================================
d(4).id       = 'DFM_CTX_STRONG_SPARSE_HOLDOUT';
d(4).name     = 'Strong context but context-linked holdout/reveals (induces sparsity)';
d(4).scenario = 'E2';

o = struct();
o.scenario          = 'E2';
o.phi_idio_high     = 0.98;
o.phi_idio_low      = 0.05;
o.sigma_idio_high   = 2.0;
o.sigma_idio_low    = 0.2;
o.lambda_scale_high = 0.5;
o.lambda_scale_low  = 2.0;
o.holdout_mode      = 'logit';
% holdout regressors: X_it = [lambda_i, t/T] (no intercept; alpha calibrated internally)
o.holdout_beta      = [2.5; -1.0];
o.holdout_rate      = 0.15;
o.target_obs_rate   = 0.60;
d(4).p_override = o;

d(4).expected = [ ...
    'Isolates sparsity: some context bins receive very few decision cells (and hence few reveals), ', ...
    'so arm×context counts remain sparse even for moderate T.' ...
];

% =========================================================
% (5) Strong context, three regimes (optional sensitivity)
% =========================================================
d(5).id       = 'DFM_CTX_STRONG_3REG';
d(5).name     = 'Three-regime factor model (richer heterogeneity; optional)';
d(5).scenario = 'E2';

o = struct();
o.scenario          = 'E2';
o.regime_n          = 3;
o.lambda_scale_vec  = [2.0, 1.0, 0.4];
o.phi_idio_vec      = [0.05, 0.60, 0.98];
o.sigma_idio_vec    = [0.20, 0.80, 2.00];
o.target_obs_rate   = 0.60;
o.holdout_mode      = 'random';
d(5).p_override = o;

d(5).expected = [ ...
    'Sensitivity check: more than two regimes yields smoother oracle(ctx) gains, ', ...
    'but increases demands on discretization (bins) and feedback.' ...
];

% =========================================================
% Return one or all
% =========================================================
if nargin < 1 || isempty(dgp_id)
    dgp = d;
    return;
end

idx = find(strcmp({d.id}, dgp_id), 1, 'first');
if isempty(idx)
    ids = strjoin({d.id}, ', ');
    error('dgp_library:unknown', 'Unknown dgp_id="%s". Known ids: %s', dgp_id, ids);
end

dgp = d(idx);
end
