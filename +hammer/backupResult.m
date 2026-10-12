function backupResult(path)
% Preserve the previous result when the existing Restart option is selected.
if ~isfile(path), return; end
[folder, name, ext] = fileparts(path);
dest = fullfile(folder, [name '.before_restart_' ...
    char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) ext]);
assert(~isfile(dest), 'Result backup already exists: %s', dest);
[ok, msg] = movefile(path, dest);
assert(ok, 'Cannot back up old result: %s', msg);
fprintf('Previous result preserved: %s\n', dest);
end
