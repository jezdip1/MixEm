function st = deck_read_states(dev)
% Vrátí logical vektor stavů kláves StreamDecku.
% Podporuje streamdeck==0.8.5 i jiné varianty API.

% 1) zkus modernější název
try
    pyStates = dev.get_key_states();
catch
    % 2) fallback na starší/alternativní název
    pyStates = dev.key_states();
end

stCell = cell(py.list(pyStates));
st = cellfun(@(b) logical(b), stCell);
st = st(:)'; % row vector
end
