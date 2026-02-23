function yhat = imputer_cs_mean(Y_obs, M_avail, idx, t_end, p)
% imputer_cs_mean.m
% ---------------------------------------------------------
% Arm 1: cross-sectional mean imputer.
% For each requested cell (i,t), impute by mean of available observations
% at time t using data up to t_end.
%
% This is a very strong baseline in factor models when cross-sectional
% heterogeneity is limited.
% ---------------------------------------------------------

Y_obs   = force_panel(Y_obs,   p.N, p.T, 'Y_obs');
M_avail = force_panel(M_avail, p.N, p.T, 'M_avail');
t_end = min(max(1, t_end), p.T);

N = p.N;
T = p.T;

[i_req, t_req] = ind2sub([N, T], idx);

yhat = zeros(numel(idx),1);

for j=1:numel(idx)
    tt = t_req(j);

    if tt < 1 || tt > t_end
        % no look-ahead: if request is beyond t_end, fallback to last available time
        tt = t_end;
    end

    obs = M_avail(:,tt);

    if any(obs)
        mt = nanmean_local(Y_obs(obs,tt));
        if isnan(mt); mt = 0; end
        yhat(j) = mt;
    else
        yhat(j) = 0;
    end
end

end
