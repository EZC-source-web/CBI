function dr = compute_dr_pseudoloss(idxV, yhat_store, Y_true, nuis, p)
% compute_dr_pseudoloss.m (v6)
% ---------------------------------------------------------
% Feedback loss used for learning on revealed indices idxV.
%
% Two modes:
%   p.loss_mode = 'dr'       : doubly robust pseudo-loss (default)
%   p.loss_mode = 'observed' : observed squared loss on revealed cells
%
% DR pseudo-loss for squared error on revealed indices idxV:
%   \tilde\ell_it^{(k)} =
%      (1/e_hat(X_it)) * (yhat - y)^2
%    - (1/e_hat(X_it) - 1) * (yhat - m_hat(X_it))^2
%
% Since idxV are revealed, M_it=1 on idxV.
% ---------------------------------------------------------

K = size(yhat_store,2);
y = Y_true(idxV);

dr = NaN(numel(idxV), K);

if strcmp(p.loss_mode,'observed')
    for k=1:K
        yh = yhat_store(idxV,k);
        dr(:,k) = (yh - y).^2;
    end
    return;
end

% DR mode
e = p.rho_reveal * ones(numel(idxV),1);
m = nuis.m_hat(idxV);
% Residual variance term for squared-error risk (may be scalar or vector)
if isfield(nuis,'sigma2_hat')
    if isscalar(nuis.sigma2_hat)
        sig2 = nuis.sigma2_hat * ones(numel(idxV),1);
    else
        sig2 = nuis.sigma2_hat(idxV);
    end
else
    sig2 = zeros(numel(idxV),1);
end

c = p.overlap_clip;
e = min(max(e, c), 1-c);

for k=1:K
    yh = yhat_store(idxV,k);
    l1 = (yh - y).^2;
    l0 = (yh - m).^2 + sig2;
    dr(:,k) = (1./e).*l1 - (1./e - 1).*l0;
end

end
