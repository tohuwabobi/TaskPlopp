# Verifier: Vordergrund nur waehrend der Bedienung

## Umsetzung
Nur src/TaskPlopp.ps1 als Produktcode. PowerShell 5.1, vorhandene Windows-ABI,
kein eigener C#-Code, Compiler, neues Paket, Popup, Farbe oder Einstellungsfeld.
Initiales Shown und expliziter Show-Aufruf setzen Main.TopMost=true und heben das
Hauptfenster bzw. den bereits offenen aktivierbaren Dialog nativ an.
Normales Activated, Aktualisieren und internes Wiederzeigen pinnen nicht neu.
Vorhandener 150-ms-Wake-Timer gibt TopMost frei, sobald eine fremde Anwendung aktiv
ist. Owner-Kette eigener Dialoge bleibt waehrend Bedienung erlaubt. Hide und
Minimize geben den Zustand ebenfalls frei. Kein eigener Beobachtertimer/Thread.
Tray- und Zahnrad-Kontextaufruf fuer Transfer binden den gleichen Show-Weg ein.

## Technische Discovery waehrend X+
GA_ROOTOWNER und GetLastActivePopup lieferten fuer die echten eigenen modalen
Testformen keine ausreichende Zuordnung. Bestehendes GetWindow mit GW_OWNER (4)
und GW_ENABLEDPOPUP (6) funktioniert fuer Hauptfenster, modale Form und Unterdialog.
Die Schleifen haben lokale Besuchsmengen gegen Wiederholung, keine persistente
Fensterverwaltung. Native.ps1 und die API-/Config-/Hotkey-Einstellungen unveraendert.

## Tests unter Windows PowerShell 5.1 auf ARKANIS
Test-TaskPloppKeyAndWindow.ps1 erweitert, externe PS5.1-Form unter eigener Prozess-ID.
Die externe Fixture erlaubt dem Testprozess explizit SetForegroundWindow; diese
zusaetzliche feste ABI-Deklaration existiert ausschliesslich in der Test-Fixture.
Ansonsten verhindert Windows den Rueckaufruf aus einem automatisierten Hintergrundtest.
Die Anwendung selbst bekommt keine Foreground-Freigabe/Sonderrechte hinzugefuegt.

Bestanden:
- Natives WS_EX_TOPMOST und WinForms-Property nach initialem/erneutem explizitem Aufruf.
- Reale Aktivierung der separaten eigenen Test-App: Main bleibt sichtbar, verliert
  Topmost; externe App bleibt aktiv. Normales Aktivieren von Main pinnt nicht erneut.
- Foreground=0 bleibt ohne Aktion. Hide/Capture-artiges Ausblenden gibt frei;
  internes Show setzt keinen neuen Pin. Minimieren gibt nativen Pin frei.
- Eigene echte modale Form und verschachtelte Form bleiben bedienbar/topmost.
  Externe Aktivierung entfernt Topmost auch nativ von allen eigenen Dialogen.
  Show waehlt den offenen Unterdialog und bewahrt dessen Eingabefeldinhalt.
- Reale Transfer-GUI nach verborgenem Main ueber Show+Transfer (Tray-Handlerweg):
  sichtbar/bedienbar; externer Wechsel gibt native Stile frei; Wiederaufruf erreicht
  vorhandenen Transferdialog. Beide produktiven Kontext-Clickhandler angebunden.
- Zusaetzlich eigene externe Fixture topmost gesetzt: Show hebt Main darueber,
  anschliessende Peer-Aktivierung gibt Main frei. Dies ist kein echter Citrix-Test.
- Bestehende Key-/Minimize-/Tray-/Favoriten-/Layout-Undo-Tests weiterhin bestanden.

Weitere Regressionen bestanden: Native-Quellcodeaudit, Keyboard, Hotkey-Aufnahme,
GUI-Layout/Status-ohne-Popups, Sofortspeichern und WindowLayout (ohne API).

## Noch offene manuelle Abnahme
Auf Test-PC nach Neustart: TaskPlopp per konfiguriertem Hotkey oeffnen, fremde App
anklicken oder Alt+Tab, dann erneut Hotkey. Besonders unter echtem Citrix-Vollbild.
Bei echter Dateiauswahl/Unterdialog Wiederaufruf und Rueckkehr ebenfalls praktisch
kontrollieren; automatisiert wurden eigene modale Formen und echter Transfer,
nicht der native Dateiauswahldialog, benutzt. Kein garantierter Windows-Fokus bei
Betriebssystem-/Rechtebeschraenkungen. Kein Echtzeitversprechen bei blockierter GUI.
Keine fremden Nutzerfenster fuer Fokus-/Ueberdeckungstests verwendet, keine Aufnahme,
API-Anfrage, produktive Hotkey-Aenderung oder PC-Sperre.

## Quellen
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindow
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos
