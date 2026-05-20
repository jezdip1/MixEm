function T = makeTriggerCodesTable()
% mixem.makeTriggerCodesTable
% Returns a table of physical trigger codes.
%
% Name            ... physical code name (e.g. STIM_ON_AUD or STIM_ON_AUD_ALT)
% Code            ... physical byte value sent to sync output
% Version         ... trigger schema version
% LogicalName     ... logical event decoded from this code
% LogicalCode     ... primary logical event code
% IsAlternate     ... true for duplicate-avoidance state code

    TC = mixem.TriggerCodes();
    ALT = mixem.TriggerAltCodes();
    ver = string(TC.Version);

    fn = fieldnames(TC);
    fn = fn(~strcmp(fn,'Version'));

    % Primary codes
    names = strings(0,1);
    codes = uint16([]);
    logicalNames = strings(0,1);
    logicalCodes = uint16([]);
    isAlt = false(0,1);

    for i = 1:numel(fn)
        v = TC.(fn{i});
        if ~(isnumeric(v) && isscalar(v) && isfinite(double(v)))
            continue
        end
        names(end+1,1) = string(fn{i}); %#ok<AGROW>
        codes(end+1,1) = uint16(v); %#ok<AGROW>
        logicalNames(end+1,1) = string(fn{i}); %#ok<AGROW>
        logicalCodes(end+1,1) = uint16(v); %#ok<AGROW>
        isAlt(end+1,1) = false; %#ok<AGROW>
    end

    % Alternate physical codes, one per logical trigger.
    for i = 1:numel(fn)
        if ~isfield(ALT, fn{i}), continue; end
        vPrimary = TC.(fn{i});
        vAlt = ALT.(fn{i});
        if ~(isnumeric(vPrimary) && isscalar(vPrimary) && isnumeric(vAlt) && isscalar(vAlt))
            continue
        end
        names(end+1,1) = string(fn{i}) + "_ALT"; %#ok<AGROW>
        codes(end+1,1) = uint16(vAlt); %#ok<AGROW>
        logicalNames(end+1,1) = string(fn{i}); %#ok<AGROW>
        logicalCodes(end+1,1) = uint16(vPrimary); %#ok<AGROW>
        isAlt(end+1,1) = true; %#ok<AGROW>
    end

    % --- validations ---
    if any(double(codes) < 0 | double(codes) > 255 | ~isfinite(double(codes)))
        error('Trigger codes must be in range 0..255.');
    end

    if numel(unique(codes)) ~= numel(codes)
        [u,~,ic] = unique(codes);
        counts = accumarray(ic,1);
        dupVals = u(counts>1);
        msg = "Duplicate physical trigger codes detected: ";
        for d = 1:numel(dupVals)
            v = dupVals(d);
            hit = names(codes==v);
            msg = msg + sprintf('%d => %s; ', v, strjoin(cellstr(hit'),','));
        end
        error('%s', msg);
    end

    T = table(names, codes, repmat(ver, numel(names), 1), logicalNames, logicalCodes, isAlt, ...
        'VariableNames', {'Name','Code','Version','LogicalName','LogicalCode','IsAlternate'});

    T = sortrows(T, 'Code', 'ascend');
end
