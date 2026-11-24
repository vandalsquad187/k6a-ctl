# k6a-ctl — Versionshistorie

> Ausgelagert aus `README.md` beim Docs-Umbau 2026-11-19. Neueste Eintraege zuerst.
> Inhalt unveraendert.

## 2026-11-24 — v1.6.11: WebUI-Refresh (Header, Indicator, Themes)
Dezent poliertes WebUI-Layout, auf-/zuklappbare Kacheln bleiben unveraendert:
- **Header-Titel**: `k6a-ctl` → Glitch-/Strikethrough-Zeichenkette
  `K̶̟͚͂͐͝6̶̹̰͉̀a̸̞͝-̸̻̱̠̇͑͝c̴̖̣͓͝t̷͕̩͛̅ĺ̸͉͓̗`, font-size 20px → 26px
  (Pseudo-Vollbild 16px → 20px).
- **State-Indicator (Header-Pill)**: „ein Tick" groesser (12px/4px → 14px/5px);
  GAMING aktiv = hell gruen (`#86efac`/`#4ade80`), DAILY aktiv = hell orange
  (`#fdba74`/`#fb923c`); CD-Pill-Farben unveraendert.
- **4 neue Themes**: Gruvbox Dark, Tokio Night, Rose Pine, Solarized Dark —
  CSS-Variablen-Override wie die bestehenden (github/vscode/dracula);
  `data-th`-Keys `gruvbox|tokio|rosepine|solarized`, Theme-Buttons umbrechend
  (`#themeSwitch{flex-wrap:wrap}`).
- **Dezentes Polishing**: Kacheln mit feinem 1px-Rahmen + sanftem Schatten,
  Chip-Hover/-Active-Uebergänge.
- Banner-Fallback `v1.6.11`, versionCode 181.

## 2026-11-21 — v1.6.10: Review-Quickwins (description, r()-Warn, mode-Default)
Zweites externes Review, verifiziert (u. a. sepolicy=No-op empirisch widerlegt
durch Finding 3 / hash_state); nur P4+P5+P1 umgesetzt:
- **module.prop**: description auf Kurztext gestrafft (vorher ~3 KB Changelog im
  Prop — Fossil). Details bleiben in dieser Datei.
- **`r()` warn-once**: fehlende Pfade werden pro Pfad einmal geloggt
  (`run/.rmiss`, subshell-sicher), Rueckgabe weiterhin `0`.
- **Default `mode=auto`** (nur Shipped-Template / Neuinstallationen). Bestehende
  `settings.conf` beim Upgrade **nicht** ueberschreiben — Device behaelt gaming.
- Banner-Fallback `v1.6.10`, versionCode 180.
- **sepolicy-Kurz-Experiment (Review-P2 „No-op") — widerlegt, Regel bleibt**:
  selinuxfs-Oracle `u:r:kernel:s0 → u:object_r:sysfs:s0` class file =
  **`40012`** (read+open+getattr), dir = **`10040012`** — byte-identisch zum
  Finding-3-Messwert in `k6a-gov-history.md`. Ohne Reboot laesst sich die
  aus dem Boot geladene Policy nicht zuruecknehmen (`ksud sepolicy` kennt nur
  apply/patch, kein remove); Live-Entfernen der Datei wuerde nichts aendern.
  `hash_state=1` nach rmmod/insmod mit `retries=0`. Verdict: Review-P2 falsch.

## 2026-11-20 — v1.6.9: P1+P2 Review-Fixes (Sicherheit/Bugs/Robustheit/Doku)
Externe 18-Punkte-Review, verifiziert und als P1+P2 umgesetzt (kein Kernel-Flash):
- **P1/1** `webroot/app.js`: tote Root-Bridge `ksuExec` entfernt (0 Aufrufe);
  Hist-Zeilen nur noch `createElement`/`textContent` statt `innerHTML` (XSS-Sink).
- **P1/2** WebUI-Einzelintervall: zweites bare `setInterval(fetchData,2000)`
  raus (Backoff war wirkungslos); BW-Inputs bekommen `activeElement`-Guard
  (Tippen wird nicht mehr alle 2 s überschrieben).
- **P1/3** `service.sh` Port-Check nur noch lokale Spalte (`awk '$2 ~ /:223F$/'`)
  — vorher matchte `:223F ` auch Remote und meldete fälschlich „belegt".
- **P1/4** `webui-handler.sh`: `setcfg`/`_setcfg_locked` liefern rc; alle 9
  Caller `if setcfg …; then ok; else bad` — Fehler sind nicht mehr immer HTTP 200.
- **P1/5** Single-Instance-Match `*k6a-ctl*` → `*k6a-controller*` (False Positive
  u. a. bei `tail -f …/k6a-ctl/…` → RC≠0 → Crash-Zählung).
- **P1/6** `build.sh`: `webui.token`, `*.tmp.*`, `*.lock` ausgeschlossen.
- **P2/7** Crash-Storm: kein `break` mehr — Watchdog bleibt am Leben
  (Backoff capped 30 s), statt bis Reboot tot zu sein.
- **P2/8** `k6a-lib.sh`: kein `thermal_zone0`-Fallback für Gold (ist pm6150-tz);
  Caps (`cpu_apply`/`gpu_limits`/Gold-/Silver-Cap) via `w_checked`.
- **P2/9** **#11 Wahrheit `72 80 87 66 …`** — settings.conf-Kommentar, README-Default
  und module.prop auf den R2-validierten Shipped-Wert angleichen (Kernel-Default
  96/99/102/93 nur als Fußnote ohne Key).
- **P2/10** README-Drift: taskset/fps/IRQ-Rows korrigiert, Legacy-CD-State-Machine-
  Claims auf DAILY/GAMING-Realität, `w_checked`-Satz präzisiert.
- **P2/11** `check_module.sh` Legacy-Zweig (`delegated=0`) validiert jetzt
  `cd_thresholds` (7 Zahlen) statt toter `cd_l2_temp=`-Keys mit Default-Vakuum.
- module.prop 1.6.9 / versionCode 179. Tags: v1.6.7–v1.6.9 nachgezogen.

## 2026-11-19 — v1.6.8: Daemon-Stop-Verifikation repariert + Feinleiter/Silver-Persistenz
- **Fix (Review-Punkt 2)**: `_turbo_verify_tick` nutzte `pidof vendor.thermal-engine`
  / `pidof mi_thermald` — **pidof sieht diese Daemons auf dem Gerät nicht** (AGENTS-Falle,
  derselbe Grund, aus dem der Controller selbst nie via pidof gefunden wird). Der v1.6.7-Check
  loggte deshalb immer `Stop verifiziert (beide Daemons tot)`, **auch bei lebendem Respawn** —
  ein falscher Verifikations-Beweis. Neu: eigener `/proc/[0-9]*/cmdline`-Scan
  (`_daemon_scan`, `tr '\0' ' '` + `case`-Match, 0 Forks im Match) mit **Tri-State**:
  `lebt` → WARN, `tot` → verifiziert, `unbekannt` (/proc unlesbar) → eigene Log-Zeile statt
  Fake-Beweis. Self-Match-Falle gelöst: das Muster läuft nur in der Shell-Variablen, nie in
  argv eines Kindprozesses (sonst matcht der Scan sich selbst → Dauer-„lebt"); `$$`-Exclusion
  belt+braces. Scan feuert einmal pro Turbo-Stop (3-Tick-Countdown), nicht pro Tick.
- **Persistenz (Review-Punkt 3)**: settings.conf-Schlüssel **`cd_ladder`** (0/1, Build461-
  Default = Feinleiter an; 0 = flaches Build459-Verhalten) und **`cd_silver_caps`** (3 Hz
  L2/L3/L4, `0 0 0` = aus) — beide Nodes sind Sysfs-flüchtig (Reboot → Kernel-Defaults),
  das Modul re-appliziert sie idempotent beim Controller-Start, genau wie `gpu_caps`/`cd_thresholds`.
  cfg_load validiert (0/1 bzw. genau 3 Zahlen, sonst Kernel-Default antasten), Start-Banner
  zeigt beide Werte, Gate `[5]` prüft beide Keys gegen die Kernel-Store-Validierung
  (≤2e9, all-or-none-0, l2≥l3≥l4). Alte Kernel ohne Node: Write failt still.
- **Banner-Fallback** `${_MODVER:-v1.6.5}` → v1.6.8 (Stand-Drift vom c0b8a81-Muster).
- **module.prop**: 1.6.8 / versionCode 178.
- Verifiziert: `sh -n` grün, Gate OK 0 warns, Dekoy-Test 18/18 (lebt/tot/Kreuz-Check/
  unbekannt/Countdown/Integration inkl. Self-Match-Nachweis).

## 2026-11-14 — v1.6.6: gpu_caps/poll_adaptive-Persistenz (D1-Arming rebootfest)
- **Fund (r14)**: die k6a_gov-Nodes `gpu_caps` (L2/L3/L4-CD-Hz) und `poll_adaptive`
  überleben keinen Reboot — Kernel-Defaults (800/565/430 bzw. adaptive=1) stehen
  nach jedem Boot wieder drin; die r12/r13/r14-Arming-Werte (800/680/500 + 0)
  mussten bisher JEDEs Mal manuell per sysfs gesetzt werden. Bis v1.6.5 las das
  Modul gpu_caps nur für die Telemetrie (:688), schrieb nie.
- **Fix**: settings.conf-Schlüssel `gpu_caps` (genau 3 Hz-Werte, Validierung wie
  cd_thresholds) und `poll_adaptive` (0/1) + `_apply_gov_caps()` beim
  Controller-Start (gleiche idempotente Schreiblogik wie `_apply_cd_thresholds`
  — Boot/RMMod-Recovery/Watchdog-Respawn deckt die Stelle ab; nur schreiben,
  wenn sysfs abweicht; alte Kernel ohne Node failen still). Start-Log-Zeile
  zeigt beide Werte. rmmod-Recovery braucht keinen service.sh-Hook mehr.
- **Verifiziert**: Gate grün, Controller-Restart am Gerät — Start-Log zeigt
  `gpu_caps=800000000 680000000 500000000 poll_adaptive=0`, Sysfs-Readback
  identisch; idempotent (zweiter Start ohne Rewrite-Log).

## 2026-11-13 — v1.6.5: C1-Fuzz-Schutz + hb-Keys im Blob + Failure-Semantics
- **`_read_int()` (C1)**: zentrale 0-fork-Integer-Lesefunktion (read+eval,
  keine Subshells) — schneidet auf die erste Ganzzahl, Leer-/Read-Fail →
  default. Hintergrund: die v1.6.0-`uptime`-Bugklasse („132910.53" tötete
  `$(( ))`) existierte weiterhin an 5 Hot-Path-Stellen (`_write_data`:
  CPU/GPU-Takte, Akku-Capacity/Temp) und an 3 im service.sh-Watchdog. Alle
  8 Stellen laufen jetzt über den Scrub; der Controller kann dort nicht mehr
  sterben.
- **Gate-Sektion `[7] _read_int-Fuzz`**: 10 Fälle (Float/`42x`/`1e5`/
  Leerzeichen/negativ/leer/Text/Multiline/readfail/007) gegen die echte
  Funktion — die nächste Firmware-Surprise failt das Gate statt den Tick.
- **service.sh-uptime-Scrub**: 3 `cut`-Stellen (Init/Clean-Exit/Backoff)
  scrubben auf 0 statt im `$(( ))` zu sterben (das hätte den Watchdog selbst
  gekillt — der hält sonst den Controller nicht).
- **hb-Keys in data.txt (C5)**: `hb_pid`/`hb_hit`/`hb_miss` zusätzlich zu
  `gov_hist` — WebUI zeigt die HB-Diag unter der Hist-Tabelle statt nur
  service.log.
- **README: Failure-Semantics-Tabelle** — was jede Schicht bei fehlender
  Quelle/Garbage/totem Modul macht (Kernel hold+fail-safe, ctl Scrub,
  Watchdog-Backoff, Turbo-Notbremse).
- Verifiziert: Gate 41/41 grün (neu: 12 Fuzz-Checks — der Float-Fall fand beim
  ersten Lauf den POSIX-read-Bug in `_read_int` selbst, Fix voraus), Controller-Smoke
  (Sandbox, 3 Ticks, data.txt-Keys unverändert + neue hb-Keys), Syntax-Checks
  `sh -n` auf controller/service/check_module/lib.

## 2026-11-09 — v1.6.0: Fork-Diet-2 + r3-Items (Exit-Semantik repariert)
- **Exit-Bug-Fund (r3-Mystery aufgelöst)**: der auto-Mode-`>10 s`-Exit lief de-facto nie —
  `_NOWUP` (aus `/proc/uptime`, Float "132910.53") kippte im `case *[!0-9]*`-Gard auf 0,
  bevor der Punkt-Abschnitt entfernt wurde; das Delta `_NOWUP−_AUTO_LAST` war dadurch immer
  0. Der ctl klebte folglich nach jedem Runden-Ende in GAMING (die r2/r3-Beobachtung, bis
  der v1.5.6-Lifecycle-Guard eventually Force-Daily schoss). Fix: Punkt-Abschnitt wird
  entfernt, **bevor** der Integer-Check läuft — Exit lebt wieder.
- **Residual-Prozess-Fix (r3-Fund)**: swipe-from-recents lässt einen cached CODM-Prozess
  zurück (zygote-Fork, cgroup `/background`); `_auto_eval` scannt jetzt ALLE pidof-Treffer
  auf `top-app` statt nur den ersten. Der >10 s-Exit feuert, sobald kein Treffer mehr im
  Vordergrund sitzt — kein force-stop mehr nötig.
- **Fork-Diet**: P6 (`pidof|awk`-Forks → pid-Argument-Reuse, nur 1 pidof-Ruf je Tick),
  P7 (`ts` in `data.txt` aus dem `/proc/uptime`-Delta statt `date +%s` je Write),
  P8 (settings.conf-Reload per Content-Compare statt stat-Signatur — 0 forks,
  Punkte-Fall diszipliniert), P10 (`data.txt` als printf-Blob statt `cat<<EOF`; `mv`
  bleibt atomar). Ziel-Budget "Controller-CPU ≪18 %" bleibt/Tendenz besser.
- **HB-Diag**: Herzschlag-Zeile erweitert (`pid=… hit=… miss=…`) — die nächste Runde
  beweist die Exit-Pfade sichtbar im Log.
- Verifiziert am Gerät: Start v1.6.0, schedutil-Restore, data.txt-Format unverändert,
  `ts`-Epoch mit Gerätkuhr synchron (nach der `/proc/uptime`-Feld-1-Korrektur).

## 2026-11-09 — v1.5.6: Daily-Restore vervollständigt (hispeed) + Lifecycle-Guard
- **Daily-Restore (hispeed_load/hispeed_freq)**: `_apply_schedutil daily` schrieb bislang
  nur `up/down_rate_limit_us` (10000/50000) zurück — `hispeed_load`/`hispeed_freq` blieben
  auf den GAMING-Werten stehen (hl=50, hf=Gold-Zwicker/P6-Zmax). Im Daily-Idle boostete
  dann jede Task mit Load ≥ 50 % bei 1939200/2304000 Hz im Hintergrund weiter. Fix: der
  Daily-Zweig schreibt jetzt Stockwerte `hispeed_load=90` + `hispeed_freq=0` auf beiden
  Clustern (P0 und P6); am Gerät live verifiziert (hl=90 hf=0 auf cpu0/4/6/7 nach `-> DAILY`).
- **Lifecycle-Guard**: im auto-Mode zählt 5 aufeinanderfolgende Ticks mit `STATE=GAMING`
  während Kernel-Truth `state ≠ gaming && game_pid = 0` → Force-Daily mit Log-Zeile
  (`P18-GUARD: …`). Der reguläre `>10 s`-Exit bleibt primär; der Guard ist Backup gegen
  hängende Phasen-Übergänge.
- Keine Fork-Änderungen (Fork-Diet folgt als v1.6.0), CPU-Budget unverändert.

## 2026-11-08 — v1.5.5: Turbo-Notbremse (Reviewer-Patch `turbo-safety`, inkl. Akku-Fallback)
Reviewer-Beitrag mit Akku-Arm-Live-Fallback (Patch verbatim, Basis = v1.5.3).
**Untere Grenzen (nicht übertreiben, pro Settings.conf überschreibbar):**
- `TURBO_MAX_C=98` (SoC-Gold-Notbremse): liegt 2 °C über der k6a_gov-cd_l2-tier-Schwelle (96),
  d.h. während Turbo ruht der Kernel-Deckel und die Notbremse fungiert als das Finite-Gate,
  das GFP-Ausbrüche einfängt.
- `TURBO_MAX_BATT_C=44` (Akku-Notbremse; re-arm nur unter 41 °C, `TURBO_MAX_BATT_C-3`):
  der Akku-Arm der Notbremse ist die Second-Fan-Domain (USB-Toolbox-emulate-Route).
- `TURBO_REARM_C=85` (Freigabe-Schwelle nach Trip): bewusst NICHT auf 80 gesenkt — bei
  98-auslösend und Gaming-Profil-Abdrosselung ab 96 bleiben ~13 K Sperr-Abstand; 80
  verlängert die Freigabe-Wartezeit (dicker, ohne zusätzliche Sicherheit). Wie immer
  ist `TURBO_REARM_C` config-overridable, falls es später real nachzuziehen ist.
- **Blind-Counter**: 5 Ticks ohne reale Kerntemperatur (`_TURBO_BLIND`) → Trip.
- `_TURBO_LOCK` bleibt persistent bis ein echter `<85`-Readback; `_enter_daily`
  resetet die Sperre (z. B. doel).

**Kern der Notbremse**: unter Turbo (faked Zones `50000 Mmounts`) sind die OEM-Daemons
und **Userspace-Zonen-Reader BLIND** — deshalb zählt nur die REALE Kernel-Temperatur aus
`k6a_gov/status` (temp respektive `temp_peak` als Momentanwert — **keine Session-Ratchet-Station**,
`read_temp()` setzt `temp_peak` pro Tick auf 0 und macht das Maximum der vier Gold-Zonen;
keine Kaltstart-Pflicht) und der Batterie-Warm-Marker. Die Notbremse hat das exclusive
Gate unmittelbar Ruhe → hierfür gilt: **FOG ist die Notbremse NOTBEAM live**, CANDIDATE:
die Ctl-Senke muss laufen (solange der Controller TICKEN läuft, NOTBEAM live, ansonsten
NICHT im cardiogram zu erleben). Der Trip-Wert ist in-line ergänzt über
`k6a_gov/status`-Kanal, nicht über die fake-SZ-Mounts — deshalb NIE blind Anspruch.

**Akku-Fallback (NEU in v1.5.5)**: ist `bt` aus dem Kernel-Status nicht lesbar
(-1/leer), liest `_turbo_guard` `/sys/class/power_supply/battery/temp` direkt mit
`read` (Zehntelgrad → /10; Builtin, kein Fork). Kernel-`bt` VOR ein sysfs-Lese,
fehlende oder kaputte Datei → harmlos (bleibt `batt=0`). Der Akku-Arm hängt damit
**nie** an k6a_gov. Reviewer-Stub-Tests: 44.1 °C löst aus, 35 °C nicht.

**Bewährte Grenze (die "bt=-1"-Story Scharfstellen)**: BT=-1 ist kein "Kernel nicht
verdrahtet" — der Kernel (**v1.7.0**) setzt `batt_temp_c = -1`, wenn `battery_guard`
aus ist, und hält -1 auch bei Read-Errors. Der Controller wartet icing `battery_guard=1`
via `_sync_batt_guard`, solange `BATT_GUARD=on` —giebt das Gerät hat `batt_guard=off`
(R3-Referen Investigations), damit spendete DasGerät `bt=-1` (v1.7.0). **Build 434**
(v1.7.1, BadazzKernel `e9eef01cf`) liest之父 den Kernel Akkutemp jeden Tick (auch
guard=0) → `bt` Liefert die Echte Temperatur. Der Akku-Fallback in v1.5.5 ist
sologen doppelt (bt live + sysfs-Fallback, Kernel-vorzug) — die NOTBEAM-ARM
Arbeiten auf beiden Achsen (kernel-Status und sysfs), unabhängig.

**Verifizierung (am Gerät)**: Zone-Typen übersp Shen — `thermal_zone26/type` =
`cpu-1-0-usr`, `thermal_zone18/type` = `cpu-0-0-usr` (beweist die gold-CPU und
silver-CPU-Zonen), im Notbrems-Mount log als `26(cpu-1-0-usr)` sichtbar. Die
v1.5.4-Notbremse-Fire-Tests (dieselben Mechanismen) passierten am Gerät:
gold=68C → Trip, OEM-Brake restore, re-arm <65, blind-Counter.

## 2026-11-07 — v1.5.3: Fix v1.5.2-crash (P4-Muster: POSIX-read-Fallback)
**v1.5.2 hatte einen Crash im auto-GAMING-Exit-check**: `/proc/uptime`
wurde via `read -r _NOWUP < /proc/uptime` gelesen — POSIX-sh weist einer
einzelnen Variablen die **ganze Zeile inkl. Leerzeichen** zu →
`$(( _NOWUP - _AUTO_LAST ))` bricht im Tick ≥2 nach GAMING-Entry mit
`unexpected '.'` → Shell-Exit 1 → service.sh-Re-Boot-Loop (Crashzikle alle
~3 s, 19:11-19:14). Fix: `read -r _NOWUP _` (2. Dummy-Var nimmt den Rest)
+ numerischer Case-Guard (`*[!0-9]*` → 0). Am Gerät verifiziert: synaptic
mode=gaming-GAMING-Entry war zuvor crash-frei (Exit-check lief dort nicht),
auto-Match-Entry 19:42:42+30 s crash-frei (Vorher 19:40:33 exit-1 Zyklen).
Betroffene Versionsbereiche: nur v1.5.2 (161/162). Debug-Harness (`DEBUG`-Trace über set -x + trace.log) blieb in v1.5.2a receipts.

## 2026-11-07 — v1.5.2: Fork-Diet im GAMING-Hot-Loop
Ziel: Reviewer-Befund „Controller 18 % eines Kerns im Gaming" senken.
Umgesetzt (ohne Semantik-Änderung):
- **SLEEP=2** im GAMING statt 1 (DAILY bleibt 5 s): halbiert die Tick-Rate
  im Gaming — der größte Hebel (~−50 % der Hot-Loop-Kosten); die
  Entry/Exit-Hysterese (`_AUTO_HIT≥2`, 10-s-Exit) bleibt gültig, WebUI-Takt
  im Gaming unverändert 2 s.
- **read_temp** setzt `TEMP_NOW` direkt (global) statt `echo` aus
  `$(cat ...)` — 2 Forks + 2 Subshells entfallen pro Tick.
- **_ensure_gov**: scaling_governor-Vergleich via `read -r` statt
  `$(cat ...)` — 2 Forks + 2 Subshells entfallen pro Tick.
- **Single-Instance-Guard**: `OLD=$(cat $PIDF)` → `read -r OLD < $PIDF`
  (Built-in, 0 Forks pro Tick).
- **_AUTO_LAST/_nowa** (GAMING-Exit-Hysterese) von `date +%s`-Forks auf
  einen `/proc/uptime`-Built-in-Read umgestellt (Uptime-Domain; 0 Forks
  statt 2 Forks pro Tick im Gaming).
Nicht geändert: Epoch-Format von `ts`/hist in data.txt, guard-Race-Fenster,
Watchdog/Recovery-Logik, WebUI/Handler.

Erste Messung (DAILY, 60 s): **≈ 3.9 % eines Kerns (vorher ~3.8 %)** —
kein sichtbarer Sprung. Die DAILY-Last ist primär Shell-Interpreter- und
sysfs-Lesekosten je Tick, nicht die eliminierten Forks; die GAMING-Messung
(SLEEP=2-Hebel) folgt beim nächsten Match-Zyklus.

---

## 2026-11-07 — v1.5.1: WebUI-Härtung + gov-Versionen 1.10+ (Reviewer-Patch)

Reviewer-Patch „token_log_lock“ vom Team (3 Hunks, alle übernommen):

### Änderungen in v1.5.1
- **setcfg-Lock** (bin/webui-handler.sh): `mkdir`-Spin um das
  Read-Modify-Write auf settings.conf (40×50 ms, danach Stale-Break >
  2 s). Reine Defensive — der nc-Server ist sequenziell (eine Connection
  nach der anderen) — falls aber zwei Connections kollidieren, nimmt sich
  kein Request mehr die Keys des anderen weg.
- **Token nie im Log** (bin/webui-handler.sh): `_logq` schreibt per
  `sed 's/\([?&]\)k=[0-9a-fA-F]*/\1k=***/'` → REQ-Log-Zeile zeigt `k=***`.
  GET-Only-Handler-Architektur macht das wasserdicht (der Handler liest
  nur die zuerst empfangene GET-Line `read -r REQ`, das Token kommt also nur
  im Query-String vor; Token ist 32-hex via `tr -dc 'a-f0-9'` — die
  Zeichenklasse greift).
- **kver_ok erweitert** (service.sh): `1.[5-9].*` →
  `1.[5-9].*|1.[1-9][0-9].*` — lädt k6a_gov auch, wenn der Kernel-Gov auf
  1.10.x geht (beide Warn-Texte mit angepasst). 1.7.0 weiter ok; Versionen
  < 1.5 bleiben abgelehnt.

### Verifiziert
- `/ping` + no-op-setcfg → REQ-Log zeigt `k=***`, Lock-Verzeichnis
  nach dem Request geräumt, 6er-Request-Kette alle OK
- kver_ok-Muster lokal geprüft (`1.7.0` ok, `1.10.0` ok, `1.4.9` reject)
- kein Controller-Restart nötig — der Handler wird pro Connection frisch
  geladen; die service.sh-Änderungen wirken beim nächsten Boot

## 2026-11-07 — v1.5.0: „turbo“ — Thermal-Brake-Controller (OEM-Brake lockern)

Anlass: ein Reviewer brachte ein Magisk-Modul („Licking-Thermal 14.1“) an, das
alle Thermal-Userspace-Ketten nuklear ausschaltet: `ctl.stop` aller drei
Daemons (vendor.thermal-engine, mi_thermald, thermal-HAL), `mode=disabled` +
Fake-Temp-30°-Bind-Mounts über **alle** Zonen, leere Dateien über jede
`*thermal*`/`*throttl*`-Datei in /system-/vendor, kgsl
`force_clk_on/throttling=0`, Akku-Grenzen verbogen (temp_hot=57 °C,
thermal_limit=0, bcl=0). Klarer Konsens: **nicht flashen** — `mode=disabled`
friert die Kernel-Sensorkette ein, also genau die Datenquelle, an der
k6a_gov hängt.

v1.5.0 baut das allein sinnvolle Subset davon als optionale Toggles in den
Controller (settings.conf, hot-reload):

### Die zwei Arme (unabhängig kombinierbar, Default je 0)
- **`turbo_stop_daemons=1`** — bei `_enter_gaming`:
  `setprop ctl.stop vendor.thermal-engine` + `setprop ctl.stop mi_thermald`.
  Userspace-OEM-Brake pausiert. Der thermal-HAL (`vendor.thermal-hal`) bleibt
  absichtlich an (reine Lese-/Report-Instanz, throttelt nichts).
- **`turbo_spoof_temp=1`** — Bind-Mount `$MODDIR/run/faketemp` (30000 =
  30.0 °C) auf **nur die 2 SoC-Zonen** (`thermal_zone26/temp`,
  `thermal_zone18/temp` — exakt die Zonen, aus denen der Stack seinen
  Gaming-Temp-Eindruck bezieht).

### Invarianten (was bewusst NICHT passiert)
- **kein `mode=disabled`** — Zonen bleiben aktiv, Trip-Logik des Kernels
  wirkt weiter real
- **Akku/BCL unberührt** — temp_hot/thermal_limit/bcl, Akku-Temp-Nodes
- **k6a_gov liest real** — Kernel liest Sensoren direkt, Bind-Mounts wirken
  nur auf Userspace-Reader
- kgsl/GPU-Frequenzpfade unangetastet (kein force_clk_on-Gehirnersatz)

### Recovery (alles reversibel)
- `_turbo_recover` bei JEDEM Controller-Cold-Start (Boot, Watchdog-Respawn):
  stale Bind-Mounts umounten + `ctl.start` auf beiden Daemons (idempotent —
  init ignoriert Start bereits laufender Services)
- `_enter_daily` umountet und restauriert die Daemons (Guard `_TURBO_ACTIVE`)
- absolute Binärpfade (`/system/bin/mount`, `/system/bin/umount`) — die
  Mount-Aufrufe hängen nicht vom $PATH ab (su-Shells erben je nach Kontext
  unterschiedliche PATHs; Befund „mount: not found“ in einer Termux-su-Shell)

### Getestet am Gerät (2026-11-07)
- Spoof-Arm einmalig manuell: Bind-Mount an → Zone-Temps `30000/30000`,
  k6a_gov-Status zeitgleich unverändert `temp=69` (Kernel liest real);
  `umount` → Temps wieder real, keine Leftovers, `run/faketemp` aufgeräumt
- Mount-Verifikation per **Mountpoint** (` on <zone>/temp type `), nicht per
  Dateinamen: /proc/mounts zeigt für File-Bind-Mounts als Source
  `/dev/block/dm-XX` — `grep faketemp` findet nichts (Befund, gefixt)
- Deployment verifiziert: Banner `v1.5.0 … turbo_stop=0 turbo_spoof=0`,
  DAILY-Entry sauber, thermal-Daemons (1361/1541/2137) laufen

### Messplan (A-Profil als Basis)
Basis = A-Regime (thresholds 96/99/102/93, gpu_caps 585/430/305, hysteresis
500/2000, battery_guard_temp 47 — wie R3-A), `turbo_*=0`:
1. **A10** = `turbo_stop_daemons=1` (1 Match) → Daemon-Pause allein
2. **A11** = beide Arme an (1 Match) → Daemon-Pause + Userspace-Temp blind
Vergleichsanker: R3-A (Ø med180 73.9 fps; thermal-engine schrieb nie auf das
Gold-Cluster) und R4-B (NoFan+B, 2/2-Matches, med180 76.2/77.1 fps). Weil
die OEM-Brake bislang keinen messbaren FPS-Einfluss zeigte, ist der
Erwartungswert der Arme klein — Sinn ist der saubere Ersatz für das
Reviewer-Modul: gleiche Wirkung (OEM-Userpace-Brake aus), aber mit
Kill-Switch (Settings auf 0), Recovery und ohne Zone-/Akku-Tricks des Moduls.

### Am Gerät verifiziert (2026-11-07) — A10/A11-Serie, Lüfter, CODM
- **A10** (2 Runden hintereinander, `turbo_stop_daemons=1`, spoof=0): Entry
  → `turbo: thermal-daemons pausiert`, Exit → `turbo: oem-brake
  wiederhergestellt` (mi_thermald/thermal-engine mit NEUEN PIDs neu
  gestartet). ktemp max 76/77 °C, policy **99.9 % @1708800**, kstate
  **0×cd (kein einziger Cooldown)**, PSI cpu max 25.76, GPU-normales
  Frequenzspektrum, Spiel-Impression „flüssig“.
- **A11** (1 Runde, beide Arme an): zusätzlich `turbo: temp-spoof 30°
  aktiv (zone 26/temp 18/temp)` am Entry; io-Rows zeigen ktemp 68–73 °C
  während Userspace-seitig 30000 gemountet ist — **Kernel-Beweis:** k6a_gov
  liest REAL, Userspace-blind CONFIRMED. policy/kstate identisch zu A10
  (99.9 % ×1708800, 0×cd). Mount-Aufbau/-Abbau + Daemon-Restore
  idempotent über 3 Zyklen.
- **CPU-Last-Messung** (Reviewer-Befund quantifiziert): Controller im
  GAMING = **18 % eines Kerns** (57.4 s/302 s bzw. 55.78 s/303 s, beide
  Runs identisch), im DAILY ≈ 3 %. Charakterisierung komplett; Optimierung
  v1.5.2 (subshell-freie read_temp, _write_data ohne forks, SLEEP=2 im
  Gaming) steht als Vorschlag an.
- **Fazit**: beide Turbo-Arme funktionieren exakt wie designed (Daemon-
  pause + Blind-mount), ohne messbares FPS/Temp-Delta — die R3-A/R4-B-
  Basis bleibt der Maßstab. Release-Gate v1.5.1 erfüllt.

## 2026-11-05 — v1.4.9: Token-Gate, Fork-Diet, mode=auto, P4-Watchdog (Review-Runde)

Reviewer-Runde 2026-11 (5 Befunde, alle umgesetzt, am Gerät live verifiziert):

### Änderungen in v1.4.9
- **WebUI Token-Gate** (Befund 2): jede app mit INTERNET-Recht konnte
  127.0.0.1:8767 nutzen (Android-Loopback ist app-geteilt). Jetzt:
  `config/webui.token` (root-only, 32 hex, per service.sh gelegt), `&k=`
  an alle state-changing Routen; `/ping` und `data.txt` bleiben reine Lese-Zugänge
- **setcfg atomar** (Befund 4): `cat tmp > CONF` → `mv -f tmp CONF`
  (kein Event mehr, bei dem der Controller halbe Configs einliest)
- **Fork-Diet** (Befund 3): ~100 procs/s im Gaming-Tick war Bandbreiten- und
  Wärme-Frachtkosten im Controller selbst. Jetzt: Status-while-read direkt
  aus der Node (0 forks), `cfg_load` nur bei geänderter settings.conf
  (stat-Signatur), direkte Node-Reads (`read < node`) für scaling_cur/battery/
  profile/gpu_caps/battery_guard/game_pid, `nice 0`, `data.txt`-Takt 2 s
  (gaming; daily 5 s; force-write bei State-Wechsel)
- **mode=auto** (Befund 5): `pidof $PKG` + `/proc/<pid>/cgroup` top-app-Zugehörigkeit
  (0 fork path via `read`-Kette) + Hysterese: 2 Bestätigungs-Ticks → `_enter_gaming`,
  10 s ohne top-app → `_enter_daily` incl. oom-reset sauber
- **P4-Stale-Watchdog** (aus 2026-11-01-Deployment in den Tree): 5 Ticks ohne
  `state_age_ms`-Fortschritt bei delegiertem Gaming-Tick → `enable=0`,
  einmal `rmmod+insmod+Re-Apply` → `enable=1`; daneben 60-Tick-Heartbeat
- **controller oom_adj -17 Restria**: dokumentiert (kontrollierte LMK-Immunität
  während GAMING; Reset beim DAILY-Wechsel)

### Am Gerät verifiziert (2026-11-05)
- `/ping` ohne Token 200; `/mode`/`/profile`/flasch-Token 403; valides Token 200
- `mode=auto`: `-> DAILY` 8 s nach dem Modus-Switch (enable=0, game_pid=0)
- `data.txt`-Takt: ~2 s statt 1 s (mtimes 109→111→115 s)
- Sysfs-Arm (R3-A-Profil): thresholds `96 99 102 93 1708800 1555200 1324800`,
  gpu_caps `585000000 430000000 305000000`, hysteresis `fast=500 normal=2000`,
  battery_guard_temp `47`/guard `off`
- on-device `sh -n` über controller/handler/service grün

## 2026-11-05 — v1.4.10: Gold-Cap-Skip nach daily→gaming (Match-2-Befund)

- **Befund** (Match 2, 22:21–22:45): Controller-Enter 22:24:35 loggte
  `profile → badazz_safe` + `-> GAMING (…gold_cap=1708800…)`, aber **keine**
  `gold_cap →…`/`thermal_protect=on`-Zeile — Kernel lief mit
  `policy_max=1555200` (Daily-Cap) kalt durchs ganze Match, während Match 1
  sauber 1708800 hielt.
- **Root Cause**: `_apply_caps_gaming`-Guard verglich den Prozess-State
  `_THP_APPLIED` gegen den Config-Tuple (`on|1708800|0|0`). Nach `_enter_daily`
  blieb dieTuple stehen; das nächste `_enter_gaming` (2. Match im selben
  Controller-Prozess) matchte exakt → stummer `return 0` → kein
  `P6/scaling_max_freq`-Write. Im Kernel (delegated, `legacy_mode=1`) setzt
  `enforce_max_freq` im plain-GAMING-State `cap_now=0` und schreibt nichts —
  Caps im delegated-Modus macht **nur** der Controller. Also blieb 1555200.
- **Fix**: Guard-Invalidierung (`_THP_APPLIED=""`) in `_enter_daily` &&
  belt+braces in `_enter_gaming`. Der Guard bleibt for die Live-Reaktion auf
  Config-Änderungen im Tick-Loop (Zeile 620) — dort muss er matchen/konvergieren.
  Innere `_apply_gold_cap/_apply_silver_cap/_apply_gpu_cap`-Wert-Guards machen
  das Entry idempotent (Silver/GPU: 0==0 → skip wie bisher, Gold: 1555200≠1708800 → write+log).
- ** Erläuterung als Theorie-Mitnahme**: das Crash-Fenster 20:34–20:40 (Kernel
  gaming auf 1555200) zeigt exakt dieselbe Signatur — Kernel-/Boot-Default-Cap
  im State gaming, kein Raise durch irgendeine Schicht.

## 2026-11-06 — v1.4.10 am Gerät verifiziert: R4-B-Serie (NoFan, 2 Matches)

Messkonfiguration (B-Profil / Reviewer-Deckel, Lüfter aus):
`cd_thresholds=60 85 92 55 1555200 1200000 1000000`, `battery_guard_temp=45`,
Gold-Caps 1708800 (gaming) / 1555200 (daily), `gpu_caps=565/430/355 MHz`.

Kern-Semantik in beiden Runden identisch: Entry → ~1 min `policy=1708800`
(gaming) → CD_L2 ab Window ≥ 60° → restliche Matchdauer `policy=1555200`,
GPU ≤ 565 MHz, keine L3/L4-Eskalation, Exit sauber → DAILY (1555200).

| Runde | Dauer | gaming/cd_l2-Residency | Policy | GPU-Histogramm (dedup/s) | ktemp max | Ende-Zonen | Akku |
|---|---|---|---|---|---|---|---|
| M1 20:21–20:38 | ~17 min | 104 s / 911 s | 1555200 ab +65 s | 529×355 · 260×565 · 158×430 · 1×800 | 81 | 69.0/66.7 | 96→77 % |
| M2 21:07–21:28 | ~21 min | 99 s / 1153 s | 1555200 ab +99 s | 510×355 · 167×565 · 127×430 · 6×650 · 2×800 | 81 | 72.5/69.0 | 69→51 % |

- **v1.4.10-2nd-Entry-Proof**: M2 war der zweite Entry im selben
  Controller-Prozess. Entry 21:07:35 schrieb erwartungskonform
  `gold_cap → 1708800` + `thermal_protect=on` + `cd_thresholds` +
  `profile → badazz_safe` (service.log) — der stille Skip aus v1.4.9 ist
  damit in Aktion gefehlt und nach dem Fix verifiziert behoben.
- NoFan-FPS-Eindruck: M1 leichte Frame-Dips in der letzten Matchminute;
  M2 (heißeres Ende, 72.5 °C Zone) subjektiv **ohne** End-Dips — das
  Deckel-Regime hält die Gold-Last konstant warm-neutral.
- IO-Protokoll (Nachtrag): der Sampler (`io_samp4.sh`) verschiebt die vorige
  Out-Datei per **startup-`mv`** in `_DONE_`/`_PARTIAL_`/`_ARM_<epoch>`-Backups
  — Match-Daten gehen dadurch **nicht verloren**; parallel laufende
  Sampler-Instanzen inter-leaven Rows (Auswertung daher dedup pro Sekunde).
  Respawn-Loop inkl. Rotation gehört zum `badazz_iowatch`-Modul
  (`service.sh` + `.io_samp_env`/`.io_arm_flag`).

## 2026-10-18 — v1.4.1: GAMING-Schwellen 96/99/102/93 (BadazzKernel build352)

Messbasis: BadazzKernel-runde r46–r54 (build351, gleiche Karte, NoFan,
Discharging, eine Runde pro Messung, med180 = validate.py).

| Setup | med180 | k6a-Verhalten |
|---|---|---|
| gekappt (1708800), alt显露 Schwellen 93/96/99 | 62,5/58,3/63,0 (Ø 61,3) | gaming 100%, SoC ≤ ~90 °C |
| uncapped (2304000), Schwellen 93/96/99 | 60,5/66,5/62,0 (Ø 63,0) | SoC max 95 °C, k6a 20–39 % in cd_l2 (p6 → 1708800) |
| uncapped, Schwellen **96/99/102/93** | **70,2/74,5/77,0 (Ø 73,9)** | **gaming 100 %, p6 100 % @ 2304000, 0 Täler** |

Der +10…+13-fps-Gewinn kommt ausschließlich daraus, dass die Runde
`gaming` nie verlässt; die alte 93-°C-L2-Schwelle war der eigentliche
Bremser, nicht die p6-Kappe. r44 (75,7) ist der historische Archetyp
(jener erste „ashol“ Nim-Lauf ohne CD-Fenster).

### Änderungen in v1.4.1
- `service.sh`: Version-Lock minor-flexibel (`kver_ok` akzeptiert
  `1.5.*` statt exakt 1.5.0) — build352 bringt `k6a_gov.ko` 1.5.1,
  das vorher bei jedem Boot abgewiesen und als Legacy-Fallback
  übersprungen worden wäre.
- `settings.conf`: `cd_thresholds=96 99 102 93 …` (auf Gerät bereits
  gefixt; jetzt auch für frische Modul-Installationen).
- `k6a-controller`: `_apply_cd_thresholds` **idempotent** — Boot-Write
  nur noch bei Abweichung, kein stammschutz über thresholds_user, kein
  unnötiges Überschreiben des GAMING-Defaults aus build352.
- `gold_cap_gaming` bleibt 1708800 bis zur build352-A/B-Kontrolle
  (0 vs 1708800, 3 Runden je) — danach Votum über settings.conf.

## 2026-10-18 — v1.4.2: silver/GPU-Deckel als Runtime-Tunables

Neu in `settings.conf` (Hz; **0 = unverändert** = Boot-Max, Restore beim
Verlassen des Gaming-State):

```conf
silver_cap_gaming=0   # policy0 (Silver) während GAMING
gpu_cap_gaming=0      # kgsl-3d0 devfreq/max_freq + max_gpuclk während GAMING
```

- `gold_cap_gaming` (seit v1.3) deckelt policy6 (Gold, CPU) — v1.4.2 ergänzt
  Silver (policy0) und die GPU. Rohwerte werden nicht gerastet: Kernel
  (cpufreq/devfreq) snapt selbst auf die OPP-Tabelle.
- `gpu_limits()` schreibt jetzt zusätzlich `kgsl-3d0/max_gpuclk` — mi_thermald
  besitzt das cooling device `thermal-devfreq-0` (GPU): Unser Write passiert
  nach dessen Spielbeginn-Init und wird bei jedem State-Wechsel neu gesetzt.
- Idempotent wie `_apply_gold_cap`: kein Write, kein Log bei unverändertem
  Wert; `GPUCAP/silver_cap>A-(Boot-Max)` wird auf Io Allowed geklemmt.

**Messbasis v1.4.2** (sweet SD732G, CODM, build352 + Schwellen 96/99/102/93):

| Runde | Config | med180 | late-med | bt max | k6a |
|---|---|---|---|---|---|
| r56 | FAN, gpu frei | **82,5** | **69,6** | 32,3 °C | gaming 100 % |
| r57 | NoFan, gpu frei | 72,0 | 45,6 | 41,7 °C | gaming 100 % |
| r58 | NoFan, Trip 95→98 °C | 63,8 ↓ | 38,6 ↓ | **45,2 °C** | 17 % cd_l2 |

Eingestelltes Wissen: daemon-seitiges Thermal-Pinning bei ~95 °C ist **nicht
per sysfs-Trip schraubbar** (Write blieb bestehen, Pinnung blieb) und das
Erhöhen verschlechtert den Standistäfen — ohne Lüfter muss irgendwo ein
Deckel mitmachen andernfalls heizt der Akku (bt >45 °C). **Der Lüfter
erledigt es** — deshalb bleibt `gpu_cap_gaming=0` der Default; 700000000
ist ein sinnvoller NoFan-Experimentwert (CPU-limitiert, tp besser ~80 °C).

## 2026-10-18 — v1.4.4: Aufklappbare Kacheln + History-Ring + Settings-Panel

**UI/UX:**
- **Status- & Kernel-Governor-Kachel** auf-/zuklappbar (`<details>`/`<summary>`);
  Pfeil (groß, rechts) dreht beim Zuklappen, Zustand per `localStorage`.
- **Akku-Guard + Akku-Guard(°C)** in die Toggle-Karte verschoben (unter
  Thermal-Schutz/Gold-Cap) — Governor-Karte nur noch Lesezeilen.
- **Settings-Button (⚙, rechts unten)** mit Panel: Theme-Picker
  (`github`/`vscode`/`dracula`, per `data-theme` CSS-Variablen),
  Hintergrundbild + Kachel-Transparenz (Slider, `localStorage`-Persistenz),
  Reset, **Check-Updates** (Vergleich `module.version` vs. GitHub-raw;
  dazu schreibt die ctl jetzt `modver` in `data.txt`), Fullscreen.
- **WebUI-Härting:** service.sh spawnt webui nur noch, wenn `:8767` frei ist
  (belegt-check via `/proc/net/tcp`), kein Doppelspawn bei leerer pid-Datei.

**Bugfix:**
- **History funktionierte nicht richtig** — der Kernel liefert in `status`
  nur die **letzte** Transition; die ctl erkannte Kernels-State-Änderungen
  pro Tick jetzt selbst und hält einen 15er-Ring (`run/webhist.txt`), der
  in `data.txt` als `gov_hist` landet (Live:getestet: Daily/→Gaming-Flip
  = 3 Zeilen).

**Analyse-Nachtrag (Code-Verifizierung):** `thermal_protect` steuert nur
die drei statischen ctl-Deckel; der **Akku-Guard** ist Kernel-intern und
hart: bt ≥45 °C → CD_L2-Zwang (p6 1708800, GPU 800 MHz) **inkl. Blockade
des CD-Ladder-Exits** bis bt <40 °C (−5 K). `profile=custom` ⇒
`auto_badazz_switch` inaktiv.

**Messbasis v1.4.4** (build353, Gold-Cap-Verifikation unter Lüfter):

| Runde | Config | med180 | late-med | k6a |
|---|---|---|---|---|
| r56 | FAN, gpu+Cap frei | **82,5** | **69,6** | gaming 100 % |
| r59d | FAN, Gold-Cap 1708800 | 60,1 | 53,1 | gaming 100 % |

⇒ Empfehlung: **Lüfter AN, Gold-Cap AUS** für CODM — der Cap kostet im
FAN-Regime ~15–22 fps und bringt keine Bonus-Coolness vs. den Lüfter.
Der UI-Toggle bleibt als Backup-Modus (Akku, extrem-Hitze) praktikabel.

## 2026-10-18 — v1.4.3: Gold-Cap-UI-Toggle + thermal_protect wirksam

**Analyse-Erkenntnis v1.4.2:** `thermal_protect` war ein **toter Schalter**
(Code-Befund: parse + Anzeige + Log, aber **keine** `$THP`-Verzweigung im
Enforcement-Pfad). v1.4.3 bindet ihn mit echter Semantik:

| Flag | Wirkung |
|---|---|
| `thermal_protect=on`  | Gaming-Deckel **aktiv** (gold/silver/gpu per settings.conf) |
| `thermal_protect=off` | Gaming-Deckel **pausiert** (alle drei → Boot-Max); `battery_guard`, `auto_badazz_switch`, `cd_thresholds` bleiben aktiv (echte Schutzschichten) |

**WebUI-Toggles (Einstellungskarte):**
- **"Gold-Cap 1708/2304"**: `an` = `gold_cap_gaming=1708800`, `aus` = `0`
  (=2304 MHz frei) — der bewährte Tuning-Schalter aus den r46–r54-Messungen.
- **"Thermal-Schutz"** pausiert/aktiviert alle drei Deckel in einem Zug.

Live-Verhalten: `cfg_load` läuft pro Tick und `_apply_caps_gaming` ist
idempotent — Reaktionszeit bei mode=gaming ≈ 2 s (SLEEP=2 seit v1.5.2); beim Wechsel Daily→
wird eh auf Boot-Max restauriert.
