function validate_params(p)
% validate_params.m (v6)
% ---------------------------------------------------------
% Basic sanity checks. Fail fast and loudly.
% ---------------------------------------------------------

req = { ...
    'seed','N','T','R', ...
    'phi','sigma_u','sigma_eps','sigma_lambda', ...
    'sigma_idio','phi_idio_high','phi_idio_low', ...
    'scenario','kappa','prop_nonlinear', ...
    'target_obs_rate','beta0','overlap_clip', ...
    'holdout_rate','holdout_mode','holdout_beta', ...
    'act_set','loss_mode', ...
    'B','batch_by_time','Delta','rho_reveal','normalize_regret', ...
    'n_bins_lambda','n_bins_time', ...
    'ucb_c','min_reveals_for_ucb', ...
    'ridge_lambda_logit','max_irls_iter','irls_tol','ridge_lambda_m', ...
    'nuisance_update','nuisance_mode', ...
    'als_max_iter','als_tol','als_ridge','als_ycap', ...
    'ssm_max_iter','ssm_tol','ssm_min_var','ssm_estimate_phi', ...
    'verbose','debug' ...
};

for j=1:numel(req)
    if ~isfield(p, req{j})
        error('validate_params:missing', 'Missing p.%s', req{j});
    end
end

if p.N<=1 || p.T<=2
    error('validate_params:size','Need N>1 and T>2.');
end
if p.R<1
    error('validate_params:R','Need R>=1.');
end
if abs(p.phi)>=1
    error('validate_params:phi','Need |phi|<1.');
end

if p.target_obs_rate<=0 || p.target_obs_rate>=1
    error('validate_params:obsrate','target_obs_rate must be in (0,1).');
end
if p.overlap_clip<=0 || p.overlap_clip>=0.5
    error('validate_params:clip','overlap_clip must be in (0,0.5).');
end

if p.holdout_rate<0 || p.holdout_rate>0.9
    error('validate_params:holdout','holdout_rate must be in [0,0.9].');
end

if p.B<1
    error('validate_params:B','Need B>=1.');
end
if p.Delta<0
    error('validate_params:Delta','Need Delta>=0.');
end
if p.rho_reveal<=0 || p.rho_reveal>1
    error('validate_params:rho','rho_reveal must be in (0,1].');
end

if ~(strcmp(p.holdout_mode,'random') || strcmp(p.holdout_mode,'logit'))
    error('validate_params:holdout_mode','holdout_mode must be random or logit.');
end
if ~(strcmp(p.act_set,'holdout_only') || strcmp(p.act_set,'all_missing'))
    error('validate_params:act_set','act_set must be holdout_only or all_missing.');
end
if ~(strcmp(p.loss_mode,'dr') || strcmp(p.loss_mode,'observed'))
    error('validate_params:loss_mode','loss_mode must be dr or observed.');
end
if ~(strcmp(p.nuisance_update,'once') || strcmp(p.nuisance_update,'batch'))
    error('validate_params:nuisance_update','nuisance_update must be once or batch.');
end
if ~(strcmp(p.nuisance_mode,'estimated') || strcmp(p.nuisance_mode,'oracle'))
    error('validate_params:nuisance_mode','nuisance_mode must be estimated or oracle.');
end

end
