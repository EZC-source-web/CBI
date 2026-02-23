function nuis = estimate_nuisance(Y_obs, M_final, M0, X, p)
% estimate_nuisance.m
% ---------------------------------------------------------
% Estimates nuisance functions needed by the DR pseudo-loss:
%   e_hat(X) : propensity score for base observability M_final
%   m_hat(X) : outcome regression E[Y|X]
%
% Consistency with theory:
% - M_final corresponds to M_{it} in Theory.tex (base observation indicator).
% - m_hat is trained on decision-time observed outcomes (M0==1), to avoid
%   look-ahead into held-out revealed cells.
%
% Extra diagnostics:
% - sigma2_hat: residual variance estimate from m_hat (used to form an
%   outcome-regression-only pseudo-loss for simulation comparisons).
% ---------------------------------------------------------

Y_obs  = force_panel(Y_obs,  p.N, p.T, 'Y_obs');
M_final= force_panel(M_final,p.N, p.T, 'M_final');
M0     = force_panel(M0,     p.N, p.T, 'M0');

% --- e_hat: fit (possibly misspecified) linear logit to M_final ---
y = double(M_final(:));
beta_e = logit_fit_irls(X, y, p.ridge_lambda_logit, p.max_irls_iter, p.irls_tol);
e_hat = logistic(X * beta_e);

% overlap clip
c = p.overlap_clip;
e_hat = min(max(e_hat, c), 1-c);

% --- m_hat: pooled ridge regression on decision-time observed cells ---
obs_idx = find(M0(:));
Yv = Y_obs(obs_idx);
Xv = X(obs_idx,:);

beta_m = ridge_fit(Xv, Yv, p.ridge_lambda_m);
m_hat = X * beta_m;

% Residual variance estimate (population variance, toolbox-free)
res = Yv - Xv*beta_m;
sigma2_hat = mean(res.^2);

nuis = struct();
nuis.beta_e = beta_e;
nuis.e_hat  = e_hat;
nuis.beta_m = beta_m;
nuis.m_hat  = m_hat;
nuis.sigma2_hat = sigma2_hat;

end
