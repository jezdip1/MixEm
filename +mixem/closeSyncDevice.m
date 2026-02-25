function closeSyncDevice(sync)
% mixem.closeSyncDevice
% Zavře serial a ppdev (a pošle 0).

    if isempty(sync) || ~isfield(sync,'mode')
        return;
    end

    % Vrať na 0, pokud jde
    try
        if isfield(sync,'ok') && sync.ok
            try, sync = mixem.syncTriggerOff(sync); catch, end %#ok<NASGU>
        end
    catch
    end

    switch lower(string(sync.mode))
        case "serial"
            try
                if isfield(sync,'serial') && ~isempty(sync.serial) && isvalid(sync.serial)
                    try, flush(sync.serial); catch, end
                    try, clear sync.serial; catch, end
                end
            catch
            end

        case "parallel"
            try
                if exist('ppdev_mex','file')
                    try, ppdev_mex('Close', double(sync.ppPort)); catch, end
                end
            catch
            end
    end

    % Pro jistotu i CloseAll (neškodí, jen když existuje)
    try
        if exist('ppdev_mex','file')
            try, ppdev_mex('CloseAll'); catch, end
        end
    catch
    end
end