% WIPE_OUTPUTS.m
% ---------------------------------------------------------
% Deletes and recreates the single output folder to avoid confusion.
% Safe to run before any new experiment.
%
% Expected structure:
%   out/exhibits/   (tables & figures used by LaTeX)
%   out/raw/        (light per-stage objects; optional)
% ---------------------------------------------------------

ROOT = fileparts(mfilename('fullpath'));
OUT  = fullfile(ROOT,'out');

if exist(OUT,'dir')
    rmdir(OUT,'s');
end

mkdir(OUT);
mkdir(fullfile(OUT,'exhibits'));
mkdir(fullfile(OUT,'raw'));

% Keep folders visible in git-style workflows
fid=fopen(fullfile(OUT,'.gitkeep'),'w'); if fid>0, fclose(fid); end
fid=fopen(fullfile(OUT,'exhibits','.gitkeep'),'w'); if fid>0, fclose(fid); end
fid=fopen(fullfile(OUT,'raw','.gitkeep'),'w'); if fid>0, fclose(fid); end

fprintf('[OK] Outputs wiped. Fresh folder created:\n  %s\n', OUT);
