function v = nanvar_local(x)
%NANVAR_LOCAL Toolbox-free NaN-robust variance (population).
x = x(:);
x = x(~isnan(x));
if numel(x) <= 1
    v = NaN;
else
    v = var(x, 1);
end
end
