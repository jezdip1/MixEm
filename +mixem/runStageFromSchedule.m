function runStageFromSchedule(params, phaseName, blockLo, blockHi)
% RUNSTAGEFROMSCHEDULE
% Vykoná masterSchedule pro danou Phase a bloky (screen + trial dle Seq).

ms = params.masterSchedule;
cellchar = @(v) local_cellchar(v);

isPhase = strcmp(cellfun(cellchar, ms.Phase, 'UniformOutput', false), phaseName);
isScreen = isPhase & strcmp(cellfun(cellchar, ms.Event, 'UniformOutput', false), 'screen');
isTrial = isPhase & strcmp(cellfun(cellchar, ms.Event, 'UniformOutput', false), 'trial') & ...
                 (ms.Block >= blockLo) & (ms.Block <= blockHi);

rows = ms(isScreen | isTrial, :);
if height(rows)==0
    warning('runStageFromSchedule:NoRows','Phase=%s block [%g..%g] -> 0 rows', phaseName, blockLo, blockHi);
    return
end

[~,ord] = sort(rows.Seq);
rows = rows(ord,:);

% True resume: keep the saved randomized order, but skip rows that were
% completed in a previous session. lastCompletedSeq is updated after each
% completed screen/trial.
if isfield(params,'resumeActive') && logical(params.resumeActive) && ...
        isfield(params,'lastCompletedSeq') && ~isempty(params.lastCompletedSeq)
    rows = rows(rows.Seq > double(params.lastCompletedSeq), :);
    if height(rows)==0
        params = mixem.logMsg(params, "STAGE_SKIP_ALREADY_DONE", 'Phase', phaseName, 'blockLo', blockLo, 'blockHi', blockHi);
        assignin('caller','params',params);
        return
    end
end

dbg = false;
if isfield(params,'debugClickable'), dbg = logical(params.debugClickable); end

hasBridge = isfield(params,'getsecs_minus_epoch') && ~isempty(params.getsecs_minus_epoch) ...
         && isnumeric(params.getsecs_minus_epoch) && isfinite(params.getsecs_minus_epoch);

% default: na screenech OK-only
if isfield(params,'deck') && ~isempty(params.deck)
    try, params.deck = mixem.deck_show_ok(params.deck); catch, end
end

params = mixem.logMsg(params, "STAGE_BEGIN", 'Phase', phaseName, 'blockLo', blockLo, 'blockHi', blockHi);
params = mixem.progressMsg(params, 'STAGE_BEGIN', 'phase', phaseName, 'blocks', sprintf('%d-%d', blockLo, blockHi), 'rows', height(rows));

for k = 1:height(rows)
    r = rows(k,:);
    ev = cellchar(r.Event);

    % keep context
    params.currentSeq   = double(r.Seq);
    params.currentBlock = double(r.Block);
    params.currentTrialInBlock = double(r.TrialInBlock);

    if strcmp(ev,'screen')
        png = cellchar(r.PNG);
        if isempty(png), continue; end
        params = mixem.logMsg(params, "SCREEN", 'PNG', png, 'Phase', phaseName);
        params = mixem.progressMsg(params, 'SCREEN', 'phase', phaseName, 'block', double(r.Block), 'seq', double(r.Seq), 'png', png);

        if isfield(params,'deck') && ~isempty(params.deck)
            try, params.deck = mixem.deck_show_ok(params.deck); catch, end
        end
        mixem.waitOnPNG(params, png, params.deck, dbg);
        params.lastCompletedSeq = max(double(getfield_with_default(params,'lastCompletedSeq',0)), double(r.Seq));
        try, mixem.safeSave(params); catch, end
        continue
    end

    % ---------------- trial ----------------
    task     = cellchar(r.Task);        % 'main' nebo 'control'
    modality = local_norm_modality(cellchar(r.Modality));
    stimPath = cellchar(r.StimPath);

    params.currentTask     = string(task);
    params.currentModality = string(modality);
    params.currentStimPath = string(stimPath);

    params = mixem.logMsg(params, "TRIAL_START", 'Phase', phaseName, 'Task', task, 'Modality', modality, 'Stim', stimPath);
    params = mixem.progressMsg(params, 'TRIAL_START', 'phase', phaseName, 'task', task, 'block', double(r.Block), 'trialInBlock', double(r.TrialInBlock), 'modality', modality, 'stim', stimPath);

    if isfield(params,'deck') && ~isempty(params.deck)
        try, params.deck = mixem.deck_show_123(params.deck); catch, end
    end

    % Preserve the historical RNG draw order from the validated May release:
    % fixation jitter is drawn first, then (when applicable) the stimulus
    % timeout jitter. We calculate both before showing fixation so auditory
    % file IO/resampling/FillBuffer can happen outside the timing-critical
    % trigger-to-audio path without changing the randomized sequence.
    fixWait = 2 + rand()*0.5;

    % Timeout logic
    if strcmp(task,'control')
        stimTimeout = 0.3 + rand()*3.3;
        promptName  = 'control_1_2_3';
    else
        promptName  = 'valence_1_2_3';
        dur_ms = double(r.Dur_ms);
        if strcmp(modality,'vis')
            if isnan(dur_ms) || dur_ms<=0
                stimTimeout = 0.3 + rand()*3.3;
            else
                stimTimeout = dur_ms/1000;
            end
        else
            if ~isnan(dur_ms) && dur_ms>0
                stimTimeout = dur_ms/1000;
            else
                stimTimeout = local_audio_duration_sec(stimPath);
                if isnan(stimTimeout) || stimTimeout<=0, stimTimeout = Inf; end
            end
        end
    end

    % Prepare auditory buffer BEFORE fixation so disk IO/resampling/
    % FillBuffer cannot inflate the trigger-to-audio latency. Control tones
    % are truncated to their random planned duration and get a 50 ms
    % half-cosine fade at that exact endpoint.
    audioPrepared = false;
    if strcmp(modality,'aud')
        if strcmp(task,'control')
            audioPrepared = mixem.prepareAudioFile(params, stimPath, ...
                'MaxDurationSec', stimTimeout, 'FadeOutSec', 0.050);
        else
            audioPrepared = mixem.prepareAudioFile(params, stimPath);
        end
    end

    % Fix
    mixem.showPNG(params,'fix_cross.png',false);
    tFixOn = Screen('Flip', params.win);
    params = mixem.sendTrig(params,'FIX_ON');
    WaitSecs(fixWait);

    % init stamps
    tStimOn    = NaN;
    tStimOff   = NaN;
    tAudOn     = NaN;
    tPrompt1On = NaN;
    tPrompt2On = NaN;

    respKey  = '';
    resp     = NaN;
    rt_ms    = NaN;
    tRespAbs = NaN;

    sentRespTrig = false;

    % Stimulus + response
    if strcmp(modality,'aud')
        mixem.showPNG(params,'stim_aud.png',false);
        tStimOn = Screen('Flip', params.win);
        params = mixem.sendTrig(params,'STIM_ON_AUD');

        tTrigAud = local_last_trig_getsecs(params);
        if audioPrepared
            tAudOn = mixem.startPreparedAudio(params);
        else
            tAudOn = NaN;
        end
        trigToAudio_ms = NaN;
        if isfinite(tTrigAud) && isfinite(tAudOn)
            trigToAudio_ms = 1000*(tAudOn - tTrigAud);
        end
        if strcmp(task,'control')
            params = mixem.logMsg(params, "AUDIO_START", 'File', stimPath, 'tAudOn_GetSecs', tAudOn, ...
                'trigToAudio_ms', trigToAudio_ms, 'plannedDur_ms', 1000*stimTimeout, 'plannedFadeOut_ms', 50);
        else
            params = mixem.logMsg(params, "AUDIO_START", 'File', stimPath, ...
                'tAudOn_GetSecs', tAudOn, 'trigToAudio_ms', trigToAudio_ms);
        end

        [respKey, resp, ~, tRespAbs] = mixem.collectResponse123(params, params.deck, stimTimeout, struct());
        if ~isempty(respKey) && ~sentRespTrig
            params = mixem.sendTrig(params,'RESP_KEYPRESS','note',respKey);
            sentRespTrig = true;
            params = mixem.logMsg(params, "RESP", 'respKey', respKey, 'resp', resp, 'tResp_GetSecs', tRespAbs);
        end

        % Control tones have a clean planned fade at timeout; only an EARLY
        % response needs a runtime 50 ms fade. Main auditory stimuli keep the
        % historical immediate-stop behavior.
        if strcmp(task,'control') && ~isempty(respKey)
            fadeSec = 0.050;
            if isfinite(tAudOn) && isfinite(tRespAbs)
                fadeSec = min(fadeSec, max(0, (tAudOn + stimTimeout) - tRespAbs));
            end
            tStimOff = mixem.stopAudio(params, fadeSec);
        else
            tStimOff = mixem.stopAudio(params, 0);
        end

        tRef = tStimOn;
        if isfinite(tAudOn), tRef = tAudOn; end
        if isfinite(tRespAbs), rt_ms = 1000*(tRespAbs - tRef); end

    else
        tStimOn = mixem.showImageCentered(params, stimPath, 500, 400);
        params = mixem.logMsg(params, "VIS_ON", 'File', stimPath, 'tOn_GetSecs', tStimOn);
        params = mixem.sendTrig(params,'STIM_ON_VIS');

        [respKey, resp, ~, tRespAbs] = mixem.collectResponse123(params, params.deck, stimTimeout, struct());
        if ~isempty(respKey) && ~sentRespTrig
            params = mixem.sendTrig(params,'RESP_KEYPRESS','note',respKey);
            sentRespTrig = true;
            params = mixem.logMsg(params, "RESP", 'respKey', respKey, 'resp', resp, 'tResp_GetSecs', tRespAbs);
        end
        if isfinite(tRespAbs), rt_ms = 1000*(tRespAbs - tStimOn); end

        % If the participant responded while the image was still visible,
        % remove it immediately instead of leaving it on screen until the
        % next fixation cross.
        if ~isempty(respKey)
            tStimOff = mixem.clearScreen(params, 0);
        end
    end

    if isnan(tStimOff)
        tStimOff = GetSecs;
    end
    params = mixem.sendTrig(params,'STIM_OFF');

    % Prompt cascade
    hitP1 = local_prompt_hitrects(params,'prompt_1.png');
    hitP2 = local_prompt_hitrects(params,'prompt_2.png');

    if isempty(respKey)
        mixem.showPNG(params,'prompt_1.png',false);
        tPrompt1On = Screen('Flip', params.win);
        params = mixem.sendTrig(params,'PROMPT1_ON');

        [respKey, resp, ~, tRespAbs] = mixem.collectResponse123(params, params.deck, 2.0, hitP1);
        if ~isempty(respKey) && ~sentRespTrig
            params = mixem.sendTrig(params,'RESP_KEYPRESS','note',respKey);
            sentRespTrig = true;
            params = mixem.logMsg(params, "RESP", 'respKey', respKey, 'resp', resp, 'tResp_GetSecs', tRespAbs, 'from', "prompt1");
        end
    end

    if isempty(respKey)
        mixem.showPNG(params,'prompt_2.png',false);
        tPrompt2On = Screen('Flip', params.win);
        params = mixem.sendTrig(params,'PROMPT2_ON');

        [respKey, resp, ~, tRespAbs] = mixem.collectResponse123(params, params.deck, Inf, hitP2);
        if ~isempty(respKey) && ~sentRespTrig
            params = mixem.sendTrig(params,'RESP_KEYPRESS','note',respKey);
            sentRespTrig = true;
            params = mixem.logMsg(params, "RESP", 'respKey', respKey, 'resp', resp, 'tResp_GetSecs', tRespAbs, 'from', "prompt2");
        end
    end

    % If response arrived during prompt_1/prompt_2, rt_ms was not set in
    % the stimulus window above. RT is still measured from stimulus onset
    % (audio: actual audio onset when available; visual: image flip).
    if isnan(rt_ms) && isfinite(tRespAbs)
        tRef = tStimOn;
        if exist('tAudOn','var') && isfinite(tAudOn)
            tRef = tAudOn;
        end
        if isfinite(tRef)
            rt_ms = 1000*(tRespAbs - tRef);
        end
    end

    tTrialEnd = GetSecs;
    epochEnd = NaN;
    if hasBridge
        epochEnd = tTrialEnd - params.getsecs_minus_epoch;
    end

    % Log to resultsTable
    if isempty(respKey)
        respKeyStr = ""; respStr = "";
    else
        respKeyStr = string(respKey);
        respStr    = respKeyStr;
    end

    sr = "";
    if ismember('SR', r.Properties.VariableNames)
        try, sr = string(cellchar(r.SR)); catch, sr = ""; end
    end

    cc = NaN;
    if ismember('CorrectCat', r.Properties.VariableNames)
        try, cc = double(r.CorrectCat); catch, cc = NaN; end
    end

    dur_ms_log = double(r.Dur_ms);
    if strcmp(task,'control') || (strcmp(modality,'vis') && (isnan(dur_ms_log) || dur_ms_log<=0))
        % Store the PLANNED stimulus window. Actual exposure remains directly
        % recoverable from OffsetStim-OnsetStim when a response ends it early.
        dur_ms_log = 1000 * double(stimTimeout);
    end

    row = { ...
        string(params.subjID), ...
        string(task), double(r.Block), double(r.TrialInBlock), ...
        string(modality), sr, string(stimPath), double(dur_ms_log), ...
        string(promptName), double(cc), respKeyStr, respStr, double(rt_ms), ...
        double(tFixOn), double(tStimOn), double(tStimOff), ...
        double(tPrompt1On), double(tPrompt2On), double(NaN), double(tTrialEnd), ...
        double(epochEnd) ...
    };

    params.resultsTable = [params.resultsTable; row]; %#ok<AGROW>

    params = mixem.sendTrig(params,'TRIAL_END');
    params = mixem.logMsg(params, "TRIAL_END", 'TrialEnd_GetSecs', tTrialEnd, 'respKey', respKeyStr, 'rt_ms', rt_ms);
    params = mixem.progressMsg(params, 'TRIAL_DONE', 'phase', phaseName, 'task', task, 'block', double(r.Block), 'trialInBlock', double(r.TrialInBlock), 'resp', respKeyStr, 'rt_ms', rt_ms);

    params.currTrial = params.currTrial + 1;
    params.lastCompletedSeq = max(double(getfield_with_default(params,'lastCompletedSeq',0)), double(r.Seq));
    mixem.safeSave(params);
end

params = mixem.logMsg(params, "STAGE_END", 'Phase', phaseName, 'blockLo', blockLo, 'blockHi', blockHi);
params = mixem.progressMsg(params, 'STAGE_DONE', 'phase', phaseName, 'blocks', sprintf('%d-%d', blockLo, blockHi));

assignin('caller','params',params);
end

% ---- helpers ----
function s = local_cellchar(v)
if iscell(v)
    if isempty(v) || isempty(v{1}), s=''; else, s=char(v{1}); end
else
    s = char(v);
end
end

function m = local_norm_modality(m)
m = lower(strtrim(m));
if any(strcmp(m, {'aud','audio','auditory'})), m='aud'; return; end
if any(strcmp(m, {'vis','visual','image'})),   m='vis'; return; end
end


function v = getfield_with_default(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    v = s.(fieldName);
else
    v = defaultValue;
end
end

function hit = local_prompt_hitrects(params, pngName)
hit = struct('r1',[],'r2',[],'r3',[]);
try, hit.r1 = mixem.getClickableRectForPNG(params,pngName,'r1'); catch, end
try, hit.r2 = mixem.getClickableRectForPNG(params,pngName,'r2'); catch, end
try, hit.r3 = mixem.getClickableRectForPNG(params,pngName,'r3'); catch, end
end

function t = local_last_trig_getsecs(params)
t = NaN;
try
    if isfield(params,'trigLog') && ~isempty(params.trigLog) && ...
            ismember('GetSecs_On', params.trigLog.Properties.VariableNames)
        t = double(params.trigLog.GetSecs_On(end));
    end
catch
end
end

function d = local_audio_duration_sec(wavPath)
d = NaN;
try
    info = audioinfo(wavPath);
    d = double(info.Duration);
catch
end
end