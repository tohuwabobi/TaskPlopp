# TaskPlopp: Lokales Diktat mit whisper.cpp und Vosk

Stand: 07.11.2026. Fassung 3. Status: X+ beauftragt und implementiert; manuelle Abnahme offen.
Basis: main, Commit 668b2f9. Modus P+: konkretisierte Planung einschliesslich Verifier.

## Ziel und Ergebnis

Tobias startet und beendet ein Diktat direkt in TaskPlopp. Die ausgewaehlte lokale
Engine transkribiert die Aufnahme. Der unveraenderte erkannte Text landet in der
Zwischenablage. Beide Engines sind nach Einrichtung installiert und einzeln nutzbar.
Aufnahme und Transkription erzeugen kein sichtbares Konsolenfenster.

## Scope

Enthalten:
- whisper.cpp mit mehrsprachigem Modell base und Vosk mit kleinem deutschen Modell.
- Einrichtungsbutton fuer beide Engines und Modelle, Auswahl fuer das naechste Diktat.
- Mikrofonbutton, Aufnahme, einfacher bewegter Pegel, Transkription, Zwischenablage.
- Rueckmeldungen in der vorhandenen zweizeiligen Statusleiste.
- Audio im Arbeitsspeicher; keine eigene Audio- oder Textablage als Archiv.

Spaeter: Cloud-APIs, API-Schluessel/DPAPI, Linux-Server, automatische Texteingabe,
Nachbearbeitung, Zusammenfassungen, MP3 und frei konfigurierbare CLI-Parameter.
Kein Python, pip, zusaetzlicher Windows-Dienst oder dauerhaft laufender Modellserver.
Die bestehende PC-Sperre wird durch Diktate nicht ausgesetzt.

## Discovery: bestaetigt und noch offen

Bestaetigt durch Code- und Quellenpruefung:
- TaskPlopp bietet Toolbar, Konfigurationsdialog mit Tabs und eine eigene MessageBar.
- Der untersuchte PC hat einen Intel Core Ultra 5 245, 14 Kerne, x64.
- Offizielle Windows-x64-Pakete existieren fuer beide Engines.
- whisper.cpp kann WAV-Daten ueber Standardeingabe lesen, auch im Windows-Code des
  untersuchten Binaerpaket-Tags b5454. Vosk stellt eine native API fuer Audiopuffer bereit.
- WinMM bietet Windows-Aufnahme ohne zusaetzliche Paketinstallation.

Noch NICHT praktisch nachgewiesen:
- DLL-Abhaengigkeiten und Start der ausgewaehlten Windows-Pakete auf diesem PC.
- Das tatsaechlich genutzte Standardmikrofon, Formatunterstuetzung und Aufnahmequalitaet.
- Verarbeitungsgeschwindigkeit und deutsche Erkennungsqualitaet beider Modelle.
- Erfolgreiche komplette Verarbeitung ohne temporaere Audiodatei.

Diese Punkte werden zuerst praktisch geprueft. RAM-Verarbeitung bleibt das Ziel;
ein notwendiger Tempdatei-Fallback wird vor einer Scope-Aenderung mit Tobias besprochen.

## Bedienung und GUI-Spezifikation

1. Die kompakte obere Leiste erhaelt ein Mikrofon-Symbol mit Tooltip "Diktat starten".
   Task-Favoriten bleiben sichtbar und behalten Nummerierung und Reihenfolge.
2. Erster Klick startet die Aufnahme vom aktuellen Windows-Standardmikrofon.
   Dieses wird bereits ueber die Audio-Ansicht gewaehlt; keine zweite Geraeteliste.
   Das beim Start geoeffnete Geraet bleibt fuer diese Aufnahme massgeblich.
3. Zeile 1 meldet gruen "Diktat laeuft" mit Aufnahmedauer. Zeile 2 zeigt einen
   einfachen laufenden Pegelverlauf. Dies zeigt den Eingangspegel, keine Spracherkennung.
   Mikrofonbutton erscheint aktiviert; Tooltip "Aufnahme beenden und transkribieren".
4. Zweiter Klick beendet die Aufnahme und startet genau eine Transkription.
   Status orange "Transkription laeuft - whisper.cpp/Vosk" mit bewegter Anzeige.
   Der Aufnahmebutton ist dabei deaktiviert. Keine Warteschlange oder Parallelaufnahmen.
5. Erfolg: Text in die Zwischenablage, Status gruen "Diktat in Zwischenablage".
   Der naechste Klick beginnt ein neues Diktat. Keine automatische Texteingabe.
6. Fehler rot mit konkretem naechstem Schritt; Hinweise orange. Die bisherige rote
   Farbe anderer Warnmeldungen wird nicht pauschal geaendert.
7. Keine verwertbare Aufnahme oder kein erkannter Text: Hinweis statt Erfolg;
   vorhandener Zwischenablageinhalt bleibt erhalten.
8. Falls die Zwischenablage belegt ist, bleibt nur das Ergebnis voruebergehend im RAM.
   Ein erneuter Kopierversuch wird angeboten. Ein neues Diktat verwirft das alte Ergebnis.
9. Kontextmenue des Mikrofonbuttons: "Aufnahme verwerfen" waehrend Aufnahme.
   Das verwirft Audio ohne Transkription. Ein komplexer Abbruch laufender Engines
   ist fuer Version 1 nicht erforderlich; beim echten Programmende werden eigene
   laufende Hilfsprozesse beendet und Ressourcen freigegeben.
10. X blendet TaskPlopp wie bisher aus; eine Aufnahme laeuft weiter. Das Tray-Symbol
    bzw. sein Tooltip kennzeichnet eine laufende Aufnahme. Wiederaufruf zeigt den
    aktuellen Diktatstatus erneut. Kein automatischer Aufnahmestart beim Programmstart.
11. Kein kuenstliches Zeitlimit und kein zeitgesteuerter automatischer Versand an
    eine Engine. Eine spaetere Zeitbegrenzung bleibt eine gesonderte Produktentscheidung.
    Tatsaechliche Aufnahme-/Speicherfehler stoppen die Aufnahme mit roter Fehlermeldung;
    Teilaufnahmen werden nicht stillschweigend als vollstaendiges Diktat gemeldet.
12. Andere ausdrueckliche Meldungen duerfen wie bisher die Statusleiste ersetzen.
    Kein Prioritaetsmanagement. Aufnahmestatus bleibt am Mikrofonbutton/Tray erkennbar;
    neue Diktatphasen und Wiederaufruf zeigen die passende Diktatmeldung erneut.

## Konfiguration und Einrichtung

Neuer Tab "Diktat" im vorhandenen Konfigurationsdialog:
- Engine: "whisper.cpp (lokal)" oder "Vosk (lokal)"; Startvorgabe whisper.cpp.
- Sprache zunaechst Deutsch, sichtbar erlaeutert; keine ungetestete Sprachkombinatorik.
- Pro Engine eine einfache Anzeige "Nicht eingerichtet / Bereit / Fehler".
- Button "Diktat-Komponenten installieren" richtet beide Engines und Modelle ein.
- Installation meldet Download/Entpacken/Pruefung und anschliessend Erfolg oder Fehler.
- Die Engine-Auswahl wird beim Aufnahmebeginn festgehalten. Aenderungen gelten erst
  fuer das naechste Diktat. Bestehende Speichern-/Abbrechen-Semantik bleibt erhalten.
- Einrichtung installiert lokale Komponenten unabhaengig vom Speichern der Auswahl;
  dieser Unterschied wird am Einrichtungsbutton kurz erklaert.

Installationsziel: %LOCALAPPDATA%\TaskPlopp\Dictation mit Unterordnern pro Engine/Modell.
Keine grossen Binaerdateien oder Modelle im Repository oder unter Syncthing.
Keine automatische Installation beim normalen Programmstart; nur ausdruecklicher
Einrichtungsbutton. Erneuter Klick verwendet bereits vollstaendig gepruefte Pakete.
Abgebrochene Downloads ergeben keinen Status "Bereit" und sind erneut startbar.

Versionen werden fest eingetragen, nicht blind als "latest" ausgefuehrt. Fuer den
Machbarkeitstest sind whisper.cpp b5454 und Vosk v0.3.45 Windows-x64 Kandidaten;
neuere kompatible offizielle Pakete koennen vor Umsetzung begruendet gewaehlt werden.
Downloads erfolgen ausschliesslich von fest eingetragenen offiziellen HTTPS-Quellen.
Vorhandene Herausgeber-Digests werden geprueft; der untersuchte whisper.cpp-Release
liefert SHA-256. Der Vosk-Release liefert keinen Digest: dies offen dokumentieren,
keinen unabhaengigen Herkunftsnachweis behaupten und keine separate Hash-Infrastruktur
aufbauen. Eigene Hashes dienen nur der Integritaet/Wiederholbarkeit der Einrichtung.
Lizenzen und Herkunft der konkret verwendeten Pakete/Modelle dokumentieren.
Installation im Benutzerordner benoetigt normalerweise keine Adminrechte. Fehlende
Systemlaufzeit oder Unternehmenssperren werden konkret gemeldet, nicht umgangen.

## Technische Umsetzung nach KISS

- PowerShell 5.1/WinForms bleibt die Anwendung; keine neue UI-Technologie.
- Eine kleine C#-Aufnahmeklasse nutzt WinMM und PCM, Ziel 16 kHz / 16 Bit / Mono.
  Vor Start Format und Standardgeraet pruefen. Standard bedeutet eCapture/eConsole;
  bei getrennten Rollen die zugehoerige WinMM-Geraete-ID ueber Endpoint-ID zuordnen
  (DRV_QUERYFUNCTIONINSTANCEID), nicht nur den Anzeigenamen oder WAVE_MAPPER annehmen.
  Bereits vorhandenes GetDefaultId(1,0) aus dem Audio-Modul dafuer wiederverwenden.
  Ein nicht unterstuetztes Format fuehrt
  zu verstaendlichem Fehler; notwendige Formatkonvertierung erst nach Praxistest entscheiden.
- Audiobloecke bleiben im RAM; Pegel wird aus denselben Bloecken berechnet.
- whisper.cpp laeuft als kurzlebiger versteckter Prozess mit binaerem WAV-Stream auf
  stdin, Sprache explizit -l de, ohne Zeitstempel (-nt), Zusatzdruck (-np) und GPU (-ng).
  Vollstaendiger Aufruf fuer den geprueften Windows-Stand b5454:
  whisper-cli.exe -m <ggml-base.bin> -f - -of taskplopp-stdout -l de -nt -np -ng
  Dabei KEINE -otxt/-oj/sonstigen Ausgabeformat-Flags setzen. Der virtuelle Basisname
  taskplopp-stdout (ungleich '-') aktiviert den normalen stdout-Segmentcallback;
  ohne Formatflag wird keine Ausgabedatei geoeffnet. Nur -f - ohne -of deaktiviert
  hier den Callback. -otxt -of - ist unter Windows ungeeignet, weil b5454 dafuer
  CON statt der umgeleiteten stdout-Pipe oeffnet. M1 muss diesen konkreten Aufruf
  am versteckten Windows-Prozess mit umgeleiteten Pipes nachweisen; Quellcode allein
  ersetzt den Binaernachweis nicht. Bei Versionswechsel den Vertrag erneut pruefen.
  CPU-Modus ist reproduzierbare Startvorgabe. Stdout wird als UTF-8 gelesen und liefert
  nur Transkript; Diagnosen auf stderr werden getrennt behandelt. Beide Ausgabestroeme
  parallel lesen, binaer in stdin schreiben und danach schliessen; kein Pipe-Deadlock.
  Exitcode, leeres Ergebnis und moegliche unvollstaendige Ergebnisse getrennt pruefen.
- Vosk nutzt seine native API ueber eine kleine C#-Anbindung, ohne Python. Die native
  DLL und ihre Abhaengigkeiten muessen vorab auf PS5.1/x64 praktisch geprueft werden.
  Bei accept_waveform == 1 den abgeschlossenen JSON-Segmenttext aus result sammeln;
  am Ende final_result ergaenzen. Abgeschlossene JSON-Ergebnisse als UTF-8 dekodieren, keine
  Teilhypothesen doppelt uebernehmen. Rueckgabewert -1 bedeutet Fehler. Saetze vor
  Sprechpausen duerfen beim abschliessenden Flush nicht verloren gehen.
- Rechenarbeit und Downloads laufen ausserhalb des UI-Threads. Fuer Vosk reicht ein
  einzelner C#-Worker; fuer whisper.cpp ein Prozess. UI uebernimmt Ergebnisse per Timer.
  Native Bibliotheksladeprobleme werden zuerst im Machbarkeitstest geloest; nur falls
  erforderlich wird Vosk ebenfalls in einen kleinen versteckten Helfer ausgelagert.
- Nur drei Ablaufphasen: bereit, Aufnahme, Transkription. Kein allgemeiner Jobmanager,
  kein Eventbus, keine Queues. Einrichtung und Diktat schliessen sich gegenseitig aus:
  keine Installation waehrend Aufnahme/Transkription, kein Start waehrend Installation.
  Dadurch werden geladene DLLs/Modelle nicht gleichzeitig ersetzt. Einfache deaktivierte
  Buttons reichen; kein allgemeines Sperrmanagement.
- GUI, globale Tastenkombination und Sperrtimer bleiben waehrend Verarbeitung aktiv.
- Nur gewaehlte Engine laedt ihr Modell; nach Verarbeitung Speicher wieder freigeben.
- WinForms-Zwischenablagezugriff erfolgt im vorhandenen STA-UI-Thread.
- RAM-Ablage bedeutet keine eigenen Audiodateien; Windows-Auslagerungsdatei und
  Speicherabbilder werden dadurch nicht ausgeschlossen. Zwischenablageverlauf und
  Windows-Cloud-Zwischenablage folgen den vorhandenen Windows-Einstellungen.
- Geheimnisse und Tresor sind fuer diese lokale Version nicht erforderlich.

## Geplanter Dateiumfang

Bestehende Dateien gezielt erweitern:
- TaskPlopp.ps1: Mikrofonbutton, Lebenszyklus, Tray-Rueckmeldung, UI-Anbindung.
- TaskPlopp.Configuration.ps1: Diktat-Tab und Einrichtung.
- TaskPlopp.Apps.ps1: Standardwerte und Validierung der Diktateinstellungen.
- TaskPlopp.Status.ps1: einfacher Pegel/Arbeitsindikator in den vorhandenen zwei Zeilen.
- config.example.json und README.md: Beispiel und Bedienung/Installation/Lizenzen.

Neue kleine Module, endgueltige Aufteilung nach Machbarkeitstest:
- TaskPlopp.Dictation.ps1: Ablauf, Engine-Auswahl und Ergebnisuebergabe.
- TaskPlopp.Dictation.cs: Aufnahme, Pegel und native Verarbeitung/Worker.
- Install-TaskPloppDictation.ps1: nachvollziehbare Paket-/Modelleinrichtung.
- Test-TaskPloppDictation.ps1 und gezielter GUI-Test.

Persoenliche Favoriten, Chrome-Profile, Ordner und bestehende PC-Sperrkonfiguration
werden weder ersetzt noch umsortiert. Andere Projekte bleiben unberuehrt.

## Milestones, Steps und Akzeptanzkriterien

### M1 - Technischer Durchstich vor GUI-Ausbau

Steps: Offizielle Pakete und Modelle benutzerlokal einrichten; Laufzeitabhaengigkeiten
pruefen; kurze Aufnahme vom echten Standardmikrofon; dieselbe Aufnahme an beide Engines
uebergeben; benoetigte Zeit, Audioformat und RAM-Verarbeitung feststellen.

Akzeptanz: Beide liefern deutschen Text auf diesem PC, keine Konsole, keine eigene
Audiodatei und keine erforderliche Admininstallation. Ungeloeste Abweichungen werden
benannt, bevor die komplette GUI darauf aufgebaut wird. Kein Geschwindigkeitsversprechen
allein aus Herstellerangaben. Den Test mit einem kurzen gesprochenen Satz muss Tobias
begleiten; vorhandene fremde Gespraeche werden nicht als Testmaterial verwendet.
Stop-Gate: Scheitert RAM-Verarbeitung, nativer Enginebetrieb oder Aufnahme wesentlich,
endet der technische Durchstich vor dem GUI-Ausbau. Befund, Folgen und kleinste
Alternative Tobias vorlegen; keine stillen Tempdatei-, Python-, Cloud- oder
Admin-Fallbacks. Kein neues Liveexperiment ausserhalb des freigegebenen Umfangs.

### M2 - Einrichtung und Konfiguration

Steps: Installationsfunktion und Diktat-Tab ergaenzen, Engine-Auswahl speichern,
fehlende/teilweise Einrichtung erkennen, Wiederholung testen.

Akzeptanz: Ein Button richtet beide Engines ein; Neustart erhaelt Auswahl; Abbrechen
im Konfigurationsdialog aendert keine Einstellung; bestehende Konfiguration migriert
mit Standardwerten; Netzfehler ergeben eine verstaendliche Meldung und erneuten Versuch.

### M3 - Aufnahme und Transkription in der GUI

Steps: Mikrofonbutton, Pegel, Dauer, Start/Stop/Verwerfen, Hintergrundverarbeitung,
Statusmeldungen, Clipboard und Freigabe der Aufnahme integrieren.

Akzeptanz: Erster Klick nimmt auf, zweiter transkribiert, Text entspricht dem rohen
Erkennungsergebnis. Nur eine Verarbeitung zugleich. Task-Favoriten und Audio-Ansicht
bleiben nutzbar. Kein UI-Stillstand, keine sichtbare Konsole, kein Audioarchiv.

### M4 - Abnahme und Dokumentation

Steps: Gezielte automatisierte Tests, vorhandene passende Regressionstests und kurze
manuelle Diktate mit beiden Engines. README um Einrichtung und Grenzen ergaenzen.

Akzeptanz: Saemtliche Pflichtnachweise der Verifier unten sind bestanden. Fehlende
oder gescheiterte Pflichtnachweise bleiben offen und verhindern die Gesamtabnahme;
Dokumentation einer Luecke ersetzt keinen Nachweis.
Keine unbeabsichtigten Favoriten-/Sperraenderungen. Git-Diff auf Scope und Geheimnisse
pruefen; Commit/Push nur nach entsprechendem Auftrag.

## Verifier

Automatisiert mit isolierter Konfiguration und synthetischen Audiopuffern:
- Defaults/Migration, ungueltige Engine und Speichern/Abbrechen.
- Start/Stop/Verwerfen, Doppelklick und keine parallelen Aufnahmen.
- Kein Mikrofon, Aufnahmefehler, leere Aufnahme, Engine fehlt, Prozessfehler.
- Stdout-Transkript strikt von stderr-Diagnosen trennen; Fehler niemals als Text kopieren.
- Vosk mit mindestens zwei abgeschlossenen Segmenten und finalem Rest testen:
  erwarteter Text aus festgelegten Ersatzantworten vollstaendig und ohne Duplikate.
- UTF-8-Umlaute, Sprechpausen und Whisper-Ausgabe ohne Zeitstempel gezielt pruefen.
- Echter Windows-whisper-Prozess: RAM-WAV nach stdin, Transkript aus stdout-Pipe,
  keine CON-Ausgabe, kein Dateischreiben. Modell und Testaudiomaterial getrennt pruefen.
- Diktat/Installation gegenseitig gesperrt; keine Ersetzung geoeffneter Komponenten.
- Belegte Zwischenablage und Kopierversuch mit zurueckgehaltenem Ergebnis.
- Speicher/Ressourcen nach Erfolg, Fehler, Verwerfen und echtem Programmende freigeben.
- Downloadfehler/Teilinstallation mit Testpaketen statt wiederholter grosser Downloads.
- Pegel/Status und Toolbar bei Mindestfenstergroesse, Schriftvergroesserung und Ausblenden.
- Bestehende Audio-, Tastatur- und PC-Sperrtests passend wiederverwenden; keine echte
  PC-Sperre ausloesen. Unterschied zwischen UI-Test und echter Tastatureingabe benennen.

Manuell mit Tobias:
- Je Engine denselben kurzen deutschen Satz sowie etwa eine Minute Diktat sprechen.
- Aufnahmezeit, Transkriptionszeit, erkannte Woerter und auffaellige Fehler vergleichen.
- Mikrofon ueber Audio umstellen, danach neue Aufnahme vom gewaehlten Mikrofon pruefen.
- Stille/abgezogenes Mikrofon fuehren zu Hinweis/Fehler statt falscher Erfolgsmeldung.
- Waehren Aufnahme ausblenden/wiederaufrufen; laufenden Zustand wiedererkennen.
- Ergebnis in einen lokalen Texteditor einfuegen; keine eigene Zusammenfassung/Bereinigung.
- Verarbeitung ohne Netzwerk nach Einrichtung pruefen, keine eigenen Audio-Tempdateien.

## Quellen der Discovery

- https://github.com/ggml-org/whisper.cpp
- https://github.com/ggml-org/whisper.cpp/releases/tag/b5454
- https://github.com/ggml-org/whisper.cpp/blob/b5454/examples/common-whisper.cpp
- https://github.com/alphacep/vosk-api
- https://github.com/alphacep/vosk-api/releases/tag/v0.3.45
- https://alphacephei.com/vosk/models
- https://learn.microsoft.com/en-us/windows/win32/api/mmeapi/nf-mmeapi-waveinopen

## P+-Reviewprotokoll

Fassung 1 wurde am 07.11.2026 von einem unabhaengigen Reviewer mit Zugriff auf den
Auftrag, diesen Plan und den vorhandenen TaskPlopp-Code geprueft. Kein Produktcode,
keine Installation, Aufnahme oder Liveaenderung wurde im Review ausgefuehrt.

Befunde und Aufloesung in Fassung 2:
- Unbeauftragtes 30-Minuten-Limit entfernt; keine automatische Transkription nach Zeit.
- Vosk sammelt alle abgeschlossenen Segmenttexte plus finalen Rest; Mehrsegment-Verifier.
- Whisper-Aufruf explizit Deutsch, ohne Zeitstempel, UTF-8 und getrennte Diagnosen.
- Einrichtung und laufende Diktate gegenseitig ausschliessen, ohne Sperrframework.
- Fehlende Pflichtnachweise verhindern Gesamtabnahme; kein Erfolg durch Dokumentation.
- Mikrofonrollen ueber vorhandene Endpoint-ID und WinMM-Mapping konkretisiert.
- Vosk ohne veroeffentlichten Digest: feste offizielle HTTPS-Quelle statt erfundener
  Pflicht zu unabhaengiger Hashquelle; Grenzen eigener Hashwerte offen dokumentiert.
- Explizites M1-Stop-Gate vor GUI-Ausbau bei wesentlichem Machbarkeitsfehler.

KISS-Einschaetzung: Vorhandene GUI und Statusleiste erweitern, ein Aufnahmeweg und
zwei konkrete Engine-Anbindungen. Genau eine Aufnahme/Transkription, kein Archiv,
Server oder generischer Anbieteradapter. Zusatzzustaende nur fuer tatsaechliche
Bedienungsanforderungen wie laufende Einrichtung und belegte Zwischenablage.

Runde 2: Bisherige Befunde behoben, aber Windows-whisper-CLI liefert bei nacktem
stdin-Aufruf keinen Text. In Fassung 3 den virtuellen Ausgabebasisnamen ohne
Dateiformat-Flags ergaenzt. Alternative -otxt -of - verworfen, weil b5454 unter
Windows CON statt der stdout-Pipe oeffnet. Dies wurde anhand desselben offiziellen
Quellcodes durch Autor und unabhaengigen Reviewer nachvollzogen. Echte Binaerpruefung
bleibt verpflichtend in M1 nach Ausfuehrungsfreigabe.

Runde 3: Unabhaengige Reviewfreigabe fuer die inhaltliche Fassung 3 erteilt.
Gepruefter SHA-256 vor diesem rein dokumentarischen Freigabevermerk:
2AF7F4A84077324CE5BA94DCF37A4C9A4B23F7FE923110B831AC63807C7DC09D
Reviewer: diktat_plan_review, getrennt vom Planverfasser; keine verbleibenden
blockierenden Befunde zu Ziel, Spec, Machbarkeit, KISS, Verifiern und Freigabegrenzen. P+-Reviewfreigabe autorisiert weder
Installation noch Produktimplementierung. Danach diese konkrete Fassung Tobias zur
X-/X+-Freigabe vorlegen. M1 benoetigt diese Ausfuehrungsfreigabe; die manuelle
Mikrofonaufnahme erfolgt erst mit Tobias, ohne Aufnahme fremder Gespraeche.

Ergaenzende Discoveryquelle:
https://learn.microsoft.com/en-us/windows/win32/coreaudio/device-roles-for-legacy-windows-multimedia-applications

## Umsetzung und Nachweise am 07.11.2026

Autorisierung: Tobias hat nach unabhaengiger Reviewfreigabe der Fassung 3 im Chat
explizit X+ beauftragt. Dies umfasst Umsetzung, passende Pruefungen, Dokumentation
und Git nach erfolgreicher fachlicher Abnahme. Kein erneuter Gitauftrag erforderlich.

Implementiert:
- Native WinMM-Aufnahme in PCM-RAM-Puffern mit eigener kleiner Pumpe, damit GUI-Arbeit
  keine Aufnahmebloecke verschluckt. Pufferueberlauf/entferntes Geraet wird als Fehler
  behandelt. Mikrofon wird anhand der eCapture/eConsole-Endpoint-ID zugeordnet.
- whisper.cpp als versteckter Prozess mit WAV-stdin/Text-stdout; Vosk ueber native
  API im C#-Worker, alle abgeschlossenen Segmente plus finaler Rest.
- Mikrofonbutton mit Start/Stop, Verwerfen/Kopierwiederholung im Kontextmenue,
  gruener Pegel und Dauer, orange Arbeitsanzeige, Fehler und Clipboard-Erfolg.
- Diktat-Konfiguration, Engine-Auswahl fuer naechste Aufnahme, versteckte Einrichtung
  beider Engines mit Fortschritt auch im Konfigurationsdialog. Einrichtung und
  Diktate sind gegenseitig ausgeschlossen. Keine automatische Modellinstallation.
- Keine eigenen Audio-/Textdateien; kein API-Schluessel/Tresorzugriff. Komponenten
  und Modelle ausschliesslich unter LOCALAPPDATA, persoenliche Favoriten erhalten.

Installiert und praktisch unter Windows PowerShell 5.1 x64 geprueft:
- whisper.cpp b5454 Windows-x64, mehrsprachiges base-Modell; Vosk v0.3.45 Windows-x64
  und vosk-model-small-de-0.15. Kein Admin, Python oder GPU erforderlich gewesen.
- Beide Engines liefern den vollstaendigen kuenstlich gesprochenen deutschen Testsatz.
  Letzte Messung rund 1.05 s Whisper / 0.92 s Vosk; dies ist synthetisches Testmaterial,
  kein Qualitaets-/Geschwindigkeitsversprechen fuer Tobias' Stimme oder lange Diktate.
- Standardmikrofon-ID und 16-kHz/16-Bit/Mono-Format per WAVE_FORMAT_QUERY bestaetigt.
  Dabei keine Aufnahme gestartet. Echte Mikrofonaufnahme bleibt offen.
- Installerlauf mit beiden Modellen erfolgreich; Whisper-Release-Digest geprueft.
  Zusaetzlich SHA-256 des base-Modells aus Hugging-Face-LFS-Metadaten der gepinnten
  Revision geprueft: 60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe.

Automatisierte Nachweise:
- Test-TaskPloppDictation.ps1: WAV, UTF-8-/Mehrsegmenttext, Prozessfehler; lokale
  Ersatzdaten fuer Downloadabbruch/Pruefsummenfehler/Cache/Teil-Datei-Cleanup;
  versteckter Installer mit Fortschritt, stderr/Exitcode und Prozessbeendigung.
- Mit -Engines: beide nativen Engines erhalten denselben synthetisierten Testsatz
  im RAM; gesamter normalisierter Satz wird gegen die festgelegte Erwartung geprueft.
- Test-TaskPloppDictationUi.ps1 -Engines: temporaere Konfiguration; Engine speichern/
  abbrechen, Mindestbreite ohne Toolbar-Umbruch, Pegel und grosse Schrift, keine
  Parallelaufnahme waehrend Installation/Transkription, Clipboardfehler und erneutes
  Kopieren an simulierter Schreibgrenze, leeres/fehlerhaftes Ergebnis, Verwerfen,
  fehlende Einrichtung. Beide echten Engines durch den GUI-Stop/Transkriptionsablauf;
  unabhaengiger UI-Heartbeat laeuft waehrenddessen weiter. Keine Mikrofonaufnahme.
- Bestehende Apps-, Audio-, Audio-UI-, Keyboard- und IdleLock-Pruefungen bestanden,
  jeweils unter PS5.1. Physische Tastatur/Escape bewusst SKIP ohne aktiven Desktop.
- Bestehender Test-TaskPlopp.ps1: Konfigurationspruefungen bestanden; echte
  Testfensteraktivierung in dieser Sitzung fehlgeschlagen. Keine Behauptung eines
  bestandenen Fokus-/Citrix-Nachweises; vor fachlicher Gesamtabnahme offen benennen.
- GUI-Vorschauen per DrawToBitmap erstellt und visuell geprueft. Keine abgeschnittene
  Mikrofontaste bei Mindestbreite; Status und Diktatkonfiguration lesbar.

Betrieb: bisheriger eindeutig zugeordneter TaskPlopp-Prozess 16776 ohne offenen
Konfigurationsdialog beendet; neue GUI versteckt gestartet und als Prozess 27620
mit sichtbarem TaskPlopp-Fenster bestaetigt. Startup-Link bleibt bestehen.
Es wurde keine Aufnahme automatisch gestartet und keine persoenliche Zwischenablage
fuer automatische Tests veraendert. Keine anderen Anwendungsprozesse beendet.

Noch offene Pflichtabnahme mit Tobias:
- Tatsaechliche Mikrofonaufnahme/Pegel, kurze und ca. einminuetige Diktate mit beiden
  Engines, vollstaendiges Ergebnis und reales Einfuegen aus Zwischenablage.
- Wechsel auf ein anderes Mikrofon ueber Audio und anschliessende Aufnahme;
  Stille/entferntes Mikrofon, Ausblenden/Wiederaufruf waehrend Aufnahme.
- Offlineprobe nach Einrichtung. Der produktive Verarbeitungscode enthaelt keine
  Netzwerkaufrufe; ein tatsaechlich deaktiviertes Netzwerk wurde nicht getestet.
- Aktiver lokaler Desktop/Fokusnachweis, soweit in dieser Sitzung moeglich.

Gesamtabnahme bleibt offen. Fehlende manuelle Nachweise werden nicht durch
synthetische Tests ersetzt.

Tobias hat anschliessend im Chat ausdruecklich den sofortigen Git-Push des
aktuellen Stands vor der manuellen Abnahme beauftragt; er testet spaeter am PC.
Dies hebt fuer diesen Stand die zuvor vorgesehene Reihenfolge Abnahme vor Git auf.
Die offenen Praxistests und ihre fachlichen Nachweise bleiben unveraendert offen.
