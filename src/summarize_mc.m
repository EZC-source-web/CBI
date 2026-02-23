function summary = summarize_mc(rep)
% summarize_mc.m
% ---------------------------------------------------------
% Aggregates replication outputs into mean and quantiles.
% Adds risk-estimator diagnostics (bias of DR/IPW/OR vs oracle MSE).
% ---------------------------------------------------------

R = numel(rep);
K = numel(rep{1}.arm_mse);

arm_mse = zeros(R, K);
policy_mse = zeros(R, 1);
final_regret = zeros(R, 1);

riskhat_dr  = NaN(R, K);
riskhat_ipw = NaN(R, K);
riskhat_or  = NaN(R, K);
riskhat_pi_dr = NaN(R,1);

for r=1:R
    arm_mse(r,:) = rep{r}.arm_mse(:)';
    policy_mse(r) = rep{r}.policy_mse;
    final_regret(r) = rep{r}.final_regret;

    riskhat_dr(r,:)  = rep{r}.riskhat_dr;
    riskhat_ipw(r,:) = rep{r}.riskhat_ipw;
    riskhat_or(r,:)  = rep{r}.riskhat_or;
    riskhat_pi_dr(r) = rep{r}.riskhat_pi_dr;
end

q = [0.10, 0.50, 0.90];

summary = struct();
summary.arm_mse_mean = mean(arm_mse, 1);
summary.policy_mse_mean = mean(policy_mse);
summary.arm_mse_q = quantile_local(arm_mse, q);
summary.policy_mse_q = quantile_local(policy_mse, q);
summary.final_regret_mean = mean(final_regret);
summary.final_regret_q = quantile_local(final_regret, q);

% Risk-estimator bias (relative to oracle arm MSE on acted-on set)
summary.risk_bias_dr_mean  = mean(riskhat_dr  - arm_mse, 1, 'omitnan');
summary.risk_bias_ipw_mean = mean(riskhat_ipw - arm_mse, 1, 'omitnan');
summary.risk_bias_or_mean  = mean(riskhat_or  - arm_mse, 1, 'omitnan');
summary.policy_dr_risk_mean = mean(riskhat_pi_dr, 'omitnan');

end

function Q = quantile_local(X, probs)
X = sort(X, 1);
n = size(X,1);
Q = zeros(numel(probs), size(X,2));
for j=1:numel(probs)
    p = probs(j);
    k = max(1, min(n, round(p*n)));
    Q(j,:) = X(k,:);
end
end
