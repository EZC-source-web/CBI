function out = run_paper_mc(cfg)
% run_paper_mc.m
% ---------------------------------------------------------
% Main orchestrator for the paper-grade Monte Carlo suite.
%
% PAPER-GRADE OUTPUT POLICY
%   - single output folder: out/
%   - exhibits (tables/figures) in: out/exhibits/   (always overwritten)
%   - light raw objects in:         out/raw/        (always overwritten)
%
% The suite can run:
%   (1) optional calibration over (bins, c)
%   (2) optional stage ladder 0..7
%   (3) main scaling exercise over T_grid (with constant batch length)
% and then exports a small number of paper-ready exhibits.
% ---------------------------------------------------------

if nargin<1 || isempty(cfg)
    cfg = paper_mc_defaults();
end

% ---------------------------------------------------------
% Backward/forward compatible defaults
if ~isfield(cfg,'do_main_scaling');       cfg.do_main_scaling = true; end
if ~isfield(cfg,'main_scaling_stages');   cfg.main_scaling_stages = [6 7]; end
if ~isfield(cfg,'bins_grid');             cfg.bins_grid = []; end
if ~isfield(cfg,'c_grid');                cfg.c_grid = []; end
% ---------------------------------------------------------

setup_paths();

% ---------------- output folders (single folder, overwrite) ----------------
root = cfg.out_root;
exh_dir = fullfile(root, 'exhibits');
raw_dir = fullfile(root, 'raw');

ensure_dir(root);
ensure_dir(exh_dir);
ensure_dir(raw_dir);

% Wipe content (keep .gitkeep if present)
wipe_dir_except_gitkeep(exh_dir);
wipe_dir_except_gitkeep(raw_dir);

% Run stamp (for logging only; paths are stable)
run_stamp = datestr(now,'yyyymmdd_HHMMSS');
if ~isfield(cfg,'run_id') || isempty(cfg.run_id)
    cfg.run_id = 'paper_mc';
end
cfg.generated_at = datestr(now);
cfg.run_stamp = run_stamp;

% Save config snapshot (overwritten each run)
save(fullfile(root,'cfg_snapshot.mat'), 'cfg');
write_cfg_txt(fullfile(root,'cfg_snapshot.txt'), cfg);

% Storage for exports
results = struct();
results.run_id = cfg.run_id;
results.run_stamp = run_stamp;
results.cfg = cfg;

% =========================================================
% (1) Optional calibration (Stage 7 only by default)
% =========================================================
if cfg.do_calibration
    fprintf('\n[Paper MC] Calibration step (bins x c) at T=%d...\n', cfg.T_calib);

    if ~isempty(cfg.bins_grid)
        bins_grid = cfg.bins_grid;
    else
        bins_grid = [3 3; 4 4; 6 6];
    end

    if ~isempty(cfg.c_grid)
        c_grid = cfg.c_grid;
    else
        c_grid = [0.10 0.50 1.00];
    end

    rows = {};
    ii = 0;

    for j=1:size(bins_grid,1)
        for cc=1:numel(c_grid)
            ii = ii + 1;
            ov = build_override(cfg, cfg.T_calib, 7);
            % Prefer DGP ids (paper-grade). Keep scenario for backward compatibility.
            if isfield(cfg,'dgp_id_stage7') && ~isempty(cfg.dgp_id_stage7)
                ov.dgp_id = cfg.dgp_id_stage7;
            end
            ov.scenario = cfg.scenario_stage7;
            ov.n_bins_lambda = bins_grid(j,1);
            ov.n_bins_time   = bins_grid(j,2);
            ov.ucb_c         = c_grid(cc);

            out7 = run_stage_paper(7, ov, cfg);
            s = out7.res.summary;

            % Store means + MCSE for key objects (appendix exhibit)
            rows(ii,:) = {ov.ucb_c, ov.n_bins_lambda, ov.n_bins_time, ...
                s.k_best_static, ...
                s.best_static_mse_mean, s.best_static_mse_se, ...
                s.policy_mse_mean,      s.policy_mse_se, ...
                s.gap_vs_best_static_mean, s.gap_vs_best_static_se, ...
                s.win_vs_best_static_mean,  s.win_vs_best_static_se, ...
                s.share_best_static_mean,  s.share_best_static_se, ...
                s.sparsity_mean,           s.sparsity_se, ...
                s.oracle_ctx_mse_mean,     s.oracle_ctx_mse_se, ...
                s.gap_vs_oracle_ctx_mean,  s.gap_vs_oracle_ctx_se};

            fprintf('  c=%.2f, bins=(%d,%d): k*=%d best=%.3f policy=%.3f gap=%.3f | share=%.3f spars=%.3f | oracleCtx=%.3f\n', ...
                ov.ucb_c, ov.n_bins_lambda, ov.n_bins_time, s.k_best_static, ...
                s.best_static_mse_mean, s.policy_mse_mean, s.gap_vs_best_static_mean, ...
                s.share_best_static_mean, s.sparsity_mean, s.oracle_ctx_mse_mean);
        end
    end

    calib = struct();
    calib.rows = rows;
    results.calibration = calib;
end

% =========================================================
% (2) Optional stage ladder (0..7) at one horizon
% =========================================================
if cfg.do_stage_ladder
    fprintf('\n[Paper MC] Stage ladder (0..7) at T=%d...\n', cfg.T_stage_ladder);

    ladder = struct();
    ladder.stage = (0:7)';
    % Columns used by write_tab_stage_ladder():
    %  1 st,2 scenario,3 T,4 B,5 k*,6 best_mu,7 best_se,8 pol_mu,9 pol_se,
    % 10 gap_mu,11 gap_se,12 win_mu,13 win_se,14 orc_mu,15 orc_se,
    % 16 gapc_mu,17 gapc_se,18 share_mu,19 share_se,20 spars_mu,21 spars_se
    ladder.rows = cell(numel(ladder.stage), 21);

    for st = ladder.stage'
        ov = build_override(cfg, cfg.T_stage_ladder, st);

        % Stage-specific scenarios (match stage_config logic)
        if st==6
            if isfield(cfg,'dgp_id_stage6') && ~isempty(cfg.dgp_id_stage6)
                ov.dgp_id = cfg.dgp_id_stage6;
            end
            ov.scenario = cfg.scenario_stage6;
        elseif st==7
            if isfield(cfg,'dgp_id_stage7') && ~isempty(cfg.dgp_id_stage7)
                ov.dgp_id = cfg.dgp_id_stage7;
            end
            ov.scenario = cfg.scenario_stage7;
        end

        outst = run_stage_paper(st, ov, cfg);
        s = outst.res.summary;

        ladder.rows(st+1,:) = { ...
            st, outst.res.p.scenario, outst.res.p.T, outst.res.p.B, ...
            s.k_best_static, ...
            s.best_static_mse_mean, s.best_static_mse_se, ...
            s.policy_mse_mean,      s.policy_mse_se, ...
            s.gap_vs_best_static_mean, s.gap_vs_best_static_se, ...
            s.win_vs_best_static_mean,  s.win_vs_best_static_se, ...
            s.oracle_ctx_mse_mean,     s.oracle_ctx_mse_se, ...
            s.gap_vs_oracle_ctx_mean,  s.gap_vs_oracle_ctx_se, ...
            s.share_best_static_mean,  s.share_best_static_se, ...
            s.sparsity_mean,           s.sparsity_se};
    end

    results.ladder = ladder;
end

% =========================================================
% (3) Main scaling exercise over T_grid (selected stages)
% =========================================================
scaling = struct();
scaling.rows = {};

if cfg.do_main_scaling
    fprintf('\n[Paper MC] Main scaling exercise over T grid...\n');

    kk = 0;
    stages = cfg.main_scaling_stages(:)';

    for T = cfg.T_grid
        for st = stages
            kk = kk + 1;
            ov = build_override(cfg, T, st);

            if st==6
                if isfield(cfg,'dgp_id_stage6') && ~isempty(cfg.dgp_id_stage6)
                    ov.dgp_id = cfg.dgp_id_stage6;
                end
                ov.scenario = cfg.scenario_stage6;
            elseif st==7
                if isfield(cfg,'dgp_id_stage7') && ~isempty(cfg.dgp_id_stage7)
                    ov.dgp_id = cfg.dgp_id_stage7;
                end
                ov.scenario = cfg.scenario_stage7;
            end

            outst = run_stage_paper(st, ov, cfg);
            s = outst.res.summary;

            scaling.rows(kk,:) = { ...
                st, ov.scenario, T, outst.res.p.B, ov.n_bins_lambda, ov.n_bins_time, ov.ucb_c, ...
                s.k_best_static, ...
                s.best_static_mse_mean, s.best_static_mse_se, ...
                s.policy_mse_mean,      s.policy_mse_se, ...
                s.gap_vs_best_static_mean, s.gap_vs_best_static_se, ...
                s.win_vs_best_static_mean,  s.win_vs_best_static_se, ...
                s.oracle_ctx_mse_mean,     s.oracle_ctx_mse_se, ...
                s.gap_vs_oracle_ctx_mean,  s.gap_vs_oracle_ctx_se, ...
                s.share_best_static_mean,  s.share_best_static_se, ...
                s.sparsity_mean,           s.sparsity_se, ...
                ... % CtxGain := Best(static) - Oracle(ctx)
                s.value_context_mean,      s.value_context_se};
        end
    end
end

results.scaling = scaling;

% =========================================================
% Export exhibits (single destination)
% =========================================================
export_paper_exhibits(results, exh_dir, cfg);

% Output struct
out = struct();
out.run_id = cfg.run_id;
out.run_stamp = run_stamp;
out.out_root = root;
out.exhibits_dir = exh_dir;
out.raw_dir = raw_dir;
out.results = results;

end

% =========================================================
% Helpers
% =========================================================
function ensure_dir(p)
if ~exist(p,'dir'); mkdir(p); end
end

function wipe_dir_except_gitkeep(d)
if ~exist(d,'dir'); return; end
files = dir(d);
for i=1:numel(files)
    nm = files(i).name;
    if strcmp(nm,'.') || strcmp(nm,'..'); continue; end
    if files(i).isdir
        rmdir(fullfile(d,nm), 's');
    else
        if strcmp(nm,'.gitkeep'); continue; end
        delete(fullfile(d,nm));
    end
end
end

function write_cfg_txt(path, cfg)
fid = fopen(path,'w');
assert(fid>0,'Cannot open cfg txt');
keys = fieldnames(cfg);
for i=1:numel(keys)
    k = keys{i};
    v = cfg.(k);
    if isnumeric(v)
        if isscalar(v)
            fprintf(fid,'%s: %g\n', k, v);
        else
            fprintf(fid,'%s: [%s]\n', k, num2str(v));
        end
    elseif islogical(v)
        fprintf(fid,'%s: %d\n', k, v);
    elseif ischar(v)
        fprintf(fid,'%s: %s\n', k, v);
    else
        fprintf(fid,'%s: (type %s)\n', k, class(v));
    end
end
fclose(fid);
end

function ov = build_override(cfg, T, stage)
% Build a parameter override struct consistent with constant batch length.
L = cfg.batch_len_L;
B = max(1, round(T / L));

ov = struct();
ov.N = cfg.N;
ov.T = T;
ov.B = B;
ov.R = cfg.R;
ov.verbose = false;
ov.target_obs_rate = cfg.target_obs_rate;
ov.holdout_rate = cfg.holdout_rate;
ov.n_bins_lambda = cfg.n_bins_lambda;
ov.n_bins_time   = cfg.n_bins_time;
ov.ucb_c = cfg.ucb_c;
ov.Delta = cfg.Delta;
ov.rho_reveal = cfg.rho_reveal;
ov.nuisance_mode = cfg.nuisance_mode;
ov.nuisance_update = cfg.nuisance_update;
ov.stage = stage; %#ok<NASGU>
end
