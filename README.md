# TaskPlopp

Kleiner lokaler Fensterumschalter fuer Windows PowerShell 5.1 mit Windows Forms.
Eigener Programm-, Installer- und Testcode besteht ausschliesslich aus PowerShell.
Es wird kein C#-Quelltext kompiliert und keine eigene Hilfs-DLL erzeugt. Die kleine
Datei `TaskPlopp.Native.ps1` deklariert benoetigte Windows-/COM-Schnittstellen ueber
.NET-Laufzeitmetadaten. Windows Forms, Windows-APIs und die nativen Whisper-/Vosk-
Programme bleiben die vorhandenen Laufzeitabhaengigkeiten.
Keine Zusatzmodule, kein Administrator und kein Autostart. Ein kleiner lokaler Prozess haelt den Hotkey aktiv.

## Starten

Nach einem Git-Clone kann `config.example.json` als `config.json` kopiert werden.
Ohne Konfiguration startet TaskPlopp mit leerer Favoritenliste; Favoriten lassen
sich anschliessend ueber die GUI hinzufuegen. Persoenliche `config.json`, deren
Sicherungen und `shortcuts` werden nicht in Git versioniert. `Set-LocalFavorites.ps1`
und der zugehoerige lokale Test enthalten die Einrichtung fuer Tobias' Rechner
und sind kein allgemeiner Installationsschritt fuer andere Nutzer.

Einmal in Windows PowerShell ausfuehren:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\CodexProjekte\TaskPlopp\Install-Shortcut.ps1
```

Die Desktop-Verknuepfung startet TaskPlopp und aktiviert die gespeicherte globale
Tastenkombination, standardmaessig **Strg+Alt+F10**.
Der Hotkey bleibt nach dem Schliessen der GUI aktiv, solange das TaskPlopp-Symbol
im Infobereich laeuft. Rechtsklick darauf: **TaskPlopp beenden**. Nach der naechsten
Windows-Anmeldung einmal die Desktop-Verknuepfung starten. Kein Autostart.
Der Hotkey wird ueber die Windows-API RegisterHotKey registriert; die Verknuepfung
selbst hat keine Tastenkombination mehr. Falls die Kombination bereits belegt ist,
erscheint der Hinweis in der Statusleiste; die GUI bleibt ueber das Symbol erreichbar.

Unter **Konfiguration > Tastenkombination** lassen sich Strg, Alt, Umschalt und Win
mit A-Z, 0-9 oder einer Funktionstaste kombinieren. Mindestens eine Zusatztaste ist
erforderlich; F12 bleibt entsprechend der Windows-Vorgabe ausgespart. Die Vorschau
zeigt die Auswahl. **Speichern** registriert die neue Kombination sofort, ohne
Neustart. Bei Belegung oder Speicherfehler bleiben die alte Kombination und die
gespeicherten Einstellungen erhalten. **Abbrechen** aendert nichts. Dieselbe
gespeicherte Kombination wird beim naechsten Programmstart wieder registriert und
im Infobereich angezeigt. Die Desktop-Verknuepfung selbst braucht keine Aenderung.
Windows-Kombinationen koennen vom Betriebssystem reserviert sein; die Weiterleitung
innerhalb Citrix muss mit der gewaehlten Kombination vor Ort getestet werden.
[Windows-Hotkey-Vorgaben](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey).

Eine vorhandene TaskPlopp-Verknuepfung aktualisieren:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\CodexProjekte\TaskPlopp\Install-Shortcut.ps1 -Update
```

Direkter Start:

```powershell
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\TaskPlopp.ps1
```

## Bedienung

### Audio und Meldungen

**Audio** in der oberen Leiste ersetzt die Taskbuttons im selben Fenster durch
zwei Spalten: Lautsprecher und Mikrofone. Ein Klick oder die beschriftete Taste
setzt das Geraet als Windows-Standard fuer Console, Multimedia und Kommunikation.

Die obere Leiste nutzt kompakte Symbole: kreisender Pfeil fuer Aktualisieren,
Zahnrad fuer Konfiguration, **Citrix** zum Minimieren und in der Audioansicht einen
Zurueck-Pfeil statt des langen Buttontexts. Beim Darueberfahren nennt ein Tooltip
die Funktion. Die Symbole stammen aus der Windows-Schrift Segoe MDL2 Assets.
Citrix, Audio, Sperre und Diktat stehen links; Aktualisieren und Zahnrad rechts.
Statusleiste und breite Taskbuttons haben gleiche Aussenkanten und symmetrische
Abstaende. Der vorhandene Fensterhintergrund bildet den dezenten Statusrahmen.
Das groessere Startfenster nutzt bis zu 760 x 1200 Pixel und bleibt bildschirmbegrenzt.

Erfolg erscheint erst nach Ruecklesen aller drei Rollen. **[Aktiv]** bedeutet,
dass alle Rollen dasselbe Geraet nutzen; andernfalls stehen die einzelnen Rollen
an den jeweils verwendeten Geraeten. Zusammengehoerige Geraete erhalten dieselbe Farbe.

**Aktualisieren** liest die gerade sichtbare Ansicht neu ein. Abgezogene Geraete
verschwinden nach dem Aktualisieren; fehlende Standards und Lesefehler werden
angezeigt. Ein Fehlversuch bleibt eine Fehlermeldung, auch wenn einzelne Rollen
bereits umgestellt wurden. Es gibt keine automatische Rueckstellung.

**Zurueck zu Tasks** oder **Escape** bringt die Favoriten mit ihren bisherigen
Tasten zurueck. In einem offenen Kontextmenue schliesst Escape zuerst das Menue.
Hotkey und Tray oeffnen immer die Tasks. Die Konfiguration kehrt dagegen zur
vorherigen Ansicht zurueck. Audio veraendert keine gespeicherten Favoriten.

Zwischen Toolbar und Inhalt liegt eine feste **zweizeilige Meldungsleiste**:
Hinweise orange, Warnungen/Fehler rot und Erfolge gruen. Die erste Zeile nennt
Art und Aussage, die zweite das Detail. Nur zu lange Texte laufen horizontal;
es gibt dort keine Scrollbar. Eine neue Meldung ersetzt die alte, ohne Verlauf
oder automatische Ablaufzeit. Bei verstecktem Fenster ruht die Laufschrift.
Auch Favoriten-, Fenster-, Start- und Konfigurationsfehler erscheinen hier, ohne
Meldungsboxen oder Tray-Sprechblasen. In der offenen Konfiguration gibt es dieselbe
zweizeilige Leiste, damit Fehler dort sichtbar bleiben. Keine automatische Oeffnung
der Konfiguration bei fehlendem Favoritenziel; dazu das Zahnrad verwenden.

Die Audio-Core-Logik und Geraetefarben stammen aus dem lokalen TDAudioSwitch,
liegen aber vollstaendig im TaskPlopp-Repository. COM-Signaturen wurden korrigiert;
die alte CLI/GUI wird nicht gestartet. Keine Module und kein zweiter Prozess noetig.
Windows-Standardgeraete sind keine per-App- oder Citrix-Geraeteeinstellungen.

### Automatische PC-Sperre

TaskPlopp sperrt den PC standardmaessig nach **30 Minuten ohne erkannte Maus-/
Tastaturaktivitaet**. Unter **Konfiguration > PC-Sperre** lassen sich Ein/Aus und
**1 bis 480 Minuten** speichern. Der kompakte Schloss-Button oben schaltet dieselbe
Einstellung direkt um: gruenes geschlossenes Schloss = aktiv, graues offenes
Schloss = aus. Der Tooltip nennt Zustand und Frist. Aenderungen erscheinen in der
Meldungsleiste. Windows-eigene Sperrvorgaben werden damit nicht veraendert.

Beim Aktivieren, Aendern der Minuten und beim Programmstart beginnt die Frist neu.
Unveraendertes Speichern anderer Einstellungen verlaengert sie nicht. Das X
blendet TaskPlopp nur aus; die Ueberwachung bleibt aktiv. **TaskPlopp beenden** im
Infobereich beendet auch die Zusatzsperre. Audio und Diktate pausieren sie nicht.

Die Beobachtung verwendet wie das alte IdleLock-Skript Mausposition und gedrueckte
Tasten, ergaenzt um den Windows-Eingabezeitstempel fuer kurze Eingaben zwischen
Abfragen. Gemessen wird mit einer monotonen Uhr statt der veraenderbaren Wanduhr.
Eingaben werden weder protokolliert noch gespeichert. Bei einem nicht verfuegbaren
Eingabedesktop (etwa waehrend einer Sperre) wird nicht erneut gesperrt; mit der
ersten wieder verfuegbaren Probe beginnt die Frist neu. Der Windows-Sperraufruf
meldet nur die Anforderung, keine unabhaengig bestaetigte erfolgreiche Sperrung.

Kein zusaetzlicher Prozess, kein Konsolenfenster und kein weiterer Autostart sind
fuer diese Funktion noetig. Der bisherige geplante Task **User Idle Lock Without
Windows Idle** wird bei der lokalen Umstellung deaktiviert/gestoppt. Seine Dateien
unter `%LOCALAPPDATA%\IdleLock` bleiben als Rueckfallmoeglichkeit erhalten. Nicht
beide Ueberwachungen gleichzeitig betreiben.

### Fenster und Favoriten bedienen

- Die konfigurierte Kombination (Standard **Strg+Alt+F10**) oeffnet TaskPlopp. Danach waehlen **1 bis 9**, **0**, anschliessend
  **A bis Z** den entsprechend beschrifteten Programm-/Fensterbutton direkt aus.
  Die Zahlen funktionieren auch auf dem Ziffernblock (Num an). Fuer Buchstaben
  ist keine Umschalttaste noetig. Der Tastendruck fuehrt denselben Wechsel oder
  Programmstart wie ein Mausklick aus.
- Die Zuordnung folgt der sichtbaren Reihenfolge: erst Favoriten, dann weitere
  Fenster. Jeder Favorit belegt genau einen Platz, auch ohne offenes Fenster
  oder mit mehreren Fenstern. Unter **Konfiguration > Favoriten** den Eintrag
  auswaehlen und mit **Nach oben / Nach unten** verschieben, dann **Speichern**.
  So bleibt der erste Favorit auf **1**, der zweite auf **2** usw. Bei mehreren
  passenden Fenstern aktiviert der normale Klick das vorderste passende Fenster;
  per Rechtsklick lassen sich die einzelnen Fenster auswaehlen.
  Die Nummern der weiteren Fenster werden beim Aktualisieren neu vergeben. Die ersten 36 Buttons
  erhalten Direktwahltasten; weitere bleiben per Maus oder Tab/Enter erreichbar.
  Toolbar und Konfiguration werden nicht nummeriert. In Konfigurationsdialogen
  und offenen Kontextmenues bleiben normale Tastatureingaben erhalten.

- Ein Fensterbutton stellt ein minimiertes Fenster wieder her und aktiviert es.
  Bei lokalen Programmen werden zuvor offene Citrix-Fenster minimiert, damit der
  Vollbild-Viewer das Ziel nicht verdeckt. Citrix bleibt verbunden. Beim Auswaehlen
  eines Citrix-Fensters wird Citrix selbst nicht minimiert.
  Nach erfolgreichem Wechsel blendet sich die GUI aus; derselbe Prozess bleibt geladen.
- Favoriten erscheinen auch ohne offenes Fenster als Button **Starten**.
  Der Klick aktiviert ein passendes Fenster oder startet die konfigurierte App.
- **Konfiguration > Offenes Fenster hinzufuegen**: Fenster auswaehlen. TaskPlopp
  uebernimmt Programmkennung und Startziel automatisch. Den Buttonnamen kannst du
  frei aendern. Bei fehlendem Startziel eine Startdatei oder installierte App waehlen.
- **Programmdatei hinzufuegen** legt einen Favoriten aus einer EXE oder LNK an,
  auch wenn das Programm geschlossen ist. **Installierte App hinzufuegen** nutzt
  den Windows-Appkatalog, beispielsweise fuer Store-Apps.
- Der optionale Titelfilter waehlt passende vorhandene Fenster aus. Er ist eine
  einfache Textsuche ohne Beachtung der Gross-/Kleinschreibung. Er oeffnet keine
  Dokumente oder Browser-Tabs. Mehrere passende Fenster bleiben per Rechtsklick waehlbar.
- **Programmkennung** wird automatisch befuellt. Bei manuell gewaehlten
  Startverknuepfungen, die einen Launcher statt der eigentlichen App starten,
  kann eine Korrektur noetig sein. Neue Favoriten aus Fenstern verwenden zusaetzlich
  den Programmpfad oder die App-ID, damit Apps mit gleichem Prozessnamen getrennt bleiben.
- **Speichern** uebernimmt die Aenderungen in `config.json`; **Abbrechen** verwirft
  die Dialogaenderungen. Bestehende Favoriten werden weiter unterstuetzt.
- Die Liste **Weitere Fenster** zeigt eine Alt+Tab-aehnliche Auswahl einschliesslich
  minimierter Fenster. Toolfenster, nicht aktivierbare und von Windows ausgeblendete
  Fenster werden herausgefiltert. Eine exakte Kopie der Windows-Alt+Tab-Liste ist
  nicht garantiert. Favoriten erscheinen nicht noch einmal in dieser Liste.
- Rechtsklick auf ein weiteres Fenster: **Als Favorit hinzufuegen** oder
  **Dieses Programm ausblenden**. Die Ausblendung gilt fuer alle Fenster dieser
  App, nicht nur fuer den gerade sichtbaren Titel. Favoriten bleiben sichtbar.
  Unter **Konfiguration > Ausgeblendete Programme** laesst sich die Regel entfernen.
- **Weitere offene Fenster anzeigen** schaltet die zusaetzliche Fensterliste ein/aus.
- **Aktualisieren** liest die offenen Fenster erneut ein.
- **Citrix minimieren** minimiert sichtbare Fenster der Prozesse `wfica32`,
  `CDViewer`, `Citrix.DesktopViewer.App`, `SelfService`, `Receiver` und `CitrixWorkspaceApp`. Sitzungen werden
  weder getrennt noch beendet. Die GUI blendet sich danach aus.
- Ein erneuter Start holt die vorhandene GUI nach vorn. Das X blendet sie aus; beendet wird TaskPlopp ueber das Symbol im Infobereich.
- Programmstarts verwenden eine EXE, eine Windows-Startverknuepfung oder eine
  registrierte App-ID. Startziele gelten fuer den jeweiligen PC. Programme
  innerhalb der Citrix-Sitzung koennen lokal nicht einzeln aufgelistet werden.

## Citrix und Windows

### Chrome mit einem bestimmten Profil starten

Eine Windows-Verknuepfung zu Chrome kann beispielsweise das Ziel
`"C:\Program Files\Google\Chrome\Application\chrome.exe" --profile-directory="Profile 1"`
verwenden. `Profile 1` ist der Profilordner, nicht der frei vergebene Profilname.
Der Profilpfad steht in Chrome unter `chrome://version`.
Diese LNK in TaskPlopp als Startdatei des Favoriten auswaehlen.
Die Startargumente der Verknuepfung bleiben dabei erhalten.

Wichtig: TaskPlopp unterscheidet vorhandene Chrome-Fenster noch nicht nach Profil.
Fuer einen Profilfavoriten **Startziel immer ausfuehren (z.B. Chrome-Profil)**
aktivieren. Dann wird immer die Profilverknuepfung gestartet, statt ein beliebiges
offenes Chrome-Fenster zu aktivieren. Chrome entscheidet ueber Wiederverwendung
oder ein weiteres Fenster. Die Favoriten fuer **hspwo.de** und **Mein Chrome**
sind so eingerichtet. Ein Titelfilter ersetzt keine zuverlaessige Profilerkennung.

### Downloads und Desktop

Die eingerichteten Favoriten **Downloads** und **Desktop** verwenden den jeweils
tatsaechlichen lokalen Ordnerpfad. Ein passendes offenes Explorer-Fenster wird
ueber seine Shell-Ordneradresse erkannt; andernfalls startet die Verknuepfung
Explorer mit genau diesem Ordner. Andere Explorer-Fenster gelten nicht als Treffer.
Bei Explorer-Fenstern mit mehreren Tabs kann die Shell je nach Windows-Version nur
den aktiven Tab melden; TaskPlopp schaltet keine Hintergrund-Tabs gezielt um.
Die Links liegen unter `shortcuts`. `Set-LocalFavorites.ps1` richtet die vier
lokalen Eintraege erneut ein und sichert vorher `config.json`. Dabei ersetzt es
die generischen Chrome-/Explorer-Favoriten und setzt deren vereinbarte Reihenfolge.

### Vollbild und Fokus

Der Hotkey wird vom lokalen TaskPlopp-Hotkey-Prozess registriert. Citrix kann Tastenkombinationen
im Vollbild an die entfernte Sitzung weiterreichen. Daher Strg+Alt+F10 in der
tatsaechlichen Sitzung ausprobieren. Funktioniert der Hotkey nur lokal, muss die
lokale Tastenweiterleitung in Citrix mit der IT abgestimmt oder zuerst ueber die
Citrix-Leiste zum lokalen Desktop gewechselt werden. TaskPlopp veraendert keine
Citrix-Richtlinien oder Registry-Einstellungen.

Windows kann Fokuswechsel einschraenken, insbesondere zu erhoehten Programmen.
TaskPlopp meldet einen nicht bestaetigten Wechsel. Dann zuerst Citrix minimieren.
Ein Start ueber PowerShell kann kurz ein Konsolenfenster zeigen.

Herstellerhinweis: [Citrix-Tastaturverhalten](https://docs.citrix.com/en-us/citrix-workspace-app-for-windows/keyboard.html).

## Lokales Diktat

Unter **Konfiguration > Diktat > Diktat-Komponenten installieren** werden beide
lokalen Engines und deutsche Modelle eingerichtet: whisper.cpp mit dem
mehrsprachigen Modell **base** sowie Vosk mit **small-de-0.15**. Download etwa
220 MB. Dateien liegen unter `%LOCALAPPDATA%\TaskPlopp\Dictation`, ausserhalb
von Git und Syncthing. Windows PowerShell 5.1 x64 und Windows `curl.exe` werden
verwendet; Python, pip, GPU und API-Schluessel werden nicht gebraucht.
Normalerweise sind keine Adminrechte erforderlich. Fehlende Systemkomponenten
oder gesperrte Downloads werden als Fehler angezeigt.

Die Auswahl **whisper.cpp / Vosk** gilt nach Speichern fuer das naechste Diktat.
Die Einrichtung selbst installiert sofort, auch wenn der Dialog danach abgebrochen
wird. Beide Engines werden nach dem Entpacken mit synthetischer Stille geprueft;
erst danach gelten sie als bereit. Fortschritt und Fehler stehen sowohl im
Konfigurationsdialog als auch in der gemeinsamen Statusleiste.

- Mikrofon oben einmal klicken: Aufnahme vom Windows-Standardmikrofon beginnt.
  Das Mikrofon waehlt man zuvor ueber **Audio**. Gruener Pegelverlauf zeigt den
  Eingang, keine bestaetigte Spracherkennung.
- Erneut klicken: Aufnahme stoppen und mit der beim Start ausgewaehlten Engine
  transkribieren. Orange zeigt Verarbeitung; die GUI bleibt bedienbar.
- Erfolg: erkannter Text liegt unveraendert in der Zwischenablage, mit **Strg+V**
  einfuegen. Keine Zusammenfassung, Bereinigung oder automatische Texteingabe.
- Rechtsklick auf Mikrofon: **Aufnahme verwerfen** oder nach Clipboardfehler
  **Erneut in Zwischenablage kopieren**. Ein neues Diktat verwirft das alte Ergebnis.
- Bei leeren/zu kurzen Aufnahmen, sehr niedrigem Pegel oder fehlendem Ergebnis
  bleibt die Zwischenablage erhalten. Ein messbarer Pegel beweist keine Sprache;
  Erkennungsfehler oder erfundener Text des Modells sind weiterhin moeglich.

X blendet TaskPlopp aus; eine laufende Aufnahme bleibt aktiv und wird am
Infobereich-Symbol/Tooltip angezeigt. Wiederaufruf zeigt ihren Status. Echtes
Beenden verwirft laufende Aufnahmen und beendet eigene Hilfsprozesse.
Es gibt kein kuenstliches Zeitlimit. Die automatische PC-Sperre bleibt aktiv.
Einrichtung und Diktat sind gegenseitig gesperrt; nur die ausgewaehlte Engine
laedt ihr Modell. Es gibt keinen staendig laufenden Transkriptionsserver.

Audio wird als PCM 16 kHz, 16 Bit, Mono im RAM gehalten und ueber Speicherpuffer
bzw. eine binaere WAV-Pipe verarbeitet. Keine eigenen Audio-Tempdateien oder
Archive. Modelle und heruntergeladene Installationspakete bleiben auf der Platte.
Windows-Auslagerungsdatei, Speicherabbilder und Windows-Zwischenablageverlauf/
Cloud-Synchronisation folgen den vorhandenen Windows-Einstellungen.
Nach Einrichtung benoetigen die Engines keine Internetverbindung.

Verwendete Quellen und Lizenzen:

- [whisper.cpp b5454](https://github.com/ggml-org/whisper.cpp/releases/tag/b5454),
  [MIT](https://github.com/ggml-org/whisper.cpp/blob/b5454/LICENSE).
- [Whisper-Modell base](https://huggingface.co/ggerganov/whisper.cpp/tree/5359861c739e955e79d9a303bcbc70fb988958b1),
  Ursprung [OpenAI Whisper, MIT](https://github.com/openai/whisper/blob/main/LICENSE).
- [Vosk v0.3.45](https://github.com/alphacep/vosk-api/releases/tag/v0.3.45),
  [Apache 2.0](https://github.com/alphacep/vosk-api/blob/v0.3.45/COPYING).
- [Deutsches Vosk-Modell small-de-0.15, Apache 2.0](https://alphacephei.com/vosk/models).

Die Einrichtung pinnt Versionen und prueft veroeffentlichte SHA-256-Werte fuer
whisper.cpp und das Whisper-Modell. Vosk stellt im verwendeten Release keinen
Herausgeber-Digest bereit; Download erfolgt von festen offiziellen HTTPS-Quellen.
Keine Behauptung eines unabhaengigen Hashnachweises fuer diese Vosk-Dateien.

## Konfiguration sichern und uebertragen

**Rechtsklick auf das Zahnrad > Konfiguration sichern/uebertragen** oder derselbe
Eintrag im Infobereich oeffnet einen kleinen Dialog mit Exportieren und Importieren.
Der normale Zahnradklick bleibt die Konfiguration. Export sichert den gespeicherten
Stand; ein noch offener Konfigurationsentwurf muss zuerst geschlossen werden.

Die ZIP enthaelt `config.json` und nur die direkt referenzierten Verknuepfungen unter
`links/0001.lnk` usw. Keine Formatversion, kein Manifest. LNK-Dateien bleiben binaer
unveraendert, einschliesslich Argumenten und Arbeitsverzeichnis; mehrfach verwendete
Links werden einmal mitgenommen. EXE-Dateien, Chrome-Profile, Audio-/Diktatmodelle,
Windows-Audiostandards und Autostarteinrichtung werden nicht mitgesichert.

Importieren zeigt Favoriten-/Linkanzahl und Hinweise auf fehlende Ziele. Erst
**Anwenden** im selben Dialog ersetzt die ganze Konfiguration. **Schliessen** bricht
ab; die Vorschau allein veraendert nichts. Vorher entsteht eine ZIP unter
`%LOCALAPPDATA%\TaskPlopp\Backups`, einschliesslich exakter alter Configdatei als
`config-original.json`. Beschaedigte alte JSON-Dateien werden als Rohsicherung mit
Hinweis erhalten und sperren einen gueltigen Restore nicht. Eine solche reine
Rohsicherung muss manuell entnommen werden; sie ist kein gueltiges GUI-Importpaket.
Fehlende alte Links werden benannt. Ist die Config selbst unlesbar oder die Sicherung
nicht schreibbar, wird vor dem Ersetzen abgebrochen.

Importierte Links liegen in einem neuen Ordner unter
`%LOCALAPPDATA%\TaskPlopp\ImportedShortcuts`. Reihenfolge und Tastennummern bleiben;
Pfade, Arbeitsverzeichnisse und Chrome-Profilnamen muessen auf einem anderen PC ggf.
manuell angepasst werden. Es werden keine Programme aus der Vorschau gestartet.
Sicherungen und alte Importordner werden nicht automatisch geloescht.

Import ist waehrend Aufnahme, Transkription oder Einrichtung gesperrt, Export bleibt
moeglich. Hotkeykonflikte werden gemeldet. Bei einem Fehler nach dem Schreibpunkt
bleiben die neuen Linkkopien erhalten; der Dialog nennt den Sicherungspfad und weist
auf den zu pruefenden gespeicherten Stand hin. Kein stiller Rollback oder Retry.

Export in eine neue ZIP erfolgt direkt. Fuer eine vorhandene ZIP erscheint der
Ersetz-Hinweis im Transferdialog; erst **Anwenden** ueberschreibt die Datei. Es gibt
keine zusaetzliche Bestaetigungsbox. Eine neue Auswahl, Abbruch oder ein Fehler
verwirft die alte Vorbereitung, sodass Anwenden sie nicht versehentlich wiederholt.
Konfiguration, Auswahlfenster, Dateiauswahl und Hover-Tooltips bleiben ausdruecklich
aufrufbare Bedienhilfen.

## Pruefung

```powershell
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppLayout.ps1
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppNative.ps1
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppTransfer.ps1
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppTransferUi.ps1
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPlopp.ps1
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppAudio.ps1
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppAudioUi.ps1
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppIdleLock.ps1
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppHotkey.ps1
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppDictation.ps1 -Engines
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppDictationUi.ps1 -Engines
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppApps.ps1 -StoreLaunch
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\TaskPlopp.ps1 -SmokeTest
```

Mit `-ResidentTest` statt `-SmokeTest` werden Ausblenden und erneutes Einblenden im gleichen Prozess inklusive Zeitmessung geprueft.

Der Smoke-Test oeffnet die GUI kurz, speichert `%TEMP%\TaskPlopp-smoke.png` und
schliesst sie. Der echte Wechsel aus Citrix-Vollbild muss vor Ort geprueft werden.
Der App-Test prueft Konfigurationsmigration, Fensterfilter, App-Identitaeten,
Ausblenden, EXE-Zielvalidierung, echten LNK-Start eines kurzlebigen PowerShell-
Testfensters und den echten
Konfigurationsdialog mit temporaeren Einstellungen. `-StoreLaunch` startet
zusaetzlich den Windows-Rechner, sofern kein Rechnerfenster offen ist. Nur ein
dabei neu entstandener Rechnerprozess wird anschliessend geschlossen. Ohne aktiven
Desktop bleibt der echte Store-Start als SKIP offen; die Shell-Aktivierung ist dort
nicht verlaesslich pruefbar. Ein direkter EXE-Start ohne Parameter bleibt ebenfalls
ein Praxisbeleg; die automatische Fixture prueft den echten LNK-Start samt Argumenten.
Die Konfigurationsvorschau liegt unter `%TEMP%\TaskPlopp-configuration.png`.

Der Audio-Test prueft COM-Signaturen, Variantenlayout, drei Rollen, Farben,
Teilfehler und fehlende Geraete. Mit **-Hardware** schaltet er die echten Standards
kurz um und stellt sie im finally-Block je Rolle wieder her. Der UI-Test prueft
Ansichten, Meldungen/Laufschrift und kleine/grosse Schrift, ohne Geraete umzuschalten.
Vorschauen: `%TEMP%\TaskPlopp-audio.png`, `TaskPlopp-audio-small.png` und
`TaskPlopp-audio-large-font.png`. Ohne aktives Desktopfenster werden physische
Tastatur-/Escape-Pruefungen ausdruecklich uebersprungen. Echte DPI-Skalierung,
Hoer-/Mikrofonprobe und der Einsatz innerhalb von Citrix bleiben manuell zu pruefen.

Der IdleLock-Test simuliert Zeit und Eingaben ohne echten Sperraufruf. Er prueft
Minutenvalidierung, Migration alter Einstellungen, neue Frist bei Aenderungen,
Toolbar-/Konfigurationssynchronisierung, Abbrechen und Lebensdauer des Timers.
Die UI benutzt eine temporaere Konfiguration; ihre Vorschau steht unter
`%TEMP%\TaskPlopp-idle-config.png`. Eine tatsaechliche PC-Sperre und das Verhalten
bei Eingaben innerhalb von Citrix sind anschliessend lokal zu pruefen.

Die Diktattests verwenden synthetische Audiopuffer bzw. mit Windows Hedda erzeugte
deutsche Sprache im RAM, keine Mikrofonaufnahme. `-Engines` benoetigt die eingerichteten
Modelle und fuer die Teststimme Windows-Sprachsynthese. Der Engine-Test vergleicht
den ganzen Testsatz. Der GUI-Test prueft Konfiguration, Fehler, Verwerfen, Pegel,
Kopierwiederholung und einen weiterlaufenden UI-Heartbeat mit beiden echten Engines.
Dabei wird die Clipboard-Schreibgrenze simuliert; die persoenliche Zwischenablage
bleibt unberuehrt. Echte Mikrofonaufnahme, Geraetewechsel, Einfuegen und Offlineprobe
bleiben manuelle Abnahmeschritte. Vorschauen: `%TEMP%\TaskPlopp-dictation-*.png`.

Der Hotkey-Test reserviert ausschliesslich freie Testkombinationen und gibt diese
anschliessend frei. Er prueft Registrierung/Wechsel, unveraendertes Speichern,
Belegung, Speicherfehler, WakeEvent nach Wechsel und Konfigurationsdialog mit
temporaerer Datei. Der Callback wird durch eine gezielte Windows-Nachricht geprueft;
dies ersetzt keinen echten Tastendruck in Citrix. Vorschau: `%TEMP%\TaskPlopp-hotkey-config.png`.

Der Native-Test prueft ausserdem den Quellcode auf Compilerpfade, ABI-Caching,
Mikrofonzuordnung per Endpoint-ID und synthetische FIFO-/Teilpuffer-/Ueberlauffaelle.
Nur mit ausdruecklichem `-Microphone` macht er eine kurze Aufnahme am aktuellen
Standardmikrofon, ausschliesslich im RAM und ohne Transkription; er vergleicht die
Byteanzahl mit der Treiberposition und prueft die Freigabe. Diktat bleibt waehrend
des Betriebs beim Ausblenden aktiv. Stoppen erfolgt kooperativ im WinMM-Runspace;
TaskPlopp wartet darauf ohne die GUI zu blockieren. Vosk laeuft in einem kurzlebigen
versteckten PowerShell-Prozess, Whisper in seiner vorhandenen EXE. Beide erhalten
Audio ueber stdin, liefern Text ueber stdout und benoetigen keine Audiodatei.

Transfer-Tests verwenden isolierte Configs, echte Test-LNKs und Tempziele. Sie pruefen
Originalbytes und LNK-Eigenschaften, Fehlerpakete, beschaedigten Altbestand sowie
Fehler vor/nach dem Save. Der GUI-Test prueft Kontextmenue, Entwurfsschutz, doppelte
Oeffnung und Schliessen. Echte Uebertragung auf einen anderen PC bleibt ein Praxistest.

## Symbol

Die eigene Lupe mit Plopp-Stern liegt unter `assets\TaskPlopp.ico` und wird fuer
Fenster, Infobereich und Desktop-Verknuepfung verwendet. SVG und PNG liegen daneben.
`Build-Icon.ps1` erzeugt aus den Zeichenbefehlen neun ICO-Aufloesungen (16 bis 256 px).

Der Layouttest verwendet isolierte Favoriten und misst gleiche Raender/Kanten,
Toolbargruppen und lange Ueberschriften bei kleiner/grosser Ansicht und Schrift.
Er prueft Statusmeldungen statt Popups, sichtbare Konfigurationsfehler, Startupfehler
und Abmeldung des GUI-Exceptionhandlers ohne Fremdfensteraktionen. Reale DPI- und
Citrix-Pruefungen bleiben Praxisbelege.
