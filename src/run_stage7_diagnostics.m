function out = run_stage7_diagnostics(p0)
% run_stage7_diagnostics.m (v6.13)
% ---------------------------------------------------------
% Stage 7 diagnostics bundle (scenario E2).
%
% This script automates the key tests used to diagnose why the Stage-7
% policy may fail to beat the best static arm in short samples.
%
% Tests (mirroring the chat):
%   (D1) Context discretization vs. exploration (2x2 grid)
%        - bins=(4,4) vs (8,8)
%        - c=0.1 vs 5.0
%   (D2) Batch-frequency ladder (B = 12,24,36,48) at bins=(4,4), c=0.1
%
% Outputs written to: out/stage_7_diagnostics/
%   - tab_stage7_diag_bins_c.tex
%   - tab_stage7_diag_B_ladder.tex
%   - fig_stage7_diag_gap_bins_c.png
%   - fig_stage7_diag_gap_vs_B.png
%   - fig_stage7_diag_share_vs_B.png
%   - fig_stage7_diag_sparsity_vs_B.png
%
% Usage:
%   out = run_stage7_diagnostics();
%   out = run_stage7_diagnostics(struct('R',50,'T',200,'N',80,'verbose',true));
%
% Notes:
%   - This is a DIAGNOSTIC bundle (demo-friendly). For paper-grade results,
%     increase R and T, and consider varying T (panel length) rather than B.
% ---------------------------------------------------------

setup_paths();

if nargin < 1 || isempty(p0)
    p0 = struct();
end

% Demo defaults (only if missing)
if ~isfield(p0,'N'), p0.N = 40; end
if ~isfield(p0,'T'), p0.T = 100; end
if ~isfield(p0,'B'), p0.B = 12; end
if ~isfield(p0,'R'), p0.R = 20; end
if ~isfield(p0,'verbose'), p0.verbose = false; end

thr = 5; % threshold used in "sparsity<5" diagnostics

root = fileparts(fileparts(mfilename('fullpath')));
outdir = fullfile(root,'out','stage_7_diagnostics');
if ~isfolder(outdir), mkdir(outdir); end

% =========================================================
% (D1) 2x2 grid: bins x c
% =========================================================

cases = struct();
cases(1).c  = 0.10; cases(1).bl = 4; cases(1).bt = 4; cases(1).label = 'c=0.1, bins=(4,4)';
cases(2).c  = 5.00; cases(2).bl = 4; cases(2).bt = 4; cases(2).label = 'c=5.0, bins=(4,4)';
cases(3).c  = 0.10; cases(3).bl = 8; cases(3).bt = 8; cases(3).label = 'c=0.1, bins=(8,8)';
cases(4).c  = 5.00; cases(4).bl = 8; cases(4).bt = 8; cases(4).label = 'c=5.0, bins=(8,8)';

rows = cell(numel(cases), 9);
% columns: c, bl, bt, k*, bestMSE, policyMSE, gap, share(k*), sparsity

fprintf('\n[Stage 7 diagnostics] (D1) bins x c grid (%d configs)\n', numel(cases));
for j=1:numel(cases)
    p = p0;
    p.ucb_c = cases(j).c;
    p.n_bins_lambda = cases(j).bl;
    p.n_bins_time   = cases(j).bt;

    res = run_stage(7, p);

    arm  = res.res.summary.arm_mse_mean;
    pol  = res.res.summary.policy_mse_mean;
    [bestMSE, kBest] = min(arm);
    gap = pol - bestMSE;

    sh = mean_share_best_arm(res, kBest);
    sp = mean_sparsity(res, thr);

    rows(j,:) = {cases(j).c, cases(j).bl, cases(j).bt, kBest, bestMSE, pol, gap, sh, sp};

    fprintf('  %s: k*=%d best=%.3f policy=%.3f gap=%.3f | share(k*)=%.3f sparsity<%d=%.3f\n', ...
        cases(j).label, kBest, bestMSE, pol, gap, sh, thr, sp);
end

tex1 = fullfile(outdir,'tab_stage7_diag_bins_c.tex');
write_tex_table_bins_c(rows, tex1, thr);

% Plot gaps for the 4 configs (bars)
g = figure('Name','Stage 7 diagnostics: gap (bins x c)');
gapv = cell2mat(rows(:,7));
bar(gapv);
xticklabels({cases.label});
xtickangle(20);
ylabel('Gap = policy MSE - best static MSE');
title('Stage 7 diagnostics (bins x c): gap');
grid on;
fig1 = fullfile(outdir,'fig_stage7_diag_gap_bins_c.png');
saveas(g, fig1);
close(g);

% =========================================================
% (D2) B ladder at bins=(4,4), c=0.1
% =========================================================

Bs = [12 24 36 48];
rowsB = cell(numel(Bs), 8);
% columns: B, k*, bestMSE, policyMSE, gap, share(k*), sparsity, R

fprintf('\n[Stage 7 diagnostics] (D2) B ladder at bins=(4,4), c=0.1\n');
for j=1:numel(Bs)
    p = p0;
    p.B = Bs(j);
    p.ucb_c = 0.10;
    p.n_bins_lambda = 4;
    p.n_bins_time   = 4;

    res = run_stage(7, p);

    arm  = res.res.summary.arm_mse_mean;
    pol  = res.res.summary.policy_mse_mean;
    [bestMSE, kBest] = min(arm);
    gap = pol - bestMSE;

    sh = mean_share_best_arm(res, kBest);
    sp = mean_sparsity(res, thr);

    rowsB(j,:) = {Bs(j), kBest, bestMSE, pol, gap, sh, sp, p.R};

    fprintf('  B=%d: k*=%d best=%.3f policy=%.3f gap=%.3f | share(k*)=%.3f sparsity<%d=%.3f\n', ...
        Bs(j), kBest, bestMSE, pol, gap, sh, thr, sp);
end

tex2 = fullfile(outdir,'tab_stage7_diag_B_ladder.tex');
write_tex_table_B_ladder(rowsB, tex2, thr);

% Figures for B ladder
Bv = cell2mat(rowsB(:,1));
gapv = cell2mat(rowsB(:,5));
shv  = cell2mat(rowsB(:,6));
spv  = cell2mat(rowsB(:,7));

h = figure('Name','Stage 7 diagnostics: gap vs B');
plot(Bv, gapv, '-o');
grid on;
xlabel('Number of batches B');
ylabel('Gap = policy MSE - best static MSE');
title('Stage 7 diagnostics: gap vs B (bins=(4,4), c=0.1)');
fig2 = fullfile(outdir,'fig_stage7_diag_gap_vs_B.png');
saveas(h, fig2);
close(h);

h = figure('Name','Stage 7 diagnostics: share(k*) vs B');
plot(Bv, shv, '-o');
grid on;
xlabel('Number of batches B');
ylabel('Mean share of best-static arm');
title('Stage 7 diagnostics: share(k^*) vs B (bins=(4,4), c=0.1)');
fig3 = fullfile(outdir,'fig_stage7_diag_share_vs_B.png');
saveas(h, fig3);
close(h);

h = figure('Name','Stage 7 diagnostics: sparsity vs B');
plot(Bv, spv, '-o');
grid on;
xlabel('Number of batches B');
ylabel(sprintf('Mean share with countSelKC<%d', thr));
title('Stage 7 diagnostics: feedback sparsity vs B (bins=(4,4), c=0.1)');
fig4 = fullfile(outdir,'fig_stage7_diag_sparsity_vs_B.png');
saveas(h, fig4);
close(h);

% Recommend baseline as argmin gap within tested Bs
[~, idxMin] = min(gapv);
B_star = Bv(idxMin);

fprintf('\n[Recommendation] Within this diagnostic grid, B*=%d minimizes the gap (demo).\n', B_star);
fid = fopen(fullfile(outdir,'stage7_diag_recommendation.txt'),'w');
fprintf(fid,'Stage 7 diagnostics recommendation (demo):\n');
fprintf(fid,'  - Use coarse bins (e.g., (4,4) rather than (8,8)) to avoid sparse feedback.\n');
fprintf(fid,'  - Within the tested B ladder, B*=%d minimizes the gap for bins=(4,4), c=0.1.\n', B_star);
fprintf(fid,'  - For paper-grade horizon experiments, vary T (panel length) rather than B.\n');
fclose(fid);

% Return bundle
out = struct();
out.outdir = outdir;
out.rows_bins_c = rows;
out.rows_B = rowsB;
out.tex_bins_c = tex1;
out.tex_B = tex2;
out.fig_gap_bins_c = fig1;
out.fig_gap_B = fig2;
out.fig_share_B = fig3;
out.fig_sparsity_B = fig4;
out.B_star = B_star;

fprintf('\n[OK] Stage 7 diagnostics written to: %s\n', outdir);

end

% =========================================================
% Helpers
% =========================================================

function sh = mean_share_best_arm(stageOut, kBest)
% Mean selection share of the best-static arm across reps.
R = numel(stageOut.res.rep);
vals = NaN(R,1);
for r=1:R
    algo = stageOut.res.rep{r}.algo;
    flat = flatten_actions(algo.action);
    flat = flat(~isnan(flat) & flat>0);
    if ~isempty(flat)
        vals(r) = mean(flat==kBest);
    end
end
sh = mean(vals,'omitnan');
end

function sp = mean_sparsity(stageOut, thr)
% Mean fraction of (arm x context-bin) cells with countSelKC < thr.
R = numel(stageOut.res.rep);
vals = NaN(R,1);
for r=1:R
    algo = stageOut.res.rep{r}.algo;
    if isfield(algo,'countSelKC')
        C = algo.countSelKC;
        vals(r) = mean(C(:) < thr);
    end
end
sp = mean(vals,'omitnan');
end

function flat = flatten_actions(a)
% Robustly flatten stored actions to a vector.
flat = [];
if iscell(a)
    for ii=1:numel(a)
        tmp = a{ii};
        if iscell(tmp)
            tmp = cell2mat(tmp);
        end
        flat = [flat; tmp(:)]; %#ok<AGROW>
    end
else
    flat = a(:);
end
end

function write_tex_table_bins_c(rows, filename, thr)
% LaTeX table for (D1) bins x c diagnostics.

fid = fopen(filename,'w');
assert(fid>0, 'Cannot open file: %s', filename);

fprintf(fid,'\\begin{tabular}{cccccccc}\\toprule\n');
fprintf(fid,'$c$ & bins($\\lambda$) & bins($t$) & $k^*$ & Best & Policy & Gap & Share($k^*$)/Sparsity$<%d$ \\\\ \\midrule\n', thr);

nl = sprintf('\n');
fmtRow = ['%.2f & %d & %d & %d & %.3f & %.3f & %.3f & %.3f / %.3f \\\\' nl];

for i = 1:size(rows,1)
    c    = rows{i,1};
    bl   = rows{i,2};
    bt   = rows{i,3};
    k    = rows{i,4};
    best = rows{i,5};
    pol  = rows{i,6};
    gap  = rows{i,7};
    sh   = rows{i,8};
    sp   = rows{i,9};

    fprintf(fid, fmtRow, c, bl, bt, k, best, pol, gap, sh, sp);
end

fprintf(fid,'\\bottomrule\\end{tabular}\n');
fclose(fid);
end


function write_tex_table_B_ladder(rows, filename, thr)
% LaTeX table for (D2) B ladder diagnostics.
fid = fopen(filename,'w');
assert(fid>0, 'Cannot open file: %s', filename);

fprintf(fid,'\\begin{tabular}{ccccccc}\\toprule\n');
fprintf(fid,'$B$ & $k^*$ & Best & Policy & Gap & Share($k^*$) & Sparsity$<%d$ \\\\ \\midrule\n', thr);

nl = sprintf('\n');
fmtRow = ['%d & %d & %.3f & %.3f & %.3f & %.3f & %.3f \\\\' nl];

for i = 1:size(rows,1)
    B    = rows{i,1};
    k    = rows{i,2};
    best = rows{i,3};
    pol  = rows{i,4};
    gap  = rows{i,5};
    sh   = rows{i,6};
    sp   = rows{i,7};

    fprintf(fid, fmtRow, B, k, best, pol, gap, sh, sp);
end

fprintf(fid,'\\bottomrule\\end{tabular}\n');
fclose(fid);
end