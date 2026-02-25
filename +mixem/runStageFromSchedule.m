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

dbg = false;
if isfield(params,'debugClickable'), dbg = logical(params.debugClickable); end

hasBridge = isfield(params,'getsecs_minus_epoch') && ~isempty(params.getsecs_minus_epoch) ...
         && isnumeric(params.getsecs_minus_epoch) && isfinite(params.getsecs_minus_epoch);

% default: na screenech OK-only
if isfield(params,'deck') && ~isempty(params.deck)
    try, params.deck = mixem.deck_show_ok(params.deck); catch, end
end

params = mixem.logMsg(params, "STAGE_BEGIN", 'Phase', phaseName, 'blockLo', blockLo, 'blockHi', blockHi);

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

        if isfield(params,'deck') && ~isempty(params.deck)
            try, params.deck = mixem.deck_show_ok(params.deck); catch, end
        end
        mixem.waitOnPNG(params, png, params.deck, dbg);
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

    if isfield(params,'deck') && ~isempty(params.deck)
        try, params.deck = mixem.deck_show_123(params.deck); catch, end
    end

    % Fix
    mixem.showPNG(params,'fix_cross.png',false);
    tFixOn = Screen('Flip', params.win);
    params = mixem.sendTrig(params,'FIX_ON');
    WaitSecs(2 + rand()*0.5);

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

    % init stamps
    tStimOn    = NaN;
    tStimOff   = NaN;
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

        tAudOn = mixem.playAudioFile(params, stimPath);
        params = mixem.logMsg(params, "AUDIO_START", 'File', stimPath, 'tAudOn_GetSecs', tAudOn);

        [respKey, resp, ~, tRespAbs] = mixem.collectResponse123(params, params.deck, stimTimeout, struct());
        if ~isempty(respKey) && ~sentRespTrig
            params = mixem.sendTrig(params,'RESP_KEYPRESS','note',respKey);
            sentRespTrig = true;
            params = mixem.logMsg(params, "RESP", 'respKey', respKey, 'resp', resp, 'tResp_GetSecs', tRespAbs);
        end

        if ~isempty(respKey)
            mixem.stopAudio(params);
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
    end

    tStimOff = GetSecs;
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
    if strcmp(task,'control')
        if isnan(dur_ms_log) || dur_ms_log<=0
            dur_ms_log = NaN;
        end
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

    params.currTrial = params.currTrial + 1;
    mixem.safeSave(params);
end

params = mixem.logMsg(params, "STAGE_END", 'Phase', phaseName, 'blockLo', blockLo, 'blockHi', blockHi);

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

function hit = local_prompt_hitrects(params, pngName)
hit = struct('r1',[],'r2',[],'r3',[]);
try, hit.r1 = mixem.getClickableRectForPNG(params,pngName,'r1'); catch, end
try, hit.r2 = mixem.getClickableRectForPNG(params,pngName,'r2'); catch, end
try, hit.r3 = mixem.getClickableRectForPNG(params,pngName,'r3'); catch, end
end

function d = local_audio_duration_sec(wavPath)
d = NaN;
try
    info = audioinfo(wavPath);
    d = double(info.Duration);
catch
end
end