function syncTriggerOff(h)
    if isstruct(h) && isfield(h,'ok') && h.ok
        try, ppdev_mex('Write', h.port, 0); catch, end
    end
end
