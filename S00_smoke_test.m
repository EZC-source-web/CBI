% S00_smoke_test.m
% ---------------------------------------------------------
% Quick smoke test: verifies that the pipeline runs end-to-end
% and produces exhibits (tables/figures) in out/exhibits/.
% ---------------------------------------------------------

ROOT = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(ROOT,'src')));
rehash toolboxcache;
clear functions;

cfg = paper_mc_defaults();
cfg.run_id = 'smoke_test';

cfg.R = 10;
cfg.T_stage_ladder = 200;
cfg.T_grid = [200];                 % keep short
cfg.batch_len_L = 25;

cfg.n_bins_lambda = 3;
cfg.n_bins_time   = 3;
cfg.ucb_c = 0.5;

cfg.do_calibration  = false;
cfg.do_stage_ladder = true;
cfg.do_main_scaling = true;
cfg.main_scaling_stages = [6 7];

cfg.use_parallel = false;

out = run_paper_mc(cfg);
assignin('base','last_run',out);
print_exhibits_summary(out);
