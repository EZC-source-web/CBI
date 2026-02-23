% S10_calibrate_bins.m
% ---------------------------------------------------------
% Calibration 1: choose context discretization (bins) to control sparsity.
% ---------------------------------------------------------

ROOT = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(ROOT,'src')));
rehash toolboxcache;
clear functions;

cfg = paper_mc_defaults();
cfg.run_id = 'calib_bins';

cfg.R = 100;
cfg.T_calib = 400;
cfg.T_stage_ladder = 200;  % unused (ladder off)
cfg.T_grid = [400];        % keep consistent
cfg.batch_len_L = 25;

% Calibrate bins holding c fixed (3 levels: baseline, mid, strongly coarse).
cfg.bins_grid = [3 3; 2 2; 1 1];
cfg.c_grid    = 0.5;

% Base values used outside the calibration grid
cfg.n_bins_lambda = 3;
cfg.n_bins_time   = 3;
cfg.ucb_c = 0.5;

cfg.do_calibration  = true;
cfg.do_stage_ladder = false;
cfg.do_main_scaling = false;

cfg.use_parallel = true;

out = run_paper_mc(cfg);
assignin('base','last_run',out);
print_exhibits_summary(out);
