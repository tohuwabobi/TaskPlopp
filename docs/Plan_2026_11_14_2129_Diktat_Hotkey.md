# Globaler Diktat-Hotkey Strg+NumPad1 - P+

Stand 14.11.2026, Basis be43772. Tobias hat P+ und anschliessend bedingtes X+
erteilt: Nach unabhaengiger Planfreigabe TaskPlopp beenden und direkt umsetzen.
Bis Reviewfreigabe nur diese Plan-Datei schreiben.

## Ziel / Bedienung
Strg+NumPad0 (bzw. bisherige individuelle Belegung) oeffnet TaskPlopp unveraendert.
Zusaetzlich Strg+NumPad1, separat konfigurierbar: Start bringt TaskPlopp zu Tasks
nach vorne und startet lokales Diktat mit sichtbarer Statusleiste/Mikrofonpegel.
Erneuter Druck waehrend dieses Diktats fordert Stopp und anschliessende bestehende
Transkription an. Stopp und Ergebnis holen kein Fenster nach vorne und wechseln
keinen Fokus. Kein automatisches Zurueckspringen, Einfuegen oder Senden.

## Discovery
Bestehender New-TaskPloppHotkeyListener registriert einen Hotkey je kleinem
Runspace/Thread mit MOD_NOREPEAT und signalisiert einen EventWaitHandle.
Readonly-/RAM-Probe: Strg+NumPad1 auf ARKANIS registriert und wieder freigegeben;
zwei unveraenderte Listener mit getrennten Events routinggetreu synthetisch
angesprochen. Kein Mikrofon oder App-Fokus dabei. Weitere RAM-Probe bestaetigt:
vorhandenes Invoke-TaskPloppDictation kann Ready -> Recording -> Stopanforderung;
Transcribing startet nicht erneut, Layout-Zweck wird nicht gestoppt.

## KISS-Entscheidung
Vorhandenen Listener zweimal verwenden: Oeffnen und Diktat, feste zwei Aktionen.
Damit genau ein zusaetzlicher kleiner Listener-Runspace; kein neues Thread-/Queue-
Framework, kein Umbau auf WndProc/C#, keine Kommandoverwaltung in einem Listener.
New-TaskPloppHotkeyListener bekommt einen optionalen expliziten Signal-Parameter;
Standard bleibt WakeEvent fuer bisherige Aufrufer/Tests. Diktat verwendet eigenen
unnamed AutoReset-Event. Bestehender benannter WakeEvent bleibt Singleton/Oeffnen.
Beide Events im vorhandenen 150-ms-GUI-Timer konsumieren; nur GUI-Thread bedient
Aufnahme und Controls. Kein weiterer GUI-Timer, keine parallele zweite Aufnahme.
MOD_NOREPEAT verhindert Autorepeat; wie bisher koennen extrem schnelle mehrfache
Druecke innerhalb eines GUI-Ticks in AutoReset-Signalen zusammenfallen. Kein neues
Ereignisprotokoll fuer solche nicht zugesagte Eingabegeschwindigkeit.

## Settings / Konfiguration
- Zwei neue Felder DictationHotkeyModifiers=2 und DictationHotkeyKey=NumPad1.
  Alte Konfigurationen/ZIPs erhalten nur diese fehlenden Defaults, bestehende
  Oeffnen-/Diktat-Belegungen bleiben erhalten. Bekannte Transferfelder ergaenzen.
- Wertepruefung wie vorhandener Oeffnen-Hotkey (einschl. F12-/Modifier-Regeln).
  Kein zweites unabhaengiges Tastennamenformat. Gleiche native VK+Modifier erkennen,
  auch bei Aliasen. Keine neue ZIP-Version, Schluessel oder Dateipfade.
- Konfigurationstab Tastenkombination: zwei klar benannte Aktionen mit aktuellem
  Wert und je Aufnahme-Button. Ein gemeinsames Aufnahmefeld/Timer und bestehende
  Tastenaufnahme; nur feste Zielaktion im bestehenden captureState merken.
  Aufnahme prueft/aktiviert/speichert sofort, Escape bricht ab. Kein Save-Button.
- Diktat-Hotkey waehrend ConfigurationOpen oder offenem TransferDialog konsumieren,
  ohne Aufnahme, Fokuswechsel oder Ueberschreiben der jeweiligen Dialogmeldung.
  Damit kann das Druecken des bereits belegten Diktat-Hotkeys bei der Aufnahme der
  Konfiguration kein Mikrofon starten. Kein allgemeiner Modal-/Fenster-Tracker.

## Registrierung / Konflikte ohne neue Zustandsverwaltung
- Feste Listener/ActiveSpec-Felder je Aktion, vorhandene Dispose-Funktion nutzen.
  Beim Start beide unabhaengig versuchen. Belegung einer Kombination darf den
  anderen funktionierenden Hotkey nicht abschalten. Richtige Aktion im bestehenden
  StartupNotice/Status nennen; keine Popupmeldung und kein stiller Ersatzhotkey.
- Alte Oeffnen-Belegung koennte schon Strg+NumPad1 sein. Migration darf deshalb
  nicht die gesamte Konfiguration als ungueltig verwerfen. Beim Start zuerst
  Oeffnen registrieren, Diktat-Konflikt melden; Mic-Button bleibt nutzbar.
- Beim Speichern nur wirklich gegen gespeicherte Settings geaenderte native
  Kombinationen neu registrieren. Ungeaenderter, momentan nicht registrierter
  Hotkey darf normale Favoriten-/Audio-/sonstige Configspeicherung nicht blockieren.
- Werden Hotkeywerte geaendert, sind gleiche native Kombinationen fuer beide Aktionen
  unzulaessig. Bestehender Legacy-Defaultkonflikt darf ohne Hotkeyaenderung les- und
  speicherbar bleiben, damit Nutzer andere Einstellungen weiter bearbeiten kann.
- Alle geaenderten neuen Listener zuerst probeweise registrieren; scheitert einer,
  alle neuen Kandidaten freigeben, bisherige Listener und Datei erhalten. Erst
  nach Save-Settings-Erfolg Kandidaten uebernehmen und alte Listener freigeben.
  Ungeaenderte Listener weiterverwenden. Bei Schreibfehler alle Kandidaten weg.
- Direktes gegenseitiges Tauschen zweier noch belegter Kombinationen wird mit
  Konflikthinweis abgewiesen; bei Bedarf zuerst temporaere andere Kombination
  konfigurieren. Kein automatischer Swap-/Rollback-Dispatcher oder Retry-Framework.
- Shutdown beide Listener sauber freigeben, danach Events entsorgen. Keine
  produktiven Belegungen fuer Tests veraendern. Traytext bleibt unter Windows-Limit;
  Aufnahme-/Transkriptionszustand weiterhin anzeigen, keine langen kombinierten
  Hotkeylabels unbesehen in NotifyIcon.Text schreiben.

## Diktat-Dispatch / Fokus
Nur kleiner Wrapper um bestehenden Diktatweg, keine zweite Recorderimplementierung:
1. Offene eigene Konfiguration/Transfer: keine Aktion (siehe oben).
2. Laufender LayoutJob, Diktat-Installer oder DictationPurpose=Layout mit Phase
   ungleich Ready: keine Aktion, kein Fokuswechsel, laufende Status-/Wellenanzeige
   bleibt erhalten. Nicht einfach den bestehenden Busy-Hinweis ueber eine laufende
   Aufnahme legen, denn Set-TaskPloppMessage wuerde deren Activity zuruecksetzen.
3. Ready und nicht beschaeftigt: zuerst Show-TaskPlopp, damit auch ein Startfehler
   sichtbar wird; dann Invoke-TaskPloppDictation fuer normalen Dictation-Zweck.
   Falls Engine/Mikrofon fehlt, rote bestehende Fehlermeldung im sichtbaren Fenster.
4. Recording mit Purpose=Dictation: ausschliesslich bestehenden Stopweg aufrufen,
   kein Show/Activate, kein Minimieren/Positionswechsel. Wiederholter Druck nach
   schon gestellter Stopanforderung darf Recorder nicht neu starten/Watch resetten.
5. Transcribing: nichts starten/stoppen, nicht fokussieren; bestehende Anzeige bleibt.
   Fertigstellung verwendet unveraenderten Clipboard-/Fehlerweg, ohne Show/Activate.
Bei gleichzeitig anstehenden Oeffnen- und Diktatsignalen hat die ausdrueckliche
Oeffnen-Aktion ihre normale Bedeutung; "kein Fokuswechsel bei Stopp" gilt fuer den
Diktat-Hotkey allein, nicht fuer einen separat gleichzeitig gedrueckten Oeffnen-Hotkey.

## Scope
src/TaskPlopp.Hotkey.ps1: Spec je Aktion, Signalparameter, Registrierung/Save/Cleanup,
kleiner Diktat-Dispatchwrapper (oder in Dictation.ps1, wenn dort kuerzer).
src/TaskPlopp.ps1: zweiter Event, Initialisierung, GUI-Dispatch, Cleanup.
src/TaskPlopp.Apps.ps1: Defaults/validierte Hotkeypaare.
src/TaskPlopp.Configuration.ps1: zwei Aktionszeilen, gemeinsame Aufnahme.
src/TaskPlopp.Transfer.ps1: neue Feldnamen, bestehender Import-/Saveweg.
src/TaskPlopp.Dictation.ps1 nur bei notwendigem Wrapper, keine Audiopipeline aendern.
src/TaskPlopp.Audio.ps1: kurze Ergaenzung der vorhandenen Hilfe, bestehende Fettschrift
und Texte erhalten. data/config.example.json und README.md aktualisieren.
Bestehende Hotkey-/DictationUi-/Transfer-Tests erweitern, ggf. eigener schmaler
Test-TaskPloppDictationHotkey.ps1. Verifier unter docs. Keine produktive Config/Keys.

## Verifier / Abnahme
- PS5.1-Defaults/Altkonfig/ZIP-Roundtrip, explizite alte Belegungen erhalten.
- Reale freie Testregistrierungen und synthetische WM_HOTKEY getrennt an beide
  Events; kein versehentliches Oeffnen bei Diktat und umgekehrt. Freigabe nach Dispose.
- Externer Konflikt, interner Doppelbelegung/Alias, fehlgeschlagenes Save und beide
  gleichzeitig geaendert: alte Datei/Listener erhalten, kein Kandidaten-Leak.
  Ein Start-Hotkey darf ausfallen, anderer bleibt nutzbar. Unregistrierter unveraenderter
  Hotkey blockiert keine sachfremde Aenderung. Alter Oeffnen=Strg+NumPad1 als Legacyfall.
- Zwei Tastenaufnahmen mit eigenem Ziel, Vorschau, Abbruch, Sofortspeichern/Neuladen;
  Diktat-Signal bei offenem Dialog startet nichts. ConfigUi-Layout mit grosser Schrift.
- Speicherbasierte Recorder-/Engine-Fakes fuer Ready, Recording, Stop pending,
  Transcribing, Layout-Aufnahme, Layout-Worker, Installer, fehlende Engine/Fehler.
  Kein echter Mikrofon-/API-Test erforderlich. Start genau einmal, Stopp genau einmal.
- Fokus-Spy fuer Show/Activate sowie eigene UI: Start bringt Tasks samt gruener
  Aufnahme-/Pegelanzeige nach vorne; Stopp und Ergebnis benutzen keinen Show-/Activate-
  Aufruf. Echte externe Test-GUI darf beim Stopp/Ergebnis aktiv bleiben. Kein
  Verschieben echter Nutzerfenster. Mic-Button/Diktat-/Layout-/Statusregressionen.
- Native-Quellcodeaudit (kein eigener C#/Compiler), Hotkey, DictationUi, Autosave,
  Transfer und Layout/Help unter PS5.1. CRLF/PS1-BOM, keine neuen Farben/Popups/Pakete.
- Manueller spaeterer Test: echter Strg+NumPad1-Druck, Aufnahme sichtbar, zu fremder App
  wechseln, erneut stoppen, Text einfuegen. NumLock an/aus und Citrix-Vollbild pruefen.
  Isolierte Registrierung ist kein Beleg fuer echte Tastatur-/Citrix-Zustellung.

## P+-Review / anschliessende Ausfuehrung
Review freigegeben durch unabhaengigen dictation_hotkey_review; keine Planblocker.
Zusaetzlicher Nachweis: Importkonflikt mit aktiven Listenern testen. Keine Tests/App-Aktionen
im Review. Nach Freigabe dieses Plans gilt Tobias' bereits erteiltes
bedingtes X+: TaskPlopp beenden, eng umsetzen, testen, dokumentieren, eigenpruefen,
committen/pushen und auf ARKANIS wieder starten. Keine erneute Freigabefrage.

Ausgefuehrt nach bedingtem X+: TaskPlopp vor Umsetzung beendet. Implementierung
und gezielte Tests abgeschlossen; Details und verbleibende manuelle Fokus-/Citrix-
Abnahme in Verifier_2026_11_14_Diktat_Hotkey.md. Ein Layout-Regressionstest ist an
seiner Windows-Fokusvoraussetzung blockiert, nicht als bestanden gewertet.
