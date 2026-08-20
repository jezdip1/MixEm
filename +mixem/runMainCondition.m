function runMainCondition(params, phase)
% phase: 'practice' | 'main_r1' | 'supplemental' | 'main_r2'
% Systemově dle masterSchedule: screen+trial dle Seq.
% Practice má na konci feedback s volbou repeat/continue.
%
% TIMING POLICY:
% - OnsetFix, OnsetStim, OffsetStim, OnsetPrompt1, OnsetPrompt2, TrialEnd: ABS GetSecs (double).
% - WallClockEpoch_TrialEnd: POSIX epoch (double), odvozené přes params.getsecs_minus_epoch.
% - RT_ms: default RT od onsetu stimulu (vis: tStimOn; aud: tAudOn pokud je k dispozici, jinak tStimOn).
%
% NOTE:
% - OnsetRating se v main nepoužívá -> ukládáme NaN.

ms = params.masterSchedule;
cellchar = @(v) local_cellchar(v);

switch phase
    case 'practice',     phaseName = 'practice_main';
    case 'main_r1',      phaseName = 'test';
    case 'supplemental', phaseName = 'supplemental';
    case 'main_r2',      phaseName = 'repetition2';
    otherwise, error('runMainCondition:BadPhase','%s',phase);
end

% vyber screeny v dané phase + main trialy v dané phase
isPhase  = strcmp(cellfun(cellchar, ms.Phase, 'UniformOutput', false), phaseName);
isScreen = isPhase & strcmp(cellfun(cellchar, ms.Event, 'UniformOutput', false), 'screen');
isTrial  = isPhase & strcmp(cellfun(cellchar, ms.Event, 'UniformOutput', false), 'trial') & ...
                    strcmp(cellfun(cellchar, ms.Task,  'UniformOutput', false), 'main');

rows = ms(isScreen | isTrial,:);
if height(rows)==0
    warning('runMainCondition:NoRows','phase=%s (%s) empty', phase, phaseName);
    return
end

[~,ord] = sort(rows.Seq);
rows = rows(ord,:);

if isfield(params,'resumeActive') && logical(params.resumeActive) && ...
        isfield(params,'lastCompletedSeq') && ~isempty(params.lastCompletedSeq)
    rows = rows(rows.Seq > double(params.lastCompletedSeq), :);
    if height(rows)==0
        params = mixem.logMsg(params, "MAIN_SKIP_ALREADY_DONE", 'phase', phase, 'phaseName', phaseName);
        assignin('caller','params',params);
        return
    end
end

dbg = false;
if isfield(params,'debugClickable'), dbg = logical(params.debugClickable); end

hasBridge = isfield(params,'getsecs_minus_epoch') && ~isempty(params.getsecs_minus_epoch) ...
         && isnumeric(params.getsecs_minus_epoch) && isfinite(params.getsecs_minus_epoch);

params = mixem.logMsg(params, "MAIN_BEGIN", 'phase', phase, 'phaseName', phaseName, 'nRows', height(rows));
params = mixem.progressMsg(params, 'MAIN_BEGIN', 'phase', phase, 'phaseName', phaseName, 'rows', height(rows));

% --------- PRACTICE repeat loop ----------
repeatPractice = true;
while repeatPractice
    repeatPractice = false;

    % deck: na začátku practice dáme OK-only pro první instrukční obrazovky
    if isfield(params,'deck') && ~isempty(params.deck)
        try, params.deck = mixem.deck_show_ok(params.deck); catch, end
    end

    for k = 1:height(rows)
        r  = rows(k,:);
        ev = cellchar(r.Event);

        % set common context for logs/triggers
        params.currentSeq   = double(r.Seq);
        params.currentBlock = double(r.Block);
        params.currentTrialInBlock = double(r.TrialInBlock);
        params.currentTask  = "main";

        if strcmp(ev,'screen')
            png = cellchar(r.PNG);
            if isempty(png), continue; end

            params.currentModality = "";
            params.currentStimPath = "";

            params = mixem.logMsg(params, "SCREEN", 'PNG', png, 'phaseName', phaseName);
            params = mixem.progressMsg(params, 'SCREEN', 'phase', phaseName, 'block', double(r.Block), 'seq', double(r.Seq), 'png', png);

            % feedback screen: special rozhodnutí
            if strcmp(png,'feedback.png') && strcmp(phase,'practice')
                choice = mixem.waitFeedbackDecision(params);
                params = mixem.logMsg(params, "PRACTICE_FEEDBACK", 'choice', choice);
                if strcmp(choice,'repeat')
                    repeatPractice = true;
                end
                params.lastCompletedSeq = max(double(getfield_with_default(params,'lastCompletedSeq',0)), double(r.Seq));
                try, mixem.safeSave(params); catch, end
                break
            end

            % běžný screen: OK-only deck + continue hitbox
            if isfield(params,'deck') && ~isempty(params.deck)
                try, params.deck = mixem.deck_show_ok(params.deck); catch, end
            end
            mixem.waitOnPNG(params, png, params.deck, dbg);
            params.lastCompletedSeq = max(double(getfield_with_default(params,'lastCompletedSeq',0)), double(r.Seq));
            try, mixem.safeSave(params); catch, end
            continue
        end

        % ---------------- TRIAL ----------------
        if isfield(params,'deck') && ~isempty(params.deck)
            try, params.deck = mixem.deck_show_123(params.deck); catch, end
        end

        modality = local_norm_modality(cellchar(r.Modality));
        stimPath = cellchar(r.StimPath);
        dur_ms   = double(r.Dur_ms);

        params.currentModality = string(modality);
        params.currentStimPath = string(stimPath);

        params = mixem.logMsg(params, "TRIAL_START", ...
            'phaseName', phaseName, 'modality', modality, 'stim', stimPath, 'dur_ms', dur_ms);
        params = mixem.progressMsg(params, 'TRIAL_START', 'phase', phaseName, 'task', 'main', 'block', double(r.Block), 'trialInBlock', double(r.TrialInBlock), 'modality', modality, 'stim', stimPath);

        % Timeout planning
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

        % Prepare auditory buffer BEFORE fixation so disk IO/resampling/
        % FillBuffer cannot inflate the trigger-to-audio latency.
        audioPrepared = false;
        if strcmp(modality,'aud')
            audioPrepared = mixem.prepareAudioFile(params, stimPath);
        end

        % ---------------- Fix (2–2.5s) ----------------
        mixem.showPNG(params,'fix_cross.png',false);
        tFixOn = Screen('Flip', params.win);
        params = mixem.sendTrig(params,'FIX_ON');
        WaitSecs(2 + rand()*0.5);

        % init stamps
        tStimOn    = NaN;
        tStimOff   = NaN;
        tAudOn     = NaN;
        tPrompt1On = NaN;
        tPrompt2On = NaN;

        % response
        respKey = '';
        resp    = NaN;
        rt_ms   = NaN;
        tRespAbs = NaN;
        sentRespTrig = false;

        % ---------------- Stim + early response ----------------
        if strcmp(modality,'aud')
            mixem.showPNG(params,'stim_aud.png',false);
            tStimOn = Screen('Flip', params.win);
            params = mixem.sendTrig(params,'STIM_ON_AUD');
            tTrigAud = local_last_trig_getsecs(params);

            % Audio is already prepared; only the Start call remains between
            % the trigger and actual PsychPortAudio onset.
            if audioPrepared
                tAudOn = mixem.startPreparedAudio(params);
            else
                tAudOn = NaN;
            end
            trigToAudio_ms = NaN;
            if isfinite(tTrigAud) && isfinite(tAudOn)
                trigToAudio_ms = 1000*(tAudOn - tTrigAud);
            end
            params = mixem.logMsg(params, "AUDIO_START", 'file', stimPath, ...
                'tAudOn_GetSecs', tAudOn, 'trigToAudio_ms', trigToAudio_ms);

            [respKey, resp, ~, tRespAbs] = mixem.collectResponse123(params, params.deck, stimTimeout, struct());

            if ~isempty(respKey) && ~sentRespTrig
                params = mixem.sendTrig(params,'RESP_KEYPRESS','note',respKey);
                sentRespTrig = true;
                params = mixem.logMsg(params, "RESP", 'respKey', respKey, 'resp', resp, 'tResp_GetSecs', tRespAbs, 'from', "stim");
            end

            % Always stop auditory playback when leaving the stimulus window.
            mixem.stopAudio(params);

            tRef = tStimOn;
            if isfinite(tAudOn), tRef = tAudOn; end
            if isfinite(tRespAbs), rt_ms = 1000*(tRespAbs - tRef); end

        else
            tStimOn = mixem.showImageCentered(params, stimPath, 500, 400);
            params = mixem.logMsg(params, "VIS_ON", 'file', stimPath, 'tOn_GetSecs', tStimOn);
            params = mixem.sendTrig(params,'STIM_ON_VIS');

            [respKey, resp, ~, tRespAbs] = mixem.collectResponse123(params, params.deck, stimTimeout, struct());

            if ~isempty(respKey) && ~sentRespTrig
                params = mixem.sendTrig(params,'RESP_KEYPRESS','note',respKey);
                sentRespTrig = true;
                params = mixem.logMsg(params, "RESP", 'respKey', respKey, 'resp', resp, 'tResp_GetSecs', tRespAbs, 'from', "stim");
            end

            if isfinite(tRespAbs), rt_ms = 1000*(tRespAbs - tStimOn); end

            if ~isempty(respKey)
                tStimOff = mixem.clearScreen(params, 0);
            end
        end

        % define "stim off" as moment we leave stimulus section
        if isnan(tStimOff)
            tStimOff = GetSecs;
        end
        params = mixem.sendTrig(params,'STIM_OFF');

        % ---------------- Prompts ----------------
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

        % ---------------- Log -> resultsTable ----------------
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
            cc = double(r.CorrectCat);
        end

        dur_ms_log = double(dur_ms);
        if strcmp(modality,'vis') && (isnan(dur_ms_log) || dur_ms_log<=0)
            % Practice visual stimuli use a runtime 0.3--3.6 s jitter. Store
            % that PLANNED value instead of NaN; actual exposure is still
            % OffsetStim-OnsetStim if the participant responds earlier.
            dur_ms_log = 1000 * double(stimTimeout);
        end

        row = { ...
            string(params.subjID), ...
            "main", double(r.Block), double(r.TrialInBlock), ...
            string(modality), sr, string(stimPath), double(dur_ms_log), ...
            "valence_1_2_3", double(cc), respKeyStr, respStr, double(rt_ms), ...
            double(tFixOn), double(tStimOn), double(tStimOff), ...
            double(tPrompt1On), double(tPrompt2On), double(NaN), double(tTrialEnd), ...
            double(epochEnd) ...
        };

        params.resultsTable = [params.resultsTable; row]; %#ok<AGROW>

        params = mixem.sendTrig(params,'TRIAL_END');
        params = mixem.logMsg(params, "TRIAL_END", 'respKey', respKeyStr, 'rt_ms', rt_ms, 'tTrialEnd_GetSecs', tTrialEnd);
        params = mixem.progressMsg(params, 'TRIAL_DONE', 'phase', phaseName, 'task', 'main', 'block', double(r.Block), 'trialInBlock', double(r.TrialInBlock), 'resp', respKeyStr, 'rt_ms', rt_ms);

        params.currTrial = params.currTrial + 1;
        params.lastCompletedSeq = max(double(getfield_with_default(params,'lastCompletedSeq',0)), double(r.Seq));
        mixem.safeSave(params);
    end
end

params = mixem.logMsg(params, "MAIN_END", 'phase', phase, 'phaseName', phaseName);
params = mixem.progressMsg(params, 'MAIN_DONE', 'phase', phaseName);

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


function v = getfield_with_default(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    v = s.(fieldName);
else
    v = defaultValue;
end
end

function hit = local_prompt_hitrects(params, pngName)
hit = struct('r1',[],'r2',[],'r3',[]);
try, hit.r1 = mixem.getClickableRectForPNG(params,pngName,"r1"); catch, end
try, hit.r2 = mixem.getClickableRectForPNG(params,pngName,"r2"); catch, end
try, hit.r3 = mixem.getClickableRectForPNG(params,pngName,"r3"); catch, end
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

function m = local_norm_modality(m)
m = lower(strtrim(m));
if any(strcmp(m, {'aud','audio','auditory'})), m = 'aud'; return; end
if any(strcmp(m, {'vis','visual','image'})),   m = 'vis'; return; end
end