function [M0, holdout, p_hold] = apply_holdout(M_final, X, p, r)
% apply_holdout.m (v6)
% ---------------------------------------------------------
% DATA RELEASE LAYER.
% Starting from base observability M_final (Omega), create a decision-time
% vintage M0 by holding out a subset of base-observed cells.
%
% Interpretation (consistent with Theory.tex):
%   - Omega          : { (i,t): M_final(i,t)=1 }
%   - holdout subset : delayed-release cells (hidden at decision time)
%   - M0             : available at decision time (vintage)
%
% Modes:
%   - 'random' : holdout is an i.i.d. subset of Omega with rate holdout_rate
%   - 'logit'  : holdout probability depends on context X_it (still MAR).
%
% Outputs:
%   M0       : N x T logical
%   holdout  : N x T logical, subset of (M_final==1)
%   p_hold   : N x T double, holdout probabilities (for diagnostics)
% ---------------------------------------------------------

rng(p.seed + 3*10^6 + r);

M_final = force_panel(M_final, p.N, p.T, 'M_final');

if size(X,1) ~= p.N*p.T
    error('apply_holdout:X','X must be stacked (N*T) x d.');
end

obs_idx = find(M_final(:));
holdout = false(p.N*p.T,1);

switch p.holdout_mode
    case 'random'
        nh = round(p.holdout_rate * numel(obs_idx));
        if nh > 0
            perm = obs_idx(randperm(numel(obs_idx), nh));
            holdout(perm) = true;
        end
        p_hold = zeros(p.N*p.T,1);
        p_hold(obs_idx) = p.holdout_rate;

    case 'logit'
        eta = X * p.holdout_beta(:);
        % Calibrate alpha so that E[ logistic(alpha+eta) | M_final=1 ] = holdout_rate
        alpha = calibrate_alpha_on_subset(eta, obs_idx, p.holdout_rate);
        pvec = logistic(alpha + eta);

        % Clip (avoid degenerate schedules)
        pvec = min(max(pvec, 1e-4), 1-1e-4);

        U = rand(p.N*p.T,1);
        holdout(obs_idx) = (U(obs_idx) <= pvec(obs_idx));
        p_hold = pvec;

    otherwise
        error('apply_holdout:mode','Unknown holdout_mode %s', p.holdout_mode);
end

holdout = reshape(holdout, [p.N, p.T]);
M0 = M_final & ~holdout;

p_hold = reshape(p_hold, [p.N, p.T]);

end

% --- local helper: bisection calibration on subset ---
function alpha = calibrate_alpha_on_subset(eta, idx, target)
f = @(a) mean( logistic(a + eta(idx)) ) - target;

aL = -30; aU = 30;
fL = f(aL); fU = f(aU);
if fL > 0 || fU < 0
    alpha = 0;
    return;
end
for it=1:80
    aM = 0.5*(aL+aU);
    if f(aM) > 0
        aU = aM;
    else
        aL = aM;
    end
end
alpha = 0.5*(aL+aU);
end
