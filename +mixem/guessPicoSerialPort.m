function port = guessPicoSerialPort()
% mixem.guessPicoSerialPort
% Jednoduchý guess: vezme první dostupný serial port.
% Doporučení: pro stabilitu nastavuj MIXEM_SYNC_PORT.

    port = "";

    try
        % MATLAB R2020b+:
        ports = serialportlist("available");
    catch
        try
            ports = serialportlist;
        catch
            ports = [];
        end
    end

    if isempty(ports)
        return;
    end

    % Priorita (čistě heuristická):
    % Linux: /dev/ttyACM*, /dev/ttyUSB*
    % Windows: COM*
    ports = string(ports);
    idx = find(contains(ports,"ttyACM") | contains(ports,"ttyUSB"), 1, 'first');
    if isempty(idx)
        idx = 1;
    end
    port = ports(idx);
end