# TaskPlopp: eigenen C#-Code entfernen und Konfiguration sichern/uebertragen

07.11.2026. Fassung 4: X+ umgesetzt und technisch geprueft; genannte Praxisbelege offen.
Basis: main 1d07dc4. Diese Fassung ersetzt die bisherigen technischen Festlegungen.
Tobias hat den Umfang um die vollstaendige Entfernung eigenen C#-Codes erweitert
und jede ZIP-Formatversionierung ausgeschlossen. Erst nach unabhaengigem Review
wird diese konkrete Fassung zur X-/X+-Freigabe vorgelegt.

## Ziel, Grenzen und KISS

TaskPlopp bleibt ein kleines Windows-PowerShell-5.1-Programm. Eigener Programm- und
Testcode besteht ausschliesslich aus PowerShell. Bestehendes Verhalten bleibt erhalten.
Zusaetzlich koennen Einstellungen und benoetigte LNK-Dateien ueber Kontextmenues als
ZIP gesichert und importiert werden. Favoritenreihenfolge und Tastennummern bleiben.

Kein eigener C#-Quelltext, keine C#-Kompilierung, keine Ersatzimplementierung in einer
anderen Sprache und keine neue Hilfs-DLL. Vorhandene Windows-/NET-/COM-Komponenten
und bereits verwendete native Whisper-/Vosk-Binaerdateien bleiben erforderlich.
Nur Add-Type -AssemblyName fuer vorhandene Bibliotheken; kein Add-Type mit Quelltext,
MemberDefinition, OutputAssembly oder C#-Dateien, auch nicht in Tests/Installation.

Windows-/DLL-Signaturen und COM-Interfaces werden in einem kleinen privaten
PowerShell-Bindungsmodul mit Reflection.Emit als Laufzeitmetadaten definiert.
Keine C#-Strings, kein Compiler, kein eigener IL-Programmcode oder Codegenerator auf
Platte. Diese Interop-Schicht bleibt ausdruecklich sichtbar; sie ist keine neue Sprache.
Nur konkret benoetigte Windows-/Vosk-Schnittstellen, kein allgemeines Pluginframework.

Kein Zusammenfuehren von Konfigurationen, keine automatische Programminstallation,
Chrome-Konto-/Profilmigration oder Pfadheuristik. Bestehende LNK-Favoriten bleiben
Links mit unveraenderten Argumenten, Working Directory und sonstigen Eigenschaften.
Keine Cloud-Transkription oder Aenderung der getesteten Modelle/Erkennungsparameter.

## Discovery und zusaetzliche Klaerung vor Planstart

Belege liegen ausserhalb Git unter
%LOCALAPPDATA%\TaskPlopp\Discovery\20261107-PowerShellOnly:
Ergebnis.txt, results.json, native.ps1, engines.ps1 und die isolierten test-*.ps1.
Alle Gegenproben liefen unter Windows PowerShell 5.1 Desktop/x64, ohne eigenen C#-Code.

Nachgewiesen:
- Hotkey registrieren, Konflikt erkennen, Hintergrund-Runspace mit eigener Windows-
  Nachrichtenqueue, Nachricht uebergeben, Stoppen und Registrierung sauber freigeben.
  Kein physischer Tastendruck/Citrix-Vollbildtest daraus abgeleitet.
- Fenster aufzaehlen, eigenes Testfenster minimieren/wiederherstellen, Styles,
  Owner/Popup, DWM-Cloaking und Paket-AppIds lesen. Fremde Fenster unveraendert.
- LastInput, Cursorverfuegbarkeit und Tastenstatus lesen. Kein echter PC-Sperraufruf.
- Core-Audio-Endpunkte und drei Rollen lesen; SetDefaultEndpoint fuer alle sechs
  aktuellen Rollen mit demselben Endpunkt erfolgreich, Werte danach unveraendert.
- Whisper und Vosk mit synthetischem bekanntem deutschen Satz im RAM. Vollstaendiger
  Text, keine blockierte GUI. Vosk sammelt abgeschlossene Segmente und final_result.
- Normale WinForms-Form/Panel mit PowerShell-Ereignissen fuer Auswahl, Status,
  Laufschrift und synthetischen Pegel; ZIP/JSON/LNK-Roundtrip und versteckte Prozesse.

Der kurze SAPI-Mikrofontest lieferte zwar korrekte PCM-Daten, die zusaetzliche Probe
zeigte aber problematische Restpuffer beim Stoppen. Deshalb ist SAPI NICHT der
geplante Aufnahmeweg. Kein ungeprueftes Weglassen von Wortenden.

Stattdessen wurde die bisherige WinMM-Technik in reinem PowerShell getestet:
Hintergrundaufnahme mit Standard-Windows-API, Stop, Treiberposition lesen, Reset,
alle zurueckgegebenen Puffer in Reihenfolge uebernehmen, Unprepare und Close.
31298 gelesene Bytes entsprachen exakt der Treiberposition (TIME_BYTES); Stoppen/
Freigabe ca. 55 ms, UI-Pumpe lief weiter, keine Audiodatei. Siehe
microphone-winmm-result.json und test-microphone-winmm.ps1.
Zusaetzliche Abbruchprobe test-worker-stop.ps1 / worker-stop-result.json:
Vosk in verstecktem PS5.1-Kindprozess: 286080 PCM-Bytes nur per stdin, gleicher
vollstaendiger bekannter Text, ca. 1,25 s. Zwei kontrollierte blockierende Fixtures
(Eingabepipe mit 4 MiB sowie Aufruf nach vollstaendiger Eingabe) wurden jeweils
in ca. 16 ms beendet; Schreib-/Lesetasks abgeschlossen, UI-Pumpe aktiv, keine Datei.
Das beweist Prozessisolation/Pipe-Abbruch, keinen kuenstlich erzeugten DLL-Defekt.
Diese Proben klaeren den Planweg; Sprachqualitaet und echter Citrix-Fokus bleiben
spaetere Praxisbelege. Keine weiteren Mikrofonaufnahmen fuer den Planreview.

## Teil A: vollstaendige Entfernung eigenen C#-Codes

### A1 - Windows-/COM-Bindungen und Fensterfunktionen

Neues TaskPlopp.Native.ps1 enthaelt nur fest benoetigte Signaturen und kleine
PowerShell-Funktionen. Typen/Signaturen einmal erstellen und wiederverwenden,
nicht pro Timer-Tick, Audioblock oder Diktat neue Assemblies erzeugen.
Native Fehler/Returnwerte sowie ref/out-Parameter korrekt behandeln; PreserveSig
bei COM beibehalten. Pointergroesse und Speicherlayouts ausdruecklich pruefen.
Diktat bleibt bei den vorhandenen Windows-x64-Engines; kein neues PS7-Ziel.

Die statischen TaskPlopp.Native-Aufrufe werden durch klar benannte PowerShell-
Funktionen ersetzt. Fenster ueber GetTopWindow/GetWindow inklusive Child-Walk
aufzaehlen, damit keine eigenen unmanaged Callback-Delegaten benoetigt werden.
Mehrere Fenster eines Prozesses erhalten; Get-Process.MainWindowHandle allein
waere kein gleichwertiger Ersatz. Bestehende Alt-Tab-aehnliche Filter, AppId-
Zuordnung, Citrix-Minimierung, Fokuspruefung und minimierte Fenster erhalten.
Foreground-Wechsel weiter nur bei tatsaechlicher Bestaetigung als Erfolg melden.

### A2 - Hotkey und PC-Sperre

TaskPlopp.Hotkey.ps1 verwendet einen kleinen PowerShell-Runspace mit festem Thread:
RegisterHotKey, WM_HOTKEY lesen, beim Ende UnregisterHotKey auf demselben Thread.
Zur Aktivierung das schon vorhandene WakeEvent signalisieren und vorhandene
Hauptfenster-Abfrage nutzen; keine neue Nachrichteninfrastruktur oder Pollingprozesse.

Beim Hotkeywechsel zuerst neue Registrierung bestaetigen, dann Einstellungen
speichern und alte Registrierung stoppen. Fehlschlag erhaelt alte Kombination.
Keine Registrierung bei UI-Smoke-Tests, nur freie Testkombinationen in nativen Tests.

IdleLock liest dieselben Windowsdaten ueber PowerShell-Bindungen. Monotone Frist,
kurze/gehaltene Tasten, Maus, nicht verfuegbarer Desktop, Ausblenden und Einstellungs-
aenderungen behalten ihre Bedeutung. LockWorkStation ueber dieselbe Bindung,
kein Wechsel zu Registry-/Windowsrichtlinien oder einem neuen Sperrprogramm.
Automatisierte Tests loesen keine echte Sperre aus.

### A3 - GUI, Tastenauswahl und Status

Normale Windows.Forms.Form mit KeyPreview/KeyDown. Auswahl 1-9,0,A-Z einschliesslich
Nummernblock, genau ein Platz pro Favorit. Nur aktive Hauptansicht reagiert;
Konfigurationsdialog, sichtbare Kontextmenues und Ctrl-/Alt-Kombinationen behalten
Vorrang. Escape in Audio kehrt zur Taskansicht zurueck, im Menue schliesst zuerst das Menue.

Normales Panel mit PowerShell-Paint-Ereignis und Forms-Timer fuer zweizeilige
Meldungen, Farben, Clipping/Laufschrift, Pegel und Arbeitsanzeige. Vorhandene
Statusfunktionen anpassen statt eine C#-Klasse durch nachgebaute Klassengerueste
zu ersetzen. Keine neuen Hintergrundthreads fuer Zeichnen, keine Worker-GUIzugriffe.
Timer fuer Laufschrift bei ausgeblendetem Hauptfenster anhalten, Ressourcen entsorgen.

### A4 - Audio, Aufnahme, Erkennung und Einrichtung

TaskPlopp.Audio.ps1 erhaelt die native COM-Anbindung in PowerShell: Geraete-ID,
Name, ContainerId/Farben, drei Standardrollen und verifizierter Rollenwechsel.
PROPVARIANT/PROPERTYKEY korrekt layouten und freigeben, COM-Objekte nicht zwischen
Runspace-Threads teilen. Keine fremden Audio-Module oder neuen Audio-Hilfsprogramme.

WinMM-Aufnahme in einem dedizierten PowerShell-Runspace: PCM16kHz/16Bit/Mono,
aktuelles eCapture/eConsole-Mikrofon ueber Endpoint-ID einer WinMM-Device-ID zuordnen.
WAVE_MAPPER allein oder Anzeigenamengleichheit gelten nicht als Geraetenachweis.
Daten im RAM, Puffer in FIFO-Reihenfolge, Pegel daraus berechnen, Ueberlauf/entferntes
Geraet als Fehler. Beim Stoppen Reset und auch teilweise gefuellte Puffer uebernehmen.
Puffer/Header aufbereiten/freigeben, Mikrofon auf Erfolg, Verwerfen, Fehler und Exit
schliessen. Keine Datei, kein automatischer Start, kein kuenstliches Zeitlimit.

Whisper: bestehende EXE und WAV-stdin/Text-stdout, -l de -nt -np -ng und virtueller
-of taskplopp-stdout ohne Ausgabeformatflag. UTF-8, stderr getrennt/parallel lesen.
Vosk: neues kleines TaskPlopp.DictationWorker.ps1 als kurzlebiger versteckter
Windows-PowerShell-5.1-Kindprozess. PCM binaer per stdin, Text UTF-8 per stdout,
Diagnose per stderr; keine Datei oder JSON/Base64 fuer Audio. Dort die vorhandene
native DLL mit PowerShell-Signaturen aufrufen, alle abgeschlossenen Segmente und
finalen Rest uebernehmen; im Normal-/Fehlerweg Modell/Recognizer freigeben.
Modelle/Parameter unveraendert, keine neue Qualitaetsoptimierung im Umbau verstecken.

Nur eine Aufnahme bzw. Erkennung gleichzeitig. WinMM im PowerShell-Runspace,
Erkennung in den genannten eigenen Kindprozessen. Keine Scriptblocks ueber Task.Run
ohne Runspace. Bytes typstabil uebergeben, nicht im Pipeline-Ausgabestrom aufzaehlen
oder in JSON/Base64 wandeln. UI liest nur Status/Ergebnis. Auswahl gilt ab naechster
Aufnahme. Start/Stop/Verwerfen, Trayhinweis, Ausblenden und Clipboard-Wiederholung
bleiben. GUI und Idle-Timer reagieren weiter.

Abbruch konkret: stdin WriteAsync und stdout/stderr ReadToEndAsync, Haupttimer
prueft Fertigmeldung/HasExited statt auf WaitForExit/GetResult zu blockieren.
Beim Beenden nur den selbst gestarteten Erkennungs-/Installerprozess bzw. dessen
eigenen Prozessbaum gezielt beenden; keine fremden Prozesse oder Namen-Sammelkills.
Pipefehler nach Abbruch beobachten, nicht als normalen Erfolg/Clipboardtext werten.
Task-Ergebnis/Prozessressourcen erst nach Abschluss lesen/freigeben.

Aufnahme kooperativ per Stopsignal beenden; GUI pollt Abschluss und bleibt bedienbar.
EndInvoke/Stop/Dispose nicht synchron auf einen noch laufenden Runspace anwenden.
Bei ausbleibendem Abschluss nach zwei Sekunden Fehler anzeigen, keine neue Aufnahme
zulassen und unmanaged Puffer nicht aus dem UI unter dem Worker freigeben. Erst
Worker-finally darf seine WinMM-Ressourcen schliessen. Beim wirklichen Prozessende
keine unbegrenzte Join-/Dispose-Schleife; Windows gibt Prozesshandles frei. Kein
neues allgemeines Job-/Statusframework. Verstecken beendet keine laufende Aufnahme.

Install-TaskPloppDictation.ps1 und der GUI-Einrichtungsweg nutzen ebenfalls nur
PowerShell. Fortschritt mit vorhandenem Process/ReadLineAsync, stderr und Exitcode
lesen, weiterhin nur vorhandene feste Downloads. Probe der Engines ohne C#-Jobklasse.
Bereits eingerichtete Komponenten wiederverwenden, nicht fuer diesen Umbau neu laden.
Keine Installation waehrend Aufnahme/Erkennung und umgekehrt.

### A5 - Quellcode- und Testbereinigung

TaskPlopp.Audio.cs und TaskPlopp.Dictation.cs aus aktuellem Projekt entfernen.
Alle C#-Quelltextbloecke entfernen aus TaskPlopp.ps1, Start-TaskPlopp.ps1,
TaskPlopp.Keyboard.ps1, TaskPlopp.Status.ps1 und TaskPlopp.IdleLock.ps1.
Alle davon abhaengigen Aufrufstellen, Installer, Tests und aktuelle README anpassen.
Keine alten .cs-Dateien oder Sourcebloecke als Backup im aktuellen Projekt verstecken.
Git-Historie wird nicht umgeschrieben; getrennte Discovery-/Benchmarkbelege bleiben.

Auch Test-TaskPloppApps.ps1 darf keine C#-EXE-Fixture mehr kompilieren. Testfenster
und Marker mit isoliertem PowerShell-Skript und vorhandenem powershell.exe/LNK
erzeugen. EXE-Zielvalidierung und LNK-Start separat verifizieren; kein eigener
Binaerfixturebau in anderer Sprache. Ein nicht sicher automatisierbarer echter
EXE-Startnachweis bleibt offen und wird nicht durch einen Mock als bestanden ersetzt.
Test-TaskPloppHotkey.ps1 ersetzt seine C#-SendMessage-Fixture; auch der optionale
PostMessage-Helfer in Test-TaskPloppLocalFavorites.ps1 wird PowerShell-nativ.
Tests gegen private C#-Typnamen/Layoutreflection auf fachliche Wirkung und die
neuen Signaturen umstellen; bestehende Fehlerpruefungen nicht einfach streichen.

## Teil B: Sicherung/Import im Kontextmenue

### Bedienung

Rechtsklick Zahnrad und neuer Eintrag im Tray-Menue oeffnen denselben kleinen
Dialog Konfiguration sichern/uebertragen: Exportieren, Importieren, Schliessen.
Linksklick Zahnrad bleibt unveraendert, keine neue Toolbar-Taste oder Konfigurations-
seite. Bei schon offenem Dialog diesen aktivieren. Bei offenem Konfigurationsentwurf
keinen parallelen Importdialog starten; keine ungespeicherten Eingaben verwerfen.

Export sichert gespeicherte Einstellungen. Import zeigt Anzahl Favoriten/Links und
fehlende Programme/Ordner sowie Hinweis auf Chrome-Profilpruefung. Anwenden ersetzt
die ganze Konfiguration nach vorheriger Sicherung; Abbrechen aendert nichts.
Fehlverweise bleiben an ihren Plaetzen, damit Nummern nicht verrutschen. Import-
hotkey-Konflikt ist ein Fehler statt stiller Ersatzkombination.
Import waehrend Aufnahme/Erkennung/Installation sperren, Export bleibt moeglich.
Rueckmeldungen lesbar im Dialog und in vorhandener Statusleiste, einschliesslich
Pfad der Sicherung. Keine zusaetzlichen laufenden Prozesse oder Meldungsmanager.

### Einfache ZIP ohne Versionierung oder Manifest

- config.json: Konfigurationskopie, dieselben Felder wie heute. In dieser Kopie
  zeigen mitgepackte LNK-StartTarget-Werte auf links/0001.lnk usw.
- links/0001.lnk usw.: unveraenderte binaere Links; mehrfach verwendete Quelle nur
  einmal speichern. Andere Startziele bleiben unveraendert. Aktive Originale bleiben
  durch Export unangetastet. Relative Paketpfade nur im ZIP, nie als aktive Startziele.
- Nur bei automatischer Vorimport-Sicherung zusaetzlich config-original.json mit
  exakten vorherigen Datei-Bytes, sofern vorhanden. Hinweise auf alten Schaden bei
  Bedarf in hinweise.txt. Keine Versionsnummer, FormatVersion, Manifestkennung,
  Migration oder Versionsverwaltung. Eindeutige Backup-Dateinamen nur gegen Kollision.

Nur direkt als StartTarget referenzierte LNK-Dateien mitnehmen, keine Linkketten,
EXE-Ziele, Zielordner, Chrome-Profile, Modelle, Transkripte, Audio, API-Schluessel,
Windows-Audiostandards oder Autostartkonfiguration. Keine Cloud-/Git-Sicherung.

Import prueft ZIP/JSON und erwartete eindeutige Eintraege. Links nur aus streng
geprueften links/<Nummer>.lnk-Eintraegen unter selbst bestimmten Namen schreiben;
keine pauschale Extraktion und keine Dateipfade aus dem ZIP als Schreibziele verwenden.
Mitgelieferte Links kommen in ein neues eigenes Verzeichnis unter
%LOCALAPPDATA%\TaskPlopp\ImportedShortcuts\<guid>. Nur passende StartTarget-Werte
auf diese absoluten Importpfade umstellen. Linkinhalt und andere Einstellungen
nicht automatisch umschreiben. Keine Heuristik fuer Benutzername, Laufwerk, Working
Directory, Downloads/Desktop oder Chrome-Profilidentitaet. Auf anderem PC kann
manuelle Korrektur noetig sein; Hinweis ist keine Garantie spaeterer Startbarkeit.

### Sicherung, Schreibpunkt und Fehler

Manueller Export verlangt gueltige lesbare Config und alle direkt referenzierten
LNK-Dateien. Fehlende EXE-Ziele sind dagegen kein Exportfehler. Exportziel .zip,
normalisierter Pfad ungleich ConfigPath. Erst eigene temporaere ZIP pruefen, dann
veroeffentlichen; Ersetzen nur nach Windows-Speicherdialogbestaetigung.

Ein gueltiges Importpaket muss auch bei beschaedigtem Altbestand funktionieren.
Vor Anwenden vorhandene config.json roh sichern, gueltige Konfiguration und noch
lesbare referenzierte Links zusaetzlich als regulaere Paketdaten speichern.
Fehlende/unlesbare alte Links konkret in hinweise.txt benennen. Alte ungueltige
Config nicht durch Defaults ersetzen: nur Originalbytes und Schadenshinweis sichern,
keine erfundene gueltige config.json. Solcher Rohsnapshot ist manuell entnehmbar,
aber kein gueltiges GUI-Importpaket. Fehlt die alte Datei, dies benennen und vorhandene
Standardwerte verwenden. Ist vorhandene Config selbst unlesbar oder die Sicherung
nicht schreibbar, vor Ersetzen abbrechen. Alte Schaeden in Vorschau benennen.

Gueltige alte Konfiguration mit fehlender LNK darf im Snapshot ihren bestehenden
Fehlverweis behalten; er bleibt spaeter als Warnung importierbar. Deklarierter
relativer Paketlink ohne vorhandenen ZIP-Eintrag ist dagegen ein Importfehler.
Paket mit ungueltiger/fehlender config.json wird immer abgewiesen.

Nach bestaetigter vorheriger ZIP-Sicherung unter
%LOCALAPPDATA%\TaskPlopp\Backups neue Importlinks schreiben und Settings pruefen.
Vorhandenen Settings-/Hotkey-Speicherweg wiederverwenden. Erst nach erfolgreichem
Save script:Settings, Tray, Idle-Frist und Ansicht aktualisieren. Vorhandene Links
niemals ueberschreiben. Kein eigener allgemeiner Rollback-/Transaktionsmanager.

Der Speicherhelfer kann nach dem Datei-Save noch werfen. Deshalb ab Beginn seines
Aufrufs bei Fehlern neue Linkkopien immer behalten; gezielt gespeicherte Datei
nachlesen, keine unbelegte Nichtuebernahme/Rueckgaengigmachung behaupten. Ungeklaerten
Ausgang mit Sicherungspfad melden, nicht blind wiederholen. Nur vor Speicheraufruf
sicher unbenutzte eigene Dateien bereinigen. Bestaetigter Save plus Anzeigeproblem
behaelt neue Config/Links; Anzeigeproblem gesondert melden. Keine automatische
Loeschung alter Sicherungen/Importgenerationen und keine Aufraeumdienste.

## Dateiumfang und Umsetzungsschritte nach Freigabe

M1 – Native PowerShell-Grundlage: TaskPlopp.Native.ps1 neu; Windows-/COM-Bindungen,
Fenster, Hotkey und Idle umstellen, gezielte Tests. Keine neuen Features dabei.
M2 – GUI/Audio/Diktat: vorhandene Keyboard-, Status-, Audio- und Dictation-Module,
Startskript und Installer umstellen; TaskPlopp.DictationWorker.ps1 neu fuer den
Vosk-Kindprozess; alle eigenen C#-Produktteile entfernen.
M3 – Verifier/Testfixtures und README anpassen, aktuelles Projekt auf restlichen
C#-Code/Compilerpfade pruefen. C#-freie Abnahme aus frischen PS5.1-Prozessen.
M4 – TaskPlopp.Transfer.ps1 neu und kleine Menueanbindung in TaskPlopp.ps1; bei Bedarf
Konfigurationsdialog nur eindeutig benennen. ZIP-/Importtests und README ergaenzen.
M5 – Gemeinsame Regression, Diff-/Scopepruefung, kontrollierter Neustart. Alter
residenter Prozess kann C#-Typen weiter im RAM halten; der neue Stand muss in einem
frischen Prozess starten. Laufende Aufnahme/Installation oder offener Konfigurations-
entwurf werden nicht fuer einen Neustart verworfen. Git nach entsprechendem Auftrag.

Kein Schreibzugriff auf andere Projekte, Syncthing-Regeln, produktive Profile oder
bestehende Favoriten/Links. Tests verwenden isolierte ConfigFile- und Tempverzeichnisse.
Bei neuem grundlegenden Problem/Noetigkeit einer anderen Sprache stoppen und Tobias
Befund/Optionen vorlegen, keine stillen Ersatzpakete oder Funktionsstreichungen.

## Unabhaengige Verifier / Abnahme

Quellcodeziel:
- Keine .cs-Datei und kein eigener C#-Quelltext in produktiven Skripten, Installern,
  Tests oder ausfuehrbaren Fixtures des aktuellen Projekts. AST-/Suchpruefung und
  manuelles Diffreview: Add-Type nur AssemblyName, keine Compiler-/Sourcepfade.
- Neues Starten/Import aller Module unter PS5.1 in frischem Prozess, ohne geladene
  alte TaskPlopp-C#-Typen und ohne neue eigene Binaerdatei. Reflection.Emit ausschliesslich
  deklarative Bindungen, keine handgeschriebenen IL-Programme.

Bestehende Funktionen:
- Native Hotkeyregistrierung/Konflikt/Wechsel/Savefehler, WakeEvent, Ausblenden und
  Beenden. Nur freie Testkeys; nichts an Benutzerhotkey veraendern.
- Fensterfilter mit normalem, minimiertem, verstecktem und Toolfenster; mehrere
  Fenster eines Prozesses, AppId-Zuordnung. Eigene Fixture verwenden; Fokusfehler
  nicht als bestaetigten Wechsel ausgeben. Citrix-Realtest getrennt dokumentieren.
- Keyauswahl inkl. NumPad und Escape, Dialog-/Menuevorrang, alle 36 Platzlabels;
  zweizeilige Statusfarben, langes Scrollen, Pegel, Ausblenden, Mindestbreite und Font.
- Endpunkte/Name/ContainerId, sechs Rollen, Teilfehler und entfernte Geraete.
  Native Typen/Layouts und COM-Freigabe testen. Echten Wechsel zu anderem Geraet
  nur im vereinbarten Hardwaretest mit Wiederherstellung jeder vorherigen Rolle.
- Aufnahme-Puffer mit synthetischen Daten FIFO/Teilpuffer/Ueberlauf/Verwerfen/Fehler/
  Stop/Exit testen. Freigegebene kurze Hardwareprobe: gelesene Bytes gegen unabhaengig
  abgefragte Treiberposition vergleichen, Mikrofon danach geschlossen, keine Audiodatei.
  Keine ungefragten langen Mikrofonaufnahmen oder Aufnahme fremder Gespraeche.
- Beide realen Engines mit demselben synthetischen deutschen Satz: gesamtes Ergebnis
  gegen vorgegebene Woerter pruefen; Mehrsegment-/UTF-8-/Fehler-/Clipboardfaelle erhalten.
  GUI-Heartbeat und Idle-Ueberwachung bleiben waehrend Aufnahme/Erkennung aktiv.
- Grosse Bytearrays ohne Pipeline-Aufzaehlung, Modell-/COM-/Pufferspeicher nach Ende,
  Workerstop und eigene Prozessbeendigung, Installer-Fortschritt/Teilinstallation testen.
  Insbesondere blockierten stdin-Write und blockierenden Kindprozess abbrechen:
  kein UI-Warten, beide Pipes/Schreibtask enden, nur eigene PID beendet, kein Clipboard.
  Ausbleibende WinMM-Fertigmeldung per Fixture: GUI weiter aktiv, Aufnahme gesperrt,
  keine vorzeitige Pufferfreigabe oder synchrone Runspace-Entsorgung.
- Idle: eigene Zeit-/Eingabefixtures, gehaltene/kurze Taste, nicht verfuegbarer Desktop,
  geaenderte Minuten und deaktiviert; kein echter Sperraufruf.

Sicherung/Import:
- Roundtrip von Config und echten Test-LNKs: Felder/Reihenfolge gegen Originalfixture,
  binaere Bytes plus getrennt per WScript.Shell gelesene Arguments/WorkingDirectory/
  TargetPath/IconLocation vergleichen. Nicht nur Importerausgabe gegen sich selbst.
- Anderes Tempziel, mehrfach referenzierte/externe Links, Wiederexport, EXE/AppId-
  Favoriten und fehlende Ziele. Keine echten Benutzerfavoriten ueberschreiben.
- Abbrechen, falsche/defekte Pakete, doppelte/unerwartete Eintraege, unsichere
  Paketpfade, fehlender relativer Link, nicht schreibbare Ziele, Export auf ConfigPath.
- Vorimport-Sicherung gegen vorherige Rohbytes und vorhandene Links pruefen;
  fehlende alte Links/ungueltige alte JSONsyntax duerfen gueltigen Restore nicht sperren.
- Belegter Hotkey und Schreibfehler vor Save lassen alte Werte aktiv; Ausnahme
  unmittelbar nach erfolgreichem Datei-Save sowie Anzeigeproblem duerfen aktive neue
  Linkkopien nicht loeschen. Ungeklaerten Ausgang nicht als Rollback/Erfolg ausgeben.
- Beide Kontextmenues, normaler Zahnradklick, Schliessen/Abbrechen, doppelte Oeffnung,
  Entwurf und laufende Aufnahme/Installation pruefen, Rueckmeldung auch bei verstecktem Main.

Fehlende Pflichtnachweise verhindern die entsprechende Abnahme; gruene isolierte
Tests sind kein Beweis einer kompletten Produktumstellung. Physischer Tastendruck,
Citrix-Vollbild/Fokus und Import auf zweitem realem PC sind eigenstaendige Praxisbelege.
Sie duerfen fuer die Planung offen bleiben; im Abschluss klar als geprueft/offen
melden. Keine nur dokumentierte Luecke als bestandenen Pflichtnachweis ausgeben.

## P+-Reviewprotokoll

Fassungen 1/2 wurden nur fuer das fruehere Sicherungsvorhaben geprueft. Deren Freigabe
wird nicht auf den erweiterten Umfang uebertragen. Damalige Befunde zu beschaedigtem
Altbestand, Schreibpunkt/Link-Cleanup und ConfigPath-Schutz bleiben beruecksichtigt.

Fassung 3 (SHA256 49A0EC9682B2A0ABD66C60036BDCC6E8F42A81D4548BB2A5FE8E560B6DB8D639)
wurde unabhaengig durch transfer_plan_review gegen Produktcode/Discovery geprueft.
Befund: Abbruchweg bei blockierenden nativen Workeraufrufen war nicht konkret genug.
Keine weiteren Blocker; PropertyStore-/Endpoint-Zuordnung sind geradlinige Portierung.
Fassung 4 legt Vosk-Kindprozess, asynchrone Pipes und kooperativen WinMM-Stop explizit
fest. Neue isolierte Pipe-/Stop-Probe erfolgreich, ohne Mikrofonaufnahme. Testhelper-
Inventur ergaenzt. ZIP bleibt ohne Manifest/Versionierung.

Abschliessende unabhaengige Reviewfreigabe durch transfer_plan_review erteilt fuer
Fassung 4, SHA256 68D1AA4F835CC6FB17860181E2504E95B6E2A006D40C0F3366E606AB0112BDAA.
Keine verbleibenden Blocker zu Machbarkeit, KISS, Spec oder Verifiern. Die nachfolgende
Dokumentation der Freigabe aendert nur diesen Status, nicht den geprueften Planinhalt.
Freigabe betrifft den Plan, keine Produktabnahme. Umsetzung erst nach Tobias'
ausdruecklichem X-/X+-Auftrag fuer diese Fassung. Keine Implementierung im P+-Cycle.

## X+-Ausfuehrung und Verifier am 07.11.2026

Tobias hat Fassung 4 ausdruecklich mit X+ freigegeben. M1 bis M4 umgesetzt;
M5-Eigencheck und kontrollierter Neustart erfolgt. Keine neuen Sprachen, Pakete,
Hilfs-DLLs oder Formatversionen. Keine persoenlichen Favoriten/Links veraendert.

- Native.ps1 ersetzt die eigenen Compilerbloecke durch deklarative ABI-Metadaten.
  Fensterliste/Filter, AppId/Child-Walk, Hotkey-WakeEvent und Idle bleiben PowerShell.
- Normale Form/Panel mit PowerShell-Ereignissen ersetzen Keyboard-/Statusklassen.
- CoreAudio direkt aus PowerShell; WinMM-Aufnahme im Runspace, FIFO/Teilpuffer,
  Pegel und Stop-Drain. Geschlossene Ressourcen werden bestaetigt; bei nicht
  bestaetigter Mikrofonfreigabe bleibt eine weitere Aufnahme gesperrt.
- Whisper mit unveraenderter stdin/stdout-CLI; Vosk in DictationWorker.ps1 mit
  binaerem stdin und Text-stdout. Installer ebenfalls ohne eigenen Compiler.
- Beide .cs-Dateien entfernt, alle Test-Compilerfixtures einschliesslich optionalem
  LocalFavorites-PostMessage ersetzt. Keine Git-Historie umgeschrieben.
- Transfer.ps1 mit Zahnrad-/Tray-Kontextmenue, einfacher ZIP, LNK-Deduplizierung,
  unveraenderten Linkbytes, automatischer Rohsicherung und erhaltenen Linkkopien
  nach unklarem/post-save Fehler. Vorschau prueft auch Ziele/Arbeitsordner der Links.

13 getrennte PS5.1-Prueflaeufe sind erfolgreich: Native, Basistest, Apps, Audio,
AudioUi, Keyboard, IdleLock, Hotkey, Dictation -Engines, DictationUi -Engines,
Transfer, TransferUi und ResidentTest. Ergebnisse stehen lokal unter
%LOCALAPPDATA%\TaskPlopp\Discovery\20261107-PowerShellOnly\implementation-regression.json.
Reproduzierbare Testskripte liegen im Repository; keine persoenlichen Audiodaten.

Besondere Nachweise:
- Beide realen Engines liefern den vollstaendigen bekannten synthetischen Satz;
  Whisper ca. 1,2 s, Vosk ca. 1,4 s. GUI-Heartbeat laeuft; Clipboardgrenze simuliert.
- Kurze freigegebene Aufnahme mit Produktcode nur im RAM: 32258 Bytes entsprechen
  exakt der Treiberposition, Stop ca. 58 ms, Mikrofon geschlossen, keine Audiodatei.
- COM-Erzeugerreferenzen explizit freigegeben; zusaetzlicher Test bestaetigt RCW-
  Referenzzaehler null nach Freigabe des zurueckgegebenen Enumerators.
- Sechs reale CoreAudio-Set-Aufrufe auf jeweils denselben bisherigen Endpunkt;
  alle Rollen danach unveraendert bestaetigt. Kein Wechsel zu anderem Geraet.
- Blockierte 4-MiB-Eingabepipe und blockierender Erkennungs-Kindprozess mit dem
  Produkt-Stopweg beendet, Close ca. 0 bis 3 ms, alle I/O-Tasks abgeschlossen.
- Unfertiger Runspace und fehlende Mikrofonfreigabe per Fixture blockieren weitere
  Aufnahmen ohne vorzeitige Pufferfreigabe. Wirkliches Prozessende mit unfertigem
  Worker separat in ca. 0,9 s bestaetigt, ohne weitere Mikrofonaufnahme.
- Unicode-Fenstertitel/Umlaute und mehrere Fenster desselben Prozesses jetzt
  ausdruecklich verifiziert. Im Eigencheck entdeckter Charset-Fehler korrigiert.
- Zeitabhaengigen AudioUi-Test korrigiert: dessen Smoke-Schliesstimer wird waehrend
  der eigenen Dialogpruefungen angehalten; Abschluss bleibt deterministisch.
- ZIP-Roundtrip prueft Felder/Reihenfolge gegen Original und echte LNK-Bytes plus
  WScript.Shell-Eigenschaften. Negative Pakete, beschaedigte Altconfig, fehlende alte
  Links sowie Fehler vor/nach Datei-Save geprueft. Benutzerkonfiguration unberuehrt.
- Laufende Instanz vor Neustart nur lesend geprueft: kein Konfigurationsdialog und
  Mikrofonbutton 'Diktat starten' aktiv, also keine Aufnahme/Erkennung/Einrichtung.
  Ueber eigene Nachrichtenqueue sauber beendet und versteckt neu gestartet.
  Neuer Prozess und neuer Kontextmenuehinweis bestaetigt; Config-Hash unveraendert.

Offene Praxisbelege, NICHT als bestanden gewertet:
- Physische Direktwahl/Hotkeyweiterleitung und Vordergrundwechsel unter Citrix.
- Echter Mikrofon-Sprachtest, anderer Audio-Endpunkt, Einfuegen und zweiter realer PC.
- Separater direkter EXE-Start ohne Argumente; getestet sind EXE-Zielvalidierung und
  echter LNK-Start eines isolierten PowerShell-Testfensters.
- Optionaler echter Store-App-Start: Shell-Aufruf blockierte ohne aktiven Desktop;
  nur eigenen Testprozess beendet, keine Benutzer-App. Test kennzeichnet diesen
  Fall jetzt als SKIP. Paketkatalog, Identitaetsabgleich und Import bleiben geprueft.
Die bestehenden Shell-App-Startfunktionen wurden dabei nicht umgebaut.
Keine tatsaechliche PC-Sperre ausgeloest. Keine erneute Installation/Modelldownloads.
Technische Pruefung erfolgreich; die genannten Praxisgrenzen bleiben sichtbar.