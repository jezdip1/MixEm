function syncTriggerOn(h)
    if isstruct(h) && isfield(h,'ok') && h.ok
        try, ppdev_mex('Write', h.port, 255); catch, end
    end
end
