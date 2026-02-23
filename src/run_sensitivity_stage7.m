function out = run_sensitivity_stage7(p0)
% run_sensitivity_stage7.m (v6.13)
% ---------------------------------------------------------
% Sensitivity exercise for Stage 7 (scenario E2).
%
% Goal: study when the contextual bandit policy improves over the best
% static arm by varying tuning knobs (exploration c and context bins).
%
% This version also records:
%   - the ex post best static arm k*
%   - share of selections on k*
%   - feedback sparsity: share(countSelKC < thr)
%
% Outputs (written to out/stage_7_sensitivity/):
%   - tab_stage7_sensitivity.tex
%   - fig_stage7_sensitivity_gap.png
%
% Usage:
%   out = run_sensitivity_stage7();
%   out = run_sensitivity_stage7(p0);  % optional overrides
% ---------------------------------------------------------

setup_paths();

% ---------------- default overrides ----------------
if nargin < 1 || isempty(p0)
    p0 = struct();
end

% Reasonable demo+ defaults (only set if missing)
if ~isfield(p0,'N'), p0.N = 40; end
if ~isfield(p0,'T'), p0.T = 100; end
if ~isfield(p0,'B'), p0.B = 12; end
if ~isfield(p0,'R'), p0.R = 50; end
if ~isfield(p0,'verbose'), p0.verbose = false; end

thr = 5; % sparsity threshold

% ---------------- grid knobs ----------------
ucbC  = [0.10 0.25 0.50 1.00 2.00];
binsL = [4 6 8];
binsT = [4 6 8];

% ---------------- output folder ----------------
root = fileparts(fileparts(mfilename('fullpath')));
outdir = fullfile(root,'out','stage_7_sensitivity');
if ~isfolder(outdir), mkdir(outdir); end

% Storage: [c, binsL, binsT, k*, policy, best, gap, share(k*), sparsity]
rows = cell(numel(ucbC)*numel(binsL)*numel(binsT), 9);
ii = 0;

fprintf('\n[Stage 7 sensitivity] Running grid (%d configs)...\n', numel(ucbC)*numel(binsL)*numel(binsT));

for c = ucbC
    for bl = binsL
        for bt = binsT
            p = p0;
            p.ucb_c = c;
            p.n_bins_lambda = bl;
            p.n_bins_time   = bt;

            res = run_stage(7, p);

            arm  = res.res.summary.arm_mse_mean;
            pol  = res.res.summary.policy_mse_mean;
            [best, kBest] = min(arm);
            gap  = pol - best;

            sh = mean_share_best_arm(res, kBest);
            sp = mean_sparsity(res, thr);

            ii = ii + 1;
            rows(ii,:) = {c, bl, bt, kBest, pol, best, gap, sh, sp};

            fprintf('  c=%.2f bins=(%d,%d): k*=%d policy=%.3f best=%.3f gap=%.3f | share=%.3f sparsity=%.3f\n', ...
                c, bl, bt, kBest, pol, best, gap, sh, sp);
        end
    end
end
rows = rows(1:ii,:);

% ---------------- write LaTeX table ----------------
texfile = fullfile(outdir,'tab_stage7_sensitivity.tex');
write_tex_table(rows, texfile, thr);

% ---------------- plot gap ----------------
% Each marker is one (binsL,binsT) configuration.
gapv = cell2mat(rows(:,7));
cv   = cell2mat(rows(:,1));

figure('Name','Stage 7 sensitivity: gap');
plot(cv, gapv, 'o');
grid on;
xlabel('UCB exploration constant c');
ylabel('Gap = policy MSE - best static MSE');
title('Stage 7 sensitivity (each marker = one bins configuration)');

figfile = fullfile(outdir,'fig_stage7_sensitivity_gap.png');
saveas(gcf, figfile);

% Return struct
out = struct();
out.rows    = rows;
out.texfile = texfile;
out.figfile = figfile;
out.outdir  = outdir;

fprintf('\n[OK] Wrote:\n  %s\n  %s\n', texfile, figfile);
fprintf('[OK] Folder: %s\n\n', outdir);

end

% =========================================================
% Helpers
% =========================================================
function write_tex_table(rows, filename, thr)

fid = fopen(filename,'w');
assert(fid>0, 'Cannot open file for writing: %s', filename);

fprintf(fid,'\\begin{tabular}{ccccccccc}\\toprule\n');
fprintf(fid,'$c$ & bins($\\lambda$) & bins($t$) & $k^*$ & Policy & Best & Gap & Share($k^*$) & Sparsity$<%d$ \\\\ \\midrule\n', thr);

for i=1:size(rows,1)
    c  = rows{i,1};
    bl = rows{i,2};
    bt = rows{i,3};
    k  = rows{i,4};
    pm = rows{i,5};
    bm = rows{i,6};
    gp = rows{i,7};
    sh = rows{i,8};
    sp = rows{i,9};

    fprintf(fid,'%.2f & %d & %d & %d & %.3f & %.3f & %.3f & %.3f & %.3f \\\\
', c, bl, bt, k, pm, bm, gp, sh, sp);
end

fprintf(fid,'\\bottomrule\\end{tabular}\n');

fclose(fid);
end

function sh = mean_share_best_arm(res, kBest)
% Mean share of actions on the best static arm across replications.
R = numel(res.res.rep);
shv = nan(R,1);
for r=1:R
    algo = res.res.rep{r}.algo;
    a = flatten_actions(algo.action);
    a = a(~isnan(a));
    if isempty(a)
        shv(r) = NaN;
    else
        shv(r) = mean(a==kBest);
    end
end
sh = mean(shv, 'omitnan');
end

function sp = mean_sparsity(res, thr)
% Mean share of (arm,context) cells with countSelKC < thr across replications.
R = numel(res.res.rep);
spv = nan(R,1);
for r=1:R
    algo = res.res.rep{r}.algo;
    C = algo.countSelKC;
    spv(r) = mean(C(:) < thr);
end
sp = mean(spv, 'omitnan');
end

function flat = flatten_actions(a)
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
