function [Sched, schedPath] = ensure_schedule(PID, phase)
root   = fileparts(fileparts(mfilename('fullpath')));
idxCsv = fullfile(root,'Stimuli','index','stimuli_master_index.csv');
if ~exist(idxCsv,'file'), error('Missing stimuli index: %s', idxCsv); end
T = utils.loadStimuliTable(idxCsv);
switch lower(phase)
  case 'main1',       rows = strcmpi(T.set,'main');
  case 'supplemental',rows = strcmpi(T.set,'supp');
  case 'main2',       rows = strcmpi(T.set,'main');
  case 'validation',  rows = strcmpi(T.set,'main') | strcmpi(T.set,'supp');
  otherwise, error('Unknown phase: %s', phase);
end
TT = T(rows,:);
subjDir   = fullfile(root,'Results','subjects',PID);
if ~exist(subjDir,'dir'), mkdir(subjDir); end
schedPath = fullfile(subjDir, sprintf('schedule_%s.csv', lower(phase)));
if exist(schedPath,'file')
    Sched = readtable(schedPath);
    fprintf('Loaded existing schedule: %s (%d rows)\n', schedPath, height(Sched)); return;
end
rng('shuffle'); ord = randperm(height(TT))'; Sched = TT(ord,:);
Sched.block=zeros(height(Sched),1); Sched.trial_in_blk=zeros(height(Sched),1);
Sched.order_idx=(1:height(Sched))'; Sched.done=false(height(Sched),1);
Sched.onset_ts=strings(height(Sched),1); Sched.offset_ts=strings(height(Sched),1);
Sched.response_key=strings(height(Sched),1); Sched.rt_ms=nan(height(Sched),1);
if ~ismember('correct_if_applicable', Sched.Properties.VariableNames)
  Sched.correct_if_applicable = nan(height(Sched),1);
end
writetable(Sched, schedPath);
fprintf('Created new schedule: %s (%d rows)\n', schedPath, height(Sched));
end
