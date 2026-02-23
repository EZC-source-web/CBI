function alpha = calibrate_alpha(eta_no_alpha, target)
% calibrate_alpha.m
% ---------------------------------------------------------
% Given eta_no_alpha = X*beta + nonlinear_term (without alpha),
% find alpha such that mean(logistic(alpha + eta_no_alpha)) ~= target.
% Uses bisection on [-30,30].
% ---------------------------------------------------------

f = @(a) mean( 1 ./ (1 + exp(-max(min(a + eta_no_alpha, 35), -35))) ) - target;

aL = -30; aU = 30;
fL = f(aL); fU = f(aU);
if fL > 0 || fU < 0
    % target out of range, but still return midpoint
    alpha = 0.5*(aL+aU);
    return;
end

for it=1:80
    aM = 0.5*(aL+aU);
    if f(aM) > 0
        aU = aM;
    else
        aL = aM;
    end
end
alpha = 0.5*(aL+aU);

end
