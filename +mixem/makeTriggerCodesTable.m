function T = makeTriggerCodesTable()
% mixem.makeTriggerCodesTable
% Vrací table: Name, Code, Version

    TC = mixem.TriggerCodes();
    ver = TC.Version;

    fn = fieldnames(TC);
    fn = fn(~strcmp(fn,'Version'));

    codes = zeros(numel(fn),1);
    for i = 1:numel(fn)
        codes(i) = double(TC.(fn{i}));
    end

    % --- validations ---
    if any(codes < 0 | codes > 255 | ~isfinite(codes))
        error('Trigger codes must be in range 0..255.');
    end

    if numel(unique(codes)) ~= numel(codes)
        % najdi duplicity
        [u,~,ic] = unique(codes);
        counts = accumarray(ic,1);
        dupVals = u(counts>1);
        msg = "Duplicate trigger codes detected: ";
        for d = 1:numel(dupVals)
            v = dupVals(d);
            names = fn(codes==v);
            msg = msg + sprintf('%d => %s; ', v, strjoin(names',','));
        end
        error('%s', msg);
    end

    T = table(string(fn), uint16(codes), repmat(string(ver), numel(fn), 1), ...
        'VariableNames', {'Name','Code','Version'});

    % hezké řazení
    T = sortrows(T, 'Code', 'ascend');
end