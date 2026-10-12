# MixEm: nasazení na KISARGRYZEN26

Připravený laboratorní kandidát, nikoli potvrzení funkčního měření na novém PC.
Výchozí kód odpovídá nahranému snapshotu. Kontrola byla provedena přes Git blob SHA.

## Instalace

Z kořene tohoto balíčku nebo čistého checkoutu kandidátní větve:

```bash
sudo python3 scripts/install_lab.py --stimuli '/cesta/k/puvodni/slozce/Stimuli'
```

Bez parametru `--stimuli` se připraví kód a launchery. Hlavní spuštění zůstane
blokované, dokud není importována úplná a ověřená sada stimulů. Stejný příkaz
lze později zopakovat s `--stimuli`. Zdrojové soubory se kopírují, nepřesouvají.
Vyžaduje existující účet `laboperator`, skupinu `hammerlab`, Python 3 a MATLAB R2024b.
Instalátor nevytváří účty, neinstaluje MATLAB a nemění ostatní paradigmata.

- Kód: `/srv/hammerlab/paradigms/MixEm/releases/v0.1.0-rc1-kisargryzen26`
- Aktivní verze: `/srv/hammerlab/paradigms/MixEm/current`
- Stimuly: `/data/stimuli/MixEm/snapshot-20261012`
- Výsledky: `/data/results/MixEm`
- Konfigurace: `/srv/hammerlab/config/MixEm.env`

Instalátor zachovává existující konfiguraci a stejnojmenný release nepřepíše
odlišným obsahem. Každé spuštění ověří kód; main/preflight ověřuje i obsah celé
sady stimulů. Plná sada se bere ze snapshotu, nikoli automaticky ze staršího Gitu.
Pokud existující konfigurace ukazuje jinam, zkontrolujte její cesty před testem.

## Provozní změny

- MATLAB s GUI, jednoznačná cesta k hlavní funkci a launchery pro kontrolu,
  zařízení, FF, 00, výsledky a návod.
- Konfigurace obrazovky, zvuku, mikrofonu, Pico portu, stimulů a výsledků mimo kód.
- Žádné pevné sériové číslo Pico ani cesta do účtu bciadmin.
- Evidence verze v `params.Runtime`, kontrola souborů před spuštěním.
- Obnova aktuálních hardwarových objektů a cest při pokračování; starý výsledek
  se při Restart nejprve přejmenuje na zálohu.
- MusEm: zapnuté PTB sync testy, cleanup i při chybě inicializace, uložení bez
  aktivních hardwarových objektů. MixEm: zachována původní stavová logika triggerů.

## Stimuly

Doplnit celou původní složku Stimuli včetně fotografií, kontrolních stimulů a vol_test. Tabulka data/mixem_reunified_stimuli_19_9_2025.xlsx je součástí kódu.

Instrukce pro obsluhu jsou v `OPERATING.txt`. Jádro experimentu bylo zachováno;
plný běh, synchronizace PTB, příjem TTL a zvuk/nahrávání musí být ověřeny lokálně.
V tomto prostředí není MATLAB, Psychtoolbox ani zařízení laboratoře.
