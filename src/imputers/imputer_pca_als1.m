function yhat = imputer_pca_als1(Y_obs, M_avail, idx, t_end, p)
% imputer_pca_als1.m
% ---------------------------------------------------------
% Arm 3: static one-factor imputer via Alternating Least Squares (ALS) with missingness.
% Fits:
%   Y_it ≈ lambda_i * F_t
% on data up to t_end using only available entries (M_avail==1).
%
% Robustness improvements (v5):
% - ridge regularization in both ALS steps
% - normalization of F at each iteration to prevent scale explosion
% - early stopping
% - prediction cap p.als_ycap to avoid blow-ups in early iterations
% ---------------------------------------------------------

Y_obs   = force_panel(Y_obs,   p.N, p.T, 'Y_obs');
M_avail = force_panel(M_avail, p.N, p.T, 'M_avail');
t_end = min(max(2, t_end), p.T);

N = p.N; T = p.T;

Y = Y_obs(:, 1:t_end);
M = M_avail(:, 1:t_end);

% Initialize F using cross-sectional means (fallback to zeros)
F = zeros(t_end,1);
for t=1:t_end
    obs = M(:,t);
    if any(obs)
        mt = nanmean_local(Y(obs,t));
        if isnan(mt); mt = 0; end
        F(t) = mt;
    else
        F(t) = 0;
    end
end
if norm(F) < 1e-8
    F = randn(t_end,1) * 1e-2;
end

% Normalize F and initialize lambda
scale = max(norm(F), 1e-8);
F = F / scale;
lambda = zeros(N,1);

prev_obj = Inf;

for it=1:p.als_max_iter
    % --- Update lambda (unit loadings) ---
    for i=1:N
        obs = M(i,:);
        if any(obs)
            Fi = F(obs);
            yi = Y(i,obs)';
            num = sum(yi .* Fi);
            den = sum(Fi.^2) + p.als_ridge;
            lambda(i) = num / den;
        else
            lambda(i) = 0;
        end
    end

    % --- Update F (time factor) ---
    for t=1:t_end
        obs = M(:,t);
        if any(obs)
            lt = lambda(obs);
            yt = Y(obs,t);
            num = sum(yt .* lt);
            den = sum(lt.^2) + p.als_ridge;
            F(t) = num / den;
        else
            F(t) = 0;
        end
    end

    % --- Normalize to avoid scale explosion ---
    scale = max(norm(F), 1e-8);
    F = F / scale;
    lambda = lambda * scale;

    % --- Objective for early stopping ---
    obj = 0;
    for t=1:t_end
        obs = M(:,t);
        if any(obs)
            r = Y(obs,t) - lambda(obs) * F(t);
            obj = obj + sum(r.^2);
        end
    end
    obj = obj + p.als_ridge * (sum(lambda.^2) + sum(F.^2));

    if abs(prev_obj - obj) / max(1, prev_obj) < p.als_tol
        break;
    end
    prev_obj = obj;
end

% Predict requested indices (using estimated lambda and F at time t)
[i_req, t_req] = ind2sub([N, T], idx);

% Guard: if some requests have t > t_end, forecast with last factor value
F_ext = zeros(T,1);
F_ext(1:t_end) = F;
if t_end < T
    F_ext(t_end+1:T) = F(t_end);
end

yhat = lambda(i_req) .* F_ext(t_req);

% Clip predictions to avoid large errors dominating MSE
yhat = clamp(yhat, -p.als_ycap, p.als_ycap);

end
