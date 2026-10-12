function entry(paradigm, action)
root = getenv('HAMMER_CODE_ROOT');
assert(isfolder(root), 'HAMMER_CODE_ROOT is missing. Use the desktop launcher.');
addpath(root, '-begin');
if strcmp(paradigm, 'MusEm')
    code = fullfile(root,'Code');
else
    code = root;
end
addpath(code, '-begin');
cd(code);
c = hammer.config(paradigm, root);
switch action
    case 'main'
        expected = fullfile(code,'runExperiment.m');
        assert(strcmp(which('runExperiment'), expected), 'Wrong runExperiment on MATLAB path.');
        runExperiment;
    case 'preflight'
        hammer.preflight(c);
    case 'devices'
        disp(Screen('Screens'));
        disp(PsychPortAudio('GetDevices'));
        disp(serialportlist('available'));
        if exist('audioDeviceReader','file')
            reader = audioDeviceReader;
            disp(getAudioDevices(reader));
            release(reader);
        end
    case {'ff','00'}
        assert(~isempty(c.port), 'Trigger port is not configured.');
        sp = serialport(c.port,c.baud,'Timeout',1);
        guard = onCleanup(@() delete(sp)); %#ok<NASGU>
        value = hex2dec(action);
        write(sp,uint8(value),'uint8');
        pause(0.1);
        fprintf('Sent 0x%s to %s; verify the value on the receiving system.\n',upper(action),c.port);
    otherwise
        error('Unknown launcher action: %s', action);
end
end
