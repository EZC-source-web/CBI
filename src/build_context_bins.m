function ctx = build_context_bins(lambda, T, qx, qt)
% build_context_bins.m
% ---------------------------------------------------------
% Finite binning of context to implement a truly contextual policy without
% fitting a high-dimensional model.
%
% Bins:
%   - lambda bins: quantiles of lambda_i (qx bins)
%   - time bins: equally spaced bins on t/T (qt bins)
%
% Output:
%   ctx.bin_id : (N*T) x 1 integer bin id in {1,...,qx*qt}
% ---------------------------------------------------------

N = numel(lambda);

% lambda quantile edges (toolbox-free)
lam_sorted = sort(lambda(:));
edges_x = zeros(qx+1,1);
edges_x(1) = -Inf;
edges_x(end) = Inf;
for b=2:qx
    idx = max(1, min(N, round((b-1)/qx * N)));
    edges_x(b) = lam_sorted(idx);
end

% time edges
edges_t = linspace(0, 1, qt+1);
edges_t(1) = -Inf; edges_t(end) = Inf;

bin_id = zeros(N*T,1);
row = 0;
for t=1:T
    tt = t / T;
    bt = find(tt > edges_t(1:end-1) & tt <= edges_t(2:end), 1, 'first');
    for i=1:N
        row = row + 1;
        bx = find(lambda(i) > edges_x(1:end-1) & lambda(i) <= edges_x(2:end), 1, 'first');
        bin_id(row) = (bt-1)*qx + bx;
    end
end

ctx = struct();
ctx.bin_id = bin_id;
ctx.qx = qx;
ctx.qt = qt;

ctx.C = qx*qt;
end

