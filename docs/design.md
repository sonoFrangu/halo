# Halo — design (MVP: shell della notch + Now Playing)

## Obiettivo

App agente (solo barra dei menu) che disegna sopra la notch una "Dynamic Island" nera che
cresce dalla notch fisica. MVP: shell della notch + Now Playing di qualsiasi app.

## Architettura in breve

```
                ┌───────────────────────────── processo figlio ──────────────────────────────┐
/usr/bin/perl mediaremote-adapter.pl MediaRemoteAdapter.framework stream --micros --debounce=40
                └──────────────┬────────────────────────────────────────────────────────────┘
                               │ stdout: una riga JSON per aggiornamento (diff)
                               ▼
 AdapterStream ── readabilityHandler → AsyncStream<Data> → Task detached (utility)
                               │   LineSplitter (frame su '\n') → NowPlayingStreamDecoder
                               │   (merge dei diff, base64 → Data artwork)
                               ▼  NowPlayingSnapshot (Sendable)
 NowPlayingController (@MainActor) ──► NowPlayingModel (@Observable)
        │  ▲ comandi (send/seek)             │  artwork NSImage + palette (Core Image + k-means, off-main)
        ▼  │                                 ▼
 AdapterCommandRunner (coda ordinata      IslandController ── withObservationTracking ──► IslandViewModel
 di processi perl brevi)                     │  ScreenTracker (didChangeScreenParameters)        (@Observable: stato, hover)
                                             │  PointerMonitor (NSEvent global/local mouseMoved)
                                             ▼
                                   IslandPanelController → IslandPanel (NSPanel) → IslandHostingView → IslandRootView (SwiftUI)
```

Tutto è guidato da eventi: notifiche MediaRemote (nel processo perl), `readabilityHandler`,
eventi mouse, notifiche di cambio schermo, Observation. Nessun timer di polling. Gli unici
"tick" sono `TimelineView` per EQ e barra di avanzamento, messi in pausa quando non visibili o
quando la musica non suona → CPU ~0% da ferma.

## Stati dell'isola

| Stato      | Quando                                            | Forma                                     |
|------------|---------------------------------------------------|-------------------------------------------|
| `idle`     | niente in riproduzione (o in pausa da >1,5 s)     | dentro la notch fisica (invisibile); pillola finta sui monitor senza notch |
| `compact`  | musica in riproduzione                            | notch + due "ali": mini copertina a sinistra, EQ a destra |
| `hud`      | tasto luminosità/volume/muto (per ~1,6 s)         | notch + ali larghe: icona a sinistra, barra e % a destra |
| `expanded` | puntatore sopra l'isola (dopo ~90 ms)             | player completo (o stato vuoto se non c'è media) |

Una sola `NotchShape` animabile (larghezza, altezza, raggio inferiore, raggio "orecchie"
concave superiori) morfa fra gli stati. Copertina ed EQ sono viste persistenti che cambiano
cornice (piccola nell'ala → grande nel player), quindi niente crossfade fra viste diverse.
Titolo, controlli e barra compaiono con blur+scale sfalsati dopo l'apertura; la chiusura usa
una molla più corta e senza ritardi.

## Click-through e focus

- `IslandPanel`: `NSPanel` borderless + `.nonactivatingPanel`, `canBecomeKey/Main = false`,
  livello `mainMenu + 3`, `canJoinAllSpaces + stationary + fullScreenAuxiliary + ignoresCycle`.
- `ignoresMouseEvents = true` sempre, tranne quando lo stato è `expanded` **e** il puntatore è
  sopra l'isola (o si sta trascinando la barra). Così i margini trasparenti del pannello non
  rubano mai click alla menu bar o alle app sotto.
- L'hover è calcolato geometricamente (rettangolo dell'isola in coordinate schermo) a partire
  da: monitor globale/locale `mouseMoved`/`leftMouseDragged` e da una tracking area
  `.activeAlways` sulla hosting view. I monitor globali di eventi mouse non richiedono permessi
  di Accessibilità.
- `IslandHostingView.acceptsFirstMouse = true`: i pulsanti funzionano al primo click senza
  attivare l'app.

Priorità: trascinamento in corso (mantiene la forma) > `hud` > hover (`expanded`) >
riproduzione (`compact`) > `idle`.

## Fluidità

Durante il morph a ogni fotogramma cambia solo il tracciato della forma e le cornici del
contenuto. Tutto ciò che richiede un filtro costoso è statico o arriva dopo che la molla si è
assestata:

- ombra e alone (`IslandDecoration`) sono copie sfocate del contorno *finale* espanso, inserite
  con ~0,28 s di ritardo e tolte subito in chiusura (prima erano ricalcolate su un contorno che
  cambiava a ogni fotogramma);
- l'ombra colorata della copertina ha un'animazione propria ritardata;
- i controlli Liquid Glass entrano senza blur;
- la copertina è decodificata fuori dal main thread (miniatura ImageIO da 320 px) invece che
  al primo disegno, proprio mentre l'isola si apre.

## HUD luminosità e volume

`MediaKeyTap` (event tap attivo su `NX_SYSDEFINED`, sottotipo 8) intercetta luminosità, volume
e muto; `HUDController` applica il passo (`HUDStep`: 1/16, o 1/64 con Opzione+Maiusc, agganciato
alla griglia) con `DisplayBrightness` (DisplayServices, privato, caricato con `dlopen`) o
`SystemVolume` (CoreAudio) e mostra l'isola in stato `hud`. Se la regolazione non è possibile il
tasto passa al sistema. Serve il permesso di Accessibilità: `AccessibilityPermission` lo chiede
una volta e ascolta `com.apple.accessibility.api` per attivare il tap appena viene concesso
(niente polling). La barra dell'HUD è trascinabile. Preferenza in `Preferences` (UserDefaults).

## Geometria della notch

`NotchGeometry` usa `safeAreaInsets.top` (altezza) e la larghezza di
`auxiliaryTopLeftArea`/`auxiliaryTopRightArea` (larghezza e centro della notch). Senza notch:
notch virtuale 184 pt × altezza menu bar, centrata. Schermo scelto: quello con la notch, altrimenti
il primario. Ricalcolo su `NSApplication.didChangeScreenParametersNotification`.
`IslandLayout` (struct pura, testata) deriva dimensioni e cornici per ogni stato.

## File (tutti piccoli, una responsabilità)

```
Package.swift                         SwiftPM, macOS 26, Swift 6
Support/Info.plist                    LSUIElement, bundle id, versione
scripts/build-adapter.sh              compila MediaRemoteAdapter.framework con clang (niente CMake)
scripts/bundle.sh                     swift build -c release + assemblaggio Halo.app + codesign (ad-hoc o "Halo Local")
Vendor/mediaremote-adapter            submodule git (ungive/mediaremote-adapter, tag v0.7.7, BSD-3)
.github/workflows/build.yml           CI: macos-26 (Xcode 26.6/26.0.1) test + bundle + artifact; xcode-27 build SDK 27
                                      con Xcode e Command Line Tools; blocco macro SwiftUI

Sources/Halo/
  App/          HaloApp (entry point), AppDelegate (composition root), Log, Preferences
  MenuBar/      StatusItemController (menu: stato, HUD, Avvia al login, Esci), LoginItemController (SMAppService)
  System/       DisplayBrightness (DisplayServices), SystemVolume (CoreAudio), MediaKeyTap (CGEventTap),
                AccessibilityPermission
  HUD/          HUDController, HUDModel, HUDStep
  NowPlaying/   NowPlayingSnapshot, PlaybackTimeline, MediaCommand, NowPlayingModel, NowPlayingController
  NowPlaying/Adapter/  AdapterResources, AdapterStream, AdapterCommandRunner, LineSplitter,
                       NowPlayingStreamDecoder, StderrTail
  Artwork/      ArtworkDecoder (ImageIO), RGBColor, ArtworkPalette, PaletteExtractor (Core Image), KMeans,
                PaletteSelector
  Island/       IslandState, NotchGeometry, IslandLayout, IslandViewModel, IslandController,
                ScreenTracker, PointerMonitor, Motion
  Island/Panel/ IslandPanel, IslandHostingView, IslandPanelController
  UI/           IslandRootView, IslandDecoration, IslandContentView, NotchShape (+ NotchOutline, SmoothCorner),
                ArtworkView, SourceIconView, EqualizerView (+ EqualizerWave), TrackInfoView,
                ScrubberView (+ TimeFormatting), TransportControls, PressableButtonStyle,
                RevealModifier, ExpandedBackdrop, EmptyStateView, PlayerActions;
                HUD/ HUDGlyph, HUDLevelBar, HUDValueLabel
Tests/HaloTests/                      Swift Testing: parsing, timeline, geometria, layout, forma, palette, HUD
```

## Flusso dati Now Playing

1. `AdapterResources` trova `Contents/Resources/MediaRemoteAdapter/{mediaremote-adapter.pl,
   MediaRemoteAdapter.framework}` (percorsi assoluti, come richiesto dall'adapter).
2. `AdapterStream` avvia `stream --micros --debounce=40`. Ogni riga `{"type":"data","diff":…,"payload":…}`
   viene applicata allo stato: `diff=false` sostituisce, `diff=true` unisce, `null` rimuove.
   Payload vuoto = nessun player. Artwork base64 decodificato una volta sola per cambio.
3. `NowPlayingController` pubblica lo snapshot sul main actor, decodifica `NSImage`, calcola la
   palette off-main, risolve l'icona dell'app sorgente (`parentApplicationBundleIdentifier`
   quando presente, es. Safari per YouTube).
4. Il tempo trascorso non viene mai "pollato": `PlaybackTimeline` = (elapsed, timestamp, rate)
   ed è valutato solo quando serve disegnare.
5. Comandi: `send 2` (play/pausa), `send 4/5` (avanti/indietro), `seek <µs>`; eseguiti in ordine
   da `AdapterCommandRunner`, con aggiornamento ottimistico dell'interfaccia.
6. Uscita del processo: exit ≠ 0 → adapter "non disponibile" (l'adapter chiede di non
   rilanciarlo); altrimenti riavvio con backoff (max 3 tentativi).

## Estetica

- Corpo nero puro `#000`; orecchie superiori concave (cubica a tensione ridotta, curvatura più
  dolce della circonferenza); angoli inferiori continui stile Apple (algoritmo "corner
  smoothing" di Figma, smoothing 0,6) — nessun raggio semplice.
- Molle: apertura `spring(duration 0.5, bounce 0.24)`, chiusura `spring(0.34, 0.08)`.
- Player: copertina 76 pt con angoli continui e ombra colorata, bagliore radiale interno dei
  colori dominanti (mascherato per lasciare nera la riga della notch), alone esterno leggero,
  SF Pro, barra che si ingrossa all'hover, pulsanti con feedback di pressione e Liquid Glass
  (`glassEffect(.regular.interactive())`) solo sui controlli.
- Accessibilità: *Riduci movimento* → niente rimbalzi/blur/scale, EQ statico, transizioni brevi;
  *Riduci trasparenza* → controlli con fondo pieno al posto del vetro, niente alone esterno.

## Rischi

- **MediaRemote via perl**: soluzione non ufficiale; un aggiornamento di macOS può romperla.
  L'app lo segnala nel menu ("Now Playing non disponibile") invece di fallire in silenzio.
- **Geometria notch**: la larghezza da `auxiliaryTop*Area` può differire di 1–2 pt dall'hardware;
  in `idle` la forma è leggermente più piccola della notch per restare invisibile.
- **Hover su pannello non-key**: basato su monitor + tracking area `.activeAlways`; da verificare
  a mano. `.onHover` della barra di avanzamento dipende dallo stesso meccanismo di SwiftUI.
- **Firma ad-hoc**: `SMAppService` può richiedere approvazione in Impostazioni; l'artifact della CI è
  in quarantena (Gatekeeper) e va sbloccato a mano.
- **Build solo in CI**: nessun Mac nel cloud; tutto ciò che è visivo va verificato in locale.
- **HUD**: DisplayServices è privato; il tap dei tasti richiede Accessibilità, legata alla firma
  (con firma ad-hoc va riconcessa a ogni build: `scripts/bundle.sh` usa il certificato locale
  "Halo Local" se presente).
- **Processo figlio orfano**: se Halo va in crash, perl muore al primo write su pipe chiusa (SIGPIPE),
  non immediatamente.
