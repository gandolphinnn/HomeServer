# Automated Home Media Server Setup — Analisi del video

> **Video:** [Automated Home Media Server Setup](https://www.youtube.com/watch?v=3Q7UGg8LRJA)
> **Canale:** [TechWithDavid](https://www.youtube.com/@techwithdavidolding)
> **Pubblicato:** 22 gennaio 2024 · **Durata:** 6:01 · **Visualizzazioni:** ~164.000
> **Hardware usato dall'autore:** Raspberry Pi 4 (kit con case ventolato)

## In sintesi

L'autore mostra il suo setup completo di **home media server automatizzato end-to-end**: si cerca un film o una serie TV da app mobile, e il sistema la trova, la scarica, rinomina i file e la rende disponibile in streaming su tutta la rete di casa — senza alcun intervento manuale.

Il video è una **panoramica ad alto livello** (non un tutorial passo-passo): per ogni componente spiega *cosa fa e perché serve*, rimandando a tutorial esterni per l'installazione. Tutto gira in **container Docker**, definiti tramite file **Docker Compose** (l'autore preferisce avere tutto "as code").

> ⚠️ L'autore stesso precisa: contenuto a scopo educativo — scaricare solo contenuti di cui si possiedono i diritti.

## Capitoli del video

| Timestamp | Capitolo | Argomenti |
|-----------|----------|-----------|
| 00:00 | Intro | Obiettivo: media server automatizzato end-to-end |
| 00:30 | Management | Portainer, Homarr, qBittorrent + VPN |
| 02:26 | Automation | Sonarr, Radarr, Prowlarr |
| 03:37 | Media | Jellyfin, LunaSea, Nginx reverse proxy, Usenet |

## Lo stack, componente per componente

### 1. Gestione (Management)

**Portainer** — Interfaccia web per gestire tutti i container Docker. Con tanti servizi attivi, permette di vedere lo stato di ogni container a colpo d'occhio e di aprire una shell dentro un container con un click, senza ricordare comandi. L'autore lo usa per *visualizzare e gestire*, ma crea comunque i container via Docker Compose per avere tutto versionabile come codice.

**Homarr** — Dashboard unica per tutti i servizi del media server. Mostra lo stato di ogni servizio (fa ping periodici), i download in corso, chi sta guardando cosa, e un calendario delle prossime uscite delle serie TV. Interfaccia drag-and-drop, molto semplice da configurare.

**qBittorrent** — Client torrent scelto perché il più raccomandato nei forum: gratuito, ricco di funzionalità e con una web UI accessibile da tutta la rete locale.

**VPN** — Da abbinare **obbligatoriamente** a qBittorrent per anonimizzare il traffico dei download. L'autore rimanda a un suo tutorial dedicato (link sotto).

### 2. Automazione (Automation)

Qui avviene "la magia" del setup:

**Sonarr** — Automazione per le **serie TV**: cerchi una serie, e Sonarr interroga automaticamente gli indexer/siti torrent configurati, trova la release, la passa al client torrent, e a download completato fa pulizia e rinomina di cartelle e file. Tutto da solo.

**Radarr** — Identico a Sonarr ma per i **film**.

**Prowlarr** — Gestore centralizzato degli **indexer**. Senza Prowlarr, ogni app della famiglia *arr (Sonarr, Radarr, ma anche quelle per musica, audiolibri, giochi…) andrebbe configurata singolarmente con i siti di ricerca. Con Prowlarr aggiungi un indexer una sola volta e lui lo propaga automaticamente a tutte le app collegate.

### 3. Media

**Jellyfin** — Il media server vero e proprio, per lo streaming sulla rete di casa. L'autore ha provato **Plex** ed **Emby** prima di sceglierlo: Jellyfin vince perché **gratuito, open source e community-driven**. Lo usa su telefono e Android TV senza problemi.

**LunaSea** — App mobile di tipo "request library": si collega a Sonarr e Radarr e permette di **richiedere** un film o una serie direttamente dal telefono. Selezioni il titolo, LunaSea inoltra la richiesta, e nel giro di poche ore il contenuto è pronto per lo streaming. Si potrebbe fare lo stesso dalle web UI di Sonarr/Radarr, ma da mobile è molto più comodo.

### 4. Menzionati ma non ancora implementati dall'autore

**Nginx reverse proxy** — Per esporre servizi selezionati (es. Jellyfin) su internet e guardare i propri contenuti **fuori casa** (pendolarismo, vacanze) o condividerli con famiglia e amici. Senza, il server è raggiungibile solo dalla LAN.

**Usenet** — Alternativa al torrent per il reperimento dei contenuti; più volte raccomandata all'autore e ritenuta più veloce, ma non l'ha ancora approfondita.

## Il flusso end-to-end

```
LunaSea (richiesta da mobile)
   └─> Sonarr / Radarr (ricerca automatica)
         └─> Prowlarr (indexer centralizzati)
               └─> qBittorrent + VPN (download anonimo)
                     └─> Sonarr/Radarr (rinomina e organizza i file)
                           └─> Jellyfin (streaming su TV, telefono, ecc.)

Portainer + Homarr = gestione e monitoraggio di tutto lo stack (container Docker)
```

## Link utili dalla descrizione del video

| Componente | Tutorial consigliato dall'autore |
|------------|----------------------------------|
| Portainer | [Video tutorial](https://www.youtube.com/watch?v=ljDI5jykjE8&t=796s) |
| Homarr | [Guida PiMyLifeUp (Raspberry Pi)](https://pimylifeup.com/raspberry-pi-homarr-dashboard/) |
| qBittorrent + VPN | [Video tutorial](https://www.youtube.com/watch?v=nSb6Rppb9gI) |
| Sonarr | [Immagine Docker linuxserver.io](https://github.com/linuxserver/docker-sonarr/pkgs/container/sonarr) |
| Radarr | [Immagine Docker linuxserver.io](https://github.com/linuxserver/docker-sonarr/pkgs/container/radarr) |
| Prowlarr | [Immagine Docker linuxserver.io](https://github.com/linuxserver/docker-sonarr/pkgs/container/prowlarr) |
| Jellyfin | [Video tutorial](https://youtu.be/_s9w3k5Lrxw) |
| LunaSea | [Sito ufficiale](https://www.lunasea.app/) |

## Considerazioni per il progetto HomeServer

- Lo stack è pensato per girare interamente in **Docker**: un unico `docker-compose.yml` può definire tutti i servizi (approccio che l'autore raccomanda rispetto alla creazione manuale dei container).
- L'hardware richiesto è modesto: all'autore basta un **Raspberry Pi 4**; qualsiasi mini-PC o server casalingo è più che sufficiente.
- Ordine sensato di implementazione: prima **Portainer** (gestione), poi **Jellyfin** (il cuore), poi la catena di automazione **Prowlarr → Sonarr/Radarr → qBittorrent+VPN**, infine le comodità (**Homarr**, **LunaSea**) e in futuro l'accesso remoto (**reverse proxy**).
- Il video è del gennaio 2024: i componenti citati sono ancora tutti attivi e mantenuti; come app di richiesta, oggi molti usano anche **Jellyseerr** in alternativa a LunaSea.
