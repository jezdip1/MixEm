function deckState = deck_clear_keys(deckState, keys0)
% Vymaže (zčerní) dané klávesy StreamDecku (0-based indexy).
% Používá stejnou PIL logiku jako deck_set_key_icon (černý obrázek bez textu).

if isempty(deckState) || ~isstruct(deckState) || ~isfield(deckState,'dev') || isempty(deckState.dev)
    return
end
if isempty(keys0), return; end

for k = keys0(:)'
    deckState = mixem.deck_set_key_icon(deckState, double(k), '', 'black');
end
end
