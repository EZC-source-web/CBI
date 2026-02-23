function rep = one_replication(p, r)
% one_replication.m (v6)
% ---------------------------------------------------------
% One Monte Carlo replication.
%
% Data release mapping (pedagogical):
%   1) Generate complete panel Y_true from DGP (latent factor model).
%   2) Generate base observability M_final (Omega) from e0(X).
%   3) Create decision-time vintage M0 by holding out delayed-release cells.
%   4) The bandit acts on an action set (by default: holdout cells), and
%      learns from revealed feedback after delay Delta.
% ---------------------------------------------------------

validate_params(p);

% 1) Complete panel
[Y_true, F_true, lambda_true] = simulate_panel(p, r);

% 2) Contexts (always observed)
X = build_context(lambda_true, p.T);

% 3) Base observation indicator (Omega)
[M_final, e0] = draw_missingness(X, p, r);

% 4) Data release layer (vintage) via holdout
[M0, holdout, p_hold] = apply_holdout(M_final, X, p, r);

% 5) Decision-time observed panel (vintage outcomes)
Y_obs_init = Y_true;
Y_obs_init(~M0) = NaN;

% 6) Action mask (what the policy will impute)
action_mask = get_action_mask(M0, holdout, p);

% 7) Context bins and batches on the action set
ctx = build_context_bins(lambda_true, p.T, p.n_bins_lambda, p.n_bins_time);
[I_batches, t_end_batches] = build_batches(action_mask, p);

% 8) Nuisances
mu_true = compute_true_mean_component(lambda_true, F_true, p); % oracle mean component
if strcmp(p.nuisance_mode,'oracle')
    nuis = struct();
    nuis.beta_e = [];
    nuis.beta_m = [];
    nuis.e_hat = e0(:);        % true propensity for M_final
    nuis.m_hat = mu_true(:);   % true conditional mean component (oracle)
    nuis.sigma2_hat = p.sigma_eps^2;
else
    nuis = estimate_nuisance(Y_obs_init, M_final, M0, X, p);
end

% 9) Algorithm (may update nuisances over time if nuisance_update='batch')
algo = run_cbi_ucb(Y_true, Y_obs_init, M_final, M0, holdout, action_mask, X, ctx, I_batches, t_end_batches, nuis, p);

% 10) Evaluate MSEs on the action set (imputation focus)
arm_mse = evaluate_arm_mse(algo.yhat_store, Y_true, action_mask);
policy_mse = evaluate_policy_mse(algo.yhat_policy, Y_true, action_mask);

% 11) Final revealed regret (per revealed cell if normalize_regret=true)
final_regret = algo.regret_revealed(end);

rep = struct();
rep.r = r;
rep.Y_true = Y_true;
rep.M_final = M_final;
rep.M0 = M0;
rep.holdout = holdout;
rep.action_mask = action_mask;
rep.lambda_true = lambda_true;
rep.F_true = F_true;

rep.M_final = M_final;
rep.M0 = M0;
rep.holdout = holdout;
rep.action_mask = action_mask;

rep.e0 = e0;
rep.p_hold = p_hold;

rep.algo = algo;
rep.arm_mse = arm_mse;
rep.policy_mse = policy_mse;
rep.final_regret = final_regret;

% Risk estimator diagnostics: average across batches
rep.riskhat_dr  = nanmean(algo.Rhat_dr_batch, 2)';
rep.riskhat_ipw = nanmean(algo.Rhat_ipw_batch,2)';
rep.riskhat_or  = nanmean(algo.Rhat_or_batch, 2)';
rep.riskhat_pi_dr = nanmean(algo.Rhat_pi_dr);

end

% --- helpers ---
function arm_mse = evaluate_arm_mse(yhat_store, Y_true, action_mask)
Y_true = Y_true(:);
idx = find(action_mask(:));
K = size(yhat_store,2);
arm_mse = NaN(1,K);
for k=1:K
    err = yhat_store(idx,k) - Y_true(idx);
    arm_mse(k) = mean(err.^2);
end
end

function mse = evaluate_policy_mse(yhat_policy, Y_true, action_mask)
Y_true = Y_true(:);
idx = find(action_mask(:));
err = yhat_policy(idx) - Y_true(idx);
mse = mean(err.^2);
end
