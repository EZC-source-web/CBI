function yhat = imputer_raukf(Y_obs, M_avail, idx, t_end, p)
% imputer_raukf.m
% ---------------------------------------------------------
% Arm 5: Robust Adaptive Unscented/Kalman Filter (RAUKF).
%
% Implements the theoretical framework from Sections 1-2:
% Fits a 1-factor model where the process variance Q_t and 
% measurement variance R_t are adapted in real-time based on 
% the Normalized Innovation Squared (NIS). 
% Includes a Huber-style robustification to prevent isolated 
% outliers from causing permanent variance breaks.
% ---------------------------------------------------------

Y_obs   = force_panel(Y_obs,   p.N, p.T, 'Y_obs');
M_avail = force_panel(M_avail, p.N, p.T, 'M_avail');
t_end = min(max(3, t_end), p.T);

N = p.N; T = p.T;
Y = Y_obs(:, 1:t_end);
M = M_avail(:, 1:t_end);

% Quick sparsity check: if too sparse, fallback to ALS baseline
if nnz(M) < 0.05 * N * t_end
    yhat = imputer_pca_als1(Y_obs, M_avail, idx, t_end, p);
    return;
end

% --- 1. Initialization (using fast ALS-style cross-sectional means) ---
F = zeros(t_end,1);
for t=1:t_end
    obs = M(:,t);
    if any(obs)
        mt = nanmean_local(Y(obs,t));
        if isnan(mt); mt = 0; end
        F(t) = mt;
    end
end
lambda = zeros(N,1);
for i=1:N
    obs = M(i,:)';
    if any(obs) && sum(F(obs).^2) > 1e-6
        lambda(i) = sum(Y(i,obs)' .* F(obs)) / sum(F(obs).^2);
    end
end

% Estimate baseline AR(1) dynamics for the factor
phi = 0.8; % default prior
if t_end > 5
    F1 = F(1:end-1); F2 = F(2:end);
    if sum(F1.^2) > 1e-6
        phi = min(max(sum(F1.*F2)/sum(F1.^2), -0.98), 0.98);
    end
end

% Tuning parameters for adaptivity (from RAUKF theory)
rho_Q = 0.90; % Forgetting factor for Q
rho_R = 0.90; % Forgetting factor for R
huber_c = 4.0; % Huber clipping threshold for robustification

Q_t = 0.1; 
R_t = nanvar_local(Y(:)); if isnan(R_t) || R_t==0; R_t = 1.0; end

f_pred = 0;
P_pred = 1.0;

F_filt = zeros(t_end,1);

% --- 2. Adaptive Forward Filter (RAUKF Core) ---
for t=1:t_end
    % Predict step
    f_pr = phi * f_pred;
    P_pr = phi^2 * P_pred + Q_t;
    
    obs = M(:,t);
    if any(obs)
        y_t = Y(obs,t);
        h_t = lambda(obs);
        
        % Innovation
        v_t = y_t - h_t * f_pr;
        
        % Innovation variance S_t
        S_t = P_pr * (h_t.^2) + R_t;
        
        % Normalized Innovation Squared (NIS) - scalar equivalent
        nis = (v_t.^2) ./ S_t;
        mean_nis = mean(nis);
        
        % Robustification: Huber clipping to ignore massive isolated outliers
        mean_nis_clipped = min(mean_nis, huber_c);
        
        % Adaptive step: Update Q_t and R_t if NIS diverges from 1
        % (Theory: if NIS > 1, variance is underestimated)
        if mean_nis_clipped > 1.2 || mean_nis_clipped < 0.8
            alpha = 0.1; % learning rate
            Q_new = Q_t * (1 + alpha*(mean_nis_clipped - 1));
            R_new = R_t * (1 + alpha*(mean_nis_clipped - 1));
            % Smooth update
            Q_t = rho_Q * Q_t + (1 - rho_Q) * max(Q_new, 1e-4);
            R_t = rho_R * R_t + (1 - rho_R) * max(R_new, 1e-4);
        end
        
        % Filter Update (Kalman Gain)
        % Using the Woodbury identity for scalar state / vector observation
        S_inv = 1 ./ (P_pr * (h_t.^2) + R_t);
        K_gain = P_pr * (h_t .* S_inv);
        
        f_up = f_pr + sum(K_gain .* v_t);
        P_up = P_pr - P_pr^2 * sum((h_t.^2) .* S_inv);
        
        f_pred = f_up;
        P_pred = max(P_up, 1e-6);
    else
        % No observations, purely predict
        f_pred = f_pr;
        P_pred = P_pr;
    end
    
    F_filt(t) = f_pred;
end

% --- 3. Generate Imputations ---
[i_req, t_req] = ind2sub([N, T], idx);
yhat = zeros(numel(idx),1);

for j=1:numel(idx)
    i = i_req(j);
    tt = min(t_req(j), t_end); % No look-ahead
    yhat(j) = lambda(i) * F_filt(tt);
end

end