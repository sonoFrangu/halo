# Widget, schermata di blocco e notifiche in stile Apple — design

Data: 2026-09-29. Stato: approvato in chat, da implementare.

## Obiettivo

Rendere più "Apple" tre superfici di Halo, senza toccare il resto:

1. Il **widget sul desktop** diventa un widget medio in stile macOS 26.
2. La **card della schermata di blocco** usa lo stesso linguaggio, con i testi sincronizzati
   sotto, e sparisce allo sblocco anche se il main thread di Halo è bloccato.
3. Le **notifiche dalla notch** prendono l'impaginazione della Dynamic Island di iPhone, con un
   testo più curato e la miniatura della foto quando la notifica ne ha una.

Fuori dallo scopo: isola compatta ed espansa, animazioni d'ingresso degli avvisi,
Impostazioni, gli altri avvisi (batteria, HUD, AirPods, calendario, screenshot, timer).

Vincolo di consumo (preferenza dell'utente): Halo sotto l'1% di CPU. Nessuna animazione
continua nuova; misurare Halo **e** WindowServer, con la musica in riproduzione e con il
risparmio energetico spento.

## Scelte scartate (verificate su questo Mac, macOS 26)

- **Video del brano come sfondo della schermata di blocco, dietro orologio e password.** Non si
  può fare. Da bloccato a schermo ci sono `loginwindow` livello 2004 (orologio, foto,
  password), `loginwindow` livello 2001 (lo scudo, che disegna anche lo sfondo animato Sequoia)
  e, sotto, la finestra `Wallpaper` del desktop, che però non si vede. Tre prove:
  - una finestra di Halo al livello desktop + 1 resta invisibile;
  - `SLSCopySpacesForWindows` sulle finestre di loginwindow risponde vuoto, quindi non si può
    entrare nel loro spazio;
  - spazi SkyLight di Halo con livello assoluto 299 o 300 (finestre 0, 2002, 2003) restano
    invisibili; solo il livello 400 si vede, e copre tutto.

  Lo sfondo Sequoia non è un file video sostituibile. L'utente ha scelto di rinunciare al video.
- Il **Canvas di Spotify** e le **anteprime video di Apple** (iTunes Search, `entity=musicVideo`,
  `previewUrl` di 30 s) non servono più, perché non c'è più il video.

## Parte 1 — Linguaggio comune delle card

**`WidgetBackdrop`** (sostituisce `CardBackdrop`):
- `glassEffect(.regular)` in un `RoundedRectangle(style: .continuous)` e bordo bianco al 14% da
  0,5 pt;
- niente copertina sfocata, niente gradienti della palette;
- con *Riduci trasparenza*, fondo pieno `Color(white: 0.12)`.

Raggio: 22 pt sul desktop, 26 pt sul lock screen.

**`PlayerWidgetView`** (widget medio, sostituisce il layout di `PlayerCardView`):
- **Larghezza** ~360 pt, **altezza** ~170 pt, **padding** 14 pt.
- **A sinistra:** copertina quadrata da 142 pt, angoli continui da 12 pt, senza l'ombra
  colorata "prominente". Clic sulla copertina = apre l'app sorgente, come oggi.
- **A destra, in alto:**
  - riga dell'app sorgente: icona da 12 pt + nome in 10 pt semibold al 55% di bianco;
  - titolo in 15 pt semibold;
  - artista — album in 12 pt al 60%;
  - titolo e artista su una riga ciascuno, troncati; niente scorrimento del titolo.
- **A destra, in basso:**
  - barra da 3 pt (`ScrubberView`, che si ispessisce all'hover e al trascinamento come oggi);
  - tempi in 10 pt con cifre tabulari;
  - riga dei controlli ⏮ ⏯ ⏭ (`TransportControls` senza il pulsante dei testi).
- **Colore:** l'accento della palette resta solo sulla barra durante hover o trascinamento.
- **Ridisegno:** `ScrubberView` con `minimumInterval: 1` come oggi sulle card.

## Parte 2 — Widget sul desktop

`DesktopWidgetView` mostra `PlayerWidgetView` in misura `.desktop`. Quando non c'è musica
mostra `ClockCardView`, ridisegnato con lo stesso `WidgetBackdrop` e la stessa gerarchia
tipografica (ora grande in SF Rounded semibold, data e meteo come righe secondarie). I testi
sincronizzati non compaiono più nel widget desktop. Trascinamento e ombra restano come oggi.

## Parte 3 — Schermata di blocco

**`LockScreenView`**: `PlayerWidgetView` in misura `.lockScreen` (larghezza ~380 pt, raggio
26 pt). Sotto, se ci sono testi sincronizzati, `LyricsStrip`:
- separatore da 0,5 pt al 15% di bianco;
- le 3 righe di `LyricsPanel`: precedente, corrente e successiva, in 16 pt bold, corrente
  bianca, le altre al 40%.

Tutto dentro lo stesso `WidgetBackdrop`, come un unico oggetto. Senza testi resta la sola
parte del widget. La posizione resta quella di oggi (`LockScreenController.topFraction`).

**Nascondere allo sblocco senza il main thread.** Oggi `hide()` gira sul main actor, e un
main thread bloccato lascia lo spazio di livello 400 sopra il desktop (29 s il 2026-09-29).
- `LockScreenSpace` ottiene `hide()` e `show()` utilizzabili da qualsiasi thread, che chiamano
  `SLSHideSpaces` / `SLSShowSpaces`. `LockScreenSpace` diventa `@unchecked Sendable`, con i
  suoi campi immutabili.
- Nuovo **`UnlockWatch`**: `notify_register_dispatch("com.apple.sessionagent.screenIsUnlocked")`
  su una coda privata. A ogni sblocco chiama `space.hide()` direttamente su quella coda. Poi il
  main actor, quando arriva, fa il resto come oggi (`orderOut`, stato della card).
- `show()` dello spazio avviene al blocco, dal main actor, prima di `space.add(panel)`.
- Il nome della notifica BSD è quello scritto da `loginwindow` nel log
  (`sendBSDNotification: com.apple.sessionagent.screenIsUnlocked`); va verificato in
  implementazione che arrivi a un processo utente.

## Parte 4 — Notifiche dalla notch

Forma, dimensioni (`bannerWidth` ≥ 400, `bannerBodyHeight` 66), animazione d'ingresso, durata
(5,5 s) e clic (apre l'app) restano come oggi. Cambia `NotificationBanner`:

- **Sinistra:** `AppIcon` da 44 pt, angoli continui 10 pt.
- **Centro:**
  - riga del titolo: titolo in 14 pt semibold bianco; se c'è il sottotitolo, segue
    " · sottotitolo" in 14 pt regular al 55% (esempio: "**Giulia** · Calcetto");
  - sotto, il testo in 13 pt regular al 75%, fino a 2 righe, troncato alla fine.
- **Destra:**
  - con una foto allegata: miniatura 44 × 44, riempimento, angoli continui 10 pt;
  - senza foto: "ora" in 11 pt al 45% (il banner resta 5,5 s, quindi il tempo non cambia).
- Niente più nome dell'app in maiuscolo.

**`NotificationText`** (puro, testato) produce `headline`, `detail` e `message` da titolo,
sottotitolo, testo e nome dell'app:
- spazi e a capo consecutivi ridotti a uno spazio singolo;
- se il titolo, a parte maiuscole e spazi, è uguale al nome dell'app, il titolo sparisce: il
  sottotitolo o la prima riga del testo diventa `headline`;
- se manca tutto, `headline` = nome dell'app;
- il sottotitolo va in `detail`, nella riga del titolo, e non più davanti al testo.

`NotificationAlert` passa da `appName/title/body` a `headline/detail/message/image`
(URL facoltativo dell'allegato). `NotificationPayload.message`, che unisce sottotitolo e testo,
va rimosso: l'unione passa a `NotificationText`.

**Miniatura.**
- **Primo passo dell'implementazione:** con l'Accesso completo al disco concesso a Halo,
  leggere un record vero con una foto (per esempio WhatsApp) e trovare dove la plist
  `record.data` tiene l'allegato: chiave dentro `req` e forma (percorso di file, URL,
  identificatore).
- `NotificationPayload` impara a leggere quella chiave; un test con una plist costruita sulla
  forma vera.
- **Verificato il 2026-09-29:** la ricerca generica (primo URL `file://` o percorso assoluto
  di un'immagine dentro `req`) trova l'allegato di un vero `UNNotificationAttachment` (HEIC,
  app di prova firmata): la miniatura compare nel banner. Non serve conoscere la chiave
  esatta.
- **`NotificationThumbnail`** carica l'immagine su una coda privata con
  `CGImageSourceCreateThumbnailAtIndex` (lato massimo 88 px, `kCGImageSourceCreateThumbnailFromImageAlways`)
  e la tiene in una piccola cache per id della notifica (ultime 10). Il banner mostra "ora"
  finché la miniatura non è pronta.
- Se macOS non salva allegati, o il file non è leggibile, niente miniatura: nessun errore
  visibile, una riga nelle diagnostiche.

Le notifiche dei siti (`_WEB_CENTER_…`) restano escluse (commit 37b876a).

## Componenti e file

| File | Cambiamento |
|---|---|
| `UI/Widgets/WidgetBackdrop.swift` | nuovo, sostituisce `CardBackdrop.swift` (eliminato) |
| `UI/Widgets/PlayerWidgetView.swift` | nuovo, sostituisce `PlayerCardView.swift` (eliminato); `Metrics` `.desktop` / `.lockScreen` |
| `UI/Widgets/LyricsStrip.swift` | nuovo: separatore + `LyricsPanel` a 3 righe |
| `UI/Widgets/LockScreenView.swift`, `DesktopWidgetView.swift`, `ClockCardView.swift` | usano i nuovi pezzi |
| `System/LockScreenSpace.swift` | `show()`/`hide()` thread-safe, `Sendable` |
| `System/UnlockWatch.swift` | nuovo: notifica BSD di sblocco su coda privata |
| `Widgets/LockScreenController.swift` | usa `UnlockWatch`; mostra/nasconde lo spazio |
| `Notifications/NotificationText.swift` | nuovo, puro |
| `Notifications/NotificationThumbnail.swift` | nuovo |
| `Notifications/NotificationPayload.swift` | allegato; via `message` |
| `Notifications/NotificationMirror.swift`, `Alerts/IslandAlert.swift` | nuovo `NotificationAlert` |
| `UI/Alerts/NotificationBanner.swift` | nuovo layout |
| `docs/design.md` | sezioni Estetica, Widget, Notifiche aggiornate |

## Test

- `NotificationTextTests`: mittente semplice; gruppo con sottotitolo; titolo uguale al nome
  dell'app ("WhatsApp", "whatsapp "); testo su più righe e spazi doppi; tutto vuoto →
  nome dell'app.
- `NotificationPayloadTests`: allegato letto dalla forma vera; plist senza allegato → `nil`.
- `LyricsStrip` e i widget: prova manuale con `scripts/bundle.sh`:
  - widget desktop con e senza musica;
  - lock screen bloccando il Mac (con e senza testi);
  - allo sblocco la card sparisce anche con un blocco del main thread simulato (build di prova
    con uno `sleep` di 10 s sul main actor all'arrivo di `screenIsUnlocked`);
  - notifica con e senza foto.
- Consumo: Halo ~0% con musica; WindowServer invariato rispetto a Halo chiuso quando non si
  muove niente (stesso metodo di A/B a giri ripetuti usato il 2026-09-29).

## Limiti noti

- La card del lock screen resta sopra l'interfaccia di macOS (livello 400), non dietro: è il
  comportamento di oggi.
- La miniatura dipende da un formato privato. Se Apple lo cambia, le notifiche restano senza
  miniatura.
- Le icone sono quelle dell'app, non le foto dei contatti (non leggibili).
