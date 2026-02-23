function p = default_params()
% default_params.m (v6)
% ---------------------------------------------------------
% Default configuration for the Monte Carlo experiments.
% The package is designed to be toolbox-free and robust.
%
% IMPORTANT (data release interpretation):
% - M_final(i,t)=1 : ultimately observed after all releases (Omega)
% - holdout(i,t)=1 : delayed-release cells (subset of Omega)
% - M0(i,t)=1      : available at decision time (vintage)
%
% Stages 0..6 (pedagogical ladder) are configured in stage_config.m.
% ---------------------------------------------------------

p = struct();

% --- Reproducibility ---
p.seed = 12345;

% --- Panel size / Monte Carlo ---
p.N = 50;
p.T = 120;
p.R = 20;        % replications

% --- DGP / scenario selector ('A','B','C','D','E','E2') ---
% A: baseline linear factor (both nuisances can be correctly specified)
% B: outcome misspec (m-hat wrong; e-hat correct)
% C: propensity misspec (e-hat wrong; m-hat can be correct)
% D: both misspec (stress test)
% E: baseline context (weak heterogeneity; may not beat best static)
% E2: strong context heterogeneity (two regimes; policy should beat best static)
p.scenario = 'A';

% Outcome nonlinearity strength (scenario B)
p.kappa = 0.3;

% Propensity nonlinearity strength (scenario C,D)
p.prop_nonlinear = 1.0;

% --- Factor DGP ---
% Extra parameters for Scenario E (context matters)
p.sigma_idio = 0.8;
% Regime-specific idiosyncratic scale (Scenario E2)
p.sigma_idio_low  = 0.25;
p.sigma_idio_high = 2.00;
p.phi_idio_high = 0.85;
p.phi_idio_low  = 0.20;

p.phi = 0.7;
p.sigma_u = 1.0;
p.sigma_eps = 1.0;
p.sigma_lambda = 1.0;

% --- Base missingness: M_final ~ Bernoulli(e0(X)) ---
p.target_obs_rate = 0.60;
p.beta0 = [0; 1.0; -0.5];    % coefficients on X=(1, lambda_i, t/T)
p.overlap_clip = 0.05;       % clip e_hat and e0 to [c,1-c]

% --- Data release / holdout mechanism: creates M0 from M_final ---
p.holdout_rate = 0.20;
p.holdout_mode = 'random';   % 'random' or 'logit' (logit uses X to create context-linked releases)
p.holdout_beta = [0; 0.5; 0.0]; % only used if holdout_mode='logit' (stacked X beta)

% --- Bandit action set ---
% 'holdout_only'  : act only on delayed-release cells (cleanest for theory/regret)
% 'all_missing'   : act on all decision-missing cells (includes permanent missing; use as sensitivity)
p.act_set = 'holdout_only';

% --- Batched bandit / delayed feedback ---
p.B = 15;                 % number of batches
p.batch_by_time = true;   % partition action cells by time blocks
p.Delta = 2;              % delay in batches (data release lag)
p.rho_reveal = 0.50;      % within holdout: probability a cell is revealed for learning
p.normalize_regret = true;

% --- Context binning (finite contextual policy) ---
p.n_bins_lambda = 4;
p.n_bins_time = 4;

% --- UCB (risk minimization via LCB = mean - bonus) ---
p.ucb_c = 1.0;
p.min_reveals_for_ucb = 5;

% --- Feedback loss mode ---
% 'dr'       : doubly robust pseudo-loss (default)
% 'observed' : use observed squared loss on revealed cells (used in early pedagogical stages)
p.loss_mode = 'dr';

% --- Nuisance estimation (toolbox-free) ---
% e_hat: IRLS logit; m_hat: pooled ridge regression.
p.ridge_lambda_logit = 1e-6;
p.max_irls_iter = 50;
p.irls_tol = 1e-8;

p.ridge_lambda_m = 1e-6;

% Nuisance update schedule: 'once' or 'batch'
p.nuisance_update = 'batch';

% Nuisance mode: 'estimated' or 'oracle' (oracle uses true e0 and true mean component)
p.nuisance_mode = 'estimated';

% --- Arm 3: ALS factor (rank-1) ---
p.als_max_iter = 75;
p.als_tol = 1e-6;
p.als_ridge = 1e-4;
p.als_ycap = 25;

% --- Arm 4: State-space factor via EM + Kalman smoother ---
p.ssm_max_iter = 25;
p.ssm_tol = 1e-6;
p.ssm_min_var = 1e-6;
p.ssm_estimate_phi = true;

% --- Output / debugging ---
p.verbose = false;
p.debug = false;

end
