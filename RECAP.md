# Home Server — Recap del progetto

*Aggiornato: 4 agosto 2026*

Obiettivo: server domestico per **musica, video e foto** con Jellyfin, usando hardware già in mio possesso.

## Architettura decisa

| Macchina | Ruolo | Software |
|----------|-------|----------|
| **Minisforum U500** (NUC) | Compute: media server e app | Debian + Docker: Jellyfin, Immich, Portainer, Homarr, Tailscale + stack download (qBittorrent, Prowlarr, Sonarr, Radarr, Jellyseerr) |
| **HP MicroServer N40L** (NAS) | Storage: librerie media e backup | OpenMediaVault, share SMB/NFS |

Il NUC fa girare i servizi, il NAS conserva i dati. Il NUC monta lo share del NAS via fstab.

**Mappa completa di container, servizi e interfacce → [ARCHITETTURA.md](ARCHITETTURA.md)**

## Hardware — cosa è emerso

### Minisforum U500 (NUC)
- CPU Intel Core i3-5005U (Broadwell, 5ª gen, 2C/4T @ 2.0 GHz), grafica HD 5500 — verificati: **8 GB RAM, SSD Kingston 128 GB** (hostname: `glnuc`; **dall'1/8/2026 su ethernet: IP 192.168.1.171**, MAC `84:39:BE:6B:55:73`, WiFi disabilitato — il vecchio IP WiFi 192.168.1.192 non è più suo)
- Confronto col Beelink U55 (stessa CPU): si tiene l'U500, il Beelink resta di scorta
- **Limite chiave: QuickSync di 5ª gen = solo H.264 in hardware.** Niente HEVC 10-bit, VP9, AV1; la CPU non regge la transcodifica HEVC software
- **Strategia: direct play sempre.** I client moderni decodificano HEVC da soli; streaming remoto a bitrate pieno (serve upload decente)
- Per musica e foto è più che sufficiente

### HP MicroServer N40L (NAS `glnas`, IP attuale: 192.168.1.17 — DHCP **senza** lease statico, scelta di Luca: se l'IP cambia, aggiornare share/fstab. MAC ethernet: `3C:D9:2B:0C:F3:87`)
- AMD Turion II Neo N40L (2C @ 1.5 GHz), 6 GB RAM, 4 bay SATA 3.5"
- Girava **FreeNAS 8.0.2** (2011, EOL) — web UI accessibile **senza login**: non lasciarlo acceso h24 così com'è, mai esporlo a internet
- Inutile per Jellyfin (CPU debolissima, zero transcodifica hw), **perfetto come NAS di storage/backup**
- FreeNAS di solito sta su una chiavetta USB nella porta interna della scheda madre

### I 4 dischi del N40L — (storico: wipe eseguito il 30/7/2026, i vecchi dati non esistono più)
- 4× HDD da 1 TB (`ada0`–`ada3`), tutti rilevati e funzionanti, età ~15 anni
- Auto-import ha trovato il pool ZFS **`volumeone`**: 1.7 TiB totali, **1.5 TiB usati (88%)**, stato HEALTHY, montato su `/mnt/volumeone`
- **Tutti e 4 i dischi fanno parte del pool** (ZFS spalma i dati su tutti): non esiste un disco "vuoto" da sfilare. Probabilmente RAID-Z2 o mirror a coppie (conferma: `zpool status volumeone` via SSH)
- Per salvare i dati serve una destinazione esterna (disco USB o PC); ~4-5 ore per 1.5 TiB su rete gigabit

### Beelink U55 (secondo mini PC, ritrovato)
- **Stessa identica CPU dell'U500**: i3-5005U (Broadwell, 2C/4T, HD 5500) → stessi limiti, zero vantaggi come server principale; 8 GB DDR3L non espandibile, SSD M.2 SATA 128/256 GB, doppia HDMI
- **Non sostituisce l'U500.** Usi sensati: **backup off-site foto** (a casa di un parente + Tailscale + sync Immich, dopo la Fase 3), muletto di ricambio, banco di prova

### HP Pavilion 690-0007nl (vecchio PC, disponibile come donatore)
- Ryzen 5 2600 (6C/12T), 8 GB DDR4, **GTX 1050 2GB (NVENC/NVDEC Pascal: HEVC 10-bit hw!)**, 1TB HDD + 128GB SSD, PSU 310W
- **Saprebbe transcodificare** (a differenza dell'U500) e il Ryzen è molto più potente — ma in idle fa 35-50W vs ~10W dell'U500: h24 costa ~70-100 €/anno in più. **Decisione: resta donatore di pezzi**; promuoverlo a server solo se la transcodifica si rivela indispensabile all'uso reale (a quel punto: lui gratis > N150 a pagamento)
- Componenti riciclabili:
  - **HDD 1TB → destinazione per il salvataggio dati dal N40L** (l'insostituibile; tutto il volume da 1.5 TiB non ci sta), poi disco backup foto
  - ~~SSD 128GB~~ verificato: Toshiba KBG30ZMV128G = **M.2 NVMe** (serie BG3) → il N40L non lo supporta, resta nel Pavilion. **OS di OMV su chiavetta USB 16-32GB di qualità + plugin `openmediavault-flashmemory`**
  - RAM DDR4: incompatibile con N40L (DDR3 ECC) e U500 (DDR3L SO-DIMM)
  - GTX 1050: non entra nel N40L (low-profile, PSU 150W) — inutilizzabile altrove

## Piano operativo (in ordine)

### Fase 0 — Salvataggio dati dal N40L → ❌ ANNULLATA (17/7/2026)
Decisione: i dati sul pool ZFS `volumeone` (1.5 TiB) **non servono più** — si formatta direttamente senza recupero. Il wipe in Fase 2 li cancella definitivamente.

### Fase 1 — NUC ✅ COMPLETATA (17/7/2026) → dettagli e note: [FASE1-NUC.md](FASE1-NUC.md)
1. [x] Debian 13 installato (minimale, SSH; hostname `glnuc`, WiFi `192.168.1.192`)
2. [x] Docker + plugin compose dal repo ufficiale
3. [x] **Jellyfin** (`~/docker/jellyfin`, `/dev/dri` passato, `:8096`) + **Immich** (compose ufficiale in `~/docker/immich`, `:2283`) + **Tailscale** (sull'host, non in Docker)
4. [x] Jellyfin: librerie create il 3/8/2026 (Film, Serie, Musica — Musica già popolata); **VAAPI abilitato via API il 4/8** (decode h264/mpeg2/vc1, encode H264 testato OK; niente HEVC, limite Broadwell) + **preferenze lingua per utente** (audio ITA, sub ENG modalità Smart, per luca e miche); resta il test direct play al primo video reale
5. [x] Librerie temporaneamente su disco locale (`/srv/media`, per ora vuoto)

### Fase 2 — N40L: reinstallazione con OpenMediaVault ✅ COMPLETATA (31/7/2026) → guida: [FASE2-NAS.md](FASE2-NAS.md)
1. [x] Case aperto, chiavetta FreeNAS 2011 recuperata (conservata, ormai solo cimelio)
2. [x] ISO OMV su USB (Rufus MBR/BIOS) — attenzione: servono DUE chiavette, installer + destinazione (vedi note in FASE2-NAS.md)
3. [x] Installazione fatta (video risolto, porte USB frontali non bootabili → workaround porte interna+posteriore)
4. [x] OS installato su chiavetta 16-32 GB (hostname `glnas`) + plugin `flashmemory` installato (30/7)
5. [x] Password admin cambiata; lease DHCP statico: **deciso di NON farlo** (IP attuale 192.168.1.17)
6. [x] Wipe sui 4 dischi + **RAID10** (`/dev/md0`, ~1,86 TiB) + ext4 montato — resync iniziale in corso la notte del 30/7 (~5h)
7. [x] SMART: tutti e 4 promossi — 0 settori riallocati/pending su tutti, ore 72.603–84.988 (monitoraggio attivato)
8. [x] Utente `luca`, shared folder `media`, SMB attivo — testato da Windows, mappato come unità persistente (prima `Z:`, **rinominata `G:` l'1/8/2026 circa**)
9. [x] **Riavvio di prova** superato (31/7): RAID `clean` e montato, share raggiungibile senza intervento manuale

### Fase 3 — Collegamento ✅ COMPLETATA (31/7/2026) → storia completa: [FASE3-COLLEGAMENTO.md](FASE3-COLLEGAMENTO.md)
1. [x] Mount CIFS in fstab: `//192.168.1.17/media` → `/srv/media` (~1.8T), verificato dopo riavvio
2. [x] Dati spostati sul NAS (rsync ~6,2 GB) — ⚠️ una prima sessione interrotta a metà aveva lasciato container rimossi e mount mancante; nel completamento è emerso il **database Immich azzerato** → decisione: **reset totale di Immich** (nuovo account, foto in ri-caricamento dal telefono; i file non erano mai andati persi)
3. [x] Code chiuse il 4/8/2026: `/srv/media-local` eliminato; MP3 sciolti spostati in `musica/` (verificato: radice share pulita). Regola permanente: **accendere il NAS prima del NUC** (automatizzata dal watchdog)

### Fase 4 — Gestione container e download automatizzati (BLOCCO A ✅ 31/7 — BLOCCO B ✅ con VPN dal 4/8/2026) → guida: [FASE4-DOWNLOAD.md](FASE4-DOWNLOAD.md)
Ispirata al [video TechWithDavid](analisi-video-automated-home-media-server.md). Due blocchi:
1. [x] **Gestione**: Portainer (`:9443`, con `--no-setup-token`) + Homarr (`:7575`, dashboard con integrazioni Jellyfin/Immich e tile Portainer/OMV) — riavvio di prova ok, tutto verde
2. [x] **Download automatizzato ✅ COMPLETO DI VPN dal 4/8/2026 sera**: **qBittorrent (`:8080`) e Prowlarr (`:9696`) dentro il tunnel** (gluetun + ProtonVPN Plus, porte pubblicate da gluetun) + Sonarr (`:8989`) + Radarr (`:7878`) + Jellyseerr (`:5055`) + Lidarr (`:8686`, aggiunto il 4/8) — compose unico in `~/docker/arr`. Collegamenti verificati via API (testall ✅ su tutte e 4 le app, host download client = `gluetun`); hardlink su CIFS OK; **VPN collaudata end-to-end**: IP Proton (BE/NL) ≠ IP di casa, kill switch verificato, porta dinamica auto-sincronizzata da gluetun (53438→62709) e APERTA dall'esterno → connectable; **ricerca reale via VPN: 30 risultati** (LinuxTracker). ⚠️ Le app parlano con Prowlarr a `http://gluetun:9696` (non più `prowlarr:9696` — trappola DNS documentata in guida §4.7); se si riavvia gluetun a mano: `docker restart qbittorrent prowlarr`. **Manca solo**: aggiungere gli **indexer veri** (§4.8) → poi la wishlist (6 film, 5 serie) si svuota da sola. Da fare anche il riavvio di prova con lo stack completo (da casa)

### Fase 5 — Accesso con dominio proprio (IDEA, da confermare)
Sottodominio `*.private.gandogames.org` → IP Tailscale del NUC + reverse proxy (Caddy o Nginx Proxy Manager) + certificato wildcard Let's Encrypt via sfida DNS-01. URL puliti e HTTPS valido senza esporre nulla (niente port forwarding, coerente con la regola Tailscale-only). Da definire: dove è gestito il DNS di gandogames.org

> **Perché Fase 5+6 insieme (domanda di Luca del 4/8)**: l'esigenza è smettere di gestire gli IP a mano (il router può cambiarli; in LAN sono 192.x ma via Tailscale 100.x). Soluzione a strati: **lease statici post-trasloco** per la plumbing (fstab, script hs, watchdog — checklist Trasloco in GESTIONE-ENERGIA.md; trucco: `/etc/hosts` sul NUC con `glnas` e fstab per nome; G: su `\\GLNAS\media`); **un solo nome per servizio** per il livello umano: subito MagicDNS (`glnuc` → 100.x, funziona anche da casa), poi dominio+reverse proxy (Fase 5) e split DNS casa/fuori (Fase 6). Il dominio da solo NON risolve la dualità 192/100: serve Tailscale sempre attivo sui dispositivi oppure lo split DNS. Il WoL non c'entra: viaggia sul MAC, immune ai cambi IP.

### Fase 6 — DNS locale con adblock (IDEA, richiesta 4/8/2026) → valutazione completa: [SCELTA-DNS-ADBLOCK.md](SCELTA-DNS-ADBLOCK.md)
**Software scelto nella valutazione del 4/8: AdGuard Home consigliato (75/25 su Pi-hole)** — DoH/DoT nativo (niente container extra), regole per-client, rewrite wildcard in UI (pronto per la Fase 5); alternative scartate (Blocky, Technitium, cloud NextDNS come interim) e percorso a fasi nel documento. Stato dei due vincoli:
1. ⚠️ **Politica energia: resta il nodo** — con costo nascosto: col watchdog attuale "NUC h24" significa anche NAS h24 (~€124/anno in due, vs ~€32 il solo NUC con watchdog rivisto). Decisione rimandata a dopo il trasloco, insieme alla politica energia
2. ✅ **DHCP iliadbox: verificato il 4/8, si può** (modalità avanzata → DHCP → campi Server DNS 1/2; ⚠️ va forzato anche il lato **IPv6**, altrimenti i dispositivi bypassano il filtro) — al cambio router ricontrollare l'equivalente

## Download — link utili

### Strumenti da Windows (preparazione)
- **Rufus** (scrittura ISO su USB): https://rufus.ie/
- **WinSCP** (SFTP verso il FreeNAS per la Fase 0): https://winscp.net/eng/download.php

### Sistemi operativi
- **Debian stable netinst** (per il NUC): https://www.debian.org/download — scegliere la ISO *netinst* amd64
- **OpenMediaVault** (per il N40L): https://www.openmediavault.org/download.html — le ISO stanno su SourceForge: https://sourceforge.net/projects/openmediavault/files/iso/

### Docker e container
- **Docker Engine + plugin compose su Debian** (guida ufficiale, repo apt): https://docs.docker.com/engine/install/debian/
- **Jellyfin**: immagine `jellyfin/jellyfin` — https://hub.docker.com/r/jellyfin/jellyfin (docs: https://jellyfin.org/docs/general/installation/container)
- **Immich**: guida docker-compose ufficiale (immagini `ghcr.io/immich-app/...`): https://immich.app/docs/install/docker-compose
- **Tailscale**: immagine `tailscale/tailscale` — https://hub.docker.com/r/tailscale/tailscale (docs: https://tailscale.com/kb/1282/docker)

## Acquisti

**Ora: niente.** Si parte con quello che c'è.

Poi, in ordine di priorità:
1. ~~Switch gigabit 5 porte~~ → **superato: il NUC è su cavo dall'1/8/2026** (WiFi disabilitato). Se la presa ethernet torna contesa col PC gaming, lo switch (~10-15 €) resta l'acquisto giusto
2. **Un disco nuovo per il backup foto** — dati insostituibili su HDD di 15 anni è roulette russa (2×4TB NAS ~180€ la coppia, oppure 1 disco esterno USB). *Rimandabile*: l'HDD 1TB del Pavilion copre la prima fase
3. *Solo se la transcodifica manca davvero all'uso reale*: prima opzione **promuovere il Pavilion 690 a server** (gratis, transcodifica NVENC), altrimenti mini PC **Intel N150** ~130-170€ (Beelink Mini S12 Pro, NiPoGi E2, GMKtec NucBox G3) — QuickSync moderno, consumi da mini PC. Il compose file migra così com'è
4. **Raspberry Pi: scartato** — il Pi 5 non ha encoder video hardware, a parità di prezzo un N150 lo batte su tutto

## Note varie
- Consumi: U500 ~10-15W; N40L ~30-40W con dischi (~70-90 €/anno h24). **Accensione/spegnimento → guida dedicata: [GESTIONE-ENERGIA.md](GESTIONE-ENERGIA.md)**. In sintesi: WoL ✅ su entrambi (testato 1/8/2026, sul NUC via ifupdown/`ethernet-wol g`, NON NetworkManager); comando **`hs`** dal PC (`hs on/off [nas|nuc]`, output inglese, `-f` per forzare) + launcher `Accendi/Spegni server.cmd` sul Desktop — tutto ✅ operativo dal 2/8; watchdog `nas-autowake` sul NUC ✅ attivo e testato (politica: **il NAS segue il NUC**); plugin **autoshutdown** su OMV ⬜ da configurare (guida §4). Ordine: accensione NAS→NUC, spegnimento NUC→NAS (gli script lo rispettano da soli). Piano B per il NAS: BIOS con "Restore on AC Power Loss = Power On" → stacca/riattacca la corrente e si accende da solo
- RAM N40L espandibile a 8 GB ECC (16 GB non ufficiale) — per solo NAS bastano i 6 attuali
- Accesso remoto solo via Tailscale, mai port forwarding. **Tailnet `uaru-snares.ts.net` con MagicDNS (dal 4/8/2026)**: dentro ci sono glnuc, glnas (installato con `accept-dns=false`), il portatile di Luca e il telefono; key expiry disabilitato sui due server. **Homarr usa i FQDN** (`http://glnuc.uaru-snares.ts.net:<porta>`, `http://glnas...` per OMV) → tile, ping e integrazioni funzionano identici da casa e da fuori, immuni ai cambi di IP. ⚠️ WoL/`hs` funzionano solo dalla LAN di casa (i magic packet sono broadcast): da remoto il NAS si sveglia via SSH sul NUC (`ssh luca@glnuc.uaru-snares.ts.net`); entrambe spente = niente accensione remota
- Prossimo passo con Claude: ~~VPN~~ **FATTA il 4/8 sera, fase 1 + fase 2** — gluetun + ProtonVPN Plus installati e collaudati via SSH; **qBittorrent e Prowlarr entrambi nel tunnel** (kill switch, porta dinamica auto-sync, connectable, ricerca reale ok; dettagli in FASE4-DOWNLOAD.md §4, percorso decisionale in [SCELTA-VPN.md](SCELTA-VPN.md)). **Prossimi**: **indexer veri** in Prowlarr (§4.8) → la wishlist (6 film, 5 serie) si svuota da sola; riavvio di prova del NUC (da casa, col paracadute WoL); widget Homarr con integrazioni (§4 della guida Fase 4: host download client da `qbittorrent` a `gluetun`) → **indexer veri** in Prowlarr. Nel frattempo: collaudo catena quando archive.org torna su (richiesta NOTLD in coda; ricerca manuale Prowlarr + Manual Import). Rifiniture: widget Homarr (integrazioni), test direct play Jellyfin al primo video, **riavvio di prova del NUC** (da fare quando il PC è sulla LAN di casa: da remoto niente WoL di riserva), eventuale Fase 5 (dominio)
