function master = buildScheduleMixEm(params)
% buildScheduleMixEm
% Vytvoří MasterSchedule tabulku pro MixEm s délkami řízenými z runExperiment:
%   params.nPracticeMain
%   params.nPracticeControl
%   params.blocksMain12
%   params.blocksMain56
%   params.blocksMain9101212
%   params.blocksControlPerStage
%
% Volitelné (když chceš zkrátit i délku bloků a validation):
%   params.nMainPerBlock     (default 40)
%   params.nControlPerBlock  (default 20)
%   params.nVal13            (default 32)
%   params.nVal14            (default 36)
%
% ZÁKLADNÍ SLOUPCE (vždy):
%   Seq, Phase, Event, Task, Block, TrialInBlock, Modality, StimPath, Dur_ms, Prompt, PNG
%
% VOLITELNÉ (pouze pokud jsou v XLS):
%   SR         (z social_relevance)
%   CorrectCat (z valence_cat nebo val_group)
%
% Pozn.: nepoužívá string typy (jen char/cell), aby byla stabilní.

%% -------- defaults z params (aby šlo krátit běh jen změnou v runExperiment) --------
if ~isfield(params,'nPracticeMain') || isempty(params.nPracticeMain), params.nPracticeMain = 20; end
if ~isfield(params,'nPracticeControl') || isempty(params.nPracticeControl), params.nPracticeControl = 20; end

if ~isfield(params,'blocksMain12') || isempty(params.blocksMain12), params.blocksMain12 = 4; end
if ~isfield(params,'blocksMain56') || isempty(params.blocksMain56), params.blocksMain56 = 4; end
if ~isfield(params,'blocksMain9101212') || isempty(params.blocksMain9101212), params.blocksMain9101212 = 4; end

if ~isfield(params,'blocksControlPerStage') || isempty(params.blocksControlPerStage), params.blocksControlPerStage = 4; end

if ~isfield(params,'nMainPerBlock') || isempty(params.nMainPerBlock), params.nMainPerBlock = 40; end
if ~isfield(params,'nControlPerBlock') || isempty(params.nControlPerBlock), params.nControlPerBlock = 20; end

if ~isfield(params,'nVal13') || isempty(params.nVal13), params.nVal13 = 32; end
if ~isfield(params,'nVal14') || isempty(params.nVal14), params.nVal14 = 36; end

% sanity (minimálně 1, aby to mělo smysl)
params.nPracticeMain = max(0, round(double(params.nPracticeMain)));
params.nPracticeControl = max(0, round(double(params.nPracticeControl)));
params.blocksMain12 = max(0, round(double(params.blocksMain12)));
params.blocksMain56 = max(0, round(double(params.blocksMain56)));
params.blocksMain9101212 = max(0, round(double(params.blocksMain9101212)));
params.blocksControlPerStage = max(0, round(double(params.blocksControlPerStage)));
params.nMainPerBlock = max(1, round(double(params.nMainPerBlock)));
params.nControlPerBlock = max(1, round(double(params.nControlPerBlock)));
params.nVal13 = max(0, round(double(params.nVal13)));
params.nVal14 = max(0, round(double(params.nVal14)));

fprintf('buildScheduleMixEm W540 patch v3: nPracticeControl=%d nControlPerBlock=%d blocksControlPerStage=%d nVal13=%d nVal14=%d\n', ...
    params.nPracticeControl, params.nControlPerBlock, params.blocksControlPerStage, params.nVal13, params.nVal14);

%% --- 0) Nacti XLS ---
try
    T = readtable(params.stimXlsx, 'Sheet','Sheet1', 'PreserveVariableNames', true);
catch
    T = readtable(params.stimXlsx, 'PreserveVariableNames', true);
end
T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);

need = {'filename','modality','balanced_set'};
missing = setdiff(need, T.Properties.VariableNames);
if ~isempty(missing)
    error('buildScheduleMixEm:MissingCols', ...
        'V XLS chybi povinne sloupce: %s', strjoin(missing, ', '));
end

% volitelne
hasDurationMs = ismember('duration_ms', T.Properties.VariableNames);
hasDurationS  = ismember('duration',    T.Properties.VariableNames);

hasSR       = ismember('social_relevance', T.Properties.VariableNames);
hasValence  = ismember('valence_cat', T.Properties.VariableNames);
hasValGrp   = ismember('val_group',   T.Properties.VariableNames);

% typy (bez string)
T.filename     = cellstr(T.filename);
T.modality     = normalizeModalityCell(cellstr(T.modality));
T.balanced_set = double(toDouble(T.balanced_set));

% ---- duration handling (THIS IS THE IMPORTANT PART) ----
if hasDurationMs
    T.duration_ms = double(toDouble(T.duration_ms));
elseif hasDurationS
    % in your XLS the column is 'duration' and it is in SECONDS -> convert to ms
    T.duration_ms = 1000 * double(toDouble(T.duration));
else
    T.duration_ms = nan(height(T),1);
end

if hasSR,       T.social_relevance = cellstr(T.social_relevance); end
if hasValence,  T.valence_cat = double(toDouble(T.valence_cat)); end
if hasValGrp,   T.val_group   = double(toDouble(T.val_group)); end

% dělení
T_bal  = T(T.balanced_set==1, :); % MAIN
T_supp = T(T.balanced_set==0, :); % SUPPLEMENTAL

% RNG dle subjektu (deterministický schedule)
rng(params.idNum,'twister');

%% --- 1) šablona výstupní tabulky ---
varNames = {'Seq','Phase','Event','Task','Block','TrialInBlock','Modality','StimPath','Dur_ms','Prompt','PNG'};
varTypes = {'double','cell','cell','cell','double','double','cell','cell','double','cell','cell'};
master   = table('Size',[0 numel(varNames)], 'VariableTypes',varTypes, 'VariableNames',varNames);

% volitelné sloupce sbíráme paralelně
srVals = cell(0,1);
ccVals = nan(0,1);

seq = 0;
    function bumpSeq()
        seq = seq + 1;
    end

    function addScreen(phase, png)
        bumpSeq();
        master = [master; {seq, {char(phase)}, {'screen'}, {'screen'}, 0, 0, {''}, {''}, 0, {''}, {char(png)}}]; %#ok<AGROW>
        if hasSR, srVals{end+1,1} = ''; end %#ok<AGROW>
        if hasValence||hasValGrp, ccVals(end+1,1) = NaN; end %#ok<AGROW>
    end

    function addTrials(phase, task, block, Rows, useCorrectCatFromXLS)
        if isempty(Rows) || height(Rows)==0, return; end

        % promíchat v rámci bloku
        if height(Rows) > 1
            Rows = Rows(randperm(height(Rows)),:);
        end

        for ii = 1:height(Rows)
            r = Rows(ii,:);

            bumpSeq();

            stimPath = resolvePath(params, r);
            if exist(stimPath,'file') ~= 2
                error('buildScheduleMixEm:MissingStimulus', ...
                    'Chybí stimulus soubor pro phase=%s task=%s modality=%s filename=%s -> stimPath=%s', ...
                    char(phase), char(task), char(getCellScalar(r.modality)), char(getCellScalar(r.filename)), stimPath);
            end

            % dur_ms
            dur = NaN;
            if ismember('duration_ms', r.Properties.VariableNames)
                dur = double(r.duration_ms(1));
            end

            % prompt
            prom = 'valence_1_2_3';
            if strcmp(task,'control')
                prom = 'control_1_2_3';
            end
            if strcmp(task,'validation')
                prom = 'rating_1_7';
            end

            % modality
            mod = '';
            if ismember('modality', r.Properties.VariableNames)
                mod = char(getCellScalar(r.modality));
            end

            master = [master; { ...
                seq, {char(phase)}, {'trial'}, {char(task)}, double(block), double(ii), ...
                {mod}, {char(stimPath)}, double(dur), {char(prom)}, {''} ...
                }]; %#ok<AGROW>

            % optional SR
            if hasSR
                if strcmp(task,'control')
                    srVals{end+1,1} = 'na';
                elseif any(strcmp(task, {'main','validation','supplemental'}))
                    if ismember('social_relevance', r.Properties.VariableNames)
                        srVals{end+1,1} = char(getCellScalar(r.social_relevance));
                    else
                        srVals{end+1,1} = '';
                    end
                else
                    srVals{end+1,1} = 'mixed'; % practice
                end
            end

            % optional CorrectCat
            if hasValence || hasValGrp
                cc = NaN;
                if useCorrectCatFromXLS
                    if hasValence && ismember('valence_cat', r.Properties.VariableNames)
                        cc = double(r.valence_cat(1));
                    elseif hasValGrp && ismember('val_group', r.Properties.VariableNames)
                        cc = double(r.val_group(1));
                    end
                end
                ccVals(end+1,1) = cc; %#ok<AGROW>
            end
        end
    end

%% --- 2) INIT + PRACTICE ---
addScreen('init','welcome_page.png');
addScreen('init','vol_test.png');

% Practice MAIN (celkem nPracticeMain -> rozdělíme 50/50 aud/vis)
addScreen('practice_main','inst_main.png');
nPM = double(params.nPracticeMain);
nAudP = floor(nPM/2);
nVisP = nPM - nAudP;
prRows = makePracticeRows(params, nAudP, nVisP);
addTrials('practice_main','main',0, prRows, false);
addScreen('practice_main','feedback.png');

% Practice CONTROL
addScreen('practice_control','inst_control.png');
addScreen('practice_control','stim_control.png');
addScreen('practice_control','re_stim_control.png');
ctlRows = makeControlRows(params, double(params.nPracticeControl));
addTrials('practice_control','control',0, ctlRows, false);
addScreen('practice_control','feedback.png');

addScreen('test','test_page.png');

%% --- 3) TEST stage: MAIN blocks 1..blocksMain12 + CONTROL blocks (blocksControlPerStage) ---
blkSizeMain = double(params.nMainPerBlock);
blkSizeCtl  = double(params.nControlPerBlock);

nMainBlocks = double(params.blocksMain12);
testBlocks  = 1:nMainBlocks;
nCtlBlocks  = min(double(params.blocksControlPerStage), numel(testBlocks));

B1 = assignBlocksSample(T_bal, testBlocks, blkSizeMain);
for ii = 1:numel(testBlocks)
    b = testBlocks(ii);

    addScreen('test','task_main.png');
    addTrials('test','main',b, B1(B1.Block==b,:), true);

    if ii <= nCtlBlocks
        addScreen('test','task_control.png');
        addTrials('test','control',b, makeControlRows(params, blkSizeCtl), false);
    end

    addScreen('test','break_page.png');
end

%% --- 4) SUPPLEMENTAL stage: MAIN blocks 5..(4+blocksMain56) + CONTROL ---
nSuppBlocks = double(params.blocksMain56);
suppBlocks  = 5:(4 + nSuppBlocks);
nCtlBlocks  = min(double(params.blocksControlPerStage), numel(suppBlocks));

B2 = assignBlocksSample(T_supp, suppBlocks, blkSizeMain);
for ii = 1:numel(suppBlocks)
    b = suppBlocks(ii);

    addScreen('supplemental','task_main.png');
    addTrials('supplemental','main',b, B2(B2.Block==b,:), true);

    if ii <= nCtlBlocks
        addScreen('supplemental','task_control.png');
        addTrials('supplemental','control',b, makeControlRows(params, blkSizeCtl), false);
    end

    if ii < numel(suppBlocks)
        addScreen('supplemental','break_page.png');
    end
end

%% --- 5) LONG BREAK + RESUME DEMO ---
addScreen('resume','long_break_page.png');
addScreen('resume','test_resume_page.png');
addScreen('resume','stim_control.png');
addScreen('resume','re_stim_control_test.png');

%% --- 6) REPETITION2 stage: MAIN blocks 9..(8+blocksMain9101212) + CONTROL ---
nRepBlocks = double(params.blocksMain9101212);
repBlocks  = 9:(8 + nRepBlocks);
nCtlBlocks = min(double(params.blocksControlPerStage), numel(repBlocks));

B3 = assignBlocksSample(T_bal, repBlocks, blkSizeMain);
for ii = 1:numel(repBlocks)
    b = repBlocks(ii);

    addScreen('repetition2','task_main.png');
    addTrials('repetition2','main',b, B3(B3.Block==b,:), true);

    if ii <= nCtlBlocks
        addScreen('repetition2','task_control.png');
        addTrials('repetition2','control',b, makeControlRows(params, blkSizeCtl), false);
    end

    addScreen('repetition2','break_page.png');
end

%% --- 7) VALIDATION 13–14 (ponecháváme jako schedule trials; samotný běh dělá runValidationTask) ---
addScreen('validation','inst_val.png');

V1 = T;
if hasValGrp && ismember('val_group', V1.Properties.VariableNames)
    V1 = V1(V1.val_group==1 & V1.balanced_set==1,:);
else
    V1 = V1(V1.balanced_set==1,:);
end
V1 = takeN(V1, double(params.nVal13));
addTrials('validation','validation',13, V1, true);

V6 = T;
if hasValGrp && ismember('val_group', V6.Properties.VariableNames)
    V6 = V6(V6.val_group==6 & V6.balanced_set==0,:);
else
    V6 = V6(V6.balanced_set==0,:);
end
V6 = takeN(V6, double(params.nVal14));
addTrials('validation','validation',14, V6, true);

%% --- 8) END ---
addScreen('end','end_page.png');

%% --- 9) přidej volitelné sloupce ---
if hasSR
    master.SR = srVals;         % cellstr
end
if hasValence || hasValGrp
    master.CorrectCat = ccVals; % numeric
end

master = local_ensure_control_blocks(master, params);

local_assert_control_schedule(master, params);

end % ===== main =====



function local_assert_control_schedule(ms, params)
% Fail fast if the schedule contains only practice control trials. This is
% safer than discovering the problem after the experiment is already running.
eventVals = cellfun(@local_cell_char, ms.Event, 'UniformOutput', false);
taskVals  = cellfun(@local_cell_char, ms.Task,  'UniformOutput', false);
isTrial = strcmp(eventVals, 'trial');
isCtl = isTrial & strcmp(taskVals, 'control');

expectedPractice = double(params.nPracticeControl);
expectedPerBlock = double(params.nControlPerBlock);
nCtlStage = double(params.blocksControlPerStage);
n1 = double(params.blocksMain12);
n2 = double(params.blocksMain56);
n3 = double(params.blocksMain9101212);
expectedBlocks = [1:min(nCtlStage,n1), 5:(4+min(nCtlStage,n2)), 9:(8+min(nCtlStage,n3))];
expectedTotal = expectedPractice + expectedPerBlock * numel(expectedBlocks);
actualTotal = nnz(isCtl);

bad = [];
for jj = 1:numel(expectedBlocks)
    b = expectedBlocks(jj);
    actualB = nnz(isCtl & double(ms.Block)==b);
    if actualB ~= expectedPerBlock
        bad = [bad; b actualB]; %#ok<AGROW>
    end
end

if actualTotal ~= expectedTotal || ~isempty(bad)
    detail = '';
    for jj = 1:size(bad,1)
        detail = sprintf('%s block %d=%d;', detail, bad(jj,1), bad(jj,2));
    end
    error('buildScheduleMixEm:InvalidControlSchedule', ...
        ['Invalid control schedule generated by buildScheduleMixEm W540 patch v3: ' ...
         'expected total control=%d, actual=%d. Expected %d control trials in blocks [%s]. Bad:%s'], ...
         expectedTotal, actualTotal, expectedPerBlock, num2str(expectedBlocks), detail);
end
end

function s = local_cell_char(v)
if iscell(v)
    if isempty(v) || isempty(v{1}), s = ''; else, s = char(v{1}); end
else
    s = char(v);
end
end

function ms = local_ensure_control_blocks(ms, params)
% Ensure that every expected non-practice control block is actually present.
% This is a defensive repair for the W540 failure mode where the main task
% blocks are generated but the following control blocks silently disappear.
% Existing correct blocks are left untouched; missing/partial blocks are
% rebuilt and inserted immediately after the corresponding main block.

if isempty(ms) || height(ms)==0
    return
end

expectedPerBlock = double(params.nControlPerBlock);
nCtlStage = double(params.blocksControlPerStage);
n1 = double(params.blocksMain12);
n2 = double(params.blocksMain56);
n3 = double(params.blocksMain9101212);

blockList = [1:min(nCtlStage,n1), 5:(4+min(nCtlStage,n2)), 9:(8+min(nCtlStage,n3))];
phaseList = [repmat({'test'}, 1, min(nCtlStage,n1)), ...
             repmat({'supplemental'}, 1, min(nCtlStage,n2)), ...
             repmat({'repetition2'}, 1, min(nCtlStage,n3))];

changed = false;
for jj = 1:numel(blockList)
    b = blockList(jj);
    ph = phaseList{jj};

    [eventVals, taskVals, phaseVals, pngVals] = local_schedule_strings(ms);
    isCtlTrialThis = strcmp(eventVals,'trial') & strcmp(taskVals,'control') & ...
                     strcmp(phaseVals, ph) & double(ms.Block)==b;
    if nnz(isCtlTrialThis) == expectedPerBlock
        continue
    end

    fprintf('buildScheduleMixEm W540 patch v3: repairing control block %d (%s), existing control trials=%d, expected=%d\n', ...
        b, ph, nnz(isCtlTrialThis), expectedPerBlock);

    % Remove partial control trials for this block, if any.
    if any(isCtlTrialThis)
        ms(isCtlTrialThis,:) = [];
    end

    % Recompute strings after deletion.
    [eventVals, taskVals, phaseVals, pngVals] = local_schedule_strings(ms);

    % Find the end of the corresponding main block.
    mainIdx = find(strcmp(eventVals,'trial') & strcmp(taskVals,'main') & ...
                   strcmp(phaseVals, ph) & double(ms.Block)==b);
    if isempty(mainIdx)
        warning('buildScheduleMixEm:CannotRepairControlBlock', ...
            'Cannot insert control block %d (%s): corresponding main trials not found.', b, ph);
        continue
    end
    mainEnd = max(mainIdx);

    % Remove any stale task_control screen(s) between mainEnd and the next
    % non-control screen. Then insert the fresh task_control screen + trials
    % just before the break/next-section screen.
    nextNonCtlScreenRel = find(strcmp(eventVals(mainEnd+1:end),'screen') & ...
                               ~strcmp(pngVals(mainEnd+1:end),'task_control.png'), 1, 'first');
    if isempty(nextNonCtlScreenRel)
        insertBefore = height(ms) + 1;
    else
        insertBefore = mainEnd + nextNonCtlScreenRel;
    end

    if insertBefore > mainEnd + 1
        seg = (mainEnd+1):(insertBefore-1);
        rmStale = strcmp(eventVals(seg),'trial') & strcmp(taskVals(seg),'control');
        rmStale = rmStale | (strcmp(eventVals(seg),'screen') & strcmp(pngVals(seg),'task_control.png'));
        if any(rmStale)
            rmAbs = seg(rmStale);
            ms(rmAbs,:) = [];
            % Recompute insertion position after removing stale rows.
            [eventVals, taskVals, phaseVals, pngVals] = local_schedule_strings(ms); %#ok<ASGLU>
            mainIdx = find(strcmp(eventVals,'trial') & strcmp(taskVals,'main') & ...
                           strcmp(phaseVals, ph) & double(ms.Block)==b);
            mainEnd = max(mainIdx);
            nextNonCtlScreenRel = find(strcmp(eventVals(mainEnd+1:end),'screen') & ...
                                       ~strcmp(pngVals(mainEnd+1:end),'task_control.png'), 1, 'first');
            if isempty(nextNonCtlScreenRel)
                insertBefore = height(ms) + 1;
            else
                insertBefore = mainEnd + nextNonCtlScreenRel;
            end
        end
    end

    newRows = local_make_control_master_rows(ms, params, ph, b, expectedPerBlock);
    if insertBefore <= height(ms)
        ms = [ms(1:insertBefore-1,:); newRows; ms(insertBefore:end,:)]; %#ok<AGROW>
    else
        ms = [ms; newRows]; %#ok<AGROW>
    end
    changed = true;
end

if changed
    ms.Seq = (1:height(ms))';
end
end

function rows = local_make_control_master_rows(template, params, phaseName, blockNum, nTrials)
ctrl = makeControlRows(params, nTrials);
rows = local_empty_like_schedule(template, height(ctrl)+1);

% Screen row: task_control prompt immediately before the rebuilt control block.
rows.Seq(1) = NaN;
rows.Phase{1} = char(phaseName);
rows.Event{1} = 'screen';
rows.Task{1} = 'screen';
rows.Block(1) = 0;
rows.TrialInBlock(1) = 0;
rows.Modality{1} = '';
rows.StimPath{1} = '';
rows.Dur_ms(1) = 0;
rows.Prompt{1} = '';
rows.PNG{1} = 'task_control.png';
if ismember('SR', rows.Properties.VariableNames), rows.SR{1} = ''; end
if ismember('CorrectCat', rows.Properties.VariableNames), rows.CorrectCat(1) = NaN; end

for ii = 1:height(ctrl)
    rr = ii + 1;
    r = ctrl(ii,:);
    rows.Seq(rr) = NaN;
    rows.Phase{rr} = char(phaseName);
    rows.Event{rr} = 'trial';
    rows.Task{rr} = 'control';
    rows.Block(rr) = double(blockNum);
    rows.TrialInBlock(rr) = double(ii);
    rows.Modality{rr} = char(getCellScalar(r.modality));
    rows.StimPath{rr} = char(resolvePath(params, r));
    rows.Dur_ms(rr) = NaN;
    rows.Prompt{rr} = 'control_1_2_3';
    rows.PNG{rr} = '';
    if ismember('SR', rows.Properties.VariableNames), rows.SR{rr} = 'na'; end
    if ismember('CorrectCat', rows.Properties.VariableNames), rows.CorrectCat(rr) = NaN; end
end
end

function rows = local_empty_like_schedule(template, nRows)
vars = template.Properties.VariableNames;
rows = table();
for kk = 1:numel(vars)
    v = vars{kk};
    switch v
        case {'Seq','Block','TrialInBlock','Dur_ms','CorrectCat'}
            rows.(v) = nan(nRows,1);
        otherwise
            rows.(v) = cell(nRows,1);
    end
end
rows = rows(:, vars);
end

function [eventVals, taskVals, phaseVals, pngVals] = local_schedule_strings(ms)
eventVals = cellfun(@local_cell_char, ms.Event, 'UniformOutput', false);
taskVals  = cellfun(@local_cell_char, ms.Task,  'UniformOutput', false);
phaseVals = cellfun(@local_cell_char, ms.Phase, 'UniformOutput', false);
pngVals   = cellfun(@local_cell_char, ms.PNG,   'UniformOutput', false);
end

%% ===== helpers =====

function x = toDouble(x)
if isnumeric(x), return; end
x = double(str2double(cellstr(x)));
end

function Rows = takeN(TT, N)
N = min(N, height(TT));
if N==0
    Rows = TT([],:);
else
    Rows = TT(randperm(height(TT), N), :);
end
end

function TT = assignBlocksSample(TT, blockNums, blkSize)
% Náhodně vybere až blkSize*numel(blockNums) řádků a přiřadí TT.Block podle pořadí.
nWant = blkSize * numel(blockNums);
TT = takeN(TT, nWant);

if height(TT)==0
    TT.Block = zeros(0,1);
    return
end

n = height(TT);
idxBlock = ceil((1:n)' / blkSize);
idxBlock(idxBlock > numel(blockNums)) = numel(blockNums);
TT.Block = blockNums(idxBlock)';
end

function Rows = makePracticeRows(params, nAud, nVis)
% Practice:
% aud: Stimuli/MAV_MEB_practice/*.wav  -> actual audio duration
% vis: Stimuli/OASIS_practice/*.jpg    -> jittered by runner (Dur_ms = NaN)

prA = dir(fullfile(params.stimDir,'MAV_MEB_practice','*.wav'));
prV = dir(fullfile(params.stimDir,'OASIS_practice','*.jpg'));

na = min(nAud, numel(prA));
nv = min(nVis, numel(prV));

if na > 0, prA = prA(randperm(numel(prA), na)); else, prA = prA([]); end
if nv > 0, prV = prV(randperm(numel(prV), nv)); else, prV = prV([]); end

Rows = table('Size',[0 3], ...
    'VariableTypes', {'cell','cell','double'}, ...
    'VariableNames', {'filename','modality','duration_ms'});

for k = 1:numel(prA)
    d = prA(k);
    f = fullfile(d.folder, d.name);
    Rows = [Rows; {char(d.name), 'aud', local_audio_ms(f)}]; %#ok<AGROW>
end

for k = 1:numel(prV)
    d = prV(k);
    Rows = [Rows; {char(d.name), 'vis', NaN}]; %#ok<AGROW>
end

if height(Rows)>1
    Rows = Rows(randperm(height(Rows)),:);
end
end

function Rows = makeControlRows(params, N)
% Control stimuli:
% aud: Stimuli/control_stimuli/control_tone_*.wav
% vis: Stimuli/control_stimuli/control_grey_*.png
%
% There are only three physical files per modality. The experiment needs
% N trials, therefore we sample WITH replacement while keeping an
% approximately 50/50 aud/vis split and avoiding immediate repetition of
% the identical file. The actual stimulus duration is jittered by the
% runner (300--3600 ms), so Dur_ms is stored as NaN in the schedule.

N = max(0, round(double(N)));
ctrlAud = dir(fullfile(params.stimDir,'control_stimuli','control_tone_*.wav'));
ctrlVis = dir(fullfile(params.stimDir,'control_stimuli','control_grey_*.png'));

Rows = table('Size',[0 3], ...
    'VariableTypes', {'cell','cell','double'}, ...
    'VariableNames', {'filename','modality','duration_ms'});

if N==0
    return
end
if isempty(ctrlAud) && isempty(ctrlVis)
    error('buildScheduleMixEm:NoControlStimuli', ...
        'No control stimuli found in %s', fullfile(params.stimDir,'control_stimuli'));
end

% target counts: 50/50 when both modalities exist
if isempty(ctrlAud)
    nAud = 0; nVis = N;
elseif isempty(ctrlVis)
    nAud = N; nVis = 0;
else
    nAud = floor(N/2);
    nVis = N - nAud;
end

items = table('Size',[0 3], ...
    'VariableTypes', {'cell','cell','double'}, ...
    'VariableNames', {'filename','modality','duration_ms'});

for i = 1:nAud
    d = ctrlAud(1 + mod(i-1, numel(ctrlAud)));
    items = [items; {char(d.name), 'aud', NaN}]; %#ok<AGROW>
end
for i = 1:nVis
    d = ctrlVis(1 + mod(i-1, numel(ctrlVis)));
    items = [items; {char(d.name), 'vis', NaN}]; %#ok<AGROW>
end

% Pre-shuffle, then greedily build an order without immediate same-file repeats.
if height(items)>1
    items = items(randperm(height(items)),:);
end
used = false(height(items),1);
lastName = '';
for k = 1:height(items)
    cand = find(~used);
    if ~isempty(lastName)
        names = cellfun(@char, items.filename(cand), 'UniformOutput', false);
        ok = ~strcmp(names, lastName);
        if any(ok)
            cand = cand(ok);
        end
    end
    pick = cand(randi(numel(cand)));
    Rows = [Rows; items(pick,:)]; %#ok<AGROW>
    used(pick) = true;
    lastName = char(items.filename{pick});
end
end

function ms = local_audio_ms(wavPath)
ms = NaN;
try
    info = audioinfo(wavPath);
    ms = 1000 * double(info.Duration);
catch
end
end

function p = resolvePath(params, r)
% Mapuje filename+modality na fyzickou cestu ve Stimuli.
% Robustní: normalizace modality + fallback podle přípony.
% Podporuje: practice, selections, *_other, control, OASIS* search.

fn = char(getCellScalar(r.filename));

mod = '';
if ismember('modality', r.Properties.VariableNames)
    try
        mod = lower(strtrim(char(getCellScalar(r.modality))));
    catch
        mod = '';
    end
end

[~,~,ext] = fileparts(fn);
ext = lower(ext);

isAud = any(strcmp(mod, {'aud','audio','auditory'})) || any(strcmp(ext,{'.wav','.mp3','.flac'}));
isVis = any(strcmp(mod, {'vis','visual','image'}))   || any(strcmp(ext,{'.png','.jpg','.jpeg','.bmp'}));
if ~isAud && ~isVis
    isAud = any(strcmp(ext,{'.wav','.mp3','.flac'}));
    isVis = ~isAud;
end

if isAud
    cand = { ...
        fullfile(params.stimDir,'MAV_MEB_practice',fn), ...
        fullfile(params.stimDir,'MAV_vocal_selection',fn), ...
        fullfile(params.stimDir,'MEB_musical_selection',fn), ...
        fullfile(params.stimDir,'MAV_vocal_other',fn), ...
        fullfile(params.stimDir,'MEB_musical_other',fn), ...
        fullfile(params.stimDir,'control_stimuli',fn) ...
    };

    for i = 1:numel(cand)
        if exist(cand{i},'file') == 2
            p = cand{i};
            return
        end
    end
    p = cand{end};

else
    cand = { ...
        fullfile(params.stimDir,'OASIS_practice',fn), ...
        fullfile(params.stimDir,'OASIS_person_selection',fn), ...
        fullfile(params.stimDir,'OASIS_os_selection',fn), ...
        fullfile(params.stimDir,'OASIS_person_other',fn), ...
        fullfile(params.stimDir,'OASIS_os_other',fn), ...
        fullfile(params.stimDir,'OASIS_other',fn), ...
        fullfile(params.stimDir,'control_stimuli',fn) ...
    };

    for i = 1:numel(cand)
        if exist(cand{i},'file') == 2
            p = cand{i};
            return
        end
    end

    % fallback: projdi všechny OASIS* podsložky
    p2 = local_find_in_oasis(params.stimDir, fn);
    if ~isempty(p2)
        p = p2;
        return
    end

    p = cand{end};
end
end

function out = ifelse(cond,a,b)
if cond, out=a; else, out=b; end
end

function v = getCellScalar(x)
if iscell(x)
    if isempty(x), v = ''; else, v = x{1}; end
else
    v = x;
end
end

function mods = normalizeModalityCell(mods)
% Převod různých zápisů modality na 'aud' nebo 'vis'
for i = 1:numel(mods)
    if isempty(mods{i})
        mods{i} = '';
        continue
    end
    m = lower(strtrim(mods{i}));
    if any(strcmp(m, {'aud','audio','auditory','sound','snd'}))
        mods{i} = 'aud';
    elseif any(strcmp(m, {'vis','visual','image','img','picture','pic'}))
        mods{i} = 'vis';
    else
        mods{i} = m;
    end
end
end

function p = local_find_in_oasis(stimDir, fn)
% Hledá soubor 'fn' v podsložkách Stimuli, které začínají na "OASIS".
p = '';
try
    dd = dir(stimDir);
    dd = dd([dd.isdir]);
    names = {dd.name};
    names = names(~ismember(names,{'.','..'}));
    for i = 1:numel(names)
        if startsWith(names{i}, 'OASIS')
            cand = fullfile(stimDir, names{i}, fn);
            if exist(cand,'file') == 2
                p = cand;
                return
            end
        end
    end
catch
end
end