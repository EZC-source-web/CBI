function [Y, F, lambda] = simulate_panel(p, r)
% simulate_panel.m (v6)
% ---------------------------------------------------------
% Generates a complete panel with a one-factor structure:
%   Y_it = g(lambda_i * F_t) + idio_it + eps_it
% where:
%   F_t = phi F_{t-1} + u_t
% and g depends on scenario.
%
% Scenario A: g(z) = z (linear)
% Scenario B: g(z) = z + kappa*(z^2 - E[z^2])  (nonlinear mean -> misspecifies linear m-hat)
% Scenario C/D: outcome linear, but propensity is nonlinear (handled in draw_missingness)
% Scenario E: "context matters" : units have group-specific idiosyncratic AR(1),
%             with group membership correlated with observable lambda_i.
% ---------------------------------------------------------

rng(p.seed + 10^6 + r);

N = p.N; T = p.T;

% Loadings
if isfield(p,'lambda_fixed') && ~isempty(p.lambda_fixed)
    lambda = p.lambda_fixed(:);
    if numel(lambda) ~= N
        error('lambda_fixed must have length N=%d', N);
    end
else
    lambda = p.sigma_lambda * randn(N,1);
end

% Common factor
F = zeros(T,1);
u = p.sigma_u * randn(T,1);
for t=2:T
    F(t) = p.phi * F(t-1) + u(t);
end

Z = lambda * F';             % N x T factor signal
eps = p.sigma_eps * randn(N,T);

% Idiosyncratic component (only used in scenario E)
idio = zeros(N,T);

switch p.scenario
    case 'A'
        Y = Z + eps;

    case 'B'
        z2 = Z.^2;
        Y = (Z + p.kappa * (z2 - mean(z2(:)))) + eps;

    case {'C','D'}
        Y = Z + eps;

    case 'E'
        % Split units into two groups using observable lambda_i:
        % high-persistence idiosyncrasy for lambda_i above median.
        med = median(lambda);
        phi_i = p.phi_idio_low * ones(N,1);
        phi_i(lambda >= med) = p.phi_idio_high;

        eta = p.sigma_idio * randn(N,T);
        for i=1:N
            for t=2:T
                idio(i,t) = phi_i(i) * idio(i,t-1) + eta(i,t);
            end
        end
        Y = Z + idio + eps;

    case 'E2'
        % Stronger "context matters" design.
        %
        % DEFAULT: two regimes indexed by observable loading lambda_i.
        % OPTIONAL: multiple regimes via p.regime_n and regime-specific
        % parameter vectors.
        %
        % Interpretation:
        %   - Low-lambda regime(s): strong common component + weak idiosyncrasy
        %     -> factor-based imputers dominate.
        %   - High-lambda regime(s): weak common component + strong persistent idio
        %     -> time-series imputers dominate.
        %
        % This DGP is motivated by dynamic factor models with serially
        % correlated idiosyncratic components and heterogeneous signal-to-noise.

        % ---- safe defaults for backward compatibility ----
        if ~isfield(p,'phi_idio_low');  p.phi_idio_low  = min(0.2, p.phi); end
        if ~isfield(p,'phi_idio_high'); p.phi_idio_high = max(0.9, p.phi); end
        if ~isfield(p,'sigma_idio');    p.sigma_idio    = p.sigma_eps; end

        % ---- regime assignment (toolbox-free quantile cuts) ----
        G = 2;
        if isfield(p,'regime_n') && ~isempty(p.regime_n) && p.regime_n>=2
            G = round(p.regime_n);
        end

        lam_sorted = sort(lambda(:));
        edges = [-Inf; zeros(G-1,1); Inf];
        for g=2:G
            idx = max(1, min(N, round((g-1)/G * N)));
            edges(g) = lam_sorted(idx);
        end

        grp = ones(N,1);
        for i=1:N
            for g=1:G
                if lambda(i) > edges(g) && lambda(i) <= edges(g+1)
                    grp(i) = g;
                    break;
                end
            end
        end

        % ---- regime-specific factor scaling ----
        if isfield(p,'lambda_scale_vec') && numel(p.lambda_scale_vec)==G
            lam_scale = p.lambda_scale_vec(:);
        else
            % Backward-compatible 2-regime defaults
            lamH = 0.5; lamL = 2.0;
            if isfield(p,'lambda_scale_high'); lamH = p.lambda_scale_high; end
            if isfield(p,'lambda_scale_low');  lamL = p.lambda_scale_low;  end
            lam_scale = linspace(lamL, lamH, G)';
        end

        lambda_eff = lambda;
        for g=1:G
            lambda_eff(grp==g) = lam_scale(g) * lambda_eff(grp==g);
        end
        Z = lambda_eff * F';

        % ---- regime-specific idiosyncratic AR(1) ----
        if isfield(p,'phi_idio_vec') && numel(p.phi_idio_vec)==G
            phi_vec = p.phi_idio_vec(:);
        else
            phi_vec = linspace(p.phi_idio_low, p.phi_idio_high, G)';
        end
        if isfield(p,'sigma_idio_vec') && numel(p.sigma_idio_vec)==G
            sig_vec = p.sigma_idio_vec(:);
        else
            if isfield(p,'sigma_idio_low') && isfield(p,'sigma_idio_high')
                sig_vec = linspace(p.sigma_idio_low, p.sigma_idio_high, G)';
            else
                sig_vec = linspace(p.sigma_idio, 2.5*p.sigma_idio, G)';
            end
        end

        phi_i = zeros(N,1);
        sig_i = zeros(N,1);
        for g=1:G
            phi_i(grp==g) = phi_vec(g);
            sig_i(grp==g) = sig_vec(g);
        end

        eta = randn(N,T);

        % Initialize from (approx.) stationary distribution when feasible
        denom = sqrt(max(1 - phi_i.^2, 1e-6));
        idio(:,1) = (sig_i ./ denom) .* eta(:,1);

        for t=2:T
            idio(:,t) = phi_i .* idio(:,t-1) + sig_i .* eta(:,t);
        end

        Y = Z + idio + eps;

otherwise
        error('simulate_panel:scenario', 'Unknown scenario %s', p.scenario);
end

end
