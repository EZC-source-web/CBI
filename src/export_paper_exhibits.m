function export_paper_exhibits(results, exh_dir, cfg)
% export_paper_exhibits.m
% ---------------------------------------------------------
% Paper-grade exhibit export (few but dense).
% Writes tables/figures to a SINGLE folder (always overwritten):
%   out/exhibits/
%
% Expected call (from run_paper_mc):
%   export_paper_exhibits(results, out/exhibits, cfg)
% ---------------------------------------------------------

if nargin < 3
    error('export_paper_exhibits: expected (results, exh_dir, cfg).');
end

bs = char(92);
nl = sprintf('\n');

ensure_dir(exh_dir);
wipe_dir_except_gitkeep(exh_dir);

% ---------------------------------------------------------
% 0) Write a compact manifest (in exhibits/)
% ---------------------------------------------------------
manifest = fullfile(exh_dir,'run_manifest.txt');
fid = fopen(manifest,'w');
assert(fid>0,'Cannot open manifest: %s', manifest);

fprintf(fid,'CBI paper-grade Monte Carlo: run manifest\n');
if isfield(results,'run_stamp')
    fprintf(fid,'Generated: %s\n', results.run_stamp);
else
    fprintf(fid,'Generated: %s\n', datestr(now));
end
fprintf(fid,'\n');

% Core design
fprintf(fid,'N=%d\n', cfg.N);
fprintf(fid,'T_grid=%s\n', mat2str(cfg.T_grid));
fprintf(fid,'R=%d\n', cfg.R);
fprintf(fid,'Batch length L=%d (constant)\n', cfg.batch_len_L);
fprintf(fid,'Reveal delay Delta=%d (in batches)\n', cfg.Delta);
fprintf(fid,'Reveal prob rho=%.3f\n', cfg.rho_reveal);
fprintf(fid,'Holdout rate=%.3f\n', cfg.holdout_rate);
fprintf(fid,'Target obs rate=%.3f\n', cfg.target_obs_rate);
fprintf(fid,'Context bins (lambda,time)=(%d,%d)\n', cfg.n_bins_lambda, cfg.n_bins_time);
fprintf(fid,'UCB exploration constant c=%.3g\n', cfg.ucb_c);
fprintf(fid,'Sparsity threshold (<thr)=%d\n', cfg.sparsity_thr);

if isfield(cfg,'nuisance_mode')
    fprintf(fid,'Nuisance mode=%s\n', cfg.nuisance_mode);
end
if isfield(cfg,'nuisance_update')
    fprintf(fid,'Nuisance update=%s\n', cfg.nuisance_update);
end

fclose(fid);

% ---------------------------------------------------------
% 1) Main scaling table + figure
% ---------------------------------------------------------
if isfield(results,'scaling') && isfield(results.scaling,'rows') && ~isempty(results.scaling.rows)
    tab_scaling = fullfile(exh_dir,'tab_paper_scaling.tex');
    write_tab_scaling(tab_scaling, results.scaling.rows, cfg, bs, nl);

    fig_png = fullfile(exh_dir,'fig_paper_scaling.png');
    fig_pdf = fullfile(exh_dir,'fig_paper_scaling.pdf');
    try
        make_scaling_figure(results.scaling.rows, cfg, fig_png, fig_pdf);
    catch ME
		% Be verbose on purpose: figure creation failures are often version-dependent.
		% Save an error report to out/exhibits for easier debugging.
		if exist('getReport','file')
			rep = getReport(ME,'extended','hyperlinks','off');
			warning('Could not create scaling figure.\n%s', rep);
		else
			warning('Could not create scaling figure: %s', ME.message);
			rep = ME.message;
		end
		try
			fid = fopen(fullfile(exh_dir,'fig_paper_scaling_error.txt'),'w');
			if fid>0
				fprintf(fid,'%s\n', rep);
				fclose(fid);
			end
		catch
			% ignore
		end
    end
end

% ---------------------------------------------------------
% 2) Optional: stage ladder table
% ---------------------------------------------------------
if isfield(results,'ladder') && isfield(results.ladder,'rows') && ~isempty(results.ladder.rows)
    tab_ladder = fullfile(exh_dir,'tab_paper_stage_ladder.tex');
    write_tab_stage_ladder(tab_ladder, results.ladder.rows, cfg, bs, nl);
end

% ---------------------------------------------------------
% 3) Optional: calibration table
% ---------------------------------------------------------
if isfield(results,'calibration') && isfield(results.calibration,'rows') && ~isempty(results.calibration.rows)
    tab_calib = fullfile(exh_dir,'tab_paper_calibration.tex');
    write_tab_calibration(tab_calib, results.calibration.rows, cfg, bs, nl);
end

end

% =========================================================
% Local helpers
% =========================================================
function ensure_dir(p)
if ~exist(p,'dir'); mkdir(p); end
end

function wipe_dir_except_gitkeep(d)
if ~exist(d,'dir'); return; end
files = dir(d);
for i=1:numel(files)
    nm = files(i).name;
    if strcmp(nm,'.') || strcmp(nm,'..'); continue; end
    if files(i).isdir
        rmdir(fullfile(d,nm), 's');
    else
        if strcmp(nm,'.gitkeep'); continue; end
        delete(fullfile(d,nm));
    end
end
end

function s = fmt_mean_se(mu, se)
% Format as "0.123 (0.004)" (MCSE in parentheses)
if isnan(mu)
    s = 'NA';
    return;
end
if isnan(se)
    s = sprintf('%.3f', mu);
else
    s = sprintf('%.3f (%.3f)', mu, se);
end
end

function s = to_char(x)
% Robust conversion to character vector (supports string/cell).
if ischar(x)
    s = x;
elseif isstring(x)
    s = char(x);
elseif iscell(x) && ~isempty(x)
    s = to_char(x{1});
else
    s = char(string(x));
end
end

function lab = pretty_scenario(st, sc)
% Presentation label for scenarios (avoid "Stage" wording in exhibits).
sc = to_char(sc);
if strcmp(sc,'E')
    lab = 'Scenario E';
elseif strcmp(sc,'E2')
    lab = 'Scenario E2';
else
    if isempty(sc)
        lab = sprintf('Scenario %d', st);
    else
        lab = sprintf('Scenario %s', sc);
    end
end
end
function write_tab_scaling(filename, rows, cfg, bs, nl)
% rows columns (see run_paper_mc.m):
%  1 st, 2 scenario, 3 T, 4 B, 5 binsL, 6 binsT, 7 c, 8 k*,
%  9 best_mu,10 best_se, 11 pol_mu,12 pol_se, 13 gap_mu,14 gap_se,
%  15 win_mu,16 win_se,
%  17 orc_mu,18 orc_se, 19 gapc_mu,20 gapc_se, 21 share_mu,22 share_se,
%  23 spars_mu,24 spars_se, 25 ctxgain_mu,26 ctxgain_se

fid = fopen(filename,'w');
assert(fid>0,'Cannot open %s', filename);

rowbr = [bs bs]; % LaTeX row break token: '\\'

% Sort rows by (stage, T) to keep the exhibit visually stable.
st = cell2mat(rows(:,1));
T  = cell2mat(rows(:,3));
[~,ord] = sortrows([st T],[1 2]);
rows = rows(ord,:);

fprintf(fid,'%s', [bs 'begin{tabular}{lrrllllllll}' nl]);
fprintf(fid,'%s', [bs 'toprule' nl]);

header = 'Scen. & $T$ & $B$ & Best & Policy & Gap & Win & Oracle & CtxGain & Regret & Spars$<' ;
header = [header num2str(cfg.sparsity_thr) '$'];
fprintf(fid,'%s', [header ' ' rowbr nl]);
fprintf(fid,'%s', [bs 'midrule' nl]);

last_stage = NaN;
for i=1:size(rows,1)
    st    = rows{i,1};
    sc    = rows{i,2};
    T     = rows{i,3};
    B     = rows{i,4};

    if isnan(last_stage) || st~=last_stage
        % Stage group label row
        lab = pretty_scenario(st, sc);
        fprintf(fid,'%s', [bs 'multicolumn{11}{l}{' bs 'textit{' lab '}} ' rowbr nl]);
        fprintf(fid,'%s', [bs 'midrule' nl]);
        last_stage = st;
    end

    best  = fmt_mean_se(rows{i,9},  rows{i,10});
    pol   = fmt_mean_se(rows{i,11}, rows{i,12});
    gap   = fmt_mean_se(rows{i,13}, rows{i,14});
    win   = fmt_mean_se(rows{i,15}, rows{i,16});
    orc   = fmt_mean_se(rows{i,17}, rows{i,18});
    ctxg  = fmt_mean_se(rows{i,25}, rows{i,26});
    gapc  = fmt_mean_se(rows{i,19}, rows{i,20});
    spar  = fmt_mean_se(rows{i,23}, rows{i,24});

    stage_label = to_char(sc);
    fprintf(fid,'%s & %d & %d & %s & %s & %s & %s & %s & %s & %s & %s', ...
        stage_label, T, B, best, pol, gap, win, orc, ctxg, gapc, spar);
    fprintf(fid,'%s', [' ' rowbr nl]);
end

fprintf(fid,'%s', [bs 'bottomrule' nl]);
fprintf(fid,'%s', [bs 'end{tabular}' nl]);
fclose(fid);
end

function write_tab_stage_ladder(filename, rows, cfg, bs, nl)
% rows: nStage x 21 cell array (see run_paper_mc.m)
fid = fopen(filename,'w');
assert(fid>0,'Cannot open %s', filename);

rowbr = [bs bs];

fprintf(fid,'%s', [bs 'begin{tabular}{lrrllllll}' nl]);
fprintf(fid,'%s', [bs 'toprule' nl]);

header = 'Scenario & $T$ & $B$ & Best(static) & Policy & Gap & WinRate & Oracle(ctx) & Sparsity$<' ;
header = [header num2str(cfg.sparsity_thr) '$'];
fprintf(fid,'%s', [header ' ' rowbr nl]);
fprintf(fid,'%s', [bs 'midrule' nl]);

for i=1:size(rows,1)
    st = rows{i,1};
    if isempty(st); continue; end
    sc = rows{i,2};
    T  = rows{i,3};
    B  = rows{i,4};

    best = fmt_mean_se(rows{i,6}, rows{i,7});
    pol  = fmt_mean_se(rows{i,8}, rows{i,9});
    gap  = fmt_mean_se(rows{i,10}, rows{i,11});
    win  = fmt_mean_se(rows{i,12}, rows{i,13});
    orc  = fmt_mean_se(rows{i,14}, rows{i,15});
    spar = fmt_mean_se(rows{i,20}, rows{i,21});

    stage_label = to_char(sc);

    fprintf(fid,'%s & %d & %d & %s & %s & %s & %s & %s & %s', ...
        stage_label, T, B, best, pol, gap, win, orc, spar);
    fprintf(fid,'%s', [' ' rowbr nl]);
end

fprintf(fid,'%s', [bs 'bottomrule' nl]);
fprintf(fid,'%s', [bs 'end{tabular}' nl]);
fclose(fid);
end

function write_tab_calibration(filename, rows, cfg, bs, nl)
% rows columns (see run_paper_mc.m calibration):
% 1 c,2 binsL,3 binsT,4 k*, 5 best_mu,6 best_se, 7 pol_mu,8 pol_se,
% 9 gap_mu,10 gap_se, 11 win_mu,12 win_se,
% 13 share_mu,14 share_se, 15 spars_mu,16 spars_se,
% 17 orc_mu,18 orc_se, 19 gapc_mu,20 gapc_se

fid = fopen(filename,'w');
assert(fid>0,'Cannot open %s', filename);

rowbr = [bs bs];

fprintf(fid,'%s', [bs 'begin{tabular}{rrrllllll}' nl]);
fprintf(fid,'%s', [bs 'toprule' nl]);

% Build header as a single string (avoid unmatched delimiters across lines)
header = ['$c$ & bins($' bs 'lambda$) & bins($t$) & Best & Policy & Gap & Win & Oracle & Spars$<' num2str(cfg.sparsity_thr) '$'];
fprintf(fid,'%s', [header ' ' rowbr nl]);
fprintf(fid,'%s', [bs 'midrule' nl]);

for i=1:size(rows,1)
    c    = rows{i,1};
    bl   = rows{i,2};
    bt   = rows{i,3};
    best = fmt_mean_se(rows{i,5}, rows{i,6});
    pol  = fmt_mean_se(rows{i,7}, rows{i,8});
    gap  = fmt_mean_se(rows{i,9}, rows{i,10});
    win  = fmt_mean_se(rows{i,11}, rows{i,12});
    orc  = fmt_mean_se(rows{i,17}, rows{i,18});
    spar = fmt_mean_se(rows{i,15}, rows{i,16});

    fprintf(fid,'%.2f & %d & %d & %s & %s & %s & %s & %s & %s', c, bl, bt, best, pol, gap, win, orc, spar);
    fprintf(fid,'%s', [' ' rowbr nl]);
end

fprintf(fid,'%s', [bs 'bottomrule' nl]);
fprintf(fid,'%s', [bs 'end{tabular}' nl]);
fclose(fid);
end


function make_scaling_figure(rows, cfg, png_file, pdf_file)
% 2x2 small-multiple figure (paper-standard):
%   Rows: scenarios (E vs E2)
%   Col 1: Oracle regret = Policy - Oracle(ctx) with +/- 2 MCSE
%   Col 2: Win rate = P(Policy beats Best(static)) = P(Gap<0) with +/- 2 MCSE
%
% Rationale:
% - Avoids "step/ladder" framing (we present scenarios as experimental regimes).
% - Avoids scale domination when one scenario is much harsher than the other.

scs = unique(rows(:,2),'stable'); % cell array of scenario tags
% Preferred order (if present)
pref = {'E','E2'};
scs_ord = {};
for i=1:numel(pref)
    if any(strcmp(scs,pref{i}))
        scs_ord{end+1} = pref{i};
    end
end
for i=1:numel(scs)
    if ~any(strcmp(scs_ord,scs{i}))
        scs_ord{end+1} = scs{i};
    end
end
scs = scs_ord;

nR = numel(scs);
if nR > 2
    % keep figure compact in the main paper; extra scenarios should go to the appendix
    nR = 2;
    scs = scs(1:2);
end

fig = figure('Visible','off','Color','w');
set(fig,'Position',[80 80 1200 700]);

tl = tiledlayout(nR,2,'Padding','compact','TileSpacing','compact');

% Keep the figure text minimal; details (MCSE etc.) go in the caption.
try
    title(tl,'Performance vs T');
catch
end
for r=1:nR
    sc = scs{r};
    sel = strcmp(rows(:,2), sc);

    % Sort by T
    T = cell2mat(rows(sel,3));
    [T,ii] = sort(T);

    % --- Col 1: Oracle regret (Policy - Oracle)
    regret_mu = cell2mat(rows(sel,19));
    regret_se = cell2mat(rows(sel,20));
    regret_mu = regret_mu(ii);
    regret_se = regret_se(ii);

    ax = nexttile;
    hold(ax,'on');
    errorbar(ax, T, regret_mu, 2*regret_se, '-o', 'LineWidth',1.1, 'MarkerSize',6);
    yline(ax,0);
    grid(ax,'on');
    set(ax,'FontSize',12,'LineWidth',1);
    ylabel(ax,'Regret');
    title(ax, sprintf('%s: Regret', to_char(sc)), 'Interpreter','none');
    if r==nR
        xlabel(ax,'T');
    end

    % --- Col 2: Win rate (Policy beats Best)
    win_mu = cell2mat(rows(sel,15));
    win_se = cell2mat(rows(sel,16));
    win_mu = win_mu(ii);
    win_se = win_se(ii);

    ax = nexttile;
    hold(ax,'on');
    errorbar(ax, T, win_mu, 2*win_se, '-o', 'LineWidth',1.1, 'MarkerSize',6);
    yline(ax,0.5,':');
    ylim(ax,[0 1]);
    grid(ax,'on');
    set(ax,'FontSize',12,'LineWidth',1);
    ylabel(ax,'Win rate');
    title(ax, sprintf('%s: Win', to_char(sc)), 'Interpreter','none');
    if r==nR
        xlabel(ax,'T');
    end

end % for r

% Paper setup (avoid PDF cut-off)
try
    set(fig,'PaperPositionMode','auto');
    set(fig,'PaperOrientation','landscape');
    set(fig,'PaperUnits','inches');
    paperW = 11.69; paperH = 8.27; % A4 landscape
    set(fig,'PaperSize',[paperW paperH]);
    margin = 0.35;
    set(fig,'PaperPosition',[margin margin paperW-2*margin paperH-2*margin]);
catch
end

% Export
if exist('exportgraphics','file') == 2
    try
        exportgraphics(fig, png_file, 'Resolution', 350);
    catch
        print(fig, png_file, '-dpng', '-r350');
    end
    try
        exportgraphics(fig, pdf_file, 'ContentType','vector');
    catch
        print(fig, pdf_file, '-dpdf', '-bestfit');
    end
else
    print(fig, png_file, '-dpng', '-r350');
    print(fig, pdf_file, '-dpdf', '-bestfit');
end

close(fig);
end
