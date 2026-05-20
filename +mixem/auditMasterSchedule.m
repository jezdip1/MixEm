function summary = auditMasterSchedule(ms, params)
% AUDITMASTERSCHEDULE  Lightweight sanity check of the generated schedule.
% Prints/logs trial counts by phase/task/block. Designed to catch the exact
% failure mode where the control task silently contains only the demo/practice
% rows or fewer than the requested 20 trials per block.

if nargin < 2, params = struct(); end
cellchar = @(v) local_cellchar(v);

isTrial = strcmp(cellfun(cellchar, ms.Event, 'UniformOutput', false), 'trial');
phase = cellfun(cellchar, ms.Phase, 'UniformOutput', false);
task  = cellfun(cellchar, ms.Task,  'UniformOutput', false);
blocks = ms.Block;

summary = struct();
summary.nRows = height(ms);
summary.nTrials = nnz(isTrial);
summary.nScreens = nnz(~isTrial);
summary.nMain = nnz(isTrial & strcmp(task,'main'));
summary.nControl = nnz(isTrial & strcmp(task,'control'));
summary.nValidation = nnz(isTrial & strcmp(task,'validation'));
summary.message = sprintf('Schedule audit: rows=%d screens=%d trials=%d main=%d control=%d validation=%d', ...
    summary.nRows, summary.nScreens, summary.nTrials, summary.nMain, summary.nControl, summary.nValidation);

fprintf('%s\n', summary.message);
try, params = mixem.logMsg(params, "SCHEDULE_AUDIT", 'message', summary.message); catch, end %#ok<NASGU>

% Control counts per block/phase
ctl = isTrial & strcmp(task,'control');
if any(ctl)
    phases = phase(ctl);
    b = blocks(ctl);
    [keys,~,ic] = unique(strcat(phases(:), '|', cellstr(num2str(b(:)))));
    for i = 1:numel(keys)
        n = nnz(ic==i);
        msg = sprintf('Schedule audit control count: %s n=%d', keys{i}, n);
        fprintf('%s\n', msg);
        try, params = mixem.logMsg(params, "SCHEDULE_AUDIT_CONTROL", 'message', msg); catch, end %#ok<NASGU>
    end
end

% Expected minimums from params. Use warnings rather than hard errors so that
% short debug runs remain possible when params intentionally request fewer rows.
try
    expectedPracticeCtl = double(params.nPracticeControl);
    actualPracticeCtl = nnz(ctl & strcmp(phase,'practice_control'));
    if actualPracticeCtl ~= expectedPracticeCtl
        warning('auditMasterSchedule:PracticeControlCount', ...
            'Practice control has %d trials, expected %d.', actualPracticeCtl, expectedPracticeCtl);
    end
catch
end

try
    expectedPerBlock = double(params.nControlPerBlock);
catch
    expectedPerBlock = 20;
end
if expectedPerBlock > 0
    expBlocks = local_expected_control_blocks(params);
    for i = 1:numel(expBlocks)
        b = expBlocks(i);
        actual = nnz(ctl & blocks==b);
        if actual ~= expectedPerBlock
            warning('auditMasterSchedule:ControlBlockCount', ...
                'Control block %d has %d trials, expected %d.', b, actual, expectedPerBlock);
        end
    end
end
end


function expBlocks = local_expected_control_blocks(params)
try, nCtl = double(params.blocksControlPerStage); catch, nCtl = 4; end
try, n1 = double(params.blocksMain12); catch, n1 = 4; end
try, n2 = double(params.blocksMain56); catch, n2 = 4; end
try, n3 = double(params.blocksMain9101212); catch, n3 = 4; end

b1 = 1:min(nCtl,n1);
b2 = 5:(4 + min(nCtl,n2));
b3 = 9:(8 + min(nCtl,n3));
expBlocks = [b1 b2 b3];
end

function s = local_cellchar(v)
if iscell(v)
    if isempty(v) || isempty(v{1}), s=''; else, s=char(v{1}); end
else
    s = char(v);
end
end
