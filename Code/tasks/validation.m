function validation(win, rect, cfg, Sched, schedPath, runDir)
black = BlackIndex(win); white = WhiteIndex(win);
KbName('UnifyKeyNames'); keysAllowed={'1!','2@','3#','4$','5%','6^','7&'};
isMain=strcmpi(Sched.set,'main'); isSupp=strcmpi(Sched.set,'supp');
iM=find(isMain); iS=find(isSupp); iM=iM(1:min(32,numel(iM))); iS=iS(1:min(36,numel(iS)));
rows=[iM;iS];
for k=1:numel(rows)
    i=rows(k);
    Screen('FillRect',win,white*0.2); Screen('Flip',win); WaitSecs(0.5);
    v=ask(win,rect,'Valence (1-7)',keysAllowed); a=ask(win,rect,'Arousal (1-7)',keysAllowed); it=ask(win,rect,'Intensity (1-7)',keysAllowed);
    E=struct('ts',datestr(now,'yyyy-mm-ddTHH:MM:SS'),'trial',k,'stimulus_id',Sched.stimulus_id{i},'path',Sched.path{i},'valence',v,'arousal',a,'intensity',it);
    utils.logEvent(runDir,'events_validation.csv',E);
    subject.update_schedule_row(schedPath,i,struct('done',true));
end
end
function val=ask(win,rect,titleTxt,keysAllowed)
white=WhiteIndex(win); black=BlackIndex(win);
DrawFormattedText(win,titleTxt,'center','center',white); Screen('Flip',win);
while true
    [down,~,kc]=KbCheck;
    if down
        key=KbName(find(kc)); if iscell(key), key=key{1}; end
        ix=find(strcmpi(keysAllowed,key),1);
        if ~isempty(ix), val=ix; WaitSecs(0.15); break;
        elseif strcmpi(key,'ESCAPE'), error('Aborted by user');
        end
    end
end
Screen('FillRect',win,black); Screen('Flip',win);
end
