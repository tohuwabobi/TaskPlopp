# Weitere Themen

## Morgen, 09.11.2026: Logitech-Sondertasten als Hotkey
Tobias moechte TaskPlopp auch ueber Sondertasten seiner Logitech-Tastatur oeffnen, zum Beispiel die Taschenrechner-Taste. Zuerst pruefen, welche Taste Windows/Logitech durchreicht und ob die vorhandene Hotkey-Registrierung oder eine einfache Tastenzuordnung reicht. Noch keine Umsetzung beauftragt.

## OpenAI-Schluessel im Konfigurationsmenue einrichten
Tobias moechte den OpenAI-API-Key fuer den Fensterordner direkt in der Konfiguration einrichten koennen, insbesondere auf weiteren PCs. Verdeckte Eingabe, benutzergebundene lokale DPAPI-Speicherung und Statusmeldung ueber Erfolg/Fehler; keine Klartextablage im Projekt oder im Konfigurations-Export. Umgesetzt und von Tobias auf GANDALF praktisch abgenommen. Rueckmeldung vom zweiten Chat: Tobias lehnt eine manuelle PowerShell-Einrichtung ausdruecklich ab. Die Eingabemaske muss auf dem jeweiligen PC bedienbar sein; die fremde DPAPI-Datei reicht nicht. Keine Klartextschluessel ueber Chats austauschen.

## Testrechner / Zuordnung
- Aktueller Host dieses Chats laut Tobias: hspwo-arkanis.
- Zweiter Test-PC bestaetigt: HSPWO-GANDALF. Der dortige Chat hat den Namen per [Environment]::MachineName ermittelt. Projektpfad: C:\CodexProjekte\TaskPlopp.
- Auf HSPWO-GANDALF wurde die Desktop-Verknuepfung erfolgreich eingerichtet. Der dortige Chat hat Setup.bat als Doppelklick-Einstieg fuer Install-Shortcut.ps1 -Update hinzugefuegt und README.md angepasst. Diese Aenderungen erhalten; Testergebnisse und lokale Schluesselablage dem jeweiligen Rechner zuordnen.

## Weitere Umbauten - separat planen
1. Stammordner aufraeumen: Nur zum Start benoetigte Dateien, README und Setup.bat im Stamm belassen; uebrige Dateien in passende Unterordner verschieben. Noch nicht umsetzen.
2. Konfiguration ohne Speichern-Button: Aenderungen sofort ohne Rueckfrage speichern. Eigenes spaeteres Umbauthema; ersetzt im aktuellen Auftrag noch nicht die bestehenden Speicheraktionen.
3. Leertaste minimiert TaskPlopp in die normale Windows-Taskleiste. Eigenes spaeteres Tastaturthema.

## Praktische Abnahme abgeschlossen
Tobias hat den Gesamtstand auf HSPWO-GANDALF bestaetigt, einschliesslich Fensterordner und Rueckgaengig. Die Key-Eingabe meldete zuvor gruenen Erfolg. Ein Test auf GANDALF reicht Tobias ausdruecklich zur Abnahme; ARKANIS wird sich in der Praxis zeigen und ist keine offene Freigabebedingung. Automatische Tests ersetzen diese Bedienungsabnahme nicht.