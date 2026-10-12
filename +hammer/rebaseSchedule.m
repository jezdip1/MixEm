function tbl = rebaseSchedule(tbl, stimulusRoot)
% Change only the pending schedule paths; historical response rows are retained.
if ~istable(tbl), return; end
names = intersect({'StimPath','WavPath'}, tbl.Properties.VariableNames);
for k = 1:numel(names)
    column = names{k};
    for i = 1:height(tbl)
        value = tbl.(column)(i,:);
        if iscell(value), old = char(value{1}); else, old = char(value); end
        norm = strrep(old, '\', '/');
        hits = strfind(norm, '/Stimuli/');
        if ~isempty(hits)
            tail = norm(hits(end)+9:end);
        elseif startsWith(norm, 'Stimuli/')
            tail = norm(9:end);
        elseif startsWith(norm, [strrep(stimulusRoot,'\','/') '/'])
            tail = norm(numel(stimulusRoot)+2:end);
        else
            continue;
        end
        parts = strsplit(tail, '/');
        assert(~any(strcmp(parts, '..')), 'Invalid stimulus path.');
        path = fullfile(stimulusRoot, parts{:});
        if iscell(tbl.(column)), tbl.(column){i} = path;
        else, tbl.(column)(i) = string(path); end
    end
end
end
