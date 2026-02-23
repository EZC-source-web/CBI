function plot_diagnostics(res)
% plot_diagnostics.m
% ---------------------------------------------------------
% Simple plotting utility (toolbox-free) to inspect learning dynamics.
%
% Usage:
%   res = run_mc(p);
%   plot_diagnostics(res);
%
% It uses the first replication as an illustration.
% ---------------------------------------------------------

rep = res.rep{1};
algo = rep.algo;

figure;
plot(cumsum(algo.regret_revealed), 'LineWidth', 1.5);
xlabel('Batch b'); ylabel('Cumulative revealed regret');
title('CBI-UCB learning dynamics');

figure;
imagesc(algo.Rhat_dr_batch);
colorbar;
xlabel('Batch b'); ylabel('Arm k');
title('Batch-wise DR risk estimates (arms x batches)');

% Action histogram on acted-on cells
a = algo.action;
a = a(~isnan(a));
figure;
histogram(a, 1:(algo.K+1));
xlabel('Arm'); ylabel('Count');
title('Chosen arms on acted-on cells');

end
