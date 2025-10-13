function runExperiment()
root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root,'Code')));
cfg = utils.loadConfig();
PID = subject.ensure_subject();
phList = {'main1','supplemental','main2','validation'};
fprintf('Available phases: %s\n', strjoin(phList, ', '));
phase = input('Phase? (main1/supplemental/main2/validation): ','s');
if ~ismember(lower(phase), phList), error('Unknown phase: %s', phase); end
[Sched, schedPath] = subject.ensure_schedule(PID, phase);
runDir = fullfile(root, 'Results', datestr(now,'yyyymmdd_HHMMSS')); if ~exist(runDir,'dir'), mkdir(runDir); end
Screen('Preference','SkipSyncTests', 1); PsychDefaultSetup(2);
[win, rect] = Screen('OpenWindow', max(Screen('Screens')), 0); HideCursor;
try
  switch lower(phase)
    case 'main1',        tasks.main(win, rect, cfg, Sched, schedPath, runDir, 1);
    case 'supplemental', tasks.main(win, rect, cfg, Sched, schedPath, runDir, 2);
    case 'main2',        tasks.main(win, rect, cfg, Sched, schedPath, runDir, 3);
    case 'validation',   tasks.validation(win, rect, cfg, Sched, schedPath, runDir);
  end
catch ME, sca; ShowCursor; rethrow(ME);
end, sca; ShowCursor;
end
