function rep = one_replication_paper(p, r, sparsity_thr)
% one_replication_paper.m
% ---------------------------------------------------------
% One Monte Carlo replication (paper mode).
% Computes all metrics needed for exhibits, but returns only a light struct.
%
% Key differences vs one_replication.m:
%   - factor loadings can be fixed across replications using p.lambda_fixed
%   - does not store Y_true, algo.yhat_store, ... (large objects)
%   - computes an oracle-contextual benchmark (best arm per context bin)
%   - computes policy share on the best static arm and a sparsity diagnostic
% ---------------------------------------------------------

if nargin<3 || isempty(sparsity_thr)
    sparsity_thr = 5;
end

validate_params(p);

% 1) Complete panel
[Y_true, F_true, lambda_true] = simulate_panel(p, r);

% 2) Contexts (always observed)
X = build_context(lambda_true, p.T);

% 3) Base observation indicator (Omega)
[M_final, e0] = draw_missingness(X, p, r);

% 4) Data release layer (vintage) via holdout
[M0, holdout, ~] = apply_holdout(M_final, X, p, r);

% 5) Decision-time observed panel (vintage outcomes)
Y_obs_init = Y_true;
Y_obs_init(~M0) = NaN;

% 6) Action mask (what the policy will impute)
action_mask = get_action_mask(M0, holdout, p);

% 7) Context bins and batches on the action set
ctx = build_context_bins(lambda_true, p.T, p.n_bins_lambda, p.n_bins_time);
[I_batches, t_end_batches] = build_batches(action_mask, p);

% 8) Nuisances
mu_true = compute_true_mean_component(lambda_true, F_true, p);
if strcmp(p.nuisance_mode,'oracle')
    nuis = struct();
    nuis.beta_e = [];
    nuis.beta_m = [];
    nuis.e_hat = e0(:);
    nuis.m_hat = mu_true(:);
    nuis.sigma2_hat = p.sigma_eps^2;
else
    nuis = estimate_nuisance(Y_obs_init, M_final, M0, X, p);
end

% 9) Algorithm
algo = run_cbi_ucb(Y_true, Y_obs_init, M_final, M0, holdout, action_mask, X, ctx, I_batches, t_end_batches, nuis, p);

% 10) Evaluate MSEs on the action set
arm_mse = eval_arm_mse(algo.yhat_store, Y_true, action_mask);
policy_mse = eval_policy_mse(algo.yhat_policy, Y_true, action_mask);

% 11) Oracle contextual benchmark (best arm per context bin)
oracle_ctx_mse = eval_oracle_ctx_mse(algo.yhat_store, Y_true, action_mask, ctx);

% 12) Regret and selection diagnostics
final_regret = algo.regret_revealed(end);

% Best static arm index (replication-specific; we will also recompute at summary level)
[~, k_best_rep] = min(arm_mse);

share_best_rep = compute_share_best(algo.action, action_mask, k_best_rep);

K = numel(arm_mse);
share_by_arm = compute_share_by_arm(algo.action, action_mask, K);

sparsity = NaN;
if isfield(algo,'countSelKC') && ~isempty(algo.countSelKC)
    sparsity = mean(algo.countSelKC(:) < sparsity_thr);
end

% Risk estimator diagnostics: average across batches (small vectors)
riskhat_dr  = nanmean(algo.Rhat_dr_batch,  2)';
riskhat_ipw = nanmean(algo.Rhat_ipw_batch, 2)';
riskhat_or  = nanmean(algo.Rhat_or_batch,  2)';
riskhat_pi_dr = nanmean(algo.Rhat_pi_dr);

% ---- light output ----
rep = struct();
rep.r = r;
rep.arm_mse = arm_mse;
rep.policy_mse = policy_mse;
rep.oracle_ctx_mse = oracle_ctx_mse;
rep.final_regret = final_regret;
rep.k_best_rep = k_best_rep;
rep.share_best_rep = share_best_rep;
rep.share_by_arm = share_by_arm;
rep.sparsity = sparsity;
rep.riskhat_dr = riskhat_dr;
rep.riskhat_ipw = riskhat_ipw;
rep.riskhat_or = riskhat_or;
rep.riskhat_pi_dr = riskhat_pi_dr;

end

% ---------------- helpers ----------------
function arm_mse = eval_arm_mse(yhat_store, Y_true, action_mask)
Y_true = Y_true(:);
idx = find(action_mask(:));
K = size(yhat_store,2);
arm_mse = NaN(1,K);
for k=1:K
    err = yhat_store(idx,k) - Y_true(idx);
    arm_mse(k) = mean(err.^2);
end
end

function mse = eval_policy_mse(yhat_policy, Y_true, action_mask)
Y_true = Y_true(:);
idx = find(action_mask(:));
err = yhat_policy(idx) - Y_true(idx);
mse = mean(err.^2);
end

function mse = eval_oracle_ctx_mse(yhat_store, Y_true, action_mask, ctx)
% Best arm per context bin, evaluated oracle-style on the full action set.
Y_true = Y_true(:);
mask = logical(action_mask(:));
K = size(yhat_store,2);
C = ctx.C;

mse_bin = NaN(C, K);
wt = zeros(C,1);
for c=1:C
    idx = find(mask & (ctx.bin_id==c));
    wt(c) = numel(idx);
    if wt(c)==0
        continue;
    end
    y = Y_true(idx);
    for k=1:K
        e = yhat_store(idx,k) - y;
        mse_bin(c,k) = mean(e.^2);
    end
end

best_per_bin = nanmin(mse_bin, [], 2);
if sum(wt)>0
    mse = nansum(best_per_bin .* wt) / sum(wt);
else
    mse = NaN;
end
end

function sh = compute_share_by_arm(action, action_mask, K)
mask = logical(action_mask(:));
idx = find(mask);
if isempty(idx) || all(isnan(action(idx)))
    sh = NaN(1,K);
    return;
end
sh = NaN(1,K);
for k=1:K
    sh(k) = mean(action(idx) == k);
end
end


function share = compute_share_best(action, action_mask, k_best)
mask = logical(action_mask(:));
idx = find(mask);
if isempty(idx) || all(isnan(action(idx)))
    share = NaN;
    return;
end
share = mean(action(idx) == k_best);
end
