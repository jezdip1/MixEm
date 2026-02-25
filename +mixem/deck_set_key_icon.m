function deckState = deck_set_key_icon(deckState, keyIndex0, txt, bg)
% Vykreslí textový label na klávese StreamDecku (0-based).
% deckState: MATLAB struct s polem .dev (python deck).
% Vrací deckState (kvůli cache deckState.icons).

if nargin < 4 || isempty(bg), bg = 'black'; end
if isempty(deckState) || ~isstruct(deckState) || ~isfield(deckState,'dev') || isempty(deckState.dev)
    return
end

pyDeck = deckState.dev;

% Cache modulů/fontu do MATLAB structu
if ~isfield(deckState,'icons') || isempty(deckState.icons)
    deckState.icons = mixem.deck_prepare_icons(pyDeck);
end

PILH  = deckState.icons.PILH;
Image = deckState.icons.Image;
Draw  = deckState.icons.Draw;
font  = deckState.icons.font;
W     = deckState.icons.W;
H     = deckState.icons.H;

im = Image.new("RGB", py.tuple({int32(W), int32(H)}), string(bg));
d  = Draw.Draw(im);

txt = string(txt);
bbox = d.textbbox(py.tuple({0,0}), txt, pyargs('font',font));
w = int32(bbox{3} - bbox{1});
h = int32(bbox{4} - bbox{2});
x = int32((W - w)/2);
y = int32((H - h)/2);

d.text(py.tuple({x,y}), txt, pyargs('fill',"white",'font',font));

native = PILH.to_native_format(pyDeck, im);
pyDeck.set_key_image(int32(keyIndex0), native);
end
