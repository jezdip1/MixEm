function TC = TriggerCodes()
% mixem.TriggerCodes
% Jediný zdroj pravdy pro TTL kódy (0..255).
% Všechno má unikátní kód, žádná rekonstrukce z resultsTable.

    TC = struct();
    TC.Version = "MixEmTrig_v1_2026-02-24";

    % --- META / SESSION (1-19) ---
    TC.SESSION_START            = uint8(1);
    TC.SESSION_END              = uint8(2);
    TC.SUBJECT_VERSION_SENT     = uint8(3);   % marker, že jsme poslali VER (ASCII/sekvence)
    TC.SYNC_DEVICE_PARALLEL     = uint8(4);   % optional: signal which sync mode selected
    TC.SYNC_DEVICE_SERIAL       = uint8(5);
    TC.SYNC_DEVICE_NONE         = uint8(6);

    TC.WELCOME_PAGE_ON          = uint8(10);
    TC.VOLUME_TASK_START        = uint8(11);
    TC.VOLUME_TASK_END          = uint8(12);

    % --- STAGE PAGES / BREAKS (20-39) ---
    TC.TEST_PAGE_ON             = uint8(20);
    TC.LONG_BREAK_PAGE_ON       = uint8(21);
    TC.TEST_RESUME_PAGE_ON      = uint8(22);
    TC.END_PAGE_ON              = uint8(23);

    % --- GENERIC TRIAL FLOW (40-89) ---
    % Fixation
    TC.FIX_ON                   = uint8(40);
    TC.FIX_OFF                  = uint8(41);

    % Stimulus ON/OFF by modality
    TC.STIM_ON_AUD              = uint8(50);
    TC.STIM_ON_VIS              = uint8(51);
    TC.STIM_OFF                 = uint8(52);

    % Prompt screens (pokud máte 1/2)
    TC.PROMPT1_ON               = uint8(60);
    TC.PROMPT1_OFF              = uint8(61);
    TC.PROMPT2_ON               = uint8(62);
    TC.PROMPT2_OFF              = uint8(63);

    % Response (jen keypress, jak chceš)
    TC.RESP_KEYPRESS            = uint8(70);

    % Trial end marker
    TC.TRIAL_END                = uint8(80);

    % --- CONDITION/STAGE MARKERS (90-129) ---
    % Ponechávám zvlášť markery pro uživatele (snadno se dělá epoching)
    TC.MAIN_PRACTICE_START       = uint8(90);
    TC.MAIN_PRACTICE_END         = uint8(91);
    TC.CONTROL_PRACTICE_START    = uint8(92);
    TC.CONTROL_PRACTICE_END      = uint8(93);

    TC.STAGE_TEST_START          = uint8(100); % blocks 1-4
    TC.STAGE_TEST_END            = uint8(101);
    TC.STAGE_SUPP_START          = uint8(102); % blocks 5-8
    TC.STAGE_SUPP_END            = uint8(103);
    TC.STAGE_REP2_START          = uint8(104); % blocks 9-12
    TC.STAGE_REP2_END            = uint8(105);

    % Block boundaries (pokud chceš – často užitečné pro sanity)
    TC.BLOCK_START               = uint8(110);
    TC.BLOCK_END                 = uint8(111);

    % --- VALIDATION (130-189) ---
    TC.VAL_TASK_START            = uint8(130);
    TC.VAL_TASK_END              = uint8(131);

    TC.VAL_SCREEN_ON_AUD         = uint8(140);
    TC.VAL_SCREEN_ON_VIS         = uint8(141);

    TC.VAL_PLAY_AUD              = uint8(150);
    TC.VAL_CONTINUE              = uint8(151);

    % Pokud máš dvě volby/prompty i ve validation:
    TC.VAL_PROMPT_ON             = uint8(152);

    % Volitelné: změna “selected item” (ne pixel movement)
    TC.VAL_SELECTION_CHANGED     = uint8(160);

    % --- RESERVED / DEBUG / ERRORS (200-255) ---
    TC.DEBUG_PING                = uint8(200);
    TC.ERROR_GENERIC             = uint8(240);
end