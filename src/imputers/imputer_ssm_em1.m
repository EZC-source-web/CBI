function yhat = imputer_ssm_em1(Y_obs, M_avail, idx, t_end, p)
% imputer_ssm_em1.m
% ---------------------------------------------------------
% Arm 4: dynamic factor imputer via a simple EM algorithm + Kalman smoother.
%
% We fit a one-factor state-space model on data up to t_end:
%   f_t = phi f_{t-1} + u_t, u_t ~ N(0,Q)
%   y_{it} = lambda_i f_t + eps_{it}, eps ~ N(0,R)
%
% Missingness handled by ignoring unavailable observations.
%
% Robustness notes:
% - EM iterations limited (p.ssm_max_iter)
% - variances floored by p.ssm_min_var
% - if data are extremely sparse, fall back to ALS (arm 3)
% ---------------------------------------------------------

Y_obs   = force_panel(Y_obs,   p.N, p.T, 'Y_obs');
M_avail = force_panel(M_avail, p.N, p.T, 'M_avail');
t_end = min(max(3, t_end), p.T);

N = p.N; T = p.T;

Y = Y_obs(:, 1:t_end);
M = M_avail(:, 1:t_end);

% Quick sparsity check
if nnz(M) < 0.05 * N * t_end
    yhat = imputer_pca_als1(Y_obs, M_avail, idx, t_end, p);
    return;
end

% ------------------ Initialization ------------------
% Proxy factor = cross-sectional mean at each t.
F0 = zeros(t_end,1);
for t=1:t_end
    obs = M(:,t);
    if any(obs)
        F0(t) = nanmean_local(Y(obs,t));
    else
        F0(t) = 0;
    end
end
if norm(F0) < 1e-8
    F0 = randn(t_end,1) * 1e-2;
end
F0 = F0 / max(norm(F0), 1e-8);

% Initial loadings by regression on proxy factor
lambda = zeros(N,1);
for i=1:N
    obs = M(i,:);
    if any(obs)
        num = sum(Y(i,obs)' .* F0(obs));
        den = sum(F0(obs).^2) + 1e-6;
        lambda(i) = num / den;
    else
        lambda(i) = 0;
    end
end

phi = p.phi;
Q = max(p.ssm_min_var, 0.5);
R = max(p.ssm_min_var, 1.0);

f0 = 0;
P0 = 1;

prev_ll = -Inf;

% ------------------ EM iterations ------------------
for it=1:p.ssm_max_iter
    % E-step: Kalman smoother
    [fs, Ps, Pcs] = kalman_smoother_scalar_multiobs(Y, M, lambda, phi, Q, R, f0, P0);

    Ef  = fs;
    Ef2 = Ps + fs.^2;

    % M-step: update lambda_i
    for i=1:N
        obs = M(i,:);
        if any(obs)
            num = sum(Y(i,obs)' .* Ef(obs));
            den = sum(Ef2(obs)) + 1e-6;
            lambda(i) = num / den;
        else
            lambda(i) = 0;
        end
    end

    % Update R (measurement variance)
    ss = 0; nn = 0;
    for t=1:t_end
        obs = M(:,t);
        if any(obs)
            y = Y(obs,t);
            h = lambda(obs);
            resid2 = (y - h * Ef(t)).^2 + (h.^2) * Ps(t);
            ss = ss + sum(resid2);
            nn = nn + numel(y);
        end
    end
    if nn > 0
        R = max(p.ssm_min_var, ss / nn);
    end

    % Update phi and Q
    if p.ssm_estimate_phi
        num = 0; den = 0;
        for t=2:t_end
            Eftftm1 = Pcs(t) + fs(t)*fs(t-1);
            num = num + Eftftm1;
            den = den + Ef2(t-1);
        end
        if den > 0
            phi = num / den;
            phi = min(max(phi, -0.98), 0.98);
        end
    end

    qsum = 0;
    for t=2:t_end
        Eftftm1 = Pcs(t) + fs(t)*fs(t-1);
        qsum = qsum + (Ef2(t) - 2*phi*Eftftm1 + phi^2*Ef2(t-1));
    end
    Q = max(p.ssm_min_var, qsum / max(1, t_end-1));

    % Stop rule (proxy; good enough for demo-scale)
    ll = -0.5*(log(Q) + log(R));
    if abs(ll - prev_ll) < p.ssm_tol
        break;
    end
    prev_ll = ll;
end

% ------------------ Prediction ------------------
[i_req, t_req] = ind2sub([N, T], idx);

F_ext = zeros(T,1);
F_ext(1:t_end) = fs;
if t_end < T
    F_ext(t_end+1:T) = fs(end);
end

yhat = lambda(i_req) .* F_ext(t_req);

end
