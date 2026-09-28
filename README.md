# Halo

App macOS personale che trasforma la notch del MacBook in una "Dynamic Island": un'isola nera
che cresce dalla notch fisica e mostra cosa stai ascoltando, da qualsiasi app (Spotify, Musica,
Safari/YouTube, …).

Stato: **MVP** — shell della notch + Now Playing. Architettura e scelte in
[`docs/design.md`](docs/design.md).

## Requisiti

- Mac Apple Silicon con macOS 26 o successivo (sviluppata per MacBook Air M2 con macOS 27).
- Per compilare: Xcode 26+ (o i Command Line Tools con Swift 6.2+). Niente CMake, niente
  progetto Xcode: solo Swift Package Manager e `clang`.

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
4. firma tutto ad-hoc (`codesign -s -`) e verifica la firma.

Test unitari (parsing dello stream, timeline, geometria, forma, palette): `swift test`.

La CI (`.github/workflows/build.yml`, runner `macos-26`) esegue test e bundle a ogni push e
carica `Halo.zip` come artifact. Se il runner `macos-26` non fosse disponibile, lancia il
workflow a mano (*Run workflow*) scegliendo `macos-latest`.

## Lanciare

```sh
open build/Halo.app
```

Oppure copia `build/Halo.app` in `/Applications` (consigliato se attivi "Avvia al login": il
login item punta al percorso dell'app). Halo compare solo nella barra dei menu (icona a
capsula): il menu mostra lo stato di Now Playing, **Avvia al login** ed **Esci**.

Se usi lo zip scaricato dalla CI, macOS lo mette in quarantena (firma ad-hoc, non
notarizzata). Sbloccalo una volta:

```sh
xattr -dr com.apple.quarantine /Applications/Halo.app
```

## Permessi richiesti

- **Nessun permesso di Accessibilità, Registrazione schermo o Monitoraggio input.** L'hover
  usa monitor di eventi *mouse* (`NSEvent`), che non richiedono autorizzazioni.
- **Elementi di login**: attivando "Avvia al login" macOS può chiedere conferma in
  Impostazioni di Sistema › Generali › Elementi login; Halo apre quella pagina se serve.
- **Now Playing**: nessun prompt. Halo avvia `/usr/bin/perl` con
  [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter): perl è un binario di
  sistema ancora autorizzato a usare il framework privato MediaRemote (bloccato per le app di
  terzi da macOS 15.4).

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
