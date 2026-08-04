# Fase 1 — NUC (Minisforum U500): Debian + Docker + servizi

> **STATO (17 lug 2026): FASE 1 COMPLETATA ✅** — Debian + Docker + Jellyfin (`:8096`) + Immich (`:2283`, admin creato) + Tailscale sull'host, tutti verificati dopo riavvio di prova (punto 9 ok). DNS verificato: il fix a `/etc/resolv.conf` sopravvive al riavvio.
>
> Rimasti aperti (non bloccanti):
> - **Jellyfin**: librerie + config direct play (Dashboard → Playback → VAAPI su `renderD128`, solo H.264) da fare quando ci sarà il primo contenuto in `/srv/media`
> - ~~NUC ancora in WiFi~~ → **passato a ethernet l'1/8/2026**: IP `192.168.1.171`, MAC `84:39:BE:6B:55:73`, WiFi disabilitato (`nmcli radio wifi off`). **Wake-on-LAN ✅ funzionante** (testato 1/8/2026 — script `sveglia-nuc.ps1` dal PC, o doppio-click su `Accendi server.cmd` sul Desktop, che sveglia NAS e NUC in ordine). Attenzione: la ethernet è gestita da **ifupdown** (`/etc/network/interfaces`), non da NetworkManager (solo WiFi) — WoL armato con `ethtool` (pacchetto installato l'1/8); persistenza ai riavvii ✅: riga `ethernet-wol g` nella stanza di `enp1s0` in `/etc/network/interfaces` (confermata 1/8). Lease DHCP statico per il MAC ethernet: **rimandato di proposito** — trasloco e cambio router in arrivo, gli IP andranno comunque rivisti (checklist in GESTIONE-ENERGIA.md)
> - **Tailscale**: verificare di aver fatto "Disable key expiry" su `glnuc` (pannello → Machines → ⋯), altrimenti tra ~6 mesi chiede il re-login
> - App Immich sul telefono: puntarla all'IP Tailscale `100.x.y.z:2283` così il backup va anche fuori casa
>
> Note di percorso: hostname reale `glnuc`; lettore SD rumoroso → moduli `sdhci` blacklistati in `/etc/modprobe.d/disable-sdcard.conf`; U500 verificato con 8 GB RAM + SSD 128 GB.

Obiettivo: NUC headless con Debian minimale, Docker, e sopra Jellyfin, Immich e Tailscale. Le librerie media stanno temporaneamente su disco locale in `/srv/media`; in Fase 3 lo stesso percorso diventerà il mount del NAS, così i container non si toccano più.

**Serve:** chiavetta USB da 4 GB+, monitor + tastiera USB (solo per l'installazione), cavo ethernet verso il router.

---

## 1. Preparare la USB (da Windows)

1. [ ] Scarica la ISO **Debian stable netinst amd64** (~700 MB): https://www.debian.org/download
2. [ ] Scarica **Rufus**: https://rufus.ie/
3. [ ] Rufus: seleziona la chiavetta e la ISO, lascia i default (**GPT / UEFI**), avvia. Alla domanda sulla modalità di scrittura scegli **"Scrivi in modalità immagine ISO (consigliato)"**
   - Se poi il NUC non dovesse avviarsi dalla USB: rifai con schema **MBR / "BIOS o UEFI-CSM"**

## 2. Installare Debian

1. [ ] Collega il NUC via **ethernet**, monitor e tastiera. Accendi e apri il boot menu (Minisforum: di solito **F7**, altrimenti **Canc/F2** per il BIOS) → avvia da USB
2. [ ] **Graphical install**, poi:

   | Schermata | Scelta |
   |---|---|
   | Lingua | English (messaggi d'errore più googlabili) |
   | Località / tastiera | Italy / Italian |
   | Hostname | `nuc` |
   | Domain | lascia vuoto |
   | **Password di root** | **LASCIALA VUOTA** → così il tuo utente finisce automaticamente nel gruppo sudo |
   | Utente | nome completo e username (es. `luca`) + password |
   | Partizionamento | Guided – use entire disk → All files in one partition |
   | Mirror | Italia → `deb.debian.org`, proxy vuoto |
   | **Software selection** | **DEseleziona** "Debian desktop environment" e GNOME; **seleziona solo** `SSH server` + `standard system utilities` |

3. [ ] Fine installazione → riavvio, togli la USB. Il NUC mostra un login testuale: da qui in poi tutto via SSH
4. [ ] (Consigliato) Nel BIOS imposta **"Restore on AC Power Loss → Power On"**: dopo un blackout il server riparte da solo

## 3. Primo accesso via SSH

1. [ ] Sul NUC (da console) trova l'IP: `ip a` → es. `192.168.0.x`
2. [ ] Sul **router**, fai una **DHCP reservation** per il MAC del NUC (più semplice e pulito dell'IP statico lato Debian) — es. `192.168.0.10`
3. [ ] Da Windows (PowerShell): `ssh luca@192.168.0.10`
4. [ ] Aggiorna:
   ```bash
   sudo apt update && sudo apt full-upgrade -y
   ```
5. [ ] Verifica che la iGPU sia visibile (serve per Jellyfin):
   ```bash
   ls -l /dev/dri     # devono esserci card0 e renderD128
   ```

## 4. Installare Docker

Comandi dalla guida ufficiale (https://docs.docker.com/engine/install/debian/), in blocco:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Poi:

```bash
sudo usermod -aG docker $USER
exit   # riconnettiti in SSH per applicare il gruppo
docker run hello-world   # verifica
```

## 5. Cartelle media (temporanee su disco locale)

```bash
sudo mkdir -p /srv/media/{musica,film,serie,immich}
sudo chown -R $USER:$USER /srv/media
```

> In Fase 3 monteremo lo share del NAS su `/srv/media`: i percorsi visti dai container non cambieranno.

## 6. Jellyfin

```bash
mkdir -p ~/docker/jellyfin/{config,cache}
cd ~/docker/jellyfin
getent group render   # annota il numero (gid), es. 105
nano docker-compose.yml
```

Contenuto (correggi il gid di `render` se diverso da 105):

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin
    container_name: jellyfin
    user: 1000:1000
    group_add:
      - "105"            # gid del gruppo "render" (getent group render)
    network_mode: host   # UI su :8096; semplifica discovery/DLNA
    volumes:
      - ./config:/config
      - ./cache:/cache
      - /srv/media:/media:ro
    devices:
      - /dev/dri:/dev/dri
    environment:
      - TZ=Europe/Rome
    restart: unless-stopped
```

```bash
docker compose up -d
```

- [ ] Apri `http://192.168.0.10:8096` → wizard: utente admin, librerie che puntano a `/media/musica`, `/media/film`, ecc.
- [ ] **Strategia direct play** (il Broadwell non transcodifica HEVC):
  - Dashboard → Playback → Transcoding: Hardware acceleration = **VAAPI**, device `/dev/dri/renderD128`, abilita **solo H.264** come codec hardware (è l'unico che la HD 5500 fa davvero) — resta come rete di sicurezza
  - Nei **client** imposta qualità su **massima/auto** così i file partono in direct play senza toccare il server

## 7. Immich

Immich va installato con il compose ufficiale (le immagini/tag cambiano spesso, meglio il loro file):

```bash
mkdir -p ~/docker/immich && cd ~/docker/immich
wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml
wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env
nano .env
```

Nel `.env` imposta:
- `UPLOAD_LOCATION=/srv/media/immich` (le foto: in Fase 3 finiranno sul NAS)
- `DB_PASSWORD=` una password robusta
- decommenta/imposta `TZ=Europe/Rome`
- **lascia `DB_DATA_LOCATION` al default locale**: il database NON va mai sul NAS

```bash
docker compose up -d
```

- [ ] Apri `http://192.168.0.10:2283` → crea l'account admin, installa l'app sul telefono e punta al server

## 8. Tailscale (sull'host, non in Docker)

Installarlo direttamente su Debian è più robusto del container: copre anche SSH e qualsiasi servizio futuro senza configurazione extra.

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up   # stampa un URL: aprilo e fai login (Google/GitHub/ecc.)
tailscale ip -4     # l'IP 100.x.y.z del NUC nella tailnet
```

- [ ] Installa il client Tailscale su telefono e PC (https://tailscale.com/download) con lo stesso account
- [ ] Da fuori casa: Jellyfin su `http://100.x.y.z:8096`, Immich su `http://100.x.y.z:2283`, SSH su `ssh luca@100.x.y.z`

## 9. Checklist finale

- [ ] `docker ps` → jellyfin + i container immich tutti "Up"
- [ ] Jellyfin raggiungibile in LAN e via Tailscale, riproduce un file di prova in direct play
- [ ] Immich raggiungibile, backup foto dal telefono funziona
- [ ] Riavvia il NUC (`sudo reboot`): tutto deve tornare su da solo
- [ ] Prossimo passo → **Fase 2**: reinstallazione N40L con OpenMediaVault (vedi RECAP)
