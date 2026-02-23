function A = force_panel(A, N, T, name)
%FORCE_PANEL Ensure A is N x T (accept vectorized N*T x 1 or N*T x K).
%
% This is the main guardrail against silent shape bugs. It is called at
% the start of most functions that work with panel objects.
%
% Usage:
%   M = force_panel(M, p.N, p.T, 'M');
%
% If A is a vector with length N*T, it is reshaped to N x T.
% If A is a matrix with size (N*T) x K (e.g. stacked features), it is left as-is.
% If A is N x T, it is left as-is.
%
% NOTE: For stacked objects (N*T) x d, call force_stacked (not needed here).

if nargin < 4
    name = 'array';
end

if isempty(A)
    error('force_panel:%s', '%s is empty.', name);
end

% N x T case
if ismatrix(A) && size(A,1)==N && size(A,2)==T
    return;
end

% vectorized N*T x 1
if isvector(A)
    if numel(A) ~= N*T
        error('force_panel:%s', '%s has numel=%d, expected N*T=%d.', name, numel(A), N*T);
    end
    A = reshape(A, [N, T]);
    return;
end

% stacked case is allowed for feature matrices, but not for panels
if size(A,1)==N*T
    % leave as-is (caller should know what it is doing)
    return;
end

s = size(A);
error('force_panel:%s', '%s is %dx%d, expected %dx%d or vector length %d.', name, s(1), s(2), N, T, N*T);
end
