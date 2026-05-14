function files = make_figure_section2_taxonomy(output_dir, formats)
%MAKE_FIGURE_SECTION2_TAXONOMY Generate four Section 2 taxonomy panels.
%
% Default output:
%   Figures/Figure_Section2_Taxonomy_A.pdf
%   Figures/Figure_Section2_Taxonomy_B.pdf
%   Figures/Figure_Section2_Taxonomy_C.pdf
%   Figures/Figure_Section2_Taxonomy_D.pdf
%   Figures/Figure_Section2_Taxonomy_Combined.pdf
%
% Each panel is generated from a stylized observation/availability matrix.
% Rows are calendar dates, columns are panel units or panel objects. Dark
% cells are available at the relevant date; light cells are unavailable.
% The visual grammar follows observation-pattern figures in the incomplete
% panel literature, while the annotations identify the econometric decision
% object and its validation signal.

if nargin < 1 || isempty(output_dir)
    root_dir = fileparts(fileparts(mfilename('fullpath')));
    output_dir = fullfile(root_dir, 'Figures');
end

% Backward-compatible convenience: if a filename is passed, use its folder.
[maybe_dir, ~, maybe_ext] = fileparts(output_dir);
if ~isempty(maybe_ext)
    output_dir = maybe_dir;
end

if nargin < 2 || isempty(formats)
    formats = {'pdf'};
elseif ischar(formats)
    formats = {formats};
end

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

rng(7);
colors = section2_colors();
patterns = make_patterns();

panels = { ...
    struct('id', 'A', 'title', 'A. Delayed release and ragged edge', ...
        'short_title', 'A. Delayed release', ...
        'draw', @(ax) draw_panel_a(ax, patterns.A, colors)), ...
    struct('id', 'B', 'title', 'B. Mixed-frequency non-availability', ...
        'short_title', 'B. Mixed frequency', ...
        'draw', @(ax) draw_panel_b(ax, patterns.B, colors)), ...
    struct('id', 'C', 'title', 'C. Evaluable missingness', ...
        'short_title', 'C. Evaluable missingness', ...
        'draw', @(ax) draw_panel_c(ax, patterns.C, colors)), ...
    struct('id', 'D', 'title', 'D. Completed-panel object and task loss', ...
        'short_title', 'D. Completed-panel object', ...
        'draw', @(ax) draw_panel_d(ax, patterns.D, colors)) ...
    };

files = {};
for i = 1:numel(panels)
    for f = 1:numel(formats)
        fmt = lower(strrep(formats{f}, '.', ''));
        file_i = fullfile(output_dir, sprintf('Figure_Section2_Taxonomy_%s.%s', panels{i}.id, fmt));
        export_one_panel(file_i, panels{i}.title, panels{i}.draw);
        files{end + 1} = file_i; %#ok<AGROW>
    end
end

for f = 1:numel(formats)
    fmt = lower(strrep(formats{f}, '.', ''));
    file_i = fullfile(output_dir, sprintf('Figure_Section2_Taxonomy_Combined.%s', fmt));
    export_combined_figure(file_i, panels);
    files{end + 1} = file_i; %#ok<AGROW>
end

for i = 1:numel(files)
    fprintf('Wrote %s\n', files{i});
end
end

function colors = section2_colors()
colors.observed = [0.13 0.30 0.33];
colors.missing = [0.94 0.91 0.84];
colors.completed = [0.61 0.68 0.61];
colors.ink = [0.10 0.10 0.10];
colors.validation = [0.86 0.46 0.12];
colors.accent = [0.10 0.39 0.57];
colors.feedback = [0.66 0.18 0.16];
colors.arrow = [0.07 0.28 0.40];
colors.white = [1 1 1];
end

function patterns = make_patterns()
T = 36;
N = 46;

% A. Delayed releases: temporary non-availability near the current vintage.
tau = 30;
lags = randi([0 8], 1, N);
[lags, ord] = sort(lags, 'ascend'); %#ok<ASGLU>
WA = zeros(T, N);
for j = 1:N
    last_observed_t = tau - lags(j);
    WA(1:max(last_observed_t, 0), j) = 1;
end
hist_gap = rand(T, N) < 0.012;
WA(hist_gap & WA == 1) = 0;
patterns.A.W = WA(:, ord);
patterns.A.tau = tau;
patterns.A.example_cell = [tau + 1, round(0.72 * N)];

% B. Mixed-frequency non-availability: high-frequency operating grid with
% lower-frequency target releases.
TB = 18;
NB = 34;
WB = zeros(TB, NB);
release_rows = 3:3:TB;
WB(release_rows, :) = 1;
early_release_units = randperm(NB, round(0.16 * NB));
WB(release_rows - 1, early_release_units) = 1;
patterns.B.W = WB;
patterns.B.release_rows = release_rows;

% C. Structural target non-observation plus a separate validation stream.
split = 23;
WC = ones(T, N);
WC(22:T, 4:12) = 0;
WC(8:24, 15:22) = 0;
WC(27:T, 1:4) = 0;
WC(:, split + 1:end) = double(rand(T, N - split) > 0.28);
VC = false(T, N);
VC(5:4:35, split + 3:5:N - 2) = true;
VC = VC & WC == 1;
patterns.C.W = WC;
patterns.C.V = VC;
patterns.C.split = split;

% D. Completed-vintage object: frontier cells are unavailable at the
% decision date, then filled by a selected completion procedure.
WD = ones(T, N);
for j = 1:N
    frontier = T - 7 + ceil(5 * j / N);
    WD(frontier:T, j) = 0;
end
WD(rand(T, N) < 0.010) = 0;
CD = WD;
CD(WD == 0) = 2;
patterns.D.W = WD;
patterns.D.completed = CD;
end

function export_one_panel(filename, panel_title, draw_fun)
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', ...
    'Position', [80 80 880 560]);
ax = axes(fig, 'Position', [0 0 1 1]);
setup_axis(ax);
preserve_canvas_margins(ax);

text(ax, 0.5, 0.965, panel_title, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 15, 'FontWeight', 'bold', ...
    'Color', [0.08 0.08 0.08], 'Interpreter', 'none');
draw_fun(ax);

set(findall(fig, '-property', 'FontName'), 'FontName', 'Helvetica');
set(fig, 'PaperPositionMode', 'auto');
set(fig, 'PaperUnits', 'inches');
set(fig, 'PaperSize', [6.2 3.8]);
set(fig, 'PaperPosition', [0 0 6.2 3.8]);

[~, ~, ext] = fileparts(filename);
if exist('exportgraphics', 'file') > 0
    if strcmpi(ext, '.png')
        exportgraphics(fig, filename, 'Resolution', 350, 'BackgroundColor', 'white');
    else
        exportgraphics(fig, filename, 'ContentType', 'vector', 'BackgroundColor', 'white');
    end
else
    if strcmpi(ext, '.png')
        print(fig, filename, '-dpng', '-r350');
    else
        print(fig, filename, '-dpdf', '-painters');
    end
end
close(fig);
end

function export_combined_figure(filename, panels)
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', ...
    'Position', [80 80 1380 900]);

frame_ax = axes(fig, 'Position', [0 0 1 1]); %#ok<LAXES>
setup_axis(frame_ax);
preserve_canvas_margins(frame_ax);

positions = [ ...
    0.025 0.505 0.465 0.470; ...
    0.510 0.505 0.465 0.470; ...
    0.025 0.020 0.465 0.470; ...
    0.510 0.020 0.465 0.470 ...
    ];

for i = 1:numel(panels)
    ax = axes(fig, 'Position', positions(i, :)); %#ok<LAXES>
    setup_axis(ax);
    text(ax, 0.5, 0.975, panels{i}.short_title, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
        'FontSize', 12.0, 'FontWeight', 'bold', ...
        'Color', [0.08 0.08 0.08], 'Interpreter', 'none');
    panels{i}.draw(ax);
    crop_combined_panel(ax, panels{i}.id);
end

set(findall(fig, '-property', 'FontName'), 'FontName', 'Helvetica');
set(fig, 'PaperPositionMode', 'auto');
set(fig, 'PaperUnits', 'inches');
set(fig, 'PaperSize', [7.2 4.7]);
set(fig, 'PaperPosition', [0 0 7.2 4.7]);

[~, ~, ext] = fileparts(filename);
if exist('exportgraphics', 'file') > 0
    if strcmpi(ext, '.png')
        exportgraphics(fig, filename, 'Resolution', 350, 'BackgroundColor', 'white');
    else
        exportgraphics(fig, filename, 'ContentType', 'vector', 'BackgroundColor', 'white');
    end
else
    if strcmpi(ext, '.png')
        print(fig, filename, '-dpng', '-r350');
    else
        print(fig, filename, '-dpdf', '-painters');
    end
end
close(fig);
end

function crop_combined_panel(ax, panel_id)
switch panel_id
    case 'A'
        axis(ax, [0.030 0.980 0.105 1.000]);
    case 'B'
        axis(ax, [0.070 0.980 0.100 1.000]);
    case 'C'
        axis(ax, [0.040 0.920 0.090 1.000]);
    case 'D'
        axis(ax, [0.045 0.955 0.125 1.000]);
end
axis(ax, 'off');
end

function setup_axis(ax)
cla(ax);
hold(ax, 'on');
axis(ax, [0 1 0 1]);
axis(ax, 'off');
set(ax, 'YDir', 'normal');
end

function preserve_canvas_margins(ax)
% White boundary objects keep exportgraphics from visually tightening the
% crop around the outermost text labels.
plot(ax, [0.020 0.985 0.985 0.020 0.020], ...
    [0.030 0.030 0.985 0.985 0.030], '-', ...
    'Color', [0.995 0.995 0.995], 'LineWidth', 0.1);
end

function draw_pattern(ax, W, box, colors)
x0 = box(1); y0 = box(2); w = box(3); h = box(4);
[T, N] = size(W);
cw = w / N;
ch = h / T;
for t = 1:T
    for j = 1:N
        v = W(t, j);
        if v == 1
            face = colors.observed;
        elseif v == 2
            face = colors.completed;
        else
            face = colors.missing;
        end
        rectangle(ax, 'Position', [x0 + (j - 1) * cw, y0 + (t - 1) * ch, cw, ch], ...
            'FaceColor', face, 'EdgeColor', 'none');
    end
end
rectangle(ax, 'Position', box, 'FaceColor', 'none', ...
    'EdgeColor', colors.ink, 'LineWidth', 0.8);
end

function draw_axes_labels(ax, box, xlab, show_time)
if nargin < 4
    show_time = true;
end
font_size = 9.5;
if iscell(xlab)
    font_size = 9.0;
end
text(ax, box(1) + box(3) / 2, axis_label_y(box), xlab, ...
    'FontSize', font_size, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'Interpreter', 'none');
if show_time
    text(ax, axis_label_x(box), box(2) + box(4) / 2, 'time', ...
        'FontSize', 9.5, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'Rotation', 90, 'Interpreter', 'none');
end
end

function y = axis_label_y(box)
y = box(2) - 0.035;
end

function x = axis_label_x(box)
x = max(0.060, box(1) - 0.015);
end

function xy = cell_center(W, box, t, j)
[T, N] = size(W);
xy = [box(1) + (j - 0.5) * box(3) / N, box(2) + (t - 0.5) * box(4) / T];
end

function draw_arrow(ax, p1, p2, colors, style, label, offset, arrow_color, line_width)
if nargin < 5 || isempty(style); style = '-'; end
if nargin < 6; label = ''; end
if nargin < 7 || isempty(offset); offset = [0 0]; end
if nargin < 8 || isempty(arrow_color); arrow_color = colors.arrow; end
if nargin < 9 || isempty(line_width); line_width = 1.2; end
plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], ...
    'Color', arrow_color, 'LineWidth', line_width, 'LineStyle', style);
v = p2 - p1;
nv = hypot(v(1), v(2));
if nv > 0
    u = v / nv;
    n = [-u(2) u(1)];
    head_len = 0.013;
    head_wid = 0.0065;
    base = p2 - head_len * u;
    head_x = [p2(1), base(1) + head_wid * n(1), base(1) - head_wid * n(1)];
    head_y = [p2(2), base(2) + head_wid * n(2), base(2) - head_wid * n(2)];
    patch(ax, head_x, head_y, arrow_color, 'EdgeColor', arrow_color);
end
if ~isempty(label)
    mid = (p1 + p2) / 2 + offset;
    text(ax, mid(1), mid(2), label, 'FontSize', 9.0, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'BackgroundColor', colors.white, 'Margin', 1.1, ...
        'Color', colors.ink, 'Interpreter', 'none');
end
end

function draw_release_time_axis(ax, W, box, release_rows, colors)
[T, ~] = size(W);
x_axis = box(1) - 0.035;
y_first = box(2) + (release_rows(1) - 0.5) / T * box(4);
y_last = box(2) + (release_rows(end) - 0.5) / T * box(4);
draw_arrow(ax, [x_axis y_first], [x_axis y_last], colors, '-', '', [], colors.accent, 1.0);
text(ax, x_axis - 0.015, (y_first + y_last) / 2, 'time', ...
    'FontSize', 9.4, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'Rotation', 90, 'Interpreter', 'none');
for r = 1:numel(release_rows)
    y = box(2) + (release_rows(r) - 0.5) / T * box(4);
    plot(ax, [box(1) - 0.014 box(1)], [y y], '-', ...
        'Color', colors.ink, 'LineWidth', 0.8);
    text(ax, box(1) - 0.019, y, sprintf('t_%d', r), ...
        'FontSize', 8.0, 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'middle', 'Interpreter', 'tex');
end
end

function draw_validation_outlines(ax, V, box, colors)
[T, N] = size(V);
cw = box(3) / N;
ch = box(4) / T;
[tt, jj] = find(V);
for m = 1:numel(tt)
    rectangle(ax, 'Position', [box(1) + (jj(m) - 1) * cw, box(2) + (tt(m) - 1) * ch, cw, ch], ...
        'FaceColor', 'none', 'EdgeColor', colors.validation, 'LineWidth', 1.15);
end
end

function draw_panel_a(ax, p, colors)
box = [0.08 0.19 0.82 0.66];
draw_pattern(ax, p.W, box, colors);
draw_axes_labels(ax, box, 'units');

tau_y = box(2) + (p.tau - 0.5) / size(p.W, 1) * box(4);
plot(ax, [box(1) box(1) + box(3)], [tau_y tau_y], '-', ...
    'Color', colors.accent, 'LineWidth', 1.35);
text(ax, box(1) + 0.020, tau_y + 0.030, 'decision date \tau', ...
    'FontSize', 9.0, 'Color', colors.accent, 'VerticalAlignment', 'middle', ...
    'HorizontalAlignment', 'left', ...
    'Interpreter', 'tex');

u = cell_center(p.W, box, p.example_cell(1), p.example_cell(2));
plot(ax, u(1), u(2), 'o', 'MarkerSize', 5.2, ...
    'MarkerEdgeColor', colors.feedback, 'MarkerFaceColor', colors.white, 'LineWidth', 1.2);
text(ax, u(1) + 0.026, u(2) + 0.058, 'u=(i,t,\tau)', ...
    'FontSize', 8.4, 'Color', colors.ink, 'BackgroundColor', colors.white, ...
    'Margin', 1.0, 'Interpreter', 'tex');

draw_arrow(ax, [0.665 0.815], u + [-0.014 0.006], colors, '-', '', [], colors.accent, 1.5);
draw_arrow(ax, u + [0.022 0.008], [0.850 0.825], colors, '--', '', [], colors.feedback, 1.4);
text(ax, 0.600, 0.835, 'procedure k', ...
    'FontSize', 9.0, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'BackgroundColor', colors.white, 'Margin', 1.2, 'Interpreter', 'none');
text(ax, 0.845, 0.835, 'feedback at \tau+\Delta', ...
    'FontSize', 9.0, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'BackgroundColor', colors.white, 'Margin', 1.2, 'Interpreter', 'tex');
end

function draw_panel_b(ax, p, colors)
box = [0.15 0.22 0.66 0.64];
draw_pattern(ax, p.W, box, colors);
draw_axes_labels(ax, box, 'units', false);
draw_release_time_axis(ax, p.W, box, p.release_rows, colors);
for rr = p.release_rows
    y = box(2) + (rr - 0.5) / size(p.W, 1) * box(4);
    plot(ax, [box(1) box(1) + box(3)], [y y], '-', ...
        'Color', colors.white, 'LineWidth', 0.35);
end
text(ax, box(1) + box(3) / 2, 0.89, 'high-frequency operating calendar', ...
    'FontSize', 9.4, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
rr = p.release_rows(3);
T = size(p.W, 1);
y_low = box(2) + (rr - 2.5) / T * box(4);
y_high = box(2) + (rr - 0.5) / T * box(4);
x_br = box(1) + box(3) + 0.026;
plot(ax, [x_br x_br], [y_low y_high], '-', 'Color', colors.feedback, 'LineWidth', 1.3);
plot(ax, [x_br - 0.010 x_br], [y_low y_low], '-', 'Color', colors.feedback, 'LineWidth', 1.3);
plot(ax, [x_br - 0.010 x_br], [y_high y_high], '-', 'Color', colors.feedback, 'LineWidth', 1.3);
text(ax, x_br + 0.060, (y_low + y_high) / 2, {'aggregation', 'restriction'}, ...
    'FontSize', 8.6, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'BackgroundColor', colors.white, 'Margin', 1.0, 'Interpreter', 'none');
text(ax, box(1) + box(3) / 2, box(2) - 0.085, 'lower-frequency release dates', ...
    'FontSize', 9.0, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'Interpreter', 'none');
end

function draw_panel_c(ax, p, colors)
box = [0.08 0.17 0.80 0.66];
draw_pattern(ax, p.W, box, colors);
draw_validation_outlines(ax, p.V, box, colors);
draw_axes_labels(ax, box, 'units and validation objects');

sep_x = box(1) + p.split / size(p.W, 2) * box(3);
plot(ax, [sep_x sep_x], [box(2) box(2) + box(4)], '-', ...
    'Color', colors.white, 'LineWidth', 1.5);
plot(ax, [sep_x sep_x], [box(2) box(2) + box(4)], '-', ...
    'Color', colors.ink, 'LineWidth', 0.8);
text(ax, box(1) + 0.25, box(2) + box(4) + 0.035, 'target population', ...
    'FontSize', 9.4, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
text(ax, sep_x + 0.20, box(2) + box(4) + 0.035, 'validation population (V_b)', ...
    'FontSize', 9.0, 'HorizontalAlignment', 'center', 'Interpreter', 'tex');
end

function draw_panel_d(ax, p, colors)
box1 = [0.08 0.22 0.36 0.56];
box2 = [0.56 0.22 0.36 0.56];
draw_pattern(ax, p.W, box1, colors);
draw_pattern(ax, p.completed, box2, colors);

header_y = box1(2) + box1(4) + 0.045;
arrow_y = box1(2) + box1(4) / 2;
text(ax, box1(1) + box1(3) / 2, header_y, 'decision-date vintage', ...
    'FontSize', 9.4, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
text(ax, box2(1) + box2(3) / 2, header_y, 'completed-panel object', ...
    'FontSize', 9.4, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
loss_inset = 0.010;
loss_x = [box2(1) + loss_inset, box2(1) + box2(3) - loss_inset, ...
    box2(1) + box2(3) - loss_inset, box2(1) + loss_inset, box2(1) + loss_inset];
loss_y = [box2(2) + loss_inset, box2(2) + loss_inset, ...
    box2(2) + box2(4) - loss_inset, box2(2) + box2(4) - loss_inset, box2(2) + loss_inset];
plot(ax, loss_x, loss_y, '-', 'Color', colors.feedback, 'LineWidth', 2.15);
text(ax, box2(1) + box2(3) / 2, box2(2) + 0.075, 'task loss L^D_\tau(k)', ...
    'FontSize', 10.2, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'Color', colors.feedback, 'BackgroundColor', colors.white, 'Margin', 1.1, ...
    'Interpreter', 'tex');
text(ax, axis_label_x(box1), box1(2) + box1(4) / 2, 'time', ...
    'FontSize', 9.5, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'Rotation', 90, 'Interpreter', 'none');
text(ax, 0.50, axis_label_y(box1), 'units', ...
    'FontSize', 9.5, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'Interpreter', 'none');

draw_arrow(ax, [0.45 arrow_y], [0.55 arrow_y], colors, '-', '', [], colors.accent, 1.6);
text(ax, 0.50, arrow_y + 0.070, {'completion', 'policy k'}, ...
    'FontSize', 8.6, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'BackgroundColor', colors.white, 'Margin', 1.1, 'Interpreter', 'none');
end
