function deckState = deck_show_rating_nav(deckState)
% Deck layout pro rating:
% 0: CONT
% 1: UP
% 2: OK
% 3: LEFT
% 4: DOWN
% 5: RIGHT

if isempty(deckState) || ~isstruct(deckState) || ~isfield(deckState,'dev') || isempty(deckState.dev)
    return
end

if isfield(deckState,'mode') && strcmp(deckState.mode,'rating_nav')
    return
end
deckState.mode = 'rating_nav';

pyDeck = deckState.dev;

deckState.kCont0  = 0;
deckState.kUp0    = 1;
deckState.kOk0    = 2;
deckState.kLeft0  = 3;
deckState.kDown0  = 4;
deckState.kRight0 = 5;

try pyDeck.set_brightness(int32(60)); catch, end

n = double(pyDeck.key_count());
allKeys = 0:(n-1);

% vyčistit vše
deckState = mixem.deck_clear_keys(deckState, allKeys);

% CONT
deckState = mixem.deck_set_key_icon(deckState, deckState.kCont0, 'CONT', 'green');

% OK (text)
deckState = mixem.deck_set_key_icon(deckState, deckState.kOk0, 'OK', 'gray');

% šipky kreslíme ručně
deckState = local_draw_arrow(deckState, deckState.kUp0,    'up');
deckState = local_draw_arrow(deckState, deckState.kDown0,  'down');
deckState = local_draw_arrow(deckState, deckState.kLeft0,  'left');
deckState = local_draw_arrow(deckState, deckState.kRight0, 'right');

end


% ============================================================
function deckState = local_draw_arrow(deckState, keyIndex0, direction)

pyDeck = deckState.dev;

% získat velikost ikony
fmt = pyDeck.key_image_format();
W   = double(fmt{'size'}{1});
H   = double(fmt{'size'}{2});

% import PIL
Image = py.importlib.import_module('PIL.Image');
Draw  = py.importlib.import_module('PIL.ImageDraw');
PILH  = py.importlib.import_module('StreamDeck.ImageHelpers.PILHelper');

% černé pozadí
im = Image.new("RGB", py.tuple({int32(W), int32(H)}), "black");
d  = Draw.Draw(im);

cx = int32(W/2);
cy = int32(H/2);
sz = int32(min(W,H)*0.30);

switch direction
    case 'up'
        p1 = py.tuple({cx, cy - sz});
        p2 = py.tuple({cx - sz, cy + sz});
        p3 = py.tuple({cx + sz, cy + sz});
    case 'down'
        p1 = py.tuple({cx, cy + sz});
        p2 = py.tuple({cx - sz, cy - sz});
        p3 = py.tuple({cx + sz, cy - sz});
    case 'left'
        p1 = py.tuple({cx - sz, cy});
        p2 = py.tuple({cx + sz, cy - sz});
        p3 = py.tuple({cx + sz, cy + sz});
    case 'right'
        p1 = py.tuple({cx + sz, cy});
        p2 = py.tuple({cx - sz, cy - sz});
        p3 = py.tuple({cx - sz, cy + sz});
end

d.polygon(py.list({p1,p2,p3}), pyargs('fill',"white"));

native = PILH.to_native_format(pyDeck, im);
pyDeck.set_key_image(int32(keyIndex0), native);

end
