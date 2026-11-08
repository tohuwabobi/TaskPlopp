# Weitere Umbauten: Sofortspeichern, Leertaste, Stammordner, Sondertasten - P+

Stand 08.11.2026, Basis c16a082, Git-Arbeitsstand bei Discovery sauber.
Urspruenglich P+-Plan, unabhaengig freigegeben; Tobias hat anschliessend X+ erteilt. Umsetzungs-/Teststand siehe Verifier_2026_11_08_Sofortspeichern_Ordner.md.

## Ziel und Reihenfolge
1. Gültige Konfigurationsänderungen ohne Speichern-Button und ohne Rückfragen übernehmen; Leertaste minimiert das aktive Hauptfenster in die Taskleiste.
2. Sichtbaren Stammordner auf Startdatei, README und Setup.bat reduzieren; funktionierende Verknüpfungen und persönliche Einstellungen erhalten.
3. Anschließend Logitech-Sondertasten auf dem tatsächlich verwendeten Rechner untersuchen. Keine ungetestete Unterstützung beliebiger Sondertasten versprechen.

## Leitplanken / Nicht-Ziele
PowerShell 5.1, WinForms, CRLF, bestehende Statusleiste/Farben. Keine Popups, C#, Frameworks, zusätzlichen Module, allgemeine Job-/Transaktionsverwaltung oder neue Archivformate. Kein automatisches Online-Testen von Keys, keine Geräteumschaltung/PC-Sperre/echten Desktopuploads in automatischen Tests. Andere Werkzeugeinstellungen auf ARKANIS/GANDALF nicht ungefragt ändern. X bleibt residenter Rückzug in den Infobereich; normales Minimieren bleibt in der Taskleiste.

## Discovery: konkrete Ausgangslage
- TaskPlopp.Configuration.ps1 hält derzeit eine Arbeitskopie, verändert Favoritenobjekte bei TextChanged und speichert alles erst bei SaveSettings. Es gibt zwei Speicherbuttons (allgemein, API-Key) sowie Abbrechen; die bisherige Abbruchsemantik entfällt bei Sofortspeicherung.
- Save-Settings schreibt atomar und validiert die temporäre Datei. Save-TaskPloppSettingsWithHotkey registriert erst einen Kandidaten, speichert und ersetzt dann den Listener. Dies wiederverwenden. Hotkey-Zusatzfelder lösen einzeln bereits Vorschauereignisse aus; Laden muss daher gegen Speicherereignisse geschützt werden.
- API-Key liegt separat mit DPAPI, kein JSON-Feld. Nur Save-TaskPloppOpenAIKey wiederverwenden. Präfix/Form kann lokale Gültigkeit prüfen, keinen vollständigen oder freigeschalteten API-Key garantieren.
- TaskPlopp.Keyboard.ps1 verwendet KeyPreview und hat bereits Vorrangregeln für aktive Form und Kontextmenüs. Leertaste würde auf einem fokussierten Button sonst dessen Standardaktion auslösen.
- Laufzeit, Worker und Tests referenzieren derzeit vielfach $PSScriptRoot als selben Ordner. Installer, Startdatei, Icons und lokale Favoriten haben weitere Root-Abhängigkeiten. Reines Verschieben ohne Pfadanpassung reicht nicht.
- config.json, config.before-*.json und shortcuts sind persönliche/ignorierte Daten. Native-Sourceaudit scannt derzeit nur den flachen Stamm; nach Verschieben muss es weiterhin alle eigenen PS-Dateien prüfen.

## M1: Sofortspeichern - verbindlicher Bedienvertrag
### Wann gespeichert wird
- Checkboxen, Auswahlfelder, Zahlenwerte: nach abgeschlossener Benutzeränderung sofort. Initialisierung und programmgesteuertes Laden sind keine Benutzeränderung.
- Textfelder (Favoritenname, Prozesskennung, Titelfilter, Modellname, API-Key): beim Verlassen des Feldes, nicht bei jedem Zeichen oder nach einer Tipp-Pause. Bei Schließen des Dialogs wird das noch fokussierte Textfeld einmal ebenfalls abgeschlossen. Dadurch wird insbesondere ein angefangener API-Key nicht automatisch während des Tippens übernommen.
- Hinzufügen, Entfernen, Umordnen eines Favoriten, Startziel-Auswahl und Wiederanzeigen ausgeblendeter Programme: sofort nach dem abgeschlossenen Klick bzw. nach bestätigter Auswahl im schon vorhandenen Picker. Abbrechen des Pickers ändert nichts.
- Hotkey: jede abgeschlossene Auswahländerung bildet eine Kombination aus den aktuell sichtbaren Feldern. Ungültig/belegt: alten aktiven Hotkey und Datei erhalten, sichtbare Auswahl auf den letzten gespeicherten Stand zurücksetzen, rote Statusmeldung. Kein gesonderter Anwenden-Button.

### Kleine Umsetzung und Fehlerverhalten
- Ein lokaler Lade-/Speicherschutz und eine gemeinsame Übernahmefunktion im Konfigurationsdialog; keine neue Zustandsmaschine/Timer für Autosave. Kandidat als Kopie der zuletzt gespeicherten Settings erstellen, genau die abgeschlossene Änderung darauf anwenden, validieren, vorhandenen Save-/Hotkeypfad aufrufen und erst dann script:Settings veröffentlichen.
- Bestehende TextChanged-Handler dürfen nicht mehr die aktiven Settings verändern. Favoriteneditor benötigt die Zuordnung zum tatsächlich bearbeiteten Favoriten; Abschluss vor Auswahlwechsel, damit der alte Text nicht versehentlich beim neu gewählten Eintrag landet.
- Bei ungültiger Eingabe oder Speicherfehler bleiben Datei und aktive Werte erhalten. Den betroffenen Editor/Eintrag auf den letzten gespeicherten Stand zurücksetzen und eindeutig rot melden: Änderung nicht übernommen, bisheriger Wert wiederhergestellt. Keine still verbleibenden ungespeicherten Änderungen, keine Schließensperre oder Rückfrage.
- Änderungen an anderen Einstellungen bleiben bedienbar; eine ungültige Namenseingabe darf z.B. nicht alle späteren Engine-Änderungen blockieren. Auswahl-/Reihenfolgeänderungen bei Fehler ebenfalls aus dem gespeicherten Stand neu anzeigen.
- Nur tatsächliche Werteänderungen schreiben. Reines Laden, wiederholtes Leave, unverändertes Schließen: keine neue Datei/Listener/Sperrfrist. PC-Sperrfrist nur bei Änderung von Ein/Aus oder Minuten neu beginnen; Engine gilt für nächste Aufnahme.
- Nach erfolgreichem Save UI und Tray aktualisieren. Meldungen unterscheiden fehlgeschlagene Speicherung und nachgelagerten UI-/Listener-Aufräumfehler; bereits veröffentlichte Datei nicht fälschlich als ungespeichert darstellen. Den vorhandenen Hotkey-Helfer dazu beim Umbau auf diesen vorhandenen Teilzustand prüfen, keinen generischen Rollback bauen.

### API-Key ohne Speicherbutton
- Maskiertes Feld bleibt anfangs leer; vorhandenen Key nie anzeigen. Nichtleere neue Eingabe bei Leave/Schließen einmal prüfen und mit vorhandener atomarer DPAPI-Funktion übernehmen, danach Feld leeren und grüne lokale Erfolgsmeldung. Keine API-Anfrage.
- Leeres Feld bedeutet nichts ändern, niemals alten Key löschen. Bei ungültiger Eingabe/Schreibfehler alten Key erhalten, Eingabe leeren und rote sichere Meldung. Keine Schlüsselwerte in JSON, Export, Fehlermeldung oder Tests ausgeben.
- Beide Speichern-Buttons und Abbrechen entfernen. Nur Schließen (auch Escape/X); gültige Änderungen bleiben gespeichert. Hilfetexte zu Speichern/Abbrechen überall aktualisieren, einschließlich Diktat/Hotkey/API-Key und README.
- Fehler beim Abschluss im Schließen-Pfad zusätzlich in der Hauptstatusleiste nach Dialogende sichtbar lassen; keine Meldung ausschließlich in einer bereits geschlossenen Statusleiste verlieren.
- Kein dauerhaftes Hochfrequenz-Neuaufbauen der Hauptfensterliste. Während Konfiguration modal offen ist, reicht Aktualisierung des benötigten Zustands; Taskansicht beim Schließen einmal frisch aufbauen.

### Dateien M1
TaskPlopp.Configuration.ps1, bei nachgewiesenem Bedarf TaskPlopp.Hotkey.ps1, TaskPlopp.IdleLock.ps1, TaskPlopp.Apps.ps1/TaskPlopp.ps1 nur zugehörige Übernahme-/Refreshfunktionen. Vorhandenen Key-Speicherhelfer in WindowLayout.ps1 nutzen. UI-Tests mit SaveSettings/CancelSettings und Abbruchannahmen gezielt auf neue Semantik umstellen, insbesondere Apps, Hotkey, IdleLock, Diktat-GUI, Layout, KeyAndWindow und Transfer-GUI. Transfer bleibt gesonderter expliziter Import/Exportdialog; dessen Anwenden-Button wird nicht zu Autosave umgebaut.

## M1b: Leertaste
- Nur unmodifizierte Space-Taste, nur aktive, sichtbare, bedienbare Hauptform, ohne offene Kontextmenüs/Datei-/Auswahldialoge/ConfigurationOpen. In TextBoxBase, ComboBox oder anderem tatsächlich bearbeitbarem Eingabekontext bleibt Space normale Eingabe.
- Gilt in Tasks und Audio, auch bei Buttonfokus: Minimize-TaskPlopp aufrufen und Handled/SuppressKeyPress setzen, damit Space keinen Favoriten und keinen Audio-/Mikrofonbutton auslöst. Keine globale Registrierung der Leertaste.
- Während Aufnahme minimiert Space nur die GUI; Aufnahme wird weder beendet noch gestartet. In der Konfiguration wird kein Key, Name oder Titelfilter durch Space abgeschnitten. Ziffern-/Buchstaben-Direktwahl, Escape und der globale Hotkey unverändert.
- Scope: TaskPlopp.Keyboard.ps1 und gezielte Keyboard-/KeyAndWindow-Tests; keine neuen Nativedeklarationen.

## M2: Ordnerstruktur und feste Startpfade
Zielstruktur:
- Stammdateien für Nutzer: Start-TaskPlopp.ps1, README.md, Setup.bat.
- src/: TaskPlopp.ps1, TaskPlopp.*-Module und beide Worker.
- tools/: Install-Shortcut.ps1, Install-TaskPloppDictation.ps1, Build-Icon.ps1, Set-LocalFavorites.ps1.
- tests/: sämtliche Test-TaskPlopp*.ps1.
- data/: config.example.json, persönliche config.json und Unterordner backups/ für alte config.before-*.json; persönliche Dateien weiter ignorieren.
- assets/, docs/ und vorhandener persönlicher shortcuts/-Ordner bleiben als Unterordner bestehen. Absolute Favoriten-Startziele/LNK-Inhalte werden nicht umgeschrieben.
- Git-Steuerdateien .gitignore/.gitattributes bleiben notwendige versteckte Repo-Dateien; .git nicht verändern oder synchronisieren.

### Pfadvertrag und Migration
- Start-TaskPlopp.ps1 bleibt am bisherigen Root-Pfad; bestehende Desktop-/shell:startup-LNKs behalten ihr Startziel. Seine vorhandenen Parameter/LibraryOnly-/CheckHotkey-Verwendung bleiben kompatibel. Keine zweite Root-Kompatibilitätsdatei TaskPlopp.ps1 behalten; README und Aufrufer gehen zum neuen src-Pfad.
- Einen kleinen expliziten Projektroot-/src-/tools-/data-Pfadvertrag verwenden. $PSScriptRoot bleibt lokal für benachbarte Module/Worker korrekt. Keine globale Pfadsucherei oder Abhängigkeit vom aktuellen Arbeitsverzeichnis.
- Setup.bat ruft tools/Install-Shortcut.ps1 -Update auf. Installer ermittelt Root über seinen Elternordner; legt weiterhin Root-Startziel, Root-Arbeitsverzeichnis und assets-Icon fest. Bestehenden Zugehörigkeitscheck auf Root statt tools anpassen. Einen fremden TaskPlopp.lnk weiterhin nicht überschreiben.
- Diktat-Installer lädt Native/Dictation aus src; Laufzeit startet Installer aus tools. Build-Icon schreibt nach assets. Tests laden src/tools über Root; Audit scannt Root, src, tools und tests. README-Testbefehle und lokale Favoritenhilfe aktualisieren.
- Defaultconfig künftig data/config.json. Explizites -ConfigFile (Tests) unverändert übernehmen; LibraryOnly-/Smoke-/Resident-Tests und Worker dürfen keine produktiven Altdaten migrieren.
- Persönliche Root-config/backups beim ersten tatsächlichen Neustart je PC in data bzw. data/backups überführen, nur bei beendeter alter Instanz. Vorher vorhandenen WakeEvent prüfen: läuft alte Instanz noch, nur wecken und keine Migration starten. Alle verschobenen Pfade vorher absolut auf Zugehörigkeit zum Projekt prüfen. Syncthing-Konfliktdateien nicht automatisch bearbeiten.
- Falls data/config.json fehlt, Root-config.json exakt dorthin verschieben. Falls beide existieren: data/config.json bleibt maßgeblich, Root-Datei unverändert unter data/legacy/ mit eindeutigem Namen aufbewahren; abweichenden Inhalt als Statushinweis melden. Keine Zusammenführung, kein stilles Überschreiben/Verwerfen.
- Vorherige config.before-*.json nach data/backups mit eindeutigen Namen verschieben, vorhandene Backups nicht ersetzen. Wiederholter Start ist wirkungslos, wenn nichts zu migrieren ist. Bei Fehler erhaltene Dateien belassen und Status melden; keinen leeren Stand über nicht migrierte alte Daten speichern. Falls die Hauptconfig nicht sicher übernommen werden kann, vorübergehend unveränderten alten Configpfad verwenden und die Migration sichtbar als unvollständig kennzeichnen.
- .gitignore für data/config.json, data/backups/, data/legacy/ ergänzen; vor G prüfen, dass echte Configs/Backups/LNKs nicht im Commit landen. Bestehende Secrets/Modelle/Importlinks unter LocalAppData unverändert. Kein Installer mit Adminrechten.

## M3: Logitech-Sondertasten - erst Hardware-Discovery
- Bestehender Validator akzeptiert nur Modifier plus A-Z/0-9/F-Tasten. Taschenrechner ist dort heute nicht einstellbar. RegisterHotKey kann dokumentierte Virtual-Key-Codes verarbeiten; Microsoft führt LaunchApplication2 (0xB7). Das beweist noch nicht, was die jeweilige Logitech-Taste lokal/Citrix tatsächlich sendet.
- Mit Tobias am verwendeten Gerät Modell, Software und tatsächliches Verhalten klären. KISS zuerst: falls auf diesem Modell verfügbar, in vorhandenem Logi Options+ die Sondertaste auf TaskPlopps aktuelle Kombination abbilden. Offiziell ist Tastenkombinationszuweisung für programmierbare Tasten dokumentiert, keine Zusage für jedes Modell.
- Falls direkte Unterstützung nötig ist: isolierte kurzlebige PS-Probe einer konkret ausgewählten Taste (Register/Unregister und tatsächliche WM_HOTKEY-Auslösung), anschließend Tastendruck mit Tobias lokal und in Citrix. Keine permanente Umbelegung, kein Low-Level-Keyboardhook/RawInput-Framework.
- Ergebnis dokumentieren und erst danach einen kleinen separaten Umsetzungsplan festlegen, z.B. eine bewiesene Sondertaste ohne Modifier in der vorhandenen Auswahl. M3 ist Discovery, noch keine freigegebene Produktimplementierung für beliebige Sondertasten. Keine Logitech-Installation/Umbelegung ohne konkreten Geräteauftrag.

## Verifier / automatische Abnahmetests
M1:
- Je ein Ereignis pro Schalter/Auswahl/Nummer, Textänderungen erst nach Leave, noch fokussiertes Textfeld bei X/Escape/Schließen, nur ein Save pro echter Änderung. Init/Neubinden erzeugt keine Saves und keine Endlosschleife.
- Favorit hinzufügen/entfernen/sortieren/Name/Prozess/Titelfilter/Startziel, ausgeblendetes Programm wiederanzeigen; Datei neu laden und tatsächliche nächste GUI-/Direktwahl prüfen. Auswahlwechsel darf keine Werte im falschen Favoriten speichern.
- Ungültiges Feld, belegter Hotkey und gesperrte Konfigdatei: aktive Settings/Dateibytes bleiben erhalten, UI zeigt bisherigen Stand und rote Meldung. Danach funktioniert eine gültige unabhängige Änderung. Nachgelagerter Fehler nach publiziertem Save als teilweise übernommener Zustand erkennbar, nicht als verlorene Speicherung melden.
- PC-Sperrfrist ändert sich nur bei Lock-Einstellungen; Engine-/Modell-/Nameänderung startet Frist nicht neu. Echte PC-Sperre nicht auslösen.
- Key nur mit Fakewerten/Tempziel: kein Keysave während Tippen oder bei leerem Leave; Save beim Verlassen/Schließen, Fehler erhält alte Bytes und leert Feld, keine Secrets in JSON/ZIP/Logs. Keine API-Anfrage. Vorhandener Import-/Exportdialog und dessen Anwenden bleiben korrekt.
M1b:
- Space in aktiver Tasks-/Audiohauptansicht minimiert (Visible/ShowInTaskbar/IsIconic), löst fokussierten Button nicht aus. Space in Editor/Key/Combo/Picker/Kontextmenü/inaktiver Form und mit Modifier wird nicht abgefangen. Aufnahme läuft weiter. Physische Tastatureingabe nur bei aktivem Desktop als echter Nachweis, sonst ausdrücklich SKIP.
M2:
- Testverzeichnis mit Leerzeichen, beliebiges Arbeitsverzeichnis; Rootstart, Setup, neu erzeugte LNK-Eigenschaften und bestehende Root-LNK-Startpfade prüfen. Desktop/Startup-Test-LNK nur an temporären Orten, echte Nutzerlinks nicht ungefragt ändern.
- Isolierte Alt-/Neustruktur-Fixtures: frische Installation, Legacyconfig, beide Configs gleich/abweichend, Backups mit Namenskollision, Schreib-/Movefehler, wiederholter Start, expliziter ConfigFile, LibraryOnly, laufende Altinstanz. Inhalte/absolute Linkziele bytegenau erhalten, kein stiller Verlust oder Überschreiben.
- Alle berührten PS5.1-Tests aus tests/ lauffähig. Diktat-Installerpfad ohne Downloads und Workerstart mit synthetischen Daten, echter ZIP/LNK-Roundtrip. Quellcodeaudit weiterhin projektweit, Root-Dateiliste wie spezifiziert. Keine reale Key-/Configmigration im automatischen Test.
M3:
- Hardwaretest ersetzt sich nicht durch synthetische WM_HOTKEY-Nachricht. Gewählte Route/Modell/Host und Citrix-Verhalten dokumentieren; unerwünschter paralleler Rechnerstart zählt als fehlgeschlagene Übernahme.

## Manuelle Abnahme und Übergabe
Tobias prüft auf einem Test-PC: Sofortspeichern ohne Button/Rückfrage und nach Neustart erhalten; fehlerhafte Eingabe sichtbar zurückgesetzt; Key verdeckt eingeben und Feld verlassen; Space minimiert ohne Buttonaktion; X/Taskbar/Hotkey weiterhin korrekt. Nach Ordnerumbau vorhandene Desktop-/Autostartverknüpfung und Setup dort tatsächlich starten. Ein Rechner reicht nach Tobias' bisheriger Präferenz zur funktionalen Abnahme, weitere PC-Migration bleibt separat kontrolliert.
Bei X/X+ M1 und M1b zuerst umsetzen/verifizieren, dann M2 mit ruhender App. Keine Umsetzung allein durch dieses P+. M3 bleibt eigener Discovery-Schritt; falls dabei unbekannte Hardwareumsetzung nötig wird, neue Entscheidung/Plan statt ungeprüfter Erweiterung. Nach späterem X+ dokumentieren, Commit/Push und praktische Grenzen offen benennen.

## Quellen und Evidenz
Lokale Quelldateien der genannten Module/Installer/Tests, gelesen am 08.11.2026.
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey
https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
https://hub.sync.logitech.com/options/post/programming-buttons-and-keys-in-options-ntwM6VsAEKhHACY
Keine Hardwareprobe oder Produktdateiänderung in dieser Planung.

## Unabhängiges Review
Freigegeben durch unabhängigen Reviewer transfer_plan_review gegen Basis c16a082. Geprüfter Inhaltsstand vor diesem Reviewvermerk: SHA256 0037739D67008BF42303FAD3322877509B298B13D227D9BA726692B846B40954. Keine blockierenden Befunde. Verbindlicher Umsetzungshinweis zur bereits geplanten lokalen Favoritenhilfe: Set-LocalFavorites.ps1:20/67 ausdrücklich auf Root-shortcuts und data/backups umstellen, damit keine persönlichen Dateien unter tools entstehen. Keine Produkt-/Schlüssel-/Hardwareänderungen im Review. Reviewfreigabe ist keine X/X+-Freigabe.