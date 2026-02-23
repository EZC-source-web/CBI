function mu = compute_true_mean_component(lambda, F, p)
% compute_true_mean_component.m (v6)
% ---------------------------------------------------------
% Returns the "oracle" mean component of Y under the simulation DGP.
% This is used only in Stage 3 (oracle nuisances) to illustrate the
% doubly robust pseudo-loss with true nuisances.
%
% For the baseline factor DGP:
%   Y_it = lambda_i * F_t + eps_it
% so mu_it = lambda_i * F_t.
%
% For nonlinear outcome scenario (B):
%   Y_it = g(lambda_i F_t) + eps_it
% so mu_it = g(lambda_i F_t).
% ---------------------------------------------------------

Z = lambda(:) * F(:)';  % N x T

switch p.scenario
    case {'A','C','D','E'}
        mu = Z;
    case 'B'
        % Centered quadratic nonlinearity (stronger mean misspecification than odd polynomials)
        s2 = mean(Z(:).^2);
        mu = Z + p.kappa * (Z.^2 - s2);
    otherwise
        mu = Z;
end

end
