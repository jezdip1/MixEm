function sync = syncTriggerOff(sync)
% mixem.syncTriggerOff
% Nastaví výstup na 0 bez pulsu.

    if isempty(sync) || ~isfield(sync,'ok') || ~sync.ok
        return;
    end

    switch lower(string(sync.mode))
        case "parallel"
            mixem.pp_write(sync, uint8(0));
            sync.lastCode = uint8(0);

        case "serial"
            if ~isempty(sync.serial) && isvalid(sync.serial)
                write(sync.serial, uint8(0), "uint8");
                sync.lastCode = uint8(0);
            end
        otherwise
            % none
    end
end