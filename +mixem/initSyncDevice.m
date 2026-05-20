function sync = initSyncDevice(varargin)
% mixem.initSyncDevice
% Detekce sync zařízení:
%   - parallel přes ppdev_mex (ppdev)
%   - serial (USB/COM -> Pico převodník)
%   - none
%
% Volby (name-value):
%   'Preferred'    : 'auto'|'parallel'|'serial'|'none'  (default 'auto')
%   'PulseWidth'   : accepted for backwards compatibility; ignored in state mode
%   'InterPulseGap': accepted for backwards compatibility; ignored in state mode
%   'ResetOnInit'  : true/false, explicitly write 0 after opening device (default false)
%   'ParallelPort' : double port number for ppdev_mex (default 1)
%   'SerialPort'   : "COM3" nebo "/dev/ttyACM0" (default auto-guess)
%   'BaudRate'     : default 115200
%
% Env override:
%   MIXEM_SYNC=auto|parallel|serial|none
%   MIXEM_SYNC_PPPORT=1
%   MIXEM_SYNC_PORT=/dev/ttyACM0 (nebo COMx)

    p = inputParser;
    p.addParameter('Preferred','auto',@(s)ischar(s)||isstring(s));
    p.addParameter('PulseWidth',0.005,@(x)isnumeric(x)&&isscalar(x)&&x>0&&x<0.1);
    p.addParameter('InterPulseGap',0.002,@(x)isnumeric(x)&&isscalar(x)&&x>=0&&x<0.1);
    p.addParameter('ParallelPort',1,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('SerialPort',"",@(s)ischar(s)||isstring(s));
    p.addParameter('BaudRate',115200,@(x)isnumeric(x)&&isscalar(x)&&x>0);
    p.addParameter('ResetOnInit',false,@(x)islogical(x)||ismember(x,[0 1]));
    p.parse(varargin{:});

    pref = lower(string(p.Results.Preferred));
    envPref = getenv('MIXEM_SYNC');
    if ~isempty(envPref)
        pref = lower(string(strtrim(envPref)));
    end

    ppPort = double(p.Results.ParallelPort);
    envPP = getenv('MIXEM_SYNC_PPPORT');
    if ~isempty(envPP)
        tmp = str2double(strtrim(envPP));
        if isfinite(tmp), ppPort = tmp; end
    end

    sync = struct();
    sync.mode          = 'none';
    sync.ok            = false;
    sync.triggerMode   = 'state';
    sync.pulseWidth    = double(p.Results.PulseWidth);    % legacy/no-op in state mode
    sync.interPulseGap = double(p.Results.InterPulseGap); % legacy/no-op in state mode
    sync.resetOnInit   = logical(p.Results.ResetOnInit);
    sync.lastCode      = [];
    sync.enforceUniqueStates = true;

    sync.ppPort = ppPort;
    sync.serial = [];
    sync.info   = "";

    % ---------- PARALLEL ----------
    wantParallel = (pref=="auto" || pref=="parallel");
    if wantParallel && exist('ppdev_mex','file')
        try
            % Zavři všechno, ať startujeme čistě.
            try, ppdev_mex('CloseAll'); catch, end

            % Otevři požadovaný port (typicky 1)
            ppdev_mex('Open', sync.ppPort);

            sync.mode = 'parallel';
            sync.ok   = true;
            sync.info = "ppdev_mex port=" + string(sync.ppPort);

            % MixEm convention: state triggers, no automatic zeroing.
            % Optional explicit reset is available only when requested.
            if sync.resetOnInit
                sync = mixem.syncTriggerOff(sync);
            end
            return;
        catch ME
            warning('initSyncDevice: parallel init failed: %s', ME.message);
        end
    end

    % ---------- SERIAL ----------
    wantSerial = (pref=="auto" || pref=="serial");
    if wantSerial
        try
            port = string(p.Results.SerialPort);
            envPort = getenv('MIXEM_SYNC_PORT');
            if ~isempty(envPort), port = string(strtrim(envPort)); end
            if strlength(port)==0
                port = mixem.guessPicoSerialPort();
            end
            if strlength(port)==0
                error('No serial port found/selected.');
            end
    
            sp = serialport(port, p.Results.BaudRate, 'Timeout', 1);
    
            % !!! FIX: nevolat configureTerminator pro raw byte režim
            % configureTerminator(sp, "");  % <- pryč
    
            flush(sp);
    
            sync.mode   = 'serial';
            sync.serial = sp;
            sync.ok     = true;
            sync.info   = "serialport:" + port;
    
            % MixEm convention: state triggers, no automatic zeroing.
            if sync.resetOnInit
                sync = mixem.syncTriggerOff(sync);
            end
            return;
        catch ME
            warning('initSyncDevice: serial init failed: %s', ME.message);
        end
    end

    % ---------- NONE ----------
    sync.mode = 'none';
    sync.ok   = false;
    sync.info = "none";
end