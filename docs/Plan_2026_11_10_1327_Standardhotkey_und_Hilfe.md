# Neuer Standard-Hotkey und Hilfe ueber die volle Inhaltsflaeche

Stand: 10.11.2026. Basis: 231c9ad. P+-Plan nach Zielanalyse und Tobias'
Korrektur zur Hilfeflaeche. Produktcode bleibt bis X/X+ unveraendert.

## Ziel und Scope
Neuer Standard Strg+NumPad0 statt Strg+Alt+F10. Fragezeichen oben rechts oeffnet
kurze, verstaendliche Hilfe im vorhandenen Hauptfenster. Die Hilfe nutzt die gesamte
Flaeche unterhalb der Toolbar, einschliesslich des bisherigen Statusbereichs.
Keine Popups, eigene C#-Logik, neuen Pakete, Farben, Adminrechte oder Webansicht.
Weiter Windows PowerShell 5.1 und vorhandene WinForms-Steuerelemente; KISS.

## M1: Standard-Hotkey
- In ConvertTo-TaskPloppSettings: fehlende HotkeyModifiers -> 2 (Strg), fehlender
  HotkeyKey -> NumPad0. Beispielkonfiguration und aktive README-Anweisungen anpassen.
- Vorhandene gespeicherte Belegungen bleiben erhalten, auch bewusst gespeichertes
  Strg+Alt+F10. Keine automatische Umschreibung persoenlicher data/config.json.
- Vorhandene Aufnahme und Registrierung wiederverwenden. NumPad0 ist die Taste auf
  dem Ziffernblock, nicht die Ziffer 0 der oberen Reihe. Keine neue Hotkey-Option.
- Registrierung bei Belegung wie bisher mit Statusmeldung; keine stille Ersatzwahl.

## M2: Hilfe und Rueckkehr
- Rechtsbuendige Toolbargruppe: ?, Aktualisieren, Zahnrad. Bestehende Abstaende,
  Schrift und Farben erhalten. In der Hilfe wird ? zum Zurueck-Pfeil mit Tooltip.
  Mindestbreite des Hauptfensters mindestens auf die gemessene Gesamtbreite beider
  Toolbarguppen samt Abstand, Innenraendern und Fensterrahmen setzen. Bestehende
  Mindestbreite 460 nur beibehalten, wenn alle Buttons vollstaendig hineinpassen.
  Kein Verkleinern der Schrift, Umbruch, Abschneiden oder horizontaler Scrollbalken.
- Hilfe als weitere vorhandene Ansicht (Tasks/Audio/Help) behandeln. Die vorherige
  Ansicht fuer Zurueck merken, keine allgemeine Navigationshistorie einfuehren.
- Ein einfaches lesbares Hilfesteuerelement fuellt den gesamten Inhaltsbereich unter
  der Toolbar. Vorhandenes ListPanel als Inhaltsflaeche weiterverwenden, ein einziges
  lesbares Hilfesteuerelement passend zum Clientbereich dimensionieren; kein neues
  Overlay-/Navigationssystem. Fuer Help MessageBar.Visible=false und die zweite
  Zeile von TopArea.RowStyles auf Absolute/0 setzen; bei Rueckkehr wieder AutoSize.
  MessageBar.Height=0 allein genuegt nicht, da Measure-TaskPloppMessage Hoehe neu setzt.
  Keine leere Statusluecke. Favoriten/Weitere Fenster/Audio sind ausgeblendet.
- Hilfe knapp mit Abschnitten: Zweck; Favoriten und Fensterwahl; Audio; PC-Sperre;
  Diktat; KI-Fensterordner und Undo; Zahnrad/Hotkey-Aufnahme; Minimieren/Schliessen.
  Eingerichteten aktuellen Hotkey anzeigen, nicht nur den neuen Standard.
  Hinweis: Diktat transkribiert lokal; KI-Fensterordner sendet Auftrag, Fenstertitel
  und Bildschirmbilder an OpenAI. Nur bestehende Funktionen beschreiben.
- Zurueck-Pfeil oder Escape stellt die vorherige Tasks-/Audioansicht mit Statusleiste
  wieder her. Erster Keyboard-Handler behandelt Help-Escape; der zweite KeyDown-
  Handler fuer Layoutabbruch muss bereits Handled gesetzte Events respektieren.
  Sonst wuerde Escape zusaetzlich Aufnahme oder Fensterordner abbrechen.
  Hilfe darf keine Favoriten-Tastaturauswahl ausloesen. Schrift bleibt
  gross; bei kleinem Fenster darf der Hilfetext vertikal scrollen statt abzuschneiden.
- Aktualisieren in Help belaesst die Hilfe und aktualisiert deren Angaben.
  Refresh in Help loescht keine verdeckten Statusdaten. Sonstige Toolbaraktionen
  bleiben vorhanden; Wechsel zu Audio verlaesst Help.
  Globaler TaskPlopp-Aufruf zeigt wie bisher Tasks. Kein neuer Wiederaufnahmemodus.
- Aktive Aufnahme, Worker, Sperrtimer, Hotkey und Statusdaten laufen unveraendert.
  Ausblenden der Statusleiste loescht keine Meldungen, Undo-Daten oder Aufnahmen.
  Beim Verlassen von Help vor Wiederzeigen Update-TaskPloppMessageTimeout einmal
  aufrufen, damit abgelaufene Meldungen nicht kurz erneut sichtbar werden.
  Rueckkehr zu Audio verwendet Update-TaskPloppAudioView -KeepMessage: gewoehnlicher
  Audiohinweis wuerde sonst Activity und zwischenzeitliche Meldung ueberschreiben.
  Config-/Transfer-Rueckkehr ueber Show-TaskPloppView muss Help erhalten und aktuelle
  Angaben neu rendern. Direkte Tasks-/Audio-Renderer muessen bei CurrentView=Help
  ohne Austausch der Inhaltscontrols zurueckkehren. Einfache fruehe Guards genuegen.

## Vorgesehene Dateien
src/TaskPlopp.Apps.ps1: Standardwerte.
src/TaskPlopp.ps1: Help-Button, vollflaechiger Inhalt und Layout-Anbindung.
src/TaskPlopp.Audio.ps1: vorhandenen Ansichtswechsel um Help erweitern; kleine
Hilfedarstellung dort bzw. in TaskPlopp.ps1, kein eigenes neues Hilfesystem.
src/TaskPlopp.Keyboard.ps1: Escape/Selektion fuer Help beruecksichtigen.
data/config.example.json, README.md: aktualisierter Standard und Bedienung.
tests/Test-TaskPloppHotkey.ps1, Test-TaskPloppKeyboard.ps1 und
Test-TaskPloppLayout.ps1: gezielte vorhandene Tests erweitern.
Neuer Verifier unter docs. Keine produktive Config-/Secret-Aenderung.

## M3: Verifier / Akzeptanz
1. Frische/leere Konfiguration ergibt Strg+NumPad0, Modifier 0x4002 inkl. NoRepeat,
   Virtual Key 0x60. Oberreihen-0 bleibt davon verschieden. Bestehender individueller
   Hotkey wird unveraendert gelesen/importiert. Konflikt erhaelt bisherigen Zustand.
2. Eigenen freien Testhotkey wie bisher verwenden; produktive Belegung nicht fuer
   Testzwecke umschalten. Echten Strg+NumPad0-Aufruf mit NumLock an/aus und im Citrix-
   Vollbild manuell abnehmen; bei anderer Windows-Tastenmeldung keine Garantie fuer
   identisches Verhalten bei ausgeschaltetem NumLock behaupten.
3. ? aus Tasks und Audio: vollstaendige Inhaltsflaeche bis unter die Toolbar,
   Statuszeile beansprucht keinen Platz, kein neues Fenster. Dynamischer Hotkey in
   Hilfe entspricht Settings. Anzeige bei normalem und kleinem Fenster pruefen.
4. Escape und Zurueck stellen vorherige Ansicht wieder her. 1/0/A-Z starten in Help
   keine Favoriten. Wiederholtes Oeffnen/Schliessen, Aktualisieren, Audio-Wechsel und
   globales Show und Konfigurationsrueckkehr nach Help pruefen; keine zurueckbleibenden
   Leerflaechen/Controls. Direkte Tasks-/Audio-Updates duerfen Help nicht ueberschreiben.
   Help-Escape bei simuliertem Layout-Auftrag pruefen: nur Ansicht zurueck, Auftrag
   und Aufnahme bleiben erhalten; kein zweiter Cancel im nachfolgenden KeyDown-Handler.
5. Statusmeldung waehrend Help erhaelt Daten und erscheint nach Rueckkehr nach den
   vorhandenen Ablaufregeln. Aufnahme-/Workerzustand darf sich allein durch den
   Ansichtswechsel nicht aendern. Help -> Audio sowohl mit Recording-Activity als auch
   spaeter gesetzter Warn-/Erfolgsmeldung pruefen; Status nicht durch Audiobereit-
   Meldung ersetzen. Frist waehrend Help ablaufen lassen: sofort korrekte leere Anzeige
   bei Rueckkehr. Layoutbreite/Toolbar bei gemessener Mindestbreite und Standardgroesse
   visuell und ueber Bounds pruefen: alle Buttons vollstaendig sichtbar, kein Ueberlapp.
6. Relevante PS5.1-Regressionen: Native-Audit, Hotkey, Keyboard, Layout, AudioUi,
   Autosave. Kein realer Mikrofon-/API-/PC-Sperrtest noetig.
7. CRLF; PS1 mit UTF-8-BOM. Eigencheck: keine neuen Farben/Popups/Compiler/Pakete,
   keine persoenlichen Configs oder Keys im Git-Diff. Umsetzung dokumentieren und
   nach X+ committen/pushen. Bereits erlaubtes TaskPlopp-Neustarten bei Bedarf.

## P+-Reviewstand
P+ von Tobias beauftragt. Unabhaengiger kontextfreier Reviewer help_plan_review las
Plan und Code. Vier konkrete Praezisierungen eingearbeitet: zweiter Escape-Handler,
Audio-Rueckkehr mit KeepMessage, Statuszeilenstyle/Timeout, gemessene Toolbar-Mindestbreite.
Zusatz: Konfigurationsrueckkehr, direkte Renderer und Refresh in Help bleiben in Help,
ohne Status zu verlieren. Keine Produktdatei geaendert und keine Tests ausgefuehrt.
Abschlussreview durch help_plan_review: freigegeben, keine verbleibenden Planblocker.
Gepruefte Fassung vor diesem Abschlussvermerk: SHA256
8380C35B060413284E18BF89611305705DAE7414E1344FCECD90384E86C53612.
Die dritte Ansicht mit fruehen Renderer-Guards wurde als einfachste praktikable
Loesung bestaetigt. Planfreigabe ist keine Implementierungsfreigabe. Ausfuehrung nach X/X+.

## Ausfuehrung nach X+
Tobias hat X+ erteilt. Umsetzung startet im oben festgelegten Dateiscope; persoenliche Konfiguration und Hotkey-Belegung bleiben erhalten.
