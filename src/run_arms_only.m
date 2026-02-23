function algo = run_arms_only(Y_true, Y_obs_init, M0_init, action_mask, p)
% run_arms_only.m (v6)
% ---------------------------------------------------------
% Computes each arm's imputation for the action set, WITHOUT any learning.
% This is used for Stage 0 (baseline) and for debugging.
% ---------------------------------------------------------

Y_true = force_panel(Y_true, p.N, p.T, 'Y_true');
Y_obs_init = force_panel(Y_obs_init, p.N, p.T, 'Y_obs_init');
M0_init = force_panel(M0_init, p.N, p.T, 'M0_init');
action_mask = force_panel(action_mask, p.N, p.T, 'action_mask');

N = p.N; T = p.T; K = 5;

Y_true = Y_true(:);
Y_obs  = Y_obs_init(:);
M_avail= logical(M0_init(:));
action_mask = logical(action_mask(:));

idxA = find(action_mask);
yhat_store = NaN(N*T, K);

if ~isempty(idxA)
    t_end = T;
    yhat_store(idxA,1) = imputer_cs_mean(Y_obs, M_avail, idxA, t_end, p);
    yhat_store(idxA,2) = imputer_ar1(Y_obs, M_avail, idxA, t_end, p);
    yhat_store(idxA,3) = imputer_pca_als1(Y_obs, M_avail, idxA, t_end, p);
    yhat_store(idxA,4) = imputer_ssm_em1(Y_obs, M_avail, idxA, t_end, p);
    yhat_store(idxA,5) = imputer_raukf(Y_obs, M_avail, idxA, t_end, p);
end

algo = struct();
algo.K = K;
algo.yhat_store = yhat_store;
algo.yhat_policy = NaN(N*T,1);
algo.action = NaN(N*T,1);
algo.regret_revealed = NaN(p.B,1);
algo.Rhat_dr_batch = NaN(K,p.B);
algo.Rhat_ipw_batch = NaN(K,p.B);
algo.Rhat_or_batch = NaN(K,p.B);
algo.Rhat_pi_dr = NaN(p.B,1);
end
