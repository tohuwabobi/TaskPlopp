# TaskPlopp: Audio-Ansicht und zweizeilige Meldungsleiste

Stand: 07.11.2026. Status: Review eingearbeitet; Implementierung am 07.11.2026 von Tobias beauftragt.
Ausgangsbasis: TaskPlopp main, Commit 80936135f28395ce754f02507af38743865a1c76.

## Ziel

Tobias kann Mikrofon und Lautsprecher direkt in TaskPlopp wechseln. TaskPlopp bleibt
das kleine Windows-PowerShell-5.1-/Windows-Forms-Tool mit einer Hauptoberflaeche.
Hinweise, Warnungen, Fehler und Erfolge erscheinen an einer gemeinsamen Stelle.
Die bestehende Fensterauswahl und die festen Favoritentasten bleiben erhalten.

## Vereinbarte Bedienung

1. Ein oberer Button **Audio** wechselt im vorhandenen Fenster zur Audio-Ansicht.
2. Die obere Buttonleiste und die neue Meldungsleiste bleiben sichtbar.
3. Unterhalb ersetzen zwei Spalten die Task-/Favoritenbuttons:
   **Lautsprecher** und **Mikrofone**. Die beiden Geraetearten sind getrennt waehlbar.
4. Ein Klick setzt das ausgewaehlte Geraet als Windows-Standardgeraet. Die Anzeige
   kennzeichnet anschliessend das tatsaechlich aktive Geraet mit **[Aktiv]** und Rahmen.
   Die vorhandenen zusammengehoerigen Geraetefarben werden soweit praktikabel uebernommen.
5. Der Audio-Button heisst in dieser Ansicht **Zurueck zu Tasks**. Er und **Escape**
   fuehren zur Task-Ansicht zurueck. Escape in einem offenen Kontextmenue schliesst
   zunaechst das Menue. Favoriten behalten ihre gespeicherte Reihenfolge und Tasten.
6. **Aktualisieren** aktualisiert die gerade sichtbare Ansicht. In der Audio-Ansicht
   werden angeschlossene/aktive Geraete und aktuelle Standards erneut eingelesen.
7. Beim erneuten Oeffnen ueber Strg+Alt+F10 oder das Tray-Symbol erscheinen die Tasks.
   Damit bleibt die bisherige blinde Favoritenauswahl moeglich.
8. Konfiguration bleibt der vorhandene separate Dialog. Nach dessen Schliessen
   wird die vorherige Hauptansicht erneut gezeichnet, nicht ungefragt die Taskliste.
9. **Citrix minimieren** behaelt sein bisheriges Verhalten. Audiowechsel selbst
   minimieren Citrix nicht und schliessen TaskPlopp nicht.

## Zweizeilige Meldungsleiste

Position: feste Hoehe zwischen oberer Buttonleiste und auswechselbarem Inhalt.
Die beiden Zeilen gehoeren jeweils zu genau einer aktuellen Meldung:

- Zeile 1: Art und kurze Aussage, z.B. **Erfolg: Mikrofon umgeschaltet**.
- Zeile 2: Geraetename, Handlungshinweis oder verstaendliches Fehlerdetail.
- Hinweise gelb/orange; Warnungen und Fehler rot; Erfolge gruen. Dunkle, lesbare
  Schrift und Textkennzeichnung ergaenzen die Hintergrundfarbe.
- Passt der Text in seine Zeile, steht er still. Ueberlanger Text laeuft horizontal
  als Laufschrift in dieser Zeile. Keine Scrollbar und kein wachsendes Meldungsfeld.
- Eine neue ausdrueckliche Meldung ersetzt die bisherige. Kein Verlauf, keine
  Warteschlange, keine Prioritaetsverwaltung, keine automatischen Popups oder
  Ablaufzeiten. Ohne neue Meldung bleibt auch ein Fehler einfach stehen.
- Initial darf die Leiste leer sein. Sichtbare Meldungen und Laufpositionen werden
  beim Aendern des Textes bzw. der Fenstergroesse passend aktualisiert.
- Die Leiste ersetzt Meldungen der neuen Audio-Funktion. Bereits vorhandene
  Meldungsboxen fuer Favoriten-/Konfigurationsfehler werden in diesem Schritt
  nicht pauschal umgebaut.

## Scope und bewusste Grenzen

Enthalten: Audio-Button, zwei Ansichten, Geraeteauswahl, verifizierte Rueckmeldung,
Aktualisieren, Escape, gemeinsame Meldungsleiste und deren Laufschrift.

Kein neues Audio-Konfigurationsmenue: Die Geraete werden automatisch erkannt.
Bestehende TDAudioSwitch-Preset-BATs sind keine Voraussetzung dieser Integration.
Geraetekombinationen wie Headset/Schreibtisch koennen spaeter folgen.

Nicht enthalten: Diktat/Transkription, API-Keys/Tresor/DPAPI, PC-Sperre,
Outlook-Schliesser, Lautstaerke/Mute, per-App-Audiorouting, Remote-Citrix-Konfiguration,
automatische USB-Ueberwachung, neue Dienste, Hintergrundjobs, Parallelzugriffe,
Sicherheitsrichtlinien oder eine Architektur fuer zukuenftige Erweiterungen.

## Vorhandene technische Basis

- `TaskPlopp.ps1`: Hauptform, obere FlowLayoutPanel-Leiste, fuellende ListPanel,
  Aufbau der Taskbuttons, Tray, Hotkey und bereits genau eine Application.Run-Schleife.
- `TaskPlopp.Keyboard.ps1`: KeyboardForm mit RegisterSelectionButton und
  ClearSelectionButtons fuer **1-9, 0, A-Z**, nur im aktiven Hauptfenster.
- `TaskPlopp.Configuration.ps1`: Am Dialogende wird derzeit direkt Update-WindowList
  aufgerufen. Das muss die aktuelle Ansicht beruecksichtigen.
- Lokale Quellen `C:\CodexProjekte\TDAudioSwitch\main.ps1` und `gui.ps1`:
  MMDevice-/Core-Audio-Erkennung, Geraete-IDs, ContainerId-Farben und PolicyConfig.
  `main.ps1 -ImportOnly` definiert Funktionen ohne die CLI zu starten.
- Der lokale TDAudioSwitch-Stand ist neuer als das separate GitHub-Repository.
  Fuer die Integration die lokalen Quellen lesen, nicht durch einen alten Download ersetzen.
- Die alte Audio-GUI besitzt ein eigenes Application.Run, globale script-Variablen
  und exit-Pfade. Sie soll nicht unveraendert in TaskPlopp gestartet/importiert werden.
- SetDefaultDevice setzt bereits **Console, Multimedia und Communications**.
  GetDefaultDevice liest bisher nur **Console**. Erfolg ueber alle drei Rollen ist
  daher mit der bisherigen Abfrage allein noch nicht nachgewiesen.

## Einfachster vorgeschlagener Aufbau

### Ansichten

Ein Wert `Tasks` oder `Audio` beschreibt die aktuelle Ansicht. Eine kleine
Anzeigefunktion zeichnet die aktuelle Ansicht. Beim Wechsel werden die bisherigen
Inhaltscontrols entsorgt und nur die gewuenschten neu aufgebaut. Keine zweite
Hauptform, keine verschachtelte Application.Run-Schleife und kein View-Framework.

Der obere Bereich wird als fester Container aus Buttonleiste und Meldungsleiste
angelegt, der Inhaltsbereich fuellt den Rest. Das vermeidet mehrdeutige Dock-Reihenfolgen.
Die Toolbar muss auch bei der minimalen Fensterbreite sinnvoll umbrechen/Platz haben;
die Meldungsleiste darf weder ueberdeckt werden noch die Inhalte verdecken.

### Audio

Nur die benoetigten Core-Audio-Funktionen und Interop-Definitionen aus dem lokalen
TDAudioSwitch in eine kleine `TaskPlopp.Audio.ps1` uebernehmen/anpassen. Keine
Laufzeitabhaengigkeit auf den benachbarten Projektordner. Keine ganze CLI und keine
Preset-Verwaltung mitkopieren. Quellenherkunft kurz dokumentieren.

Geraete beim Oeffnen und Aktualisieren lesen; zur Auswahl die Endpoint-ID benutzen.
Nach einem Wechsel die Standards fuer die betroffene Geraeteart und alle drei Rollen
zuruecklesen. Nur bei passender Rueckmeldung Erfolg anzeigen. Bei Teilfehlern oder
zwischenzeitlich entferntem Geraet die tatsaechlichen Standards neu anzeigen und eine
verstaendliche Meldung setzen. Kein Transaktions-/Rollback-System bauen.

Fehlt fuer eine Geraeteart ein Standard oder gibt es gar keine Geraete, darf die
andere Spalte weiterhin nutzbar bleiben. Kein unbeabsichtigtes Umschalten beim
Oeffnen, Aktualisieren, Anzeigen eines Fehlers oder Zurueckwechseln.

### Tastatur

Bei jedem Ansichtswechsel die vorhandene Direktwahlliste leeren. In der Audio-Ansicht
die Geraetebuttons mit derselben kleinen Registrierungsfunktion beschriften:
zuerst Lautsprecher, dann Mikrofone, insgesamt **1-9, 0, A-Z**. Bei Rueckkehr die
Taskbuttons mit der bisherigen festen Favoritenreihenfolge neu registrieren.
Es sind nie versteckte Taskbuttons ueber Audio-Tasten ausloesbar.

Escape in KeyboardForm minimal zurueck an die Hauptform melden oder gleichwertig
einfach behandeln. Keine neuen globalen Hotkeys. Normale Texteingaben in der
Konfiguration bleiben unberuehrt. Mehr als 36 Geraete bleiben per Maus/Tab waehlbar.

### Meldungen und Laufschrift

Eine Funktion nimmt Typ, Kurztext und Detailtext entgegen. Zwei geclippte
Textzeilen/kleine Zeichencontrols reichen. Textbreite einmal pro Text-/Groessenaenderung
messen. Ein gemeinsamer Windows-Forms-Timer verschiebt nur ueberlange Zeilen und
startet nach deren Durchlauf erneut. Kurze Texte brauchen keinen laufenden Timer.
Keine Threads, asynchronen Jobs, Message-Busse, Meldungsobjekthierarchien oder
allgemeinen Statusautomaten. Normale Eventhandler duerfen fuer die kleinen lokalen
Audioabfragen synchron bleiben; die Bedienbarkeit wird praktisch geprueft.

## Umsetzung in drei kleinen Milestones

1. **Oberflaeche:** Fester oberer Bereich, Audio-/Tasks-Wechsel, Zurueck/Escape,
   Direktwahlliste je Ansicht. Akzeptanz: keine zweite Hauptform, keine verschobenen
   Favoritentasten und saubere Darstellung auch bei minimaler Breite/Skalierung.
2. **Audio und Meldungen:** Geraete lesen/waehlen, alle Rollen pruefen, Aktivanzeige,
   zweizeilige Farbmeldungen und Laufschrift. Akzeptanz: Erfolg ist rueckgelesen;
   fehlende Geraete/Fehler lassen das Fenster benutzbar; nichts schaltet ungefragt um.
3. **Gezielte Pruefung und Dokumentation:** Bestehende sinnvolle Tests, kleine Tests
   fuer Ansichts-/Tastenzuordnung und Meldungslayout, manuelle Hardwarepruefung.
   Akzeptanz: untenstehende Verifier erfuellt, README aktualisiert, CRLF beibehalten.

## Verifier

- **Regression:** Strg+Alt+F10, Tray, Ausblenden/erneutes Oeffnen, Start/Wechsel von
  Favoriten und deren feste Tasten funktionieren wie bisher.
- **Ansicht:** Audio ersetzt die Tasks im selben Fenster. Toolbar und zweizeilige
  Leiste bleiben stehen. Zurueck/Escape und Konfigurationsrueckkehr stimmen.
- **Tasten:** Audio-Zahlen loesen nur Audiobuttons aus; danach liegen die Favoriten
  wieder auf ihren alten Tasten. Kontextmenues und Eingabedialoge bleiben bedienbar.
- **Auswahl:** Wiedergabe und Mikrofon jeweils einzeln testen; alle drei Rollen
  unabhaengig zuruecklesen. Oeffnen/Aktualisieren/Zurueck veraendert keine Standards.
- **Sonderfaelle:** Keine Geraete, fehlender Standard, doppelter Geraetename,
  Abziehen nach Auflisten, ungueltige ID und fehlgeschlagener/teilweiser Wechsel.
- **Meldungen:** Hinweis orange, Warnung/Fehler rot, Erfolg gruen; kurze Texte
  still, lange in beiden Zeilen laufend; keine Scrollbar. Resize sowie 100/150-Prozent-
  Skalierung pruefen. Alte Laufschrift stoppt bzw. passt nach einer neuen Meldung.
- **Hardware:** Lautsprecherwechsel tatsaechlich anhoeren und gewaehltes Mikrofon
  praktisch pruefen. Testaenderungen anschliessend auf vorherige Geraete zurueckstellen.
- **Citrix:** Fensterbedienung im Vollbild pruefen. Audio in einer laufenden Sitzung
  separat beobachten; keine Zusage, dass jede Anwendung neue Windows-Defaults
  automatisch uebernimmt. Keine Citrix-Richtlinien aendern.

## Auftrag an den unabhaengigen Reviewer

Plan und tatsaechlichen Code lesen, keine Implementierung beginnen. Technische
Unmoeglichkeiten, konkrete Integrationsfehler und vermeidbare Komplexitaet nennen.
Fuer jede Beanstandung die einfachste praktikable Alternative angeben. Besonders
Docking, KeyboardForm, bestehende Update-WindowList-Aufrufe, Default-Rollen,
Application.Run und die zweizeilige Laufschrift pruefen. Alles, was ohne Nutzen
eine allgemeine Infrastruktur einfuehrt, streichen. Ergebnis im Review-Chat liefern;
Projektdateien nicht aendern. Die Loesung darf schlicht sein.

## Praezisierung nach unabhaengigem KISS-Review

- Bei allen COM-Methoden mit HRESULT-Rueckgabewert wird PreserveSig gesetzt.
  PROPVARIANT wird passend zur Prozessarchitektur abgebildet. Verwendete COM-
  Referenzen werden nach den kurzen synchronen Operationen freigegeben.
- Console, Multimedia und Communications werden einzeln gelesen. Stimmen die
  IDs ueberein, steht am Geraet [Aktiv]. Andernfalls nennen die Geraetebeschriftungen
  ihre tatsaechlichen Rollen. Nicht lesbare Rollen werden als fehlend/unbekannt
  benannt, nicht als erfolgreicher Zustand ausgegeben. Keine Rollback-Infrastruktur.
- Task-Resize arbeitet nur in der Taskansicht. Audio bekommt einen zweispaltigen
  Inhaltscontainer. Die Toolbar darf umbrechen und waechst dann in der Hoehe.
- Nach einem Audiowechsel wird die kleine Audioansicht neu gezeichnet: zuerst
  Aktivanzeige und Rollentext setzen, dann Direktwahltasten genau einmal vergeben.
  So verschwinden keine Tastenpraefixe und kein zweites Zuordnungssystem entsteht.
- Nur Aktualisieren und Konfigurationsrueckkehr benutzen die aktuelle Ansicht.
  Die anderen bisherigen Task-Callbacks bleiben taskbezogen. Hotkey/Tray oeffnen Tasks.
- Zwei geclippte Textzeilen und ein gemeinsamer Forms-Timer reichen fuer Laufschrift.
  Der Timer wird bei kurzen Texten/unsichtbarer Hauptform angehalten und beim
  endgueltigen Beenden entsorgt. Neue Texte setzen nur ihre Laufposition zurueck.
- Die Core-Audio-Interop darf aus Gruenden der Lesbarkeit in TaskPlopp.Audio.cs
  liegen; TaskPlopp.Audio.ps1 laedt sie bei der ersten Audioabfrage. Kein Buildsystem.
- Gezielt pruefen: Audio nach Tasks und zurueck, Escape mit offenem Kontextmenue,
  Rollenteilzustand, Tastaturpraefixe nach Neuaufbau, minimale Breite und Skalierung.
  Keine breite neue Testarchitektur. Reales Zuruecklesen ist automatisierbar;
  Hoer-/Mikrofonprobe und Citrix-Verhalten bleiben vor Ort zu bestaetigen.
## Umsetzungsstand 07.11.2026

Die drei Milestones sind implementiert. Audioansicht und Meldungsleiste verwenden
weiter dieselbe Hauptform und Nachrichtenschleife. Nach dem Wechsel werden die
Geraete neu aufgebaut und die Tastenpraefixe erneut gesetzt. Drei Rollen werden
separat gelesen; teilweise belegte Rollen bleiben sichtbar. Resize behandelt
Taskbuttons und Audiospalten getrennt. Der Laufschrift-Timer ruht bei versteckter GUI.

Geprueft: drei Wiedergabe-/zwei Aufnahmegeraete erkannt; beide Geraetearten real
umgeschaltet, alle drei Rollen zurueckgelesen und urspruengliche Standards je Rolle
wiederhergestellt. Gezielte Tests bestehen fuer COM/PROPVARIANT, Rollenabweichungen,
Teilfehler, entferntes/leeres Geraet, Audio/Tasks, Konfigurations-/Hotkey-Rueckkehr,
bewegte Laufschrift beider Zeilen, Farben, Timerpause, Minimumgroesse und grosse Schrift.
Bestehende Favoriten-/Konfigurationstests und der Resident-Test bestehen ebenfalls.

Offen fuer den lokalen Praxistest: echte Tastatureingaben und Escape/Menues (die
Testsitzung stellt kein aktives Desktopfenster bereit), tatsaechliche Windows-DPI-
Skalierung, Hoer-/Mikrofonprobe und Citrix-Audiouebernahme. Die Testausgabe benennt
die uebersprungenen aktiven Tastaturpruefungen ausdruecklich. Keine Citrix-Regeln,
keine andere App und kein Quellcode im separaten TDAudioSwitch-Projekt veraendert.