# Verifier: Fensterordner mit minimierten Fenstern und Favoriten

## Umsetzung / Umfang
PowerShell 5.1; bestehende Aufnahme, lokale Transkription, Responses API und DPAPI.
Keine neuen Pakete, eigenen C#-Quellen, Compiler, Popups oder GUI-Farben.
Minimierte Fenster haben Zustand und Monitor, aber keine irrefuehrenden DWM-Rechtecke.
Favoriten erhalten lokale f-IDs. Nur Name, Prozessname, Startmodus und passende
Fenster-IDs gehen an die KI; keine Startpfade, Parameter, AppIds oder Ordnerpfade.
Antworten kennen normal/maximized; Maximieren setzt den echten Windows-Zustand.

Vor jedem Start werden kompletter Antwortvertrag, IDs, Monitorgrenzen und bekannte
Startziele geprueft. Vorhandene Starter bleiben unveraendert. Starts erfolgen seriell,
mit insgesamt 15 Sekunden Pollingbudget; ein synchron blockierender Fremdstarter ist
hierdurch nicht hart begrenzt. Neues Fenster: genau ein passender neuer Kandidat.
Zeitliche Zuordnung ist keine browserinterne Profilidentitaet. Gleichzeitiges
anderweitiges Starten eines gleichartigen Fensters kann die Zuordnung beeinflussen.
Mehrdeutige Treffer brechen die Vorbereitung vor der eigentlichen Anordnung ab.
Vorhandene Fenster werden bei spezifischem Match wiederverwendet; Immer starten bleibt erhalten.

Raten zwischen gleichnamigen Programmen mit verschiedenen Favoriten verhindert eine
kleine lokale Namenspruefung: unterscheidbares Wort des Favoritennamens im Auftrag.
Unklare Favoriten werden ausgelassen und Alternativen in der Statusleiste genannt.

## Bestandene lokale Tests auf ARKANIS
- Test-TaskPloppLayoutFavorites.ps1: eigener minimierter Katalog ohne DWM-Abfrage;
  geschlossene Favoriten ohne offene Fenster; f-IDs und Maximierungsvertrag;
  oeffentliche Favoritenprojektion ohne private Startdaten; lokale Namensregel.
- Reale PS5.1-Worker und eigene Test-GUIs: LNK samt Parametern startet, normaler
  Favorit nutzt minimiertes Fenster ohne Start, Immer starten startet genau einmal.
  Launcher-PID darf sich von der spaeteren Fenster-PID unterscheiden.
- Vor Start gemerkter Zustand fuer wiederverwendetes Fenster; Undo erhaelt
  minimiert-aus-maximiert. Neues Programm bleibt nach Undo offen.
- Zweiter Start scheitert: erstes Programm bleibt offen, keine Geometrieaenderung.
  Fehlende Datei wird vor dem ersten Start erkannt. Kein Fenster innerhalb des
  kurzen Test-Pollingbudgets: Hinweis. Mehrere neue / unspezifische alte Treffer:
  keine geratenen Ziele. Alias f+w desselben Fensters: keine doppelte Anwendung.
- Test-TaskPloppWindowLayout.ps1: normale/maximierte Fenster und alle vier
  Kombinationen minimiert-aus-normal/maximiert -> normal/maximiert -> Undo.
  Echter IsZoomed-Zustand, normale Wiederherstellungsgroesse beim Maximieren auf
  demselben Monitor erhalten; unbeteiligte Test-GUI unveraendert.
- Undo vergleicht relevanten Zustand, normale Grenzen und bei Minimierung das
  Restore-to-maximized-Flag. Windows normalisiert unbenutzte Minimierungspositionen;
  diese sind kein Fehler. Benutzerdefinierte Minimierungsposition wird weiter geprueft.
- Negative Koordinaten, Grenzen, ungueltige IDs/JSON/Zustaende, Mindestgroessen,
  veraltete Identitaet; GUI-Abbruch, Fehlerstatus, geschuetzte Apply-Phase.
- Eigene weisse Screenshotflaeche im RAM verifiziert; kein Benutzerdesktop hochgeladen.
- Regressionen: Native-Quellcodeaudit, Grundeinstellungen, Apps, Tastatur,
  Key/Taskleiste, Sofortspeichern, Diktat, Diktat-GUI, Ordnerstruktur bestanden.
  Kein Mikrofon-, Audiohardware- oder Sperrtest angefordert/ausgeloest.

## KI-Proben und Grenzen
Nur kuenstliche Titel/Favoriten und selbst gezeichnetes Testbild, vorhandener lokal
verschluesselter API-Key; keine echten Desktopbilder, keine Key-Ausgabe.
Fruehe Proben zeigten erfundene Profilwahl und Rechtecke unterhalb der Arbeitsflaeche.
Profilwahl wird jetzt lokal eingeschraenkt; Arbeitsflaechenregeln im Auftrag praezisiert.
Ungueltige Geometrie wird weiterhin abgelehnt, ohne Start/Anordnung. Kein stilles
Korrigieren, kein automatischer zweiter API-Aufruf. KI bleibt nicht deterministisch.

Letzte zusammenhaengende -Api-Serie: alle sechs Faelle bestanden. Metadaten 1,22 s;
mit Testbild 1,25 s; minimiertes Chrome 0,81 s; geschlossener Favorit 0,89 s;
benanntes Profil 1,11 s; unbestimmtes Profil 0,92 s. Einzelproben, keine Garantie
fuer allgemeine Qualitaet oder Geschwindigkeit. Fruehere Fehlschlaege bleiben oben dokumentiert.

## Manuelle Abnahme noch offen
Auf GANDALF nach Neustart: Chrome minimieren -> "Maximiere Chrome" bei eindeutigem
Fenster; benannten geschlossenen Profil-Favoriten starten; Downloads daneben;
Rueckgaengig. Bei mehreren Profilen Namen nennen. Allgemeines Chrome bei mehreren
Favoriten muss einen Hinweis geben. Bereits erfolgte fruehere Abnahme des alten
Fensterordners ersetzt diese neuen Praxistests nicht. Mehrmonitor-/Mixed-DPI-Hardware
nicht praktisch verifiziert. Starterwirkungen werden nicht atomar zurueckgenommen;
neu gestartete Programme bleiben auch bei Fehlern oder Undo offen. Undo ist nur im RAM.
