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

end % ===== main =====


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
% aud: Stimuli/MAV_MEB_practice/*.wav
% vis: Stimuli/OASIS_practice/*.jpg

prA = dir(fullfile(params.stimDir,'MAV_MEB_practice','*.wav'));
prV = dir(fullfile(params.stimDir,'OASIS_practice','*.jpg'));

na = min(nAud, numel(prA));
nv = min(nVis, numel(prV));

if na > 0, prA = prA(randperm(numel(prA), na)); else, prA = prA([]); end
if nv > 0, prV = prV(randperm(numel(prV), nv)); else, prV = prV([]); end

D = [prA(:); prV(:)];

Rows = table('Size',[0 3], ...
    'VariableTypes', {'cell','cell','double'}, ...
    'VariableNames', {'filename','modality','duration_ms'});

for k = 1:numel(D)
    d = D(k);
    nm = char(d.name);
    if isempty(nm), continue; end

    dotPos = find(nm=='.', 1, 'last');
    if isempty(dotPos), ext = ''; else, ext = lower(nm(dotPos:end)); end
    isAud = any(strcmp(ext,{'.wav','.mp3','.flac'}));

    Rows = [Rows; {nm, ifelse(isAud,'aud','vis'), 1000}]; %#ok<AGROW>
end

if height(Rows)>1
    Rows = Rows(randperm(height(Rows)),:);
end
end

function Rows = makeControlRows(params, N)
% Control stimuli:
% aud: Stimuli/control_stimuli/control_tone_*.wav
% vis: Stimuli/control_stimuli/control_grey_*.png

ctrlAud = dir(fullfile(params.stimDir,'control_stimuli','control_tone_*.wav'));
ctrlVis = dir(fullfile(params.stimDir,'control_stimuli','control_grey_*.png'));

na = min(round(N/2), numel(ctrlAud));
nv = min(N - na, numel(ctrlVis));

Rows = table('Size',[0 3], ...
    'VariableTypes', {'cell','cell','double'}, ...
    'VariableNames', {'filename','modality','duration_ms'});

if na>0
    audPick = ctrlAud(randperm(numel(ctrlAud), na));
    for k = 1:numel(audPick)
        d = audPick(k);
        Rows = [Rows; {char(d.name), 'aud', 3600}]; %#ok<AGROW>
    end
end

if nv>0
    visPick = ctrlVis(randperm(numel(ctrlVis), nv));
    for k = 1:numel(visPick)
        d = visPick(k);
        Rows = [Rows; {char(d.name), 'vis', 3600}]; %#ok<AGROW>
    end
end

if height(Rows)>1
    Rows = Rows(randperm(height(Rows)),:);
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