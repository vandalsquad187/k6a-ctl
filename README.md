# k6a-ctl

Slim Gaming-Governor-Begleitmodul für **BadazzKernel** (sweet / SM7150-Klasse).
Paart sich mit dem In-Kernel-Governor [`k6a_gov`](https://github.com/vandalsquad187/BadazzKernel) —
ist dieser vorhanden, delegiert k6a-ctl den Thermal-Cooldown an den Kernel; ohne ihn
fällt das Modul automatisch auf einen bewährten Userspace-Cooldowner zurück.

> ⚠️ Empfohlener Kernel: [vandalsquad187/BadazzKernel](https://github.com/vandalsquad187/BadazzKernel)
> v4.14.369 **build341**+ (`k6a_gov` v1.5.0 als **Modul**, `CONFIG_K6A_GOV=m`).
> Build 340+ bringt die Cap-/BW-Release (`policy_max`, `temp_src`), ab 341 wird
> der Governor per `insmod` geladen und ist ohne Kernel-Flash nachrüstbar.
> Ältere Kernel laufen, verlieren aber die Live-Cap-/BW-Statuswerte.

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

## Features

- **Drei Modi** — `daily` (Akku schonen) ↔ `gaming` (Leistung) ↔ `auto`
  (Spielerkennung: `pidof` + `/proc/<pid>/cgroup` top-app-Zugehörigkeit;
  Hysterese 2 Bestätigungs-Ticks rein, 10 s ohne top-app raus → `daily`),
  per WebUI `/mode?m=…` oder Config
- **Gold-Cluster-Deckelung pro Modus** — `gold_cap_gaming` / `gold_cap_daily`
  begrenzen `scaling_max_freq` der A76 auf die nächstgelegene verfügbare OPP.
  Kernbefund 2026-10 (COD Mobile, SD732G): die Last ist bandbreiten-/wärmelimitiert,
  nicht cpu-limitiert — 1708800 Hz (−26 %) steigerte die Bildrate messbar,
  weil der Speicher kühler bleibt und seine Timings hält
- **Persistente Schwellwerte** — `cd_thresholds` wird beim Start neu angewendet,
  überlebt also Reboot und Modul-Neustart. Reihenfolge `l2t l3t l4t rec l2g l3g l4g`
  ist durch den Kernel fix (rec zuerst → `-EINVAL`, still abgelehnt)
- **Schedutil-Tuning pro Modus** — gaming: `up=500 down=20000 hispeed_load=50`,
  daily: `up=10000 down=50000`. Der Unterschied ist messbar: mit
  `down_rate_limit=1000` sackte die Taktrate mitten im Frame bis auf 0,81 GHz
- **Auto-Delegation** — erkennt `/sys/kernel/k6a_gov/` zur Laufzeit:
  der Kernel übernimmt Cooldown-Enforcement, das Modul Boost/Monitoring
- **Auto-Ladung des Governors** — `service.sh` hängt `k6a_gov.ko` per `insmod`
  (Suchreihenfolge Modulordner → `/data/adb` → `/system/lib/modules` →
  `/vendor/lib/modules`) und fällt bei jedem Fehler still auf den Legacy-Cooldown zurück
- **Version-Lock (dynamisch)** — `service.sh` (Loader) und der Controller-Runtime-Check
  akzeptieren k6a_gov 1.5.x–1.9.x (`kver_ok` `1.[5-9].*`); GOV_KO_VER ist nur noch
  Protokollausgabe. Vom Gate erzwungen; weicht die `version=` des `.ko` bzw. der
  geladenen Laufzeit ab, wird nicht geladen (bzw. `rmmod`)
- **Hash-Status statt Bool** — `hash_state` (0 pending / 1 verified / 2 mismatch /
  3 nicht geprüft) aus `/sys/kernel/k6a_gov/status`, in `data.txt` und WebUI gespiegelt;
  `hash_verified` bleibt aus Kompatibilitätsgründen erhalten
- **SELinux-Freigabe für die Hash-Prüfung** — `sepolicy.rule` gewährt
  `kernel → sysfs {dir,file}` die Leserechte. Ohne sie ist der `k6a_gov`-Kthread
  (SID `u:r:kernel:s0`) an jedem sysfs-Open gescheitert und `hash_state` blieb
  dauerhaft `3`; `service.sh` selbst (`u:r:ksu:s0`) darf sysfs ohnehin lesen
- **Single Authority** — k6a-ctl schreibt ausschließlich `legacy`; im Delegationsmodus
  `legacy=1` (Kernel erzwingt Caps), sonst `legacy=0` (Kernel gibt alle Caps frei).
  Kein konkurrierendes Schreiben von `scaling_max_freq`/`bw_floors` mehr
- **Akku-Guard Toggle** — `/battguard?e=0|1` + `battery_guard` in der Config, Schwelle
  via `/battguard?t=35..60` (beides `settings.conf`-hot-reload, kein Flash)
- **Korrekte BW-Floor-Reihenfolge** — Payload ist jetzt `gpubw_L2 L3 L4 llcc_L2 L3 L4`,
  exakt wie der Kernel sie parst (`sscanf("%u %u %u %u %u %u")`)
- **Live-Status Build 340** — `policy_max`, `state_age_ms`, `temp_src`, `temp_valid`,
  `game_pid`, `battery_guard` aus dem Kernel gelesen und in `data.txt` / WebUI gespiegelt
- **Legacy-Fallback** — vollständige Userspace-State-Machine (CD_L2/L3/L4 + Recover)
  mit adaptiver Hysterese, falls kein In-Kernel-Governor vorhanden ist
- **Dynamische Clock-Tables** — liest `scaling_available_frequencies` zur Laufzeit,
  null hardcodierte Frequenzen, funktioniert auf jeder Kernel-Variante
- **Cooldown mit adaptiver Hysterese** — steiler Temp-Anstieg (+5°/Tick) → kurzes Dwell,
  sonst normales Dwell; Schwellen konfigurierbar
- **Localhost-WebUI-Transport** — `nc -L :8767` Control-Server mit Whitelist-Endpoints,
  immun gegen KernelSU-Bridge-Änderungen, aus jedem Browser bedienbar
- **Gesplittete WebUI** — `index.html` + `app.js` + `style.css`, kein Monolith
- **Build-Gate** — `check_module.sh` verweigert kaputte Zips: Shell-Syntax, JS-Duplikat-Scan,
  Bracket-Balance, Thermal-Zonen-Dryrun, Config-Sanity, mksh-`r`-Alias-Schattenprüfung
  *(prüft vor dem Packen — `build.sh` schließt die Datei bewusst aus der ZIP aus)*
- **Single-Instance-Lock** — atomares mkdir-Lock mit crash-sicherer Stale-Recovery
- **Akku-freundliches Tick-Raster** — DAILY: 5s / GAMING: 1s / COOLDOWN: 2s

---

## Aufbau

```
k6a-ctl/
├── module.prop              id=k6a-ctl, v1.4.4
├── service.sh               k6a_gov.ko laden (Version-Lock) + Watchdog + WebUI-Spawn
├── build.sh                 Gate-Pflicht + ZIP-Assembly
├── bin/
│   ├── check_module.sh      Build-Gate: Checks vor jedem Zip
│   ├── k6a-lib.sh           schlanke HW-Schicht: unalias r, dynamische Tables, Zonen
│   ├── k6a-controller       State Machine DAILY/GAMING + gold/silver/gpu-Deckel (idempotent) + Schwellwerte
│   ├── webui-server.sh      nc-Listener :8767 (127.0.0.1 only)
│   └── webui-handler.sh     Whitelist-Request-Handler (/mode /thermal /goldcap /profile /delegated /bw_floors /battguard /ping)
├── config/settings.conf     EINZIGE Quelle der Wahrheit (hot-reload)
└── webroot/
    ├── index.html           Markup
    ├── style.css            Theme
    └── app.js               Polling (data.txt) + Beacon-Writes (:8767)
```

### Komponenten-Interaktion

```
   KernelSU Manager ──öffnet──▶ WebUI (app.js)
                                   │  liest: data.txt (relativ, alle 2s)
                                   │  schreibt: Image-Beacon ──▶ ┐
   CODM / Game-Prozess ◀── pinning │                            ▼
   k6a_gov (Kernel)    ◀─enable── k6a-controller ◀── webui-handler (:8767)
        │                          ▲         ▲
        └── cooldown enforcement   │         └── settings.conf (hot-reload)
                                   service.sh (Watchdog, Backoff, Stale-Guard)
```

---

## Funktion

### State Machine

Der Controller läuft als Daemon mit adaptivem Tick-Raster und kennt zwei Modi
plus die Kernel-Cooldown-Zustände (nur im Legacy-Fallback):

| Zustand | Trigger | Tick | Wirkung |
|---------|---------|------|---------|
| `DAILY` | mode=daily | 5s | Monitoring, `gold_cap_daily`, schedutil daily, Gov aus |
| `GAMING` | mode=gaming | 1s | `gold_cap_gaming`, Schwellwerte, schedutil gaming, Gov an, Props |
| `CD_L2`–`CD_L4` | ≥ `l2t`/`l3t`/`l4t` | – | mit `k6a_gov`: kernel-seitig; ohne: Userspace-Fallback |

### Delegation (Auto-Erkennung)

Beim Start prüft der Controller `/sys/kernel/k6a_gov/`:

- **vorhanden** → Cooldown-Enforcement delegiert an den Kernel; das Modul schreibt
  nur `enable`/`profile`, setzt Userspace-Caps spiegelnd zum Kernel-State ein
  und übernimmt Pinning/Props/Monitoring
- **fehlt** → legacy userspace-cooldown (eigene State Machine + direkte Freq-Caps)

### Config-Hot-Reload

`settings.conf` wird jede Runde neu gelesen — Änderungen wirken ohne Neustart.
Die Datei ist die **einzige Quelle der Wahrheit**; Kommentare (`#`) sind erlaubt.

### Governor: schedutil erzwingen (F1)

`init.qcom.post_boot.sh` schreibt an Policy 0/6 den nicht existierenden Governor
`reflex`; der Kernel fällt dadurch auf `CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE`
zurück. `scaling_max_freq` wird dann respektiert, aber **nie heruntergesetzt** —
`performance` senkt `policy->max` nie ab, deshalb skaliert das System im Idle
nicht aus, und die Tunables unter `$P6/schedutil/` existieren nicht einmal.

`_ensure_gov()` (k6a-lib.sh) setzt beide Policies idempotent auf `schedutil`
und läuft beim Start sowie vor jeder State-Verarbeitung im Tick. Schreibfehler
werden über `w_checked()` geloggt; bleibt `$P6/schedutil/` danach aus, meldet
das die Lib einmalig statt still zu scheitern.

### Hot-Path-Kosten

- `settings.conf` wird pro Tick **einmal** statt zehnmal gelesen (`cfg_load`)
- **`taskset` ist entfernt** (v1.4.0) — Androids cpuset-Controller setzt die
  Affinität ohnehin zurück; der Loop über alle Threads kostete Zeit und bewirkte nichts
- Thread-`renice`/`oom_adj` nur bei State-Entry und alle 60 Ticks, nicht alle 5
- `setprop` nur bei tatsächlichem Wertwechsel
- `read_temp` liefert ohne lesbare Zone leer („--") statt eines erfundenen 40 °C
- fehlgeschlagene Schreibzugriffe werden geloggt statt ignoriert (`w_checked`)
- `k6a_gov.ko`: Kandidat mit passender Version wird gewählt, statt beim ersten
  vorhandenen (ggf. falschen) stehen zu bleiben

---

## Synergie mit k6a_gov (BadazzKernel)

Der In-Kernel-Governor und dieses Modul teilen sich die Arbeit nach dem Prinzip
**„Kernel entscheidet WANN, Modul setzt WIE um, beide nutzen dieselben Schwellen"**:

| Aufgabe | Kernel (k6a_gov) | Modul (k6a-ctl) |
|---------|------------------|------------------|
| Thermal-Trips raise/disable | ✔ (v1.0.8+) | nur im Legacy-Fallback |
| Cooldown L2-L4 State Machine | ✔ (250ms-Kthread, Hz-basiert) | Fallback + Spiegel |
| GPU thermal floor | – (bewusst entfernt: Hard-Hang-Verdächtiger) | – |
| CPU max enforcement während CD | ✔ cpufreq-notifier | **nur im Legacy-Modus** (Sicherheitsnetz) |
| BW-Floors (`gpubw`/`llcc`) | ✔ `bw_floors` (Build 340 release-fähig) | schreibt nur im Legacy-Modus |
| `legacy` (Single Authority) | ✔ | **✔ einziger Schreiber** |
| `battery_guard` / `_temp` | ✔ (Eingreifen bei 45 °C, default **aus**) | schreibt Config-Wert |
| `game_pid` | speichert/echoed, wirkt nie darauf | ✔ `pidof $game_pkg` |
| OFF→GAMING Aktivierung | ✔ (v1.0.5+) | schreibt nur enable/profile |
| Input-Boost + Schedutil-Tunables | – | ✔ einmalig pro Moduswechsel |
| RenderThread-Pinning (taskset/chrt) | – (braucht PID/comm-Scan) | ✔ alle 5 Ticks in GAMING |
| Props (game_mode/vulkan/fps) | – | ✔ bei GAMING-Start |
| IRQ affinity | – | ✔ einmalig bei GAMING-Start |
| Monitoring/WebUI/data.txt | – | ✔ |

**Handshake beim Boot:** existiert `/sys/kernel/k6a_gov/` → Delegationsmodus;
sonst Legacy. Der Wechsel ist jederzeit möglich — der Not-Aus ist immer
`echo 0 > /sys/kernel/k6a_gov/enable` bzw. `mode=daily`.

**Warum diese Aufteilung:** Kernel-seitige Enforcement ist race-free gegen
GameTurbo/msm_thermal und kostet kein Userspace-Polling. Userspace behält,
was Prozesskontext braucht (PID-Scans, props). Der Blackscreen-Vorfall von
v1.0.5 (GPU-Floor-Writes aus Notifier-Kontext) führte zur Trennung:
seit v1.0.6 macht der Kernel bewusst **CPU-only**.

---

## Installation

1. ZIP aus [Releases](https://github.com/vandalsquad187/k6a-ctl/releases) laden
   (oder selbst bauen: `sh build.sh` — das Gate muss grün sein)
2. Via KernelSU Next / Magisk flashen
3. Reboot — Controller + WebUI-Server starten automatisch

> Hinweis: Für die Delegations-Stufe wird BadazzKernel v4.14.369 **build341**+
> (`CONFIG_K6A_GOV=m`, `k6a_gov` v1.5.0) empfohlen. Ab 341 liefert das Kernel-ZIP
> `k6a_gov.ko` nach `/data/adb/k6a_gov.ko`; `service.sh` lädt es beim Boot und
> weigert sich bei Versionsabweichung. Ohne Governor läuft der Legacy-Fallback.
> `bin/check_module.sh` ist **Build-Gate, kein Modul-Tool** — `build.sh` lässt sie
> absichtlich aus der ZIP aus. Manuell prüfen: `sh bin/check_module.sh <Repo>`.

## Konfiguration

`/data/adb/modules/k6a-ctl/config/settings.conf` — hot-reload, Kommentare erlaubt:

| Key | Default | Bedeutung |
|-----|---------|-----------|
| `mode` | `gaming` | `gaming` / `daily` — einziger Schalter, sonst nichts |
| `thermal_protect` | `on` | v1.4.3 **wirksam**: `on` = Gaming-Deckel aktiv (gold/silver/gpu per settings.conf), `off` = Deckel pausiert (→ Boot-Max); `battery_guard`, `auto_badazz_switch`, `cd_thresholds` bleiben unabhängig aktiv |
| `delegated` | `1` | `1` = Kernel-Governor erzwingt (`legacy=1`), `0` = reines Userspace (`legacy=0`) |
| `profile` | `custom` | `gaming` / `battery` / `badazz` / `badazz_safe` / `custom` — `custom` behält die `cd_thresholds` |
| `gold_cap_gaming` | 1708800 | Gold-Cluster-Deckelung im Gaming-Modus (Hz, `0` = frei) — WebUI-Toggle „Gold-Cap 1708/2304" |
| `silver_cap_gaming` | 0 | v1.4.2: Silver-Cluster (policy0) Deckel während GAMING (Hz, `0` = Boot-Max) |
| `gpu_cap_gaming` | 0 | v1.4.2: GPU (kgsl `devfreq/max_freq` + `max_gpuclk`) Deckel während GAMING (Hz, `0` = Boot-Max 800 MHz) |
| `gold_cap_daily` | 1555200 | dasselbe im Daily-Modus |
| `cd_thresholds` | 96 99 102 93 1708800 1555200 1324800 | `l2t l3t l4t rec l2g l3g l4g` — Reihenfolge kernel-fix, wird beim Start idempotent angewendet (seit build352 = Kernel-GAMING-Default) |
| `game_pkg` | CODM | Package für renice/oom-Boost |
| `battery_guard` | `on` | Akku-Guard an/aus → `/sys/kernel/k6a_gov/battery_guard` (0/1) |
| `battery_guard_temp` | 45 | Akku-Guard-Schwelle (35–60 °C) |
| `auto_badazz_temp` / `_hyst` | 95 / 5 | nur wirksam bei `profile=gaming` |

> Legacy-Keys (`cd_l2_temp` … `cd_*_pct`, `hysteresis_*`) greifen nur ohne
> In-Kernel-Governor. Mit `k6a_gov` sind die Schwellen kernel-seitig.

## Manuelle Steuerung

```sh
# Mode via localhost-endpoint
printf 'GET /mode?m=gaming HTTP/1.0\r\n\r\n' | nc 127.0.0.1 8767

# Gold-Cap-Toggle (v1.4.3): on = 1708800, off = 0 (=2304 frei)
printf 'GET /goldcap?g=on HTTP/1.0\r\n\r\n' | nc 127.0.0.1 8767
printf 'GET /goldcap?g=off HTTP/1.0\r\n\r\n' | nc 127.0.0.1 8767

# Thermal-Protect (v1.4.3 wirksam): Deckel aktiv/pausiert
printf 'GET /thermal?t=on HTTP/1.0\r\n\r\n' | nc 127.0.0.1 8767

# Akku-Guard: Schwelle 35..60 °C bzw. an/aus
printf 'GET /battguard?t=48 HTTP/1.0\r\n\r\n' | nc 127.0.0.1 8767
printf 'GET /battguard?e=0 HTTP/1.0\r\n\r\n' | nc 127.0.0.1 8767

# oder direkt in der config
su -c "sed -i 's/^mode=.*/mode=daily/' /data/adb/modules/k6a-ctl/config/settings.conf"
```

## Troubleshooting

```sh
tail -f /data/adb/modules/k6a-ctl/config/service.log   # Events + Heartbeat
cat /data/adb/modules/k6a-ctl/webroot/data.txt          # Live-Werte (gov_* = Build340/341-Keys)
sh <repo>/bin/check_module.sh .                         # Gate manuell (Repo-Seite, nicht in der ZIP)
dmesg | grep k6a_gov                                    # Kernel-Seite
grep k6a_gov /data/adb/modules/k6a-ctl/config/service.log   # insmod-Ergebnis + Version-Lock
ls -l /data/adb/k6a_gov.ko                              # kam das Modul beim Flashen an?
```

Werte-Abgleich nach einem Kernel-Flash (Build 341 erwartet):

```sh
su -c "cat /sys/kernel/k6a_gov/status | grep -E 'version|hash_state|policy_max|temp_src|temp_valid'"
#   version=1.5.0  hash_state=1
#   policy_max=...  state_age_ms=...  temp_src=1  temp_valid=1
su -c "cat /sys/kernel/k6a_gov/legacy"      # im Delegationsmodus erwartet: 1
su -c "cat /sys/kernel/k6a_gov/game_pid"    # Spiel gestartet? sonst 0
```

`hash_state=3` („nicht geprüft") statt `1`: die Hash-Prüfung läuft im Kernel-Thread
`k6a_gov`, dessen SELinux-Domäne `u:r:kernel:s0` **keinen** Zugriff auf sysfs-Dateien hat
(`kernel → sysfs:file allowed = 0`). `sepolicy.rule` im Modulordner behebt das beim nächsten
Boot — nach dem Anwenden der Regel:
`echo 'u:r:kernel:s0 u:object_r:sysfs:s0 6' > /sys/fs/selinux/access; cat /sys/fs/selinux/access`
muss `40012` statt `0` liefern (read+open+getattr).

Bekannte Falle (hier gefixt, trotzdem merken): **mksh definiert `alias r='fc -e -'`**.
Eine Library, die eine Funktion `r()` ohne vorheriges `unalias r` definiert, wird
stumm verschattet — jeder Aufruf wird zum History-Replay-Fehler. Das Gate prüft darauf.

---

## Lizenz & Credits

Persönliches Projekt, keine Garantie — flashen auf eigene Verantwortung.

BadaZz89 ([@vandalsquad187](https://github.com/vandalsquad187)) — Kernel & Konzept.
Entwickelt und gefestigt in einer langen gemeinsamen Debug-Session: von
„ein doppeltes `const` tötete die komplette WebUI" bis zu einem validierten
In-Kernel-Governor-Stack mit 290+ nachgewiesenen Cooldown-Eingriffen.

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
idempotent — Reaktionszeit bei mode=gaming ≈ 1 s; beim Wechsel Daily→
wird eh auf Boot-Max restauriert.
