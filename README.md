# Halo

App macOS personale che trasforma la notch del MacBook in una "Dynamic Island": un'isola nera
che cresce dalla notch fisica e mostra cosa stai ascoltando da qualsiasi app (Spotify, Musica,
Safari/YouTube, …), sostituisce l'HUD di luminosità e volume, avvisa di ricarica, AirPods,
notifiche e Full Immersione, tiene timer, cronometro e download come attività live, uno
scaffale di file, e porta musica e testi sul desktop e sulla schermata di blocco.

Architettura e scelte in [`docs/design.md`](docs/design.md).

## Funzioni

| Funzione | Dove | Note |
| --- | --- | --- |
| **Now Playing** | isola `compact` (copertina + EQ) ed espansa (player completo) | qualsiasi app che pubblica Now Playing |
| **Testi sincronizzati** | pannello sotto il player, widget, schermata di blocco | da [LRCLIB](https://lrclib.net); scorri con due dita per sfogliarli, tocca una riga per saltare lì |
| **HUD luminosità e volume** | ali dell'isola; in linea nell'intestazione se il player è aperto | barra trascinabile, passi fini con ⌥⇧ |
| **Ricarica e batteria** | ali dell'isola | collegato/scollegato, avvisi al 20/10/5 % |
| **AirPods e cuffie** | banner sotto la notch | batteria di auricolari e custodia, volume |
| **Notifiche** | banner sotto la notch | stile Dynamic Island con miniatura delle foto; clic = apre l'app; niente notifiche dei siti; per ogni app: mostra, solo nome, nascondi, passa la Full Immersione |
| **Meteo** | intestazione dell'isola espansa, widget | [Open-Meteo](https://open-meteo.com) |
| **Scaffale file** | scheda dell'isola espansa | trascina file sulla notch; trascinali fuori per usarli |
| **Appunti** | scheda dell'isola espansa | ultimi 20 testi e immagini copiati; clic per ricopiarli, trascinali fuori; solo in memoria, senza password |
| **Uscita audio** | pulsante AirPlay nel player | scegli altoparlanti, cuffie o monitor senza aprire Impostazioni |
| **Tutti i display** | un'isola per schermo | monitor esterni e Mac senza notch: pillola finta |
| **Widget sul desktop** | sopra lo sfondo, sotto le finestre | widget medio in vetro come quelli di macOS 26, oppure orologio e meteo |
| **Schermata di blocco** | sopra il lock screen | player e testi mentre il Mac è bloccato; sparisce subito allo sblocco |
| **Gesti** | sull'isola aperta | scorri ← → per cambiare brano, ↑ ↓ per il volume (sopra i testi li sfoglia); clic sulla copertina apre l'app |
| **Calendario** | scheda dell'isola, intestazione, banner | prossimi impegni, riunione entro l'ora al posto del meteo, promemoria 5 min prima con "Partecipa" |
| **Anteprima screenshot** | banner sotto la notch | trascina la miniatura dove vuoi, copia, scaffale, cestino |
| **Timer e Pomodoro** | scheda dell'isola, ali (attività live), menu | countdown nelle ali, anello, ciclo 4 × 25 + 5 min |
| **Cronometro** | scheda Timer, ali (attività live), menu | quadrante con lancetta; con un timer attivo, due righe |
| **Download e AirDrop** | ali (attività live), banner alla fine | anello e percentuale; poi Mostra nel Finder / Scaffale |
| **Full Immersione** | ali dell'isola | simbolo, colore e nome quando la attivi o la disattivi; notifiche zitte mentre è attiva |
| **Sblocco** | ali dell'isola | il lucchetto che si apre quando sblocchi il Mac |
| **Microfono e fotocamera** | ali dell'isola | pallino arancione/verde quando un'app li usa |
| **Lingua tastiera e Bloc Maiusc** | ali dell'isola | avviso breve al cambio |
| **Modalità presentazione** | — | con un'app a tutto schermo gli avvisi che interrompono restano zitti |
| **Risparmio energetico** | — | in modalità basso consumo meno animazioni e ridisegni |

Tutto si accende e spegne dalle **Impostazioni** (menu della capsula › Impostazioni…, ⌘,),
organizzate come Impostazioni di Sistema: una pagina per argomento (Generale, Isola, Musica,
Attività, Avvisi, Scaffale e screenshot, Permessi, Informazioni), ogni opzione con la
spiegazione di cosa fa e dove si vede; un'opzione accesa a cui manca un permesso lo segnala con
il pulsante per concederlo. Il menu contiene lo stato di Now Playing, il sottomenu Timer e
cronometro, le Impostazioni, una voce per i permessi mancanti (solo se ce ne sono) ed Esci.

## Requisiti

- Mac con macOS 26 o successivo (sviluppata per MacBook Air M2 con macOS 27). L'app è Universal
  (arm64 + x86_64), ma sui Mac Intel non è mai stata provata.
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
   `Contents/Resources/MediaRemoteAdapter/` e l'icona `AppIcon.icns`, generata con `sips` e
   `iconutil` da `Support/AppIcon.png` (disegnata da `scripts/icon/render-icon.py`; il PNG è già
   nel repository, quindi per compilare non servono né Python né altri pacchetti);
4. firma tutto e verifica la firma: ad-hoc (`codesign -s -`) per default, oppure con il
   certificato locale "Halo Local" se esiste, altrimenti con un certificato "Apple Development"
   se il portachiavi ne ha uno (vedi sotto).

### Firma stabile (consigliata)

macOS lega i permessi (Accessibilità, Accesso completo al disco) alla firma dell'app. Con la
firma ad-hoc la firma cambia a ogni build, quindi dopo ogni `scripts/bundle.sh` i permessi vanno
rimossi e concessi di nuovo. Se hai un certificato "Apple Development" (gratis con qualsiasi
Apple ID, da Xcode › Settings › Accounts) lo script lo usa da solo. Altrimenti, una volta sola:

1. Accesso Portachiavi › Assistente Certificato › Crea un certificato…
2. Nome **`Halo Local`**, Tipo di identità **Radice autofirmata**, Tipo di certificato
   **Firma codice** › Crea.

Da quel momento `scripts/bundle.sh` firma con `Halo Local` (lo stampa a video) e i permessi
sopravvivono alle ricompilazioni. `HALO_SIGN_IDENTITY="Altro nome" scripts/bundle.sh` forza
un'altra identità.

Test unitari (stream Now Playing, timeline, geometria e layout, forma, palette, HUD, avvisi,
batterie, LRC e sincronia dei testi, meteo, notifiche, gesti, calendario, timer, cronometro,
Full Immersione, download): `scripts/test.sh` (`swift test` più il percorso del plugin di Swift Testing, che con i soli
Command Line Tools il compilatore non trova da solo).

La CI (`.github/workflows/build.yml`) esegue test e bundle a ogni push con Xcode 26.0.1 e 26.6
(runner `macos-26`) e con Xcode 27 + Command Line Tools su SDK 27, e carica `Halo.zip` come
artifact.

`scripts/dmg.sh` impacchetta `build/Halo.app` in `build/Halo-<versione>.dmg`, con un link ad
Applicazioni accanto all'app: è il file delle release. La finestra la imposta Finder via
AppleScript (la prima volta macOS chiede il permesso di Automazione); lo sfondo,
`Support/DMGBackground.png`, si rigenera con `scripts/dmg/render-background.py`.

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
| **Accesso completo al disco** | notifiche e Full Immersione nella notch: leggere il database di Centro Notifiche e quello di Non disturbare | niente notifiche né cambi di Full Immersione nella notch (tutto il resto funziona) |
| **Calendario** (accesso completo) | prossimi impegni e promemoria delle riunioni | scheda Calendario con il pulsante per concederlo |
| **Automazione** (Spotify, Musica) | play, pausa, brani e posizione mandati direttamente a Spotify e Musica (chiesta al primo clic sul player) | Halo usa MediaRemote, che con Spotify funziona a intermittenza |

La pagina **Impostazioni › Permessi** li elenca tutti con lo stato (Concesso / Necessario / Verrà
chiesto al primo uso), a cosa servono e il pulsante che apre la pagina giusta di Impostazioni di
Sistema; lo stato si aggiorna da solo quando torni su Halo.

- Accessibilità: richiesta al primo avvio; poi da Impostazioni › Permessi o dal menu.
- Calendario: richiesto al primo avvio; se negato, "Concedi…" apre la pagina Calendari.
- Accesso completo al disco: "Concedi…" apre Impostazioni di Sistema › Privacy e sicurezza ›
  Accesso completo al disco; aggiungi `Halo.app` con **+**. Halo se ne accorge da solo quando
  torni a un'altra app (non serve riavviarlo).
- **Download e AirDrop**: Halo non legge i file; si iscrive all'avanzamento che browser e
  AirDrop pubblicano per i file nella cartella Download. Se macOS chiede l'accesso alla cartella
  Download è per questo (negandolo si perde solo questa funzione).
- **Nessuna Registrazione schermo né Monitoraggio input.** Hover e trascinamento file usano
  monitor di eventi *mouse* (`NSEvent`), che non richiedono autorizzazioni. Microfono e
  fotocamera "in uso" si leggono da CoreAudio/CoreMediaIO senza permessi e senza accenderli;
  la modalità presentazione legge solo dimensioni e proprietari delle finestre.
- **Elementi di login**: attivando "Avvia al login" macOS può chiedere conferma in
  Impostazioni di Sistema › Generali › Elementi login; Halo apre quella pagina se serve.
- **Now Playing**: nessun prompt. Halo avvia `/usr/bin/perl` con
  [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter): perl è un binario di
  sistema ancora autorizzato a usare il framework privato MediaRemote (bloccato per le app di
  terzi da macOS 15.4). I *comandi* seguono la via più affidabile per l'app che suona:
  AppleScript per Spotify e Musica (permesso Automazione), poi MediaRemote chiamato da Halo,
  l'adapter e infine il tasto multimediale (con Accessibilità). Ogni play/pausa viene
  verificato sullo stream: se non ha effetto entro un secondo circa si passa alla via successiva.
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
- **Play/pausa**: il pulsante cambia subito e Halo porta il player in quello stato: con Spotify
  e Musica via AppleScript (*play*/*pausa* espliciti, istantanei), altrimenti via MediaRemote;
  se lo stream non conferma il cambio passa alla via successiva, e se nessuna funziona entro
  6 s il pulsante torna a mostrare lo stato reale (mai una pausa finta). Due clic ravvicinati si
  fondono in un'unica richiesta. Lo stato "in pausa" si legge dalla velocità di riproduzione:
  Spotify in pausa continua a dichiararsi "in riproduzione" e prima il tempo scorreva fino a
  0:00. Il vetro dei pulsanti è disegnato dallo stile del pulsante, così nessun clic va perso.

### Testi sincronizzati
- Cercati su LRCLIB a ogni cambio brano (con debounce e cache); se esistono solo testi non
  sincronizzati non vengono mostrati. Il pulsante con le virgolette apre/chiude il pannello.
- La riga cantata è centrata, grande, sfumata con i colori della copertina; il pannello si
  ridisegna **solo** quando cambia riga (nessun timer).
- Ogni riga compare un attimo prima del suo tempo (0,25 s, regolabile in Impostazioni › Musica ›
  Sincronia del testo, da 1 s dopo a 1,5 s prima): con cuffie Bluetooth o testi di LRCLIB un po'
  sfasati basta spostare il cursore.

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
- **Notifiche**: ogni notifica delle app consegnata da macOS appare anche nella notch, in stile
  Dynamic Island: icona, mittente (con il gruppo accanto), testo su 2 righe e la miniatura se è
  una foto. Clic sul banner = apre l'app. Più di 3 notifiche insieme (es. al risveglio) mostrano
  solo l'ultima. Le notifiche dei siti web non compaiono mai.
- **Notifiche per app** (Impostazioni › Avvisi): ogni app installata che può mandare notifiche
  ha un menu *Mostra* / *Solo app* (icona e nome, senza testo né foto) / *Non mostrare*; con
  "Silenzia durante una Full Immersione" acceso, la luna accanto fa passare quell'app anche
  durante una Full Immersione. Le app nuove partono da *Mostra*.
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
- Spento per default (Impostazioni › Musica › Widget sulla scrivania). Un widget medio in vetro
  come quelli di macOS 26: copertina, app, titolo, artista e album, avanzamento e controlli;
  quando non suona nulla mostra ora, data e meteo.
  Si trascina dove vuoi (la posizione viene ricordata) e sta sotto tutte le finestre.

### Schermata di blocco
- Quando blocchi il Mac con musica in riproduzione, il widget del player con sotto i testi
  compare sopra la schermata di blocco, sotto l'orologio. Sparisce subito allo sblocco, anche se
  Halo fosse momentaneamente bloccato.

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

### Cronometro
- Nella scheda Timer (pulsante "Cronometro") o dal menu. Nell'isola aperta un quadrante con la
  lancetta dei secondi e il tempo grande, pausa/riprendi e azzera; nelle ali il tempo che sale
  (contato dal sistema, come il countdown). Con timer e cronometro insieme la scheda mostra due
  righe e le ali danno la precedenza al timer.

### Download e AirDrop
- Mentre un file arriva nella cartella Download (Safari, Chrome e gli altri browser che
  pubblicano l'avanzamento, oppure AirDrop) le ali mostrano un anello con la freccia e la
  percentuale; con la musica l'anello va nell'ala destra al posto dell'equalizzatore.
- Alla fine un banner con l'anteprima del file (trascinabile), "Download completato" o
  "Ricevuto con AirDrop": clic per aprirlo, oppure Mostra nel Finder / Tieni sullo scaffale.
- Gli aggiornamenti vengono sfoltiti al punto percentuale prima di arrivare all'interfaccia;
  senza trasferimenti in corso non gira nulla.

### Full Immersione e sblocco
- Attivando o disattivando una Full Immersione (Centro di Controllo, barra dei menu,
  Comandi rapidi) le ali mostrano il suo simbolo nel suo colore e il nome ("Lavoro · Attiva").
  Mentre è attiva le notifiche non compaiono nella notch (disattivabile).
- Quando sblocchi il Mac il lucchetto nell'isola si apre, come su iPhone.

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

## Consumi

Misurati con `top` (campioni ogni 3 s per 30 s) su MacBook Air M2 con macOS 27, build Universal
di release, isola chiusa:

| Situazione | CPU Halo | CPU adapter (perl) | Memoria Halo |
| --- | --- | --- | --- |
| Niente in riproduzione | 0,05 % (picco 0,3 %) | 0 % | 53 MB |
| Spotify in riproduzione | 0,04 % (picco 0,2 %) | 0 % | 53 MB |
| Diretta Twitch in Safari | 0,01 % | 0,01 % | 37 MB |

Il disegno delle animazioni (EQ, forma dell'isola) lo fa WindowServer e non è contato qui.

## Risoluzione problemi

- **`Undefined symbols … PackageDescription.Package.__allocating_init(… SwiftVersion …)`**
  (o `reference to member 'v26' cannot be resolved`) anche su un progetto vuoto creato con
  `swift package init`: i Command Line Tools sono incoerenti (resti di una versione precedente).
  Reinstallali: `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.
- **`plugin for module 'SwiftUIMacros' not found`**: codice con macro SwiftUI compilato con i
  soli Command Line Tools sull'SDK di macOS 27 (vedi Requisiti). Usa Xcode o evita la macro.
- **Nessuna notifica nella notch**: guarda Impostazioni › Permessi (o la voce "Concedi…" nel
  menu); se hai ricompilato con firma ad-hoc, rimuovi Halo dall'elenco e aggiungilo di nuovo
  (vedi *Firma stabile*). Con una Full Immersione attiva le notifiche restano zitte per scelta.
- **Testo in anticipo o in ritardo sulla voce**: Impostazioni › Musica › Sincronia del testo.
- **Play/pausa che non rispondono**: con Spotify e Musica controlla Impostazioni › Permessi ›
  Automazione (se l'hai negata: Impostazioni di Sistema › Privacy e sicurezza › Automazione ›
  Halo). Prova anche la voce *Play/Pausa* nel menu di Halo: se quella funziona e il pulsante
  nella notch no, il problema è il clic, non il comando.
- **Diagnostica**: menu di Halo › *Copia diagnostica* (o Impostazioni › Informazioni) copia un
  resoconto degli ultimi eventi: build in esecuzione, clic, comandi inviati con la via usata,
  cosa riporta il player (`playing=… rate=…`) ed esito. Da Terminale:
  `log stream --level info --predicate 'subsystem == "io.github.sonofrangu.halo"'`.
- **Meteo assente**: senza rete o con entrambi i servizi irraggiungibili il badge resta vuoto;
  riprova aprendo l'isola dopo qualche minuto.
- Le prime righe di `scripts/bundle.sh` stampano toolchain, versione di Swift e SDK in uso.
- Log: `log stream --level info --predicate 'subsystem == "io.github.sonofrangu.halo"'` (senza
  `--level info` si vedono solo i messaggi principali). La build in esecuzione (commit e ora di
  `scripts/bundle.sh`) è in Impostazioni › Informazioni: se non corrisponde all'ultima, esci
  da Halo prima di riaprirlo (`open` riporta in primo piano l'istanza già aperta).

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
  app in Impostazioni › Notifiche se vuoi solo quello di Halo). Il formato del database è
  privato: se cambia, il banner mostra solo il nome dell'app.
- **Full Immersione**: non c'è un'API pubblica per le altre app; Halo legge il database di Non
  disturbare (`~/Library/DoNotDisturb/DB`, formato privato) e vede **solo le Full Immersioni
  attivate a mano**: una che parte da programma (orario, luogo, app) non lascia traccia lì, quindi
  non viene annunciata e non silenzia le notifiche di Halo. Durante una Full Immersione Halo
  silenzia *tutte* le notifiche, anche quelle delle app che la Full Immersione lascerebbe passare.
- **Download e AirDrop**: solo i file che arrivano nella cartella Download e solo dalle app che
  pubblicano l'avanzamento del file (Safari, AirDrop e la maggior parte dei browser; non i
  download fatti da Terminale). Il nome mostrato è quello del file in corso (senza
  `.download`/`.crdownload`); se il browser lo rinomina alla fine, "Mostra nel Finder" apre la
  cartella.
- **Comandi del player**: AppleScript solo per Spotify e Musica; per le altre app (browser,
  Podcast, …) MediaRemote, il cui invio diretto non è documentato, poi l'adapter (circa 0,2 s
  più lento) e il tasto multimediale. Avanti/indietro e posizione non si possono verificare
  sullo stream: usano AppleScript o la via che ha già funzionato per play/pausa.
- **Icona**: è un `.icns` classico (squircle disegnata con la griglia delle icone macOS). macOS
  26+ preferisce le icone di Icon Composer, compilabili solo con Xcode: se il sistema la
  giudica fuori forma può mostrarla dentro il proprio riquadro grigio.
- **AirPods**: batterie lette da `system_profiler` alla connessione e poi ogni 5 minuti finché
  le cuffie restano l'uscita audio (circa 30 ms di CPU a lettura); la scheda ricompare quando
  un auricolare (o la batteria unica) scende al 20% e al 10%, la custodia non conta. Se il
  dispositivo non pubblica le batterie si vede solo il volume.
- **Now Playing**: se l'adapter termina con errore Halo non lo rilancia (come raccomandato
  dall'adapter): serve riavviare Halo.
- **L'EQ non legge l'audio.** È un'animazione sintetica che parte solo in riproduzione; livelli
  reali richiederebbero permessi di cattura audio.
- **Artwork**: alcune app (spesso i browser) non forniscono la copertina o la forniscono in
  ritardo; al suo posto c'è un segnaposto con i colori neutri.
- **Titoli lunghi**: scorrono nel player dell'isola; nelle card (desktop, blocco) sono troncati.
- **Microfono/fotocamera**: Halo sa *che* un dispositivo è in uso, non *quale app* lo usa.
- **Modalità presentazione**: riconosce le app a tutto schermo (finestra grande quanto lo
  schermo), non la condivisione dello schermo.
- **Contenuti live** (senza durata) mostrano la barra vuota e `--:--`; il seek è disattivato.
- **Le ali coprono la menu bar**: in `compact` le ali nere stanno sopra gli elementi della menu
  bar adiacenti alla notch. I click li raggiungono comunque (il pannello è click-through), ma
  passarci sopra con il puntatore apre il player dopo ~90 ms.
- **HUD**: niente suono di feedback del volume (il tasto non arriva al sistema); luminosità solo
  del display integrato; niente tasti retroilluminazione tastiera (l'Air M2 non li ha).
- **Testi**: dipendono da LRCLIB (database comunitario): per brani rari o molto recenti possono
  mancare o essere sfasati.
- **Intel non provato**: `scripts/bundle.sh` produce un'app Universal (Halo e l'adapter per
  arm64 e x86_64), ma la parte x86_64 non è mai stata eseguita su un Mac Intel.
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
  Timer/          timer, Pomodoro e cronometro
  Transfers/      download e AirDrop (avanzamento pubblicato dei file)
  Focus/          Full Immersione (database di Non disturbare)
  Settings/       finestra Impostazioni (pagine, permessi)
  UI/             forma e viste SwiftUI (Alerts/, Calendar/, HUD/, Settings/, Shelf/, Timer/, Widgets/)
Tests/HaloTests   Swift Testing
scripts/          bundle.sh, build-adapter.sh, icon/render-icon.py
Support/          Info.plist, AppIcon.png
Vendor/           mediaremote-adapter (submodule)
```

## Licenza

Copyright © 2026 sonoFrangu. Halo è software libero: puoi ridistribuirlo e modificarlo secondo
i termini della [GNU General Public License versione 3](LICENSE). Chi distribuisce una versione
modificata deve pubblicarne il codice sorgente con la stessa licenza. Halo è distribuito senza
alcuna garanzia.

## Licenze di terze parti

[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) © 2025 Jonas van den
Berg e contributori, licenza BSD 3-Clause. Il testo della licenza è incluso in
`Halo.app/Contents/Resources/MediaRemoteAdapter/LICENSE` e nel submodule.

Servizi usati a runtime: [LRCLIB](https://lrclib.net) (testi), [Open-Meteo](https://open-meteo.com)
(meteo, dati CC BY 4.0), [ipwho.is](https://ipwho.is) (posizione approssimata).
