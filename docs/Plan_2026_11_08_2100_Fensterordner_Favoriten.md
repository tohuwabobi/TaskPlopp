# Fensterordner: minimierte Fenster, Maximieren und Favoriten - P+

Stand 08.11.2026, Basis 72d04bd. Tobias beauftragt P+, noch kein X/X+.

## Ziel / Beispiele
"Maximiere Chrome" beruecksichtigt ein bereits minimiertes Chrome-Fenster.
"Chrome hspwo.de und Downloads nebeneinander" kann die benannten Favoriten starten,
wenn erforderlich, und die passenden Fenster anordnen. "Maximiere Chrome hspwo.de"
verwendet den benannten Favoriten einschliesslich seines gespeicherten Profilstarts.
Vorhandene normale Fenster und die bisherige Anordnung funktionieren weiter.

## Scope / KISS
PowerShell 5.1, vorhandene Mikrofon-/Transkriptionsstrecke, Responses API, DPAPI,
Statusleiste und ein Undo-Snapshot im RAM. Keine neue GUI/Popup/Farbe, kein C#,
keine parallelen Worker, keine weitere KI-Runde und kein neues Paket.
Nur vorhandene geeignete lokale Fenster und konfigurierte Favoriten. Keine frei
von der KI gelieferten Pfade/Argumente/Programme ausfuehren. Keine Fenster schliessen,
keine anderen Fenster minimieren, keine Citrix-Innenfenster/virtuellen Desktops steuern.
Favoritennamen statt neuer Alias-/Profilverwaltung nutzen. Kein Chrome-Interna-/
UI-Automationssystem zur Ermittlung beliebiger Profilfenster bauen.

## Discovery / vorhandene Bausteine
- Get-TaskPloppLayoutContext schliesst IsIconic ausdruecklich aus; Set-TaskPloppLayout
  lehnt minimierte Ziele nochmals ab. DWM-Rechtecke koennen im minimierten Zustand
  ungeeignet sein; diese duerfen kein Grund sein, ein sonst geeignetes Fenster zu verlieren.
- Antwortschema kennt bisher nur Fenster-ID und Rechteck, keinen Zielzustand.
- Get-AppWindows/TaskPloppSwitchable liefern Alt+Tab-artige Fenster, grundsaetzlich
  einschliesslich minimierter Fenster. Ausschluss unsichtbarer Hilfs-/Toolfenster bleibt.
- Test-WindowMatch und Start-FavoriteApplication mit Preview unterstuetzen bestehende
  Identitaeten, Titelfilter, FolderPath, EXE/LNK/AppId. LaunchAlways wird bewusst fuer
  Profilstarts verwendet. Browser-Prozessname/EXE allein unterscheiden Profile nicht.
- Lokale Probe ausserhalb Repo: %LOCALAPPDATA%\TaskPlopp\Discovery\20261108-LayoutFavorites\Probe-MinMax.ps1.
  Nur eigene Testform, PS5.1, vorhandene Metadaten-APIs. Minimiert aus Normal/Maximiert ->
  echtes Maximieren -> vorhandenes Placement-Undo -> wieder minimiert -> Restore ergibt
  jeweils den urspruenglichen Normal-/Maximiertzustand. Beide Faelle bestanden, Flags 0/2,
  bestehender 44-Byte-Placementvertrag auf diesem Windows bestaetigt. Keine Benutzerfenster,
  Programme, Mikrofone, Screenshots oder API-Anfragen betroffen.
- Microsoft beschreibt Monitorermittlung mit Rechteck vor Minimierung und die Bedeutung
  von WPF_RESTORETOMAXIMIZED. Aktuelle Headerdokumentation zeigt zusaetzlich rcDevice;
  nicht blind die lokal funktionierende 44-Byte-ABI aendern, sondern vorhandenen Vertrag nutzen.

## M1: Zielkatalog und KI-Vertrag
1. GUI uebergibt neben Intent/Modell/ParentProcessId eine Kopie der aktuellen Favoriten
   an den bestehenden Plan-Worker. Vollstaendige Startziele bleiben lokal; kein Config-
   Dateipfad beim Worker neu einlesen und keine Favoritenkonfiguration schreiben.
2. Context behaelt echte Windows mit w1 usw. und ergaenzt Favorites mit f1 usw.
   IDs gelten nur fuer diesen Auftrag. Lokale Favoritenkopie und native Identitaeten
   bleiben im Context. Fuer Test-WindowMatch benoetigte ExecutablePath/AppId/FolderPath lokal mitfuehren; an KI gehen nur IDs, Namen, Prozess-/Fenstertitel, Fensterzustand,
   Monitor und ggf. nach bestehender Matchregel eindeutig bekannte Fenster-IDs.
   Keine EXE-/LNK-Pfade, Argumente oder Schluessel als KI-Startauftrag verwenden.
3. Minimierte Fenster mit minimized=true aufnehmen. Keine ungueltigen DWM-/Minus32000-
   Rechtecke als normale Lage senden: x/y/width/height duerfen fuer diesen INPUT null sein;
   letzter Monitor ueber Windows-Screen.FromHandle. Normal-/Maximiertzustand und Name
   reichen fuer Planung. Nicht minimierte Fenster behalten bisherige physische Rechtecke.
4. NO_WINDOWS entfaellt als Abbruch, sobald mindestens ein Fenster ODER Favorit vorhanden
   ist. Ohne jegliche Kandidaten Statushinweis. Screenshot weiterhin aktueller Desktop,
   minimierte/geschlossene Kandidaten werden anhand Metadaten geplant. Aufnahme/Capture-
   Hide/CaptureDone/RAM-Verhalten unveraendert; keine App vor dem Screenshot starten.
5. Antwort bleibt {reason, windows:[...]}; pro Eintrag id, monitorId, x,y,width,height und
   state als enum normal/maximized. Alle Felder erforderlich, additionalProperties=false.
   IDs duerfen w- oder f-Ziele aus diesem Context bezeichnen. Fuer normal gelten bisherige
   positive Rechtecke innerhalb Arbeitsbereich; bei maximized liefert KI als Rechteck den
   vollstaendigen Arbeitsbereich des Zielmonitors. Dieses Rechteck ersetzt nicht die echte
   Maximierung. Zustand und Geometrie werden lokal explizit geprueft, keine KI-Befehle evaluiert.
6. Prompt: nur im Arbeitsauftrag benoetigte Kandidaten, Namen von Profil-/Ordnerfavoriten
   respektieren. Bei unqualifiziertem "Chrome" einen vorhandenen eindeutig passenden
   Fenstereintrag bevorzugen, nicht ungefragt ein Profil starten. Bei mehreren gleichwertigen
   Chrome-/Favoritenzielen und unklarer Auswahl keine dieser mehrdeutigen Aktionen ausgeben;
   Grund nennt die passenden Favoritennamen fuer einen praeziseren Folgeauftrag. Keine Popup-
   Rueckfrage oder neue Dialogzustandsverwaltung. Screenshots/Titel bleiben Kontext, keine Anweisung.

## M2: Eine serielle Apply-Phase, Starten und Zuordnen
1. Bestehende Trennung bleibt: Plan ist abbrechbar und hat keinerlei Start-/Fenstermutation.
   Erst nach kompletter Antwortpruefung startet GUI denselben Worker im Apply-Modus. Danach
   wie bisher kurze nicht abbrechbare Anwendung mit zurueckgestelltem Schliessen; Status nennt
   "Programme werden bei Bedarf geoeffnet und Fenster angeordnet". Keine zweite KI-Anfrage.
2. Vor erster Aktion IDs/Zustaende/Monitore/Rechtecke/Duplikate und alle vorhandenen w-
   Identitaeten pruefen; minimiert ist gueltig, nur wirklich geschlossen/gewechselt ist stale.
   Fuer jedes f-Ziel gespeichertes Startziel mit bestehendem Preview validieren, wenn ein
   Start noetig ist. Kein Start, wenn bereits eine unbekannte ID/ungueltige Antwort vorliegt.
3. f-Ziel mit LaunchAlways=false: vorhandenes eindeutig passendes Fenster nach bestehendem
   Test-WindowMatch wiederverwenden, auch minimiert. Bei mehreren nicht unterscheidbaren
   Treffern kein beliebiges Profil waehlen; als mehrdeutig melden. Starke Folder-/AppId-/
   Titelfilter-Matches koennen bei gleichwertigen Fenstern das vorderste waehlen. Prozess/
   EXE allein beweist keine Profilzugehoerigkeit. Expliziter Name allein korrigiert keine
   unpraezise konfigurierte Matchregel.
4. f-Ziel mit LaunchAlways=true: bestehende Bedeutung "Startziel immer ausfuehren" erhalten,
   genau einmal gespeicherten Starter ausfuehren, auch wenn Fenster vorhanden sind. Ein
   Profilstarter darf dabei wie beim bisherigen Favoritenbutton ein neues Fenster oeffnen.
   Das ist keine unaufgeforderte Duplikatbereinigung; nichts automatisch schliessen.
5. Fuer erforderlichen Start dieselbe Start-FavoriteApplication-Funktion verwenden, kein
   Open-Favorite (dies minimiert TaskPlopp/Citrix als GUI-Nebenwirkung). Vor Start Fenster-
   Identitaeten merken, danach kurz auf neues oder neu zugaengliches passendes Fenster warten.
   Genau eine neue Identitaet plus Favoritenmatch nach dem seriellen bekannten Starter: praktisch zuordnen. Das ist eine zeitliche Heuristik, kein allgemeiner Beweis fuer Chrome-Profilzugehoerigkeit. Entsteht nebenher ein anderes neues passendes Browserfenster, kann die einfache Zuordnung falsch liegen; das wird nicht durch ein Parallelzugriffs-/Profil-Framework ausgeschlossen. Wiederverwendetes bestehendes
   Fenster nur bei belegter spezieller Folder-/AppId-/Titelfilterzuordnung akzeptieren; kein
   Raten allein aus Vordergrund/letztem Prozess. Falls Launcher kein zuordenbares Fenster
   liefert, mehrere Kandidaten aufweist oder Timeout: Status mit Favoritenname und keine Geometrie anwenden. Bei genau einem neuen passenden Fenster gilt die vorgenannte bewusst begrenzte Heuristik.
6. Starts nacheinander, gemeinsames Wartebudget fuer alle benoetigten Starts maximal 15 Sekunden,
   nicht 15 Sekunden pro Favorit. Kein naechster Start ohne Restbudget; Polling nur im Worker,
   GUI bleibt bedienbar. Das begrenzt Polling, nicht eine haengende synchrone Process.Start-/Shell.COM.InvokeVerb-Funktion im bestehenden Starter. Keine harte Gesamt-Wallclock-Garantie behaupten und keinen weiteren Launcher-Prozess nur dafuer bauen. Langsame Programme koennen beim naechsten Auftrag bereits gefunden werden.
7. Nach Aufloesung aller Ziele vor jeder Geometrie nochmals Identitaeten/Monitore und doppelt
   auf dasselbe HWND aufgeloeste f-/w-Ziele pruefen. Bei Doppelbelegung/ungeklaertem Start keine
   Geometrie anwenden. Schon gestartete Programme bleiben offen, Warnung nennt das Ergebnis.
   TaskPlopp fuehrt bei diesem Vorbereitungsfehler keine eigenen Restore-/Geometrieschritte aus. Nebenwirkungen bereits ausgefuehrter Starter (auch Wiederherstellen/Maximieren alter Fenster) bleiben wie Programmstarts bestehen; keine atomare Start-Ruecknahme.
8. Es ist keine atomare Ruecknahme von Programmstarts versprochen. Startfehler, fehlende Datei,
   nicht installiertes AppId-Ziel, verspätetes/mehrdeutiges Fenster sind sichtbare Ergebnisse;
   keine stillen Retries. Falls keine Geometrie veraendert wurde, bisherigen Undo behalten.

## M3: Wiederherstellen, Maximieren und Undo
- Vor jedem erforderlichen Start zusaetzlich die Placements der schon vorhandenen passenden Kandidaten lokal nach Handle/PID/Startzeit sichern. Wenn ein Kandidat eindeutig wiederverwendet wird, kommt dessen Vorstart-Placement ins Undo, denn bereits der Starter kann ihn wiederherstellen/maximieren. Nicht ausgewaehlte Kandidaten niemals mit zuruecksetzen. Bei neuen Identitaeten erst den Zustand nach Start sichern.
- WINDOWPLACEMENT der konkreten Ziele vor erster Zustands-/Geometriemutation sichern,
  insbesondere VOR Restore eines minimierten Fensters. Bestehende Identitaetspruefung behalten.
- state=normal: falls minimiert/maximiert normal wiederherstellen, begrenzt auf IsIconic=false
  und IsZoomed=false warten; dann bisherigen sichtbaren Rahmenoffset/Rechteckpfad verwenden.
- state=maximized: aus minimiert/normal bei Bedarf normalisieren, auf den Zielmonitor mit
  vorbereitetem Normalrechteck bringen, dann echtes ShowWindowAsync(SW_MAXIMIZE=3). Erfolg
  anhand IsZoomed=true, IsIconic=false und richtigem Monitor bestaetigen; keine pixelgenaue
  Gleichheit zwischen Maximierrahmen und Arbeitsbereich erzwingen. Mindestgroessen/Access-
  Probleme bleiben Warnungen. Vorhandene asynchrone Calls und endliche Wartezeiten nutzen.
- Ein RAM-Undo-Snapshot wie bisher. Bei vorher minimiertem Ziel wieder minimieren; Flags einschl.
  WPF_RESTORETOMAXIMIZED erhalten. Verifikation darf nur WPF_ASYNCWINDOWPLACEMENT ausmaskieren,
  nicht das relevante Restore-Flag ignorieren. Normale/maximierte Fenster weiter korrekt.
- Neu gestartete Fenster: initiales Placement nach Start und vor Anordnung sichern; Undo
  stellt diese Ausgangslage wieder her. Programme bleiben offen. Kein Beenden neuer Prozesse,
  auch wenn Shell/Chrome Start-PID und eigentlicher Fensterprozess unterschiedlich sind.
- Geometrie-Teilfehler liefern Snapshot fuer bereits angefasste Ziele. Erfolgs-/Warnmeldung
  unterscheidet gestartet, passend angeordnet/maximiert und nicht aufgeloest; keine falschen
  Komplett-Erfolgsmeldungen. Rueckgabe bleibt eine finale Ergebniszeile, kein Fortschrittsframework.

## Dateien / Umsetzungsschritte nach Freigabe
- src/TaskPlopp.WindowLayout.ps1: Katalog, Schema/Prompt/Validierung, f-Aufloesung, Zustandswechsel,
  Zeitbudget, Undo und Statuszusammenfassung; kleine lokale Helfer, keine allgemeine Jobverwaltung.
- src/TaskPlopp.WindowLayoutWorker.ps1: Request-Favoriten, Kandidatenleere und erweiterte Apply/
  Fehlerresultate. Bestehende DPI-Kontext-Reihenfolge und CaptureDone-Vertrag beibehalten.
- Vorhandene Apps-/Native-Helfer nutzen; src/TaskPlopp.Apps.ps1 nur falls eine kleine gemeinsame
  Match-/Start-Ergaenzung erforderlich ist. Keine neuen eigenen C#-/IL-Funktionen. Konfiguration,
  Keyablage, Autostart, Sofortspeichern und Leertaste nicht als Nebenumbau aendern.
- tests/Test-TaskPloppWindowLayout.ps1 gezielt erweitern, fuer eigene Startfixture ggf. kleine
  PS-Testdatei unter tests/fixtures. README und neuer Verifier; alte erfolgreiche Praxistests
  als historischen Stand erhalten, neue Abnahme getrennt.

## Verifier / automatische Abnahmetests
1. Reale eigene Fixtures: Normal/Maximiert/Minimiert aus Normal/Minimiert aus Maximiert als
   Eingangsfaelle, echte Maximierung, normales Zielrechteck, Undo einschliesslich Restoreflag
   und spaeterem Restorezustand. Unbeteiligte Kontrollfixture unveraendert. Kein Nutzerfenster bewegen.
2. Minimierte Kandidaten mit fehlendem DWM-Rechteck bleiben im Katalog; Hilfsfenster bleiben draussen.
   Nur Favoriten ohne offene Fenster darf Plan-Katalog ergeben; unbekannte/mehrdeutige IDs, falscher
   Zustand, falsche Bounds/Monitor und Doppel-HWND vor Mutation ablehnen.
3. Reale kleine selbst gestartete Test-App/Fenster ueber vorhandenen EXE/LNK-Startvertrag (Parameter in LNK, keine neue Argument-Eigenschaft): Favorit ohne
   Fenster starten und anordnen; minimiertes eindeutiges Match wiederverwenden ohne Start;
   LaunchAlways einmal ausfuehren; Starter wiederverwendet minimiertes vorhandenes Ziel -> Undo stellt dessen Vorstart-Minimierung/Restoreflag her. Start-PID nicht mit HWND-Besitzer gleichsetzen. Test-AppId
   mit bestehender Shell-Grenze simulieren, kein echtes Benutzerprogramm installieren/starten.
4. Profil-/Ordnerersatzfixture: zwei gleichnamige Prozesse/Fenster, nur eindeutig zugeordnete
   Start-/Folder-/Titelfilteridentitaet bewegen. Falsche Vordergrundfenster und mehrdeutige
   neue Fenster nicht beliebig zuordnen. Ein einzelnes neu erschienenes passendes Fenster nach seriellem Start wird als dokumentierte Heuristik akzeptiert; der Fall gleichzeitig neu erscheinender anderer Profile ist keine automatisch ausgeschlossene Fehlzuordnung. Polling-Zeitbudget, fehlendes Startziel,
   keine Fenster/verspaetetes Fenster und Stale-/Topologieaenderung nach Start kontrollieren.
5. Startfehler nach vorherigem erfolgreichen Start: neue App bleibt offen, andere Fenster
   ohne eigene TaskPlopp-Restore-/Geometrieschritte, Warnung korrekt. Bereits erfolgte Starter-Nebenwirkungen bleiben bestehen. Undo nach Erfolg laesst neue App offen und
   bringt alte minimierte Fenster zurueck in den vorherigen Zustand. Test-Apps danach nur
   als eigene Fixtures sauber beenden. Alte Undo-Historie nicht als neuen Start-Undo ausgeben.
6. Synthetische API-Probe nach X+: minimiertes Chrome w-Ziel maximieren; nur geschlossene
   Lieblings-App f-Ziel normal anordnen; zwei Profilnamen eindeutig/unbestimmt. Nur Fake-
   Titel und gezeichnetes Bild, keine realen Desktop-/Favoritendaten senden. Response-Schema,
   enum und Auswahl pruefen, kein Nachweis beliebiger KI-Zuverlaessigkeit. Bestehenden
   DPAPI-Key weiterverwenden, kein neuer Schluessel erforderlich.
7. Regressionen: vorhandene normale Anordnung/Undo, DictationUi mit Fake-Audio, Key-/Status-
   Verhalten, Space/Minimize/Tray und passende Native-/Apps-Tests. Kein API-/Audiotest mit
   produktivem Desktop und keine Aenderung von Configs/LNKs in automatischen Tests.

## Manuelle Abnahme mit Tobias nach X/X+
Auf GANDALF ausreichend als erster Praxisbeleg: nur Chrome minimiert -> "Maximiere Chrome" ->
vorhandenes Fenster echt maximiert, Undo wieder minimiert. Dann geschlossener benannter Favorit
z.B. Downloads -> Start + Anordnung -> Undo laesst Explorer offen und stellt Ausgangslage her.
Chrome-Profilfavorit namentlich: gespeichertes Profil wird gestartet und das praktisch zugeordnete
Fenster behandelt; dabei pruefen, ob der reale Starter ein neues passendes Fenster liefert oder ein bestaetigbares vorhandenes wiederverwendet. Keine allgemeine profilgenaue Identitaet behaupten. LaunchAlways-Verhalten vorher bewusst beibehalten. Unbestimmtes "Chrome"
bei mehreren Profilen muss bei unklarer Auswahl hilfreichen Hinweis statt falscher Zuordnung
geben. Kein Browserprofil-Introspektionssystem als Voraussetzung. Echte Mehrmonitor-/Mixed-DPI-
Pruefung nur falls Hardware vorhanden; sonst offen benennen. Vorschlag, Start und Ergebnis
im Status verfolgen; keine Popups. Diese Praxistests sind noch nicht durchgefuehrt.

## Quellen
Lokaler Code 72d04bd und isolierte Probe nur mit eigener Form, 08.11.2026.
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfromwindow
https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-windowplacement
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showwindowasync
https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses

## Unabhaengiges Review
Freigegeben durch unabhaengigen Reviewer transfer_plan_review gegen Code 72d04bd. Gepruefter Inhaltsstand vor diesem Vermerk: SHA256 7AFFABA7FE6A9677C23CAB15CD64A751233C4BBA3267159E712D42D387ABE746. Keine verbleibenden Blocker. Eingearbeitet: Vorstart-Undo fuer wiederverwendete Fenster; begrenzte zeitliche Profilheuristik statt unbelegter Profilgarantie; 15 Sekunden nur als Pollingbudget; Starter-Nebenwirkungen ohne atomare Ruecknahme klar benannt. Keine Produktdateiaenderung oder X-Freigabe durch dieses Review.
## Ausfuehrung nach X+
Tobias hat X+ erteilt. Umsetzung im vereinbarten Dateiscope. Die synthetische KI-Probe waehlte trotz expliziter Anweisung ein beliebiges Profil. Kleine Ergaenzung: Bei Favoriten mit gleichem Prozessnamen prueft PowerShell einen im Auftrag genannten unterscheidbaren Namensbestandteil. Unklare Favoritenaktionen entfallen mit Hinweis; keine weitere KI-Runde oder Aliasverwaltung. Der Test mit widerspruechlichem gezeichnetem Editorbild wurde fuer die reinen Profil-/Favoritenproben durch Metadaten ohne Bild ersetzt; der separate Bildtest bleibt bestehen.
