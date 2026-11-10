# Verifier: einmalige Startgroesse und Zentrierung

## Umsetzung
Nur src/TaskPlopp.ps1 als Produktcode. Vorhandene Controls nach Layout in Load messen;
Breite wie bisher um 760, mindestens Toolbarbreite, Hoehe fuer Favoriten und maximal
3 weitere Fensterbuttons. Zwei begrenzte direkte Messungen fuer Scrollbar/Label-Wrap.
TopArea mit voller zweizeiliger Statuszeile, Padding/Margins und Rahmen einbeziehen.
Cap ca. 85% der WorkingArea, vorhandene bedienbare Mindestgroesse hat Vorrang.
Zentrierung mit WorkingArea-Ursprung, einschliesslich negativer Koordinaten.
Keine neue Speicherung/Option, Timer, Threads, Farben, Popups, Compiler oder Pakete.
Weiter PowerShell 5.1, unveraenderter DPI-Kontext im Produktionsstart.

Die Berechnung wird produktiv nur durch Load aufgerufen. Refresh, Ansichten, Status
und Show/Restore verwenden sie nicht. Im vorhandenen Layoutpfad Minimized ueberspringen:
vorher veraenderte die Mindestbreitenberechnung im minimierten Zustand RestoreBounds
und verlor eine manuell gesetzte Groesse. Dieser Randfall ist jetzt abgesichert.

## Bestandene PS5.1-Pruefungen auf ARKANIS
- Neuer Test-TaskPloppStartup.ps1 startet drei separate normale PS5.1-Prozesse ohne
  erzwungenes PMv2. Sichtbare echte Form nach Load/Shown bei 0/2/20 Favoriten:
  760x350 / 760x376 / 760x1428 im dortigen WinForms-Koordinatenkontext;
  WorkingArea 4096x1680, 1428 entspricht 85%. Keine physische Pixelgarantie.
- Sichtbare Startbounds mittig auf gewaehlter Arbeitsflaeche, nach Shown stabil.
  Bei zwei Favoriten letztes Ziel voll sichtbar und kein unnoetiger unterer Leerraum.
  Viele Favoriten haben eine vertikale Scrollbar.
- Ersatzfensterlisten mit 0/1/3/5 echten erzeugten Buttoncontrols: alle Controls da,
  viertes/fuenftes weiteres Fenster erhoehen Zielhoehe nicht. Leere Rubriken und
  ShowOpenWindows aus/ein; fehlende Startziele zaehlen als konfigurierte Favoriten.
- Synthetischer Monitor mit negativem Ursprung, kleine Arbeitsflaeche, grosse Schrift
  und lange wrappende Labels; vorhandener Messpfad mit echten Controls verwendet.
- Leere Statuszeile und Hinweis/Erfolg/Fehler: gleiche Statushoehe, Listenanfang und
  Aussenbounds. Manuell gesetzte Bounds bleiben bei Refresh, Help/Back, Audio/Back,
  Hide/Show, globalem Show und Minimize/Restore gleich.
- Bestehender PMv2-Layouttest zusaetzlich mit finalem Startbounds-/Zentrierungscheck.
  Damit produktionsnaher Standardkontext und abweichender Test-DPI-Kontext geprueft.
- Native-Quellcodeaudit, Layout/Help/Popupfreiheit, Keyboard und KeyAndWindow mit
  echten eigenen externen/modale Testfenstern bestanden. Keine fremden Fenster bewegt,
  Mikrofonaufnahme, API-Anfrage, Audio-Umschaltung oder PC-Sperre.

## Visuelle Kontrolle / Grenzen
Eigene synthetische Startansicht mit zwei Favoriten als DrawToBitmap kontrolliert:
Toolbar oben, Statusbereich dauerhaft reserviert, beide Favoriten voll sichtbar,
kein zusaetzlicher unterer Leerraum. Keine Benutzerinhalte im Vorschaubild oder Git.
Mehrmonitor-/Mixed-DPI-Zentrierung bisher mit Ersatzrechtecken, nicht durch Wechsel
auf echte andere Monitore abgenommen. Extrem kleine Arbeitsflaechen unterhalb der
Toolbar-/Fenster-Mindestgroesse koennen nicht zugleich volle Bedienbarkeit und
vollstaendiges Einpassen garantieren; kein neuer Sonderlayoutmodus.
Die Hilfe blendet den Status wie bisher aus, aendert dabei nur Inhalt, nicht Aussenbounds.
