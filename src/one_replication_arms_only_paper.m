function rep = one_replication_arms_only_paper(p, r)
% one_replication_arms_only_paper.m
% ---------------------------------------------------------
% Arms-only replication (paper mode). No learning/policy.
% Computes arm MSEs + oracle contextual benchmark.
% ---------------------------------------------------------

validate_params(p);

% 1) Complete panel
[Y_true, F_true, lambda_true] = simulate_panel(p, r);

% 2) Contexts
X = build_context(lambda_true, p.T);

% 3) Base observation indicator
[M_final, ~] = draw_missingness(X, p, r);

% 4) Holdout layer
[M0, holdout, ~] = apply_holdout(M_final, X, p, r);

% 5) Vintage observed
Y_obs_init = Y_true;
Y_obs_init(~M0) = NaN;

% 6) Action set
action_mask = get_action_mask(M0, holdout, p);

% 7) Context bins (for oracle contextual benchmark)
ctx = build_context_bins(lambda_true, p.T, p.n_bins_lambda, p.n_bins_time);

% 8) Arms only
algo = run_arms_only(Y_true, Y_obs_init, M0, action_mask, p);

arm_mse = eval_arm_mse(algo.yhat_store, Y_true, action_mask);
oracle_ctx_mse = eval_oracle_ctx_mse(algo.yhat_store, Y_true, action_mask, ctx);

rep = struct();
rep.r = r;
rep.arm_mse = arm_mse;
rep.policy_mse = NaN;
rep.oracle_ctx_mse = oracle_ctx_mse;
rep.final_regret = NaN;
rep.k_best_rep = find(arm_mse==min(arm_mse),1);
rep.share_best_rep = NaN;
rep.sparsity = NaN;
K = size(algo.yhat_store, 2); 
rep.riskhat_dr = NaN(1,K);
rep.riskhat_ipw = NaN(1,K);
rep.riskhat_or  = NaN(1,K);
rep.riskhat_pi_dr = NaN;  % <--- QUESTA è la riga che avevo omesso!
end

% ---- helpers (duplicated from one_replication_paper for simplicity) ----
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

function mse = eval_oracle_ctx_mse(yhat_store, Y_true, action_mask, ctx)
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
