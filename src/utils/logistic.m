function y = logistic(x)
%LOGISTIC Numerically stable logistic function.
y = 1 ./ (1 + exp(-max(min(x, 35), -35)));
end
