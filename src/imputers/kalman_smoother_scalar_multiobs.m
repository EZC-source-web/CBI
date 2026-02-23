function [fs, Ps, Pcs] = kalman_smoother_scalar_multiobs(Y, M, lambda, phi, Q, R, f0, P0)
% kalman_smoother_scalar_multiobs.m
% ---------------------------------------------------------
% Kalman filter + RTS smoother for a scalar AR(1) state observed through
% multiple noisy measurements (cross-section) with missingness.
%
% Model:
%   f_t = phi f_{t-1} + u_t,      u_t ~ N(0,Q)
%   y_{it} = lambda_i f_t + eps,  eps ~ N(0,R) iid across i
%
% At each t, only indices i with M(i,t)=1 are observed.
%
% Outputs:
%   fs  : T x 1 smoothed state mean E[f_t | y_1:T]
%   Ps  : T x 1 smoothed state variance Var(f_t | y_1:T)
%   Pcs : T x 1 smoothed lag-1 covariance Cov(f_t,f_{t-1} | y_1:T) with Pcs(1)=NaN
%
% Implementation avoids matrix inversion by exploiting scalar-state formulas:
%   innovation variance: S = R + P_pred * sum(lambda_obs.^2)
%   gain: K = P_pred * sum(lambda_obs .* (y_obs - lambda_obs f_pred)) / S
%   P_upd = P_pred * R / S
% ---------------------------------------------------------

[N,T] = size(Y);

% Filter storage
f_pred = zeros(T,1);
P_pred = zeros(T,1);
f_filt = zeros(T,1);
P_filt = zeros(T,1);

% Initialization
f_prev = f0;
P_prev = P0;

for t=1:T
    % Predict
    f_pr = phi * f_prev;
    P_pr = phi^2 * P_prev + Q;

    f_pred(t) = f_pr;
    P_pred(t) = P_pr;

    obs = M(:,t);
    if any(obs)
        y = Y(obs,t);
        h = lambda(obs);

        h2 = sum(h.^2);
        S = R + P_pr * h2;

        % scalar equivalent of H'*(y - H f_pr)
        innov_proj = sum(h .* (y - h * f_pr));

        f_up = f_pr + (P_pr * innov_proj) / S;
        P_up = P_pr * R / S;
    else
        f_up = f_pr;
        P_up = P_pr;
    end

    f_filt(t) = f_up;
    P_filt(t) = max(P_up, 1e-12);

    f_prev = f_up;
    P_prev = P_up;
end

% RTS smoother
fs = zeros(T,1);
Ps = zeros(T,1);
Pcs = NaN(T,1);

fs(T) = f_filt(T);
Ps(T) = P_filt(T);

for t=T-1:-1:1
    % smoother gain
    C = P_filt(t) * phi / max(P_pred(t+1), 1e-12);

    fs(t) = f_filt(t) + C * (fs(t+1) - f_pred(t+1));
    Ps(t) = P_filt(t) + C^2 * (Ps(t+1) - P_pred(t+1));

    % lag-1 covariance
    Pcs(t+1) = C * Ps(t+1);
end

end
