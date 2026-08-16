# Fase 4 — Gestione container e download automatizzati (Portainer, Homarr, stack *arr)

> **STATO (4 ago 2026, sera): BLOCCO A ✅ — BLOCCO B ✅ COMPLETO DI VPN (gluetun + ProtonVPN Plus; qBittorrent **e** Prowlarr nel tunnel, tutto collaudato) — manca solo: aggiungere gli indexer veri (§4.8)**
>
> - **Portainer** attivo su https://192.168.1.171:9443 (compose in `~/docker/portainer`). Novità rispetto alla guida: le versioni recenti (2.43+) chiedono un *setup token* al primo avvio; dopo vari tentativi falliti si è usato il flag **`--no-setup-token`** (ok su LAN fidata) — già incorporato nel compose qui sotto. Resta la regola dei ~5 minuti per creare l'admin
> - **Homarr** attivo su http://192.168.1.171:7575 (compose in `~/docker/homarr`, chiave di cifratura in `.env`). Wizard fatto: Base URL `192.168.1.171` in modalità Host:Port, integrazioni Jellyfin + Immich via API key, tile per Portainer e OMV. Riavvio di prova superato: tutto verde
> - Bonus della sessione: Portainer ha fatto scoprire che jellyfin/immich erano stati rimossi da una Fase 3 lasciata a metà → Fase 3 completata in questa stessa sessione (storia in [FASE3-COLLEGAMENTO.md](FASE3-COLLEGAMENTO.md), incluso il reset di Immich)
> - **Blocco B (sessione 3-4/8/2026): stack installato e cablato nella variante SENZA VPN** — qBittorrent `:8080`, Prowlarr `:9696`, Sonarr `:8989`, **Radarr `:7878`** e **Jellyseerr `:5055`** (extra rispetto alla guida originale) in `~/docker/arr`. Tutti i collegamenti verificati via API (testall ok): Prowlarr→Sonarr/Radarr in fullSync; Sonarr/Radarr→qBittorrent con **API key di qBittorrent** (novità 5.1+, alternativa pulita a user+pass); Jellyseerr→Jellyfin/Sonarr/Radarr; Connect Sonarr/Radarr→Jellyfin con Update Library (indispensabile qui: inotify non funziona su CIFS)
> - **Test hardlink su CIFS: OK** (sorpresa positiva → import istantanei, niente doppio spazio). **Test download diretto: OK** (ISO Debian 755 MB arrivata sul NAS). **Collaudo catena Sonarr: in sospeso** — archive.org giù (timeout/429) e comunque la ricerca automatica `S01E01` non si sposa col naming caotico di IA: quando torna su → ricerca manuale in Prowlarr + Manual Import in Sonarr. In coda da Jellyseerr→Radarr: "Night of the Living Dead" (1968, pubblico dominio)
> - **Librerie Jellyfin create**: Film `/media/film`, Serie `/media/serie`, Musica `/media/musica` (Musica già popolata dagli MP3 esistenti). Restano: widget con integrazioni in Homarr (§8), riavvio di prova con lo stack completo (§9)
> - **VPN FATTA (4/8 sera)**: gluetun + ProtonVPN operativi e collaudati (IP Proton BE/NL, kill switch, porta dinamica auto-sincronizzata, connectable ✅) + **fase 2 fatta**: anche Prowlarr nel tunnel (§4.7, con la trappola del DNS documentata). **Prossimo: indexer veri (§4.8).** ⚠️ IP del NUC aggiornato in tutta la guida: `192.168.1.171` (ethernet dall'1/8, il vecchio `.192` non esiste più)
> - **Lidarr (musica) installato e verificato il 4/8** (§10): porta 8686, root `/data/musica` ok, qBittorrent e Connect→Jellyfin validi via API. Unico pezzo mancante: l'indexer IA — Prowlarr lo teneva in backoff per i timeout di archive.org del mattino; resync automatico programmato per le 12:36
>
> Ispirata al video [Automated Home Media Server Setup](https://www.youtube.com/watch?v=3Q7UGg8LRJA) (vedi [analisi](analisi-video-automated-home-media-server.md)), adattata al nostro setup: NUC `glnuc` (Debian + Docker, `192.168.1.171`), media su `/srv/media` (= share SMB del NAS dopo la Fase 3), utente `luca` uid/gid 1000.

Obiettivo, in due blocchi indipendenti:

- **Blocco A — Gestione**: Portainer (interfaccia web per vedere/gestire tutti i container) e Homarr (dashboard unica di tutti i servizi). Si possono installare **anche subito**, non dipendono dalla Fase 3.
- **Blocco B — Download automatizzato**: qBittorrent (client torrent) dietro VPN + Prowlarr (indexer centralizzati) + Sonarr (serie TV) + Radarr (film). Flusso finale: cerchi un titolo → viene trovato, scaricato, rinominato e appare in Jellyfin da solo.

> ⚖️ **Nota legale (importante)**: in Italia scaricare/condividere via torrent contenuti protetti da copyright è illegale. Questo stack va usato per contenuti di cui hai i diritti: ISO Linux, materiale di pubblico dominio (es. [Internet Archive](https://archive.org)), Creative Commons, tue copie personali. La VPN protegge la privacy, non rende legale ciò che non lo è.

**Prerequisiti / avvertenze:**
- **Fase 3 completata** per il Blocco B (`/srv/media` montato dal NAS, ~1.8 TiB)
- **Abbonamento VPN** (Blocco B): serve un provider supportato da gluetun (ProtonVPN, AirVPN, Mullvad, NordVPN, Surfshark…). Se non ce l'hai ancora: per uso torrent i più consigliati sono **AirVPN** e **ProtonVPN** (supportano il port forwarding). Si può partire *senza* VPN (variante indicata al punto 4), ma è sconsigliato
- **RAM**: il NUC ha 8 GB e Immich è pesante. Lo stack aggiunge ~1–1.5 GB. Prima di partire controlla `free -h`; dopo, tieni d'occhio `docker stats`. Se va stretta: in Immich si può disattivare il machine learning
- **Rete**: finché il NUC è in WiFi, ogni download passa da WiFi→NAS (e ogni import può ripassarci). Funziona, ma **lo switch gigabit in lista acquisti diventa molto più importante** con questo stack

**Mappa porte a fine fase** (tutte su `192.168.1.171`):

| Servizio | Porta | Note |
|---|---|---|
| Jellyfin | 8096 | già attivo |
| Immich | 2283 | già attivo |
| Portainer | **9443** | HTTPS (avviso certificato: normale) |
| Homarr | **7575** | |
| qBittorrent | **8080** | pubblicata da **gluetun** (dal 4/8): stesso indirizzo di sempre, ma il traffico torrent esce solo dalla VPN |
| Prowlarr | **9696** | pubblicata da **gluetun** (dal 4/8 sera, fase 2): stesso indirizzo, ricerche solo dalla VPN. ⚠️ le app lo raggiungono a `http://gluetun:9696`, non più `http://prowlarr:9696` |
| Sonarr | **8989** | |
| Radarr | **7878** | |
| Prowlarr | **9696** | |
| Seerr (ex Jellyseerr) | **5055** | richieste titoli stile Netflix (aggiunto il 3/8; migrato a Seerr 3.4.1 il 4/8, vedi Note finali) |
| Lidarr | **8686** | musica (preparato il 4/8, vedi §10) |

---

## Blocco A — Gestione

## 1. Portainer

Interfaccia web per tutti i container: stato, log, console dentro al container con un click. I compose file restano la fonte di verità (come ora); Portainer serve a *guardare e intervenire*, non a creare.

1. [ ] Sul NUC:
   ```bash
   mkdir -p ~/docker/portainer/data
   cd ~/docker/portainer
   nano docker-compose.yml
   ```
2. [ ] Contenuto:
   ```yaml
   services:
     portainer:
       image: portainer/portainer-ce:lts
       container_name: portainer
       restart: unless-stopped
       command: --no-setup-token   # le 2.43+ chiedono un token dai log; su LAN di casa si può saltare
       ports:
         - "9443:9443"
       volumes:
         - /var/run/docker.sock:/var/run/docker.sock
         - ./data:/data
   ```
3. [x] `docker compose up -d`
4. [x] **Entro 5 minuti** apri https://192.168.1.171:9443 (accetta l'avviso sul certificato) e crea l'utente admin — se aspetti troppo Portainer si blocca per sicurezza (rimedio: reset pulito = `docker compose down`, `sudo rm -rf data`, `mkdir data`, `docker compose up -d`, poi finestra in incognito)
5. [x] Environment → **local** → Containers: devi vedere jellyfin, immich, ecc. Prova ad aprire i **Logs** di jellyfin e una **Console** (`>_`) per capire lo strumento

## 2. Homarr

Dashboard di tutti i servizi: tile con stato, download in corso, calendario uscite serie TV. Le integrazioni con Sonarr/Radarr/qBittorrent si aggiungono a fine Blocco B.

1. [x] ```bash
   mkdir -p ~/docker/homarr/appdata
   cd ~/docker/homarr
   echo "SECRET_ENCRYPTION_KEY=$(openssl rand -hex 32)" > .env   # la chiave finisce in .env, compose la legge da solo
   nano docker-compose.yml
   ```
2. [x] Contenuto:
   ```yaml
   services:
     homarr:
       image: ghcr.io/homarr-labs/homarr:latest
       container_name: homarr
       restart: unless-stopped
       ports:
         - "7575:7575"
       volumes:
         - ./appdata:/appdata
         - /var/run/docker.sock:/var/run/docker.sock:ro   # per il widget Docker (facoltativo)
       environment:
         - SECRET_ENCRYPTION_KEY=${SECRET_ENCRYPTION_KEY}
   ```
3. [x] `docker compose up -d` → http://192.168.1.171:7575 → wizard: lingua, Base URL `192.168.1.171` (modalità **Host:Port**), integrazioni Jellyfin + Immich con API key (si generano in Jellyfin: Dashboard → Chiavi API; in Immich: Impostazioni account → Chiavi API)
4. [x] Tile manuali aggiunte per Portainer (`https://192.168.1.171:9443`) e OMV del NAS (`http://192.168.1.17`). Drag & drop per sistemare la griglia
5. [x] Riavvio di prova del NUC: tutte le tile verdi ✅

---

## Blocco B — Download automatizzato (dopo la Fase 3)

Come si incastrano i pezzi:

```
Prowlarr ──(sincronizza gli indexer)──> Sonarr (serie) / Radarr (film)
                                            │ trova la release e la manda a…
                                            ▼
                              qBittorrent (tutto il traffico passa da gluetun/VPN)
                                            │ scarica in /data/torrents/…
                                            ▼
                     Sonarr/Radarr importano, rinominano → /data/serie, /data/film
                                            ▼
                          Jellyfin le vede in /srv/media/serie, /srv/media/film
```

## 3. Cartelle download (sul RAID del NAS)

I container dello stack vedranno **tutto `/srv/media` come `/data`**: download e librerie sullo stesso mount, così l'import può usare gli hardlink (istantaneo, zero spazio doppio) invece della copia.

1. [x] ```bash
   mkdir -p /srv/media/torrents/{film,serie}
   ```
2. [x] **Test hardlink** — **esito 3/8/2026: HARDLINK OK** anche su CIFS (import istantanei):
   ```bash
   touch /srv/media/torrents/test.txt
   ln /srv/media/torrents/test.txt /srv/media/film/test-link.txt && echo "HARDLINK OK" || echo "hardlink NON supportato: Sonarr/Radarr copieranno (ok comunque, solo più lento)"
   rm -f /srv/media/torrents/test.txt /srv/media/film/test-link.txt
   ```
   > Su mount SMB l'hardlink può non essere supportato: non è bloccante. Sonarr/Radarr hanno "Use Hardlinks instead of Copy" attivo di default e **ripiegano da soli sulla copia**. Se il test fallisce e in futuro vogliamo gli hardlink, si valuta il passaggio a NFS (nota in FASE3).

## 4. Lo stack: gluetun + qBittorrent + Prowlarr + Sonarr + Radarr

Un unico compose: i servizi si parlano per nome sulla rete interna di Docker. qBittorrent **non ha una rete propria**: usa quella di gluetun, quindi se la VPN cade il torrent si ferma (kill switch automatico).

> ✅ **Stato reale (4/8/2026 sera)**: gluetun è **installato e collaudato** (ProtonVPN Plus, WireGuard). Percorso: stack avviato il 3/8 senza VPN (debug a strati) → il 4/8 aggiunto gluetun col compose qui sotto e host del download client cambiato in `gluetun` **via API** in Sonarr, Radarr, Lidarr e Prowlarr (testall ✅ su tutti e quattro). Backup pre-modifica: `docker-compose.yml.bak-pre-gluetun`.
> ⚠️ **Nota operativa**: se gluetun viene riavviato da solo (`docker stop/start gluetun`), i container che condividono la sua rete vanno riavviati dopo — dal 4/8 sono **due**: `docker restart qbittorrent prowlarr` (verificato sul campo). `docker compose up -d` invece gestisce l'ordine da solo (dipendenza con healthcheck).
> 💡 **Conseguenza di design (voluta)**: con Prowlarr nella rete della VPN, se il tunnel cade **anche le ricerche si fermano** — nessuna query verso gli indexer può uscire con l'IP di casa. Sonarr/Radarr/Lidarr/Jellyseerr restano invece raggiungibili come sempre (sono fuori dal tunnel): si continua a navigare nelle UI, semplicemente le ricerche danno errore finché la VPN non torna.

1. [x] ```bash
   mkdir -p ~/docker/arr/{gluetun,qbittorrent,prowlarr,sonarr,radarr}
   cd ~/docker/arr
   nano docker-compose.yml
   ```
2. [x] Contenuto — la sezione `environment` di gluetun **dipende dal provider VPN**: valori esatti nella wiki di gluetun (https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers). **Provider scelto il 4/8/2026: ProtonVPN Plus** (analisi e cambio di decisione in [SCELTA-VPN.md](SCELTA-VPN.md)). La `<PrivateKey>` si genera da account.protonvpn.com → Downloads → **WireGuard configuration** (piattaforma GNU/Linux, **spunta NAT-PMP/Port Forwarding ATTIVA** — la capacità di port forwarding è legata alla chiave generata — server P2P):
   ```yaml
   services:
     gluetun:
       image: qmcgaw/gluetun:v3
       container_name: gluetun
       restart: unless-stopped
       cap_add:
         - NET_ADMIN
       devices:
         - /dev/net/tun:/dev/net/tun
       ports:
         - "8080:8080"        # WebUI di qBittorrent (passa da qui)
       volumes:
         - ./gluetun:/gluetun
       environment:
         - TZ=Europe/Rome
         - VPN_SERVICE_PROVIDER=protonvpn
         - VPN_TYPE=wireguard
         - WIREGUARD_PRIVATE_KEY=<PrivateKey, sezione [Interface] del config Proton>
         - WIREGUARD_ADDRESSES=10.2.0.2/32     # fisso, uguale per tutti i config WireGuard di Proton
         - SERVER_COUNTRIES=Netherlands
         - PORT_FORWARD_ONLY=on                # solo server che supportano il port forwarding
         - VPN_PORT_FORWARDING=on              # gluetun negozia la porta NAT-PMP e la rinnova ogni 60 s
         - VPN_PORT_FORWARDING_UP_COMMAND=/bin/sh -c 'wget -O- --retry-connrefused --post-data "json={\"listen_port\":{{PORTS}}}" http://127.0.0.1:8080/api/v2/app/setPreferences 2>&1'
   ```
   > ☝️ **L'ultima riga è il pezzo che rende indolore la porta dinamica di Proton**: a ogni porta nuova assegnata, gluetun stesso la scrive nelle impostazioni di qBittorrent via API. Funziona senza credenziali grazie alla spunta "Bypass authentication for clients on localhost" (già attiva da tempo): condividendo la rete, per qBittorrent le richieste di gluetun arrivano da localhost.
   ```yaml

     qbittorrent:
       image: lscr.io/linuxserver/qbittorrent:latest
       container_name: qbittorrent
       restart: unless-stopped
       network_mode: "service:gluetun"   # tutto il traffico passa dalla VPN
       depends_on:
         gluetun:
           condition: service_healthy    # parte solo a tunnel già su
       environment:
         - PUID=1000
         - PGID=1000
         - TZ=Europe/Rome
         - WEBUI_PORT=8080
       volumes:
         - ./qbittorrent:/config
         - /srv/media:/data

     prowlarr:
       image: lscr.io/linuxserver/prowlarr:latest
       container_name: prowlarr
       restart: unless-stopped
       ports:
         - "9696:9696"
       environment:
         - PUID=1000
         - PGID=1000
         - TZ=Europe/Rome
       volumes:
         - ./prowlarr:/config

     sonarr:
       image: lscr.io/linuxserver/sonarr:latest
       container_name: sonarr
       restart: unless-stopped
       ports:
         - "8989:8989"
       environment:
         - PUID=1000
         - PGID=1000
         - TZ=Europe/Rome
       volumes:
         - ./sonarr:/config
         - /srv/media:/data

     radarr:
       image: lscr.io/linuxserver/radarr:latest
       container_name: radarr
       restart: unless-stopped
       ports:
         - "7878:7878"
       environment:
         - PUID=1000
         - PGID=1000
         - TZ=Europe/Rome
       volumes:
         - ./radarr:/config
         - /srv/media:/data
   ```
   > **Variante senza VPN** (sconsigliata, ma utile per partire): togli il servizio `gluetun`, e in `qbittorrent` sostituisci `network_mode` e `depends_on` con:
   > ```yaml
   >     ports:
   >       - "8080:8080"
   > ```
   > Per aggiungere la VPN dopo, basta ripristinare il compose qui sopra: la config di qBittorrent non si perde.
3. [x] `docker compose up -d` (fatto il 3/8 senza VPN; rifatto il 4/8 con gluetun — partito al primo colpo)
4. [x] **Verifica VPN** ✅ 4/8: IP visto da qBittorrent = `45.128.133.230` (Proton, Belgio) e dopo un riavvio `185.107.44.111` (Paesi Bassi) — l'IP di casa è un altro. Comandi:
   ```bash
   docker logs gluetun | grep -i "public ip"
   docker exec qbittorrent curl -s ifconfig.me; echo
   ```
5. [x] Prova kill switch ✅ 4/8: con gluetun fermo, qBittorrent è risultato **completamente isolato** (nessun pacchetto fuori). Al restart di gluetun ricordare la nota operativa sopra (riavviare anche qBittorrent)
6. [x] **Porta dinamica Proton in qBittorrent** ✅ collaudata il 4/8 su **due cicli**: porta `53438` alla prima connessione, `62709` dopo un riavvio — in entrambi i casi gluetun l'ha scritta da solo nelle impostazioni di qBittorrent (zero interventi umani), e il test TCP **dall'esterno del tunnel** dà porta APERTA → siamo *connectable*. Mai impostarla a mano; una tantum già a posto: UPnP off, porta random off, localhost-bypass attivo. Verifica al bisogno: `docker logs gluetun | grep -i "port forward"` vs Options → Connection → *Port used for incoming connections*
7. [x] **Fase 2 ✅ FATTA il 4/8/2026 sera — anche Prowlarr dietro gluetun.** Motivo: le ricerche di Sonarr/Radarr/Lidarr passano fisicamente da Prowlarr (gli indexer sincronizzati nelle app sono URL che puntano a lui), quindi spostarlo dietro la VPN copre tutto il traffico di ricerca e rende raggiungibili gli indexer bloccati da AGCOM. Cambi applicati: in `prowlarr` `ports` sostituito da `network_mode: "service:gluetun"` + `depends_on` con healthcheck, `"9696:9696"` spostato nei `ports` di gluetun. Backup: `docker-compose.yml.bak-pre-prowlarr-vpn`.
   - ✅ **Verificato**: Prowlarr esce con l'IP Proton (uguale a qBittorrent), risponde su `:9696` come prima, raggiunge ancora Sonarr/Radarr/Lidarr **per nome container** (la rete di gluetun risolve i nomi Docker: verificato con `getent hosts`), download client verde, **ricerca reale su LinuxTracker: 30 risultati** attraverso il tunnel.
   - ⚠️ **Trappola importante (costata due tentativi)**: entrando nella netns di gluetun, Prowlarr **perde il proprio nome DNS** → gli indexer già sincronizzati nelle app, che puntavano a `http://prowlarr:9696/1/`, danno *"Name does not resolve (prowlarr:9696)"*. Vanno riscritti in **`http://gluetun:9696/1/`**. Due accorgimenti: (a) `prowlarrUrl` nelle 3 Applications di Prowlarr va messo a `http://gluetun:9696` (fatto), ma il sync **non riscrive** gli URL già esistenti nelle app, nemmeno con `forceSync` → si aggiornano a mano (UI: Sonarr/Radarr → Settings → Indexers → l'indexer → URL) oppure via API; (b) Sonarr/Radarr **rifiutano il salvataggio** se l'indexer non risponde (nel nostro caso `429` di archive.org) → serve `?forceSave=true` sull'API, o in UI insistere/riprovare quando l'indexer è sano.
   - Nota: Homarr non ha richiesto modifiche (FQDN e porta invariati).
8. [ ] **Indexer veri in Prowlarr** — ultimo passo del Blocco B (⚖️ contenuti legittimi). Ora l'intera catena ricerca+download esce dalla VPN, quindi si può procedere. Nota: gli indexer bloccati da AGCOM dovrebbero essere raggiungibili (traffico dal server Proton); dopo l'aggiunta, un `testall` in Prowlarr conferma.

## 5. Configurare qBittorrent

1. [x] Password temporanea: `docker logs qbittorrent | grep -i password`
2. [x] http://192.168.1.171:8080 → login `admin` + password temporanea
3. [x] Ingranaggio (Options):
   - **Web UI** → cambia username/password. La spunta "Bypass authentication for clients on localhost" è utile solo con gluetun (rete condivisa = localhost); senza VPN non ha effetto (innocua)
   - **Web UI → API key**: novità qBittorrent 5.1+ — è il modo pulito per collegare Sonarr/Radarr senza condividere la password (usato qui)
   - **Downloads** → Default Save Path: `/data/torrents`
   - **BitTorrent** → limite di seeding ratio 2 + Stop torrent, così i download completati non seedano per sempre
4. [x] Le categorie `serie` e `film` le creeranno Sonarr/Radarr da soli al primo download; verranno salvate in `/data/torrents/<categoria>`

## 6. Configurare Prowlarr

1. [x] http://192.168.1.171:9696 → crea le credenziali (Authentication: Forms)
2. [x] **Indexers → Add Indexer**: aggiunti **Internet Archive** e **LinuxTracker** (legali, per i test). Nota (3/8): archive.org era giù (timeout/429) — capita spesso, riprovare più tardi
3. [x] **Settings → Apps → + →**:
   - **Sonarr**: Prowlarr Server `http://prowlarr:9696`, Sonarr Server `http://sonarr:8989`, API Key di Sonarr (la trovi in Sonarr → Settings → General)
   - **Radarr**: idem con `http://radarr:7878` e la sua API Key
4. [x] Salvando, Prowlarr **sincronizza gli indexer** su entrambe le app: da qui in poi gli indexer si gestiscono SOLO in Prowlarr. Su Sonarr/Radarr arriva solo Internet Archive: è normale, LinuxTracker non ha categorie TV/film (resta in Prowlarr per le ricerche manuali)

## 7. Configurare Sonarr e Radarr

Per **Sonarr** (http://192.168.1.171:8989):

1. [x] Al primo avvio: crea le credenziali
2. [x] **Settings → Media Management → Add Root Folder**: `/data/serie`
3. [x] **Settings → Download Clients → + → qBittorrent**: Host **`qbittorrent`** (configurazione attuale senza VPN), Port `8080`, **API key di qBittorrent** (o username/password della WebUI), Category `serie` → Test → Save
   - ✅ fatto il 4/8: host cambiato in `gluetun` via API (qBittorrent condivide la sua rete), test verde
4. [x] Verifica in Settings → Indexers che gli indexer arrivati da Prowlarr ci siano

Per **Radarr** (http://192.168.1.171:7878): identico, con Root Folder `/data/film` e Category `film` — fatto ✅ (3/8, verificato via API).

## 8. Integrazioni in Homarr

1. [x] In Homarr aggiungi le app qBittorrent, Sonarr, Radarr, Prowlarr, Jellyseerr con i rispettivi URL `http://192.168.1.171:<porta>` (tile aggiunte il 3/8)
2. [ ] **Widget con integrazioni** — attenzione al modello di Homarr v1, in due passi separati:
   - **Passo 1 — creare l'integrazione** (= credenziali salvate, da sola NON mostra nulla in dashboard): menu di gestione → **Integrations** → New → scegli il tipo (qBittorrent, Sonarr, Radarr, Jellyfin…) → URL **con l'IP** `http://192.168.1.171:<porta>` (⚠️ mai il nome container: Homarr sta in un altro compose e non lo risolve) → credenziali (qBittorrent: username+password; Sonarr/Radarr: API key)
   - **Passo 2 — usarla in un widget**: sulla board, matita (edit mode) → `+` → widget **Downloads** (download in corso), **Calendar** (uscite serie/film) o **Media Server** (riproduzioni Jellyfin) → nelle impostazioni del widget seleziona l'integrazione creata → salva

## 9. Verifica end-to-end + riavvio di prova

1. [x] **Test download diretto** ✅ (3/8): ISO Debian 13.6 (755 MB) scaricata e verificata in `/srv/media/torrents` sul NAS
2. [ ] **Test catena completa**: ⏸️ in sospeso — archive.org giù durante la sessione del 3/8, e comunque la ricerca automatica (`S01E01` nel titolo) non matcha il naming di IA. Richiesta già in coda via Jellyseerr→Radarr: "Night of the Living Dead" (1968). Quando IA risponde: ricerca automatica, oppure ricerca manuale in Prowlarr → grab → **Manual Import** in Sonarr/Radarr (Wanted → Manual Import da `/data/torrents/<categoria>`)
3. [x] **Jellyfin**: librerie create (3/8): Film `/media/film`, Serie `/media/serie`, Musica `/media/musica` (Musica già popolata) — resta da vedere il primo film comparire a fine catena
4. [ ] **Riavvio di prova del NUC**: tutto lo stack (ora 5 container in più) deve ripartire da solo — da fare; quando ci sarà gluetun, verificare anche la riconnessione VPN (punto 4.4)
5. [ ] `free -h` e `docker stats --no-stream`: verificare che la RAM regga (prima dello stack: 5,4 GiB disponibili)

## 10. Lidarr — musica (installato e verificato 4/8/2026)

Il "Sonarr della musica": monitora gli artisti, cerca gli album via Prowlarr, li fa scaricare a qBittorrent e li importa in `/data/musica` — la stessa cartella della libreria **Musica** di Jellyfin (già popolata). Metadati da **MusicBrainz** (l'equivalente di TVDB/TMDB). Due cose da sapere:

- **Jellyseerr non gestisce la musica** (solo film/serie): gli artisti si aggiungono direttamente dalla UI di Lidarr.
- I metadati passano dal server di Lidarr (`api.lidarr.audio`), che ogni tanto ha disservizi: se la ricerca artisti dà errore con la config giusta, è un problema loro (come archive.org giù).

**Passo 1 — cartelle** (SSH sul NUC):

```bash
mkdir -p ~/docker/arr/lidarr /srv/media/torrents/musica
```

**Passo 2 — servizio nel compose**, con append in un colpo solo + validazione YAML (anti "paste multiplo"):

```bash
cd ~/docker/arr
cp docker-compose.yml docker-compose.yml.bak-lidarr
cat >> docker-compose.yml <<'EOF'

  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    container_name: lidarr
    restart: unless-stopped
    ports:
      - "8686:8686"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Rome
    volumes:
      - ./lidarr:/config
      - /srv/media:/data
EOF
docker compose config --quiet && echo "YAML OK"
```

> `cat >>` aggiunge in fondo al file senza aprire l'editor; `docker compose config --quiet` valida il YAML **prima** di toccare i container. Se non stampa `YAML OK`: ripristina con `cp docker-compose.yml.bak-lidarr docker-compose.yml` e si riprova.

**Passo 3 — avvio**:

```bash
docker compose up -d
docker ps --format '{{.Names}}\t{{.Status}}' | grep lidarr
```

**Passo 4 — configurazione** (da casa http://192.168.1.171:8686, dal tailnet http://glnuc.uaru-snares.ts.net:8686):

1. [x] Al primo avvio: Authentication **Forms** → crea le credenziali
2. [x] **Settings → Media Management → Add Root Folder**: `/data/musica` (Quality/Metadata Profile: lasciare i default)
3. [x] **Settings → Download Clients → + → qBittorrent**: Host `qbittorrent`, Port `8080`, **API key di qBittorrent** (Options → Web UI, la stessa usata per Sonarr/Radarr), Category `musica` → Test → Save — ✅ host cambiato in `gluetun` via API il 4/8 (come per Sonarr/Radarr), test verde
4. [x] In **Prowlarr → Settings → Apps → + → Lidarr**: Prowlarr Server `http://prowlarr:9696`, Lidarr Server `http://lidarr:8686`, API key di Lidarr (Settings → General) → Test → Save. Si sincronizza Internet Archive (ha categorie audio); LinuxTracker resta fuori, come per TV/film
5. [x] **Settings → Connect → + → Emby/Jellyfin**: Host `192.168.1.171`, Port `8096`, API key di Jellyfin, **Update Library ✓** (solito motivo: inotify non funziona su CIFS)
6. [ ] **Homarr**: tile con `http://glnuc.uaru-snares.ts.net:8686` (+ eventuale integrazione Lidarr per i widget, vedi §8)

> **Verifica del 4/8 (~11:30, via API)**: Lidarr 3.1.0 su, root folder `/data/musica` accessibile (1,96 TB liberi), download client qBittorrent `isValid=true`, Connect Jellyfin `isValid=true` con `updateLibrary=true`, app Lidarr in Prowlarr `isValid=true` (fullSync, categorie Audio). **Indexer in Lidarr: 0, ma NON è un errore di config** — Prowlarr aveva messo Internet Archive in backoff fino alle 12:32 per i timeout di archive.org del mattino, e il sync salta gli indexer in backoff. Rimedio: one-shot sul NUC (`/tmp/lidarr-resync.sh`, esito in `/tmp/lidarr-resync-result.txt`) che alle 12:36 fa una ricerca di sblocco + Application Indexer Sync. Nota: i Warn `404` su `/mediabrowser/Notifications/Admin` nel log di Lidarr sono innocui — è un endpoint di Emby che Jellyfin non ha; l'Update Library funziona comunque.

**Passo 5 — musica già esistente (facoltativo)**: Artists → **Library Import** → `/data/musica` → Lidarr riconosce gli artisti degli MP3 esistenti e li cataloga. Consiglio per iniziare: **Monitor = None** (solo catalogare, niente ricerche automatiche); il rinomino file è off di default, quindi i file esistenti non vengono toccati.

## Note finali

- **Richieste da telefono → FATTO (3/8)**: **Jellyseerr** attivo su http://192.168.1.171:5055 (immagine `fallenbagel/jellyseerr`, config in `~/docker/arr/jellyseerr`, stesso compose dello stack). Wizard: media server **Jellyfin via IP** `http://192.168.1.171:8096` (il nome container non si risolve: Jellyfin è in rete host), librerie Film+Serie sincronizzate, server Sonarr (`sonarr:8989`, profilo Any, root `/data/serie`, default) e Radarr (`radarr:7878`, Any, `/data/film`, default) per nome container. Login con gli account Jellyfin
- **Jellyseerr → Seerr (4/8/2026)**: il progetto è stato rinominato **Seerr** dalla v3.0.0 (feb 2026) e l'immagine Docker è cambiata → la vecchia `fallenbagel/jellyseerr` è ferma per sempre alla 2.7.3. Nel compose ora c'è **`ghcr.io/seerr-team/seerr:latest`** + `init: true` (container e cartella config restano "jellyseerr", rename solo cosmetico rimandato). Migrazione DB automatica al primo avvio; collegamenti Jellyfin/Sonarr/Radarr sopravvissuti (verificati via API). ⚠️ Gotcha risolto: la nuova immagine gira come utente `node` (uid 1000), non più root → primo avvio in crash loop con `EACCES` sui log; risolto con chown a 1000:1000 della config (via container Docker, senza sudo). Da eliminare quando tutto è ok da giorni: `~/backup-jellyseerr-pre-seerr-*.tar.gz`, `docker-compose.yml.bak-seerr`, e la vecchia immagine con `docker rmi fallenbagel/jellyseerr:latest`
- **Connect Sonarr/Radarr → Jellyfin (fatto 3/8)**: in entrambi Settings → Connect → Emby/Jellyfin, Host `192.168.1.171` Port `8096`, API key di Jellyfin (Dashboard → API Keys), **Update Library ✓** — indispensabile nel nostro setup: il monitoraggio in tempo reale di Jellyfin (inotify) non funziona sui mount CIFS, senza questo i file importati comparirebbero solo allo scan periodico
- **Aggiornamenti**: ogni tanto `cd ~/docker/<app> && docker compose pull && docker compose up -d`
- **Backup config**: le cartelle `~/docker/*/` (compose + config) sono piccole e preziose — vale la pena includerle nel piano backup
- **Se un indexer richiede "FlareSolverr"**: è un componente extra per superare le protezioni Cloudflare — si aggiunge solo se serve, non partire con quello
