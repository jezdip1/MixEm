function deck = streamdeck_init()
Lib  = py.importlib.import_module('StreamDeck.Transport.LibUSBHIDAPI');
Mini = py.importlib.import_module('StreamDeck.Devices.StreamDeckMini');
PILH = py.importlib.import_module('StreamDeck.ImageHelpers.PILHelper');
Image = py.importlib.import_module('PIL.Image');
Draw  = py.importlib.import_module('PIL.ImageDraw');
FontM = py.importlib.import_module('PIL.ImageFont');

% pokud existuje persistent/global předchozí deck, zavři ho
try
    global MIXEM_DECK
    if ~isempty(MIXEM_DECK)
        mixem.streamdeck_close(MIXEM_DECK);
    end
catch
end
% Best-effort: reload python modulů (uvolnění singletonů)
try
    py.importlib.invalidate_caches();
    py.importlib.reload(py.importlib.import_module('StreamDeck'));
catch
end


if isprop(Mini.StreamDeckMini, 'PRODUCT_IDS')
    P = cell(py.list(Mini.StreamDeckMini.PRODUCT_IDS));
    if ~any(cellfun(@(x) isequal(double(x), hex2dec('00B3')), P))
        newP = py.list(P); newP.insert(int32(0), uint16(hex2dec('00B3')));
        Mini.StreamDeckMini.PRODUCT_IDS = newP;
    end
end

VID = uint16(hex2dec('0FD9')); PID = uint16(hex2dec('00B3'));
t    = Lib.LibUSBHIDAPI();
devs = t.enumerate(VID, PID);
assert(~isempty(devs), 'StreamDeck nenalezen (udev/plugdev?).');

d0 = devs{1}; d0.open();
sd = Mini.StreamDeckMini(d0); sd.open(); sd.reset();

fmt = sd.key_image_format();
W   = int32(double(fmt{'size'}{1}));
H   = int32(double(fmt{'size'}{2}));

try
    font = FontM.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', int32(18));
catch
    font = FontM.load_default();
end

makeIcon = @(txt,bg) local_icon(Image,Draw,font,PILH,sd,W,H,txt,bg);
setKey   = @(idx, img) sd.set_key_image(int32(idx), img);

sd.set_brightness(int32(60));

deck = struct('dev', sd, 'W', W, 'H', H, ...
              'okIndex', 1, ...  % použijeme tlačítko #1 jako OK
              'makeIcon', makeIcon, ...
              'setKeyImage', setKey);

global MIXEM_DECK
MIXEM_DECK = deck;

end

function native = local_icon(Image,Draw,font,PILH,sd,W,H,txt,bg)
im = Image.new("RGB", py.tuple({W,H}), string(bg));
d  = Draw.Draw(im);
bbox = d.textbbox(py.tuple({0,0}), string(txt), pyargs('font',font));
w = int32(double(bbox{3} - bbox{1}));
h = int32(double(bbox{4} - bbox{2}));
x = int32((double(W) - double(w))/2);
y = int32((double(H) - double(h))/2);
d.text(py.tuple({x,y}), string(txt), pyargs('fill',"white",'font',font));
native = PILH.to_native_format(sd, im);
end
