# Halo

App macOS personale che trasforma la notch del MacBook in una "Dynamic Island": un'isola nera
che cresce dalla notch fisica e mostra cosa stai ascoltando da qualsiasi app (Spotify, Musica,
Safari/YouTube, …), sostituisce l'HUD di luminosità e volume, avvisa di ricarica, AirPods e
notifiche, tiene uno scaffale di file e porta musica e testi sul desktop e sulla schermata di
blocco.

Architettura e scelte in [`docs/design.md`](docs/design.md).

## Funzioni

| Funzione | Dove | Note |
| --- | --- | --- |
| **Now Playing** | isola `compact` (copertina + EQ) ed espansa (player completo) | qualsiasi app che pubblica Now Playing |
| **Testi sincronizzati** | pannello sotto il player, widget, schermata di blocco | da [LRCLIB](https://lrclib.net); tocca una riga per saltare lì |
| **HUD luminosità e volume** | ali dell'isola; in linea nell'intestazione se il player è aperto | barra trascinabile, passi fini con ⌥⇧ |
| **Ricarica e batteria** | ali dell'isola | collegato/scollegato, avvisi al 20/10/5 % |
| **AirPods e cuffie** | banner sotto la notch | batteria di auricolari e custodia, volume |
| **Notifiche** | banner sotto la notch | copia delle notifiche di sistema; clic = apre l'app |
| **Meteo** | intestazione dell'isola espansa, widget | [Open-Meteo](https://open-meteo.com) |
| **Scaffale file** | scheda dell'isola espansa | trascina file sulla notch; trascinali fuori per usarli |
| **Tutti i display** | un'isola per schermo | monitor esterni e Mac senza notch: pillola finta |
| **Widget sul desktop** | sopra lo sfondo, sotto le finestre | player in vetro, oppure orologio e meteo |
| **Schermata di blocco** | sopra il lock screen | player e testi mentre il Mac è bloccato |
| **Gesti** | sull'isola aperta | scorri ← → per cambiare brano, ↑ ↓ per il volume; clic sulla copertina apre l'app |
| **Calendario** | scheda dell'isola, intestazione, banner | prossimi impegni, riunione entro l'ora al posto del meteo, promemoria 5 min prima con "Partecipa" |
| **Anteprima screenshot** | banner sotto la notch | trascina la miniatura dove vuoi, copia, scaffale, cestino |
| **Timer e Pomodoro** | scheda dell'isola, ali (attività live), menu | countdown nelle ali, anello, ciclo 4 × 25 + 5 min |
| **Microfono e fotocamera** | ali dell'isola | pallino arancione/verde quando un'app li usa |
| **Lingua tastiera e Bloc Maiusc** | ali dell'isola | avviso breve al cambio |
| **Modalità presentazione** | — | con un'app a tutto schermo gli avvisi che interrompono restano zitti |
| **Risparmio energetico** | — | in modalità basso consumo meno animazioni e ridisegni |

Tutto si accende e spegne dalle **Impostazioni** (menu della capsula › Impostazioni…, ⌘,).
Il menu contiene lo stato di Now Playing, il sottomenu Timer, le Impostazioni, le scorciatoie per
i permessi mancanti ed Esci.

## Requisiti

- Mac Apple Silicon con macOS 26 o successivo (sviluppata per MacBook Air M2 con macOS 27).
- Per compilare: Xcode 26+ oppure i soli Command Line Tools (Swift 6.2+). Niente CMake,
  niente progetto Xcode: solo Swift Package Manager e `clang`.
  - Con i Command Line Tools e l'SDK di macOS 27 le macro di SwiftUI (`@State`, `@Entry`,
    `#Preview`, `@Previewable`) non si espandono: il plugin `SwiftUIMacros` c'è solo in Xcode.
    Il codice non le usa e la CI blocca chi le reintroduce.

## Compilare

```sh
git clone --recursive https://github.com/sonoFrangu/halo.git
cd halo
scripts/bundle.sh
```

`scripts/bundle.sh`:

1. `swift build -c release`;
2. compila `MediaRemoteAdapter.framework` dai sorgenti in `Vendor/mediaremote-adapter`
   (submodule; se manca, lo script lo scarica con `git submodule update --init`);
3. assembla `build/Halo.app` (`LSUIElement = true`, nessuna icona nel Dock) con l'adapter in
   `Contents/Resources/MediaRemoteAdapter/`;
4. firma tutto e verifica la firma: ad-hoc (`codesign -s -`) per default, oppure con il
   certificato locale "Halo Local" se esiste (vedi sotto).

### Firma stabile (consigliata)

macOS lega i permessi (Accessibilità, Accesso completo al disco) alla firma dell'app. Con la
firma ad-hoc la firma cambia a ogni build, quindi dopo ogni `scripts/bundle.sh` i permessi vanno
rimossi e concessi di nuovo. Per evitarlo, una volta sola:

1. Accesso Portachiavi › Assistente Certificato › Crea un certificato…
2. Nome **`Halo Local`**, Tipo di identità **Radice autofirmata**, Tipo di certificato
   **Firma codice** › Crea.

Da quel momento `scripts/bundle.sh` firma con `Halo Local` (lo stampa a video) e i permessi
sopravvivono alle ricompilazioni. `HALO_SIGN_IDENTITY="Altro nome" scripts/bundle.sh` forza
un'altra identità.

Test unitari (stream Now Playing, timeline, geometria e layout, forma, palette, HUD, avvisi,
batterie, LRC, meteo, notifiche, gesti, calendario, timer): `swift test` (richiede Xcode per
Swift Testing).

La CI (`.github/workflows/build.yml`) esegue test e bundle a ogni push con Xcode 26.0.1 e 26.6
(runner `macos-26`) e con Xcode 27 + Command Line Tools su SDK 27, e carica `Halo.zip` come
artifact.

## Lanciare

```sh
open build/Halo.app
```

Oppure copia `build/Halo.app` in `/Applications` (consigliato se attivi "Avvia al login": il
login item punta al percorso dell'app). Halo compare solo nella barra dei menu.

Se usi lo zip scaricato dalla CI, macOS lo mette in quarantena (firma ad-hoc, non
notarizzata). Sbloccalo una volta:

```sh
xattr -dr com.apple.quarantine /Applications/Halo.app
```

## Permessi richiesti

| Permesso | Serve per | Senza |
| --- | --- | --- |
| **Accessibilità** | HUD luminosità/volume (event tap sui tasti) e avviso Bloc Maiusc | i tasti usano l'HUD di sistema; niente avviso Bloc Maiusc |
| **Localizzazione** (quando in uso) | meteo del posto in cui sei | posizione approssimata dall'IP ([ipwho.is](https://ipwho.is)) |
| **Accesso completo al disco** | notifiche nella notch: leggere il database di Centro Notifiche | nessuna notifica nella notch (tutto il resto funziona) |
| **Calendario** (accesso completo) | prossimi impegni e promemoria delle riunioni | scheda Calendario con il pulsante per concederlo |

- Accessibilità: richiesta al primo avvio; poi dal menu o dalle Impostazioni.
- Calendario: richiesto al primo avvio; se negato, le Impostazioni mostrano "Concedi…".
- Accesso completo al disco: dal menu o dalle Impostazioni, "Concedi…" apre Impostazioni di Sistema ›
  Privacy e sicurezza › Accesso completo al disco; aggiungi `Halo.app` con **+**. Halo se ne
  accorge da solo quando torni a un'altra app (non serve riavviarlo).
- **Nessuna Registrazione schermo né Monitoraggio input.** Hover e trascinamento file usano
  monitor di eventi *mouse* (`NSEvent`), che non richiedono autorizzazioni. Microfono e
  fotocamera "in uso" si leggono da CoreAudio/CoreMediaIO senza permessi e senza accenderli;
  la modalità presentazione legge solo dimensioni e proprietari delle finestre.
- **Elementi di login**: attivando "Avvia al login" macOS può chiedere conferma in
  Impostazioni di Sistema › Generali › Elementi login; Halo apre quella pagina se serve.
- **Now Playing**: nessun prompt. Halo avvia `/usr/bin/perl` con
  [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter): perl è un binario di
  sistema ancora autorizzato a usare il framework privato MediaRemote (bloccato per le app di
  terzi da macOS 15.4).
- **Rete**: LRCLIB (testi), Open-Meteo (meteo), ipwho.is (solo se la posizione è negata). Nessun
  altro traffico, nessun account.

## Le funzioni nel dettaglio

### Isola e player
- Tre forme principali — `idle` (nascosta nella notch), `compact` (musica: mini copertina a
  sinistra, EQ a destra), `expanded` (hover: player completo) — più gli avvisi (`alert`), resi
  da **una sola forma animabile** nera che morfa con molle.
- Player: copertina con badge dell'app sorgente, titolo, controlli in Liquid Glass, barra di
  avanzamento trascinabile che si ispessisce all'hover, pulsante testi. Alone e sfumatura
  interna prendono i colori dominanti della copertina.

### Testi sincronizzati
- Cercati su LRCLIB a ogni cambio brano (con debounce e cache); se esistono solo testi non
  sincronizzati non vengono mostrati. Il pulsante con le virgolette apre/chiude il pannello.
- La riga cantata è centrata, grande, sfumata con i colori della copertina; il pannello si
  ridisegna **solo** quando cambia riga (nessun timer).

### HUD luminosità e volume
- Luminosità (F1/F2), volume (F11/F12) e muto (F10) mostrano l'HUD nelle ali: icona animata
  (sole che ruota; AirPods/AirPods Pro/Max/cuffie quando sono l'uscita), barra con bagliore e
  percentuale. Se il player è aperto l'HUD compare in linea nell'intestazione, senza chiuderlo.
- **Regolazione personalizzata**: la barra si trascina; Opzione+Maiusc con i tasti fa passi fini
  da 1/64 come in macOS.
- Luminosità tramite il framework privato DisplayServices (solo display integrato), volume
  tramite CoreAudio. Se una delle due non è regolabile, il tasto passa al sistema.

### Ricarica, AirPods, notifiche
- **Ricarica**: batteria disegnata a mano che si riempie a molla, fulmine in carica, percentuale
  con cifre che scorrono. Eventi da IOKit (nessun polling).
- **AirPods e cuffie**: quando diventano l'uscita audio compare un banner con anelli per
  auricolare sinistro/destro, custodia e volume. Le batterie arrivano da `system_profiler` circa
  un secondo dopo (le AirPods a volte le pubblicano in ritardo: Halo riprova una volta dopo 4 s).
- **Notifiche**: ogni notifica consegnata da macOS appare anche nella notch (icona, app, titolo,
  testo). Clic sul banner = apre l'app. Più di 3 notifiche insieme (es. al risveglio) mostrano
  solo l'ultima.
- Gli avvisi si mettono in coda; l'HUD ha la precedenza; un banner resta finché il puntatore ci
  è sopra o il player è aperto.

### Meteo
- Icona e temperatura nell'intestazione dell'isola espansa e nel widget. Si aggiorna quando apri
  l'isola se il dato ha più di 20 minuti (e all'avvio): niente timer. °F con il sistema
  metrico USA.

### Scaffale file
- Trascina uno o più file verso la notch: l'isola si apre sulla scheda Scaffale e diventa un
  bersaglio di rilascio. I file restano lì (anche dopo il riavvio) con anteprime Quick Look;
  trascinali fuori per copiarli/allegarli, clic per aprirli, tasto destro per Mostra nel Finder
  o Rimuovi, "Svuota" per toglierli tutti.
- Lo scaffale tiene **riferimenti**, non copie: se sposti o elimini l'originale, sparisce anche
  dallo scaffale. Massimo 24 file.

### Tutti i display
- Con "Su tutti i display" (predefinito) ogni schermo ha la sua isola: sul display con la notch
  si fonde con quella fisica, sugli altri è una pillola nera sotto la barra dei menu. Si
  adegua a collegamenti, scollegamenti e cambi di risoluzione.

### Widget sul desktop
- Spento per default (Impostazioni › Musica › Widget sul desktop). Una card in vetro con la copertina sfocata
  come sfondo, controlli, avanzamento e testi; quando non suona nulla mostra ora, data e meteo.
  Si trascina dove vuoi (la posizione viene ricordata) e sta sotto tutte le finestre.

### Schermata di blocco
- Quando blocchi il Mac con musica in riproduzione, la card del player (con i testi) compare
  sopra la schermata di blocco, sotto l'orologio. Sparisce allo sblocco.

### Gesti
- Sull'isola aperta (scheda Musica): scorri con due dita a sinistra per il brano successivo, a
  destra per il precedente (una volta per gesto); su/giù (o rotella) per il volume, anche sopra
  l'HUD del volume. Funziona con lo scorrimento "naturale" attivo o no; l'inerzia è ignorata.
- Clic sulla copertina: porta in primo piano l'app che sta suonando.
- Feedback aptico sul trackpad Force Touch (salto di brano, volume a 0/100 %, file rilasciato,
  cambio scheda). "Tocca l'isola chiusa per play/pausa" non è stato fatto: l'isola si apre al
  passaggio del puntatore prima che un clic possa arrivarle.

### Calendario
- Scheda con i prossimi 3 impegni (colore del calendario, orario, "tra 12 min", "In corso ·
  fino alle 11:15") e pulsante **Partecipa** per link Zoom, Meet, Teams, Webex, FaceTime
  trovati in URL, luogo o note.
- Nell'intestazione, al posto del meteo, la riunione in corso o entro l'ora.
- 5 minuti prima di ogni impegno un banner (12 s) con **Partecipa**; esclusi eventi di tutto il
  giorno, annullati o rifiutati. Nessun timer: Halo dorme fino al prossimo momento utile.

### Anteprima screenshot
- Ogni screenshot (o registrazione) salvato compare nella notch con la miniatura: trascinala in
  una chat o in un documento, clic per aprirla, oppure Copia / Scaffale / Cestino.
- macOS scrive il file solo quando sparisce la sua miniatura mobile (~5 s): per un'anteprima
  immediata disattivala in ⇧⌘5 › Opzioni › Mostra miniatura mobile.

### Timer e Pomodoro
- Scheda Timer: preset 1, 5, 10, 15, 25 minuti e Pomodoro (4 round da 25 minuti con pause da 5,
  poi 15). Mentre corre: anello, countdown grande, pausa / +1 min / ferma. Anche dal menu.
- Con un timer attivo l'isola compatta diventa la sua attività live: countdown nell'ala destra
  (aggiornato dal sistema, non da Halo) e anello nell'ala sinistra se non suona musica.
- Alla fine: suono "Glass", banner con cosa viene dopo; il Pomodoro passa da solo alla fase
  successiva ("Ferma" interrompe il ciclo). Durata massima 59:59.

### Microfono, fotocamera, tastiera
- Quando un'app usa il microfono (arancione) o una fotocamera (verde) l'isola mostra un
  pallino; senza musica né timer anche l'icona del dispositivo.
- Cambio della lingua della tastiera: globo, sigla della lingua e nome del layout. Bloc Maiusc:
  "Maiusc attivo/spento" (serve Accessibilità).

### Concentrazione ed energia
- **Modalità presentazione**: se l'app in primo piano è a tutto schermo (Keynote, un video,
  una chiamata), notifiche, cuffie, alimentatore e screenshot non compaiono; HUD, tastiera,
  timer, riunioni e batteria scarica sì.
- **Risparmio energetico**: con la modalità di basso consumo attiva l'EQ si ferma, le
  transizioni diventano brevi dissolvenze, la barra di avanzamento si ridisegna 4 volte al
  secondo e i titoli non scorrono.
- **Titoli lunghi** nel player aperto scorrono in loop con i bordi sfumati (solo mentre il
  player è visibile).

## Risoluzione problemi

- **`Undefined symbols … PackageDescription.Package.__allocating_init(… SwiftVersion …)`**
  (o `reference to member 'v26' cannot be resolved`) anche su un progetto vuoto creato con
  `swift package init`: i Command Line Tools sono incoerenti (resti di una versione precedente).
  Reinstallali: `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.
- **`plugin for module 'SwiftUIMacros' not found`**: codice con macro SwiftUI compilato con i
  soli Command Line Tools sull'SDK di macOS 27 (vedi Requisiti). Usa Xcode o evita la macro.
- **Nessuna notifica nella notch**: controlla che nel menu non compaia "Concedi Accesso completo
  al disco…"; se hai ricompilato con firma ad-hoc, rimuovi Halo dall'elenco e aggiungilo di
  nuovo (vedi *Firma stabile*).
- **Meteo assente**: senza rete o con entrambi i servizi irraggiungibili il badge resta vuoto;
  riprova aprendo l'isola dopo qualche minuto.
- Le prime righe di `scripts/bundle.sh` stampano toolchain, versione di Swift e SDK in uso.
- Log: `log stream --predicate 'subsystem == "io.github.sonofrangu.halo"'`.

## Limiti noti

- **API private e workaround.** Now Playing (MediaRemote via perl), luminosità
  (DisplayServices), schermata di blocco (SkyLight) e notifiche (database di Centro Notifiche)
  non hanno API pubbliche. Ognuna viene caricata o letta a runtime e, se un aggiornamento di
  macOS la rompe, **solo quella funzione** si spegne (con un messaggio nel log o nel menu); il
  resto continua a funzionare.
- **Schermata di blocco**: funziona sul blocco di una sessione già aperta. La finestra di login
  dopo un riavvio (prima di aver mai fatto l'accesso, con FileVault) esiste prima di qualsiasi
  app utente: lì nessuna app di terzi può mostrare nulla.
- **Notifiche**: sono una *copia*: il banner di sistema compare comunque (spegnilo per singola
  app in Impostazioni › Notifiche se vuoi solo quello di Halo). Halo non sa se è attiva una
  Full Immersion (non c'è un'API pubblica per le altre app), quindi mostra anche le notifiche
  che la Full Immersion silenzierebbe: in quel caso disattiva "Notifiche nella notch".
  Il formato del database è privato: se cambia, il banner mostra solo il nome dell'app.
- **AirPods**: batterie lette da `system_profiler` (circa un secondo, una volta per
  connessione); se il dispositivo non le pubblica si vede solo il volume. Nessun avviso quando
  cambiano *durante* l'uso (servirebbe interrogare periodicamente il Bluetooth).
- **Now Playing**: se l'adapter termina con errore Halo non lo rilancia (come raccomandato
  dall'adapter): serve riavviare Halo.
- **L'EQ non legge l'audio.** È un'animazione sintetica che parte solo in riproduzione; livelli
  reali richiederebbero permessi di cattura audio.
- **Artwork**: alcune app (spesso i browser) non forniscono la copertina o la forniscono in
  ritardo; al suo posto c'è un segnaposto con i colori neutri.
- **Titoli lunghi**: scorrono nel player dell'isola; nelle card (desktop, blocco) sono troncati.
- **Microfono/fotocamera**: Halo sa *che* un dispositivo è in uso, non *quale app* lo usa.
- **Modalità presentazione**: riconosce le app a tutto schermo (finestra grande quanto lo
  schermo), non la condivisione dello schermo né le Full Immersion.
- **Contenuti live** (senza durata) mostrano la barra vuota e `--:--`; il seek è disattivato.
- **Le ali coprono la menu bar**: in `compact` le ali nere stanno sopra gli elementi della menu
  bar adiacenti alla notch. I click li raggiungono comunque (il pannello è click-through), ma
  passarci sopra con il puntatore apre il player dopo ~90 ms.
- **HUD**: niente suono di feedback del volume (il tasto non arriva al sistema); luminosità solo
  del display integrato; niente tasti retroilluminazione tastiera (l'Air M2 non li ha).
- **Testi**: dipendono da LRCLIB (database comunitario): per brani rari o molto recenti possono
  mancare o essere sfasati.
- **Solo arm64**: `scripts/build-adapter.sh` compila l'adapter per l'architettura della
  macchina che builda.
- **Build verificata solo in CI.** Lo sviluppo è avvenuto senza un Mac: tutto ciò che è visivo o
  legato all'hardware (forme, animazioni, vetro, hover, drag and drop, AirPods, schermata di
  blocco, notifiche reali) va verificato a mano — l'elenco è nella descrizione della PR.

## Struttura

```
Sources/Halo/
  App/            entry point, AppDelegate, preferenze, log
  MenuBar/        NSStatusItem e voci del menu, SMAppService
  NowPlaying/     modello, controller, timeline; Adapter/ processi perl, parsing dello stream
  Artwork/        palette (Core Image + k-means)
  Island/         geometria notch, layout, stati, hover, schermi; Panel/ NSPanel + hosting
  Alerts/         coda degli avvisi (HUD, ricarica, cuffie, notifiche)
  HUD/            luminosità e volume
  System/         DisplayServices, CoreAudio, event tap, Accessibilità, SkyLight
  Power/          batteria (IOKit)
  AudioDevices/   uscita audio e batterie delle cuffie
  Lyrics/         LRC, LRCLIB
  Weather/        Open-Meteo, posizione
  Shelf/          scaffale file, rilevamento del trascinamento, anteprime
  Notifications/  lettura del database di Centro Notifiche
  Widgets/        pannelli del widget sul desktop e della schermata di blocco
  Gestures/       interprete dello scroll, feedback aptico
  Calendar/       EventKit, link delle riunioni, orari
  Screenshots/    query Spotlight delle catture
  Timer/          timer e Pomodoro
  Settings/       finestra Impostazioni
  UI/             forma e viste SwiftUI (Alerts/, Calendar/, HUD/, Settings/, Shelf/, Timer/, Widgets/)
Tests/HaloTests   Swift Testing
scripts/          bundle.sh, build-adapter.sh
Vendor/           mediaremote-adapter (submodule)
```

## Licenze di terze parti

[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) © 2025 Jonas van den
Berg e contributori, licenza BSD 3-Clause. Il testo della licenza è incluso in
`Halo.app/Contents/Resources/MediaRemoteAdapter/LICENSE` e nel submodule.

Servizi usati a runtime: [LRCLIB](https://lrclib.net) (testi), [Open-Meteo](https://open-meteo.com)
(meteo, dati CC BY 4.0), [ipwho.is](https://ipwho.is) (posizione approssimata).
