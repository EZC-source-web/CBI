function print_exhibits_summary(out)
% print_exhibits_summary.m
% ---------------------------------------------------------
% Convenience printer: shows where the exhibits live
% and lists the generated files (name + size).
% ---------------------------------------------------------

if nargin<1 || isempty(out) || ~isstruct(out)
    fprintf('[Paper MC] No output struct provided.\n');
    return;
end

exh = '';
if isfield(out,'exhibits_dir')
    exh = out.exhibits_dir;
elseif isfield(out,'latest_exhibits_dir')
    % backward compatibility
    exh = out.latest_exhibits_dir;
end

if isempty(exh) || ~exist(exh,'dir')
    fprintf('[Paper MC] Exhibits folder not found.\n');
    if ~isempty(exh)
        fprintf('  expected: %s\n', exh);
    end
    return;
end

fprintf('\n[Paper MC] Exhibits:\n  %s\n', exh);

d = dir(exh);
d = d(~[d.isdir]);

if isempty(d)
    fprintf('  (no files)\n');
else
    [~,idx] = sort([d.bytes],'descend');
    d = d(idx);
    for i=1:numel(d)
        fprintf('  %-40s %8.1f KB\n', d(i).name, d(i).bytes/1024);
    end
end

if isfield(out,'raw_dir')
    fprintf('[Paper MC] Raw folder (light outputs):\n  %s\n', out.raw_dir);
end

end
