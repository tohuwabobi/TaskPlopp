# Verifier: Sofortspeichern, Leertaste, Ordnerstruktur, 08.11.2026

Basis c16a082. Plan_2026_11_08_1900_Sofortspeichern_Leertaste_Ordner.md unabhaengig freigegeben, anschliessendes X+ von Tobias umgesetzt. Nur PowerShell 5.1/WinForms und bestehender Batch-Starter. Keine Compiler/C#/neuen Farben/Popups, keine Pakete oder Adminrechte.

## M1 / M1b umgesetzt
- Kein Speichern/Abbrechen in der Konfiguration. Auswahlen, Schalter und Favoritenaktionen speichern sofort; Text und maskierter Key erst bei Leave oder Schliessen. Nur geaenderte Werte schreiben.
- Kandidatenkopie statt Mutieren aktiver Favoriten. Gemeinsame Uebernahme mit Ladeguard, feste Editorzuordnung bei Auswahlwechsel, Ruecksetzen auf gespeicherten Stand bei Fehler und Statushinweis. Keine Schliessensperre/Rueckfrage. Fehler beim Schliessen auch in Hauptstatus sichtbar.
- Key bleibt DPAPI CurrentUser. Leeres Feld aendert nichts; fehlerhafte Eingabe wird ohne Keyausgabe geleert. Kein Online-Test beim Speichern, keine Klartexte in Config oder ZIP.
- Nach Dateipublikation werden Anzeige-/Hotkeyaufraeumfehler als Warnung ueber gespeicherten Zustand behandelt, nicht als verlorener Save. PC-Sperrfrist wird nur bei Aenderung ihrer eigenen Einstellungen erneuert.
- Space nur unmodifiziert in aktiver Hauptform, Tasks/Audio, ohne offene Menues/Dialoge/Editor. Fokussierter Button wird nicht ausgefuehrt; Aufnahme bleibt aktiv. Keine globale Space-Registrierung.

## M2 umgesetzt
- Root: Start-TaskPlopp.ps1, README.md, Setup.bat; notwendige .gitignore/.gitattributes bleiben dort. src/tools/tests/data getrennt; assets/docs/shortcuts als vorhandene Unterordner erhalten.
- Root-Startziel und Iconpfad bleiben kompatibel mit Desktop-/Startup-LNKs. Setup ruft tools/Install-Shortcut.ps1 auf; Installer hat optionalen ShortcutPath fuer isolierte Tests, regulaer unveraendert Desktop.
- Paths-Modul mit festen relativen Projektpfaden; benachbarte Worker und Runspaces nutzen src, Diktat-Installer tools. Audit weiterhin fuer alle Projekt-PS-Dateien.
- Persoenliche Config/Sicherungen bei regulaerem Neustart nach data uebernehmen. Vorhandene kanonische Config gewinnt, zusaetzliche Root-Datei wird unveraendert unter legacy erhalten und gemeldet. Kollisionen nie ersetzen, Konfliktdateien nicht migrieren. Fehler erhalten Daten und ggf. bisherigen Pfad. Laufende alte Instanz wird nur geweckt; LibraryOnly/Test/ConfigFile migrieren nichts.
- Echter Neustart auf ARKANIS: neue residente Instanz gestartet. Hash der vorherigen Config und beider Sicherungen unveraendert; keine Root-config/backups mehr. Keine absoluten Favoritenziele/LNK-Inhalte geaendert. DPAPI und Modelle bleiben unter LocalAppData.

## Automatische Nachweise
- 17 passende Testskripte aus tests bestanden; der maschinenspezifische Test-TaskPloppLocalFavorites wurde nicht als allgemeiner Regressionstest ausgefuehrt. Kein StoreLaunch/Hardware/Microphone/Api-Schalter benutzt.
- Test-TaskPloppAutosave: kein Save beim Laden/Tippen, Save bei Leave/Close, kein wiederholter No-op-Save, Auswahlwechsel schreibt richtigen Favoriten, Reihenfolge/Checkbox/Engine, ungueltiger Text zurueckgesetzt, Schreibsperre erhaelt Datei/UI und gueltiger Folgeschritt funktioniert. Lock-Uhr bleibt bei anderen Aenderungen gleich.
- Maskierter Key mit Fakewerten/Tempziel: Leave/Close, kein Speichern waehrend Tippen, alter Key bleibt bei Fehler und Eingabe wird geleert. Fehler nach geschlossenem Dialog in Hauptstatus sichtbar. Nachgelagerter Anzeigenfehler per Fault-Injection: Datei und aktive Settings enthalten publizierten Wert; Warnung statt falscher Speicherfehlermeldung.
- Test-TaskPloppKeyboard: aktive echte Testform, Space-Zweig in Tasks/Audio, Button wird nicht ausgeloest; Shift/Dialog/Editor-Schutz. Dies testet den WinForms-Handlerpfad, ersetzt keinen physischen Tastendruck am Benutzer-PC.
- Test-TaskPloppStructure: frische/alte Config, beide Configs gleich/abweichend, identische Bytes, Backupkollision, Konfliktdatei unangetastet, wiederholter Lauf, gesperrte Quelldatei und alter Configpfad. Kopiertes Projekt mit Leerzeichen, anderes Arbeitsverzeichnis, LibraryOnly/Rootstart, Smoke/Resident und ConfigFile ohne Migration; bestehende WakeEvent-Instanz verhindert Migration; echte Test-LNK-Properties und Schutz fremder Verknuepfung.
- Weitere Regressionen: Apps, Audio, Hotkeywechsel/Fehler, Lock ohne echte Sperre, Nativeaudit, KeyAndWindow, Layout, ZIP/LNK-Transfer und Transfer-GUI, WindowLayout mit eigenen Fenstern/Screenshot im RAM.
- Beide echten Diktat-Engines anschliessend auch mit synthetischer deutscher Sprache aus den neuen Pfaden geprueft, GUI-Heartbeat und kompletter Text bestanden. Keine echte Mikrofonaufnahme.
- UI-Tests verwenden isolierte nicht vorhandene Keypfade bzw. explizite Fake-Keydateien; keine produktiven Keys geaendert oder Online-Anfragen in diesem Umbau.

## M3 / Logitech-Discovery, noch keine Produktimplementierung
Tobias: MX Keys auf ARKANIS; GANDALF aelteres Logitech-Modell, ca. acht Jahre, Drehrad oben links, Modellname noch offen. Auf ARKANIS Logi Options+ 2.9.994631 erkannt. LaunchApplication2, VK 0xB7 mit MOD_NOREPEAT, liess sich in isoliertem PS5.1-Listener registrieren und sofort sauber freigeben. Kein physischer Tastendruck und kein Citrix-Test; Registerbarkeit belegt keine Signalroute der konkreten Taste. Bestehende Kombination blieb unveraendert. Keine Software installiert oder Taste umbelegt.
Naechster Schritt am Geraet: Modell/programmierbare Taste bestaetigen, bevorzugt vorhandene Options+-Zuordnung auf den TaskPlopp-Hotkey testen. Falls direkte Appunterstuetzung noetig wird, kleiner eigener Plan nach echtem Signalnachweis statt Low-Level-Hook.

## Noch manuell abzunehmen
Auf GANDALF nach vollstaendiger Synchronisation ueber vorhandenen Desktoplink starten: neuer Konfigurationsdialog ohne Save-Buttons, geaenderte Namen/Modell/Key nach Feldwechsel bzw. Neustart erhalten; Space minimiert ohne Klickaktion, Textfelder erhalten Leerzeichen, X/Taskbar/Hotkey weiter korrekt. Danach vorhandenen Startup-Link/Setup am Geraet pruefen. ARKANIS-Start und lokale Dateihashes sind technisch belegt, keine Benutzerabnahme behauptet. Sondertastendruck und Citrix bleiben eigene Hardwaretests.

## Quellen zur Discovery
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey
https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
https://hub.sync.logitech.com/options/post/programming-buttons-and-keys-in-options-ntwM6VsAEKhHACY
## Rueckmeldung und Korrektur der Statusanzeige
Tobias bestaetigt Leertaste und aufgeraeumte Ordner; Sofortspeichern scheint zu funktionieren.
Befund: dauerhafte gruene Erfolgsmeldung unterscheidet nachfolgende Eingaben nicht.
Korrektur: Benutzer-TextChanged bei nicht ladender Konfiguration zeigt gelb den noch
nicht gespeicherten Textzustand. Config-Save/Key-Save zeigen fuer zwei Sekunden gruen,
bei normalen Settings mit eindeutigem Speicherzeitpunkt. Danach neutraler vorhandener
GUI-Hintergrund. Kein neuer Timer: vorhandenen Status-Timer mit optionaler Ablaufzeit
verwenden; neue Meldungen ersetzen/entfernen die alte Ablaufzeit. Fehler/Warnungen und
Aufnahme werden nicht automatisch ausgeblendet. Andere Meldungen bleiben unveraendert.
Tests: echter Timerablauf mit GUI-Pump, Eingabe ersetzt Gruen, pending/error ersetzen
vorigen Erfolg ohne spaeteres Loeschen, Recording ohne Save-Ablauf. Autosave-, Layout-,
Audio-GUI-, Diktat-GUI- und KeyAndWindow-Regressionen bestanden. Keine neuen Farben
oder Popups. Physische Escape-Eingabe im Audio-Test mangels aktivem Desktop SKIP;
Rueckkehr ueber Button geprueft. Neue Statusrueckmeldung noch mit Tobias nach Neustart
praktisch pruefen. Daten- und Speicherverhalten ansonsten unveraendert.