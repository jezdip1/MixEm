%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% File: +mixem/safeSave.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function safeSave(params)
% SAFESAVE
% Uloží experimentální stav do MAT tak, aby neobsahoval runtime handle-y,
% které nejdou serializovat (Python objekty StreamDecku, audio handles, sync).
%
% Zachovává: masterSchedule, resultsTable, currTrial, cesty, subjID, atd.

params = mixem.augmentResultsWithDatetime(params); %human readable timestamps

p = params;  % kopie na uložení

% --- vyhoď neserializovatelné / runtime objekty ---
% StreamDeck (python objects + PIL cache)
if isfield(p,'deck')
    p.deck = [];
end

% Sync zařízení (ppdev/parallel/USB handle apod.)
if isfield(p,'sync')
    p.sync = [];
end

% PsychPortAudio handle
if isfield(p,'pahandle')
    p.pahandle = [];
end

% Audio reader (DSP System Toolbox object)
if isfield(p,'audioReader')
    p.audioReader = [];
end

% případně cokoliv dalšího, co by mohlo být handle object
if isfield(p,'joy')
    p.joy = [];
end

% --- ulož jako 'params', aby tvůj resume kód zůstal beze změny ---
params = p; %#ok<NASGU>
save(p.dataFile, 'params', '-v7.3');
end
