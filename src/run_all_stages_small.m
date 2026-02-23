function outs = run_all_stages_small()
% run_all_stages_small.m (v6.7)
% ---------------------------------------------------------
% Runs stages 0..7 with small sizes to populate out/stage_s/ with
% at least one table and one figure per stage.
%
% IMPORTANT:
% We pass to run_stage() ONLY "global" overrides (N,T,R,B,verbose) so that
% stage_config() can control stage-specific parameters such as Delta, rho,
% loss_mode, nuisance_mode, etc. This is crucial to keep Stage 1 != Stage 2
% and Stage 3 != Stage 4 in the pedagogical ladder.
%
% Usage:
%   outs = run_all_stages_small;
% ---------------------------------------------------------

setup_paths();

% Only global overrides (do NOT pass a full default_params() struct)
p_override = struct();
p_override.N = 40;
p_override.T = 100;
p_override.R = 30;
p_override.B = 12;
p_override.verbose = true;

outs = cell(8,1);
for s=0:7
    fprintf('\n=== Running stage %d ===\n', s);
    outs{s+1} = run_stage(s, p_override);
end

fprintf('\nDone. Outputs in cbi_mc_matlab/out/\n');

end
