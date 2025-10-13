function cfg = loadConfig()
root = fileparts(fileparts(mfilename('fullpath')));
cfgPath = fullfile(root,'Code','config.json');
cfg = jsondecode(fileread(cfgPath));
end
