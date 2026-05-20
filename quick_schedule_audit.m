function [summary, ms] = quick_schedule_audit(subjID)
% QUICK_SCHEDULE_AUDIT  Build and audit MixEm schedule without PTB/audio/sync.
% Usage:
%   quick_schedule_audit
%   quick_schedule_audit('test1905')
%
% This is intended for fast W540 smoke testing after patches. It does not
% open a Psychtoolbox window and does not touch the trigger/serial devices.

if nargin < 1 || isempty(subjID)
    subjID = 'schedule_test';
end

baseDir = fileparts(mfilename('fullpath'));
addpath(baseDir, '-begin');
rehash;
try, clear('mixem.buildScheduleMixEm'); catch, end
try, clear('mixem.auditMasterSchedule'); catch, end

params = struct();
params.subjID = char(subjID);
params.idNum = mixem.rngFromSubjID(params.subjID);
params.pngDir = fullfile(baseDir,'PNG');
params.stimDir = fullfile(baseDir,'Stimuli');
params.resultsDir = fullfile(baseDir,'Results');
params.stimXlsx = fullfile(baseDir,'data','mixem_reunified_stimuli_19_9_2025.xlsx');

params.nPracticeMain = 20;
params.nPracticeControl = 20;
params.blocksMain12 = 4;
params.blocksMain56 = 4;
params.blocksMain9101212 = 4;
params.blocksControlPerStage = 4;
params.nMainPerBlock = 40;
params.nControlPerBlock = 20;
params.nVal13 = 32;
params.nVal14 = 0;

rng(params.idNum, 'twister');
ms = mixem.buildScheduleMixEm(params);
summary = mixem.auditMasterSchedule(ms, params);
assignin('base', 'mixem_schedule_audit_ms', ms);
assignin('base', 'mixem_schedule_audit_summary', summary);
fprintf('Saved schedule to base workspace as mixem_schedule_audit_ms.\n');
end
