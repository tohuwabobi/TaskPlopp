# TaskPlopp

Kleiner lokaler Fensterumschalter fuer Windows PowerShell 5.1 mit Windows Forms.
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

Die Desktop-Verknuepfung startet TaskPlopp und aktiviert **Strg+Alt+F10**.
Der Hotkey bleibt nach dem Schliessen der GUI aktiv, solange das TaskPlopp-Symbol
im Infobereich laeuft. Rechtsklick darauf: **TaskPlopp beenden**. Nach der naechsten
Windows-Anmeldung einmal die Desktop-Verknuepfung starten. Kein Autostart.
Der Hotkey wird ueber die Windows-API RegisterHotKey registriert; die Verknuepfung
selbst hat keine Tastenkombination mehr. Falls die Kombination bereits belegt ist,
erscheint ein Hinweis am TaskPlopp-Symbol; die GUI bleibt ueber das Symbol erreichbar.

Eine vorhandene TaskPlopp-Verknuepfung aktualisieren:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\CodexProjekte\TaskPlopp\Install-Shortcut.ps1 -Update
```

Direkter Start:

```powershell
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\TaskPlopp.ps1
```

## Bedienung

- **Strg+Alt+F10** oeffnet TaskPlopp. Danach waehlen **1 bis 9**, **0**, anschliessend
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

## Pruefung

```powershell
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPlopp.ps1
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\Test-TaskPloppApps.ps1 -StoreLaunch
powershell.exe -NoProfile -STA -File C:\CodexProjekte\TaskPlopp\TaskPlopp.ps1 -SmokeTest
```

Mit `-ResidentTest` statt `-SmokeTest` werden Ausblenden und erneutes Einblenden im gleichen Prozess inklusive Zeitmessung geprueft.

Der Smoke-Test oeffnet die GUI kurz, speichert `%TEMP%\TaskPlopp-smoke.png` und
schliesst sie. Der echte Wechsel aus Citrix-Vollbild muss vor Ort geprueft werden.
Der App-Test prueft Konfigurationsmigration, Fensterfilter, App-Identitaeten,
Ausblenden, EXE-/LNK-Starts mit einem kurzlebigen Testprogramm und den echten
Konfigurationsdialog mit temporaeren Einstellungen. `-StoreLaunch` startet
zusaetzlich den Windows-Rechner, sofern kein Rechnerfenster offen ist. Nur ein
dabei neu entstandener Rechnerprozess wird anschliessend geschlossen.
Die Konfigurationsvorschau liegt unter `%TEMP%\TaskPlopp-configuration.png`.

## Symbol

Die eigene Lupe mit Plopp-Stern liegt unter `assets\TaskPlopp.ico` und wird fuer
Fenster, Infobereich und Desktop-Verknuepfung verwendet. SVG und PNG liegen daneben.
`Build-Icon.ps1` erzeugt aus den Zeichenbefehlen neun ICO-Aufloesungen (16 bis 256 px).
