function deckState = deck_show_feedback(deckState)
if isempty(deckState) || ~isstruct(deckState) || ~isfield(deckState,'dev') || isempty(deckState.dev)
    return
end

if isfield(deckState,'mode') && strcmp(deckState.mode,'feedback')
    return
end
deckState.mode = 'feedback';

pyDeck = deckState.dev;

deckState.repeatIndex0 = 0;
deckState.okIndex0     = 1;

try pyDeck.set_brightness(int32(60)); catch, end

% Nastav REP/OK
deckState = mixem.deck_set_key_icon(deckState, deckState.repeatIndex0, 'REP', 'gray');
deckState = mixem.deck_set_key_icon(deckState, deckState.okIndex0,     'OK',  'green');

% Vymaž všechny ostatní klávesy, aby nezůstaly "1/2/3"
n = double(pyDeck.key_count());
allKeys = 0:(n-1);
keep = [deckState.repeatIndex0, deckState.okIndex0];
toClear = setdiff(allKeys, keep);

deckState = mixem.deck_clear_keys(deckState, toClear);
end
