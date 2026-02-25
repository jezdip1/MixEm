function deck_show_welcome(deck)
if isempty(deck) || ~isfield(deck,'dev') || isempty(deck.dev), return; end
deck.dev.reset();
okImg = deck.makeIcon("OK","gray");
deck.setKeyImage(int32(deck.okIndex), okImg);
end
