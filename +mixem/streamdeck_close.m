function streamdeck_close(deck)
% Bezpečně zavře StreamDeck (pokud je otevřený).
% Funguje i když je deck "napůl rozbitý" po přerušení.

if nargin < 1 || isempty(deck)
    return
end

try
    if isstruct(deck) && isfield(deck,'dev')
        dev = deck.dev;
    else
        dev = deck;
    end

    % některé verze mají reset(), některé ne
    try, dev.reset(); catch, end
    try, dev.close(); catch, end

catch
    % ignoruj – cílem je "best effort" cleanup
end
end
