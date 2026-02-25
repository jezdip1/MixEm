function deckState = deck_set_key_speaker_icon(deckState, keyIndex0, bg)
% Nakreslí jednoduchou ikonku repráčku (PIL) na klávesu.
% bg: 'black'/'gray'/... (PIL)

if nargin < 3 || isempty(bg), bg = 'black'; end
if isempty(deckState) || ~isstruct(deckState) || ~isfield(deckState,'dev') || isempty(deckState.dev)
    return
end

pyDeck = deckState.dev;

% Cache modulů
if ~isfield(deckState,'icons') || isempty(deckState.icons)
    deckState.icons = mixem.deck_prepare_icons(pyDeck);
end

Image = deckState.icons.Image;
Draw  = deckState.icons.Draw;
PILH  = deckState.icons.PILH;

W = int32(deckState.icons.W);
H = int32(deckState.icons.H);
cy = idivide(H, int32(2));

im = Image.new("RGB", py.tuple({W, H}), py.str(char(bg)));
d  = Draw.Draw(im);

fg = py.str("white");  % <- zásadní fix: žádné RGB tuple z MATLABu

% % Reprák: tělo + kužel
% x0 = int32(18);
% x1 = int32(28);
% y0 = cy - int32(10);
% y1 = cy + int32(10);
% 
% d.rectangle(py.tuple({x0,y0,x1,y1}), pyargs('fill',fg));
% 
% p1 = py.tuple({x1, cy - int32(14)});
% p2 = py.tuple({int32(44), cy});
% p3 = py.tuple({x1, cy + int32(14)});
% d.polygon(py.list({p1,p2,p3}), pyargs('fill',fg));

% Reprák: tělo
x0 = int32(18);
x1 = int32(28);
y0 = cy - int32(10);
y1 = cy + int32(10);
d.rectangle(py.tuple({x0,y0,x1,y1}), pyargs('fill',fg));

% "krk" (úzký obdélník mezi tělem a kuželem)
nx0 = x1;
nx1 = x1 + int32(4);
ny0 = cy - int32(6);
ny1 = cy + int32(6);
d.rectangle(py.tuple({nx0,ny0,nx1,ny1}), pyargs('fill',fg));

% Kužel jako čtyřúhelník (trapez) – méně "play" šipka
kL  = nx1;
kT  = cy - int32(16);
kB  = cy + int32(16);
kR  = nx1 + int32(12);

q1 = py.tuple({kL, cy - int32(8)});
q2 = py.tuple({kR, kT});
q3 = py.tuple({kR, kB});
q4 = py.tuple({kL, cy + int32(8)});
d.polygon(py.list({q1,q2,q3,q4}), pyargs('fill',fg));

% Vlnky
L1 = int32(42); T1 = cy - int32(16); R1 = int32(66); B1 = cy + int32(16);
L2 = int32(46); T2 = cy - int32(24); R2 = int32(78); B2 = cy + int32(24);

startAng = int32(-45);
endAng   = int32(45);
wLine    = int32(3);

d.arc(py.tuple({L1,T1,R1,B1}), startAng, endAng, pyargs('fill',fg,'width',wLine));
d.arc(py.tuple({L2,T2,R2,B2}), startAng, endAng, pyargs('fill',fg,'width',wLine));

native = PILH.to_native_format(pyDeck, im);
pyDeck.set_key_image(int32(keyIndex0), native);
end
