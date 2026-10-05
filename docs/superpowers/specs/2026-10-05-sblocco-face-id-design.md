# Sblocco in stile Face ID — design

## Obiettivo

Allo sblocco del Mac l'isola può mostrare, al posto del lucchetto nelle ali, la sequenza di
Face ID di Glance in un pannello sotto la notch: angoli del volto che si uniscono → cerchio →
anelli che ruotano → spunta. Si sceglie nelle
Impostazioni ("Lucchetto" o "Face ID"); nessun riconoscimento del volto.

## Riferimento: Glance 1.2 (`com.jonathan.glance`)

Ricavato con REA + Hopper (decompilato) e dai metadati Swift (`__swift5_fieldmd`):

- `UnlockAnimationStyle`: `none | minimal | original`. `minimal` è un lucchetto che si apre nella
  notch; `original` è la sequenza Face ID.
- `ScanAnimationHostView` (`sub_100027ac0`): `idle` mostra un'immagine fissa; `success` e
  `failure` riproducono `unlockanimation.mp4` (1,22 s) e `unsuccessfulunlockanimation.mp4`
  (1,52 s) con un `AVPlayer` muto, fermo sull'ultimo fotogramma.
- Fine scansione (`sub_10001b360`): la notch resta aperta 1,7 s dopo il successo, 5 s dopo il
  fallimento, 0,4 s se l'animazione è spenta, poi si chiude.

Halo non copia video né altri file di Glance: la sequenza è disegnata in SwiftUI.

## Comportamento

- `UnlockAnimationStyle { padlock, faceID }` in `UnlockGreeter.swift`;
  `Preferences.unlockAnimationStyle`, predefinito `.faceID`. L'avviso porta lo stile:
  `IslandAlert.unlock(UnlockAnimationStyle)`.
- Lucchetto: stile d'avviso `.wings`, com'era. Face ID: nuovo stile `.glyph`, un pannello quadrato
  sotto la notch (`IslandLayout.glyphFrame`, glifo da 64 pt).
- `FaceIDUnlockGlyph`: `Canvas` guidato da `KeyframeAnimator` avviato da `isVisible` (le macro
  SwiftUI come `@State` sono vietate dalla CI). Geometria misurata sul video di Glance (spazio da
  432 px, tratto 23, colore 0,2/0,6/0,99). Tempi, come il video:
  - 0–0,14 s gli angoli si allungano fino a unirsi; 0,05–0,21 s occhi, naso e bocca svaniscono;
  - 0,08–0,26 s il quadrato arrotondato diventa un cerchio;
  - 0,22–0,72 s due anelli proiettati in 3D ruotano con scie sfocate, poi si appiattiscono;
  - 0,77–0,95 s la spunta nasce da un punto; resta ferma fino alla chiusura.
  - Con Riduci movimento: dissolvenza dal volto alla spunta.
- `IslandAlert.unlock.duration`: 1300 → 1700 ms, l'attesa di successo di Glance.
- Impostazioni › Avvisi: riga "Animazione di sblocco" con selettore segmentato
  "Lucchetto | Face ID" sotto il toggle "Sblocco", disattivata se il toggle è spento (stesso
  schema di `TimerAppRow`).
- README e `docs/design.md` aggiornati.

## Fuori ambito

Animazione di fallimento (Halo non sa quando sbagli la password), glifo in attesa sul lock
screen, riconoscimento del volto.

## Verifica

`swift build`, `swift test`, controllo macro della CI; prova a mano con entrambi gli stili
(⌃⌘Q, poi sblocco).
