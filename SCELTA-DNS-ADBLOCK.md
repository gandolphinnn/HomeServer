# Fase 6 — DNS locale con adblock: valutazione

*Creato: 4 agosto 2026 — STATO: valutazione fatta, rollout rimandato a dopo il trasloco (vedi §2)*

Risponde a: **Pi-hole o AdGuard Home (o altro)?** — e alla domanda che viene prima: *su cosa lo facciamo girare, visto che il NUC non è acceso h24?*

---

## 1. Cosa fa (e cosa NON fa) un DNS adblock di rete

Un DNS filtrante risponde "indirizzo inesistente" alle richieste verso domini di pubblicità/tracker/malware. Vale per **tutta la casa**: TV, telefoni, ospiti, app — senza installare nulla sui dispositivi. È il suo vero valore rispetto a uBlock nel browser (che resta consigliato in parallelo).

Aspettative oneste — **non blocca**:
- Le pubblicità di **YouTube e Twitch** (arrivano dagli stessi domini dei contenuti: bloccarle = bloccare il video)
- Le sponsorizzazioni dentro le pagine/feed (Instagram, sponsored post…)
- Parte delle ads in-app che usano i CDN dei contenuti

**Blocca bene**: banner dei circuiti pubblicitari, tracker, telemetria (smart TV incluse — parlano parecchio), domini malware/phishing, ads nei giochini del telefono.

---

## 2. Il vero nodo: serve una macchina sempre accesa (prima del software)

Se il DNS di tutta la rete vive su una macchina spenta, **per la casa "internet è rotto"** (i siti non si risolvono più). Questo è il vincolo n.1 annotato in RECAP, e resta il motivo per rimandare il rollout.

### Il costo nascosto del "NUC h24"

Attenzione: con la politica attuale (**"il NAS segue il NUC"**, watchdog `nas-autowake` ogni 2 min), tenere il NUC sempre acceso significa **NAS sempre acceso** — il watchdog lo risveglierebbe in automatico. Quindi:

| Scenario | Potenza | kWh/anno | €/anno (~0,30 €/kWh) |
|----------|---------|----------|----------------------|
| NUC h24 da solo (richiede revisione watchdog) | ~12 W | ~105 | **~€32** |
| NUC h24 + NAS h24 (policy attuale invariata) | ~47 W | ~412 | **~€124** |
| Mini-dispositivo dedicato (es. Pi Zero 2W usato) | ~2 W | ~18 | ~€5 + acquisto (€25-35) |
| Cloud (NextDNS free) | — | — | €0 |

*(Valori indicativi; il delta reale dipende da quante ore al giorno le macchine sono già accese.)*

Il "NUC h24 da solo" è fattibile ma richiede di **rivedere il watchdog** (es. finestra oraria, o NAS solo on-demand) — lavoro fattibile ma non banale, da progettare. Da decidere **dopo il trasloco**, insieme al resto della politica energia.

### Il fallback "DNS secondario pubblico": paracadute sì, soluzione no

Tentazione classica: DHCP che distribuisce `NUC` come DNS primario e `1.1.1.1` come secondario, "così se il NUC è spento funziona tutto lo stesso". Vero per la **disponibilità**, ma i client **non rispettano l'ordine** primario/secondario: molti (Windows in testa) interrogano quello che risponde prima o si incollano al secondario → una fetta di traffico **bypassa il filtro anche a NUC acceso**. Accettabile come paracadute consapevole, non come progetto.

### ✅ Vincolo DHCP iliadbox: RISOLTO (verificato 4/8/2026)

La iliadbox **permette** di impostare i DNS distribuiti via DHCP: pannello → parametri iliadbox → **modalità avanzata → DHCP → scheda Server DHCP** (campi Server DNS 1/2). ⚠️ **Attenzione all'IPv6**: iliad usa anche IPv6, e i dispositivi ricevono DNS IPv6 per altra via — vanno forzati anche quelli (sezione **Configurazione IPv6 → DNS IPv6**), altrimenti metà del traffico DNS bypassa il filtro via IPv6. Fonte: [GuruHiTech — cambiare i DNS su iliadbox](https://guruhitech.com/iliad-come-cambiare-i-dns-sul-modem-iliadbox-os/). Non serve quindi spostare il DHCP sul NUC; al cambio router (trasloco) ricontrollare l'equivalente.

---

## 3. Il software: AdGuard Home vs Pi-hole

Entrambi maturi, open source, perfetti in Docker, leggerissimi (irrilevanti sui 3,8 GiB liberi del NUC). Le differenze che contano **per noi**:

| Criterio | AdGuard Home | Pi-hole v6 |
|----------|--------------|------------|
| DNS cifrato verso l'esterno (DoH/DoT/DoQ) | ✅ nativo, si incolla l'URL in UI | ❌ serve un container extra (unbound o cloudflared) |
| Regole per singolo dispositivo (TV sì, PC no…) | ✅ per-client in UI | 🟡 gruppi, più macchinoso |
| Parental control / SafeSearch | ✅ integrati | ❌ a colpi di blocklist/regex |
| Rewrite wildcard (`*.private.gandogames.org` → NUC, per la Fase 5) | ✅ campo in UI | 🟡 righe dnsmasq custom a mano |
| Fare da *server* DoT/DoH (Android "DNS privato" nativo) | ✅ con certificato (sinergia Fase 5) | ❌ |
| UI | Moderna, pulita | Funzionale, datata |
| Community, tutorial, diagnostica query | 🟡 buona | ✅ enorme, 10+ anni (ma la v6 del 2025 ha reso stantii molti tutorial in rete) |
| Governance | Open source (GPLv3) ma dietro c'è l'azienda AdGuard | Progetto community puro |
| DHCP integrato (se mai servisse) | ✅ | ✅ |
| Integrazione Homarr (widget "DNS Hole") | ✅ | ✅ |

Il consenso 2026 per le installazioni nuove va nella stessa direzione: [AdGuard Home per la maggior parte degli usi domestici, Pi-hole se pesi soprattutto community e diagnostica profonda](https://readthemanual.co.uk/pihole-vs-adguard-home/) ([confronto HomelabCompass](https://homelabcompass.com/compare/pihole-vs-adguard-home), [Mindset & Megabytes](https://mindsetandmegabytes.com/adguard-home-vs-pihole/)).

### Gli altri candidati ("o altri"), e perché no

| Software | Verdetto per noi |
|----------|------------------|
| **Blocky** | Bello per chi vuole config-as-code (YAML, niente UI) — ma senza UI la gestione famiglia (sbloccare un sito al volo dal telefono) diventa un edit+restart. No. |
| **Technitium DNS** | Il più potente (ricorsivo, DHCP, DNSSEC, app), ma UI densa e curva ripida. Overkill per l'esigenza. |
| **Unbound** | Non è un adblocker: è un resolver ricorsivo. Ruolo **complementare**: un domani AGH→unbound per non dipendere da nessun DNS pubblico (percorso "purista"). All'inizio basta AGH→DoH (Quad9/Mullvad/dns0.eu). |
| **Cloud: NextDNS / AdGuard DNS pubblico / Mullvad DNS** | Niente da installare, funziona anche a NUC spento e fuori casa. Contro: i DNS di casa li vede un terzo, niente nomi locali. **NextDNS** free = 300k query/mese poi passa a non filtrare. Ottimo **interim** o piano B, non il punto d'arrivo. |
| **pfSense/OPNsense + pfBlockerNG** | Richiede hardware router dedicato — fuori scala. Semmai discorso da riaprire al cambio router post-trasloco. |

---

## 4. Sinergie con il resto del progetto

- **Tailscale**: impostando l'AGH del NUC come nameserver del tailnet, telefono e portatile avrebbero adblock e nomi locali **anche fuori casa**. ⚠️ Sensato solo se il NUC diventa h24 (NUC spento = DNS rotto anche in mobilità). In alternativa: split DNS di Tailscale solo per il futuro dominio (Fase 5), zero impatto sul resto.
- **Fase 5 (dominio)**: AGH risolve `*.private.gandogames.org` verso il NUC in LAN (rewrite wildcard in UI) — è il pezzo "split DNS casa/fuori" già previsto in RECAP. Col certificato del dominio, AGH può anche fare da server DoT per il "DNS privato" nativo di Android.
- **Stack VPN/gluetun**: nessun conflitto — qBittorrent dentro gluetun usa il DNS del tunnel (è giusto così: le sue query non devono passare dal DNS di casa).
- **Homarr**: widget "DNS Hole" dedicato, statistiche in dashboard.
- **Energia**: vedi §2 — la decisione DNS è di fatto un capitolo della politica energia, non un capitolo software.

---

## 5. Raccomandazione

**AdGuard Home, con preferenza 75/25 su Pi-hole.**

Motivazione in ordine di peso:
1. **Meno pezzi da mantenere**: DNS cifrato in uscita nativo = un container invece di due (Pi-hole vorrebbe unbound/cloudflared a fianco). Su questo server la semplicità operativa ha sempre vinto.
2. **Per-client e parental in UI**: con più utenti in casa (e le smart TV), le regole per dispositivo sono quelle che si usano davvero.
3. **Fase 5 pronta**: rewrite wildcard in due click e opzione server DoT — il percorso dominio+split DNS è tutto in discesa.
4. Il vantaggio storico di Pi-hole (community e tutorial sterminati) per noi pesa poco: la diagnostica via SSH/API la fa Claude, e la v6 ha comunque invecchiato mezza documentazione in giro.

Il 25% di Pi-hole diventa maggioranza solo se un domani contassero più di tutto la governance 100% community e la diagnostica query minuziosa.

### Percorso a fasi

1. **Adesso: niente rollout LAN** (decisione già presa: trasloco in arrivo). Se vuoi assaggiare il blocking da subito: NextDNS free o AdGuard DNS pubblico impostati a mano su PC/telefono — zero infrastruttura, reversibile in un minuto.
2. **Pilota facoltativo a costo zero**: AGH in container sul NUC usato SOLO dal PC (DNS manuale) — la casa non dipende dal NUC, tu vedi statistiche e blocking dal vivo.
3. **Post-trasloco, la decisione vera** (in quest'ordine): politica energia (NUC h24? con quale revisione del watchdog?) → poi rollout: AGH in Docker, DNS distribuiti dal router (**IPv4 E IPv6**), eventuale secondario pubblico come paracadute consapevole, tile+widget in Homarr, e in prospettiva nameserver del tailnet.

---

## 6. Decisione

- [ ] AdGuard Home (consigliato) — quando: ______
- [ ] Pi-hole
- [ ] Cloud interim (NextDNS/AdGuard DNS) nel frattempo
- [ ] Altro / rimandata

---

## Fonti

- [Read The Manual — Pi-hole vs AdGuard Home (2026)](https://readthemanual.co.uk/pihole-vs-adguard-home/)
- [HomelabCompass — Pi-hole vs AdGuard Home (2026)](https://homelabcompass.com/compare/pihole-vs-adguard-home)
- [Mindset & Megabytes — AdGuard Home vs Pi-hole in 2026](https://mindsetandmegabytes.com/adguard-home-vs-pihole/)
- [GuruHiTech — Come cambiare i DNS sulla iliadbox (DHCP + IPv6)](https://guruhitech.com/iliad-come-cambiare-i-dns-sul-modem-iliadbox-os/)
- Progetti: [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) · [Pi-hole](https://github.com/pi-hole/pi-hole) · [Blocky](https://github.com/0xERR0R/blocky) · [Technitium](https://technitium.com/dns/)
