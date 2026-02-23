function setup_paths(pkg_root)
% setup_paths.m
% ---------------------------------------------------------
% Robust path setup for the CBI PaperMC package.
% Adds ONLY the function code under ./src (including subfolders).
%
% Usage:
%   setup_paths();                % infer package root automatically
%   setup_paths('/path/to/pkg');  % explicit package root
% ---------------------------------------------------------

if nargin < 1 || isempty(pkg_root)
    % This file lives in <pkg_root>/src
    this_file = mfilename('fullpath');
    src_dir = fileparts(this_file);
    pkg_root = fileparts(src_dir);
end

src_dir = fullfile(pkg_root, 'src');
if ~exist(src_dir, 'dir')
    error('Cannot find src/ under: %s', pkg_root);
end

addpath(genpath(src_dir));
rehash toolboxcache;
end
