# HANDOFF

## Handoff — fase4-blocco-b-stack-arr-jellyseerr [c2538c3e-e14e-49a9-9184-e4229c2e4a90] — 2026-08-04 01:09

### ✅ Done & verified
- **Fase 4 Blocco B installato nella variante SENZA VPN** (scelta deliberata: debug a strati, gluetun si aggiunge dopo senza perdere config): compose unico `~/docker/arr` con **qBittorrent :8080, Prowlarr :9696, Sonarr :8989, Radarr :7878, Jellyseerr :5055** — tutti Up e verificati **via API** (testall `isValid=true` su ogni collegamento).
- **Cablaggio completo**: Prowlarr→Sonarr+Radarr (fullSync, API key); Sonarr/Radarr→qBittorrent con **API key di qBittorrent** (novità 5.1+, Options→WebUI — auth reale confermata: 403 senza credenziali da LAN e da rete Docker); Jellyseerr→Jellyfin via IP `http://192.168.1.171:8096` + Sonarr/Radarr per nome container (profilo `Any`, root `/data/serie` e `/data/film`, entrambi default). Root folder accessibili, categoria `serie`/`film` nei download client.
- **Test hardlink su CIFS: OK** (inaspettato → import istantanei senza doppio spazio). **Test download diretto: OK** — ISO Debian 13.6 (755 MB) scaricata e verificata in `/srv/media/torrents` sul NAS.
- **Indexer** (legali, per test): Internet Archive (sincronizzato a Sonarr/Radarr) + LinuxTracker (solo in Prowlarr: niente categorie TV/film, è normale).
- **Librerie Jellyfin create**: Film `/media/film`, Serie `/media/serie` (prima creata senza cartella, poi sistemata — verificato nei `.mblink`), Musica `/media/musica` (già popolata). Jellyfin monta `/srv/media:/media:ro`, rete host.
- **Incidente riparato**: paste multiplo aveva duplicato 4× radarr/jellyseerr nel compose (YAML invalido) → troncato e riscritto pulito; backup in `~/docker/arr/docker-compose.yml.bak` (eliminabile quando tutto ok).
- **Docs aggiornati stasera**: `FASE4-DOWNLOAD.md` (STATO nuovo, IP `.171` ovunque, checkbox reali, note qBittorrent API key / §8 widget Homarr / Jellyseerr / Connect) e `RECAP.md`. Nuova memoria: `feedback-lavoro-via-ssh` (pattern ibrido: Claude diagnostica/ripara via SSH+API, Luca esegue i blocchi didattici).
- **(2ª parte sessione, ~02:30) Tailscale ovunque + MagicDNS — FATTO E COLLAUDATO DA REMOTO**: tailnet **`uaru-snares.ts.net`** (MagicDNS attivo). Tailscale ora su: glnuc (c'era), **glnas** (installato via SSH jump `-J luca@glnuc root@192.168.1.17`, con **`--accept-dns=false`**: resolv.conf di OMV intatto, verificato), **PC portatile** (`naar-it-2025-21`), telefono (`luca-edge50`, spesso offline). **Key expiry disabilitato** su glnuc e glnas. **Tile e integrazioni Homarr migrate ai FQDN** `http://glnuc.uaru-snares.ts.net:<porta>` (+ `http://glnas.uaru-snares.ts.net` per OMV): ping verdi e click funzionanti confermati da Luca **da fuori casa**. Verificato: il container homarr risolve i FQDN e raggiunge i servizi (i nomi corti no — search domain stantio nel container, irrilevante); SSH da remoto ok verso entrambe le macchine.
- **Lezione operativa importante**: `hs`/WoL funzionano SOLO dalla LAN di casa (i magic packet sono broadcast, non attraversano il tailnet) e gli IP `192.168.1.x` da fuori non rispondono → da remoto le macchine possono sembrare "giù" mentre sono accese (successo stanotte: doppio falso allarme WoL). Da remoto il NAS si può svegliare via SSH sul NUC; se entrambe sono spente non c'è accensione remota. Idea futura: estendere `hs` con fallback via tailnet.

### 🚧 In progress / incomplete
- **Collaudo catena end-to-end (§9.2 guida)**: bloccato da **archive.org giù** (timeout/429 verificati la sera del 3/8, non è un errore di config — nel log Prowlarr la query parte giusta). Nota strutturale: la ricerca automatica mette `S01E01` nel titolo → col naming caotico di IA non matcha; usare **ricerca manuale in Prowlarr → grab → Manual Import** in Sonarr/Radarr. In Sonarr c'è già "Sherlock Holmes" (1954) con Monitor=None per il test; suggerita richiesta "Night of the Living Dead" (1968) da Jellyseerr→Radarr (esito non confermato).
- **Connect Sonarr/Radarr→Jellyfin** (Update Library ✓, API key Jellyfin): istruzioni date (Blocco 12), **esito NON confermato da Luca** → verificare in Settings→Connect di entrambi. Importante nel nostro setup: inotify non funziona su CIFS, senza Connect i file importati compaiono solo allo scan periodico.
- **Homarr**: tile presenti per tutti i servizi (qBittorrent in aggiunta a fine sessione, da confermare); **widget con integrazioni da fare** — modello v1 spiegato in §8 della guida: integrazione (Manage→Integrations, URL con IP, MAI nome container: Homarr è in un altro compose) + widget che la usa (Downloads/Calendar/Media Server).

### ⏭️ Next steps
1. **VPN per torrent + indexer veri** (richiesto esplicitamente da Luca come prossimo step): scegliere **AirVPN vs ProtonVPN** (entrambi con port forwarding) → abbonamento → **gluetun** nel compose (§4 guida: qBittorrent a `network_mode: "service:gluetun"`, porta 8080 su gluetun, host download client da `qbittorrent` a `gluetun` in Sonarr E Radarr e nel download client di Prowlarr) → verifica IP VPN + kill switch (§4.4-4.5) → indexer veri in Prowlarr (⚖️ uso per contenuti legittimi).
2. Chiudere i sospesi di cui sopra: ~~collaudo import~~ ✅ FATTO a fine sessione (film "Obsession 2026" da IA: grab→download→hardlink import→Jellyfin ok; Connect confermato funzionante, bastava un refresh; ⚠️ era un rip AMZN abusivo su IA, consigliata rimozione dal client — il file in /data/film resta via hardlink), widget Homarr.
3. **Preferenze lingua** (richiesta di Luca: doppiato ITA oppure lingua originale + sub ENG): fatto livello Jellyfin (Impostazioni→Riproduzione per utente: audio Italiano, sub Inglese modalità Smart — indicato, da confermare). Con gli indexer veri: **Custom Formats ITA/MULTI** in Radarr/Sonarr (punteggio nel quality profile) + **Bazarr** (:6767, stesso compose) per il download automatico dei sottotitoli ita+eng.
4. **Riavvio di prova del NUC** con lo stack completo (§9.4) + controllo RAM (`free -h`, `docker stats` — prima dello stack: 5,4 GiB disponibili).
5. Code pregresse: direct play Jellyfin (VAAPI) al primo video; `rm -rf /srv/media-local` sul NUC (~6 GB); energia: setup 4 autoshutdown OMV (parcheggiato su richiesta di Luca); eventuale Fase 5 (dominio).
6. **Nuova idea (richiesta Luca 4/8)**: servizio DNS locale con adblock — **Pi-hole o AdGuard Home** → registrata come "Fase 6 (IDEA)" in RECAP.md, con i due vincoli da sciogliere prima: conflitto con la politica energia (il NUC si spegne → la rete resterebbe senza DNS) e capacità DHCP della iliadbox (meglio decidere dopo trasloco/cambio router).

### 🧠 Key context & decisions
- **Regola reti Docker emersa più volte**: stesso compose → ci si parla per nome container (`sonarr`, `qbittorrent`…); compose diversi o Jellyfin (rete host) → serve l'IP `192.168.1.171`. Vale per Jellyseerr→Jellyfin e per le integrazioni di Homarr.
- **Verifiche via API senza disturbare Luca**: API key in `~/docker/arr/<app>/config.xml` (`grep -oP '(?<=<ApiKey>)[^<]+'` via SSH), endpoint `/api/v3/*` (Sonarr/Radarr) e `/api/v1/*` (Prowlarr), `testall` in POST (leggere `isValid` nel body, non solo l'HTTP status!). Jellyseerr: `~/docker/arr/jellyseerr/settings.json`. Librerie Jellyfin: `~/docker/jellyfin/config/root/default/*/[nome].mblink`.
- Fino alla VPN: **solo contenuti legali** (ISO, pubblico dominio) — nota legale in guida.
- qBittorrent: la spunta "Bypass authentication for localhost" è attiva ma innocua senza gluetun; tornerà utile con la VPN.
- IP: NUC `192.168.1.171` (ethernet), NAS `192.168.1.17` — lease DHCP statici ancora rimandati di proposito (trasloco in arrivo, checklist in GESTIONE-ENERGIA.md). Comando `hs` e watchdog energia intatti, non toccati stasera.
- Stato canonico progetto: `RECAP.md` (quadro) + `FASE4-DOWNLOAD.md` (guida Fase 4, aggiornata alla situazione reale).

## Handoff — gestione-energia-wol-hs-watchdog [bf2edd4a-2e54-49f6-8630-1ac67bab85ee] — 2026-08-02 00:18

### ✅ Done & verified
- **Wake-on-LAN funzionante e testato su entrambe le macchine** (guida completa: `GESTIONE-ENERGIA.md`, creata in questa sessione):
  - NAS `glnas` (192.168.1.17, MAC `3C:D9:2B:0C:F3:87`): BIOS già ok + spunta WoL in OMV Network → Interfaces.
  - NUC `glnuc` (192.168.1.171, MAC `84:39:BE:6B:55:73`): **passato su ethernet l'1/8, WiFi disabilitato**; ethernet gestita da **ifupdown, NON NetworkManager** → WoL persistente con riga `ethernet-wol g` in `/etc/network/interfaces` (confermata).
- **Comando `hs`** in `C:\Users\Luca\Commands` (`hs.bat` shim + `hs.ps1`): `hs` (status), `hs on/off [nas|nuc]`, `hs help`. **Output in inglese, flag `-f`** (rinominato da -Forza su richiesta di Luca → memoria `feedback-comandi-inglese`). Script sottostanti in `D:\Personale\HomeServer`: `sveglia-nas/nuc.ps1`, `spegni-nas/nuc.ps1` (flag `-Force`, messaggi inglesi). Launcher Desktop: `Accendi server.cmd` / `Spegni server.cmd`.
- **Spegnimenti via SSH operativi** (setup 1-2 guida): chiave ed25519 del PC autorizzata per `luca@nuc` e `root@nas` (con sanificazione CRLF/BOM via `tr`); sudoers `/etc/sudoers.d/homeserver` sul NUC (`poweroff` + `systemctl stop/start nas-autowake.timer`, parsed OK).
- **Watchdog `nas-autowake` sul NUC attivo e testato sul campo** (setup 3): `/usr/local/sbin/nas-autowake.sh` + service oneshot + timer (45s dal boot, poi ogni 2 min) + drop-in `docker.service.d/after-media.conf` (Docker dopo srv-media.mount) + `ifupdown-wait-online` abilitato. Il journal ha dimostrato ENTRAMBI i percorsi: mount+restart container (jellyfin, immich) e WoL+riconnessione CIFS automatica (~3 min dal WoL al NAS operativo).
- **Review adversariale (workflow, 18 finding corretti)** — il critico: la prima config autoshutdown avrebbe creato un **ciclo spegni/riaccendi ogni ~20 min** (autoshutdown spegne a NUC idle → watchdog risveglia). Risolto: **IP check del plugin ATTIVO con Range = solo `192.168.1.171`** = politica "NAS segue NUC" lato NAS.
- Docs allineati: `RECAP.md` (data, acquisti switch superato, sintesi energia), `FASE1-NUC.md` (ethernet/WoL ✅), `FASE3-COLLEGAMENTO.md` (IP storico corretto, regola boot automatizzata dal watchdog).

### 🚧 In progress / incomplete
- **Setup 4 — plugin autoshutdown su OMV**: Luca ha installato/iniziato a configurare il plugin ma l'ha lasciato **volontariamente con Enable=false** (doveva staccare). Campi inseriti da verificare contro la tabella §4 di `GESTIONE-ENERGIA.md`.
- **Lease DHCP statici: rimandati DI PROPOSITO** — trasloco e cambio router in arrivo; alla nuova rete usare la checklist "Trasloco" in `GESTIONE-ENERGIA.md` (elenca TUTTI i posti dove vivono gli IP, incluso il Range dell'autoshutdown).

### ⏭️ Next steps
1. **Completare setup 4** (Services → Autoshutdown): verificare i campi con la tabella §4 della guida — critici: **IP check ✅ con Range=`192.168.1.171`** (mai il default 2..254), **Socket numbers solo `22`** (mai 445/139), Cycles 6 / Sleep 180, Extra options `CHECK_SAMBA_CLIENTS="true"` — poi **Enable ✅ con Fake ✅ + Verbose ✅**, applica barra gialla.
2. **Test in Fake mode** (log dalla **web UI** Diagnostics → Logs, NON da SSH: il check CLI bloccherebbe il contatore): a NUC acceso → check IP positivo su .171 resetta il contatore; a NUC spento → contatore scende fino a `Shutdown command not executed in FAKE-Mode` (~18-20 min). Se compaiono `SMB client(s) with locks` costanti dal NUC → Check Samba ❌ (nota in guida §4).
3. Dopo ~1 settimana di Fake ok: togliere Fake e Verbose → sistema a regime.
4. Code pregresse: eliminare `/srv/media-local` sul NUC (~6 GB); Fase 4 Blocco B (scegliere VPN → stack arr); eventuale Fase 5 (dominio).

### 🧠 Key context & decisions
- **Politica energia: "il NAS segue il NUC"**, applicata da due lati: watchdog sul NUC (risveglia il NAS entro 2 min) + IP check dell'autoshutdown puntato SOLO sul NUC (il NAS non tenta lo spegnimento finché il NUC risponde). Ordini: accensione NAS→NUC, spegnimento NUC→NAS (gli script li impongono; `-f` per forzare il singolo host).
- **Non modificare mai `/etc/autoshutdown.conf` a mano** (generato da Salt/GUI); parametri expert nel campo Extra options.
- CIFS è **soft** di default e si riconnette da solo al ritorno del NAS → il watchdog riavvia i container SOLO quando monta lui lo share (bind mount Docker = rprivate, non vede i mount successivi). Nello script usare `findmnt`, mai `mountpoint` (si blocca su CIFS stale).
- Stato canonico progetto: `RECAP.md` (quadro) + `GESTIONE-ENERGIA.md` (energia, scenari, troubleshooting, checklist trasloco).
- Utente: principiante Linux, guidare in italiano passo-passo con comandi copia-incolla; MA utility/comandi CLI (cartella `Commands`) in inglese con flag brevi (memoria `feedback-comandi-inglese`).

## Handoff — fase2-omv-installato-troubleshooting [1357fafb-830f-497e-aff9-40ca5c89db9c] — 2026-07-30 22:30

### ✅ Done & verified
- **OMV installato sul N40L** (hostname `glnas`): web UI raggiungibile (`admin`), **SSH verificato** dal PC sia verso NUC che NAS (`root@<ip-nas>`). OS sulla chiavetta nuova 16-32 GB.
- **BIOS N40L configurato**: SATA AHCI, Restore on AC Power Loss = Power On, WoL abilitato, PXE in fondo al boot order.
- **Fase 0 ANNULLATA** (decisione utente 17/7): i dati vecchi sul pool ZFS non servono, si formatta senza recupero.
- **Troubleshooting risolto** (dettagli nel blocco STATO di `FASE2-NAS.md`): video assente (risolto, causa non identificata); "Failed to create a file system" = l'installer tentava di formattare se stesso perché c'era una sola chiavetta (diagnosi: log Alt+F4 → "/dev/sde1 is mounted"); porte USB frontali non bootabili da BIOS (workaround: installer interna + destinazione posteriore, poi scambio); "console vuota" = fallback PXE.
- Prima di questo, sessione del 17/7: confronto **Beelink U55** (stessa CPU → resta di scorta), guida a **librerie Jellyfin** (percorsi `/media/...` dentro il container) e indicazioni fonti musica legali (Bandcamp/rip CD + MusicBrainz Picard).

### 🚧 In progress / incomplete
- **Fase 2 a metà**: restano flashmemory (punto 4), wipe+SMART (5), RAID10+ext4 (6), utente+share SMB (7), riavvio di prova (8).
- **Da confermare** (istruzioni date, esito non confermato): password `admin` cambiata; lease DHCP statico NAS sulla iliadbox; da quale porta USB boota ora la chiavetta OS (piano: interna).
- **Trasloco fisico del NAS** nella posizione definitiva ancora da fare → wipe/RAID vanno fatti DOPO (la sync RAID dura ore).

### ⏭️ Next steps
1. Conferme di cui sopra (password admin, lease statico, porta di boot) + trasloco NAS.
2. **Flashmemory**: `ssh root@<ip-nas>` → `wget -O - https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install | bash` → web UI → System → Plugins → `openmediavault-flashmemory`.
3. **Wipe** dei 4 dischi (Storage → Disks) + lettura **SMART** (ore, settori riallocati/pending — dischi di 15 anni, valutare prima del RAID).
4. **RAID10** (Storage → Multiple Device) + **ext4** + mount; poi utente `luca` (gruppo `ssh` se vuole `luca@glnas`), shared folder `media`, SMB, test da Windows `\\ip\media`.
5. Poi **Fase 3**: mount NAS su `/srv/media` del NUC via fstab (decidere SMB vs NFS).

### 🧠 Key context & decisions
- Guide operative: `FASE2-NAS.md` (con STATO + problemi/soluzioni in cima), `FASE1-NUC.md`, quadro in `RECAP.md`.
- NUC operativo: `glnuc` in WiFi su `192.168.1.192` (Jellyfin :8096, Immich :2283, Tailscale attivo). Passaggio a ethernet del NUC ancora in sospeso (manca presa/switch).
- Regola web UI OMV: ogni modifica → barra gialla "Pending changes" → va applicata con la spunta.
- Utente principiante: italiano, passo-passo, comandi copia-incolla, un blocco alla volta.
