function beta = logit_fit_irls(X, y, lambda, maxit, tol)
% logit_fit_irls.m
% ---------------------------------------------------------
% Logistic regression via IRLS (toolbox-free), with ridge penalty.
%
% Minimizes:
%   - sum_i [ y_i log p_i + (1-y_i) log(1-p_i) ] + (lambda/2)||beta||^2
%
% Returns:
%   beta (d x 1)
% ---------------------------------------------------------

[n,d] = size(X);
beta = zeros(d,1);

for it=1:maxit
    eta = X*beta;
    p = logistic(eta);

    % weights and working response
    W = p .* (1-p);
    W = max(W, 1e-8);

    z = eta + (y - p) ./ W;

    % solve weighted ridge LS: (X'WX + lambda I) beta = X'Wz
    XW = X .* W;                % each row scaled by W_i
    XtWX = X' * XW;
    XtWz  = X' * (W .* z);

    beta_new = (XtWX + lambda*eye(d)) \ XtWz;

    if norm(beta_new - beta) / max(1, norm(beta)) < tol
        beta = beta_new;
        return;
    end
    beta = beta_new;
end

end
