# TaskPlopp nur waehrend der Bedienung im Vordergrund - P+

Stand 08.11.2026; Basis f30f56c. Planung, noch keine X-/X+-Freigabe.

## Ziel
Hotkey oder explizites Oeffnen bringt TaskPlopp nach vorne, auch ueber Citrix im
Vollbild. Wechselt Tobias zu einem anderen Programm, bleibt TaskPlopp als normales
Fenster offen und verdeckt dieses nicht dauerhaft. Der naechste explizite Aufruf
holt TaskPlopp wieder nach vorne. Keine Citrix-Erkennung und kein neuer Schalter.

## Discovery
Main.TopMost ist aktuell dauerhaft true. Zusaetzlich setzt Raise-TaskPloppWindow
in TaskPlopp.Native.ps1 per SetWindowPos(HWND_TOPMOST) den nativen Zustand. Nur die
Initialisierung auf false zu setzen genuegt deshalb nicht. Aufrufe stehen in
Show-TaskPlopp und beim ersten Shown. Eigene Konfiguration und Transfer verwenden
ShowDialog(Main), Dateiauswahl und Picker ebenfalls Owner-Beziehungen.
Vorhandener GUI-Timer prueft alle 150 ms das WakeEvent und laeuft auch in modalen
WinForms-Dialogen. Vorhandene ABI-Deklarationen liefern GetForegroundWindow,
GetAncestor(GA_ROOTOWNER=3), GetLastActivePopup, GetWindowLongPtrW und SetWindowPos.

## Scope / uebliche Leitplanken
PowerShell 5.1, kein eigener C#-/JS-/TS-Code, kein Compiler, keine Pakete/Adminrechte.
Keine neue GUI, Farbe, Popup, Konfigurationsoption, Speicherung, Hotkey-Aenderung,
Citrix-Erkennung, Hook, weiterer Timer/Thread oder allgemeines Fensterstatussystem.
Nur src/TaskPlopp.ps1 fuer Verhalten; bestehende ABI-Funktionen weiterverwenden.
Tests: tests/Test-TaskPloppKeyAndWindow.ps1; bei noetiger eigener externer GUI-Fixture
kleine PS5.1-Datei unter tests/fixtures. README.md und neuer Verifier unter docs.
TaskPlopp.Native.ps1 nur lesen; vorhandene Raise-Funktion bleibt bekanntes natives
Anheben, alle produktiven Aufrufpfade muessen zum nachstehenden Lifecycle passen.
Keine produktiven Nutzerfenster fuer automatisierte Fokus-/Ueberdeckungstests verwenden.

## Spec / einfachste praktikable Loesung
1. Main beginnt mit TopMost=false. Explizites Oeffnen ueber Hotkey/Tray/Verknuepfung
   sowie erstmaliges Anzeigen setzt Main.TopMost=true vor dem nativen Anheben.
   Damit stimmen WinForms-Zustand und native Topmost-Eigenschaft zusammen.
   Kein erneutes Festhalten allein durch Activated, Aktualisieren oder Timer.
2. Bestehenden 150-ms-Wake-Timer um eine kurze Pruefung erweitern, nur solange
   Main.TopMost=true und das Hauptfenster sichtbar und nicht minimiert ist.
   Ist das Vordergrundfenster Main oder ueber GA_ROOTOWNER von Main besessen,
   bleibt das zeitweilige Topmost erhalten. So bleiben Konfiguration, Transfer,
   Picker, Dateidialoge und Menus ohne eigene dauerhafte Fensterbeobachter bedienbar.
   Handle 0 waehrend eines Fokusuebergangs: in diesem Tick nichts tun.
3. Ist ein fremdes Fenster im Vordergrund, Main.TopMost=false setzen. Keine
   Aktivierung, kein SetForegroundWindow und kein Zwangs-Minimieren dabei.
   Kein erneutes Anheben, bis Tobias TaskPlopp wieder explizit aufruft.
   Windows demotiert beim Zuruecksetzen des Topmost-Owners auch dessen owned windows;
   den nativen Stil der eigenen Dialoge in den Tests mitpruefen.
4. Minimieren, X-Ausblenden und Layout-Capture-Hide geben das zeitweilige Topmost
   ebenfalls frei. Das im vorhandenen VisibleChanged/Resize-Pfad oder direkt in den
   vorhandenen Minimieren-/Ausblendenpfaden klein integrieren. Internes Wiederzeigen
   nach Screenshot/Fehler pinnt nicht automatisch, solange kein expliziter Aufruf erfolgt.
5. Expliziter Aufruf bei offenem eigenem Dialog soll diesen aktivieren, statt das
   deaktivierte Hauptfenster vorzuziehen. Vorhandene Transfer-Sonderbehandlung
   erhalten/vereinfachen; sichtbares GetLastActivePopup(Main) fuer eigene modale
   Dialoge benutzen. Nicht versehentlich neue Dialoginstanzen erzeugen oder Eingaben
   verwerfen. Native Topmost-Freigabe muss auch nach diesem Aufruf greifen.
   Die bestehenden Clickhandler fuer Sichern/uebertragen in Tray und Zahnrad-
   Kontextmenue in TaskPlopp.ps1 ebenfalls explizit anbinden: zuerst vorhandenen
   Show-TaskPlopp-Aufrufweg benutzen, dann den Transfer oeffnen/aktivieren. So startet
   ein Transfer aus dem Tray nicht mit verborgenem Owner ausserhalb des Lifecycle.
6. Taskleisten-Minimieren bleibt Minimieren. X bleibt Ausblenden in den Infobereich.
   Space, Aufnahme, Transkription, Statusmeldung, Layout/Undo bleiben unveraendert.

Die Freigabe erfolgt spaetestens im naechsten normalen 150-ms-Tick, sofern der GUI-
Thread Nachrichten verarbeitet. Kein harter Echtzeitanspruch bei blockierter GUI.
Windows kann Vordergrundaktivierung verweigern; Citrix-/Treiberverhalten wird nicht
als garantiert behauptet. Kein automatisches Minimieren fremder Fenster hinzufuegen.

## Milestones / Steps
M1: Kleiner gemeinsamer Lifecycle fuer explizites Anheben und Freigeben, beide
bisherigen Raise-Aufrufstellen und eigene Dialoge beruecksichtigen.
M2: Bestehenden Wake-Timer und Hide/Minimize-Wege anbinden; keine zweite Schleife.
M3: Isolierte PS5.1-Tests, relevante Regressionen, README und Verifier; danach
konkreten Teststand und verbleibenden Citrix-Praxistest an Tobias melden.

## Verifier / technische Akzeptanz
- Native WS_EX_TOPMOST pruefen, nicht nur den gecachten WinForms-Propertywert.
- Explizites Oeffnen: Main ist sichtbar, wiederhergestellt und topmost.
- Wechsel zu eigener Test-GUI eines separaten Prozesses: Main verliert topmost,
  bleibt offen; fremde Test-GUI bleibt Vordergrund, Main wird nicht reaktiviert.
- Danach normaler Fokuswechsel zu Main: kein neues topmost; erneuter Hotkey-/Show-
  Aufruf dagegen topmost. Gleiches fuer initiales Shown.
- Eigener modaler Dialog und verschachtelte eigene Form: waehrend Bedienung nicht
  faelschlich freigeben; Wechsel vom Dialog zu externer Fixture gibt Main UND Dialog
  nativ frei. Expliziter Aufruf bei offenem Dialog bringt diesen zurueck, Eingaben erhalten.
- Tray-Transfer bei vorher verborgenem Main: eigener Dialog erreichbar, nach Wechsel
  zur externen Fixture kein haengendes topmost. Zahnrad-Kontextweg ebenso pruefen.
  Wiederaufruf auch bei echtem Dateidialog/Unterdialog manuell kontrollieren.
- Hide/X und Minimize/Space geben topmost frei, Tray-/Taskbarverhalten unveraendert.
  Layout-Capture und Wiederzeigen/Undo erzeugen kein haengendes topmost.
- GetForegroundWindow=0: kein Wiederanheben, keine Fehler-/Popup-Schleife.
- PS5.1-Tests KeyAndWindow, Native, Keyboard, Hotkey, WindowLayout; keine echte
  Aufnahme, kein API-Aufruf und keine produktive Hotkey-Umschaltung erforderlich.
- Eigencheck: keine neuen Quellen/Compiler/Pakete/Farben/Popups; CRLF und PS1-BOM.

## Manuelle Abnahme
1. Normales Programm aktiv -> Hotkey -> TaskPlopp vorne -> anderes Programm klicken
   oder Alt+Tab -> anderes Programm kann TaskPlopp verdecken.
2. Citrix im Vollbild -> Hotkey -> TaskPlopp bedienbar -> Citrix anklicken -> TaskPlopp
   haelt sich nicht mehr darueber fest. Hotkey holt es erneut nach vorne.
3. Konfiguration oeffnen -> fremdes Programm -> zurueck per Hotkey: Konfiguration
   erreichbar, Eingaben unveraendert. X/Minimieren/Space verhalten sich wie bisher.
Diese neue Citrix-Abnahme ist noch offen und wird nicht durch simulierte Vollbild-
Testfenster ersetzt. Logitech-Sondertasten bleiben ein getrenntes Thema.

## Quellen
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getancestor
Lokaler Code f30f56c, insbesondere TaskPlopp.ps1 und TaskPlopp.Native.ps1.

## Unabhaengiges Review
Erstes kontextfreies Review: keine technischen Blocker; Praezisierung zum direkten
Tray-Transfer und echten Datei-/Unterdialogen gefordert. Beide Punkte oben aufgenommen.
Abschliessend freigegeben durch unabhaengigen Reviewer foreground_plan_review;
keine verbleibenden Blocker. Gepruefte Fassung vor diesem Vermerk: SHA256
9FD9DCE5742A3FA98FC9B8487B8AC9FD899DB884C4BF44A24A62831A597B38D9.
Keine Implementierung oder UI-/Schreibtests im P+-Durchlauf. Umsetzung wartet auf X/X+.

## Ausfuehrung
Tobias hat X+ erteilt und beliebiges Beenden/Neustarten von TaskPlopp erlaubt. Beginn der Umsetzung auf Basis f30f56c. Pruefung umfasst auch Aktivierung ohne Buttonklick; bestehender 150-ms-Takt. Keine neue Implementierungsfreigabe erforderlich.

### Technische Praezisierung aus den Umsetzungstests
Die anfangs geplanten GA_ROOTOWNER/GetLastActivePopup-Abfragen lieferten bei unseren echten modalen PS5.1-WinForms-Testfenstern nicht die erwartete Besitzer-/Dialogzuordnung. GW_OWNER (GetWindow, 4) erkennt die vorhandene native Owner-Kette korrekt; GW_ENABLEDPOPUP (GetWindow, 6) liefert den aktiven auch verschachtelten modalen Dialog. Beide ABI-Aufrufe waren bereits vorhanden. Diese kleine Routinekorrektur ersetzt die betreffenden Abfragen aus Spec 2/5, ohne neuen Dateiscope, Zustand oder Produktmechanismus. Externe Fixture erlaubt dem Test-Elternprozess explizit die Rueckkehr (AllowSetForegroundWindow nur als Test-ABI), damit Windows-Fokusregeln den Wiederaufruftest nicht verfaelschen.
