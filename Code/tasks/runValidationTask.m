function params = runValidationTask(params)
    S = params.masterSchedule;
    rows = strcmpi(S.Phase, 'validation');
    if ~any(rows)
        warning('Validation has no rows in schedule.'); return;
    end
    idxRows = find(rows);

    black = BlackIndex(params.win); white = WhiteIndex(params.win);
    KbName('UnifyKeyNames'); keysAllowed = {'1!','2@','3#','4$','5%','6^','7&'};

    for k = 1:numel(idxRows)
        i = idxRows(k);

        % (Optional) present stimulus again; here a short flash placeholder
        Screen('FillRect', params.win, white*0.2); Screen('Flip', params.win); WaitSecs(0.5);

        v = ask(params.win, params.winRect, 'Valence (1-7)', keysAllowed);
        a = ask(params.win, params.winRect, 'Arousal (1-7)', keysAllowed);
        it= ask(params.win, params.winRect, 'Intensity (1-7)', keysAllowed);

        runDir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'Results', datestr(now,'yyyymmdd_HHMMSS'));
        E = struct('ts', datestr(now,'yyyy-mm-ddTHH:MM:SS'), 'trial', k, 'stimulus_path', S.StimulusPath{i}, 'valence', v, 'arousal', a, 'intensity', it);
        utils.logEvent(runDir, 'events_validation.csv', E);

        params.masterSchedule.Done(i) = true;
        utils.safeSave(params);
    end
end

function val = ask(win, rect, titleTxt, keysAllowed)
    white = WhiteIndex(win); black = BlackIndex(win);
    DrawFormattedText(win, titleTxt, 'center', 'center', white);
    Screen('Flip', win);
    while true
        [down,~,kc] = KbCheck;
        if down
            key = KbName(find(kc)); if iscell(key), key = key{1}; end
            ix = find(strcmpi(keysAllowed, key), 1);
            if ~isempty(ix), val = ix; WaitSecs(0.15); break;
            elseif strcmpi(key,'ESCAPE'), error('Aborted by user');
            end
        end
    end
    Screen('FillRect', win, black); Screen('Flip', win);
end
