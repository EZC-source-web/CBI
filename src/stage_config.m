function [p, meta] = stage_config(stage)
% stage_config.m (v6)
% ---------------------------------------------------------
% Pedagogical ladder (specific -> general), consistent with Theory.tex.
%
% Each stage configures:
%   - DGP / missingness / data release lag (Delta) and feedback density (rho)
%   - learning signal (observed loss vs DR pseudo-loss)
%   - nuisance mode (oracle vs estimated)
%
% Stages:
%   0: Arms-only baseline (no learning)
%   1: Immediate data release (Delta=0, rho=1), observed loss feedback
%   2: Delayed / partial release (Delta>0 and/or rho<1), observed loss feedback
%   3: DR pseudo-loss with ORACLE nuisances (illustrates Lemma DR unbiasedness)
%   4: DR pseudo-loss with ESTIMATED nuisances (applied case)
%   5: Misspecification ladder (A,B,C,D) with estimated nuisances
%   6: Context-matters (scenario E): best arm depends on observable context
% ---------------------------------------------------------

p = default_params();
meta = struct();

meta.stage = stage;
meta.run_policy = true;
meta.multi_scenario = false;

switch stage
    case 0
        meta.name = 'Stage 0: arms-only baseline';
        meta.anchor = 'Define imputation risk (MSE/RMSE) for each imputer.';
        meta.run_policy = false;      % run arms only (no learning)
        p.scenario = 'A';
        p.act_set = 'holdout_only';
        p.holdout_mode = 'random';
        p.Delta = 0;
        p.rho_reveal = 1.0;

    case 1
        meta.name = 'Stage 1: immediate data release (observed loss)';
        meta.anchor = 'Introduce batching + regret with immediate revealed loss.';
        p.scenario = 'A';
        p.act_set = 'holdout_only';
        p.loss_mode = 'observed';
        p.nuisance_mode = 'estimated'; % irrelevant in observed mode
        p.nuisance_update = 'once';
        p.Delta = 0;
        p.rho_reveal = 1.0;

    case 2
        meta.name = 'Stage 2: delayed/partial data release (observed loss)';
        meta.anchor = 'Effect of delayed and sparse feedback on learning/regret.';
        p.scenario = 'A';
        p.act_set = 'holdout_only';
        p.loss_mode = 'observed';
        p.nuisance_mode = 'estimated'; % irrelevant in observed mode
        p.nuisance_update = 'once';
        p.Delta = 2;
        p.rho_reveal = 0.5;

    case 3
        meta.name = 'Stage 3: DR pseudo-loss with oracle nuisances';
        meta.anchor = 'Validate doubly robust risk estimation with oracle nuisances.';
        p.scenario = 'A';
        p.act_set = 'holdout_only';
        p.loss_mode = 'dr';
        p.nuisance_mode = 'oracle';
        p.nuisance_update = 'once';
        p.Delta = 2;
        p.rho_reveal = 0.5;

    case 4
        meta.name = 'Stage 4: DR pseudo-loss with estimated nuisances';
        meta.anchor = 'Applied DR learning: estimated e-hat and m-hat, updated over time.';
        p.scenario = 'A';
        p.act_set = 'holdout_only';
        p.loss_mode = 'dr';
        p.nuisance_mode = 'estimated';
        p.nuisance_update = 'batch';
        p.Delta = 2;
        p.rho_reveal = 0.5;

    case 5
        meta.name = 'Stage 5: misspecification ladder (A,B,C,D)';
        meta.anchor = 'Double robustness: m misspec, e misspec, both.';
        meta.multi_scenario = true;
        p.loss_mode = 'dr';
        p.nuisance_mode = 'estimated';
        p.nuisance_update = 'batch';
        p.act_set = 'holdout_only';
        p.Delta = 2;
        p.rho_reveal = 0.5;

    case 6
        meta.name = 'Stage 6: baseline context (scenario E)';
        meta.anchor = 'Baseline context: limited heterogeneity; exploration cost may dominate in short horizons.';
        % Paper-grade DGP id (see dgp_library.m). Can be overridden in scripts.
        p.dgp_id = 'DFM_CTX_MODERATE';
        p.loss_mode = 'dr';
        p.nuisance_mode = 'estimated';
        p.nuisance_update = 'batch';
        p.act_set = 'holdout_only';
        p.Delta = 2;
        p.rho_reveal = 0.5;

    
    case 7
        meta.name = 'Stage 7: strong context heterogeneity (scenario E2)';
        meta.anchor = 'Two-regime design: best imputer varies with observable context; policy should beat best static.';
        % Paper-grade DGP id (see dgp_library.m). Can be overridden in scripts.
        p.dgp_id = 'DFM_CTX_STRONG';
        p.loss_mode = 'dr';
        p.nuisance_mode = 'estimated';
        p.nuisance_update = 'batch';
        p.act_set = 'holdout_only';
        p.Delta = 2;
        p.rho_reveal = 0.5;

        % NOTE: the heterogeneity strength is now governed by the DGP catalog.
        % Stage 7 still pins the *feedback environment* for the paper-grade suite.
        p.Delta = 1;
        p.rho_reveal = 0.9;
        p.min_reveals_for_ucb = 1;
        p.n_bins_lambda = 2;
        p.n_bins_time   = 1;
        p.ucb_c = 0.5;

otherwise
        error('stage_config:stage','Unknown stage %d', stage);
end

% Apply DGP overrides if requested
if isfield(p,'dgp_id') && ~isempty(p.dgp_id)
    p = apply_dgp(p, p.dgp_id);
end

end
