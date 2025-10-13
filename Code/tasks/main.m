function main(win, rect, cfg, Sched, schedPath, runDir, phaseFlag)
KbName('UnifyKeyNames'); km = utils.keymap();
black = BlackIndex(win); white = WhiteIndex(win);
N = height(Sched); blocks = 4; edges = round(linspace(1, N+1, blocks+1));
for b = 1:blocks
    rows = edges(b):edges(b+1)-1;
    Sched.block(rows)        = b;
    Sched.trial_in_blk(rows) = (1:numel(rows))';
end
writetable(Sched, schedPath);
row = subject.next_pointer(Sched);
if isempty(row), DrawFormattedText(win,'Phase complete.','center','center',white); Screen('Flip',win); KbStrokeWait; return; end
for i = row:height(Sched)
    if Sched.done(i), continue; end
    durFix = cfg.fixation_ms_min + rand()*(cfg.fixation_ms_max - cfg.fixation_ms_min);
    Screen('FillRect', win, black); local_cross(win, rect, white); Screen('Flip', win); WaitSecs(durFix/1000);
    stimPath = fullfile(fileparts(fileparts(mfilename('fullpath'))), Sched.path{i});
    onset = GetSecs; respKey=''; rt=NaN;
    if strcmpi(Sched.modality{i},'visual')
        try, img=imread(stimPath); tex=Screen('MakeTexture',win,img); Screen('DrawTexture',win,tex); Screen('Flip',win);
        catch, Screen('FillRect',win,white*0.3); Screen('Flip',win);
        end
    else
        Screen('FillRect',win,white*0.2); Screen('Flip',win); % TODO: PsychPortAudio playback
    end
    tStart = GetSecs;
    while (GetSecs - tStart) < (cfg.stimulus_ms_max/1000)
        [down,~,kc]=KbCheck; if down
            key=KbName(find(kc)); if iscell(key), key=key{1}; end
            if any(strcmpi(key,{'1!','2@','3#'})), respKey=key; rt=(GetSecs-onset)*1000; break;
            elseif strcmpi(key,'ESCAPE'), error('Aborted by user'); end
        end
    end
    offset = GetSecs;
    E = struct('ts', datestr(now,'yyyy-mm-ddTHH:MM:SS'), 'phase',phaseFlag, ...
        'block', Sched.block(i), 'trial_in_blk', Sched.trial_in_blk(i), 'order_idx', Sched.order_idx(i), ...
        'stimulus_id', Sched.stimulus_id{i}, 'path', Sched.path{i}, 'modality', Sched.modality{i}, ...
        'soc_rel', Sched.soc_rel{i}, 'valence_cluster', Sched.valence_cluster{i}, ...
        'response_key', respKey, 'rt_ms', rt);
    utils.logEvent(runDir, sprintf('events_main_phase%d.csv', phaseFlag), E);
    subject.update_schedule_row(schedPath, i, struct('done', true, 'onset_ts', string(onset), 'offset_ts', string(offset), 'response_key', string(respKey), 'rt_ms', rt));
    Screen('FillRect', win, black); Screen('Flip', win);
end
end
function local_cross(win, rect, color)
[cx, cy] = RectCenter(rect);
Screen('DrawLine', win, color, cx-10, cy, cx+10, cy, 2);
Screen('DrawLine', win, color, cx, cy-10, cx, cy+10, 2);
end
