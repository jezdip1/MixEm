function deckState = deck_show_ok(deckState)
if isempty(deckState) || ~isstruct(deckState) || ~isfield(deckState,'dev') || isempty(deckState.dev)
    return
end

% if isfield(deckState,'mode') && strcmp(deckState.mode,'ok')
%     return
% end
deckState.mode = 'ok';

pyDeck = deckState.dev;
deckState.okIndex0 = 1;

try pyDeck.set_brightness(int32(60)); catch, end

deckState = mixem.deck_set_key_icon(deckState, deckState.okIndex0, 'OK', 'green');

n = double(pyDeck.key_count());
allKeys = 0:(n-1);
toClear = setdiff(allKeys, deckState.okIndex0);

deckState = mixem.deck_clear_keys(deckState, toClear);
end
