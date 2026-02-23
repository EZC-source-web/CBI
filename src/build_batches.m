function [I_batches, t_end_batches] = build_batches(action_mask, p)
% build_batches.m (v6)
% ---------------------------------------------------------
% Partition the ACTION SET into B batches.
% action_mask(i,t)=1 indicates a cell for which an imputation decision will be taken.
%
% Default batching is time-ordered to mimic real-time processing.
%
% Output:
%   I_batches     : cell{B,1} of linear indices into N x T
%   t_end_batches : B x 1 end time for each batch (used to restrict training window)
% ---------------------------------------------------------

action_mask = force_panel(action_mask, p.N, p.T, 'action_mask');
N = p.N; T = p.T;

I_batches = cell(p.B,1);
t_end_batches = zeros(p.B,1);

if ~p.batch_by_time
    idx_all = find(action_mask);
    % random partition
    perm = idx_all(randperm(numel(idx_all)));
    edges = round(linspace(0, numel(perm), p.B+1));
    for b=1:p.B
        I_batches{b} = perm(edges(b)+1 : edges(b+1));
        t_end_batches(b) = T;
    end
    return;
end

% Time-ordered batches
edgesT = round(linspace(1, T+1, p.B+1));
edgesT(1) = 1; edgesT(end) = T+1;

for b=1:p.B
    t0 = edgesT(b);
    t1 = edgesT(b+1)-1;
    t1 = max(min(t1, T), 1);
    t0 = max(min(t0, T), 1);
    t_end_batches(b) = t1;

    if t1 < t0
        I_batches{b} = [];
        continue;
    end

    [ii, jj] = find(action_mask(:, t0:t1));
    if isempty(ii)
        I_batches{b} = [];
        continue;
    end
    tt = t0 + (jj - 1);
    I_batches{b} = sub2ind([N, T], ii, tt);
end

end
