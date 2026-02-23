function y = clamp(x, lo, hi)
%CLAMP Clamp x elementwise to [lo,hi].
y = min(max(x, lo), hi);
end
