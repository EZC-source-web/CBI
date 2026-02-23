function m = nanmean_local(x)
%NANMEAN_LOCAL Toolbox-free NaN-robust mean.
x = x(:);
x = x(~isnan(x));
if isempty(x)
    m = NaN;
else
    m = mean(x);
end
end
