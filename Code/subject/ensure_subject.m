function PID = ensure_subject()
PID = input('Participant ID (e.g., PID001): ','s');
if isempty(PID), error('ParticipantID is empty.'); end
root = fileparts(fileparts(mfilename('fullpath')));
subjDir = fullfile(root,'Results','subjects',PID);
if ~exist(subjDir,'dir'), mkdir(subjDir); end
fprintf('Subject %s -> %s\n', PID, subjDir);
end
