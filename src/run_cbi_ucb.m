function algo = run_cbi_ucb(Y_true, Y_obs_init, M_final, M0_init, holdout, action_mask, X, ctx, I_batches, t_end_batches, nuis, p)
% run_cbi_ucb.m (v6)
% ---------------------------------------------------------
% Batched contextual bandit imputation with delayed data releases.
%
% THEORY-TO-CODE MAPPING (data release interpretation)
% ---------------------------------------------------
% Omega:        M_final(i,t)=1  (ultimately observed)
% Vintage:      M0_init(i,t)=1  (available at decision time)
% Holdout:      holdout(i,t)=1  (delayed-release subset of Omega)
% Revealed set: V_b subset of holdout released at batch b after delay Delta
% Action set:   action_mask (default: holdout_only)
%
% Learning signal:
% - doubly robust pseudo-loss (compute_dr_pseudoloss)
%
% No look-ahead:
% - imputers and nuisance estimators use only vintage-available outcomes,
%   updated as releases arrive.
% ---------------------------------------------------------

% Shape guards
Y_true    = force_panel(Y_true,    p.N, p.T, 'Y_true');
Y_obs_init= force_panel(Y_obs_init,p.N, p.T, 'Y_obs_init');
M_final   = force_panel(M_final,   p.N, p.T, 'M_final');
M0_init   = force_panel(M0_init,   p.N, p.T, 'M0_init');
holdout   = force_panel(holdout,   p.N, p.T, 'holdout');
action_mask = force_panel(action_mask, p.N, p.T, 'action_mask');

N = p.N; T = p.T;
K = 4; % number of arms (fixed in this package)

% Flatten for speed / simplicity
Y_true = Y_true(:);
Y_obs  = Y_obs_init(:);
M_avail= logical(M0_init(:));
holdout = logical(holdout(:));
action_mask = logical(action_mask(:));

% Context bin map: bin_id is a function handle (linear index -> bin in 1..C)
bin_id = ctx.bin_id;
C = ctx.C;

NT = N*T;
yhat_store  = NaN(NT, K);
yhat_policy = NaN(NT, 1);
action      = NaN(NT, 1);

% Bandit stats per bin (risk minimization)
sumDR    = zeros(K, C);
% Revealed *selection* counts per (arm,context). DR provides an estimate for
% each arm at each revealed time, but the reliability of arm-k's estimate is
% largely driven by how often arm-k has been *played* (and revealed) in that
% context bin.
countSelKC = zeros(K, C);
% Total revealed count per context-cell (diagnostics + log-term)
countV   = zeros(1, C);

% Delayed release schedule
V_sched = cell(p.B + p.Delta, 1);

% Diagnostics
regret_revealed = NaN(p.B,1);
revealed_count  = zeros(p.B,1);

Rhat_dr_batch  = NaN(K, p.B);
Rhat_ipw_batch = NaN(K, p.B);
Rhat_or_batch  = NaN(K, p.B);
Rhat_pi_dr     = NaN(p.B,1);

for b=1:p.B
    % (1) Incorporate releases arriving now (data release)
    idxV_now = V_sched{b};
    if ~isempty(idxV_now)
        Y_obs(idxV_now) = Y_true(idxV_now);
        M_avail(idxV_now) = true;
    end

    % (2) Optional nuisance update on updated vintage
    if strcmp(p.nuisance_update,'batch') && b>1 && strcmp(p.nuisance_mode,'estimated')
        nuis = estimate_nuisance(reshape(Y_obs, [N,T]), reshape(M_final,[N,T]), reshape(M_avail,[N,T]), X, p);
        % Flatten nuisances
        nuis.e_hat = nuis.e_hat(:);
        nuis.m_hat = nuis.m_hat(:);
    end

    % (3) Update bandit statistics using revealed feedback (DR pseudo-loss)
    if ~isempty(idxV_now)
        revealed_count(b) = numel(idxV_now);

        dr = compute_dr_pseudoloss(idxV_now, yhat_store, Y_true, nuis, p);

        % IPW-only and OR-only pseudo-losses (diagnostics)
        y = Y_true(idxV_now);
        e = p.rho_reveal * ones(numel(idxV_now),1);
        m = nuis.m_hat(idxV_now);
        sig2 = nuis.sigma2_hat;
        c = p.overlap_clip; e = min(max(e, c), 1-c);

        ipw = NaN(size(dr));
        orp = NaN(size(dr));
        for k=1:K
            yh = yhat_store(idxV_now,k);
            l1 = (yh - y).^2;
            l0 = (yh - m).^2;
            ipw(:,k) = (1./e).*l1;
            orp(:,k) = l0 + sig2;
        end

        for j=1:numel(idxV_now)
            idx = idxV_now(j);
            cbin = bin_id(idx);
            sumDR(:,cbin) = sumDR(:,cbin) + dr(j,:)';
            countV(cbin)  = countV(cbin) + 1;
            a_sel = action(idx);
            if ~isnan(a_sel)
                countSelKC(a_sel,cbin) = countSelKC(a_sel,cbin) + 1;
            end
        end

        Rhat_dr_batch(:,b)  = mean(dr, 1)';
        Rhat_ipw_batch(:,b) = mean(ipw,1)';
        Rhat_or_batch(:,b)  = mean(orp,1)';

        % Policy DR risk on V_b (using chosen action)
        lpi = zeros(numel(idxV_now),1);
        for j=1:numel(idxV_now)
            idx = idxV_now(j);
            a = action(idx);
            if isnan(a)
                lpi(j) = NaN;
            else
                lpi(j) = dr(j,a);
            end
        end
        Rhat_pi_dr(b) = nanmean(lpi);

        % Revealed regret (squared loss)
        reg = 0;
        for j=1:numel(idxV_now)
            idx = idxV_now(j);
            yj = Y_true(idx);
            losses = (yhat_store(idx,:) - yj).^2;
            lpol = (yhat_policy(idx) - yj).^2;
            reg = reg + (lpol - min(losses));
        end
        if p.normalize_regret
            regret_revealed(b) = reg / max(1, numel(idxV_now));
        else
            regret_revealed(b) = reg;
        end
    else
        revealed_count(b) = 0;
        regret_revealed(b) = 0;
    end

    % (4) Impute cells in batch b with current vintage (no look-ahead)
    idxB = I_batches{b};
    if isempty(idxB)
        continue;
    end
    t_end = t_end_batches(b);

    y1 = imputer_cs_mean(Y_obs, M_avail, idxB, t_end, p);
    y2 = imputer_ar1(Y_obs, M_avail, idxB, t_end, p);
    y3 = imputer_pca_als1(Y_obs, M_avail, idxB, t_end, p);
    y4 = imputer_ssm_em1(Y_obs, M_avail, idxB, t_end, p);

    yhat_store(idxB,1) = y1;
    yhat_store(idxB,2) = y2;
    yhat_store(idxB,3) = y3;
    yhat_store(idxB,4) = y4;

    % (5) Choose actions with contextual LCB and store policy imputations
    for j=1:numel(idxB)
        idx = idxB(j);
        cbin = bin_id(idx);

        % UCB/LCB should be computed per (arm,context-cell), not just per context.
        % Otherwise the bonus is identical across arms and the exploration
        % constant has (almost) no effect.
        nk = countSelKC(:,cbin);
        if any(nk < p.min_reveals_for_ucb)
            under = find(nk < p.min_reveals_for_ucb);
            a = under(randi(numel(under)));
        else
            % Mean DR risk estimate (all revealed data in this context cell)
            meanR = sumDR(:,cbin) / max(1, countV(cbin));
            % Arm-specific exploration bonus based on how often we have
            % actually *selected* each arm in this context cell.
            t_c = countV(cbin);
            bonus = p.ucb_c * sqrt(log(1 + t_c) ./ max(1, nk));
            lcb = meanR - bonus;
            [~, a] = min(lcb);
        end
        action(idx) = a;
        yhat_policy(idx) = yhat_store(idx, a);
    end

    % (6) Schedule delayed data release for HOLDOUT cells in this batch
    eligible = idxB(holdout(idxB));   % only delayed-release cells can become revealed
    if ~isempty(eligible)
        U = rand(size(eligible));
        to_reveal = eligible(U < p.rho_reveal);
        if ~isempty(to_reveal)
            bb = b + p.Delta;
            if bb <= numel(V_sched)
                V_sched{bb} = [V_sched{bb}; to_reveal];
            end
        end
    end
end

algo = struct();
algo.K = K;
algo.yhat_store = yhat_store;
algo.yhat_policy = yhat_policy;
algo.action = action;

algo.sumDR = sumDR;
algo.countV = countV;
algo.countSelKC = countSelKC;

algo.V_sched = V_sched;
algo.M_avail_final = reshape(M_avail, [N,T]);

algo.regret_revealed = regret_revealed;
algo.revealed_count = revealed_count;

algo.Rhat_dr_batch  = Rhat_dr_batch;
algo.Rhat_ipw_batch = Rhat_ipw_batch;
algo.Rhat_or_batch  = Rhat_or_batch;
algo.Rhat_pi_dr     = Rhat_pi_dr;

algo.I_batches = I_batches; % save batch partition for diagnostics
algo.t_end_batches = t_end_batches(:); % save time endpoints for diagnostics
end
