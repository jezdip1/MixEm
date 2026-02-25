function bitArray = pp_write(sync, val)
% mixem.pp_write
% Zápis 8bit hodnoty na parallel port přes ppdev_mex.
% Vrací bitArray (1x16 logical) tak jak ho vrací ppdev_mex('Write',...).

    if ~isfield(sync,'ppPort')
        error('pp_write: sync.ppPort missing');
    end

    v = double(uint8(val));  % ppdev_mex chce double scalar
    bitArray = ppdev_mex('Write', double(sync.ppPort), v);
end