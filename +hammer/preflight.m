function preflight(c)
% Build real schedules without presenting stimuli or creating subject results.
fprintf('%s / %s\n', c.paradigm, c.Runtime.release);
fprintf('MATLAB: %s\n', version);
for f = {'Screen','PsychPortAudio','PsychImaging','resample','serialport'}
    assert(exist(f{1},'file') ~= 0, 'Missing MATLAB dependency: %s', f{1});
end
assert(isfolder(c.stimuli), 'Missing stimulus root: %s', c.stimuli);
assert(isfolder(c.results), 'Missing results root: %s', c.results);
probe = tempname(c.results); fid = fopen(probe,'w');
assert(fid >= 0, 'Results directory is not writable.'); fclose(fid); delete(probe);
state = rng; guard = onCleanup(@() rng(state)); %#ok<NASGU>
if strcmp(c.paradigm,'MixEm')
    p = struct('stimDir',c.stimuli,'pngDir',fullfile(c.root,'PNG'), ...
        'stimXlsx',fullfile(c.root,'data','mixem_reunified_stimuli_19_9_2025.xlsx'));
    for id = 0:3
        p.idNum = id;
        s = mixem.buildScheduleMixEm(p);
        mixem.auditMasterSchedule(s,p);
        assertFiles(s.StimPath);
        fprintf('Schedule ID class %d: %d rows, all referenced stimuli exist.\n',id,height(s));
    end
else
    imp = fullfile(c.stimuli,'Imp'); aff = fullfile(c.stimuli,'Affect_Em');
    s = buildSchedule('Imp',imp,4,20,2,1); assertFiles(s.WavPath);
    for subset = 1:2
        for condition = {'Affect','Em'}
            s = buildSchedule(condition{1},aff,2,20,2,subset); assertFiles(s.WavPath);
        end
    end
    % Read one frame, discard immediately: confirms the mandatory microphone opens.
    reader = hammer.microphone(c);
    microphoneGuard = onCleanup(@() release(reader)); %#ok<NASGU>
    frame = reader(); assert(~isempty(frame),'Microphone returned no samples.');
    release(reader);
    fprintf('Required microphone opened; one frame read and discarded.\n');
end
hammer.screen(c);
assert(~isempty(c.port), 'No trigger port configured.');
sp = serialport(c.port,c.baud,'Timeout',1);
delete(sp);
fprintf('Serial port opened and closed; no trigger byte sent.\n');
fprintf('PREFLIGHT PASS (files, schedules, dependencies, serial access).\n');
fprintf('Still verify display timing, sound, input controls and FF/00 on the lab hardware.\n');
end

function assertFiles(paths)
paths = cellstr(string(paths));
paths = paths(~cellfun(@isempty,paths));
missing = paths(~cellfun(@isfile,paths));
assert(isempty(missing), 'Missing stimulus: %s', strjoin(missing(1:min(5,end)), ', '));
end
