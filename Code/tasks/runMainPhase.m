function params = runMainPhase(params, phaseName)
    S = params.masterSchedule;
    rows = strcmpi(S.Phase, phaseName);
    if ~any(rows)
        warning('Phase %s has no rows in schedule.', phaseName); return;
    end
    idxPhase = find(rows);

    % Resume pointer = první nedokončený v této fázi
    firstTodo = find(~S.Done(idxPhase), 1, 'first');
    if isempty(firstTodo)
        fprintf('Phase %s already complete.\n', phaseName);
        return;
    end

    % PTB colors
    black = BlackIndex(params.win); white = WhiteIndex(params.win);

    for k = firstTodo:numel(idxPhase)
        i = idxPhase(k);
        if S.Done(i), continue; end

        % Fixation jitter
        durFix = params.cfg.fixation_ms_min + rand()*(params.cfg.fixation_ms_max - params.cfg.fixation_ms_min);
        Screen('FillRect', params.win, black); drawCross(params.win, params.winRect, white); Screen('Flip', params.win);
        WaitSecs(durFix/1000);

        % Present stimulus (visual/audio branch)
        stimPath = fullfile(fileparts(fileparts(mfilename('fullpath'))), S.StimulusPath{i});
        onset = GetSecs; respKey = ''; rt = NaN;
        if strcmpi(S.Modality{i},'visual')
            try
                img = imread(stimPath);
                tex = Screen('MakeTexture', params.win, img);
                Screen('DrawTexture', params.win, tex); Screen('Flip', params.win);
            catch
                Screen('FillRect', params.win, white*0.2); Screen('Flip', params.win);
            end
        else
            % TODO: PsychPortAudio playback when audio stimuli are WAV
            Screen('FillRect', params.win, white*0.1); Screen('Flip', params.win);
        end

        % Collect response (keys 1/2/3)
        tStart = GetSecs;
        while (GetSecs - tStart) < (params.cfg.stimulus_ms_max/1000)
            [down,~,kc] = KbCheck;
            if down
                key = KbName(find(kc)); if iscell(key), key = key{1}; end
                if any(strcmpi(key, {'1!','2@','3#'}))
                    respKey = key; rt = (GetSecs - onset)*1000; break;
                elseif strcmpi(key,'ESCAPE')
                    error('Aborted by user');
                end
            end
        end
        offset = GetSecs;

        % Append event row
        runDir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'Results', datestr(now,'yyyymmdd_HHMMSS'));
        E = struct('ts', datestr(now,'yyyy-mm-ddTHH:MM:SS'), ...
            'phase', phaseName, 'block', S.Block(i), 'trial_in_blk', S.TrialIndex(i), ...
            'stimulus_path', S.StimulusPath{i}, 'modality', S.Modality{i}, 'soc_rel', S.SocRel{i}, 'valence_cluster', S.Valence{i}, ...
            'response_key', respKey, 'rt_ms', rt);
        utils.logEvent(runDir, sprintf('events_%s.csv', phaseName), E);

        % Checkpoint do masterSchedule (v params) — žádné nové randomizace
        params.masterSchedule.Done(i)   = true;
        params.masterSchedule.Resp(i)   = string(respKey);
        params.masterSchedule.RTms(i)   = rt;
        params.masterSchedule.Onset(i)  = string(onset);
        params.masterSchedule.Offset(i) = string(offset);

        % Clear screen
        Screen('FillRect', params.win, black); Screen('Flip', params.win);

        % Průběžný save (bezpečné navázání)
        utils.safeSave(params);
    end
end

function drawCross(win, rect, color)
    [cx, cy] = RectCenter(rect);
    Screen('DrawLine', win, color, cx-10, cy, cx+10, cy, 2);
    Screen('DrawLine', win, color, cx, cy-10, cx, cy+10, 2);
end
