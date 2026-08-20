function quick_release_audit()
% QUICK_RELEASE_AUDIT  Fast non-PTB checks for both supported MixEm protocols.
%
% Run from the MixEm repository root:
%   quick_release_audit
%
% This does not open a window/audio/trigger device. It verifies the two
% schedule variants introduced for production:
%   FULL = historical 792-trial protocol with supplemental blocks 5-8
%   CORE = 552-trial protocol without supplemental blocks 5-8

baseDir = fileparts(mfilename('fullpath'));
addpath(baseDir, '-begin');
rehash;

fprintf('\n=== MixEm release audit: FULL protocol ===\n');
[sFull, msFull] = quick_schedule_audit('release_audit_full', true);
assert(sFull.nTrials == 792, 'FULL: expected 792 trials, got %d.', sFull.nTrials);
assert(sFull.nMain == 500, 'FULL: expected 500 main trials, got %d.', sFull.nMain);
assert(sFull.nControl == 260, 'FULL: expected 260 control trials, got %d.', sFull.nControl);
assert(sFull.nValidation == 32, 'FULL: expected 32 validation trials, got %d.', sFull.nValidation);
assert(local_count_phase_task_trials(msFull, 'supplemental', 'main') == 160, ...
    'FULL: expected 160 supplemental main trials.');
assert(local_count_phase_task_trials(msFull, 'supplemental', 'control') == 80, ...
    'FULL: expected 80 supplemental control trials.');

fprintf('\n=== MixEm release audit: CORE protocol ===\n');
[sCore, msCore] = quick_schedule_audit('release_audit_core', false);
assert(sCore.nTrials == 552, 'CORE: expected 552 trials, got %d.', sCore.nTrials);
assert(sCore.nMain == 340, 'CORE: expected 340 main trials, got %d.', sCore.nMain);
assert(sCore.nControl == 180, 'CORE: expected 180 control trials, got %d.', sCore.nControl);
assert(sCore.nValidation == 32, 'CORE: expected 32 validation trials, got %d.', sCore.nValidation);
assert(local_count_phase_task_trials(msCore, 'supplemental', 'main') == 0, ...
    'CORE: supplemental main trials must be absent.');
assert(local_count_phase_task_trials(msCore, 'supplemental', 'control') == 0, ...
    'CORE: supplemental control trials must be absent.');

fprintf('\nPASS: FULL and CORE schedule variants have expected trial counts.\n');
fprintf('NOTE: PTB timing, audio fade, hardware triggers and resume still require W540 smoke tests.\n');
end

function n = local_count_phase_task_trials(ms, phaseName, taskName)
cellchar = @(v) local_cellchar(v);
isTrial = strcmp(cellfun(cellchar, ms.Event, 'UniformOutput', false), 'trial');
phase = cellfun(cellchar, ms.Phase, 'UniformOutput', false);
task = cellfun(cellchar, ms.Task, 'UniformOutput', false);
n = nnz(isTrial & strcmp(phase, phaseName) & strcmp(task, taskName));
end

function s = local_cellchar(v)
if iscell(v)
    if isempty(v) || isempty(v{1}), s=''; else, s=char(v{1}); end
else
    s = char(v);
end
end
