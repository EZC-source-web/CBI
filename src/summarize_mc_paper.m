function S = summarize_mc_paper(rep)
% summarize_mc_paper.m
% ---------------------------------------------------------
% Compute paper-facing summaries (means + standard errors) from a
% cell array of replication structs produced by one_replication_paper()
% or one_replication_arms_only_paper().
% ---------------------------------------------------------

R = numel(rep);
K = numel(rep{1}.arm_mse);

arm_mse = NaN(R,K);
policy_mse = NaN(R,1);
oracle_ctx_mse = NaN(R,1);
final_regret = NaN(R,1);
share_by_arm = NaN(R,K);
sparsity = NaN(R,1);
riskhat_dr = NaN(R,K);
riskhat_ipw = NaN(R,K);
riskhat_or  = NaN(R,K);
riskhat_pi_dr = NaN(R,1);

for r=1:R
    arm_mse(r,:) = rep{r}.arm_mse;
    policy_mse(r) = rep{r}.policy_mse;
    oracle_ctx_mse(r) = rep{r}.oracle_ctx_mse;
    final_regret(r) = rep{r}.final_regret;
    if isfield(rep{r},'share_by_arm') && ~isempty(rep{r}.share_by_arm)
        share_by_arm(r,:) = rep{r}.share_by_arm;
    end
    sparsity(r) = rep{r}.sparsity;
    riskhat_dr(r,:) = rep{r}.riskhat_dr;
    riskhat_ipw(r,:) = rep{r}.riskhat_ipw;
    riskhat_or(r,:)  = rep{r}.riskhat_or;
    riskhat_pi_dr(r) = rep{r}.riskhat_pi_dr;
end

arm_mse_mean = mean(arm_mse,1,'omitnan');
[best_static_mse_mean, k_best_static] = min(arm_mse_mean);

best_static_mse_rep = arm_mse(:,k_best_static);
policy_mse_mean = mean(policy_mse,'omitnan');
oracle_ctx_mse_mean = mean(oracle_ctx_mse,'omitnan');

% Replication-level gaps
gap_best_rep = policy_mse - best_static_mse_rep;
gap_oracle_rep = policy_mse - oracle_ctx_mse;

% "Power-like" diagnostic: probability the policy beats Best(static)
win_best_rep = (gap_best_rep < 0);

% Value of context and capture ratio
value_context_rep = best_static_mse_rep - oracle_ctx_mse;
denom = value_context_rep;
cap_ratio_rep = (best_static_mse_rep - policy_mse) ./ denom;
cap_ratio_rep(denom<=0) = NaN;

S = struct();
S.R = R;
S.K = K;
S.k_best_static = k_best_static;
S.arm_mse_mean = arm_mse_mean;
S.best_static_mse_mean = best_static_mse_mean;
S.best_static_mse_se   = se(best_static_mse_rep);
S.policy_mse_mean = policy_mse_mean;
S.policy_mse_se   = se(policy_mse);
S.oracle_ctx_mse_mean = oracle_ctx_mse_mean;
S.oracle_ctx_mse_se   = se(oracle_ctx_mse);
S.gap_best_mean = mean(gap_best_rep,'omitnan');
S.gap_best_se   = se(gap_best_rep);

% Win probability vs Best(static)
S.win_vs_best_static_mean = mean(win_best_rep,'omitnan');
S.win_vs_best_static_se   = se_bern(win_best_rep);
S.gap_oracle_mean = mean(gap_oracle_rep,'omitnan');
S.gap_oracle_se   = se(gap_oracle_rep);
S.value_context_mean = mean(value_context_rep,'omitnan');
S.value_context_se   = se(value_context_rep);
S.capture_ratio_mean = mean(cap_ratio_rep,'omitnan');
S.capture_ratio_se   = se(cap_ratio_rep);

% ---------------------------------------------------------
% Backward-compatible field names
% (some callers use the explicit "gap_vs_*" naming).
% ---------------------------------------------------------
S.gap_vs_best_static_mean = S.gap_best_mean;
S.gap_vs_best_static_se   = S.gap_best_se;

S.win_vs_best_mean = S.win_vs_best_static_mean;
S.win_vs_best_se   = S.win_vs_best_static_se;
S.gap_vs_oracle_ctx_mean  = S.gap_oracle_mean;
S.gap_vs_oracle_ctx_se    = S.gap_oracle_se;

S.final_regret_mean = mean(final_regret,'omitnan');
S.final_regret_se   = se(final_regret);

S.share_best_static_mean = mean(share_by_arm(:,k_best_static),'omitnan');
S.share_best_static_se   = se(share_by_arm(:,k_best_static));

S.sparsity_mean = mean(sparsity,'omitnan');
S.sparsity_se   = se(sparsity);

% Risk estimate biases (DR, IPW, OR) vs true MSE
S.riskhat_dr_mean  = mean(riskhat_dr,1,'omitnan');
S.riskhat_ipw_mean = mean(riskhat_ipw,1,'omitnan');
S.riskhat_or_mean  = mean(riskhat_or,1,'omitnan');
S.riskhat_pi_dr_mean = mean(riskhat_pi_dr,'omitnan');

S.bias_dr_mean  = S.riskhat_dr_mean  - arm_mse_mean;
S.bias_ipw_mean = S.riskhat_ipw_mean - arm_mse_mean;
S.bias_or_mean  = S.riskhat_or_mean  - arm_mse_mean;

S.bias_pi_dr_mean = S.riskhat_pi_dr_mean - policy_mse_mean;
end

function s = se(x)
x = x(:);
x = x(~isnan(x));
if numel(x)<=1
    s = NaN;
    return;
end
s = std(x,0) / sqrt(numel(x));
end

function s = se_bern(x)
% Standard error for a Bernoulli mean (handles NaNs)
x = x(:);
x = x(~isnan(x));
n = numel(x);
if n<=1
    s = NaN;
    return;
end
p = mean(x);
s = sqrt(p*(1-p)/n);
end
