function X = build_context(lambda, T)
% build_context.m
% ---------------------------------------------------------
% Stacks contexts X_it = (1, lambda_i, t/T) into a (N*T) x 3 matrix.
% This is intentionally simple; you can add lags or other features later.
% ---------------------------------------------------------

N = numel(lambda);
X = zeros(N*T, 3);

row = 0;
for t=1:T
    tt = t / T;
    for i=1:N
        row = row + 1;
        X(row,:) = [1, lambda(i), tt];
    end
end

end
