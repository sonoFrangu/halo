# Halo

App macOS personale che trasforma la notch del MacBook in una "Dynamic Island": un'isola nera
che cresce dalla notch fisica e mostra cosa stai ascoltando, da qualsiasi app (Spotify, Musica,
Safari/YouTube, …), e sostituisce l'HUD di sistema di luminosità e volume.

Stato: shell della notch + Now Playing + HUD luminosità/volume. Architettura e scelte in
[`docs/design.md`](docs/design.md).

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

### Firma stabile (consigliata per l'HUD)

macOS lega il permesso di Accessibilità alla firma dell'app. Con la firma ad-hoc la firma
cambia a ogni build, quindi dopo ogni `scripts/bundle.sh` il permesso va rimosso e concesso di
nuovo. Per evitarlo, una volta sola:

1. Accesso Portachiavi › Assistente Certificato › Crea un certificato…
2. Nome **`Halo Local`**, Tipo di identità **Radice autofirmata**, Tipo di certificato
   **Firma codice** › Crea.

Da quel momento `scripts/bundle.sh` firma con `Halo Local` (lo stampa a video) e il permesso
sopravvive alle ricompilazioni. `HALO_SIGN_IDENTITY="Altro nome" scripts/bundle.sh` forza
un'altra identità.

Test unitari (parsing dello stream, timeline, geometria, forma, palette, passi dell'HUD):
`swift test` (richiede Xcode per Swift Testing).

La CI (`.github/workflows/build.yml`, runner `macos-26`) esegue test e bundle a ogni push e
carica `Halo.zip` come artifact. Se il runner `macos-26` non fosse disponibile, lancia il
workflow a mano (*Run workflow*) scegliendo `macos-latest`.

## Lanciare

```sh
open build/Halo.app
```

Oppure copia `build/Halo.app` in `/Applications` (consigliato se attivi "Avvia al login": il
login item punta al percorso dell'app). Halo compare solo nella barra dei menu (icona a
capsula): il menu mostra lo stato di Now Playing, **HUD luminosità e volume nella notch**,
**Avvia al login** ed **Esci**.

Se usi lo zip scaricato dalla CI, macOS lo mette in quarantena (firma ad-hoc, non
notarizzata). Sbloccalo una volta:

```sh
xattr -dr com.apple.quarantine /Applications/Halo.app
```

## Risoluzione problemi

- **`Undefined symbols … PackageDescription.Package.__allocating_init(… SwiftVersion …)`**
  (o `reference to member 'v26' cannot be resolved`) anche su un progetto vuoto creato con
  `swift package init`: i Command Line Tools sono incoerenti (resti di una versione precedente).
  Reinstallali: `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.
- **`plugin for module 'SwiftUIMacros' not found`**: codice con macro SwiftUI compilato con i
  soli Command Line Tools sull'SDK di macOS 27 (vedi Requisiti). Usa Xcode o evita la macro.
- Le prime righe di `scripts/bundle.sh` stampano toolchain, versione di Swift e SDK in uso.

## Permessi richiesti

- **Accessibilità** (solo per l'HUD di luminosità e volume): per sostituire l'HUD di sistema
  Halo intercetta i tasti luminosità/volume/muto con un event tap, e macOS lo consente solo alle
  app autorizzate in Impostazioni › Privacy e sicurezza › Accessibilità. Al primo avvio compare
  la richiesta; poi è raggiungibile dal menu ("Concedi Accessibilità per l'HUD…"). Senza
  permesso, o con l'HUD disattivato dal menu, i tasti funzionano come sempre con l'HUD di
  sistema. Con la firma ad-hoc il permesso va riconcesso dopo ogni build: vedi *Firma stabile*.
- **Nessuna Registrazione schermo né Monitoraggio input.** L'hover usa monitor di eventi
  *mouse* (`NSEvent`), che non richiedono autorizzazioni.
- **Elementi di login**: attivando "Avvia al login" macOS può chiedere conferma in
  Impostazioni di Sistema › Generali › Elementi login; Halo apre quella pagina se serve.
- **Now Playing**: nessun prompt. Halo avvia `/usr/bin/perl` con
  [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter): perl è un binario di
  sistema ancora autorizzato a usare il framework privato MediaRemote (bloccato per le app di
  terzi da macOS 15.4).

## HUD luminosità e volume

- I tasti luminosità (F1/F2), volume (F11/F12) e muto (F10) mostrano l'isola in modalità HUD:
  a sinistra l'icona (il sole ruota con la luminosità; per il volume compaiono AirPods, AirPods
  Pro/Max o cuffie quando sono l'uscita attiva), a destra una barra con bagliore proporzionale
  al livello e la percentuale.
- **Regolazione personalizzata**: la barra si trascina con il mouse; Opzione+Maiusc con i tasti
  fa passi fini da 1/64 come in macOS. La luminosità è caldo-solare, il volume prende i colori
  della copertina in riproduzione.
- Luminosità tramite il framework privato DisplayServices (solo display integrato), volume
  tramite CoreAudio sul dispositivo di uscita predefinito. Se una delle due non è regolabile
  (es. uscita HDMI senza volume), il tasto passa al sistema.

## Come funziona (in breve)

- **Isola**: `NSPanel` borderless non-attivante sopra la menu bar, su tutti gli Spazi e sopra
  le app a schermo intero. Tre stati — `idle` (nascosta nella notch), `compact` (musica in
  riproduzione: mini copertina a sinistra, EQ a destra), `expanded` (hover: player completo) —
  resi da **una sola forma animabile** nera che morfa con molle.
- **Click-through**: il pannello ignora il mouse tranne quando l'isola è espansa *sotto il
  puntatore*; non ruba mai focus né click alla menu bar o alle app sotto.
- **Zero polling**: stream JSON dell'adapter, notifiche di sistema, eventi mouse e Observation.
  EQ e barra di avanzamento animano solo quando visibili e in riproduzione.
- **Estetica**: nero puro `#000`, orecchie superiori concave, angoli inferiori continui
  (corner smoothing stile Apple), bagliore dai colori dominanti della copertina (Core Image +
  k-means), Liquid Glass solo sui controlli, SF Pro.
- **Accessibilità**: rispetta *Riduci movimento* (niente rimbalzi/blur/scale, EQ statico) e
  *Riduci trasparenza* (controlli pieni al posto del vetro, niente alone esterno).

## Limiti noti

- **Now Playing dipende da un workaround non ufficiale.** Un aggiornamento di macOS può
  romperlo; in quel caso il menu e l'isola espansa mostrano "Now Playing non disponibile" con il
  motivo. Se l'adapter termina con errore Halo non lo rilancia (come raccomandato dall'adapter):
  serve riavviare Halo.
- **L'EQ non legge l'audio.** È un'animazione sintetica che parte solo quando il player dichiara
  di essere in riproduzione; livelli reali richiederebbero permessi di cattura audio.
- **Artwork**: alcune app (spesso i browser) non forniscono la copertina o la forniscono in
  ritardo; al suo posto c'è un segnaposto con i colori neutri.
- **Titoli lunghi** vengono troncati con "…" (niente scorrimento marquee, per ora).
- **Contenuti live** (senza durata) mostrano la barra vuota e `--:--`; il seek è disattivato.
- **Le ali coprono la menu bar**: in `compact` le ali nere stanno sopra gli elementi della menu
  bar adiacenti alla notch. I click li raggiungono comunque (il pannello è click-through), ma
  passarci sopra con il puntatore apre il player dopo ~90 ms.
- **Un solo schermo**: l'isola sta sul display con la notch o, in assenza, sul display
  principale; non segue il monitor attivo.
- **Stato "pausa"**: dopo ~1,5 s di pausa l'isola torna `idle`; in pausa resta raggiungibile
  con l'hover (player completo).
- **HUD**: niente suono di feedback del volume (il tasto non arriva al sistema); luminosità solo
  del display integrato (non dei monitor esterni); niente tasti retroilluminazione tastiera
  (il MacBook Air M2 non li ha).
- **Solo arm64**: `scripts/build-adapter.sh` compila l'adapter per l'architettura della
  macchina che builda.
- **Build verificata solo in CI.** Lo sviluppo è avvenuto senza un Mac: tutto ciò che è visivo
  (forma, allineamento alla notch, animazioni, vetro, hover) va verificato a mano — vedi la
  descrizione della PR.

## Struttura

```
Sources/Halo/
  App/          entry point, AppDelegate, log
  MenuBar/      NSStatusItem, SMAppService
  NowPlaying/   modello, controller, timeline; Adapter/ processi perl, parsing dello stream
  Artwork/      palette (Core Image + k-means)
  Island/       geometria notch, layout, stati, hover, schermi; Panel/ NSPanel + hosting
  UI/           forma, viste SwiftUI del player
Tests/HaloTests Swift Testing
scripts/        bundle.sh, build-adapter.sh
Vendor/         mediaremote-adapter (submodule)
```

## Licenze di terze parti

[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) © 2025 Jonas van den
Berg e contributori, licenza BSD 3-Clause. Il testo della licenza è incluso in
`Halo.app/Contents/Resources/MediaRemoteAdapter/LICENSE` e nel submodule.
