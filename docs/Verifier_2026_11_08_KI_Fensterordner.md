# Verifier KI-Fensterordner, 08.11.2026

Umsetzung des geprueften P+-Plans, ausdrueckliches X+ von Tobias. Initialer Sicherungspush 95b26f9.
PowerShell 5.1, kein C# oder Compiler, keine neue Installation/Popups/Farben.

## Bestaetigt
- Test-TaskPloppWindowLayout.ps1: strikte Antwortpruefung, negative Koordinaten als Datenfixture, unbekannte/doppelte IDs und Monitore, falsche Typen/Extrafelder/Grenzen, verweigerte/unvollstaendige/beschaedigte Antworten.
- Echte versteckte PS5.1-Worker gegen eigene Fenster: sichtbare DWM-Rechtecke, unbeteiligte Kontrollfixture unveraendert, normale/maximierte Wiederherstellung, erzwungene Mindestgroesse mit Teilerfolg und Undo, veraltete Identitaet und geaenderte Monitortopologie ohne Bewegung.
- GUI: dynamischer Aufnahmetext bleibt bei Pegel-Ticks erhalten; Layout-Transkript geht nicht in Zwischenablage; Modellfeld wird gespeichert; CaptureDone und simulierte HTTP401/429/500, Timeout, Key-/Capturefehler, Monitoraenderung geben Status und GUI frei. Reale HTTP-Fehler wurden nicht absichtlich erzeugt.
- Ein realer harmloser Warteprozess wird bei Abbruch beendet, keine nachtraegliche Anwendung. Escape/Schliessen waehrend Apply werden zurueckgestellt. Wiederaufruf kann GUI vor CaptureDone nicht einblenden.
- Zwei echte OpenAI-Aufrufe mit gpt-4.1-mini und ausschliesslich kuenstlichen Fenstern/Arbeitsauftrag: Editor und Quellenbrowser ausgewaehlt, Musikplayer ausgelassen, gueltige Rechtecke nebeneinander. Metadaten allein 4,03 Sekunden; mit gezeichnetem Bild 1,27 Sekunden. Einzelproben, kein allgemeiner Performancevergleich.
- Regressionen: Native-Quellcodeaudit, Apps, Diktat, Diktat-GUI mit beiden echten Engines und synthetischer deutscher Sprache, Layout, Hotkey, Audio-GUI und ZIP-Transfer bestanden. Keine echte Mikrofonaufnahme, Umschaltung von Audiohardware, PC-Sperre oder produktive Hotkey-Aenderung.
- Darstellung der neuen Toolbar anhand gerenderter Test-GUI kontrolliert. Bestehende Schriftanpassung und symmetrische Abstaende erhalten.

## Kleine notwendige Ergaenzung zum Dateiscope
TaskPlopp.Transfer.ps1 kennt das neue Feld WindowLayoutModel, damit bestehendes Sichern/Importieren nach Speichern der Konfiguration weiter funktioniert. Keine Aenderung des ZIP-Formats; kein Schluessel im Paket.

## Offene manuelle Abnahme / Grenzen
- Screenshot der eigenen weissen Testflaeche war auf dem aktuellen Desktop pixelmaessig nicht verifizierbar (SKIP); Kodierung/Capture lieferte Daten, aber keine bestaetigte weisse Flaeche. Reale Bildschirmaufnahme mit Tobias testen, kein erfolgreicher Realdesktop-Beleg behauptet. Kein echter Desktopinhalt an OpenAI geschickt.
- Gesprochenes Arbeitsziel -> Screenshot -> KI -> passende echte Arbeitsfenster -> Undo zusammen mit Tobias testen. Einzelne erfolgreiche synthetische Anordnung belegt keine allgemeine KI-Qualitaet.
- Echter Mehrmonitor-/Mixed-DPI-Aufbau nicht vorhanden; negative Koordinaten sind als Vertrag getestet, kein Hardwarebeleg. Citrix/Topmost/Zugriffsrechte und Mindestgroessen bleiben reale Grenzen.
- Bei Programm-/Workerabsturz waehrend Anwendung keine Crash-Wiederherstellung; Undo nur nach normaler Rueckmeldung im RAM. Keine persistente Historie.
- Bestehende produktive Instanz nicht zwangsweise beendet; sie muss zum Laden der neuen Module neu starten.

## Bedienung fuer Praxistest
TaskPlopp neu starten. Fenster-Symbol rechts vom Diktat anklicken, Arbeitsziel sprechen,
nochmals klicken; Anordnung beobachten. TaskPlopp wieder oeffnen, Rechtsklick auf
das Fenstersymbol und letzte Anordnung rueckgaengig machen. Normales Diktat bleibt separat.
## Nachtrag: praktische Abnahme
Tobias hat den Fensterordner auf HSPWO-GANDALF erfolgreich getestet und danach auch
Rueckgaengig bestaetigt. Er akzeptiert diesen Praxistest als ausreichend; ARKANIS
wird im normalen Einsatz erprobt. Die eigene weisse Screenshot-Fixture war im
spaeteren Regressionstest im RAM erfolgreich verifizierbar. Der fruehere SKIP
bleibt als historischer Teststand dokumentiert. API-Key-Einrichtung und Taskleisten-
verhalten siehe Verifier_2026_11_08_API_Key_und_Minimieren.md.