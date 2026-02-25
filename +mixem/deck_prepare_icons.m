function icons = deck_prepare_icons(pyDeck)
PILH  = py.importlib.import_module('StreamDeck.ImageHelpers.PILHelper');
Image = py.importlib.import_module('PIL.Image');
Draw  = py.importlib.import_module('PIL.ImageDraw');
FontM = py.importlib.import_module('PIL.ImageFont');

fmt = pyDeck.key_image_format();
W   = double(fmt{'size'}{1});
H   = double(fmt{'size'}{2});

try
    font = FontM.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', int32(18));
catch
    font = FontM.load_default();
end

icons = struct();
icons.PILH  = PILH;
icons.Image = Image;
icons.Draw  = Draw;
icons.FontM = FontM;
icons.font  = font;
icons.W     = W;
icons.H     = H;
end
