function runExperiment()
    %% 0) Startup — reset, sync, PTB, audio, joystick
    clearvars; clc;

    % Close any previous audio / parallel-port sessions if left open
    try PsychPortAudio('Close'); catch, end

    % Optional: ppdev-mex for parallel/USB sync (keeps MusEm habit)
    addpath('./ppdev-mex/');
    try
        ppdev_mex('CloseAll');
    catch
    end

    % Initialize sync box (parallel/USB). Safe if not present.
    params.sync = utils.initSyncDevice();
    utils.syncTriggerOff(params.sync);

    % Psychtoolbox sane defaults
    PsychDefaultSetup(2);
    Screen('Preference','SkipSyncTests', 1);   % set 0 on lab machine
    InitializePsychSound(1);                    % high precision
    rng('shuffle');

    % Try to open joystick #1 (optional)
    if exist('vrjoystick','file')
        try
            params.joy = vrjoystick(1);
            fprintf('Gamepad detected: using joystick #1.\n');
        catch
            params.joy = [];
            warning('vrjoystick found but failed to open. No gamepad input.');
        end
    else
        params.joy = [];
        warning('vrjoystick function not found. Gamepad disabled.');
    end

    %% 1) Subject + Paths + Resume logic (MusEm‑style)
    params.subjID   = subject.ensure_subject();
    baseDir         = fileparts(pwd);
    params.pngDir   = fullfile(baseDir,'PNG');
    params.stimRoot = fullfile(baseDir,'Stimuli');
    params.resultsDir = fullfile(baseDir,'Results');
    if ~exist(params.resultsDir,'dir'), mkdir(params.resultsDir); end
    params.dataFile = fullfile(params.resultsDir, sprintf('%s.mat', params.subjID));

    % Config (JSON) — timing, keys, counts
    cfg = utils.loadConfig();
    params.cfg = cfg;

    % Resume?
    resume = false;
    wantResume = 0;
    if exist(params.dataFile,'file')
        data = load(params.dataFile);
        if isfield(data,'params') && isfield(data.params,'masterSchedule') && isfield(data.params,'resultsTable')
            wantResume = 1;
        end
        if wantResume
            choice = input('Výsledky existují. Pokračovat [C] nebo Restart [R]? ','s');
            if upper(choice)=='C'
                params = data.params;   % use previous params (includes masterSchedule/resultsTable)
                resume = true;
            else
                delete(params.dataFile);
                resume = false;
            end
        else
            warning('Soubor %s postrádá klíčové proměnné. Začínám znovu.', params.dataFile);
            delete(params.dataFile);
            resume = false;
        end
    end

    % Extract numeric ID → counterbalancing helper (like MusEm)
    tokens = regexp(params.subjID,'(\d+)$','tokens','once');
    if ~isempty(tokens); idNum = str2double(tokens{1}); else; idNum = sum(double(params.subjID)); end
    isOddID  = mod(idNum,2)==1;

    %% 2) Master schedule (generate once, save in params) — MixEm design
    % Phases: main1 (1–4), supplemental (5–8), main2 (9–12), validation (13–14)
    if ~resume
        % Build from Stimuli/index and config; fixed order per subject
        params.masterSchedule = subject.ensure_schedule(params.subjID, 'all_phases', params.stimRoot, cfg);

        % Pre-create unified results table (append rows as we go)
        params.resultsTable = utils.makeResultsTable();
    end

    %% 3) Open window & audio I/O
    [params.win, params.winRect] = PsychImaging('OpenWindow', max(Screen('Screens')), 0);
    Screen('TextSize', params.win, 24);
    HideCursor; Priority(MaxPriority(params.win));

    % Output device (playback); Input device (mic) optional
    params.samplerate = 44100;
    try
        params.pahandle = PsychPortAudio('Open', [], 1, 0, params.samplerate, 2);
    catch
        warning('PsychPortAudio open (playback) failed. Will use visual only for now.');
        params.pahandle = [];
    end

    %% 4) Run — welcome, volume test, phases
    try
        utils.syncTriggerOff(params.sync); WaitSecs(0.5);
        utils.sendSubjectVersion(params); % optional no‑op stub

        params.debugClickable = false;
        if ~resume
            screens.showWelcomeScreen(params);
            screens.testVolumeTask(params);
        end

        % MAIN PHASES — interleaved control inside runMainPhase
        params = tasks.runMainPhase(params, 'main1');
        params = tasks.runMainPhase(params, 'supplemental');
        params = tasks.runMainPhase(params, 'main2');

        % VALIDATION
        params = tasks.runValidationTask(params);

        utils.safeSave(params);
    catch ME
        utils.safeSave(params);
        sca; Priority(0); ShowCursor;
        PsychPortAudio('Close');
        rethrow(ME);
    end

    %% 5) Close
    sca; Priority(0); ShowCursor;
    PsychPortAudio('Close');
    fprintf('Done. Data saved: %s\n', params.dataFile);
end
