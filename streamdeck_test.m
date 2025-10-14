% if pyenv().Status=="Loaded", terminate(pyenv); end
% pyenv('Version','/home/bciadmin/anaconda3/envs/mixem/bin/python');

%%
Lib  = py.importlib.import_module('StreamDeck.Transport.LibUSBHIDAPI');
Mini = py.importlib.import_module('StreamDeck.Devices.StreamDeckMini');

% doplň PID 0x00B3 do StreamDeckMini.PRODUCT_IDS (pro případ, že chybí)
if isprop(Mini.StreamDeckMini, 'PRODUCT_IDS')
    P = cell(py.list(Mini.StreamDeckMini.PRODUCT_IDS));
    hasMK2 = any(cellfun(@(x) isequal(double(x), hex2dec('00B3')), P));
    if ~hasMK2
        newP = py.list(P);
        newP.insert(int32(0), uint16(hex2dec('00B3')));
        Mini.StreamDeckMini.PRODUCT_IDS = newP;
    end
end

t = Lib.LibUSBHIDAPI();
VID = uint16(hex2dec('0FD9')); PID = uint16(hex2dec('00B3'));
devs = t.enumerate(VID, PID);
assert(~isempty(devs), 'Stream Deck nenalezen (udev/plugdev?).');

d0  = devs{1}; d0.open();
deck = Mini.StreamDeckMini(d0);
deck.open();
disp("Type: " + string(deck.deck_type()));
disp("SN:   " + string(deck.get_serial_number()));

deck.reset(); deck.close(); d0.close();

%%
% --- importy (po pyenv nastavení) ---
Lib  = py.importlib.import_module('StreamDeck.Transport.LibUSBHIDAPI');
Mini = py.importlib.import_module('StreamDeck.Devices.StreamDeckMini');
PILH = py.importlib.import_module('StreamDeck.ImageHelpers.PILHelper');

% <- DŮLEŽITÉ: importovat PIL submoduly přímo
Image = py.importlib.import_module('PIL.Image');
Draw  = py.importlib.import_module('PIL.ImageDraw');
FontM = py.importlib.import_module('PIL.ImageFont');  % "Font" nepoužij jako název modulu i proměnné najednou

VID = uint16(hex2dec('0FD9'));
PID = uint16(hex2dec('00B3'));

% --- otevření zařízení přes libusb backend ---
t     = Lib.LibUSBHIDAPI();
devs  = t.enumerate(VID, PID);   % vrací Python list
assert(~isempty(devs), 'Stream Deck nenalezen (udev/plugdev?).');

d0 = devs{1};    % <- indexuj až na separátní proměnné
d0.open();
deck = Mini.StreamDeckMini(d0);
deck.open();
deck.reset();

% --- rozměr ikon ---
% fmt = deck.key_image_format(); sz = fmt{'size'};
fmt = deck.key_image_format();
W   = fmt{'size'}{1};   % py.int
H   = fmt{'size'}{2};   % py.int


% --- font (bezpečný fallback) ---
try
    font = FontM.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', int32(18));
catch
    font = FontM.load_default();
end

% --- helper na generování štítků ---
makeIcon = @(txt,bg) local_icon(Image,Draw,font,PILH,deck,W,H,string(txt),string(bg));

% --- vykresli NO / OK / YES na klávesy 0..2 ---
imgs = { makeIcon("NO","red"), makeIcon("OK","gray"), makeIcon("YES","green") };
for k = 1:numel(imgs)
    deck.set_key_image(int32(k-1), imgs{k});
end
deck.set_brightness(int32(60));

% --- krátký test stavů (volitelné) ---
t0 = tic;
while toc(t0) < 10
    st = (deck.key_states());
%     if any(st), fprintf('States: %s\n', mat2str(st)); end
    fprintf('States: %s%s%s%s%s%s\n', st)
    pause(0.2);
end

deck.reset(); deck.close(); d0.close();

% ------- lokální funkce -------
function native = local_icon(Image,Draw,font,PILH,deck,W,H,txt,bg)
im = Image.new("RGB", py.tuple({W,H}), bg);
d  = Draw.Draw(im);
bbox = d.textbbox(py.tuple({0,0}), txt, pyargs('font',font));
w = int32(bbox{3} - bbox{1}); h = int32(bbox{4} - bbox{2});
x = int32((W - w)/2); y = int32((H - h)/2);
d.text(py.tuple({x,y}), txt, pyargs('fill',"white",'font',font));
native = PILH.to_native_format(deck, im);   % vrací bytes-like pro set_key_image
end
