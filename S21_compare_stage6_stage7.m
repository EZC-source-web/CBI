% S21_compare_stage6_stage7.m
% ---------------------------------------------------------
% Bridge comparison: Stage 6 (E) vs Stage 7 (E2) under the same
% paper-grade configuration.
% ---------------------------------------------------------

ROOT = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(ROOT,'src')));
rehash toolboxcache;
clear functions;

cfg = paper_mc_defaults();
cfg.run_id = 'compare_stage6_stage7';

cfg.R = 500;
cfg.batch_len_L = 25;
cfg.T_grid = [50 75 100 125 150 175 200 225 250 275 300 325 350 375 400 425 450 475 500 600 700 800 900 1000 1250 1500 1750 2000];

cfg.n_bins_lambda = 3;
cfg.n_bins_time   = 3;
cfg.ucb_c = 0.5;

cfg.do_calibration  = false;
cfg.do_stage_ladder = false;
cfg.do_main_scaling = true;
cfg.main_scaling_stages = [6 7];

cfg.use_parallel = true;

out = run_paper_mc(cfg);
assignin('base','last_run',out);
print_exhibits_summary(out);
