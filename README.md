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

---

## Features

- **Zwei Modi, sonst nichts** — `daily` (Akku schonen) ↔ `gaming` (Leistung),
  per WebUI `/mode?m=…` oder Config. Keine Auto-Spielerkennung, jeder Modus
  ist ein stimmiges Gesamtpaket
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
- **Version-Lock** — `GOV_KO_VER` in `service.sh` und die `1.5.*`-Erwartung im Controller
  sind gepaart und vom Gate erzwungen; weicht die `version=` des `.ko` bzw. der
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
├── module.prop              id=k6a-ctl, v1.4.0
├── service.sh               k6a_gov.ko laden (Version-Lock) + Watchdog + WebUI-Spawn
├── build.sh                 Gate-Pflicht + ZIP-Assembly
├── bin/
│   ├── check_module.sh      Build-Gate: Checks vor jedem Zip
│   ├── k6a-lib.sh           schlanke HW-Schicht: unalias r, dynamische Tables, Zonen
│   ├── k6a-controller       State Machine DAILY/GAMING + Gold-Cap + Schwellwerte
│   ├── webui-server.sh      nc-Listener :8767 (127.0.0.1 only)
│   └── webui-handler.sh     Whitelist-Request-Handler (/mode /thermal /ping)
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
| `thermal_protect` | `on` | `on` / `off` |
| `delegated` | `1` | `1` = Kernel-Governor erzwingt (`legacy=1`), `0` = reines Userspace (`legacy=0`) |
| `profile` | `custom` | `gaming` / `battery` / `badazz` / `badazz_safe` / `custom` — `custom` behält die `cd_thresholds` |
| `gold_cap_gaming` | 1708800 | Gold-Cluster-Deckelung im Gaming-Modus (Hz, `0` = frei) |
| `gold_cap_daily` | 1555200 | dasselbe im Daily-Modus |
| `cd_thresholds` | 93 96 99 90 1708800 1555200 1324800 | `l2t l3t l4t rec l2g l3g l4g` — Reihenfolge kernel-fix, wird beim Start angewendet |
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
