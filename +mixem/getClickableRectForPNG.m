function rect = getClickableRectForPNG(params, pngName, which)
% getClickableRectForPNG(params, pngName, which)
% which: 'continue' | 'speaker' | 'repeat' | 'r1' | 'r2' | 'r3' | ...
% Vrací [L T R B] v pixelech OKNA; jinak [].
%
% Implementace používá window-normalized bb = [x1 y1 x2 y2] v rozsahu 0..1.

if nargin < 3 || isempty(which), which = 'continue'; end

% robustně na char a lower
if isstring(pngName), pngName = char(pngName); end
if isstring(which),   which   = char(which);   end

pngName = lower(strtrim(pngName));
which   = lower(strtrim(which));

winRect = Screen('Rect', params.win);
rect = []; % default

% společný continue button (dole uprostřed) – pro většinu stránek
bb_continue_main = [0.35 0.75 0.65 0.95];
% rect = bbToRect(winRect, [0.35 0.80 0.65 0.95]);

switch pngName
    % ------------------- INIT / INFO PAGES -------------------
    case 'welcome_page.png'
        if strcmp(which,'continue')
            rect = bbToRect(winRect, bb_continue_main);
        end

    case 'inst_main.png'
        if strcmp(which,'continue')
            rect = bbToRect(winRect, bb_continue_main);
        end

    case 'task_main.png'
        if strcmp(which,'continue')
            rect = bbToRect(winRect, bb_continue_main);
        end

    case 'inst_control.png'
        if strcmp(which,'continue')
            rect = bbToRect(winRect, bb_continue_main);
        end

    case 'task_control.png'
        if strcmp(which,'continue')
            rect = bbToRect(winRect, bb_continue_main);
        end

    case {'test_page.png','break_page.png','long_break_page.png','end_page.png'}
        if strcmp(which,'continue')
%             rect = bbToRect(winRect, [0.40 0.80 0.60 0.92]);
            rect = bbToRect(winRect, [0.35 0.75 0.65 0.95]);
        end

    % ------------------- VOLUME TEST -------------------
    case 'vol_test.png'
        switch which
            case 'speaker'
                % ikona repráku ve vol_test (už máš odladěné)
                rect = bbToRect(winRect, [0.35 0.52 0.65 0.64]);
            case 'continue'
                rect = bbToRect(winRect, bb_continue_main);
        end

    % ------------------- MAIN PRACTICE FEEDBACK -------------------
    case 'feedback.png'
        switch which
            case 'repeat'
                rect = bbToRect(winRect, [0.42 0.48 0.58 0.68]); % ikona opakování (střed)
            case 'continue'
                rect = bbToRect(winRect, bb_continue_main);
        end

        % ------------------- CONTROL DEMO -------------------
    case 'stim_control.png'
        % 3 speaker ikonky nahoře
        switch which
            case 'r1'  % levá ikonka
                rect = bbToRect(winRect, [0.15 0.30 0.34 0.56]);
            case 'r2'  % prostřední ikonka
                rect = bbToRect(winRect, [0.42 0.30 0.58 0.56]);
            case 'r3'  % pravá ikonka
                rect = bbToRect(winRect, [0.66 0.30 0.85 0.56]);
            case 'continue'
%                 rect = bbToRect(winRect, [0.35 0.80 0.65 0.95]);
                rect = bbToRect(winRect, [0.35 0.75 0.65 0.95]);
        end

    case 're_stim_control.png'
        switch which
            case 'repeat'
                rect = bbToRect(winRect, [0.40 0.42 0.60 0.65]); % šipka opakování
            case 'continue'
                rect = bbToRect(winRect, [0.35 0.75 0.65 0.95]);
        end

    case 're_stim_control_test.png'
        % stejný layout jako re_stim_control.png
        switch which
            case 'repeat'
                rect = bbToRect(winRect, [0.40 0.42 0.60 0.65]);
            case 'continue'
                rect = bbToRect(winRect, [0.35 0.75 0.65 0.95]);
        end


    % ------------------- PROMPTS (volitelné, pokud chceš klikat na 1/2/3) -------------------
    % Pokud prompt_1.png a prompt_2.png obsahují grafické volby 1/2/3,
    % můžeš zde definovat r1/r2/r3. Zatím nechávám prázdné.
    case 'prompt_1.png'
        % example:
        % if strcmp(which,'r1'), rect = bbToRect(winRect,[...]); end
        % if strcmp(which,'r2'), rect = bbToRect(winRect,[...]); end
        % if strcmp(which,'r3'), rect = bbToRect(winRect,[...]); end
        % (pokud tam nic klikacího není, nech prázdné)
    case 'prompt_2.png'
        % analogicky jako prompt_1.png
    case 'inst_val.png'
        if strcmp(which,'continue')
            rect = bbToRect(winRect, [0.35 0.75 0.65 0.92]);
        end

    case 'resp_val_aud.png'
        switch which
            case 'grid'
                % oblast 3×7 políček (startovní odhad, doladíš debug rámečkem)
                rect = bbToRect(winRect, [0.15 0.53 0.85 0.77]);
            case 'continue'
                rect = bbToRect(winRect, [0.35 0.75 0.65 0.95]);
            case 'speaker'
                % velká ikonka repráku nahoře (pro replay, pokud chceš)
                rect = bbToRect(winRect, [0.43 0.12 0.57 0.32]);
        end

    case 'resp_val_vis.png'
        switch which
            case 'grid'
                rect = bbToRect(winRect, [0.15 0.53 0.85 0.77]);
            case 'continue'
                rect = bbToRect(winRect, [0.35 0.75 0.65 0.95]);
        end

    otherwise
        % nic
end
end

% ---------- helpers ----------
function rect = bbToRect(winRect, bb)
winW = RectWidth(winRect);
winH = RectHeight(winRect);
L = round(winRect(1) + bb(1)*winW);
T = round(winRect(2) + bb(2)*winH);
R = round(winRect(1) + bb(3)*winW);
B = round(winRect(2) + bb(4)*winH);
rect = [L T R B];
end
