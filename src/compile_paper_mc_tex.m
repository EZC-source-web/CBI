function compile_paper_mc_tex(tex_dir)
% compile_paper_mc_tex.m
% ---------------------------------------------------------
% Compile the standalone LaTeX file text/PaperMCMain.tex.
% Runs: pdflatex -> bibtex -> pdflatex -> pdflatex
% Requires a TeX distribution (pdflatex + bibtex) available on PATH.
% ---------------------------------------------------------

if nargin < 1 || isempty(tex_dir)
    pkg_root = fileparts(fileparts(mfilename('fullpath')));
    tex_dir = fullfile(pkg_root,'text');
end

main_tex = fullfile(tex_dir,'PaperMCMain.tex');
if ~exist(main_tex,'file')
    error('Cannot find: %s', main_tex);
end

% Compile inside tex_dir so BibTeX finds the aux/bbl files.
cwd = pwd;
cleanupObj = onCleanup(@() cd(cwd));
cd(tex_dir);

cmd_pdf = 'pdflatex -interaction=nonstopmode -halt-on-error "PaperMCMain.tex"';

% Pass 1
[status1, out1] = system(cmd_pdf);
if status1 ~= 0
    disp(out1);
    error('pdflatex failed (pass 1).');
end

% BibTeX (only needed if \cite appears; harmless otherwise)
[statusb, outb] = system('bibtex "PaperMCMain"');
if statusb ~= 0
    disp(outb);
    error('bibtex failed.');
end

% Pass 2
[status2, out2] = system(cmd_pdf);
if status2 ~= 0
    disp(out2);
    error('pdflatex failed (pass 2).');
end

% Pass 3
[status3, out3] = system(cmd_pdf);
if status3 ~= 0
    disp(out3);
    error('pdflatex failed (pass 3).');
end

fprintf('Compiled: %s\n', fullfile(tex_dir,'PaperMCMain.pdf'));
end
