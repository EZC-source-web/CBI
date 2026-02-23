% RUN_ALL.m  (v12)
% ---------------------------------------------------------
% One-command entry point (self-contained).
% It sets the path, runs the paper-grade Monte Carlo suite,
% and writes outputs to out/ (always overwritten).
%
% Workflow:
%   >> RUN_ALL
%   then compile text/PaperMCMain.tex (after exhibits exist)
% ---------------------------------------------------------

ROOT = fileparts(mfilename('fullpath'));
cd(ROOT);

% --- Clean session (best-effort) ---
try, close all; catch, end
clearvars -except ROOT
clear functions;
rehash toolboxcache;

% --- Add package paths ---
addpath(genpath(fullfile(ROOT,'src')),'-begin');
addpath(fullfile(ROOT,'text'),'-begin');
rehash toolboxcache;
clear functions;

% --- Banner ---
fprintf('\n============================================\n');
fprintf('CBI paper-grade Monte Carlo (v12)\n');
fprintf('Root: %s\n', ROOT);
fprintf('Timestamp: %s\n', datestr(now));
fprintf('============================================\n');

% --- Path diagnostics for common collisions (robust across MATLAB versions) ---
key = {'dgp_library','apply_dgp','run_paper_mc'};
for i=1:numel(key)
    fn = key{i};
    w = which(fn,'-all');
    if isempty(w)
        error('Cannot find %s on path. Did you unzip correctly?', fn);
    end
    if ischar(w)
        paths = {w};
    else
        paths = w; % cell array of paths
    end
    fprintf('[PATH] %-12s -> %s\n', fn, paths{1});
    if numel(paths)>1
        fprintf('       WARNING: multiple definitions found for %s:\n', fn);
        for j=1:numel(paths)
            fprintf('         %s\n', paths{j});
        end
        error('Path collision detected for %s. Remove old packages from MATLAB path and re-run.', fn);
    end
end

% --- Configure & run ---
cfg = paper_mc_defaults();
cfg.run_id = 'paper_mc_v12';

% Main paper exhibits only by default.
% (Calibration/sensitivity is still available via S10/S11, but it is not
% run nor exported by default to keep the exhibit set compact.)
cfg.do_calibration  = true;
cfg.do_stage_ladder = false;
cfg.do_main_scaling = true;

% Bridge: Scenario E vs Scenario E2 (internal stages 6 vs 7)
cfg.main_scaling_stages = [6 7];

cfg.use_parallel = true;

fprintf('\n[1/2] Running Monte Carlo suite...\n');
out = run_paper_mc(cfg);
assignin('base','last_run',out);

fprintf('\n[2/2] Exhibits summary...\n');
print_exhibits_summary(out);

fprintf('\nDONE. Next: compile text/PaperMCMain.tex (after exhibits are created).\n');
