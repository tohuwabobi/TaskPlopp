# Verifier: globaler Diktat-Hotkey

Stand: 14.11.2026, ARKANIS, Windows PowerShell 5.1 STA.
Plan: Plan_2026_11_14_2129_Diktat_Hotkey.md, unabhaengig freigegeben.

## Ergebnis
- Zusaetzlich zu Oeffnen (Standard Strg+NumPad0) startet/stoppt Diktat
  standardmaessig Strg+NumPad1. Beide Aktionen separat per Tastenaufnahme
  konfigurierbar, sofort gespeichert und in Sicherung/Import enthalten.
- Start ruft die vorhandene Tasks-Ansicht auf, dann die Aufnahme. Stopp und
  Ergebnisverarbeitung enthalten keinen neuen Fokus-/Fensteraufruf.
- Transkription, Layout, Installation und offene Konfigurations-/Transferdialoge
  ignorieren den Diktat-Hotkey. Bestehende Aktivitaetsanzeige bleibt bestehen.
- Bestehende Belegungen erhalten; Legacy-Oeffnen=Strg+NumPad1 laedt weiterhin.
  Bei dessen Konflikt bleibt Oeffnen aktiv, Diktat meldet die fehlende Registrierung.
- Nur PowerShell, bestehende WinForms/ABI-Deklarationen. Keine Pakete, Popups,
  Farben, API-Aufrufe, echte Mikrofonaufnahme oder Aenderung der Nutzer-Zwischenablage.

## Erfolgreich automatisiert
- Test-TaskPloppHotkey.ps1: vorhandene Registrierung/Freigabe, Capture fuer beide
  Aktionen, Vorschau, Abbruch, Sofortspeichern, Doppelbelegung, Fehlerbehandlung,
  keine Aufnahme aus Konfiguration; wartendes Signal beim Schliessen verworfen.
- Test-TaskPloppDictationHotkey.ps1: zwei echte getrennte Registrierungen und Events,
  Konflikt-Rollback beider geaenderter Aktionen, Importkonflikt mit aktiven Listenern,
  Schreibfehler und Freigabe von Kandidaten, Alias-Duplikate, Legacy-Kollision,
  unabhaengiger Start bei teilweisem Konflikt. Speicher-Fakes fuer Start/Stopp,
  ausstehenden Stopp, Transkription/Layout/Installation/Dialoge ohne Audiogeraet.
  Reale GUI-Timer-Zustellung, Aufnahme-/Pegelanzeige, rote Startfehler und reale
  Ergebnisverarbeitung mit Clipboard-Fake; Stopp/Ergebnis erhalten Vordergrundhandle.
- Test-TaskPloppDictationUi.ps1, Test-TaskPloppAutosave.ps1,
  Test-TaskPloppTransfer.ps1, Test-TaskPloppTransferUi.ps1 bestanden.
- Test-TaskPloppNative.ps1: Parser-/Quellcodeaudit inklusive Tests, keine C#-Dateien
  oder Compilerquellen, gecachte feste ABI-Metadaten und bestehende Audio-Pruefungen.
- Konfigurationsansicht per DrawToBitmap ausschliesslich der eigenen synthetischen
  Test-GUI angesehen: beide Aktionen, Buttons, Vorschauen und Hinweise lesbar.
  Bild im Windows-Tempverzeichnis TaskPlopp-hotkey-actions.png, keine Nutzerdaten.

## Grenzen / offene manuelle Abnahme
- Windows verweigerte die kuenstliche Vordergrundaktivierung der externen Test-GUI.
  Dieser Teil ist explizit SKIP; stattdessen blieb das tatsaechlich bestehende
  Vordergrundhandle bei Stopp/Ergebnis identisch. Echte physische Hotkeys liefern
  eine andere Windows-Aktivierungsberechtigung; sie sind damit nicht bewiesen.
- Test-TaskPloppLayout.ps1: alle fuenf Groessen-/Abstandskombinationen sowie
  Hilfetexte, fette Ueberschriften und beide fettgedruckten Standard-Hotkeys bestanden.
  Der anschliessende Escape-Navigationsteil stoppt an seiner Voraussetzung
  "Test requires active Main for Help Escape" (Windows-Fokusverweigerung).
  Der Gesamttest ist deshalb NICHT als bestanden gewertet; Folgepruefungen nicht ausgefuehrt.
- Tobias: echte Strg+NumPad1-Taste druecken, sichtbaren Aufnahmestart pruefen,
  andere App aktivieren, erneut stoppen, Ergebnis dort mit Strg+V einfuegen.
  NumLock an/aus und Citrix-Vollbild gesondert testen. Keine automatische Eingabe.
- Sehr schnelle Wiederholungen innerhalb des vorhandenen GUI-Timerintervalls
  koennen wie beim Oeffnen zusammenfallen (AutoResetEvent, kein Befehls-Queuebau).

## Produktstart
TaskPlopp auf ARKANIS nach Umsetzung neu gestartet (PID 32156). Prozess bleibt
am Leben; SHA256 der produktiven data/config.json vor/nach Start identisch.
Keine Aufnahme automatisch gestartet. GANDALF benoetigt einen Neustart fuer den neuen Code.
