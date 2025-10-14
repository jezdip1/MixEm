function h = initSyncDevice()
    % Try to open ppdev/USB sync; return a handle/struct usable by syncTriggerOn/Off
    h = struct('ok', false);
    try
        if exist('ppdev_mex','file')
            ppdev_mex('CloseAll');
            h.port = ppdev_mex('Open', 'LPT1');  % adjust if needed
            h.ok = true;
        end
    catch
        h.ok = false;
    end
end
