function runExperiment()
%% 0) Startup
clearvars; clc; %#ok<CLSCR>

% Keep this MixEm checkout at the beginning of the MATLAB path. This avoids
% accidentally calling an older +mixem package left on the path from a prior
% session or from another checkout.
baseDir = fileparts(mfilename('fullpath'));
addpath(baseDir, '-begin');
addpath(fullfile(baseDir,'ppdev-mex'), '-begin');
rehash;

% Force MATLAB to reload the schedule generator after a patch/unzip.
try, clear('mixem.buildScheduleMixEm'); catch, end
try, clear('mixem.auditMasterSchedule'); catch, end
try, clear('mixem.runStageFromSchedule'); catch, end
try, clear('mixem.progressMsg'); catch, end

try, PsychPortAudio('Close'); catch, end
try
pyenv('Version','/home/bciadmin/anaconda3/envs/streamdeck39/bin/python', ...
      'ExecutionMode','OutOfProcess');
catch
end

if exist('ppdev_mex','file'), ppdev_mex('CloseAll'); end

params = struct();
params.cleanupDone = false;

% Separate scalar guard for the onCleanup object. On some MATLAB/PTB/Linux
% combinations the onCleanup callback can still attempt a second heavy cleanup
% after a successful run; disarming this guard before normal return prevents
% that post-run hang while keeping error cleanup available during the task.
mixemCleanupArmed = true;

% Keep cleanup active from the beginning. The nested cleanup function reads
% the current params workspace, so it also cleans resources acquired later
% if an error occurs during schedule construction or before the main task.
cleanupObj = onCleanup(@mixem_localCleanup); %#ok<NASGU>

try
    params.sync = mixem.initSyncDevice('Preferred','auto','ParallelPort',1, ...
        'PulseWidth',0.005,'InterPulseGap',0.002,'ResetOnInit',false);
catch MEinit
    % Backward-compatible fallback if MATLAB still has an older
    % initSyncDevice on path/cache. This should not happen after clear/rehash
    % with the cumulative v7 patch, but keeps the experiment start recoverable.
    if contains(MEinit.message, 'ResetOnInit') || contains(MEinit.message, 'recognized parameter')
        warning('initSyncDevice did not accept ResetOnInit; retrying without it. Check path/cache after this run.');
        params.sync = mixem.initSyncDevice('Preferred','auto','ParallelPort',1, ...
            'PulseWidth',0.005,'InterPulseGap',0.002);
        if ~isfield(params.sync,'triggerMode'), params.sync.triggerMode = 'state'; end
        if ~isfield(params.sync,'lastCode'), params.sync.lastCode = []; end
    else
        rethrow(MEinit);
    end
end

params.trig      = mixem.TriggerCodes();
params.trigTable = mixem.makeTriggerCodesTable();  % pro export/inspekci

PsychDefaultSetup(2);
Screen('Preference','SkipSyncTests',1);
InitializePsychSound(1);
rng('shuffle');

% --- pick presentation screen (externí, pokud existuje) ---
allScreens   = Screen('Screens');
presentScr   = max(allScreens);
bgColor      = 0;

Screen('Preference','VisualDebuglevel', 1);
Screen('Preference','Verbosity', 2);

PsychImaging('PrepareConfiguration');

[params.win, params.winRect] = PsychImaging('OpenWindow', presentScr, bgColor);
HideCursor;
Priority(MaxPriority(params.win));

% Text velikost podle výšky okna (škáluje s rozlišením)
winH = RectHeight(params.winRect);
Screen('TextSize', params.win, round(0.04*winH));
Screen('TextFont', params.win, 'Arial');

% --- Timing base (PTB high-res clock) ---
% Pozn.: GetSecs je "absolutní" jen v rámci běhu PTB/MATLAB; pro globální absolutno logujeme i epoch time.
Screen('Flip', params.win);                 % warm-up flip (stabilizuje první timestamp)
params.tExpStartAbs = GetSecs;              % PTB absolutní čas (double)
params.startWallClock = datetime('now');    % čitelné metadata
params.startWallClockEpoch = posixtime(params.startWallClock); % globální absolutno (double, s od 1970)
params.getsecs_minus_epoch = params.tExpStartAbs - params.startWallClockEpoch; % diagnostika/bridge

%% 1) Subject + Paths + Resume
params.subjID = input('Zadejte ID participanta: ','s');

% baseDir defined at startup and kept at path beginning.
params.pngDir     = fullfile(baseDir,'PNG');
params.stimDir    = fullfile(baseDir,'Stimuli');
params.resultsDir = fullfile(baseDir,'Results'); if ~exist(params.resultsDir,'dir'), mkdir(params.resultsDir); end

% --- Main MAT results file (legacy behavior) ---
params.dataFile   = fullfile(params.resultsDir, sprintf('%s.mat',params.subjID));

% --- NEW: session-stamped log identity (stable even if resume) ---
% Example: SUBJ_20260224_134501
params.sessionStamp = char(datetime(params.startWallClock,'Format','yyyyMMdd_HHmmss'));
params.sessionID    = sprintf('%s_%s', params.subjID, params.sessionStamp);

% --- NEW: log file paths ---
params.logDir = fullfile(params.resultsDir,'Logs');
if ~exist(params.logDir,'dir'), mkdir(params.logDir); end

params.logFileTxt = fullfile(params.logDir, sprintf('%s_log.txt', params.sessionID));
params.logFileMat = fullfile(params.logDir, sprintf('%s_log.mat', params.sessionID));
params.logFileCSV = fullfile(params.logDir, sprintf('%s_triglog.csv', params.sessionID)); % trigger log export

% --- NEW: open log file (append) + header ---
params.logFID = fopen(params.logFileTxt,'a');
if params.logFID < 0
    warning('Cannot open log file for writing: %s', params.logFileTxt);
else
    fprintf(params.logFID, '==== MixEm run start ====\n');
    fprintf(params.logFID, 'sessionID: %s\n', params.sessionID);
    fprintf(params.logFID, 'subjID: %s\n', params.subjID);
    fprintf(params.logFID, 'startWallClock: %s\n', char(params.startWallClock));
    fprintf(params.logFID, 'startWallClockEpoch: %.6f\n', params.startWallClockEpoch);
    fprintf(params.logFID, 'tExpStartAbs(GetSecs): %.6f\n', params.tExpStartAbs);
    fprintf(params.logFID, 'getsecs_minus_epoch: %.6f\n', params.getsecs_minus_epoch);
    if isfield(params,'sync') && isfield(params.sync,'mode')
        fprintf(params.logFID, 'sync.mode: %s\n', char(string(params.sync.mode)));
    end
    if isfield(params,'sync') && isfield(params.sync,'info')
        fprintf(params.logFID, 'sync.info: %s\n', char(string(params.sync.info)));
    end
    fprintf(params.logFID, 'pulseWidth: %.6f\n', params.sync.pulseWidth);
    fprintf(params.logFID, 'interPulseGap: %.6f\n', params.sync.interPulseGap);
    fprintf(params.logFID, 'triggerVersion: %s\n', char(string(params.trig.Version)));
    fprintf(params.logFID, '-------------------------\n');
end

% --- NEW: init trigger event log (if not present) ---
% Keep inside params so it gets saved with safeSave as well.
if ~isfield(params,'trigLog') || isempty(params.trigLog)
    params.trigLog = table('Size',[0 10], ...
        'VariableTypes', {'double','double','double','string','double','string','double','double','double','double'}, ...
        'VariableNames', {'WallClockEpoch_On','WallClockEpoch_Off','GetSecs_On','Name','Code','Note','Seq','Block','Trial','TrialInBlock'});
end

% --- NEW: helper inline logger (anonymous function) ---
% Usage: logMsg('text');  (prepends timestamps)
logMsg = @(msg) mixem_localLog(params, msg); %#ok<NASGU>

params.stimXlsx   = fullfile(baseDir,'data','mixem_reunified_stimuli_19_9_2025.xlsx');

% % Task sizes & counts (editable)
% params.nPracticeMain    = 2;
% params.nPracticeControl = 2;
% params.blocksMain12     = 2;
% params.blocksMain56     = 2;
% params.blocksMain9101212= 2;
% params.blocksControlPerStage = 2;
% params.nMainPerBlock = 2;
% params.nControlPerBlock = 2;
% params.nVal13 = 3;
% params.nVal14 = 3;

% Task sizes & counts (editable)
params.nPracticeMain    = 20;
params.nPracticeControl = 20;
params.blocksMain12     = 4;
params.blocksMain56     = 4;
params.blocksMain9101212= 4;
params.blocksControlPerStage = 4;
params.nMainPerBlock = 40;
params.nControlPerBlock = 20;

% Validation: current agreed short version keeps block 13
% (32 main stimuli) and skips block 14 (36 supplemental stimuli).
% Set params.nVal14 = 36 to restore the full validation task.
params.nVal13 = 32;
params.nVal14 = 0;

% Resume detection
resume = false; wantResume = 0;
if exist(params.dataFile,'file')
    data = load(params.dataFile);
    if isfield(data,'params') && isfield(data.params,'masterSchedule') && isfield(data.params,'resultsTable')
        wantResume = 1;
    end
    if wantResume
        choice = input('Výsledky existují. Pokračovat [C] nebo Restart [R]? ','s');
        if ~isempty(choice) && upper(choice)=='C'
            % IMPORTANT:
            % zachovat načtený params (včetně výsledků) a jen doplnit runtime-only věci (okno, audio, deck) níže
            loaded = data.params;
            % Přeneseme runtime proměnné z aktuální session (window, timing metadata) do loaded,
            % ale NEpřepisujeme historická data jako resultsTable apod.
            loaded.win     = params.win;
            loaded.winRect = params.winRect;

            % --- NEW: preserve current runtime-only handles/paths ---
            % A saved MAT file may contain stale handles from a previous MATLAB
            % process.  On resume, always use the newly opened window/log/sync
            % objects from the current session, while keeping the saved schedule
            % and behavioral results.
            loaded.resultsDir       = params.resultsDir;
            loaded.logDir           = params.logDir;
            loaded.sessionStamp     = params.sessionStamp;
            loaded.sessionID        = params.sessionID;
            loaded.logFileTxt       = params.logFileTxt;
            loaded.logFileMat       = params.logFileMat;
            loaded.logFileCSV       = params.logFileCSV;
            loaded.logFID           = params.logFID;
            loaded.sync             = params.sync;
            loaded.trig             = mixem.TriggerCodes();
            loaded.trigAlt          = mixem.TriggerAltCodes();
            loaded.trigTable        = mixem.makeTriggerCodesTable();
            if isfield(loaded,'lastTrigPhysicalCode'), loaded = rmfield(loaded,'lastTrigPhysicalCode'); end
            if isfield(loaded,'lastTrigLogicalName'),  loaded = rmfield(loaded,'lastTrigLogicalName');  end
            if isfield(loaded,'lastTrigLogicalCode'),  loaded = rmfield(loaded,'lastTrigLogicalCode');  end

            % pokud v uloženém params chybí timebase metadata, doplnit (legacy files)
            if ~isfield(loaded,'tExpStartAbs') || isempty(loaded.tExpStartAbs)
                loaded.tExpStartAbs = params.tExpStartAbs;
            end
            if ~isfield(loaded,'startWallClock') || isempty(loaded.startWallClock)
                loaded.startWallClock = params.startWallClock;
            end
            if ~isfield(loaded,'startWallClockEpoch') || isempty(loaded.startWallClockEpoch)
                loaded.startWallClockEpoch = params.startWallClockEpoch;
            end
            if ~isfield(loaded,'getsecs_minus_epoch') || isempty(loaded.getsecs_minus_epoch)
                loaded.getsecs_minus_epoch = params.getsecs_minus_epoch;
            end

            params = loaded; %#ok<NASGU>
            resume = true;

            % NEW: resume note
            mixem_localLog(params, 'RESUME: continuing from existing dataFile.');
        else
            delete(data.params.dataFile);
            resume = false;
            mixem_localLog(params, 'RESTART: existing dataFile deleted.');
        end
    else
        warning('Soubor existuje, ale chybí potřebné proměnné. Začínám znovu.');
        delete(params.dataFile);
        mixem_localLog(params, 'WARNING: legacy/broken dataFile deleted; starting new.');
    end
end

% Resume bookkeeping. New runs start from the beginning; resumed runs keep
% the stored masterSchedule order and skip rows completed in an earlier session.
params.resumeActive = logical(resume);
if ~isfield(params,'lastCompletedSeq') || isempty(params.lastCompletedSeq) || ~isnumeric(params.lastCompletedSeq)
    if resume && isfield(params,'currentSeq') && ~isempty(params.currentSeq) && isnumeric(params.currentSeq)
        params.lastCompletedSeq = double(params.currentSeq);
    else
        params.lastCompletedSeq = 0;
    end
end

% Deterministic RNG per subj for stable schedules
params.idNum = mixem.rngFromSubjID(params.subjID);
rng(params.idNum,'twister');

%% 2) Build master schedule (if not resuming)
if ~resume
    fprintf('MixEm code path: runExperiment=%s\n', mfilename('fullpath'));
    fprintf('MixEm code path: buildSchedule=%s\n', which('mixem.buildScheduleMixEm'));
    fprintf('MixEm code path: auditSchedule=%s\n', which('mixem.auditMasterSchedule'));

    params.masterSchedule = mixem.buildScheduleMixEm(params);
    params.currTrial = 1;
    params.lastCompletedSeq = 0;

    try
        mixem.auditMasterSchedule(params.masterSchedule, params);
        mixem_localAssertSchedule(params.masterSchedule, params);
    catch ME
        error('runExperiment:BadSchedule', 'Schedule audit failed / invalid schedule: %s', ME.message);
    end

    % Unified results table (ABSOLUTNÍ ČASY)
    % - Onset*/Offset*/TrialEnd jsou v GetSecs jednotkách (double)
    % - WallClockEpoch* jsou globální absolutní sekundy (POSIX epoch, double)
    varNames = {'SubjID','Task','Block','TrialInBlock','Modality','SR','StimPath','Dur_ms',...
                'Prompt','CorrectCat','RespKey','Resp','RT_ms',...
                'OnsetFix','OnsetStim','OffsetStim','OnsetPrompt1','OnsetPrompt2','OnsetRating','TrialEnd',...
                'WallClockEpoch_TrialEnd'};

    varTypes = {'string','string','double','double','string','string','string','double',...
                'string','double','string','string','double',...
                'double','double','double','double','double','double','double',...
                'double'};

    params.resultsTable = table('Size',[0,numel(varNames)],'VariableTypes',varTypes,'VariableNames',varNames);

    mixem_localLog(params, sprintf('Built masterSchedule. n=%d rows.', height(params.masterSchedule)));
else
    mixem_localLog(params, 'Resume: masterSchedule/resultsTable loaded from MAT.');
    try
        mixem.auditMasterSchedule(params.masterSchedule, params);
        mixem_localAssertSchedule(params.masterSchedule, params);
    catch ME
        error('runExperiment:BadScheduleOnResume', ['Loaded resume schedule is invalid: %s\n' ...
            'Start a fresh participant ID or choose Restart so the corrected schedule is generated.'], ME.message);
    end
end

%% 3) Audio + StreamDeck (window already open)
Screen('TextSize', params.win, 24);
HideCursor;
Priority(MaxPriority(params.win));

% Audio out
pah = PsychPortAudio('Open',[],1,0,44100,2);
params.pahandle   = pah;
params.samplerate = 44100;

% Optional back recording of room audio (name below may need adjustment per host)
params.micDeviceName = 'HDA Intel PCH: ALC3232 Analog (hw:1,0)';
try
    params.audioReader = audioDeviceReader('Device',params.micDeviceName,'SampleRate',params.samplerate,'NumChannels',1,'SamplesPerFrame',512); %#ok<NASGU>
catch
    params.audioReader = [];
    warning('audioDeviceReader init failed; back recording disabled.');
    mixem_localLog(params, 'WARNING: audioDeviceReader init failed; back recording disabled.');
end

% StreamDeck init
params.deck = [];
try
    params.deck = mixem.streamdeck_init();
    mixem.deck_show_welcome(params.deck);
catch ME
    warning('StreamDeck init skipped: %s', ME.message);
    mixem_localLog(params, sprintf('WARNING: StreamDeck init skipped: %s', ME.message));
end

% Cleanup is already active from startup via mixem_localCleanup.

%% 4) Run experiment
try
    % MixEm trigger convention: state/step values, no implicit reset-to-zero.
    WaitSecs(0.3);

    % --- NEW: send + log version and session start ---
    params = mixem.sendTrig(params,'SESSION_START');
    params = mixem.sendSubjectVersion(params);
    mixem_localLog(params, sprintf('SESSION_START sent. trigVersion=%s', char(string(params.trig.Version))));

    % ---------- DEBUG ROUTER ----------
    st = getenv('MIXEM_STAGE');
    if isempty(st)
        params.debugStage = 'all';
    else
        params.debugStage = lower(strtrim(st));
    end

    % debug rámečky pro klikání (přepni env MIXEM_DEBUGCLICK=1)
    dc = getenv('MIXEM_DEBUGCLICK');
    params.debugClickable = ~isempty(dc) && any(dc=='1');

    % Console progress is useful during the long full run. Disable with MIXEM_PROGRESS=0.
    progEnv = getenv('MIXEM_PROGRESS');
    if isempty(progEnv)
        params.progressConsole = true;
    else
        params.progressConsole = ~any(strcmpi(strtrim(progEnv), {'0','false','off','no'}));
    end
    mixem_localLog(params, sprintf('debugStage=%s debugClickable=%d progressConsole=%d', params.debugStage, params.debugClickable, params.progressConsole));
    params = mixem.progressMsg(params, 'RUN_START', 'stage', params.debugStage, 'resume', resume);

    % ---------- Non-resume init screens (jen pokud debugStage vyžaduje) ----------
    if ~resume
        switch params.debugStage
            case {'welcome','all','volume','main_practice','control_practice'}
                params = mixem.sendTrig(params,'WELCOME_PAGE_ON');
                src = mixem.waitOnPNG(params, 'welcome_page.png', params.deck, params.debugClickable);
                fprintf('Welcome advanced via: %s\n', src);
                mixem_localLog(params, sprintf('welcome_page advanced via: %s', src));
        end

        switch params.debugStage
            case {'volume','all','main_practice','control_practice'}
                params = mixem.sendTrig(params,'VOLUME_TASK_START');
                mixem.testVolumeTask(params);
                params = mixem.sendTrig(params,'VOLUME_TASK_END');
        end
    end

    % ---------- Execute selected stage ----------
    switch params.debugStage

        case 'welcome'
            return

        case 'volume'
            return

        case 'main_practice'
            params = mixem.sendTrig(params,'MAIN_PRACTICE_START');
            params = mixem.progressMsg(params, 'SECTION_START', 'section', 'main_practice');
            mixem.runMainCondition(params,'practice');
            params = mixem.sendTrig(params,'MAIN_PRACTICE_END');
            return

        case 'control_practice'
            params = mixem.sendTrig(params,'CONTROL_PRACTICE_START');
            params = mixem.progressMsg(params, 'SECTION_START', 'section', 'control_practice');
            mixem.runControlCondition(params,'practice');
            params = mixem.sendTrig(params,'CONTROL_PRACTICE_END');
            return

        case 'test_1_4'
            params = mixem.sendTrig(params,'STAGE_TEST_START');
            params = mixem.progressMsg(params, 'SECTION_START', 'section', 'test_1_4');
            mixem.runStageFromSchedule(params, 'test', 1, 4);
            params = mixem.sendTrig(params,'STAGE_TEST_END');
            return

        case 'supp_5_8'
            params = mixem.sendTrig(params,'STAGE_SUPP_START');
            params = mixem.progressMsg(params, 'SECTION_START', 'section', 'supplemental_5_8');
            mixem.runStageFromSchedule(params, 'supplemental', 5, 8);
            params = mixem.sendTrig(params,'STAGE_SUPP_END');
            return

        case 'rep2_9_12'
            params = mixem.sendTrig(params,'STAGE_REP2_START');
            params = mixem.progressMsg(params, 'SECTION_START', 'section', 'repetition2_9_12');
            mixem.runStageFromSchedule(params, 'repetition2', 9, 12);
            params = mixem.sendTrig(params,'STAGE_REP2_END');
            return

        case 'resume_pages'
            params = mixem.runResumePages(params);
            return

        case 'main_r1'
            mixem.runMainCondition(params,'main_r1');
            return

        case 'control_1_4'
            mixem.runControlCondition(params,'control_1_4');
            return

        case 'supplemental'
            mixem.runMainCondition(params,'supplemental');
            return

        case 'control_5_8'
            mixem.runControlCondition(params,'control_5_8');
            return

        case 'main_r2'
            mixem.runMainCondition(params,'main_r2');
            return

        case 'control_9_12'
            mixem.runControlCondition(params,'control_9_12');
            return

        case 'validation'
            params = mixem.sendTrig(params,'VAL_TASK_START');
            params = mixem.progressMsg(params, 'SECTION_START', 'section', 'validation');
            mixem.runValidationTask(params);
            params = mixem.sendTrig(params,'VAL_TASK_END');
            return

        case 'all'
            if ~resume
                params = mixem.sendTrig(params,'MAIN_PRACTICE_START');
                mixem.runMainCondition(params,'practice');
                params = mixem.sendTrig(params,'MAIN_PRACTICE_END');

                params = mixem.sendTrig(params,'CONTROL_PRACTICE_START');
                mixem.runControlCondition(params,'practice');
                params = mixem.sendTrig(params,'CONTROL_PRACTICE_END');

                params = mixem.sendTrig(params,'TEST_PAGE_ON');
                mixem.showPNG(params,'test_page.png',true);
            end

            params = mixem.sendTrig(params,'STAGE_TEST_START');
            params = mixem.progressMsg(params, 'SECTION_START', 'section', 'test_1_4');
            mixem.runStageFromSchedule(params, 'test', 1, 4);
            params = mixem.sendTrig(params,'STAGE_TEST_END');

            params = mixem.sendTrig(params,'STAGE_SUPP_START');
            params = mixem.progressMsg(params, 'SECTION_START', 'section', 'supplemental_5_8');
            mixem.runStageFromSchedule(params, 'supplemental', 5, 8);
            params = mixem.sendTrig(params,'STAGE_SUPP_END');

            % Long break / resume reminder pages should be shown in a fresh
            % run, or when resuming before repetition2 has actually started.
            % If we resume later (e.g., inside repetition2 or validation), do
            % not force the participant through the long break screens again.
            showResumePages = true;
            if resume
                try
                    firstRep2Seq = mixem_localFirstSeq(params.masterSchedule, 'repetition2');
                    showResumePages = isempty(firstRep2Seq) || double(params.lastCompletedSeq) < double(firstRep2Seq);
                catch
                    showResumePages = true;
                end
            end

            if showResumePages
                params = mixem.sendTrig(params,'LONG_BREAK_PAGE_ON');
                params = mixem.runResumePages(params);
            else
                mixem_localLog(params, 'Resume: skipping long-break/resume pages; already past repetition2 start.');
            end

            params = mixem.sendTrig(params,'STAGE_REP2_START');
            params = mixem.progressMsg(params, 'SECTION_START', 'section', 'repetition2_9_12');
            mixem.runStageFromSchedule(params, 'repetition2', 9, 12);
            params = mixem.sendTrig(params,'STAGE_REP2_END');

            params = mixem.sendTrig(params,'VAL_TASK_START');
            params = mixem.progressMsg(params, 'SECTION_START', 'section', 'validation');
            mixem.runValidationTask(params);
            params = mixem.sendTrig(params,'VAL_TASK_END');

            if isfield(params,'deck') && ~isempty(params.deck)
                try, params.deck = mixem.deck_show_ok(params.deck); catch, end
            end
            params = mixem.sendTrig(params,'END_PAGE_ON');
            mixem.waitOnPNG(params,'end_page.png', params.deck, params.debugClickable);
%             mixem.showPNG(params,'end_page.png',true);

            mixem.safeSave(params);
            mixem_localLog(params, 'safeSave done (end of all).');

        otherwise
            error('Neznámý MIXEM_STAGE/debugStage: %s', params.debugStage);
    end

catch ME
    try
        mixem_localLog(params, sprintf('ERROR: %s', ME.message));
        mixem.safeSave(params);
        params = mixem.augmentResultsWithDatetime(params); %human readable timestamps
        mixem_localLog(params, 'safeSave + augmentResultsWithDatetime done in catch.');
    catch
    end
    sca; Priority(0); ShowCursor; PsychPortAudio('Close');
    rethrow(ME);
end

%% 5) Close
try
    params = mixem.progressMsg(params, 'RUN_DONE');
catch
end
try
    params = mixem.sendTrig(params,'SESSION_END');
catch
end

try, sca; catch, end
try, Priority(0); catch, end
try, ShowCursor; catch, end
try
    if exist('pah','var') && ~isempty(pah)
        PsychPortAudio('Close', pah);
    else
        PsychPortAudio('Close');
    end
catch
end

% --- NEW: export trigLog to CSV + save log snapshot MAT ---
try
    if isfield(params,'trigLog') && ~isempty(params.trigLog)
        writetable(params.trigLog, params.logFileCSV);
        mixem_localLog(params, sprintf('trigLog exported: %s (n=%d)', params.logFileCSV, height(params.trigLog)));
    end
catch ME
    warning('Failed to export trigLog CSV: %s', ME.message);
end

try
    % Save minimal log snapshot (not full params, which is in dataFile already)
    logSnapshot = struct();
    logSnapshot.sessionID = params.sessionID;
    logSnapshot.subjID = params.subjID;
    logSnapshot.startWallClock = params.startWallClock;
    logSnapshot.startWallClockEpoch = params.startWallClockEpoch;
    logSnapshot.tExpStartAbs = params.tExpStartAbs;
    logSnapshot.getsecs_minus_epoch = params.getsecs_minus_epoch;
    logSnapshot.sync = params.sync;
    logSnapshot.trigVersion = string(params.trig.Version);
    logSnapshot.trigTable = params.trigTable;
    logSnapshot.trigLog = params.trigLog;
    save(params.logFileMat, 'logSnapshot');
    mixem_localLog(params, sprintf('log snapshot saved: %s', params.logFileMat));
catch ME
    warning('Failed to save log snapshot MAT: %s', ME.message);
end

mixem.safeSave(params);

% --- NEW: finalize text log ---
try
    mixem_localLog(params, sprintf('Done. Data saved: %s', params.dataFile));
    mixem_localLog(params, '==== MixEm run end ====');
    if isfield(params,'logFID') && ~isempty(params.logFID) && params.logFID > 0
        fclose(params.logFID);
        params.logFID = [];
    end
catch
end

try
    mixem.closeSyncDevice(params.sync);
catch
end

% Normal finalization already closed PTB/audio/sync and the log file. The
% onCleanup guard remains useful for errors, but must not run a second
% heavy cleanup at normal function return, as that can leave MATLAB busy on
% some Ubuntu/PTB/PortAudio combinations. Disarm the cleanup object explicitly
% and then destroy it while the nested callback is known to be a no-op.
params.cleanupDone = true;
mixemCleanupArmed = false;
try
    cleanupObj = [];
catch
end

fprintf('Done. Data saved: %s\n', params.dataFile);

% ---------------------------------------------------------
% Local cleanup helper. Because this is nested, it sees the current
% value of params even if an error occurs before the normal finalization.
% ---------------------------------------------------------
function mixem_localCleanup()
    try
        if exist('mixemCleanupArmed','var') && ~mixemCleanupArmed
            return;
        end
    catch
    end
    try
        if isfield(params,'cleanupDone') && params.cleanupDone
            return;
        end
    catch
    end
    try
        mixem.fullCleanup(params);
    catch
        try, sca; catch, end
        try, PsychPortAudio('Close'); catch, end
        try, Priority(0); catch, end
        try, ShowCursor; catch, end
    end
end

% ---------------------------------------------------------
% Local helper (nested function) for consistent log lines
% ---------------------------------------------------------
function mixem_localLog(paramsLocal, msg)
    try
        if ~isfield(paramsLocal,'logFID') || isempty(paramsLocal.logFID) || paramsLocal.logFID < 0
            return;
        end
        tGS = GetSecs;
        tEpoch = tGS - paramsLocal.getsecs_minus_epoch;
        stamp = char(datetime(tEpoch,'ConvertFrom','posixtime','Format','yyyy-MM-dd HH:mm:ss.SSS'));
        fprintf(paramsLocal.logFID, '[%s] (epoch=%.6f getsecs=%.6f) %s\n', stamp, tEpoch, tGS, char(string(msg)));
    catch
    end
end

function firstSeq = mixem_localFirstSeq(ms, phaseName)
    firstSeq = [];
    try
        if isempty(ms) || height(ms)==0 || ~ismember('Phase', ms.Properties.VariableNames)
            return;
        end
        phaseVals = cellfun(@mixem_localCellChar, ms.Phase, 'UniformOutput', false);
        mask = strcmp(phaseVals, char(phaseName));
        if any(mask)
            firstSeq = min(double(ms.Seq(mask)));
        end
    catch
        firstSeq = [];
    end
end

function s = mixem_localCellChar(v)
    if iscell(v)
        if isempty(v) || isempty(v{1})
            s = '';
        else
            s = char(v{1});
        end
    else
        s = char(v);
    end
end



function mixem_localAssertSchedule(ms, paramsLocal)
    try
        eventVals = cellfun(@mixem_localCellChar, ms.Event, 'UniformOutput', false);
        taskVals  = cellfun(@mixem_localCellChar, ms.Task,  'UniformOutput', false);
        isTrial = strcmp(eventVals, 'trial');
        isCtl = isTrial & strcmp(taskVals, 'control');

        expectedPractice = double(paramsLocal.nPracticeControl);
        expectedPerBlock = double(paramsLocal.nControlPerBlock);
        nCtlStage = double(paramsLocal.blocksControlPerStage);
        n1 = double(paramsLocal.blocksMain12);
        n2 = double(paramsLocal.blocksMain56);
        n3 = double(paramsLocal.blocksMain9101212);
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
            error('MixEm:InvalidControlSchedule', ...
                ['Invalid control schedule: expected total control=%d, actual=%d. ' ...
                 'Expected %d control trials in each block [%s]. Bad:%s ' ...
                 'This usually means MATLAB is using a stale/shadowed buildScheduleMixEm. ' ...
                 'Run: clear functions; rehash; which mixem.buildScheduleMixEm -all'], ...
                 expectedTotal, actualTotal, expectedPerBlock, num2str(expectedBlocks), detail);
        end
    catch ME
        if strcmp(ME.identifier, 'MixEm:InvalidControlSchedule')
            rethrow(ME);
        else
            error('MixEm:ScheduleAssertFailed', 'Could not verify schedule: %s', ME.message);
        end
    end
end


end