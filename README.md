# k6a-ctl

Slim Gaming-Governor-Begleitmodul für **BadazzKernel** (sweet / SM7150-Klasse).
Paart sich mit dem In-Kernel-Governor [`k6a_gov`](https://github.com/vandalsquad187/BadazzKernel) —
ist dieser vorhanden, delegiert k6a-ctl den Thermal-Cooldown an den Kernel; ohne ihn
fällt das Modul automatisch auf einen bewährten Userspace-Cooldowner zurück.

> ⚠️ Empfohlener Kernel: [vandalsquad187/BadazzKernel](https://github.com/vandalsquad187/BadazzKernel) v1.0.8+

---

## Features

- **Auto-Delegation** — erkennt `/sys/kernel/k6a_gov/` zur Laufzeit:
  der Kernel übernimmt Cooldown-Enforcement, das Modul Boost/Pinning/Monitoring
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
- **Single-Instance-Lock** — atomares mkdir-Lock mit crash-sicherer Stale-Recovery
- **Akku-freundliches Tick-Raster** — DAILY: 5s / GAMING: 1s / COOLDOWN: 2s

---

## Aufbau

```
k6a-ctl/
├── module.prop              id=k6a-ctl, v1.0.0
├── service.sh               Boot-Setup + Controller-Watchdog + WebUI-Server-Spawn
├── build.sh                 Gate-Pflicht + ZIP-Assembly
├── bin/
│   ├── check_module.sh      Build-Gate: 5 Checks vor jedem Zip
│   ├── k6a-lib.sh           schlanke HW-Schicht: unalias r, dynamische Tables, Zonen
│   ├── k6a-controller       State Machine OFF/GAMING/CD_L2-L4 + Hysterese + Backoff
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

Der Controller läuft als Daemon mit adaptivem Tick-Raster und kennt fünf Zustände:

| Zustand | Trigger | Tick | Wirkung |
|---------|---------|------|---------|
| `DAILY` | mode=daily oder Start | 5s | Monitoring-only, keine Caps |
| `GAMING` | mode=gaming | 1s | Pinning (RenderThread→Gold), Props, IRQ |
| `CD_L2` | ≥88°C | 2s | Gold auf ~90% des Max, GPU ~70% |
| `CD_L3` | ≥92°C | 2s | Gold ~70%, GPU ~44% |
| `CD_L4` | ≥95°C | 2s | Gold ~58%, GPU ~33% (Notbremse) |

Recover: unter `cd_recover` (80°C) zurück zu GAMING. Die Hysterese misst den
Temp-Anstieg pro Tick: steil (>5°/Tick) → kurzes Dwell, sonst langes Dwell —
verhindert Flattern um die Schwelle.

### Delegation (Auto-Erkennung)

Beim Start prüft der Controller `/sys/kernel/k6a_gov/`:

- **vorhanden** → Cooldown-Enforcement delegiert an den Kernel; das Modul schreibt
  nur `enable`/`profile`, setzt Userspace-Caps spiegelnd zum Kernel-State ein
  und übernimmt Pinning/Props/Monitoring
- **fehlt** → legacy userspace-cooldown (eigene State Machine + direkte Freq-Caps)

### Config-Hot-Reload

`settings.conf` wird jede Runde neu gelesen — Änderungen wirken ohne Neustart.
Die Datei ist die **einzige Quelle der Wahrheit**; Kommentare (`#`) sind erlaubt.

---

## Synergie mit k6a_gov (BadazzKernel)

Der In-Kernel-Governor und dieses Modul teilen sich die Arbeit nach dem Prinzip
**„Kernel entscheidet WANN, Modul setzt WIE um, beide nutzen dieselben Schwellen"**:

| Aufgabe | Kernel (k6a_gov) | Modul (k6a-ctl) |
|---------|------------------|------------------|
| Thermal-Trips raise/disable | ✔ (v1.0.8+) | nur im Legacy-Fallback |
| Cooldown L2-L4 State Machine | ✔ (250ms-Kthread, Hz-basiert) | Fallback + Spiegel |
| GPU thermal floor | – (bewusst entfernt: Hard-Hang-Verdächtiger) | – |
| CPU max enforcement während CD | ✔ cpufreq-notifier | identische % -Caps (Sicherheitsnetz) |
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

> Hinweis: Für die Delegations-Stufe wird BadazzKernel mit `CONFIG_K6A_GOV=y`
> (v1.0.8+, Celsius-Thresholds) empfohlen. Ohne ihn läuft der Legacy-Fallback.

## Konfiguration

`/data/adb/modules/k6a-ctl/config/settings.conf` — hot-reload, Kommentare erlaubt:

| Key | Default | Bedeutung |
|-----|---------|-----------|
| `mode` | `gaming` | `gaming` / `daily` |
| `thermal_protect` | `on` | `on` / `off` |
| `game_pkg` | CODM | Package für Thread-Pinning |
| `cd_l2_temp` … `cd_l4_temp` | 80/82/88 | Cooldown-Eingriffe (°C) |
| `cd_recover` | 76 | Recover unterhalb (°C) |
| `hysteresis_fast` / `_normal` | 3/10 | Dwell-Zyklen |
| `cd_*_gold_pct` | 90/70/58 | Gold-Caps als % vom Geräte-Max |
| `cd_*_gpu_pct` | 70/44/33 | GPU-Caps als % vom Geräte-Max |

## Manuelle Steuerung

```sh
# Mode via localhost-endpoint
printf 'GET /mode?m=gaming HTTP/1.0\r\n\r\n' | nc 127.0.0.1 8767

# oder direkt in der config
su -c "sed -i 's/^mode=.*/mode=daily/' /data/adb/modules/k6a-ctl/config/settings.conf"
```

## Troubleshooting

```sh
tail -f /data/adb/modules/k6a-ctl/config/service.log   # Events + Heartbeat
cat /data/adb/modules/k6a-ctl/webroot/data.txt          # Live-Werte
sh /data/adb/modules/k6a-ctl/bin/check_module.sh .      # Gate manuell
dmesg | grep k6a_gov                                    # Kernel-Seite
```

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
