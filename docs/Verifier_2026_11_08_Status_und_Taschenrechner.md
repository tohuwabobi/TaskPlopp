# Verifier: Meldungen aufraeumen und Taschenrechner-Hotkey

PowerShell 5.1; keine neuen Pakete, C#-Quellen, Popups oder Farben.
Fensterordner-Abschluss, leerer Vorschlag, Undo und Fehler erhalten 15 Sekunden
Anzeigedauer. Aktualisieren loescht bisherige Meldungen in normalen Leisten.
Aufnahme/Transkription sowie laufender Layout-Worker oder Installer bleiben erhalten.
Kein Undo-Snapshot wird durch das Loeschen der Anzeige veraendert.

Die Auswahl Taschenrechner wird auf Windows LaunchApplication2 / VK 0xB7 abgebildet.
Nur fuer diese Sondertaste sind null Zusatztasten erlaubt. Bestehende F12-Regel,
Konflikterkennung, vorherigen Hotkey erhalten und Sofortspeichern bleiben bestehen.
Keine neue Einstellung und keine automatische Aenderung der produktiven Belegung.

Bestanden unter PS5.1 auf ARKANIS:
- Hotkey-Konfiguration: Taschenrechner im Menue, Vorschau, null Zusatztasten sofort
  speichern/neuladen, danach gewoehnliche Kombination wieder waehlbar.
- Reale Registrierung von Taschenrechner ohne Zusatztasten, synthetische WM_HOTKEY-
  Benachrichtigung erreicht WakeEvent, Registrierung anschliessend freigegeben.
- Bestehende echte Hotkey-Wechsel/Konflikte/Speicherfehler und Ruecknahme bestanden.
- Fensterordner-Tests ohne API: Ablauf, Aktualisieren loescht Meldung, Aktualisieren
  waehrend Aufnahme/Planung erhaelt Status. Eigene Testfenster/Undo weiterhin korrekt.
- Native-Quellcodeaudit, Sofortspeichern und ZIP-Transfer bestanden.
- Keine Mikrofonaufnahme und keine Desktopdaten an eine API gesendet.

Noch manuell: TaskPlopp nach Synchronisierung neu starten, Taschenrechner auswaehlen,
Zusatztasten nach Wunsch abwaehlen und echte Sondertaste druecken, auch unter Citrix.
Ein Logitech-Treiber kann eine andere Aktion senden; das wurde nicht physisch getestet.
Windows-Registrierung und synthetische Benachrichtigung ersetzen diesen Test nicht.

Quellen:
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey
https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
