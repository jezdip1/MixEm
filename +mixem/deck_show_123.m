function deckState = deck_show_123(deckState)
if isempty(deckState) || ~isstruct(deckState) || ~isfield(deckState,'dev') || isempty(deckState.dev)
    return
end

% if isfield(deckState,'mode') && strcmp(deckState.mode,'123')
%     return
% end
deckState.mode = '123';

pyDeck = deckState.dev;

deckState.k1Index0 = 0;
deckState.k2Index0 = 1;
deckState.k3Index0 = 2;

try pyDeck.set_brightness(int32(60)); catch, end

deckState = mixem.deck_set_key_icon(deckState, deckState.k1Index0, '1', 'red');
deckState = mixem.deck_set_key_icon(deckState, deckState.k2Index0, '2', 'gray');
deckState = mixem.deck_set_key_icon(deckState, deckState.k3Index0, '3', 'green');

n = double(pyDeck.key_count());
allKeys = 0:(n-1);
keep = [deckState.k1Index0, deckState.k2Index0, deckState.k3Index0];
toClear = setdiff(allKeys, keep);

deckState = mixem.deck_clear_keys(deckState, toClear);
end
