# TaskPlopp: ruhiges Layout und Meldungen ohne Popups

07.11.2026. Fassung 2, X+ umgesetzt und technisch geprueft; Praxisgrenzen siehe unten.
Basis: main 883414c; bereits beauftragte, lokale Fenstervergroesserung in
TaskPlopp.ps1 (760 x maximal 1200, bildschirmbegrenzt) bleibt erhalten.
Dieser Plan erweitert den Layoutauftrag um Tobias' ausdrueckliches Popup-Verbot.

## Ziel und sichtbares Ergebnis

- Obere Zeile links: Citrix, Audio/Zurueck, PC-Sperre, Diktat.
- Obere Zeile rechts: Aktualisieren, Zahnrad; dazwischen flexibler freier Platz.
- Keine zweite Toolbarzeile, keine abgeschnittenen oder ueberlappenden Buttons
  bei 420 Pixel Mindestbreite. Tooltips und bestehende Aktionen bleiben.
- Zweizeilige Statusleiste mit seitlichem Einzug und oben/unten je 3 Pixel Luft;
  Fensterhintergrund bildet die dezente Abhebung. Keine extra Rahmenlinie.
- Statusleiste und breite Task-Buttons haben gemeinsame linke/rechte Aussenkanten.
  Grundabstand zum Fenster-Clientrand: beidseits 10 Pixel.
- Hinweise orange/gelb, Warnungen/Fehler rot, Erfolg gruen; bestehende Laufschrift,
  Aufnahmepegel und Arbeitsanzeige bleiben.
- Keine vom Programm erzeugten Meldungs-/Bestaetigungsfenster oder Trayballoons.
  Das umfasst den Screenshotfall "Kein sichtbares Citrix-Fenster gefunden",
  Start-/Hotkeyfehler, Favoriten-/Fensterfehler und Konfigurationsvalidierung.
  Ausdruecklich vom Nutzer geoeffnete Konfiguration, Auswahl- und Dateidialoge
  bleiben normale Bedienansichten; keine automatische Konfiguration bei fehlendem
  Favoritenziel. Hover-Tooltips sind weiterhin gewuenscht.

## Discovery: konkrete Ursachen im aktuellen Code

TaskPlopp.ps1 verwendet eine einzige FlowLayoutPanel-Toolbar; alle sechs Buttons
werden links angehaengt. Die Statusleiste hat Margin 0. Task-Buttons haben implizite
Standard-Margins und Breite Max(340, ClientSize.Width - 42); das ergibt ungleiche
Raender und kann bei schmalem Clientbereich eine horizontale Scrollbar verursachen.

Meldungsquellen: zentrale Show-Notice-MessageBox samt Aufrufstellen in Hauptfenster
und Konfiguration; Hotkeyfehler als ShowBalloonTip; Importbestaetigung als MessageBox.
Der SaveFileDialog benutzt seine Standard-Ueberschreibbestaetigung.
Startfehler der Config entstehen vor Aufbau der Statusleiste. Konfigurationsfehler
duerfen nicht nur in der vom modalen Dialog verdeckten Hauptstatusleiste landen.
Transfer besitzt bereits einen sichtbaren Textbereich fuer Vorschau/Rueckmeldung.

## Spec und einfachste Umsetzung

### 1. Toolbar: zwei Standardgruppen

Toolbar wird eine kleine TableLayoutPanel-Zeile mit linker flexibler Spalte und
rechter AutoSize-Spalte. Darin zwei normale FlowLayoutPanels ohne Umbruch:
ToolbarLeft und ToolbarRight. Aussen je 10 Pixel, Gruppenaussen-Margins 0,
zwischen Buttons je 6 Pixel, zwischen Gruppen mindestens 12 Pixel.
Die bestehenden 64/42-Pixel-Buttons und Aktionen wiederverwenden.
Add-ToolbarButton bekommt nur eine einfache Gruppenauswahl; Aktualisieren und
Zahnrad rechts einsortieren. Kein eigener Layoutmanager oder absolute X-Koordinaten.

Bei 96 DPI benoetigen die Gruppen 230 + 90 Pixel; mit Aussenabstand und Gruppenspalt
352 Pixel Clientbreite. Die vorhandene Mindestbreite 420 reicht grundsaetzlich aus.
Groessere Schrift/Skalierung bleibt eine ausdrueckliche Layoutpruefung.

### 2. Gemeinsame Kanten, auch bei Scrollbar

Ein gemeinsamer Basiswert 10 Pixel fuer Statusleiste und Task-Inhalt. Task-Buttons
erhalten horizontale Margins 0; Breite aus dem tatsaechlich sichtbaren Clientbereich
abzueglich Padding berechnen, ohne harte 340-Pixel-Mindestbreite.
Anlegen und Resize benutzen dieselbe kleine Breiten-/Abstandsfunktion.

Ohne vertikale Scrollbar: Status und Task-Buttons je 10 Pixel vom Clientrand.
Mit Scrollbar: deren reale Windowsbreite s links spiegeln. TaskPanel hat dann
links 10+s und rechts 10 Pixel Padding innerhalb seines bereits um s schmaleren
Clientbereichs; Status-Margin beidseits 10+s. So sind beide Aussenabstaende zum
Fenster gleich, beide Kanten deckungsgleich, und kein Button liegt hinter der
Scrollbar. Nach deren Verschwinden zurueck auf 10 Pixel.
Keine dauerhaft reservierte Leerflaeche, keine manuelle Scrollbar.

Nach Inhaltsaufbau, Resize/Font/Layout und Ansichtswechsel aktualisieren.
Nur bei geaenderten Werten setzen, damit keine Layout-Endlosschleife entsteht;
falls noetig ein einfacher Wiedereintrittsschutz innerhalb dieser Funktion.
Audio bleibt zweispaltig; der aeussere Audio-Container nutzt dieselben Grundraender.
Keine Neugestaltung der inneren Audio-Geraetebuttons.
Auch Add-Heading/Leerlistenhinweise begrenzen: horizontale Margins 0 und
MaximumSize.Width aus derselben Nutzbreite; AutoSize mit Zeilenumbruch fuer die
Hoehe beibehalten. Sonst erzeugen lange Ueberschriften bei grosser Schrift trotz
passender Buttons erneut eine horizontale Scrollbar.

Isolierter PS5.1-WinForms-Prototyp belegt beide Toolbargruppen und diese Kantenlogik,
einschliesslich echter langer Headingtexte und Font 15:
%LOCALAPPDATA%\TaskPlopp\Discovery\20261107-Layout\Test-LayoutPrototype.ps1.
760x1200/wenige Tasks: 10 Pixel beidseits, 404 Pixel Gruppenspalt;
420x350/viele Tasks: Scrollbar sichtbar, 27 Pixel beidseits, Gruppenspalt 64 Pixel;
Font 15: Ueberschriften umbrechen (59 statt 23 Pixel hoch), keine Horizontalbar.
Danach wenige Tasks/grosses Fenster: wieder 10 Pixel ohne Scrollbar.
Je Fall 9 bis 13 Layout-Ereignisse, kein Layoutkreislauf. Kein Produktcode geaendert.

### 3. Meldungen statt Popups

Show-Notice und direkte MessageBox-/Balloon-Aufrufe durch vorhandene
Set-TaskPloppMessage-Aufrufe mit passender Kategorie ersetzen.
Kein Citrix-Fenster ist ein Hinweis, kein modaler Fehler; Fokus-/Speicherfehler rot.
Fehlendes Favoritenziel erklaert in der Leiste den Weg ueber das Zahnrad und
oeffnet nicht selbststaendig die Konfiguration.

Startup-Configfehler in einer kleinen lokalen Variable halten und nach Aufbau der
Statusleiste anzeigen; ggf. Hotkeyfehler dazunehmen. Keine Queue/History oder Timer
zum automatischen Wegblenden. Versteckte GUI wegen einer Meldung nicht hervorholen.

In der offenen Konfiguration dieselbe vorhandene zweizeilige Statuskomponente
unten einbetten. Gemeinsames Rendering wiederverwenden; Meldungsfunktion schreibt
in Hauptleiste und, sofern vorhanden, Konfigurationsleiste. Kein zweites Meldungssystem.
Nur tatsaechlich vorhandene, nicht verworfene Statuspanels ansprechen; Librarytests
ohne Hauptleiste duerfen Konfigurationsfehler trotzdem lokal anzeigen.
Dialog-Lebensdauer entsorgt den lokalen Panel-Timer. Farben/Laufschrift identisch.
Transfer-Rueckmeldungen bleiben in seinem bestehenden Textbereich und Hauptstatus.
Unbehandelte UI-Ereignisfehler duerfen keinen WinForms-Standardfehlerdialog ausloesen:
ein einzelner Application.ThreadException-Handler vor erster Form-/Handle-Erzeugung
im GUI-Startpfad, nach LibraryOnly-/Zweitinstanz-Rueckkehr. Vorhandene Statusausgabe
nutzen; vor Bereitstellung der Leiste denselben kleinen Startup-Text verwenden.
Handler selbst vor rekursivem Fehler schuetzen und im finally abmelden. Kein
allgemeines Recovery-/Loggingframework. Hintergrundarbeiter werden nicht umgebaut.

### 4. Bestaetigungen direkt im Transferdialog

Importieren waehlt/prueft die ZIP und zeigt die bestehende Vorschau. Erst der neue
Button Anwenden ersetzt die Konfiguration; Schliessen verwirft die Vorbereitung.
Kein Import, Backup oder Link-Schreiben beim blossen Anzeigen der Vorschau.

Export in neue Datei funktioniert direkt. SaveFileDialog.OverwritePrompt=false;
bei vorhandenem Ziel zuerst Pfad und Ersetz-Hinweis im Transferdialog anzeigen.
Erst Anwenden erlaubt Write-TaskPloppTransferZip -Overwrite.
Bei neuem Ziel ohne ausdrueckliche Ersetzbestaetigung nie -Overwrite verwenden.

Alle vorhandenen Dateipicker erfassen: Select-TaskPloppFile in Configuration.ps1
sowie Open/Save im Transfermodul. Eigene Validierungsrueckfragen der Picker ueber
vorhandene CheckFileExists/CheckPathExists/ValidateNames-Flags deaktivieren;
Save zusaetzlich OverwritePrompt=false und CreatePrompt=false. Danach unmittelbar
kleine eigene Path-/Extension-/Exists-Pruefung, erst dann Auswahl uebernehmen.
Fehler in der sichtbaren Statuskomponente, kein neuer Favorit/Import bei ungueltigem
Pfad. Kein selbstgebauter Dateibrowser. Explizite Dateiauswahl bleibt bestehen.

Nur ein kleines vorbereitetes Aktionsobjekt (Import/Export, Pfad, ggf. Paket).
Jede neue Auswahl, Exportaktion, Abbruch oder Schliessen verwirft die vorige
Vorbereitung; Anwenden nur fuer eine aktuelle gueltige Vorbereitung aktivieren.
Anwenden konsumiert/deaktiviert die Vorbereitung VOR dem Schreibaufruf; auch nach
einem Fehler kann kein alter Apply-Rest erneut ausgeloest werden. Nutzer muss bei
Fehler/unklarem Ausgang bewusst neu auswaehlen. Keine automatische Wiederholung.
Vor Anwenden Importsperre und normale bestehende Validierungen erneut pruefen.
Automatische Vorimport-Sicherung, Hotkeykonfliktbehandlung, Rohbytes und Verhalten
bei Fehlern nach dem Schreibpunkt unveraendert erhalten. Keine automatische Wiederholung.

## Scope und Schritte nach ausdruecklichem X/X+

M1: TaskPlopp.ps1 - zwei Toolbargruppen, gemeinsame Rand-/Breitenberechnung.
M2: TaskPlopp.Status.ps1 / TaskPlopp.Configuration.ps1 - vorhandene Meldungswege,
    fruehe Fehler und sichtbare Konfigurationsleiste; alle eigenen Popups entfernen.
M3: TaskPlopp.Transfer.ps1 - Vorschau/Anwenden und Inline-Ueberschreiben.
M4: Betroffene vorhandene UI-Tests an verschachtelte Toolbar anpassen; einen gezielten
    isolierten Layout-/Meldungstest ergaenzen, README knapp aktualisieren.
M5: Syntax/CRLF, fachliche Verifier, Diff/Eigencheck; laufende Instanz nur ohne
    Aufnahme/Einrichtung/offenen Entwurf kontrolliert aktualisieren. Git gemaess Auftrag.

PowerShell 5.1, kein eigener C#-/anderer Quellcode, keine Zusatzpakete.
Keine Config-/ZIP-Formataenderung, kein Speichern von Fenstergroessen,
keine Aenderung der bereits laufenden vergroesserten Standardansicht.
Keine Arbeit an Hotkey-, Audio-, Diktat-, Idle- oder Fensteraktivierungslogik ausser
deren Meldungsausgabe. Bestehende Nutzerdateien/Favoriten bleiben unangetastet.
Im P+-Cycle nur dieser Plan; gezielte notwendige Discovery isoliert ausserhalb Repo.

## Verifier / Akzeptanz

- Koordinaten in einheitlichem Hauptfenster-Clientbezug messen: linke/rechte
  Aussenabstaende gleich, Status-/Taskkanten deckungsgleich (Toleranz 1 Pixel).
- Viele/wenige isolierte Favoriten: Scrollbar erscheint/verschwindet; keine
  horizontale Scrollbar, kein verdeckter letzter Button, keine Layoutschleife.
  Lange echte Ueberschriften und Leerlistenhinweise muessen ebenfalls hineinpassen.
- 420x350 und 760x1200; normale und groessere Schrift; Tasks und Audio. Alle sechs
  Toolbarbuttons vollstaendig sichtbar in einer Zeile, links/rechts richtig geordnet,
  mindestens 12 Pixel zwischen Gruppen, Randabstand passend. DPI-Praxisbeleg getrennt.
- Farben, beide langen Zeilen/Laufschrift, Pegel, Fontwechsel und Ausblenden pruefen.
  Bestehende Toolbaraktionen, Tooltips, Kontextmenue/Transfer und Direktwahlnummern
  erhalten; gefaehrliche Aktionen im Layouttest nicht real ausloesen.
- AST-/Suchaudit: keine MessageBox/ShowBalloonTip/eigenen Meldungsfenster mehr in
  Produktpfaden. Explizite Bedien-/Dateidialoge und Tooltips getrennt inventarisieren.
- Screenshotfall ohne Citrix, geschlossenes Fenster, fehlendes Startziel,
  ungueltige Config beim Start, Hotkeykonflikt und ungueltige Eingaben beim Speichern:
  sichtbare passende Statusmeldung, kein automatischer Dialog, keine Configaenderung.
- Konfigurationsfehler bleiben im offenen Dialog lesbar; lokale Statuskomponente
  schliesst ihren Timer mit dem Dialog. Versteckte Hauptansicht wird nicht erzwungen.
- Importvorschau/Schliessen aendert weder Config noch Links noch Backups.
  Anwenden genau einmal mit bestehendem Speicherweg; fehlerhafte/abgebrochene neue
  Auswahl kann keine alte Vorbereitung anwenden.
- Filepicker-Flags und eigene Validierung mit ungueltigen Pfaden/Endungen pruefen:
  keine native Meldungsbestaetigung, keine ungueltige Auswahl uebernommen.
- UI-Ereignisfehler per isolierter Fixture: Statusfehler statt Standarddialog;
  kein rekursiver Handlerfehler, nach GUI-Ende kein haengender Handler.
- Vorhandene Export-ZIP bleibt bis explizitem Anwenden bytegleich; neue Exportdatei
  braucht keine Bestaetigung. Vor-/Nach-Save-Fehler und laufende Aufnahme/Installation
  behalten ihre Schutzwirkung. Alle bisherigen Transfer- und UI-Pruefungen bestehen.
- Keine echte PC-Sperre, Mikrofonaufnahme, Audioumschaltung oder Fremdfensteraktionen
  fuer Layout-/Meldungstests. Screenshots nur isolierter Testansichten.

## P+-Review

Fassung 1 (SHA256 9869F579B6B2FE0E6BBE17A1A8348FED198067C4373FB1E660493641879904B2)
unabhaengig durch transfer_plan_review geprueft. Befunde/Loesung in Fassung 2:
1. Lange AutoSize-Headings koennen horizontal ueberlaufen: gemeinsame Nutzbreite
   auch auf Headings/Leerhinweise anwenden, Wrap statt unbeschraenkter Breite.
   Erweiterter isolierter Prototyp mit echten Texten und Font 15 erfolgreich.
2. Alle Produkt-Filepicker statt nur Save-Overwrite erfassen; Flags und nachgelagerte
   eigene Validierung festgelegt. Kein neuer Picker.
3. Vorbereitete Transferaktion vor Apply konsumieren; keine Wiederholung nach Fehler.
4. Einzelnen UI-Exception-Handler vor erster Form/Handle registrieren, gegen Rekursion
   sichern und abmelden; kein Framework.
Fassung 2: unabhaengige Reviewfreigabe durch transfer_plan_review erteilt.
Gepruefter SHA256 C2DFC709B56ABC25D6475655DB399C6E651C03445D31CD53064F054B99D0BCB3.
Keine verbleibenden Blocker zu Machbarkeit, KISS, Scope oder Verifiern.
Diese abschliessende Statusnotiz aendert keine geprueften technischen Festlegungen.
Reale DPI-/Citrix-Pruefungen bleiben Praxisnachweise. Umsetzung erst nach Tobias'
ausdruecklichem X-/X+-Auftrag fuer diese Fassung; keine Produktumsetzung im P+-Cycle.

## X+-Ausfuehrung und Verifier

Tobias hat Fassung 2 mit X+ freigegeben und die Grenzen bekraeftigt: kein eigener
C#-Code, nur PowerShell, keine neuen Farben. M1 bis M5 technisch umgesetzt.
Die nachgereichte Idee eines KI-Fensterordners ist separate Zielanalyse; hier wurde
keine KI-Anbindung, Screenshotuebertragung oder Fensteranordnung implementiert.

Umsetzung:
- Standard-TableLayout mit ToolbarLeft/ToolbarRight, gemeinsame Raender und kleine
  Breitenfunktion statt absoluter Buttonpositionen. Lange Ueberschriften umbrechen.
- Status-Margin 10/3 Pixel ohne Scrollbar; bei Scrollbar deren Breite symmetrisch
  spiegeln. Vorhandener Hintergrund bildet den Rahmen; RGB-Palette unveraendert.
- Alle eigenen Meldungs-/Bestaetigungsboxen und Trayballoons entfernt. Fehlendes
  Favoritenziel oeffnet keine Konfiguration. Startfehler werden erst nach Aufbau
  der Leiste ausgegeben. Ein einzelner GUI-Exceptionhandler wird sauber abgemeldet.
- Konfiguration verwendet dieselbe Statuskomponente; lokale Timer werden entsorgt.
- Transfer zeigt Vorschau/Ersetz-Hinweis inline. Anwenden konsumiert die Vorbereitung
  vor dem Aufruf; keine Wiederholung alter Aktionen nach Abbruch oder Fehler.
  Native Picker-Rueckfragen deaktiviert, ausgewaehlte Pfade danach selbst geprueft.
- Bisherige grossere Fenstergroesse 760x1200/bildschirmbegrenzt erhalten. Keine neuen
  Configfelder, keine ZIP-Format-/Hotkey-/Audio-/Diktat-/Idle-Aenderung.

14 getrennte PS5.1-Prueflaeufe erfolgreich:
Native, Basis, Apps, Audio, AudioUi, Keyboard, IdleLock, Hotkey,
Dictation -Engines, DictationUi -Engines, Transfer, TransferUi, Layout, ResidentTest.
Lokaler Ergebnisnachweis:
%LOCALAPPDATA%\TaskPlopp\Discovery\20261107-Layout\implementation-regression.json.

Gezielte Verifier:
- 760x1200 und 420x350, Schriftgroessen 10/15, 0/3/30 Favoriten, lange echte
  Ueberschriften und Erscheinen/Verschwinden der Scrollbar. Task-/Statuskanten
  deckungsgleich, Aussenabstaende symmetrisch, keine horizontale Scrollbar.
- Alle sechs Toolbarbuttons in einer Zeile, richtige Reihenfolge und Mindestspalt.
- Kein-Citrix-Hinweis, geschlossenes Fenster, Fokusfehler, fehlendes Startziel,
  ungueltige Konfigurationseingabe, defekte Startconfig und GUI-Ausnahme als Status.
  Keine automatische Konfiguration, keine Fremdfensteraktionen in diesen Fixtures.
- Lokale Status-Laufschrift und Timerende geprueft; GUI-Exceptionhandler nach Ende
  per ThreadContext-Read nachweislich entfernt. Kein Standardfehlerdialog.
- Pickerflags an echten Dialogobjekten ohne Anzeige geprueft; ungueltige Pfade
  abgewiesen. Explizite Bedien-/Dateidialoge und Hover-Tooltips bleiben erhalten.
- Vorschau/Abbruch ohne Import; einmaliges Anwenden, Ersetzen erst nach Anwenden,
  neuer Export direkt; keine alte Aktion nach fehlerhafter/neuer Auswahl oder Apply.
  Importaufruf im UI-Test gezielt ersetzt; reale Backendfehler-/Rohbytes-Tests separat.
- Quellcodeaudit: keine Popupquellen oder eigenen Compilerpfade. Die RGB-Konstanten
  der betroffenen Produktdateien stimmen mit dem vorherigen Stand ueberein.
- Beide echten Engines mit synthetischer Sprache weiterhin vollstaendig, GUI-Heartbeat
  aktiv. Kein neuer Modelldownload, keine Mikrofonaufnahme/Audioumschaltung/PC-Sperre.

Bilder nur isolierter Testansichten: %TEMP%\TaskPlopp-layout-frame.png und
%TEMP%\TaskPlopp-transfer-inline.png. Kein Screenshot wurde an einen Dienst gesendet.

Vor Neustart laufende Instanz gelesen: keine offene Konfiguration/Transferansicht,
Mikrofonbutton 'Diktat starten' aktiv, keine Aufnahme/Erkennung/Installation.
Alte eigene Nachrichtenqueue sauber beendet, neuer versteckter PS5.1-Prozess gestartet;
Toolbarreihenfolge am neuen Prozess lesend bestaetigt. Config-Hash unveraendert.
Reale andere Windows-DPI-Skalierungen und Citrix-Vollbild/physische Tastendruecke
bleiben gesonderte Praxisbelege; isolierte Direktwahl ist kein Citrix-Nachweis.
Technische Pruefung erfolgreich. Git-Abschluss nach Diff-/Scopepruefung.