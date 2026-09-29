# Notifiche per app — design

## Obiettivo

Oggi le notifiche nella notch hanno un solo interruttore ("Notifiche nella notch") più
"Silenzia durante una Full Immersione", e i siti web sono sempre esclusi. L'utente vuole
decidere **app per app** se una notifica compare e in che modo.

Per ogni app:

- **Modalità**: *Mostra* (come oggi), *Solo app* (icona e nome, niente testo né miniatura),
  *Non mostrare*.
- **Anche con Full Immersione**: l'app passa anche quando "Silenzia durante una Full
  Immersione" zittirebbe le notifiche.

Fuori ambito: durata del banner per app, regole per gli altri avvisi di Halo (ricarica,
AirPods, tastiera…), campo di ricerca nell'elenco (si aggiunge se l'elenco risulta troppo lungo).

## Dati

In `Preferences`, due chiavi nuove:

- `notificationAppModes: [String: String]` — bundle id → `"hidden"` o `"appOnly"`. Un'app
  assente vale *Mostra*: le app nuove partono da lì e la preferenza resta piccola.
- `notificationFocusBypass: [String]` — bundle id delle app che passano durante una Full
  Immersione.

Tipo nuovo in `Notifications/`:

```swift
enum NotificationAppMode: String { case show, appOnly, hidden }
```

## Decisione

Una funzione pura, in `Notifications/`, decide cosa fare di una notifica:

- input: bundle id, modalità dell'app, se la Full Immersione sta silenziando, se l'app è in
  `notificationFocusBypass`;
- output: *scarta*, *mostra intera*, *mostra solo app*.

Regole, in ordine:

1. Siti web (`_WEB_CENTER_…`) e Halo stessa: scarta (come oggi).
2. Modalità *Non mostrare*: scarta.
3. Full Immersione che silenzia e app non in bypass: scarta.
4. Modalità *Solo app*: mostra solo app.
5. Altrimenti: mostra intera.

## Dove si applica

- `NotificationMirror.databaseChanged()`: il controllo `isSuppressed()` sull'intero lotto
  sparisce; la decisione si prende notifica per notifica. `lastID` avanza comunque, così le
  notifiche scartate non ricompaiono più tardi.
- `AppDelegate`: `isSuppressed` diventa `isFocusSilencing` (`Preferences.notificationsFollowFocus
  && focus?.active != nil`); il bypass lo legge la funzione di decisione dalle preferenze.
- *Solo app*: `NotificationText.make(title: nil, subtitle: nil, body: nil, appName:)` (dà solo il
  nome dell'app) e `imageURL = nil`, quindi nessuna miniatura. Il clic apre l'app come oggi.

## Elenco delle app

- `NotificationDatabase.appIdentifiers()`: `SELECT identifier FROM app`.
- Filtro: solo identificativi con un'app installata
  (`NSWorkspace.urlForApplication(withBundleIdentifier:)`), niente siti web né Halo.
  Ordinati per nome (`AppName.of`).
- Letto all'apertura della pagina Avvisi (e quando la finestra torna in primo piano, con il
  `revision` già esistente). Senza Accesso completo al disco l'elenco è vuoto e il gruppo mostra
  il pulsante "Concedi…" come le altre righe che richiedono quel permesso.
- Un errore di lettura del database lascia l'elenco vuoto e scrive nel log, come le altre query.

## Impostazioni

- Pagina **Avvisi**, gruppo nuovo "Notifiche per app" subito dopo "Notifiche e Full
  Immersione", disattivato se "Notifiche nella notch" è spento.
- Nuovo `SettingsItem.Kind.notificationApps`, reso in `SettingsView` da una riga su misura (come
  `timerApp`).
- Per ogni app: icona (`NSWorkspace.icon(forFile:)`), nome, `Picker` a menu
  Mostra / Solo app / Non mostrare, e — solo se "Silenzia durante una Full Immersione" è
  acceso — un interruttore con la luna "Anche con Full Immersione".

## Test

- `NotificationRulesTests`: la funzione di decisione su tutte le combinazioni di modalità,
  Full Immersione e bypass, più siti web e Halo.
- Il test esistente sul filtro dei siti web resta.
- L'interfaccia (elenco, icone, menu) va verificata a mano.

## Limiti

- La Full Immersione vista da Halo è solo quella attivata a mano (limite già noto): il bypass
  vale solo lì.
- Il banner di sistema di macOS compare comunque: le regole valgono solo per la notch.
