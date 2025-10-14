function T = loadStimuliTable(csvPath)
    opts = detectImportOptions(csvPath,'Delimiter',',');
    opts = setvartype(opts, {'stimulus_id','path','modality','soc_rel','set','valence_cluster'}, 'string');
    T = readtable(csvPath, opts);
    need = {'stimulus_id','path','modality','soc_rel','set','valence_cluster'};
    miss = setdiff(need, T.Properties.VariableNames);
    if ~isempty(miss)
        error('Stimuli index missing columns: %s', strjoin(miss, ', '));
    end
end
