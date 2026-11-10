# TaskPlopp: passende Groesse und Position nur beim Programmstart - P+

Stand 10.11.2026, Basis 6552533. Entwurf im P+-Review; noch keine X-/X+-Freigabe.

## Ziel / bestaetigte Entscheidungen
Breite ungefaehr wie bisher. Starthoehe richtet sich nach Favoriten und einigen
weiteren Fenstern, hoechstens etwa 85 Prozent der Arbeitsflaechenhoehe. Die zweizeilige
Statusleiste bleibt in Tasks/Audio mit ihrer vollen Hoehe reserviert, auch leer. Die
bestehende Help-Ansicht blendet sie weiterhin zugunsten der Hilfeflaeche aus; dabei
aendert sich nur der Inhalt, niemals die Aussenhoehe des Fensters. Position
mittig auf dem Monitor unter dem Mauszeiger. Nach dem Start keine automatische
Groessen-/Positionsaenderung durch Refresh, Status, Hotkey, Hilfe oder Audiowechsel.
Manuelles Verschieben/Resize bleibt moeglich; keine gespeicherte Fenstergroesse.

## Discovery / vorhandener Code
Main.Size bisher vor Font/Controls auf min(760, Arbeitsbreite-80) und
min(1200, Arbeitshoehe-80); StartPosition=CenterScreen. Tasks werden vor Application.Run
aufgebaut. Die Buttons, Labels, Abstaende und der dauerhaft zweizeilige Status sind
somit messbar. Update-TaskPloppContentLayout setzt bereits Toolbar-Mindestbreite,
Buttonbreiten/-hoehen und symmetrische Raender. Erstes Shown hebt Main nach vorne.
Show-TaskPlopp und Refresh duerfen die neue Startberechnung spaeter nicht erneut rufen.

## Spec / kleinste praktikable Umsetzung
1. Einmal die Arbeitsflaeche des Monitors unter dem Mauszeiger erfassen. WorkingArea
   statt Vollbildgrenzen verwenden, damit Taskleiste nicht ueberdeckt wird. Alle
   Werte im gleichen WinForms-/DPI-Kontext benutzen; keine Mischung mit physischen
   Screenshot-/DWM-Pixeln und keine neue globale DPI-Einstellung.
2. StartPosition=Manual und Startbreite wie bisher um 760 begrenzen, mit vorhandener
   Toolbar-Mindestbreite als Untergrenze. Bei schmaler Arbeitsflaeche den vorhandenen
   Abstand von insgesamt 80 reduzieren, soweit fuer die Mindestbreite noetig.
   Mindestbreite erst nach abgeschlossenem Toolbarlayout in Load bestimmen. Falls
   sie die ganze Arbeitsbreite uebersteigt, ist das die unten benannte technische
   Hardwaregrenze; dort ist vollstaendiges Einpassen mathematisch nicht zugesagt.
   Keine schmaleren Buttons/kleinere Schrift oder neuer Toolbarumbruch.
3. Nach Font, Controls und initialem Tasks-Aufbau das normale WinForms-Layout
   abschliessen. Einmalige Startanpassung im ersten Load (vor erster Anzeige), wenn
   die Anfangsskalierung abgeschlossen ist. Keine neue Timer-/Shown-Schleife.
   Bestehendes Shown-Anheben bleibt anschliessend bestehen.
4. Zielinhalt: komplette Favoritenrubrik und, wenn aktiviert/vorhanden, Ueberschrift
   Weitere Fenster plus bis zu drei weitere Fensterbuttons. Drei ist die konkrete
   einfache Auslegung von "einige", kein konfigurierbarer Wert. Bei null Favoriten
   vorhandenen Hinweistext, bei null weiteren Fenstern vorhandenen Leerhinweis
   einbeziehen. Nur bereits erzeugte Controls messen; keine zweite Fensterenumeration
   oder neue Matching-/Startlogik. Vorhandenes Button.Tag.IsFavorite fuer die Rubriken
   benutzen; kein neues Status-/Zuordnungssystem fuer die Hoehenmessung.
5. Benötigte Aussenhoehe = gemessene Hoehen/Margins des Zielinhalts, Listenpadding,
   komplette TopArea inkl. Toolbar und zweizeiligem Status sowie Fensterrahmen.
   Hoehen aus Summe von Control.Height + Margin.Vertical fuer den ausgewaehlten
   Prefix messen; nicht DisplayRectangle/AutoScroll fuer den Gesamtinhalt und nicht
   bereits gescrollte Bottom-Werte benutzen. Startbreite zuerst setzen, dann
   PerformLayout und Update-TaskPloppContentLayout vor der Hoehenmessung abschliessen.
   Keine schaetzenden Konstanten fuer Button-/Schrifthoehen und kein pauschaler
   Zusatz-Leerraum. Lange/wrappende Ueberschriften nach festgelegter Breite messen.
   Zielhoehe zwischen vorhandener Mindesthoehe und floor(0.85 * WorkingArea.Height)
   begrenzen. Falls Mindesthoehe den 85%-Richtwert ueberschreitet, hat die bedienbare
   Mindesthoehe Vorrang, soweit sie noch in die Arbeitsflaeche passt. Bei extrem
   kleinen Arbeitsflaechen, die schon die bedienbare Mindestgroesse unterschreiten,
   keinen neuen Layout-Sondermodus bauen; technische Grenze im Verifier benennen.
6. Hoehe setzen und Layout abschliessen. Falls dadurch Scrollbar und symmetrischer
   Einzug die Breite/Labelhoehe veraendern, hoechstens eine zweite direkte Messung
   mit denselben Hoehengrenzen. Keine unbeschraenkte Korrekturschleife oder spaetere
   automatische Nachregelung. Favoriten ueber dem Limit bleiben scrollbar.
7. Finale Aussenbounds mit x=area.X+(area.Width-width)/2 und analog y berechnen.
   Negative Monitorurspruenge beruecksichtigen; auf dem gewaehlten Monitor bleiben.
   Keine Zentrierung auf primaerem Monitor, aktive Anwendung oder Main.CurrentScreen.
8. Einmaliger Load-Handler oder expliziter einmaliger Startaufruf, kein persistentes
   Flag-/Statussystem, neue Einstellung, Datei oder Monitorueberwachung.
   Statusanzeigen, Hilfe-/Audiowechsel, Hide/Restore und Hotkey behalten spaeter die
   vom Nutzer bestimmte Groesse/Position; Ausnahme bisherige Fensterzustands-Restore.

## Scope / uebliche Bauchschmerzen-Themen
Produktcode nur src/TaskPlopp.ps1. Relevante Tests in tests/Test-TaskPloppLayout.ps1
und, falls sinnvoll fuer Restore, bestehendem Test-TaskPloppKeyAndWindow.ps1.
Ein eigener tests/Test-TaskPloppStartup.ps1 fuer isolierte Startbounds im normalen
PS5.1-Prozesskontext ist erlaubt; kein allgemeines Test-/Startframework.
README.md und eigener Verifier unter docs. Keine persoenliche Config/Keys aendern.
Weiter PowerShell 5.1; keine eigene C#-/JS-/TS-Logik, Compiler, Pakete, Adminrechte,
Popups, neuen Farben, GUI-Schalter, dauerhafte Speicherung, Hintergrundworker oder
Timer. Kein Aendern der Statushoehe/Schrift und kein allgemeiner GUI-Umbau.

## Milestones
M1: Vorhandene Controls einmal messen, Startbounds im passenden Moment setzen.
M2: Normal-/Leer-/Viele-Fenster-Faelle, DPI und Monitorgeometrie pruefen.
M3: Relevante Regressionen, Verifier/README, Eigencheck; nach X+ committen/pushen.

## Verifier / Akzeptanz
- Erststart mit null, wenigen und vielen Favoriten sowie 0/1/3/>3 weiteren Fenstern,
  ShowOpenWindows aus/ein. Gewoehnliche Hoehe passend, viele Controls auf ca. 85%
  begrenzt; fehlende Favoritenfenster/Startziele fuehren nicht zu Fehlberechnung.
- Gemessene normale Schriftgroesse und grosse Schrift, unterschiedliche Hoehen und
  lange Labels: kein verdeckter letzter Zielbutton, wenn Platz reicht; keine
  willkuerliche grosse Luecke unter letztem Zielcontrol. Viele Fenster scrollbar.
- Toolbar, Tasks-/Audio-Statushoehe und Raender bleiben unveraendert. Leere, Hinweis-, Erfolgs-
  und Fehlermeldung veraendern weder Aussenbounds noch den Listenanfang.
- Zentrierungsrechnung fuer primaeren/zweiten Monitor, negative Urspruenge und
  kleine Arbeitsflaeche mit Ersatzrechtecken pruefen. Echte Anzeige nur auf vorhandener
  Hardware; keine physische Mehrmonitor-/Mixed-DPI-Abnahme behaupten, wenn nicht da.
- Nicht nur reine Rechenfunktion testen: final sichtbare Formbounds/Controlbounds
  nach Load/Shown pruefen. Mindestens einen separaten PS5.1-Starttest ohne erzwungenes
  SetThreadDpiAwarenessContext ausfuehren: der bestehende Layouttest setzt PMv2,
  waehrend der Produktionsstart das nicht tut. Beide Kontexte unterscheiden.
  Sicherstellen, dass WinForms-Skalierung/AutoSize kein spaeteres Wachstum
  oder Verschieben erzeugt. Normale Startansicht visuell kontrollieren.
- Danach manuell im eigenen Testfenster andere Bounds setzen, Refresh, neue Status-
  meldung, Help/Back, Audio/Back, Hide/Show, Show-TaskPlopp und Minimieren/Restore:
  Groesse und Position bleiben erhalten. Beim zweiten Prozessstart neu berechnen.
- Native-Audit, Layout/Help, Keyboard und relevante KeyAndWindow-Regressionspruefungen
  unter PS5.1; keine echten Mikrofon-/API-/Sperrtests und keine fremden Fenster bewegen.
- Windows-Taskleiste und bedienbare Toolbar respektieren. Unterschreitet die Hardware
  selbst die vorhandene Mindestbreite/-hoehe, Grenze statt neuer Sonderloesung benennen.
- CRLF und PS1-BOM. Diff ohne Secrets, fremde Aenderungen und neue Popup-/Compilerquellen.

## Quellen
https://learn.microsoft.com/en-us/dotnet/framework/winforms/automatic-scaling-in-windows-forms
Lokaler PS5.1-Code 6552533; keine Umstellung auf neuere .NET-/DPI-Mechanismen.

## Planstand
P+-Review durch unabhaengigen startup_size_plan_review: kein technischer Discovery-
Blocker fuer die einmalige Load-Berechnung. Praezisiert: dauerhaft reservierter Status
gilt fuer Tasks/Audio; bestehendes Ausblenden in Help bleibt unveraendert und beeinflusst
nicht die Aussenbounds. Abschliessendes Review: freigegeben, keine verbleibenden
entscheidenden Annahmen oder Discovery-Blocker. Gepruefte Fassung vor diesem Vermerk:
SHA256 1EC1A8756D006393E8AFE5F373F255B9109EA8ECA7022D774B4D4A010C031A4A.
Keine Produktdatei geaendert; keine UI-/Schreibtests. Umsetzung erst nach X/X+.

## Ausfuehrung nach X+
Tobias hat X+ erteilt. Umsetzung im festgelegten Scope; Startberechnung ausschliesslich im Load-Handler, keine Aenderung persoenlicher Einstellungen.

### Notwendiger kleiner Restore-Fix
Der neue Test zeigte, dass Update-TaskPloppContentLayout beim Minimieren aus den minimierten Abmessungen eine andere Mindestbreite ableitet und damit RestoreBounds auf die Mindestgroesse aendert. Der vorhandene Layoutpfad kehrt nun bei Minimized sofort zurueck. Dadurch bleiben manuelle normale Bounds erhalten; kein neuer Zustand und kein weiterer Dateiscope.
