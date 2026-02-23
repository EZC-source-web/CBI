function yhat = imputer_ar1(Y_obs, M_avail, idx, t_end, p)
% imputer_ar1.m
% ---------------------------------------------------------
% Arm 2: univariate AR(1) per unit, estimated on available data up to t_end.
%
% For each unit i:
%   y_it = a_i + phi_i y_{i,t-1} + eps_it
% estimated by OLS using consecutive observed pairs (t-1,t) where both observed.
% If insufficient data, falls back to last observed value (or 0).
%
% Missing gaps are forecasted iteratively.
% ---------------------------------------------------------

Y_obs   = force_panel(Y_obs,   p.N, p.T, 'Y_obs');
M_avail = force_panel(M_avail, p.N, p.T, 'M_avail');
t_end = min(max(2, t_end), p.T); % need at least 2 for AR(1)

N = p.N; T = p.T;

[i_req, t_req] = ind2sub([N, T], idx);
yhat = zeros(numel(idx),1);

% Pre-estimate AR(1) params for each i (cheap for small N)
phi = zeros(N,1);
a   = zeros(N,1);

for i=1:N
    y = Y_obs(i,1:t_end);
    m = M_avail(i,1:t_end);

    % find consecutive observed pairs
    ok = (m(2:end) & m(1:end-1));
    if nnz(ok) >= 5
        y1 = y(1:end-1); y2 = y(2:end);
        x = y1(ok);  z = y2(ok);

        % OLS with intercept
        X = [ones(numel(x),1), x(:)];
        b = X \ z(:);
        a(i) = b(1);
        phi(i) = b(2);
        % stability guard
        phi(i) = min(max(phi(i), -0.98), 0.98);
    else
        % fallback
        phi(i) = 0.0;
        a(i) = 0.0;
    end
end

% Forecast each requested cell
for j=1:numel(idx)
    i = i_req(j);
    tt = t_req(j);

    if tt < 1
        yhat(j) = 0;
        continue;
    end

    % only use data up to min(tt-1, t_end)
    tmax = min(tt-1, t_end);
    y = Y_obs(i,1:tmax);
    m = M_avail(i,1:tmax);

    if any(m)
        last_t = find(m, 1, 'last');
        y_last = y(last_t);
        steps = tt - last_t;

        % iterate forward
        y_f = y_last;
        for s=1:steps
            y_f = a(i) + phi(i) * y_f;
        end
        yhat(j) = y_f;
    else
        yhat(j) = 0;
    end
end

end
