function beta = ridge_fit(X, y, lambda)
% ridge_fit.m
% ---------------------------------------------------------
% Ridge regression (toolbox-free):
%   beta = argmin_b ||y - X b||^2 + lambda ||b||^2
%
% Uses normal equations with small ridge for stability.
% ---------------------------------------------------------

[d1, d2] = size(X); %#ok<NASGU>
XtX = X' * X;
Xty = X' * y;

beta = (XtX + lambda * eye(size(XtX))) \ Xty;

end
