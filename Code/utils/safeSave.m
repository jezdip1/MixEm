function safeSave(params)
    try
        save(params.dataFile, 'params');
    catch ME
        warning('safeSave: %s', ME.message);
    end
end
