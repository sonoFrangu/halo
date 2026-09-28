# Halo — design

## Obiettivo

App agente (solo barra dei menu) che disegna sopra la notch una "Dynamic Island" nera che
cresce dalla notch fisica: Now Playing di qualsiasi app, HUD luminosità/volume, avvisi
(ricarica, cuffie, notifiche), meteo, testi sincronizzati, scaffale file; più una card del
player sul desktop e sulla schermata di blocco. Funzioni equivalenti a Canopy, con un'estetica
più curata.

## Architettura in breve

```
                ┌───────────────────────────── processo figlio ──────────────────────────────┐
/usr/bin/perl mediaremote-adapter.pl MediaRemoteAdapter.framework stream --micros --debounce=40
                └──────────────┬────────────────────────────────────────────────────────────┘
                               │ stdout: una riga JSON per aggiornamento (diff)
                               ▼
 AdapterStream ── readabilityHandler → AsyncStream<Data> → Task detached (utility)
                               │   LineSplitter → NowPlayingStreamDecoder (merge dei diff, artwork)
                               ▼  NowPlayingSnapshot (Sendable)
 NowPlayingController (@MainActor) ──► NowPlayingModel (@Observable) ◄── LyricsController (LRCLIB)
                                           │
 HUDController ─┐                          │            WeatherController (Open-Meteo, on demand)
 PowerMonitor ──┤                          │            ShelfController (FileDragMonitor, ShelfStore)
 AudioDevice-   ├──► AlertCenter ──────────┤
   Monitor ─────┤    (coda, precedenze,    │
 Notification-  │     tempi, "hold")       ▼
   Mirror ──────┘                  IslandsCoordinator ── ScreenTracker, PointerMonitor
                                           │ un IslandController per display
                                           ▼
                             IslandViewModel (@Observable: stato, contesto, hover, drop)
                                           ▼
                   IslandPanelController → IslandPanel (NSPanel) → IslandHostingView → IslandRootView

 DesktopWidgetController / LockScreenController → CardPanel → PlayerCardView (stessi modelli)
```

Tutto è guidato da eventi: notifiche MediaRemote (nel processo perl), `readabilityHandler`,
eventi mouse, notifiche di sistema e distribuite, callback IOKit/CoreAudio, eventi kqueue sul
database delle notifiche, Observation. Nessun timer di polling. Gli unici "tick" sono
`TimelineView` per EQ e barra di avanzamento (in pausa quando non visibili o in pausa di
riproduzione; 1 fps sulle card sempre visibili), l'orologio del widget (1 al minuto) e i testi
(date esplicite dei cambi riga).

## Stati dell'isola

| Stato      | Quando                                            | Forma                                     |
|------------|---------------------------------------------------|-------------------------------------------|
| `idle`     | niente in riproduzione (o in pausa da >1,5 s)     | dentro la notch fisica (invisibile); pillola sui display senza notch |
| `compact`  | musica in riproduzione                            | notch + due "ali": mini copertina a sinistra, EQ a destra |
| `alert`    | un avviso di `AlertCenter`                        | stile `wings` (HUD, ricarica: ali larghe) o `banner` (cuffie, notifiche: corpo sotto la notch) |
| `expanded` | puntatore sopra l'isola (dopo ~90 ms) o file trascinati sulla notch | scheda Player (con testi) o Scaffale |

Una sola `NotchShape` animabile (larghezza, altezza, raggio inferiore, raggio "orecchie"
concave superiori) morfa fra stati e contesti. `IslandContext` (media presente, stile
dell'avviso, scheda, testi aperti) decide le misure dentro uno stato; i suoi cambi avvengono in
una molla, quindi anche aprire i testi o cambiare scheda è un morph della stessa forma.
Copertina ed EQ sono viste persistenti che cambiano cornice. Il resto compare con blur+scale
sfalsati dopo l'apertura; la chiusura usa una molla più corta e senza ritardi.

Priorità (`IslandViewModel.resolveState`): trascinamento in corso (mantiene la forma) > isola
già aperta sotto il puntatore (gli avvisi aspettano; l'HUD compare in linea
nell'intestazione) > file trascinati sulla notch > avviso > hover > riproduzione > `idle`.

## Avvisi (`AlertCenter`)

- Stesso tipo → sostituisce (nuovo livello HUD, notifica più recente).
- HUD → ha la precedenza; l'avviso interrotto torna in testa alla coda con il tempo pieno.
- Altri → in coda, uno dopo l'altro. Durate: HUD 1,6 s, ricarica 3,2 s, cuffie 4,5 s,
  notifiche 5,5 s.
- "Hold": trascinare la barra dell'HUD ferma tutto; puntatore su un banner o isola aperta
  fermano tutto tranne l'HUD (così un banner non scade senza essere visto).

## Click-through e focus

- `IslandPanel`: `NSPanel` borderless + `.nonactivatingPanel`, `canBecomeKey/Main = false`,
  livello `mainMenu + 3`, `canJoinAllSpaces + stationary + fullScreenAuxiliary + ignoresCycle`.
- `ignoresMouseEvents = true` sempre, tranne quando l'isola è aperta (`expanded` o `alert`)
  **e** il puntatore è sopra (o si sta trascinando una barra, o dei file sulla notch).
- L'hover è geometrico (rettangolo dell'isola in coordinate schermo) da monitor globale/locale
  `mouseMoved`/`leftMouseDragged` e da una tracking area `.activeAlways`. I monitor di eventi
  mouse non richiedono permessi.
- `acceptsFirstMouse = true`: i pulsanti funzionano al primo click senza attivare l'app.

## Più display

`IslandsCoordinator` tiene un `IslandController` per display (`CGDirectDisplayID`), ricostruito
su `didChangeScreenParametersNotification`; i servizi (Now Playing, avvisi, testi, meteo,
scaffale) sono condivisi, ogni isola ha il suo view model. Con "Su tutti i display" spento resta
solo l'isola del display con la notch (o del principale). Un avviso è mostrato su tutte le isole;
un'isola aperta lo trattiene con un "hold" per display.

## Fluidità

Durante il morph cambiano solo il tracciato della forma e le cornici del contenuto; ciò che
richiede filtri costosi è statico o arriva dopo che la molla si è assestata:

- ombra e alone (`IslandDecoration`) sono copie sfocate del contorno *finale*, inserite con
  ~0,28 s di ritardo e tolte subito in chiusura;
- l'ombra colorata della copertina ha un'animazione propria ritardata;
- i controlli Liquid Glass entrano senza blur;
- copertina e miniature dello scaffale sono decodificate fuori dal main thread.

## HUD luminosità e volume

`MediaKeyTap` (event tap attivo su `NX_SYSDEFINED`, sottotipo 8) intercetta luminosità, volume
e muto; `HUDController` applica il passo (`HUDStep`: 1/16, o 1/64 con Opzione+Maiusc) con
`DisplayBrightness` (DisplayServices, privato, `dlopen`) o `SystemVolume` (CoreAudio) e pubblica
l'avviso `.hud`. Se la regolazione non è possibile il tasto passa al sistema. Serve
Accessibilità: `AccessibilityPermission` la chiede una volta e ascolta
`com.apple.accessibility.api` per attivare il tap appena concessa.

## Ricarica e cuffie

- `PowerMonitor`: `IOPSNotificationCreateRunLoopSource`; `PowerTransition` (funzione pura,
  testata) decide l'avviso: collegato, scollegato, soglie 20/10/5 % scendendo a batteria.
- `AudioDeviceMonitor`: listener CoreAudio su `kAudioHardwarePropertyDefaultOutputDevice`;
  quando l'uscita diventa cuffie/AirPods pubblica un banner, poi `BluetoothBatteryReader`
  (`system_profiler SPBluetoothDataType -json`, fuori dal main actor, un solo tentativo in più
  dopo 4 s) aggiorna le batterie nello stesso banner. `HeadphoneBatteries.parse` è testata.

## Testi sincronizzati

`LyricsController` osserva la traccia corrente, fa debounce (350 ms) e cerca su LRCLIB
(`/api/get`, poi `/api/search`), con cache LRU di 60 brani. `LRCParser` (testato) gestisce più
timestamp per riga, frazioni a 2/3 cifre, `[offset:]`. `LyricsPanel` usa un `TimelineView` con
le date esatte dei cambi riga (`LyricsTimeline.changeDates`), ricalcolate quando cambia la
timeline (seek, pausa): si ridisegna solo quando cambia la riga.

## Meteo

`WeatherController` aggiorna all'avvio e quando un'isola si apre se il dato ha più di 20
minuti: nessun timer. Posizione da `LocationProvider` (Core Location, una tantum, timeout 8 s)
o, se negata, da ipwho.is; condizioni da Open-Meteo. `WeatherCode` → simbolo SF + descrizione.

## Scaffale file

- `FileDragMonitor`: monitor globali/locali di `leftMouseDown/Dragged/Up`; un trascinamento di
  file cambia il `changeCount` della pasteboard di drag rispetto a quello registrato al rilascio
  precedente → "file in trascinamento". Nessun permesso, nulla gira a mouse fermo.
- Con file in trascinamento e puntatore sulla notch l'isola si apre sulla scheda Scaffale, che
  diventa bersaglio (`DropDelegate`). `ShelfStore` salva i percorsi in UserDefaults (max 24,
  elimina quelli spariti); `ShelfThumbnails` genera anteprime Quick Look in background.

## Notifiche

Non esiste un'API pubblica per osservare le notifiche delle altre app. `NotificationMirror`
apre in sola lettura il database SQLite di Centro Notifiche
(`~/Library/Group Containers/group.com.apple.usernoted/db2/db`, serve l'Accesso completo al
disco), memorizza l'ultimo `rec_id` e, a ogni scrittura segnalata da `DatabaseChangeWatcher`
(kqueue su db, db-wal e cartella; raffiche raggruppate in 120 ms), legge i record nuovi e
pubblica i banner. `NotificationPayload` (testato) decodifica la plist binaria (`req.titl`,
`req.subt`, `req.body`). Senza permesso il menu mostra la voce per concederlo e Halo riprova a
ogni cambio di app attiva.

## Widget sul desktop e schermata di blocco

- `CardPanel`: `NSPanel` borderless trasparente non attivante; `PlayerCardView` riusa copertina,
  controlli, barra e testi dell'isola su uno sfondo `CardBackdrop` (Liquid Glass + copertina
  sfocata + sfumatura scura; pieno con *Riduci trasparenza*).
- Desktop: livello `desktopIconWindow + 1` (sopra le icone, sotto ogni finestra), su tutti gli
  Spazi, trascinabile con `WindowDragGesture`, posizione salvata (`setFrameAutosaveName`).
  Senza musica mostra ora, data e meteo.
- Schermata di blocco: `LockScreenController` ascolta `com.apple.screenIsLocked/Unlocked`; con
  musica in riproduzione mostra la card e la sposta, con `LockScreenSpace`, in uno spazio
  SkyLight creato dall'app con livello assoluto sopra quello del lock screen
  (`SLSSpaceCreate`, `SLSSpaceSetAbsoluteLevel`, `SLSShowSpaces`,
  `SLSSpaceAddWindowsAndRemoveFromSpaces`, risolti a runtime). La finestra di login dopo un
  riavvio precede ogni app utente: lì non si può mostrare nulla.

## Geometria della notch

`NotchGeometry` usa `safeAreaInsets.top` (altezza) e la larghezza di
`auxiliaryTopLeftArea`/`auxiliaryTopRightArea` (larghezza e centro della notch). Senza notch:
notch virtuale 184 pt × altezza menu bar, centrata. `IslandLayout` (struct pura, testata)
deriva dimensioni e cornici per ogni stato e contesto.

## File (tutti piccoli, una responsabilità)

```
Package.swift                         SwiftPM, macOS 26, Swift 6
Support/Info.plist                    LSUIElement, bundle id, versione, testo del permesso di posizione
scripts/build-adapter.sh              compila MediaRemoteAdapter.framework con clang (niente CMake)
scripts/bundle.sh                     swift build -c release + assemblaggio Halo.app + codesign (ad-hoc o "Halo Local")
Vendor/mediaremote-adapter            submodule git (ungive/mediaremote-adapter, tag v0.7.7, BSD-3)
.github/workflows/build.yml           CI: macos-26 (Xcode 26.6/26.0.1) test + bundle + artifact; xcode-27 build SDK 27
                                      con Xcode e Command Line Tools; blocco macro SwiftUI

Sources/Halo/
  App/            HaloApp, AppDelegate (composition root), Log, Preferences
  MenuBar/        StatusItemController, MenuItems, LoginItemController (SMAppService)
  System/         DisplayBrightness, SystemVolume, MediaKeyTap, AccessibilityPermission, LockScreenSpace
  HUD/            HUDController, HUDModel, HUDStep
  Alerts/         IslandAlert, AlertCenter
  Power/          PowerSnapshot (+ PowerTransition), PowerMonitor
  AudioDevices/   HeadphoneBatteries, BluetoothBatteryReader, AudioDeviceMonitor
  Lyrics/         LRCParser (+ LyricsTimeline), LyricsService, LyricsController
  Weather/        WeatherCode, WeatherService, LocationProvider, WeatherController
  Shelf/          ShelfStore, FileDragMonitor, ShelfThumbnails, ShelfController
  Notifications/  NotificationPayload, NotificationDatabase, DatabaseChangeWatcher, NotificationMirror
  Widgets/        CardState, CardPanel, DesktopWidgetController, LockScreenController
  NowPlaying/     NowPlayingSnapshot, PlaybackTimeline, MediaCommand, NowPlayingModel, NowPlayingController
  NowPlaying/Adapter/  AdapterResources, AdapterStream, AdapterCommandRunner, LineSplitter,
                       NowPlayingStreamDecoder, StderrTail
  Artwork/        ArtworkDecoder, RGBColor, ArtworkPalette, PaletteExtractor, KMeans, PaletteSelector
  Island/         IslandState, NotchGeometry, IslandLayout, IslandViewModel, IslandController,
                  IslandsCoordinator, IslandServices, ScreenTracker, PointerMonitor, Motion
  Island/Panel/   IslandPanel, IslandHostingView, IslandPanelController
  UI/             IslandRootView, IslandDecoration, IslandContentView, NotchShape (+ NotchOutline,
                  SmoothCorner), ArtworkView, SourceIconView, EqualizerView (+ EqualizerWave),
                  TrackInfoView, ScrubberView, TransportControls, LyricsPanel, WeatherBadge,
                  ExpandedTabsView, PressableButtonStyle, RevealModifier, ExpandedBackdrop,
                  EmptyStateView, PlayerActions
  UI/HUD/         HUDGlyph, HUDLevelBar, HUDValueLabel, InlineHUDView
  UI/Alerts/      BatteryGlyph, PowerValueView, BatteryRing, AudioDeviceBanner, NotificationBanner
  UI/Shelf/       ShelfView (+ ShelfTile, ShelfDropDelegate)
  UI/Widgets/     CardBackdrop, PlayerCardView, ClockCardView, DesktopWidgetView, LockScreenView
Tests/HaloTests/  Swift Testing: parsing, timeline, geometria, layout, forma, palette, HUD, avvisi,
                  batteria, cuffie, LRC, meteo, notifiche
```

## Flusso dati Now Playing

1. `AdapterResources` trova `Contents/Resources/MediaRemoteAdapter/{mediaremote-adapter.pl,
   MediaRemoteAdapter.framework}` (percorsi assoluti, come richiesto dall'adapter).
2. `AdapterStream` avvia `stream --micros --debounce=40`. Ogni riga `{"type":"data","diff":…,"payload":…}`
   viene applicata allo stato: `diff=false` sostituisce, `diff=true` unisce, `null` rimuove.
   Payload vuoto = nessun player. Artwork base64 decodificato una volta sola per cambio.
3. `NowPlayingController` pubblica lo snapshot sul main actor, decodifica `NSImage`, calcola la
   palette off-main, risolve l'icona dell'app sorgente.
4. Il tempo trascorso non viene mai "pollato": `PlaybackTimeline` = (elapsed, timestamp, rate)
   ed è valutato solo quando serve disegnare.
5. Comandi: `send 2` (play/pausa), `send 4/5` (avanti/indietro), `seek <µs>`; eseguiti in ordine
   da `AdapterCommandRunner`, con aggiornamento ottimistico dell'interfaccia.
6. Uscita del processo: exit ≠ 0 → adapter "non disponibile"; altrimenti riavvio con backoff
   (max 3 tentativi).

## Estetica

- Corpo nero puro `#000`; orecchie superiori concave; angoli inferiori continui stile Apple
  (corner smoothing di Figma, 0,6).
- Molle: apertura `spring(0.5, bounce 0.24)`, chiusura `spring(0.34, 0.08)`, cambi di contesto
  `spring(0.45, 0.16)`.
- Player: copertina con angoli continui e ombra colorata, bagliore radiale dei colori dominanti,
  alone esterno, barra che si ingrossa all'hover, Liquid Glass solo sui controlli.
- Avvisi disegnati a mano: batteria che si riempie a molla con fulmine, anelli per auricolari e
  custodia, cifre che scorrono; testi con la riga corrente sfumata nei colori della copertina.
- Card desktop/lock screen: vetro + copertina sfocata come campo di colore, bordo sottile.
- Accessibilità: *Riduci movimento* → niente rimbalzi/blur/scale; *Riduci trasparenza* →
  fondi pieni al posto del vetro, niente alone esterno.

## Rischi

- **API private e workaround** (MediaRemote via perl, DisplayServices, SkyLight, database delle
  notifiche): tutte caricate/lette a runtime; se spariscono si spegne solo la funzione relativa.
- **Geometria notch**: la larghezza da `auxiliaryTop*Area` può differire di 1–2 pt dall'hardware;
  in `idle` la forma è leggermente più piccola della notch per restare invisibile.
- **Hover e drop su pannelli non-key**: da verificare a mano.
- **Notifiche e Full Immersion**: Halo non vede lo stato delle Full Immersion.
- **Firma ad-hoc**: i permessi TCC vanno riconcessi a ogni build (usa "Halo Local").
- **Build solo in CI**: nessun Mac nel cloud; tutto ciò che è visivo va verificato in locale.
- **Processo figlio orfano**: se Halo va in crash, perl muore al primo write su pipe chiusa.
