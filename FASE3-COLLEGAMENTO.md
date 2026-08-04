# Fase 3 — Collegamento NUC ↔ NAS: `/srv/media` sul RAID

> **STATO (31 lug 2026): COMPLETATA ✅** — mount CIFS verificato dopo riavvio di prova: `//192.168.1.17/media` su `/srv/media` (~1.8T), container tutti su in automatico.
>
> **Com'è andata davvero** (per memoria): una prima sessione si è interrotta a metà — container fermati (`docker compose down`), scambio cartelle fatto, riga fstab scritta, ma **mount mai eseguito e rsync mai partito**. Risultato: Jellyfin/Immich riavviati più tardi su una `/srv/media` locale semivuota; Docker ha creato una cartella `immich` fantasma e il controllo d'integrità di Immich (file-marcatori `.immich`) ha bloccato `immich_server` in crash-loop. La Fase è stata completata nella sessione del Blocco A (Fase 4).
>
> **Incidente Immich**: nei passaggi il database è risultato azzerato (file intatti sul NAS: 5,2 GB in `upload/`). Tentato il ripristino dal dump automatico del 31/7 02:00 senza successo → **decisione di Luca: reset totale di Immich** (db + foto cancellati, nuovo account admin, backup ri-attivato dal telefono via Tailscale). Lezione: i dump notturni in `immich/backups/` esistono e vanno provati con più calma la prossima volta.
>
> Code aperte:
> - [ ] `/srv/media-local` (copia di sicurezza pre-migrazione, ~6 GB su SSD): eliminare → `sudo rm -rf /srv/media-local` (unico contenuto residuo: le vecchie foto Immich scartate col reset — verificare prima che sul telefono ci sia ancora tutto)
> - [x] MP3 sciolti nella radice dello share: spostati in `musica/` ✅ → prima libreria Jellyfin "Musica" su `/media/musica`
> - Nota: lo share sul PC Windows è mappato come **`G:`** (prima era `Z:`)
> - [x] Regola operativa: **accendere il NAS prima del NUC** (con NAS spento al boot, `nofail` fa partire il NUC con `/srv/media` vuota; Immich si autoprotegge, Jellyfin vede librerie vuote) → dall'1/8/2026 **automatizzata**: il watchdog `nas-autowake` sul NUC sveglia il NAS, monta lo share e riavvia i container da solo (vedi [GESTIONE-ENERGIA.md](GESTIONE-ENERGIA.md))

> Decisione: **SMB/CIFS** (non NFS): già attivo e testato sul NAS, stesso utente `luca` di Windows, prestazioni equivalenti per lo streaming media. NFS resta un'opzione futura (basta cambiare la riga di fstab) — tornerà in ballo in Fase 4 Blocco B se gli hardlink su CIFS non funzionano.

Obiettivo: il NUC monta lo share `media` del NAS su `/srv/media` in modo permanente (fstab). Jellyfin e Immich non cambiano configurazione: `/srv/media` è il percorso-contratto, cambia solo cosa c'è dietro (RAID del NAS invece dell'SSD locale).

- NAS: `192.168.1.17` (share `media`, utente `luca`) — ⚠️ niente lease statico: se l'IP cambia, aggiornare fstab
- NUC: `glnuc`, `192.168.1.171` (`ssh luca@192.168.1.171`) — nota storica: all'epoca della Fase 3 era in WiFi su `192.168.1.192`, dall'1/8/2026 è su ethernet e il WiFi è spento

---

## 1. Ricognizione (sul NUC)

1. [x] `du -sh /srv/media/*` — quanti dati ci sono da spostare (esito: ~6,2 GB, quasi tutto Immich)
2. [x] `docker ps` — cosa sta girando
3. [x] `id luca` — verificare uid/gid (1000/1000)

## 2. Client CIFS + credenziali

1. [x] `sudo apt install cifs-utils`
2. [x] File credenziali `/root/.smb-nas` (root-only, così la password non sta in fstab):
   ```
   username=luca
   password=<password di luca sul NAS>
   ```
3. [x] `sudo chmod 600 /root/.smb-nas`

## 3. Stop dei container (prima di toccare i dati)

```bash
cd ~/docker/immich && docker compose down
cd ~/docker/jellyfin && docker compose down
```

✅ (nota: `down` RIMUOVE i container — i dati restano nelle cartelle; per ricrearli serve `up -d`. Per fermare senza rimuovere: `stop`)

## 4. Scambio cartelle + fstab

1. [x] `sudo mv /srv/media /srv/media-local && sudo mkdir /srv/media`
2. [x] Riga in `/etc/fstab` (una sola riga):
   ```
   //192.168.1.17/media  /srv/media  cifs  credentials=/root/.smb-nas,uid=1000,gid=1000,file_mode=0664,dir_mode=0775,iocharset=utf8,_netdev,nofail  0  0
   ```
   - `_netdev,nofail`: il NUC non si blocca al boot se il NAS è spento
   - `uid/gid=1000`: i file montati appartengono a `luca` (i container ci scrivono con quell'utente)
3. [x] `sudo systemctl daemon-reload && sudo mount /srv/media`
4. [x] Verifica: `df -h /srv/media` mostra ~1.8T ✅

## 5. Copia dei dati

```bash
sudo apt install -y rsync   # non incluso nella Debian minimale
sudo rsync -a --info=progress2 /srv/media-local/ /srv/media/
```

✅ (~6,2 GB via WiFi; `/srv/media-local` resta come rete di sicurezza per qualche giorno)

## 6. Riavvio container + verifiche

1. [x] Jellyfin su http://192.168.1.192:8096 ✅
2. [x] Immich su http://192.168.1.192:2283 — ⚠️ qui è emerso il database azzerato → reset totale (vedi STATO)
3. [x] Test incrociato Windows `Z:` ↔ NUC `/srv/media` ✅

## 7. Rifiniture

- [x] **Riavvio di prova del NUC** (31/7): mount automatico + tutti i container su da soli ✅
- [ ] Dopo qualche giorno di uso senza problemi: `sudo rm -rf /srv/media-local`
- [ ] Prossimi passi dopo la Fase 3: librerie Jellyfin + direct play (VAAPI), riempire `/srv/media` di contenuti, backup foto (Beelink off-site?), switch gigabit per portare il NUC su cavo
