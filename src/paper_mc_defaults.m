function cfg = paper_mc_defaults()
% paper_mc_defaults.m
% ---------------------------------------------------------
% Central configuration for the paper-grade Monte Carlo suite.
% This returns *defaults*; override in RUN_PAPER_MC.m.
% ---------------------------------------------------------

cfg = struct();

% Core sizes
cfg.N = 60;
% Finer T grid to reveal thresholds / non-linear learning (batch length L constant)
% (all multiples of L=25 so that B=T/L is integer)
cfg.T_grid = [50 75 100 125 150 175 200 225 250 275 300 325 350 375 400 425 450 475 500 600 700 800 900 1000 1250 1500 1750 2000];
cfg.R = 500;

% Batch design (constant length)
cfg.batch_len_L = 25;

% Scenario choices for the paper-grade suite
% DGP ids for the paper-grade suite (see dgp_library.m)
cfg.dgp_id_stage6 = 'DFM_CTX_MODERATE'; % bridge
cfg.dgp_id_stage7 = 'DFM_CTX_STRONG';   % main

% (Backward-compatible) scenario selectors used only if scripts override
% scenario directly instead of dgp_id.
cfg.scenario_stage6 = 'E';
cfg.scenario_stage7 = 'E2';

% Context discretization + exploration (baseline)
cfg.n_bins_lambda = 3;
cfg.n_bins_time   = 3;
cfg.ucb_c = 0.50;

% Appendix calibration grids (3 levels each: baseline, mid, strongly coarse)
cfg.bins_grid = [3 3; 2 2; 1 1];
cfg.c_grid    = [0.50 1.00 2.00];

% Reveal schedule (in batches)
cfg.Delta = 1;
cfg.rho_reveal = 0.90;

% Baseline missingness/holdout
cfg.target_obs_rate = 0.60;
cfg.holdout_rate = 0.20;

% Nuisance mode for DR pseudo-loss
cfg.nuisance_mode   = 'estimated'; % 'oracle' or 'estimated'
cfg.nuisance_update = 'batch';     % 'static' or 'batch'

% Which policy/stages to run
% By default we only generate the *main* paper exhibit (scaling in T).
% Sensitivity / calibration can be run on demand via S10/S11.
cfg.do_calibration   = true;
cfg.do_stage_ladder  = false;
cfg.do_feedback_grid = false;

% Calibration horizon
cfg.T_calib = 200;

% Stage ladder horizon
cfg.T_stage_ladder = 200;

% Feedback grid (optional)
cfg.rho_grid   = [0.50 0.70 0.90];
cfg.Delta_grid = [0 1 2];

% Diagnostics thresholds
cfg.sparsity_thr = 5;

% Parallel
cfg.use_parallel = true;

% Output
cfg.out_root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out');

% Reporting: optional normalized gain (disabled by default to avoid introducing new concepts)
cfg.include_normalized_gain = false;
end
