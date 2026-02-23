function action_mask = get_action_mask(M0, holdout, p)
% get_action_mask.m (v6)
% ---------------------------------------------------------
% Defines the action set for the bandit/policy.
%
% - holdout_only : action set = delayed-release cells (holdout==1)
% - all_missing  : action set = cells missing at decision time (M0==0)
%
% The first is the cleanest when presenting regret and learning with delayed
% feedback, because the algorithm acts on the same domain on which feedback
% can (in principle) be observed.
% ---------------------------------------------------------

M0 = force_panel(M0, p.N, p.T, 'M0');
holdout = force_panel(holdout, p.N, p.T, 'holdout');

switch p.act_set
    case 'holdout_only'
        action_mask = logical(holdout);
    case 'all_missing'
        action_mask = ~logical(M0);
    otherwise
        error('get_action_mask:act_set','Unknown act_set %s', p.act_set);
end

end
