# Siri e timer di sistema nella notch — design

Data: 2026-09-28. Stato: approvato in chat, da implementare.

## Obiettivo

1. Quando Siri è aperta, la notch lo mostra con un bagliore animato (come su iPhone).
2. I timer creati con Siri o con l'app Orologio compaiono nella notch come attività live, come il
   timer di Halo.

Fuori dallo scopo: le Live Activity dell'iPhone (macOS le disegna in un processo di sistema come
grafica già pronta, senza testo né API leggibili) e lo spostamento del pannello di Siri, che resta
dove lo mette macOS.

## Cosa è stato verificato su questo Mac (macOS 26)

- **Siri**: quando è aperta, `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` elenca finestre con
  proprietario "Siri" al livello 23 (pannello ~520×265 al centro e una finestra a schermo intero
  mentre ascolta). Il nome del proprietario non richiede la Registrazione schermo. I processi sono
  `com.apple.Siri` (Siri.app in CoreServices) e `com.apple.campo` ("Siri AI"); entrambi
  rispondono all'Accessibilità (`AXUIElementCreateApplication` → `AXApplication`).
- **Timer**: `mobiletimerd` rifiuta i client senza entitlement privato ("not entitled"), e il
  Centro di Controllo non espone la voce Timer della barra dei menu all'Accessibilità. Il log di
  sistema invece riporta tutto in chiaro. Messaggi del processo `ControlCenter`, sottosistema
  `com.apple.mobiletimer.logging`, categoria `Timers`:

  | Evento | Messaggio |
  |---|---|
  | avvio / ripresa | `<id> has next trigger <MTTrigger: 0x…; trigger: Alert; date: "Monday, September 28, 2026 at 5:45:28 PM Central European Summer Time">` |
  | pausa, annullamento, fine | `<MTTimerManager: 0x…> notified next timer changed: (null)` |
  | suonato | `<MTTimerManager: 0x…> notified timer fired: <id>` |

  Pausa e annullamento producono la stessa sequenza, quindi non si distinguono. Il "next timer" è
  quello che scade per primo: con più timer Halo mostra quello.

## Parte 1 — Siri

**`SiriMonitor`** (`Sources/Halo/System/SiriMonitor.swift`, `@MainActor`):

- Un `AXObserver` per ciascuno dei due processi di Siri, su `kAXWindowCreatedNotification` e
  `kAXUIElementDestroyedNotification`. Si ricollega quando i processi si riavviano
  (`NSWorkspace.didLaunchApplicationNotification`).
- A ogni notifica, `isSiriVisible()` controlla nella lista finestre se c'è una finestra a schermo
  con proprietario "Siri" (per PID dei due processi). Finché è visibile ricontrolla ogni 0,5 s,
  perché la notifica di chiusura può mancare.
- Ripiego: se durante l'implementazione l'osservatore non riceve eventi per le finestre di Siri,
  si passa a un controllo della lista finestre ogni secondo (documentato nel codice con un
  commento `ponytail:`).
- Senza Accessibilità usa il ripiego: la lista finestre non richiede permessi.

**Nella notch**: nuovo `IslandAlert.siri`, stile `.wings`. Il monitor, quando Siri si apre, fa
`post(.siri)` e tiene l'avviso con `setInteracting(true, by: "siri")`; quando si chiude,
`setInteracting(false, by: "siri")` e `withdraw(.siri)`. `AlertCenter` non cambia. La vista
`SiriGlowView` disegna un bordo con gradiente angolare nei colori di Apple Intelligence che ruota
lungo la forma dell'isola; con Riduci movimento o effetti ridotti il gradiente è fermo. `.siri`
passa anche quando Halo è in modalità silenziosa (è una risposta a un'azione dell'utente).

## Parte 2 — Timer di sistema

**`SystemTimerLogParser`** (`Sources/Halo/SystemTimer/`, puro, testato): riceve il testo di un
messaggio e restituisce un evento opzionale:

- `.running(id: String, end: Date)` per "has next trigger";
- `.cleared` per "next timer changed: (null)";
- `.fired(id: String)` per "timer fired".

La data si legge con `DateFormatter` in `en_US_POSIX`, formato
`EEEE, MMMM d, yyyy 'at' h:mm:ss a zzzz`, dopo aver sostituito gli spazi speciali (U+202F,
U+00A0) con spazi normali. Testo non riconosciuto → `nil`.

**`SystemTimerMonitor`** (`@MainActor @Observable`): avvia
`/usr/bin/log stream --style ndjson --level default --predicate 'process == "ControlCenter" AND subsystem == "com.apple.mobiletimer.logging"'`,
divide l'output in righe con `LineSplitter`, decodifica `eventMessage` da ogni riga JSON e passa
il testo al parser. Stato: `current: SystemTimer?` (`id`, `end`, `total`). `total` è la durata
vista al primo `.running` di quell'id e resta uguale alle riprese, così l'anello mostra il
progresso reale.

- `.running`: imposta `current`; se l'id è nuovo, `total = end - adesso`.
- `.cleared`: `current = nil`.
- `.fired`: `current = nil` e `post(.timer(TimerAlert(finished: .countdown, next: nil)))`.
- Se `log` termina, riprova dopo 5 s; il terzo errore di fila va nelle diagnostiche e il
  monitor si ferma.
- Un'ora di fine già passata viene ignorata.

**Nella notch**: il timer di sistema diventa un `FocusTimer` in modalità `.countdown`
(`duration = total`, `endDate = end`) e usa il caso esistente `LiveActivity.timer`, dopo il
timer e il cronometro di Halo e prima di `.transfer`: stesso anello e stesso conto alla
rovescia del timer di Halo, nessuna vista nuova.

## Impostazioni

In `SettingsModel` e `Preferences`: "Siri nella notch" (`siriEnabled`) e "Timer di Orologio"
(`systemTimersEnabled`), entrambi attivi di default. Spegnerli ferma il monitor e ritira
l'avviso o l'attività.

## Limiti noti

- Un timer in pausa sparisce dalla notch e ricompare quando riprende.
- Un timer avviato prima dell'apertura di Halo compare solo al suo evento successivo.
- Se Apple cambia i messaggi del log, il timer non compare più (nessun crash) e le diagnostiche
  lo annotano quando `log` fallisce.

## Test

- `SystemTimerLogParserTests`: le righe reali della tabella sopra, la data con U+202F prima di
  "PM", un messaggio sconosciuto → `nil`.
- `SystemTimerMonitor`: la logica degli eventi (id nuovo vs ripresa, `total` conservato) sta in
  una funzione pura testata.
- Siri e l'aspetto grafico: prova manuale sul Mac.

## Parte 3 — Comandare Orologio dalla notch (aggiunta del 2026-09-28)

Verificato su questo Mac: Comandi Rapidi non serve (l'azione "Avvia timer" fallisce con
`WFIntentExecutorErrorDomain 101` anche lanciata dall'app, e i file `.shortcut` generati con
azioni App Intent vengono rifiutati all'importazione). L'app Orologio invece espone la scheda
Timer all'Accessibilità: `TimePicker` (tre `AXSlider` ore/minuti/secondi), `PauseResumeButton`,
`CancelButton`, la lista "Recenti". Orologio esegue i comandi **solo quando è l'app attiva**:
premere o impostare valori con l'app in secondo piano restituisce successo ma non fa nulla.
Con Orologio attivo per un istante: focus sul cursore dei minuti + cifre digitate
(`CGEvent`) impostano la durata (verificato 00:04:00 → 00:10:00); `AXPress` su
`PauseResumeButton` avvia, mette in pausa e riprende; su `CancelButton` annulla. Tempo con
Orologio in primo piano: ~0,4 s per un pulsante, ~1,2 s per un avvio.

**`ClockAppDriver`** (`@MainActor`): `start(minutes:)`, `togglePause()`, `cancel()`, ognuno
`async -> Bool`, eseguiti uno alla volta. Ogni comando: Accessibilità concessa, Orologio aperto
(se chiuso lo apre nascosto, senza attivarlo), finestra spostata fuori schermo, Orologio
attivato, scheda Timer selezionata (l'ultimo segmento della barra, non per nome: il nome
dipende dalla lingua), azione, focus restituito all'app di prima, Orologio nascosto. Se un
elemento manca il comando fallisce e lo scrive nelle diagnostiche.

**Quale app per i timer della notch** (Impostazioni › Attività, riga di scelta "Halo /
Orologio", default Orologio): con Orologio, i preset della notch e del menu (1, 5, 10, 15,
25 min) avviano un timer di Orologio; se il comando fallisce parte il timer di Halo. Pomodoro e
cronometro restano sempre di Halo. La scelta conta solo con "Timer di Siri e Orologio" attivo.

**Pausa visibile**: `SystemTimer` ha `pausedRemaining`; una pausa chiesta dalla notch mette il
timer in pausa subito (ali ferme e più tenui) e il `.cleared` che segue nel log non lo
cancella. Una pausa fatta dall'app Orologio lo fa sparire, come prima.

**Controlli**: la scheda Timer mostra il timer di Orologio come quello di Halo, con
Pausa/Riprendi e Ferma (senza "+1 minuto"); valgono anche per i timer di Siri. Il menu Timer
di Halo fa lo stesso. Aprendo l'isola con il puntatore sull'ala destra mentre c'è un timer
(di Halo o di Orologio), l'isola si apre sulla scheda Timer invece che sulla musica.

**Limiti**: a ogni comando Orologio compare per un istante; durante un avvio Halo digita le
cifre, quindi un tasto premuto in quel momento può finire altrove. Un timer messo in pausa
dalla notch e poi annullato dall'app Orologio resta in pausa nella notch finché non lo fermi.

**Aggiornamento dopo la verifica**: Orologio ignora i clic solo quando è *nascosto*, non
quando è in secondo piano. Pausa, ripresa, annullamento e avvio dai "Recenti" avvengono quindi
senza attivare Orologio: la finestra viene spinta nell'angolo in basso a sinistra (ne restano
visibili circa 40 × 110 punti) e il focus non si sposta. Solo l'avvio di una durata che non è
nei Recenti attiva Orologio con la finestra sullo schermo (circa un secondo), perché le cifre
arrivano solo a una finestra attiva e visibile.
