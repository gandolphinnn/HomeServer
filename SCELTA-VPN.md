# Scelta della VPN per lo stack torrent

*Creato: 4 agosto 2026 — STATO: **DECISO (ProtonVPN Plus) e INSTALLATO la sera stessa** — gluetun operativo e collaudato, dettagli in [FASE4-DOWNLOAD.md](FASE4-DOWNLOAD.md) §4*

Questo documento risponde a due domande, in ordine:
1. **Serve davvero una VPN?** (risposta onesta, senza terrorismi da marketing)
2. Se sì, **quale?** (requisiti, confronto, prezzi verificati, raccomandazione)

---

## 1. Serve davvero una VPN?

**Risposta breve e onesta: no in assoluto, sì di fatto per l'uso che abbiamo in programma.**

- Finché scarichi **solo contenuti legali** (ISO Linux, pubblico dominio, Internet Archive — la situazione di oggi): la VPN **non serve a niente**. Nessun rischio da mitigare.
- Se aggiungiamo **indexer veri** con contenuti protetti da copyright (il piano dichiarato): la VPN diventa **l'assicurazione più economica ed efficace disponibile**. Non è un obbligo tecnico — lo stack funzionerebbe anche senza — è una scelta di gestione del rischio. Ecco i fatti per decidere.

### 1.1 Cosa vede chi, quando usi BitTorrent senza VPN

BitTorrent è un protocollo **pubblico per design**: per scaricare un pezzo di file da un altro peer, devi dirgli il tuo IP. Non c'è modo di parteciparvi "di nascosto".

| Chi | Cosa vede |
|-----|-----------|
| **Chiunque nello swarm** | Il tuo IP di casa, associato al file esatto che stai scaricando/seedando, con data e ora. Basta aprire un client e guardare la lista peer. |
| **Società di monitoraggio** | Aziende specializzate entrano negli swarm dei titoli più scambiati **apposta** per raccogliere IP + timestamp in automatico, per conto dei detentori dei diritti. Sui torrent popolari è una presenza costante, non un'ipotesi. |
| **Il tuo ISP (iliad)** | Che fai traffico BitTorrent (il pattern è riconoscibile anche cifrato) e verso quali IP. Per legge italiana conserva i log di associazione IP↔intestatario **fino a 72 mesi**. |

La cifratura del protocollo in qBittorrent e l'"anonymous mode" **non risolvono nulla di tutto questo**: l'IP nello swarm resta il tuo.

### 1.2 Il quadro legale italiano, in breve

*(Sintesi da profano, non è consulenza legale.)*

- **Scaricare** opere protette per uso personale: illecito **amministrativo** (art. 174-ter L. 633/1941) — sanzione da €154, con confisca.
- **Condividere** (upload): con BitTorrent è inevitabile — mentre scarichi, ricarichi. La "messa a disposizione del pubblico" è un illecito **penale** (art. 171 L. 633/41, multa; se a scopo di lucro si passa all'art. 171-ter, molto più serio — non è il nostro caso, ma è il motivo per cui il torrent è più esposto dello streaming).
- **Storicamente l'enforcement contro i singoli utenti P2P in Italia è stato raro**: il caso Peppermint (2007) — migliaia di lettere agli utenti P2P — finì con il Garante Privacy che dichiarò illegittimo il monitoraggio di massa a fini civili. È il motivo per cui in Italia non c'è mai stata l'industria delle diffide alla tedesca.
- **Ma il clima è cambiato**: con la L. 93/2023 ("Piracy Shield") l'attenzione è salita. Il grosso riguarda IPTV e sport live, però le sanzioni agli **utenti finali** sono passate dalla teoria alla pratica (operazioni GdF con multe da €154 a migliaia di utenti IPTV nel 2024-25, raddoppiabili fino a €5.000 in caso di recidiva). Il P2P non è il bersaglio principale oggi, ma i log per risalire a te esistono e restano.

**Bilancio onesto**: probabilità storicamente bassa, conseguenze da fastidiose a serie, trend in peggioramento. Contro un costo di ~€3/mese.

### 1.3 Gli altri motivi (non legali) per cui la VPN conviene comunque

1. **Blocchi AGCOM**: molti indexer/tracker sono bloccati a livello DNS/IP dagli ISP italiani. La VPN li rende di nuovo raggiungibili senza trucchi caso per caso.
2. **Privacy dall'ISP**: iliad smette di vedere il tuo traffico torrent (vede solo un tunnel cifrato verso il provider VPN).
3. **Port forwarding = seeding funzionante**: paradossalmente, con la VPN giusta i torrent andranno **meglio** di oggi. Ora nessuna porta in ingresso è aperta sul router (e sulla iliadbox l'IPv4 di default può essere condiviso con altri clienti — da verificare nell'area riservata): i peer non possono connettersi a te. Con la porta inoltrata dalla VPN, sì.
4. **Igiene di rete**: l'IP di casa (dietro cui vivono NAS, NUC, i tuoi dispositivi) smette di essere pubblicato a sconosciuti negli swarm.

### 1.4 Cosa la VPN NON fa

- **Non rende legale ciò che è illegale.** Sposta il rischio, non lo azzera: resta la nota etica/legale già in FASE4-DOWNLOAD.md — buon senso su cosa scaricare.
- **Non c'entra con Tailscale.** Tailscale è una rete privata **tra i TUOI dispositivi** (per raggiungere casa da fuori); la VPN commerciale anonimizza **l'uscita verso internet**. Coesistono senza conflitti: gluetun incapsula solo qBittorrent, tutto il resto (Tailscale compreso) non cambia.

### 1.5 L'alternativa senza VPN: Usenet (per completezza)

Esiste una strada diversa che non richiede VPN: **Usenet** (SABnzbd al posto di qBittorrent, indexer NZB, provider tipo Eweka/Newshosting ~€40-60/anno). Il download è una connessione diretta cifrata col provider — **niente swarm, niente upload, il tuo IP non è visibile a terzi**. Contro: si paga il provider + spesso l'indexer, la retention non copre tutto, e Sonarr/Radarr andrebbero riconfigurati. Costo totale simile o superiore alla VPN. La segno perché è la risposta corretta a "esiste un modo senza VPN?" — ma per il nostro stack già montato, VPN + torrent resta la strada più semplice.

---

## 2. Requisiti tecnici per il nostro stack

La short-list non nasce da classifiche generiche ma da requisiti precisi:

| Requisito | Perché |
|-----------|--------|
| **Port forwarding** | Senza porta in ingresso i peer non ti raggiungono: seeding azzoppato e download lenti sui torrent poco popolati. **È il requisito che elimina il 90% dei provider.** |
| **P2P ammesso** | Alcuni provider vietano o limitano il torrent. |
| **Supporto gluetun** | Il provider deve essere tra quelli integrati in gluetun (kill switch e config automatica). |
| **WireGuard** | Protocollo moderno: più veloce e stabile di OpenVPN, meno CPU sul NUC. |
| **No-log credibile** | L'anonimato vale quanto la promessa di non registrare chi eri. |
| **Banda illimitata** | Centinaia di GB/mese tra download e seeding continuo. |

### Perché le VPN gratuite sono fuori gioco

- Le free tier **oneste** (ProtonVPN Free, Windscribe Free…) tagliano esattamente ciò che serve: P2P vietato o limitato, **zero port forwarding**, cap di traffico (10 GB/mese quando un solo film 1080p ne pesa 8-15), velocità ridotte.
- Le gratuite **"illimitate"** si pagano in altro modo: vendita dei dati di navigazione, pubblicità iniettata, o casi documentati (Hola VPN) di **rivendita della tua banda e del tuo IP** ad altri utenti. Pagare con la privacy un servizio comprato per avere privacy è un controsenso.
- Il "fai da te" (VPS gratuito + WireGuard): l'IP del VPS è intestato a te → zero anonimato, problema non risolto.

---

## 3. I candidati

### AirVPN — il profilo "seedbox"

**Pro**
- **Port forwarding statico**: riservi la porta dal pannello web e **resta tua per sempre**. La imposti una volta in qBittorrent e non ci pensi più — zero automazione da mantenere. Nessun altro provider offre porte permanenti senza far pagare un IP dedicato.
- **Tutti i server** supportano P2P e port forwarding: nessuna lista di server "giusti" da cercare.
- Prezzi bassi (vedi §4) e **prova da 3 giorni a €2** per collaudare tutto prima di impegnarsi.
- Storia torrent-first (fondata da attivisti nel 2010), no-log, pagamenti anche in crypto, WireGuard, provider nativo in gluetun.

**Contro**
- Rete server piccola rispetto ai big (irrilevante per noi: serve un server europeo veloce, non 100 paesi).
- Sito e app spartani, "da smanettoni" (irrilevante: gluetun non usa le app).
- Sede legale in **Italia**: nessun problema noto in 15 anni, ma il contesto normativo italiano (Piracy Shield/AGCOM) è più aggressivo di quello svizzero. Punto di attenzione, non un blocco.
- Nessun audit indipendente recente (Proton ne ha).

### ProtonVPN (piano Plus) — il profilo "ecosistema"

**Pro**
- Brand solido, **audit indipendenti** pubblici, sede in Svizzera.
- Server veloci (10 Gbps) e rete molto grande.
- **App eccellenti** per telefono/PC: ha senso se vuoi una VPN anche per i dispositivi personali (nota: per raggiungere casa hai già Tailscale, quindi questo valore per te è ridotto).
- Port forwarding incluso nel piano Plus senza costi extra; free tier utile come extra su altri dispositivi.

**Contro**
- **Port forwarding dinamico** (NAT-PMP): la porta **cambia a ogni riconnessione** e va rinnovata ogni 60 secondi. Gluetun sa farlo e sa aggiornare qBittorrent via API, ma è un ingranaggio in più da configurare e diagnosticare quando s'inceppa.
- P2P e port forwarding **solo su alcuni server**: gluetun va configurato per scegliere quelli giusti.
- Setup iniziale più macchinoso: config WireGuard da generare a mano dal pannello Proton con flag NAT-PMP attivo.

### Scartate (e perché)

| Provider | Motivo dell'esclusione |
|----------|------------------------|
| **Mullvad** | Privacy eccellente, ma **port forwarding rimosso nel 2023** → seeding azzoppato. |
| **PIA** | Ha il port forwarding e costa poco, ma proprietà Kape Technologies (reputazione discussa) e porta comunque dinamica. |
| **NordVPN, ExpressVPN, Surfshark** | Niente port forwarding. Fine della valutazione. |
| **Qualunque gratuita** | Vedi §2. |

---

## 4. Prezzi (verificati il 4/8/2026)

| | **AirVPN** | **ProtonVPN Plus** |
|---|---|---|
| Mensile | €7 | ~$9,99 |
| Annuale | **€49 (~€4,08/mese)** | ~$47,88 (~$3,99/mese) |
| Piano lungo | **€99 / 3 anni (~€2,75/mese)** | ~$71,76 / 2 anni (~$2,99/mese) |
| Prova | **3 giorni a €2** | Free tier (ma senza P2P/PF: non testa il nostro caso) |

Prezzi simili sui piani lunghi: **la differenza vera non è economica, è architetturale** (porta statica vs dinamica).

---

## 5. Raccomandazione

**AirVPN**, per tre motivi in ordine di peso:

1. **La porta statica elimina l'unico pezzo fragile**: con Proton serve un automatismo che rinnovi la porta ogni 60 s e aggiorni qBittorrent a ogni cambio; con AirVPN la porta si imposta una volta e basta. Su un server headless che deve funzionare da solo, meno ingranaggi = meno guasti.
2. **La prova da €2 azzera il rischio**: si monta gluetun, si collauda tutto lo stack (IP, kill switch, port forwarding, velocità) e solo a collaudo riuscito si paga l'anno.
3. A parità circa di prezzo, tutti i server vanno bene per il P2P: zero configurazione di selezione server in gluetun.

**ProtonVPN resta la scelta giusta se** vuoi anche una VPN "consumer" curata per telefono/PC fuori casa e accetti la complessità della porta dinamica.

### Percorso operativo (quando deciso)

1. Account Proton → piano **VPN Plus** (⚠️ protonvpn.com risulta bloccato da alcune reti aziendali: farlo da casa o dal telefono)
2. account.protonvpn.com → Downloads → **WireGuard configuration**: piattaforma GNU/Linux, **spunta NAT-PMP (Port Forwarding) attiva**, server **P2P** (es. Paesi Bassi) → copiare la `PrivateKey`
3. `gluetun` nel compose `~/docker/arr` (provider `protonvpn`, `VPN_PORT_FORWARDING=on`, `PORT_FORWARD_ONLY=on`, comando automatico che aggiorna la listening port di qBittorrent) + qBittorrent dietro di lui → **FASE4-DOWNLOAD.md §4** (host download client da `qbittorrent` a `gluetun` in Sonarr, Radarr, Lidarr e Prowlarr)
4. Verifiche §4.4-4.6 della guida: IP pubblico = IP VPN, kill switch, porta nel log di gluetun = listening port di qBittorrent (si riallinea da sola a ogni riconnessione)
5. Solo a quel punto: indexer veri in Prowlarr (⚖️ con buon senso su cosa scaricare; fase 2: anche Prowlarr dietro gluetun)

---

## 6. Decisione

- [ ] ~~AirVPN~~ (raccomandazione del confronto; scelta in un primo momento, poi cambiata in giornata)
- [x] **ProtonVPN Plus** ✅ — decisione finale di Luca
- [ ] ~~Altro / rimandata~~

Data decisione: **4 agosto 2026** — piano Plus (mensile $9,99, annuale ~$48, biennale ~$72; garanzia rimborso 30 giorni — la prova da €2 esiste solo su AirVPN). La porta dinamica è gestita in automatico da gluetun: `VPN_PORT_FORWARDING=on` + comando che riscrive la listening port di qBittorrent a ogni cambio (dettagli in FASE4-DOWNLOAD.md §4)

---

## Fonti

- [Flowster — VPN with Port Forwarding, 7 provider testati (2026)](https://flowster.app/vpn-with-port-forwarding-providers-2026/)
- [Cloudwards — AirVPN Review 2026 (prezzi e funzioni)](https://www.cloudwards.net/airvpn-review/)
- [Security.org — Proton VPN cost 2026](https://www.security.org/vpn/protonvpn/)
- [Cybernews — Proton VPN pricing 2026](https://cybernews.com/vpn/protonvpn-review/pricing/)
- Gluetun (docs provider e port forwarding): https://github.com/qdm12/gluetun-wiki
