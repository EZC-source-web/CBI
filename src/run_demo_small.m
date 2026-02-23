function res = run_demo_small()
% run_demo_small.m
% ---------------------------------------------------------
% Smoke test for the package.
% - small N,T,R so it runs quickly
% - prints a short summary
%
% Usage:
%   run_demo_small
% ---------------------------------------------------------

setup_paths();

p = default_params();
p.N = 30;
p.T = 80;
p.R = 20;
p.B = 10;
p.Delta = 2;
p.rho_reveal = 0.5;
p.holdout_rate = 0.2;
p.target_obs_rate = 0.55;
p.verbose = false;

res = run_mc(p);

disp('--- DEMO SUMMARY ---');
disp(res.summary);

end
