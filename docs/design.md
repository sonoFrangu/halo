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
| `compact`  | musica, un timer o microfono/fotocamera in uso    | notch + due "ali": copertina (o anello del timer, o icona) a sinistra; EQ (o countdown, o pallino) a destra |
| `alert`    | un avviso di `AlertCenter`                        | stile `wings` (HUD, ricarica: ali larghe) o `banner` (cuffie, notifiche: corpo sotto la notch) |
| `expanded` | puntatore sopra l'isola (dopo ~90 ms, regolabile) o file trascinati sulla notch | scheda Musica (con testi), Scaffale, Calendario o Timer |

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

La riga mostrata è `LyricsTimeline.displayedIndex`: posizione + anticipo (`lead`, 0,25 s,
regolabile) + tolleranza di 20 ms. La tolleranza corregge un difetto reale: valutata
*esattamente* alla data programmata, la posizione poteva cadere un soffio prima del confine per
arrotondamento (le `Date` hanno una risoluzione di ~10⁻⁷ s a questa distanza dal 2001) e la riga
precedente restava a schermo fino al cambio successivo, cioè il testo andava in ritardo di una
riga circa una volta su due. Il test di regressione valuta ogni data programmata.

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

## Gesti

`IslandHostingView` offre gli eventi di scroll a `IslandController`, che li riduce a
`ScrollSample` e li passa a `ScrollGestureInterpreter` (puro, testato): blocco dell'asse dopo
6 pt, un salto di brano per gesto oltre 60 pt, volume continuo (1/220 per punto, 1/16 per
scatto di rotella), inerzia ignorata, scorrimento naturale gestito. Attivo solo sull'isola
aperta sulla scheda Musica o sopra l'HUD del volume; altrove l'evento prosegue (es. lo
scaffale scorre). `Haptics` usa `NSHapticFeedbackManager`.

## Calendario

`CalendarController` (EventKit, accesso completo) legge gli eventi da −12 h a +36 h e si
aggiorna su `EKEventStoreChanged`, `NSCalendarDayChanged`, risveglio e **un solo** task
dormiente fino al prossimo confine (`CalendarSchedule.nextChange`: ingresso
nell'intestazione a −60 min, promemoria a −5 min, inizio, fine). `MeetingLink` trova i link
delle videochiamate con espressioni regolari; `CalendarText` scrive gli orari relativi.

## Screenshot

`ScreenshotWatcher` è una `NSMetadataQuery` viva su `kMDItemIsScreenCapture == 1` e data di
creazione ≥ avvio, in tutta la home: Spotlight notifica ogni nuovo file. Il banner usa le
miniature Quick Look già usate dallo scaffale.

## Timer

`FocusTimer` è un valore (data di fine mentre corre, tempo residuo in pausa) e `Pomodoro` la
macchina a stati del ciclo, entrambi testati. `TimerController` dorme fino alla fine; le viste
contano alla rovescia con `Text(timerInterval:countsDown:)` (lo aggiorna il sistema) e
ridisegnano l'anello una volta al secondo solo se visibile e in corsa
(`TimelineView(.animation(minimumInterval: 1, paused:))`: prima un anello nascosto continuava a
ticchettare). `Stopwatch` è il valore gemello (data d'inizio virtuale mentre corre, tempo in
pausa) e conta in su con `Text(timerInterval:countsDown: false)`; il quadrante gira solo se
visibile.

## Attività live

`LiveActivity.current` sceglie cosa mostrare nelle ali oltre alla musica, in ordine: timer,
cronometro, timer di Orologio, trasferimento. Con musica l'attività sostituisce l'equalizzatore a destra; senza,
occupa anche l'ala sinistra. `IslandViewModel.liveActivityChanged` tiene l'isola `compact`.

- **Download e AirDrop** (`TransferMonitor`): `Progress.addSubscriber(forFileURL:)` sulla
  cartella Download riceve i `Progress` che browser e AirDrop pubblicano per i file che
  scrivono (`fileOperationKind` `.downloading` / `.receiving`, o suffisso `.download`,
  `.crdownload`, `.part`). Le chiusure girano sulle code di Foundation: sono create in funzioni
  `nonisolated` (non ereditano il main actor) e ne escono solo valori `Sendable` tramite
  `TransferSink`; `FractionGate` lascia passare solo i cambi di un punto percentuale. Alla
  rimozione della pubblicazione (`UnpublishingHandler`) un trasferimento completato posta il
  banner `.transfer`.
- **Full Immersione** (`FocusMonitor`, `FocusStore` testato): legge
  `~/Library/DoNotDisturb/DB/Assertions.json` (Full Immersione attivata a mano) e
  `ModeConfigurations.json` (nome, simbolo, colore), osservati con `DatabaseChangeWatcher`
  (kqueue sulla cartella). Un cambio posta l'avviso `.focus`; `NotificationMirror.isSuppressed`
  tace le notifiche mentre una è attiva. Le Full Immersioni da programma non compaiono in quel
  file.
- **Sblocco** (`UnlockGreeter`): `com.apple.screenIsUnlocked` → avviso `.unlock`, il lucchetto
  si apre con `contentTransition(.symbolEffect(.replace))` 0,3 s dopo la comparsa.
- **Timer di Siri e Orologio** (`SystemTimerMonitor`, `SystemTimerLogParser` e
  `SystemTimerState` testati): `mobiletimerd` accetta solo client Apple e la voce Timer della
  barra dei menu non è esposta all'Accessibilità, quindi Halo segue `log stream --style ndjson`
  sui messaggi `com.apple.mobiletimer.logging` del Centro di Controllo: "has next trigger"
  (corre, fino a una data), "next timer changed: (null)" (pausa, annullamento o fine: nel log
  sono uguali) e "timer fired" (banner timer). Il timer diventa un `FocusTimer` `.countdown`,
  con la durata vista al primo avvio; un timer in pausa non compare. Se `log` si chiude,
  riprova dopo 5 s, al terzo fallimento lo scrive nelle diagnostiche.
- **Comandare Orologio** (`ClockAppDriver`, `TimerCommands`): Comandi Rapidi non serve
  (l'azione "Avvia timer" fallisce con errore 101 su macOS 26). La scheda Timer di Orologio è
  esposta all'Accessibilità (`TimePicker`, `PauseResumeButton`, `CancelButton`, "Recenti").
  Le rotelle accettano `AXValue` e `AXIncrement` ma Orologio in secondo piano li ignora. I
  Recenti mostrano al massimo 7 voci con una regola interna: 4 e 5 min avviati e annullati non
  compaiono, quindi non si possono riempire in anticipo. Su Mac Comandi Rapidi non ha le azioni
  di pausa e ripresa del timer.
  Orologio ignora i clic mentre è nascosto ma non mentre è solo in secondo piano: ogni comando
  lo mostra senza attivarlo, con la finestra spinta nell'angolo in basso a sinistra (macOS ne
  lascia visibili circa 40 × 110 punti), preme e lo nasconde; il focus non si sposta. Un avvio
  usa la voce dei Recenti con la stessa durata; se non c'è, scrive le cifre nelle rotelle, le
  rilegge e riscrive se diverse (i primi tasti dopo l'attivazione possono perdersi, e partirebbe
  la durata rimasta). I tasti arrivano solo all'app attiva con la finestra sullo schermo:
  Orologio compare per circa un secondo, poi il focus torna all'app di prima (`AXFrontmost`,
  perché `activate()` da un'app in secondo piano è rifiutato da macOS 14). Impostazioni ›
  Attività sceglie l'app dei timer della notch (Halo, predefinito, o Orologio); se Orologio non
  risponde parte il timer di Halo. Una pausa chiesta dalla notch resta visibile (`SystemTimer.pausedRemaining`). Entrando
  nell'isola sopra l'ala destra mentre c'è un timer, l'isola si apre sulla scheda Timer.

## Siri

`SiriMonitor`: un `AXObserver` sui processi `com.apple.Siri` e `com.apple.campo` ("Siri AI")
sveglia il monitor quando aprono una finestra; la lista finestre (i PID dei proprietari non
richiedono permessi) dice se una è a schermo, e finché lo è viene ricontrollata ogni 0,5 s.
Senza Accessibilità, controllo ogni secondo. Siri a schermo → avviso `.siri` (ali), tenuto con
`AlertCenter.setInteracting(by: "siri")` e ritirato alla chiusura. `SiriGlowView` disegna un
gradiente angolare che ruota lungo il bordo dell'isola (fermo con Riduci movimento o effetti
ridotti); `SiriGlyph` un'onda nell'ala sinistra. Il pannello di Siri resta dove lo mette macOS.

## Microfono, fotocamera, tastiera

- `PrivacyIndicators`: listener CoreAudio su `kAudioDevicePropertyDeviceIsRunningSomewhere` di
  ogni dispositivo d'ingresso e CoreMediaIO su `kCMIODevicePropertyDeviceIsRunningSomewhere` di
  ogni fotocamera, più i listener sugli elenchi dei dispositivi per ri-registrarsi.
- `KeyboardMonitor`: notifica distribuita `TISNotifySelectedKeyboardInputSourceChanged` e
  monitor `flagsChanged` (serve Accessibilità) per Bloc Maiusc; avvisi "ali" brevi.

## Presentazione ed energia

- `PresentationDetector`: al cambio di app o di Spazio (con 0,6 s di assestamento) legge
  `CGWindowListCopyWindowInfo` e imposta `AlertCenter.isQuiet` se l'app in primo piano ha una
  finestra grande quanto un display. In quiete `IslandAlert.waitsOutPresentations` scarta
  notifiche, cuffie, alimentatore, screenshot.
- `EnergyMode` segue `NSProcessInfoPowerStateDidChange`; con Low Power Mode imposta
  l'ambiente `reducesEffects` (EQ fermo, rivelazioni senza blur/scale, barra a 4 fps, niente
  marquee) e il view model usa animazioni brevi come con Riduci movimento.

## Impostazioni

`SettingsWindowController` apre una finestra SwiftUI con `NavigationSplitView`, come
Impostazioni di Sistema: una barra laterale di `SettingsPane` e, per ognuna, un `Form`
raggruppato con intestazione (icona, titolo, a cosa serve la pagina). `SettingsModel` è un
catalogo di `SettingsGroup` di `SettingsItem` (interruttori e cursori); ogni `SettingsToggle`
ha spiegazione, permesso richiesto (`requires`) e dipendenza (`dependsOn`, che lo disattiva
se l'opzione madre è spenta). La pagina Permessi calcola lo stato di Accessibilità
(`AXIsProcessTrusted`), Accesso completo al disco (apertura del database delle notifiche),
Calendari (EventKit) e Localizzazione, e apre la pagina giusta di Impostazioni di Sistema. Il
contatore `revision` fa rileggere i valori non osservabili; tornando su Halo
(`didBecomeActiveNotification`) la finestra si aggiorna. Il menu della barra dei menu contiene
solo stato, Timer e cronometro, Impostazioni, una voce per i permessi mancanti ed Esci.

## Icona

`scripts/icon/render-icon.py` (NumPy + Pillow) disegna a 2× e riduce: squircle 824/1024
(superellisse, esponente 4,6), fondo grafite, isola nera con alone a gradiente conico e mini
equalizzatore, ombra nel margine. Il PNG 1024 è nel repository; `bundle.sh` genera l'iconset con
`sips` e lo `.icns` con `iconutil` (entrambi di sistema).

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
scripts/bundle.sh                     swift build -c release + assemblaggio Halo.app + codesign (ad-hoc, "Halo Local" o "Apple Development")
Vendor/mediaremote-adapter            submodule git (ungive/mediaremote-adapter, tag v0.7.7, BSD-3)
.github/workflows/build.yml           CI: macos-26 (Xcode 26.6/26.0.1) test + bundle + artifact; xcode-27 build SDK 27
                                      con Xcode e Command Line Tools; blocco macro SwiftUI

Sources/Halo/
  App/            HaloApp, AppDelegate (composition root), Log, Preferences
  MenuBar/        StatusItemController, MenuItems, LoginItemController (SMAppService)
  System/         DisplayBrightness, SystemVolume, MediaKeyTap, AccessibilityPermission, LockScreenSpace,
                  PrivacyIndicators, KeyboardMonitor, PresentationDetector, EnergyMode, UnlockGreeter
  HUD/            HUDController, HUDModel, HUDStep
  Alerts/         IslandAlert, AlertCenter
  Power/          PowerSnapshot (+ PowerTransition), PowerMonitor
  AudioDevices/   HeadphoneBatteries, BluetoothBatteryReader, AudioDeviceMonitor
  Lyrics/         LRCParser (+ LyricsTimeline), LyricsService, LyricsController
  Weather/        WeatherCode, WeatherService, LocationProvider, WeatherController
  Shelf/          ShelfStore, FileDragMonitor, ShelfThumbnails, ShelfController
  Notifications/  NotificationPayload, NotificationDatabase, DatabaseChangeWatcher, NotificationMirror
  Widgets/        CardState, CardPanel, DesktopWidgetController, LockScreenController
  Gestures/       ScrollGestureInterpreter, Haptics
  Calendar/       CalendarEvent (+ MeetingLink, CalendarSchedule), CalendarText, CalendarController
  Screenshots/    ScreenshotWatcher, ScreenshotController
  Timer/          FocusTimer (+ TimerMode, Pomodoro), Stopwatch, TimerAlert, TimerController
  Transfers/      Transfer (+ TransferNaming), TransferMonitor (+ TransferSink, FractionGate, TrackedProgress)
  Focus/          FocusMode (+ FocusStore), FocusMonitor
  Settings/       SettingsModel (+ SettingsPane, SettingsPermission, SettingsToggle), SettingsWindowController
  NowPlaying/     NowPlayingSnapshot, PlaybackTimeline, MediaCommand, PlayerCommand (+ CommandRoute,
                  ScriptablePlayer), PlaybackReconciler, ScriptRunner, MediaKeyPoster, DirectMediaRemote,
                  NowPlayingModel, NowPlayingController
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
  UI/Alerts/      BatteryGlyph, PowerValueView, BatteryRing, AudioDeviceBanner, NotificationBanner,
                  CalendarBanner, ScreenshotBanner, TimerBanner, KeyboardAlertView,
                  ActivityAlertViews (Full Immersione, sblocco, TransferBanner)
  UI/Shelf/       ShelfView (+ ShelfTile, ShelfDropDelegate)
  UI/Widgets/     CardBackdrop, PlayerCardView, ClockCardView, DesktopWidgetView, LockScreenView
  UI/Calendar/    CalendarTabView (+ CalendarEventRow, JoinButton), NextEventBadge
  UI/Timer/       TimerRing (+ TimerCountdownText), TimerTabView (+ TimerRingView, CapsuleActionButton),
                  StopwatchViews (quadrante, righe), CompactTimerView (LiveActivity, ali, TransferRing)
  UI/Settings/    SettingsView (barra laterale, pagine, righe, permessi)
  UI/             … PrivacyIndicatorView, TrackInfoView (+ MarqueeText), TransportControls (+ GlassDiscButtonStyle)
Tests/HaloTests/  Swift Testing: parsing, timeline, geometria, layout, forma, palette, HUD, avvisi,
                  batteria, cuffie, LRC e sincronia, meteo, notifiche, gesti, calendario, timer,
                  cronometro, Full Immersione, download
scripts/icon/render-icon.py           disegna Support/AppIcon.png (NumPy + Pillow; il PNG è versionato)
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
5. Comandi (`PlayerCommand`): *play* e *pausa* espliciti (mai l'inverti, che con due clic
   ravvicinati si annullava), avanti, indietro, posizione. Le vie (`CommandRoute`), dalla più
   affidabile:
   - **AppleScript** per Spotify e Musica (`ScriptablePlayer`, `ScriptRunner` su una coda
     seriale fuori dal main thread; permesso Automazione chiesto al primo uso). I comandi
     MediaRemote arrivano a Spotify solo a intermittenza: era la causa della pausa che serviva
     cliccare più volte;
   - **MediaRemote nel processo** (`DirectMediaRemote`, `MRMediaRemoteSendCommand` risolto con
     `dlsym`);
   - **adapter** (`AdapterCommandRunner`, `send 0/1/4/5`, `seek`);
   - **tasto multimediale** (`MediaKeyPoster`, evento `NX_SYSDEFINED` come la tastiera; serve
     Accessibilità; per play/pausa è un inverti).

   Play/pausa passa da `PlaybackReconciler` (puro, testato): il clic fissa lo stato voluto;
   un comando parte solo se lo stream mostra l'altro stato e nessun comando è in volo, così i
   clic ravvicinati si fondono e l'inverti del tasto multimediale non si annulla da solo. Una
   via non confermata dallo stream entro il suo tempo (0,9–1,5 s) passa alla successiva; la via
   che funziona viene ricordata per app e provata per prima, quelle fallite per ultime. Dopo
   tutte le vie, o 6 s, la richiesta decade e l'interfaccia torna allo stato reale. Avanti,
   indietro e posizione non sono verificabili sullo stream ("indietro" può solo riavviare il
   brano): usano AppleScript, oppure la via che ha già funzionato per play/pausa, oppure
   l'adapter. Ogni tentativo finisce nel log con via ed esito.
6. `NowPlayingStreamDecoder`: lo stato di riproduzione è `playing && playbackRate != 0`
   (Spotify in pausa resta "playing" e porta solo la velocità a 0: prima il tempo continuava a
   scorrere fino a 0:00). Quando un diff porta solo il cambio di stato, riancora la posizione
   nota all'istante del cambio invece di riusare la coppia elapsed/timestamp vecchia (una
   ripresa saltava avanti di tutta la pausa).
7. Uscita del processo: exit ≠ 0 → adapter "non disponibile"; altrimenti riavvio con backoff
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
- **Firma ad-hoc**: i permessi TCC vanno riconcessi a ogni build (usa "Halo Local" o un certificato "Apple Development").
- **Build solo in CI**: nessun Mac nel cloud; tutto ciò che è visivo va verificato in locale.
- **Processo figlio orfano**: se Halo va in crash, perl muore al primo write su pipe chiusa.
