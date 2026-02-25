function deck_set_key_label(deck, keyIndex0, label)
% keyIndex0: 0-based index na StreamDecku
if isempty(deck) || ~isstruct(deck) || ~isfield(deck,'dev')
    return
end
dev = deck.dev;

pil = py.importlib.import_module('PIL.Image');
drawmod = py.importlib.import_module('PIL.ImageDraw');
helpers = py.importlib.import_module('StreamDeck.ImageHelpers');

% velikost klávesy
fmt = dev.key_image_format();
sz  = fmt.get('size');
w = int32(sz{1}); h = int32(sz{2});

img  = pil.new('RGB', py.tuple({w,h}), py.tuple({0,0,0}));
draw = drawmod.Draw(img);

txt = py.str(label);
bbox = draw.textbbox(py.tuple({0,0}), txt);
tw = int32(bbox{3}) - int32(bbox{1});
th = int32(bbox{4}) - int32(bbox{2});
x = int32((w - tw)/2);
y = int32((h - th)/2);

draw.text(py.tuple({x,y}), txt, py.tuple({255,255,255}));

native = helpers.PILHelper.to_native_format(dev, img);
dev.set_key_image(int32(keyIndex0), native);
end
