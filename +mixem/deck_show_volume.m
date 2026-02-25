function deckState = deck_show_volume(deckState)
% Přepne StreamDeck do volume režimu: VOL + OK.
% Vrací deckState s uloženými indexy a cache ikon.

if isempty(deckState) || ~isstruct(deckState) || ~isfield(deckState,'dev') || isempty(deckState.dev)
    return
end

pyDeck = deckState.dev;

% Vyber klávesy (0-based pro set_key_image). U Mini jsou 0..5.
% Doporučení: VOL=0 (levá nahoře), OK=1 (prostřed nahoře).
deckState.speakerIndex0 = 0;
deckState.okIndex0      = 1;

% Reset (ať je jisté, že se přepíše starý obsah)
try pyDeck.reset(); catch, end
try pyDeck.set_brightness(int32(60)); catch, end

% Vyčisti všechny klávesy (bez try/catch – ať vidíme chyby)
n = double(pyDeck.key_count());   % py.int -> double
for k0 = 0:(n-1)
    deckState = mixem.deck_set_key_icon(deckState, k0, '', 'black');
end

% Nastav VOL a OK
deckState = mixem.deck_set_key_speaker_icon(deckState, deckState.speakerIndex0, 'gray');
% deckState = mixem.deck_set_key_speaker_icon(deckState, deckState.speakerIndex0, 'gray');
% deckState = mixem.deck_set_key_icon(deckState, deckState.speakerIndex0, 'VOL', 'gray');
deckState = mixem.deck_set_key_icon(deckState, deckState.okIndex0,      'OK',  'green');
end
