% S11_calibrate_ucb_c.m
% ---------------------------------------------------------
% Calibration 2: choose the exploration constant c (UCB).
% Run after S10_calibrate_bins (or keep bins fixed at 4x4).
% ---------------------------------------------------------

ROOT = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(ROOT,'src')));
rehash toolboxcache;
clear functions;

cfg = paper_mc_defaults();
cfg.run_id = 'calib_c';

cfg.R = 100;
cfg.T_calib = 400;
cfg.T_grid = [400];
cfg.batch_len_L = 25;

% Fix bins (adjust if S10 suggests a different choice)
cfg.n_bins_lambda = 3;
cfg.n_bins_time   = 3;

% Calibrate c holding bins fixed (3 levels: baseline, mid, high).
cfg.c_grid = [0.5 1.0 2.0];

cfg.do_calibration  = true;
cfg.do_stage_ladder = false;
cfg.do_main_scaling = false;

cfg.use_parallel = true;

out = run_paper_mc(cfg);
assignin('base','last_run',out);
print_exhibits_summary(out);
