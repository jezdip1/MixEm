function cfg = loadConfig()
    root = fileparts(fileparts(mfilename('fullpath')));
    cfgPath = fullfile(root,'Code','config.json');
    if ~exist(cfgPath,'file'), error('Missing config.json'); end
    cfg = jsondecode(fileread(cfgPath));
end
