function out = run_grid_experiments()
% run_grid_experiments.m
% ---------------------------------------------------------
% Runs a grid of simulation configurations and stores results.
% This is the script you will use to populate the paper tables.
%
% You can freely extend the grids below.
% ---------------------------------------------------------

setup_paths();

base = default_params();
base.verbose = false;

scenarios = {'A','B','C','D'};
obs_rates = [0.40, 0.55, 0.70];
phis      = [0.3, 0.7, 0.9];
rhos      = [0.25, 0.50, 0.75];
kappas    = [0.0, 0.3, 0.6];   % only used in B
pnls      = [0.0, 1.0, 2.0];   % only used in C/D

grid = [];
g = 0;

for s=1:numel(scenarios)
    for or=1:numel(obs_rates)
        for ph=1:numel(phis)
            for rr=1:numel(rhos)
                g = g + 1;
                p = base;
                p.scenario = scenarios{s};
                p.target_obs_rate = obs_rates(or);
                p.phi = phis(ph);
                p.rho_reveal = rhos(rr);

                if strcmp(p.scenario,'B')
                    p.kappa = kappas(min(end,2)); % default mid unless overridden below
                else
                    p.kappa = 0.0;
                end
                if ismember(p.scenario, {'C','D'})
                    p.prop_nonlinear = pnls(min(end,2));
                else
                    p.prop_nonlinear = 0.0;
                end

                grid(g).p = p; %#ok<AGROW>
            end
        end
    end
end

out = struct();
out.grid = grid;
out.res = cell(numel(grid),1);

for g=1:numel(grid)
    p = grid(g).p;
    fprintf('[GRID] %d/%d  scenario=%s  obs=%.2f  phi=%.2f  rho=%.2f\n', ...
        g, numel(grid), p.scenario, p.target_obs_rate, p.phi, p.rho_reveal);

    out.res{g} = run_mc(p);
end

% Save .mat for later processing
save('grid_results.mat','out');

% Export a compact LaTeX table for each scenario (example)
export_results_tex(out, 'grid_results_table.tex');

end
