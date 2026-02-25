function st = deck_read_states_any(deck)
% Vrátí logical row vektor stavů kláves StreamDecku.
% Podporuje různé tvary wrapperu (struct / pyobject) a různé API (metoda/vlastnost).

% 1) rozbal device objekt
if isstruct(deck)
    if isfield(deck,'dev')
        dev = deck.dev;
    elseif isfield(deck,'deck')
        dev = deck.deck;
    else
        error('deck_read_states_any:BadDeckStruct', 'Deck struct nemá pole dev ani deck.');
    end
else
    dev = deck;
end

% 2) získej stavy (metoda nebo vlastnost)
pyStates = [];
try
    % preferované
    pyStates = dev.get_key_states();
catch
end

if isempty(pyStates)
    try
        pyStates = dev.key_states();
    catch
    end
end

if isempty(pyStates)
    % poslední pokus: vlastnost (ne metoda)
    try
        pyStates = dev.key_states;
    catch
        error('deck_read_states_any:NoKeyStates', 'Nelze načíst key states (ani get_key_states, ani key_states).');
    end
end

% 3) normalizace na MATLAB logical
try
    stCell = cell(py.list(pyStates));
catch
    % když už je to list-like, cell() často funguje přímo
    stCell = cell(pyStates);
end

st = cellfun(@(b) logical(b), stCell);
st = st(:)'; % row
end
