# Verifier: API-Key und Minimieren, 08.11.2026

P+ unabhaengig freigegeben, danach ausdrueckliches X+ von Tobias umgesetzt.
Plan: Plan_2026_11_08_1800_API_Key_und_Minimieren.md.

## Umsetzung
- Vorhandener Konfigurationsreiter Fensterordner enthaelt verdeckte Key-Eingabe, lokalen Zustand und eigenen Speicherbutton. Keysave gilt sofort, getrennt von den anderen Einstellungen; Hilfe weist ausdruecklich darauf hin.
- Binaeres DPAPI CurrentUser, UTF-8 ohne Entropie; atomarer Austausch nach verschluesseltem Tempfile und Decrypt-/Bytevergleich. Alte Datei bleibt bei Fehler erhalten. Kein Key in Config/ZIP, Ausgabe oder Fehlermeldung; keine Online-Pruefung beim Speichern.
- Normales Minimieren und automatischer Rueckzug nach Favoriten/Fensterwahl, Citrix und KI/Undo behalten TaskPlopp in der Taskleiste. X versteckt resident im Infobereich; explizites Tray-Beenden bleibt erhalten. Internes Screenshot-Hide und Apply-Schliessensperre bleiben erhalten.
- Gandalf-Aenderungen Setup.bat und README-Einstieg erhalten und mit diesem Stand gesichert.

## Automatische Tests bestanden
- Test-TaskPloppKeyAndWindow.ps1: nur kuenstliche Keys in isolierten Tempordnern. Erstsave, DPAPI-Roundtrip/Format, Ersetzen, leere/ungueltige Eingaben ohne Aenderung, real gesperrte bestehende Datei unveraendert, kaputte DPAPI-Datei erkannt, verschluesselte Tempfiles entfernt.
- Test-GUI: leere verdeckte Eingabe, bestehender Key nicht vorgeladen, gruene lokale Erfolgsmeldung und Feldleerung, rote Eingabe-/Speicherfehler, eigene Speicherung bleibt trotz Abbrechen anderer Einstellungen erhalten; Modell-Entwurf verworfen.
- Native Minimiernachricht an eigene GUI sowie Visible/ShowInTaskbar/WindowState/IsIconic; Minimieren -> X -> Wiederherstellen; gleiche residente GUI lebt weiter. Favoriten-/Fenster-/Citrix-/KI-/Undo-Pfade mit Fixtures minimieren. Explizites ExitRequested beendet Test-GUI.
- Regressionen: Test-TaskPloppWindowLayout.ps1, Layout, DictationUi, Transfer, Native bestanden. Im WindowLayout-Test fehlendes StandardOutput am simulierten Prozess ergaenzt, damit die geplanten Fehlerresultate statt eines Fixturefehlers gelesen werden.
- Eigene weisse Screenshot-Fixture im letzten WindowLayout-Lauf im RAM erfolgreich verifiziert. Keine realen Desktopbilder hochgeladen und keine neuen API-Anfragen fuer diesen Auftrag.
- Syntax/Compiler-/Popupaudit bestanden; PowerShell 5.1 und CRLF. Keine C#-Quellen oder neuen Farben.

## Praktische Abnahme durch Tobias
- API-Key-Eingabe: Tobias meldet gruene Erfolgsmeldung. Rechner fuer diese Einzelmeldung nicht ausdruecklich genannt.
- HSPWO-GANDALF: Tobias bestaetigt funktionierenden Fensterordner, anschliessend "ja klappt alles! auch rueckgaengig". Gesamtstand damit praktisch freigegeben.
- HSPWO-ARKANIS: Fensterordner nicht vor Ort getestet. Tobias akzeptiert ausdruecklich den Test auf GANDALF als ausreichend; ARKANIS folgt im normalen Einsatz. Kein weiterer ARKANIS-Test als Abnahmevoraussetzung.
- Reale Mehrmonitor-/Mixed-DPI-Situationen bleiben Hardwaregrenzen des bisherigen Verifiers; keine neuen Hardwarebelege behauptet.

## Weitere Themen ausserhalb dieses Auftrags
Stammordner aufraeumen; Konfiguration ohne Speicherbutton/mit Sofortspeicherung;
Leertaste minimiert in Taskleiste; Logitech-Sondertasten. Nur als Ideen notiert.