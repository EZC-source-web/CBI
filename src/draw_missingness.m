function [M_final, e0] = draw_missingness(X, p, r)
% draw_missingness.m
% ---------------------------------------------------------
% Generates base observation indicator M_final (N x T):
%   P(M_it = 1 | X_it) = e0(X_it)
%
% Baseline (A,B): e0(X) is correctly specified logit:
%   e0 = logistic(alpha0 + X*beta0)
%
% Misspec (C,D): true e0 includes an extra nonlinear term but we will still
% estimate a linear logit in estimate_nuisance(), so e_hat is misspecified.
%
% Output:
%   M_final : N x T logical
%   e0      : N x T double (clipped for overlap)
% ---------------------------------------------------------

rng(p.seed + 2*10^6 + r);

N = p.N; T = p.T;

if size(X,1) ~= N*T
    error('draw_missingness:X', 'X must be stacked (N*T) x d.');
end

eta_lin = X * p.beta0(:); % includes intercept via X(:,1)=1

switch p.scenario
    case {'A','B','E','E2'}
        eta = eta_lin;
    case {'C','D'}
        % Nonlinear true propensity (violates the linear logit model)
        % Use a bounded perturbation so overlap can still hold.
        z = X(:,2);
        eta = eta_lin + p.prop_nonlinear * 0.75 * sin(z);
    otherwise
        error('draw_missingness:scenario', 'Unknown scenario %s', p.scenario);
end

alpha0 = calibrate_alpha(eta, p.target_obs_rate);
e = logistic(alpha0 + eta);

% overlap clipping
c = p.overlap_clip;
e = min(max(e, c), 1-c);

U = rand(N*T,1);
Mvec = (U <= e);  % 1 = observed

M_final = reshape(Mvec, [N, T]);
e0 = reshape(e, [N, T]);

end
