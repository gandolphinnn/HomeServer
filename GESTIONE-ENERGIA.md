# Gestione energia — accendere e spegnere NAS e NUC

*Creato: 1 agosto 2026, aggiornato 2 agosto — WoL ✅, spegnimenti via SSH ✅ (setup 1-2) e watchdog ✅ (setup 3, testato sul campo: timer intervenuto da solo). Resta il setup 4 (autoshutdown su OMV).*

**Politica scelta: il NAS segue il NUC**, applicata da entrambi i lati:
- lato NUC, il **watchdog `nas-autowake`** risveglia il NAS se lo trova spento (e sistema mount + container);
- lato NAS, il **check IP dell'autoshutdown punta al solo NUC**: finché il NUC risponde al ping, il NAS non prova nemmeno a spegnersi. A NUC spento, il NAS si spegne da solo dopo ~18 min senza attività.

Ordine sempre: **accensione NAS → NUC, spegnimento NUC → NAS** (gli script lo rispettano da soli).

## I pezzi

| Pezzo | Dove | Cosa fa | Stato |
|---|---|---|---|
| `sveglia-nas.ps1`, `sveglia-nuc.ps1` | `D:\Personale\HomeServer` | accensione via Wake-on-LAN + attesa risposta | ✅ testati 1/8 |
| `spegni-nas.ps1`, `spegni-nuc.ps1` | `D:\Personale\HomeServer` | shutdown pulito via SSH | ✅ operativi (setup 1-2 fatti il 2/8) |
| `hs` | `C:\Users\Luca\Commands` (nel PATH) | comando rapido: `hs`, `hs on/off [nas\|nuc]`, `hs conn nas/nuc` (SSH), `hs help` | ✅ completo |
| `Accendi server.cmd`, `Spegni server.cmd` | Desktop | doppio click, sequenza nell'ordine giusto | ✅ |
| watchdog `nas-autowake` | NUC (systemd timer, ogni 2 min) | NAS giù? lo sveglia. Share smontato? monta e riavvia i container | ✅ attivo e testato 2/8 |
| plugin `autoshutdown` | NAS (web UI OMV) | spegne il NAS quando il NUC è spento e non c'è attività da ~18 min | ⬜ setup 4 |

## Uso quotidiano

```
hs                  stato delle due macchine
hs on               accende tutto (NAS, poi NUC)
hs off              spegne tutto (NUC, poi NAS)
hs on nas           accende solo il NAS (es. per usare G: dal PC senza NUC)
hs off nuc          spegne solo il NUC (il NAS si spegnerà da solo con l'autoshutdown)
hs conn nas         apre una sessione SSH sul NAS (root); idem: hs conn nuc (luca)
```

`hs on nuc` pretende il NAS acceso e `hs off nas` pretende il NUC spento: `-f` **sul singolo host** per ignorare il controllo (su `hs on`/`hs off` completi non si applica). L'output di `hs` e degli script è in inglese; chiamando gli script direttamente il flag è `-Force`. In alternativa: doppio click su `Accendi server.cmd` / `Spegni server.cmd` sul Desktop.

---

## Setup una tantum

### 1. Chiavi SSH dal PC (serve per gli spegnimenti)

Con la chiave, gli script entrano su NUC e NAS senza chiedere password. Da PowerShell sul PC:

```powershell
ssh-keygen -t ed25519
```

Premi Invio a tutte le domande (percorso di default, passphrase vuota). **Se dice che il file esiste già, rispondi `n`** (non sovrascrivere) e prosegui: la chiave c'è già. Poi autorizzala sulle due macchine (chiederanno la password un'ultima volta) — il `tr` lato remoto ripulisce i caratteri invisibili (CRLF/BOM) che il pipe di Windows può aggiungere e che renderebbero la chiave inutilizzabile in modo silenzioso:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh luca@192.168.1.171 "mkdir -p ~/.ssh && tr -d '\r\357\273\277' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@192.168.1.17 "mkdir -p ~/.ssh && tr -d '\r\357\273\277' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

Verifica (NON devono chiedere la password):

```powershell
ssh luca@192.168.1.171 hostname
ssh root@192.168.1.17 hostname
```

### 2. NUC: comandi amministrativi senza password per `luca`

Regola sudo ristretta ai soli comandi che servono agli script: lo spegnimento e lo stop/start del timer del watchdog. Da `ssh luca@192.168.1.171`:

```bash
echo 'luca ALL=(root) NOPASSWD: /usr/sbin/poweroff, /usr/bin/systemctl stop nas-autowake.timer, /usr/bin/systemctl start nas-autowake.timer' | sudo tee /etc/sudoers.d/homeserver >/dev/null
sudo chmod 440 /etc/sudoers.d/homeserver
sudo visudo -cf /etc/sudoers.d/homeserver
```

L'ultimo comando deve dire `parsed OK`. Test non distruttivo dal PC: `ssh luca@192.168.1.171 "sudo -n /usr/sbin/poweroff --help"` deve stampare l'aiuto del comando senza chiedere password.

### 3. NUC: watchdog `nas-autowake`

Al boot e poi ogni 2 minuti: se il NAS non risponde lo sveglia via WoL; se lo share non è montato (tipico: NUC partito col NAS spento) lo monta e riavvia i container che lo usano. Se è tutto a posto non fa e non logga nulla.

Da `ssh luca@192.168.1.171`, un blocco alla volta:

```bash
sudo apt update && sudo apt install -y wakeonlan
```

Lo script (il `tee` scrive il file; incolla tutto il blocco in una volta):

```bash
sudo tee /usr/local/sbin/nas-autowake.sh >/dev/null <<'EOF'
#!/bin/bash
# Politica: il NAS segue il NUC. Vedi D:\Personale\HomeServer\GESTIONE-ENERGIA.md sul PC.
NAS_IP="192.168.1.17"
NAS_MAC="3C:D9:2B:0C:F3:87"
SHARE="/srv/media"
COMPOSE_DIRS="/home/luca/docker/jellyfin /home/luca/docker/immich"
LOG="logger -t nas-autowake"

nas_su()  { ping -c1 -W2 "$NAS_IP" >/dev/null 2>&1; }
smb_su()  { timeout 2 bash -c "</dev/tcp/$NAS_IP/445" 2>/dev/null; }
montato() { findmnt -rn "$SHARE" >/dev/null; }   # non usare mountpoint(1): fa stat e puo' bloccarsi su CIFS stale

# Caso normale: share montato e NAS raggiungibile -> niente da fare
if montato && nas_su; then
    exit 0
fi

# NAS giu' -> Wake-on-LAN (rimandato ogni ~40s) e attesa SMB, max ~5 minuti
if ! smb_su; then
    $LOG "NAS non raggiungibile: invio Wake-on-LAN a $NAS_MAC"
    ok=0
    for i in $(seq 1 43); do   # 43 giri x ~7s (timeout 2s + sleep 5s) = ~5 min
        if smb_su; then ok=1; break; fi
        [ $(( (i - 1) % 6 )) -eq 0 ] && wakeonlan "$NAS_MAC" >/dev/null
        sleep 5
    done
    if [ "$ok" -ne 1 ]; then
        $LOG "NAS ancora giu' dopo ~5 minuti: rinuncio (ritento al prossimo giro)"
        exit 1
    fi
    $LOG "NAS sveglio, SMB raggiungibile"
fi

# Se il mount c'era gia': la sessione CIFS (soft) si ristabilisce da sola, stop qui
if montato; then
    $LOG "share gia' montato: la sessione CIFS si riconnette da sola"
    exit 0
fi

# Share non montato -> mount da fstab + riavvio dei container che lo usano
sleep 5   # margine: samba appena partito
if ! mount "$SHARE"; then
    $LOG "mount di $SHARE fallito: ritento al prossimo giro"
    exit 1
fi
$LOG "share montato: riavvio i container"
for d in $COMPOSE_DIRS; do
    docker compose --project-directory "$d" restart >/dev/null 2>&1 && $LOG "riavviato: $d"
done
$LOG "fatto"
exit 0
EOF
sudo chmod +x /usr/local/sbin/nas-autowake.sh
```

Le unit systemd (service + timer):

```bash
sudo tee /etc/systemd/system/nas-autowake.service >/dev/null <<'EOF'
[Unit]
Description=Sveglia il NAS e monta lo share se serve
Wants=network-online.target
After=network-online.target docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/nas-autowake.sh
EOF
sudo tee /etc/systemd/system/nas-autowake.timer >/dev/null <<'EOF'
[Unit]
Description=Controllo periodico NAS (nas-autowake)

[Timer]
OnBootSec=45s
OnUnitActiveSec=2min
AccuracySec=10s

[Install]
WantedBy=timers.target
EOF
```

Ordine di avvio al boot: Docker deve partire DOPO il tentativo di mount di `/srv/media`, altrimenti (rara sfortuna di tempi) i container potrebbero catturare la cartella vuota un attimo prima che il mount arrivi — e il watchdog, vedendo poi tutto montato, non li riavvierebbe mai. Grazie a `nofail` in fstab, se il NAS è spento Docker parte comunque:

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/after-media.conf >/dev/null <<'EOF'
[Unit]
After=srv-media.mount
EOF
```

Attivazione (la riga su ifupdown serve perché con questa gestione di rete Debian NON aspetta la rete di default — senza, al boot il watchdog partirebbe prima che la scheda sia su):

```bash
sudo systemctl daemon-reload && sudo systemctl enable --now nas-autowake.timer
sudo systemctl enable ifupdown-wait-online.service
```

**Test completo**: spegni il NAS — dalla web UI di OMV, oppure dal PC con `hs off nas`: prima si rifiuterà avvisandoti del watchdog (giusto così), rilancia con `hs off nas -f` per spegnerlo davvero. Poi sul NUC:

```bash
sudo systemctl start nas-autowake.service && sudo journalctl -t nas-autowake -n 20 --no-pager
```

Nel giro di 1-3 minuti il log deve raccontare: WoL inviato → NAS sveglio → (share già montato / montato + container riavviati). Prova finale del boot: NAS spento + riavvio del NUC → dopo ~3-5 minuti dev'essere tutto su e funzionante da solo.

### 4. NAS: plugin autoshutdown

Installazione: web UI OMV → **System → Plugins** → cerca `autoshutdown` → installa `openmediavault-autoshutdown` (c'è perché il repo OMV-Extras è già attivo, è quello del flashmemory). Poi **Services → Autoshutdown**.

Configurazione per il nostro scenario (i nomi sono i campi della GUI):

| Campo | Valore | Perché |
|---|---|---|
| Enable | ✅ | |
| Cycles | `6` | 6 cicli × 180 s ≈ **18 min di inattività** prima dello spegnimento |
| Sleep | `180` | intervallo tra i check (è anche la finestra su cui media traffico e I/O) |
| Shutdown command | `Shutdown` | spegnimento completo, non sospensione |
| **IP check** | ✅ | col Range qui sotto è il meccanismo **NAS-segue-NUC lato NAS**: finché il NUC risponde al ping, niente spegnimento |
| **Range** | `192.168.1.171` | ⚠️ **solo l'IP del NUC**. MAI lasciare il default `2..254`: pinga tutta la subnet e chiunque risponda (il PC, il telefono...) terrebbe il NAS acceso per sempre |
| Check sockets | ✅ | |
| Socket numbers | `22` | solo SSH: sessione aperta = niente spegnimento sotto i piedi. **MAI aggiungere 445/139**: la sessione CIFS del NUC è sempre established e bloccherebbe tutto |
| UL/DL check + rate | ✅ + `50` | il rilevatore di attività dal PC: trasferimenti >50 kB/s (mediati su 180 s) tengono su il NAS; i keepalive SMB no |
| HDD I/O check + rate | ✅ + `401` | idem per l'attività disco locale |
| Load average check | ❌ | ridondante per un NAS puro |
| Check CLI | ✅ | utenti loggati (SSH/console) = niente spegnimento |
| Check Samba | ✅ | blocca solo con **file aperti** (lock), non per la sessione idle del mount del NUC — verificato nel codice del plugin |
| Check proc names | ✅, Load proc names `smbd,nfsd`, Temp proc names `-` | smbd conta solo se sta *lavorando* (usa `top -i`), non per la sua semplice esistenza |
| SMART check | ❌ | (riattivalo se un giorno programmi self-test SMART) |
| Plugin check | ❌ | |
| Check clock / Uphours | ❌ | nessuna fascia di uptime forzato |
| Syslog | ✅ | log in `/var/log/autoshutdown.log` e in web UI → Diagnostics → Logs |
| **Fake** | ✅ **per la prima settimana** | dry-run: logga quando *avrebbe* spento, senza spegnere davvero |
| Verbose | ✅ durante il test, poi ❌ | mostra quale check sta bloccando, riga per riga |
| Extra options | `CHECK_SAMBA_CLIENTS="true"` | se il PC viene spento di colpo con file aperti, i suoi lock orfani vengono ignorati (pinga chi detiene il lock) |

Salva e applica la barra gialla. **Non modificare mai `/etc/autoshutdown.conf` a mano**: è generato dalla GUI e viene sovrascritto; i parametri extra vanno nel campo Extra options.

Nota su Check Samba: se in modalità Fake vedessi righe `SMB client(s) with locks` **costanti** provenienti da 192.168.1.171 (= un processo del NUC tiene un file perennemente aperto sullo share), metti Check Samba ❌: restano UL/DL e HDD I/O a proteggere i trasferimenti veri.

**Test in modalità Fake**: guarda i log dalla **web UI** (Diagnostics → Logs → autoshutdown) — non da SSH, altrimenti il check CLI ti vede loggato e il contatore non scende mai. Cosa aspettarsi:
- **con il NUC acceso**: a ogni ciclo il check IP segna positivo su `192.168.1.171` e il contatore si resetta — è la politica NAS-segue-NUC che lavora; il NAS non si spegnerà mai in questo stato;
- **con il NUC spento** (e PC che non trasferisce): i check devono dare esito negativo e il contatore scendere fino a `Shutdown command not executed in FAKE-Mode`.

Quando entrambi i comportamenti sono confermati: togli Fake e Verbose, riapplica.

**Convivenza col watchdog**: grazie al Range puntato sul NUC, l'autoshutdown non tenta mai lo spegnimento finché il NUC è acceso — watchdog e plugin non si pestano i piedi. Il watchdog resta come rete di sicurezza per i casi anomali (boot del NUC a NAS spento, NAS crashato). ⚠️ Se un giorno disattivi il check IP o allarghi il Range, ricontrolla questo equilibrio: con check IP spento, NAS e watchdog entrerebbero in un ciclo spegni/riaccendi ogni ~20 minuti a NUC inattivo.

---

## Scenari — cosa succede quando...

| Situazione | Comportamento |
|---|---|
| `hs on` / doppio click Accendi | NAS sveglio → poi NUC. Ordine garantito |
| NUC acceso per sbaglio prima del NAS (tasto) | il watchdog al boot sveglia il NAS, monta lo share, riavvia i container: si sistema tutto da solo in ~3-5 min |
| NUC acceso ma inattivo per ore | il NAS **resta acceso** (check IP sul NUC): è la politica scelta. Se vuoi risparmiare, spegni il NUC |
| NAS spento/crashato mentre il NUC è su | il watchdog lo risveglia entro 2 min; la sessione CIFS si riconnette da sola |
| `hs off` / doppio click Spegni | NUC giù → poi NAS. Se il NUC non si spegne, il NAS non viene toccato |
| `hs off nuc` e basta | il NAS resta su e si spegne da solo ~18-20 min dopo (check IP negativo + nessuna attività) |
| Uso G: dal PC col NUC spento | `hs on nas`; a fine lavoro non serve fare nulla: autoshutdown |
| Copia file / backup Immich in corso | l'autoshutdown non spegne (traffico >50 kB/s, I/O disco, lock SMB) |
| Voglio il NAS spento col NUC acceso (raro) | `ssh luca@192.168.1.171 "sudo systemctl stop nas-autowake.timer"`, poi `hs off nas -f`; per tornare alla normalità: idem con `start` (i due comandi systemctl sono coperti dalla regola sudoers del setup 2) |

## Trasloco / cambio router — checklist IP

I **MAC non cambiano mai** (NAS `3C:D9:2B:0C:F3:87`, NUC `84:39:BE:6B:55:73`); gli IP sì. Consiglio per il router nuovo: **lease DHCP statici per entrambi i MAC** appena arrivati, così questa checklist si fa una volta sola. Gli IP vivono qui:

- **PC** — `D:\Personale\HomeServer\`: `sveglia-nas.ps1`, `sveglia-nuc.ps1`, `spegni-nas.ps1`, `spegni-nuc.ps1` (variabili `$ip`/`$nas`/`$nuc` in testa) + `C:\Users\Luca\Commands\hs.ps1` (`$nasIp`, `$nucIp`). Se cambia la subnet (non più 192.168.1.x): anche il broadcast `192.168.1.255` dentro i due `sveglia-*.ps1`
- **NUC** — `/etc/fstab` (IP del NAS nella riga CIFS) e `/usr/local/sbin/nas-autowake.sh` (`NAS_IP`)
- **NAS** — web UI OMV → Services → Autoshutdown → **Range** (contiene l'IP del NUC)
- **Windows** — unità di rete `G:` da rimappare se cambia l'IP del NAS
- **Segnalibri/app** — web UI (Jellyfin :8096, Immich :2283, Homarr :7575, Portainer :9443, OMV) puntano all'IP di NUC/NAS; le tile di Homarr contengono gli URL
- **Tailscale** — non c'entra: gli IP `100.x` non dipendono dal router

## Troubleshooting

- **Il WoL non sveglia una macchina**: guarda il LED della porta ethernet a macchina spenta (spento = scheda non armata). NUC: `sudo ethtool enp1s0 | grep Wake-on` deve dire `g` (persistenza: riga `ethernet-wol g` in `/etc/network/interfaces`). NAS: spunta Wake-on-LAN in OMV → Network → Interfaces. Se il LED è acceso ma non si sveglia: BIOS.
- **L'autoshutdown non spegne mai**: riattiva Fake+Verbose e guarda i log dalla **web UI** (Diagnostics → Logs → autoshutdown), NON da una sessione SSH — il check CLI vedrebbe te e diventerebbe lui il blocco. Ogni riga `-> no shutdown` dice quale check (e quale IP/porta/lock) sta bloccando. Ricorda: col NUC acceso è il check IP a bloccare, per progetto.
- **L'autoshutdown sembra morto (nessuna riga nei log)**: `ssh root@192.168.1.17 "systemctl status autoshutdown"` — con una config non valida (es. errore di sintassi nelle Extra options) il servizio esce con codice 138-143 e systemd **non** lo riavvia; correggi dalla GUI e riapplica.
- **`hs off` fallisce**: leggi l'errore sopra il messaggio finale — `Permission denied` = chiave SSH mancante (setup 1); `a password is required` = regola sudoers mancante (setup 2).
- **Watchdog**: `sudo journalctl -t nas-autowake` (vuoto = non è mai dovuto intervenire, è normale); stato timer: `systemctl list-timers nas-autowake.timer`.
