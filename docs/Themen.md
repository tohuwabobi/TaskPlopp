# Weitere Themen

## Morgen, 09.11.2026: Logitech-Sondertasten als Hotkey
Tobias moechte TaskPlopp auch ueber Sondertasten seiner Logitech-Tastatur oeffnen, zum Beispiel die Taschenrechner-Taste. Zuerst pruefen, welche Taste Windows/Logitech durchreicht und ob die vorhandene Hotkey-Registrierung oder eine einfache Tastenzuordnung reicht. Discovery im laufenden X+ dokumentiert, direkte Sondertastenunterstuetzung noch nicht umgesetzt.

## OpenAI-Schluessel im Konfigurationsmenue einrichten
Tobias moechte den OpenAI-API-Key fuer den Fensterordner direkt in der Konfiguration einrichten koennen, insbesondere auf weiteren PCs. Verdeckte Eingabe, benutzergebundene lokale DPAPI-Speicherung und Statusmeldung ueber Erfolg/Fehler; keine Klartextablage im Projekt oder im Konfigurations-Export. Umgesetzt und von Tobias auf GANDALF praktisch abgenommen. Rueckmeldung vom zweiten Chat: Tobias lehnt eine manuelle PowerShell-Einrichtung ausdruecklich ab. Die Eingabemaske muss auf dem jeweiligen PC bedienbar sein; die fremde DPAPI-Datei reicht nicht. Keine Klartextschluessel ueber Chats austauschen.

## Testrechner / Zuordnung
- Aktueller Host dieses Chats laut Tobias: hspwo-arkanis.
- Zweiter Test-PC bestaetigt: HSPWO-GANDALF. Der dortige Chat hat den Namen per [Environment]::MachineName ermittelt. Projektpfad: C:\CodexProjekte\TaskPlopp.
- Auf HSPWO-GANDALF wurde die Desktop-Verknuepfung erfolgreich eingerichtet. Der dortige Chat hat Setup.bat als Doppelklick-Einstieg fuer Install-Shortcut.ps1 -Update hinzugefuegt und README.md angepasst. Diese Aenderungen erhalten; Testergebnisse und lokale Schluesselablage dem jeweiligen Rechner zuordnen.

## Weitere Umbauten - separat planen
1. Stammordner aufraeumen: Nur zum Start benoetigte Dateien, README und Setup.bat im Stamm belassen; uebrige Dateien in passende Unterordner verschieben. Umgesetzt: Stamm auf Startdatei, README und Setup reduziert; Details im neuen Verifier.
2. Konfiguration ohne Speichern-Button: Aenderungen sofort ohne Rueckfrage speichern. Umgesetzt: Schalter/Aktionen sofort, Text/Key beim Verlassen oder Schliessen; keine Speicherbuttons.
3. Leertaste minimiert TaskPlopp in die normale Windows-Taskleiste. Umgesetzt mit Schutz fuer Eingabefelder, Dialoge und Kontextmenues.

## Praktische Abnahme abgeschlossen
Tobias hat den Gesamtstand auf HSPWO-GANDALF bestaetigt, einschliesslich Fensterordner und Rueckgaengig. Die Key-Eingabe meldete zuvor gruenen Erfolg. Ein Test auf GANDALF reicht Tobias ausdruecklich zur Abnahme; ARKANIS wird sich in der Praxis zeigen und ist keine offene Freigabebedingung. Automatische Tests ersetzen diese Bedienungsabnahme nicht.
## Logitech-Discovery / Geraete
Tobias: MX Keys auf ARKANIS; auf GANDALF ein ca. acht Jahre altes Logitech-Modell
mit Drehrad oben links (genaue Modellbezeichnung offen). Auf ARKANIS wurde Logi
Options+ 2.9.994631 erkannt. LaunchApplication2 (0xB7) liess sich dort kurz registrieren
und wieder freigeben. Kein physischer Tastendruck und kein Citrix-Test erfolgt;
dies ist kein Beleg, dass die jeweilige Sondertaste dieses Signal liefert.
Naechster Schritt am Geraet: Modell/programmierbare Tasten bestaetigen und ggf.
Options+-Zuordnung auf den bestehenden TaskPlopp-Hotkey pruefen. Keine Treiber,
Low-Level-Hooks oder permanente Umbelegung eingerichtet.