function quick_trigger_state_test(varargin)
% QUICK_TRIGGER_STATE_TEST  Manual hardware check for MixEm state triggers.
%
% Sends a short sequence of MixEm logical trigger events as held state values.
% There is no automatic return to zero between events and no zero at the end.
% The sequence intentionally repeats a few logical trigger names twice in a row;
% sendTrig() must map the second one to a *_ALT physical code so that the
% physical output still changes.
%
% Example:
%   quick_trigger_state_test
%   quick_trigger_state_test('Preferred','parallel')
%   quick_trigger_state_test('Preferred','serial','SerialPort','/dev/ttyACM0')

p = inputParser;
p.addParameter('Preferred','auto',@(s)ischar(s)||isstring(s));
p.addParameter('ParallelPort',1,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
p.addParameter('SerialPort','',@(s)ischar(s)||isstring(s));
p.addParameter('BaudRate',115200,@(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('Pause',1.0,@(x)isnumeric(x)&&isscalar(x)&&x>0);
p.parse(varargin{:});

baseDir = fileparts(mfilename('fullpath'));
addpath(baseDir, '-begin');
addpath(fullfile(baseDir,'ppdev-mex'), '-begin');
rehash;

params = struct();
params.trig = mixem.TriggerCodes();
params.trigAlt = mixem.TriggerAltCodes();
params.trigTable = mixem.makeTriggerCodesTable();
params.getsecs_minus_epoch = NaN;
params.currentTask = "quick_trigger_state_test";
params.debugStage = "hardware_check";
params.sync = mixem.initSyncDevice('Preferred',p.Results.Preferred, ...
    'ParallelPort',p.Results.ParallelPort, ...
    'SerialPort',p.Results.SerialPort, ...
    'BaudRate',p.Results.BaudRate, ...
    'ResetOnInit',false);
params.trigLog = [];

fprintf('MixEm state trigger test. Device mode=%s ok=%d info=%s\n', ...
    string(params.sync.mode), params.sync.ok, string(params.sync.info));
fprintf('No implicit zero is sent between codes or at the end.\n');
fprintf('Repeated logical events must alternate to *_ALT physical codes.\n\n');

seq = {'SESSION_START', ...
       'FIX_ON','FIX_ON', ...                     % intentional repeat
       'STIM_ON_AUD','STIM_ON_AUD', ...           % intentional repeat
       'RESP_KEYPRESS','RESP_KEYPRESS', ...       % intentional repeat
       'STIM_OFF','TRIAL_END', ...
       'STIM_ON_VIS','RESP_KEYPRESS','SESSION_END'};

lastPhysical = NaN;
try
    for i = 1:numel(seq)
        params.currentSeq = i;
        name = seq{i};
        params = mixem.sendTrig(params, name, 'note', 'quick_trigger_state_test');
        row = params.trigLog(end,:);
        phys = double(row.PhysicalCode);
        if isfinite(lastPhysical) && phys == lastPhysical
            error('quick_trigger_state_test:RepeatedPhysicalCode', ...
                'Physical code repeated at step %d: %d', i, phys);
        end
        fprintf('%2d/%2d logical=%-18s logicalCode=%3d physicalCode=%3d alt=%d dupAvoided=%d\n', ...
            i, numel(seq), name, double(row.LogicalCode), phys, logical(row.UsedAltCode), logical(row.DuplicateAvoided));
        lastPhysical = phys;
        WaitSecs(p.Results.Pause);
    end
    fprintf('\nDone. Final output value should still be the physical SESSION_END code shown above.\n');
catch ME
    try, mixem.closeSyncDevice(params.sync); catch, end
    rethrow(ME);
end

try, mixem.closeSyncDevice(params.sync); catch, end
end
