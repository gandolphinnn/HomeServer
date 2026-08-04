# Fase 2 — NAS (HP MicroServer N40L): OpenMediaVault da zero

> **STATO (30 lug 2026, sera): FASE 2 QUASI COMPLETA** — NAS nella posizione definitiva, IP `192.168.1.17` (DHCP **senza** lease statico, scelta di Luca — se l'IP cambia vanno aggiornati share mappati e fstab). Fatti i punti 4–7: flashmemory installato, SMART ok su tutti e 4 i dischi (0 settori riallocati/pending; ore: sda 72.603, sdb/sdc/sdd 84.988), wipe, **RAID10 `/dev/md0`** (~1,86 TiB) + ext4 montato (soglia warning 85%), utente `luca`, share `media` via SMB **testato da Windows** e mappato come unità `Z:` persistente sul PC.
> **✅ FASE 2 COMPLETATA (31 lug 2026)**: resync finito (RAID `clean`), riavvio di prova superato — RAID montato e share `Z:` raggiungibile senza intervento manuale.
>
> **Problemi incontrati e come sono stati risolti (sessione 30/7 sera):**
> - **"Multiple Device" assente sotto Storage** → nelle versioni recenti di OMV il RAID software è un plugin: System → Plugins → installare `openmediavault-md`, poi F5
> - **Porta 445 chiusa dopo aver "abilitato" SMB** → la config non era stata applicata (`smbd` risultava `inactive/disabled`): il toggle Enabled non era stato salvato/confermato con la barra gialla. Diagnosi+fix via SSH: `omv-confdbadm read conf.service.smb` (dice se `enable` è true) e `omv-salt deploy run samba` (riapplica la config)
> - **`net view` da Windows dà "Access is denied"** → normale: senza credenziali il NAS non elenca le share; il test vero è aprire `\\192.168.1.17\media` con l'utente `luca`
>
> **Problemi delle sessioni precedenti:**
> - **Nessun output video all'avvio** → risolto con i controlli base (cavo/ingresso monitor/riavvio); causa esatta non identificata
> - **"Failed to create a file system" ripetuto a ogni tentativo** → causa vera: c'era **una sola chiavetta** collegata (l'installer, messa nella porta interna per equivoco) e l'installer stava cercando di **formattare se stesso**. Diagnosi decisiva dal log **Alt+F4**: `partman: /dev/sde1 is mounted; will not make a filesystem here!`. Lezione: servono **due chiavette** — installer (temporanea) + destinazione (permanente, senza Rufus)
> - **Porte USB frontali invisibili al BIOS** (né nel boot menu né nella lista boot) → workaround: installer nella porta **interna** (bootabile di sicuro), destinazione in porta **posteriore**, scambio delle chiavette a installazione finita. Le frontali restano da testare da sistema avviato
> - **"Console vuota" all'avvio** → era il fallback **PXE (HP PXE ROM)**: nessun device avviabile trovato → il BIOS tentava il boot da rete. Fix: PXE in fondo al boot order / disabilitato
> - **F11 che "non funziona"** → va premuto a raffica dal primo secondo; se il LED NumLock della tastiera è muto, cambiare porta USB alla tastiera
> - **Chiavetta FreeNAS 4 GB del 2011** → scartata come disco OS (troppo piccola e vecchia); l'OS sta sulla chiavetta nuova 16-32 GB

Obiettivo: N40L ripulito (FreeNAS 8 e pool ZFS eliminati — **decisione del 17/7/2026: i dati vecchi non servono**) e reinstallato con OpenMediaVault: RAID sui 4 dischi, ext4, share SMB per il NUC e per Windows.

**Serve:**
- Monitor **VGA** + tastiera USB (solo per l'installazione)
- La chiavetta USB dell'installer (va bene riformattare quella usata per Debian)
- Una **chiavetta 16-32 GB di qualità** per l'OS (nuova/affidabile — NON riusare quella FreeNAS del 2011)
- N40L collegato via ethernet alla rete di casa

---

## 0. Preparazione hardware

1. [ ] Apri il case (la porta frontale si sblocca con la chiavetta in dotazione; la porta USB interna è sulla scheda madre, in basso)
2. [ ] Sfila la **vecchia chiavetta FreeNAS** dalla porta USB interna e mettila da parte (etichettala "FreeNAS vecchio" — è l'unico "backup" della vecchia config)
3. [ ] Inserisci al suo posto la **chiavetta nuova 16-32 GB** (sarà il disco di sistema di OMV)
4. [ ] Controlla che i 4 dischi nei bay siano ben inseriti

## 1. USB installer (da Windows)

1. [ ] Scarica la ISO di OMV: https://sourceforge.net/projects/openmediavault/files/iso/ (ultima versione, file `.iso`)
2. [ ] Rufus: seleziona chiavetta installer + ISO, ma stavolta **schema MBR** e sistema destinazione **"BIOS (o UEFI-CSM)"** — il N40L è solo BIOS legacy. Modalità: "Scrivi in modalità immagine ISO"

## 2. Installazione

1. [ ] Chiavetta installer in una porta USB **frontale**, monitor VGA e tastiera collegati, accendi → **F11** (boot menu) → scegli la chiavetta USB
2. [ ] Installer testuale (è Debian sotto il cofano):

   | Schermata | Scelta |
   |---|---|
   | Lingua / località / tastiera | English / Italy / Italian |
   | Hostname | `nas` |
   | Domain | vuoto |
   | Password di **root** | scegline una e segnatela (serve per l'SSH di manutenzione; è separata dall'admin web) |
   | **Disco di destinazione** | ⚠️ la **chiavetta 16-32 GB interna** — riconoscila dalla DIMENSIONE. NON i 4 dischi da 1 TB, NON la chiavetta installer |
   | Mirror | Italia → `deb.debian.org` |

3. [ ] Fine → riavvio → **togli la chiavetta installer**. Sulla console comparirà l'IP della web UI (tipo `http://192.168.1.x`)

## 3. Web UI — primi passi

1. [ ] Dal PC: `http://<ip-del-nas>` → login **`admin` / `openmediavault`**
2. [ ] **Cambia subito la password admin**: icona utente in alto a destra → Change Password
3. [ ] Sulla iliadbox: **lease DHCP statico** anche per il NAS (Rete locale/DHCP → Lease statici, commento `NAS`)

## 4. Plugin flashmemory (protegge la chiavetta OS)

Riduce le scritture sulla USB, allungandole la vita. Via SSH (`ssh root@<ip-del-nas>`, password di root dell'installer):

```bash
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install | bash
```

Poi web UI → **System → Plugins** → cerca `openmediavault-flashmemory` → installa (segui le note del plugin).

## 5. Wipe dischi + controllo salute ⚠️ PUNTO DI NON RITORNO

1. [x] **Storage → Disks**: seleziona ognuno dei 4 dischi da 1 TB → **Wipe** (Quick) — cancella anche i residui ZFS. Da qui i vecchi dati non esistono più
2. [x] **Storage → S.M.A.R.T.**: abilita il monitoraggio, poi guarda i dettagli di ogni disco: **Power_On_Hours**, **Reallocated_Sector_Ct**, **Current_Pending_Sector**. Dischi di 15 anni: se uno ha settori riallocati/pending in crescita, va declassato o pensionato — *esito 30/7: tutti e 4 sani, 0 riallocati/pending*

## 6. RAID + filesystem

1. [x] **Storage → Multiple Device** → Create → **RAID10** con i 4 dischi (~1.8 TB utili, regge il guasto di un disco per coppia). La sincronizzazione iniziale dura ore: si può continuare a configurare nel frattempo — *nota: la voce compare solo dopo aver installato il plugin `openmediavault-md`*
2. [x] **Storage → File Systems** → Create → **ext4** sul device RAID appena creato → poi Mount

## 7. Utente e condivisioni

1. [x] **Users → Users** → crea utente `luca` con password (è l'utente con cui NUC e Windows accederanno)
2. [x] **Storage → Shared Folders** → crea `media` (sul filesystem RAID, permessi: luca read/write)
3. [x] **Services → SMB/CIFS**: abilita il servizio, poi tab Shares → aggiungi `media` — *attenzione a confermare la barra gialla, vedi problemi in cima*
4. [x] Test da Windows: Esplora file → `\\192.168.1.17\media` → login con `luca` → file copiato e riaperto ok; share mappato come unità `Z:` persistente

## 8. Rifiniture

- [x] **Riavvio di prova**: tutto deve tornare su da solo (RAID montato, share raggiungibile) — *ok 31/7, RAID `clean`*
- [x] Rimetti il coperchio, sistema il NAS nella posizione definitiva
- [ ] Prossimo passo → **Fase 3**: mount dello share sul NUC in `/srv/media` (fstab — la riga la scriviamo insieme, decidendo SMB vs NFS)
