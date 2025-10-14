function buildStimuliIndex()
    root = fileparts(fileparts(mfilename('fullpath')));
    stim = fullfile(root,'Stimuli');
    outDir = fullfile(stim,'index'); if ~exist(outDir,'dir'), mkdir(outDir); end
    out = fullfile(outDir,'stimuli_master_index.csv');

    rows = {};
    rows = [rows; crawl(fullfile(stim,'MAV_vocal_selection'), 'auditory','high','main')];
    rows = [rows; crawl(fullfile(stim,'MEB_musical_selection'), 'auditory','low','main')];
    rows = [rows; crawl(fullfile(stim,'OASIS_person_selection'),'visual','high','main')];
    rows = [rows; crawl(fullfile(stim,'OASIS_os_selection'),   'visual','low','main')];
    rows = [rows; crawl(fullfile(stim,'MAV_vocal_other'),      'auditory','high','supp')];
    rows = [rows; crawl(fullfile(stim,'MEB_musical_other'),    'auditory','low','supp')];
    rows = [rows; crawl(fullfile(stim,'OASIS_person_other'),   'visual','high','supp')];
    rows = [rows; crawl(fullfile(stim,'OASIS_os_other'),       'visual','low','supp')];
    rows = [rows; crawl(fullfile(stim,'control_stimuli'),      'mixed','-','control')];

    fid = fopen(out,'w'); fprintf(fid,'stimulus_id,path,modality,soc_rel,set,valence_cluster\n');
    for i=1:numel(rows)
        r = rows{i};
        fprintf(fid,'%s,%s,%s,%s,%s,%s\n', r.sid, r.path, r.modality, r.soc, r.setname, r.vc);
    end, fclose(fid);
    fprintf('Wrote %s (%d rows).\n', out, numel(rows));
end

function rows = crawl(dirpath, modality, soc, setname)
    rows = {}; if ~exist(dirpath,'dir'), return; end
    files = dir(dirpath); files = files(~[files.isdir]);
    root = fileparts(fileparts(mfilename('fullpath')));
    for k = 1:numel(files)
        fp = fullfile(dirpath, files(k).name);
        rel = strrep(fp, [root filesep], '');
        sid = lower(char(java.util.UUID.randomUUID())); sid = sid(1:10);
        r.sid = sid; r.path = rel; r.modality = modality; r.soc = soc; r.setname = setname; r.vc = '';
        rows{end+1} = r; %#ok<AGROW>
    end
end
