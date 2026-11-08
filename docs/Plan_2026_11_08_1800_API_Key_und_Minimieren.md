# API-Key einrichten und Taskleiste / Infobereich - P+ dann X+

Tobias hat am 08.11.2026 P+ und anschliessend X+ fuer beide Aenderungen erteilt. Nach unabhaengigem Review direkt umsetzen; keine erneute Umsetzungsfreigabe erforderlich.

## Ziel
Auf jedem PC kann Tobias den OpenAI-Key selbst ueber TaskPlopp einrichten. Minimieren behaelt einen normalen Taskleisten-Eintrag; das Fenster-X zieht TaskPlopp in den Infobereich neben der Uhr zurueck. Kein sichtbares Konsolenfenster.

## Scope / KISS
PowerShell 5.1 und vorhandene WinForms. Keine Popups, neuen Farben, C#-Quellen, Paketinstallation, API-Anfragen oder Schluesseluebertragung zwischen PCs/Chats. Kein neuer Secretmanager oder komplexer Transaktionszustand. Bestehende DPAPI-Datei und Worker-Schnittstelle bleiben kompatibel. Keine Logitech-Sondertasten in diesem Auftrag.
Bestehende README-/Setup.bat-Aenderungen von HSPWO-GANDALF erhalten. Aktueller Host laut Tobias HSPWO-ARKANIS; zweiter bestaetigter Host HSPWO-GANDALF. Tests veraendern keine produktive Schluesseldatei.

## Spec API-Key
- Im bestehenden Reiter Konfiguration > Fensterordner: beschriftetes Eingabefeld mit UseSystemPasswordChar, anfangs leer. Vorhandenen Key niemals in die Maske laden. Nur Zustand anzeigen: nicht eingerichtet / lokal eingerichtet (nicht online geprueft) / Datei nicht verwendbar.
- Eigener Button API-Key speichern uebernimmt nur den Key sofort. Erklaerender Text: getrennt von den anderen Einstellungen; Abbrechen des Konfigurationsdialogs macht einen bereits gespeicherten Key nicht rueckgaengig. Kein Loesch-/Anzeigen-/Online-Test-Feature.
- Leer/ungueltig: nichts aendern, bestehende Datei behalten, rote Meldung in der vorhandenen Konfigurations-Statusleiste. Akzeptierter Formatvertrag: getrimmter Text ^sk-[A-Za-z0-9_-]+$. Das bestaetigt nur lokale Form, keine Gueltigkeit gegen OpenAI.
- UTF-8-Keybytes mit DPAPI CurrentUser ohne Entropie schuetzen. Binaer nach %LOCALAPPDATA%\TaskPlopp\Secrets\OpenAI.dpapi speichern. Im Zielordner nur verschluesselte temporaere Datei; vor Veroeffentlichung entschluesseln und Bytes vergleichen. Vorhandene Datei atomar mit File.Replace ersetzen, sonst File.Move. Fehler vor Veroeffentlichung erhalten Originaldatei. Tempfile im finally entfernen; Bytepuffer loeschen. Kein Klartext in Dateien, Ausgaben, Fehlertexten oder JSON-Konfiguration.
- Erfolg: Eingabefeld leeren, Zustand aktualisieren und gruene Statusmeldung, ausdruecklich ohne Online-Pruefung. Fehler: generische sichere rote Meldung; Feld bei Fehler behalten, damit man Eingabe korrigieren kann. Zustand auf Oeffnen anhand lokaler Entschluesselbarkeit/Format pruefen, ohne Key anzuzeigen.
- Kleine Helfer im vorhandenen TaskPlopp.WindowLayout.ps1 fuer festen Keypfad, lokale Zustandspruefung und atomisches Speichern. Fuer isolierte Tests expliziter alternativer Pfad; Produkt verwendet festen lokalen Pfad. API-Lesepfad denselben Helfer verwenden. config.json/ZIP enthalten weiterhin nur Modellname, keinen Key.

## Spec Minimieren / X
- Hauptformular ausdruecklich ShowInTaskbar=true. Normaler Minimierbutton funktioniert als Windows-Minimieren; keine Hide-Aktion bei Resize/Minimized.
- Kleiner Helfer Minimize-TaskPlopp stellt sicher, dass die GUI sichtbar registriert bleibt, und setzt WindowState=Minimized. Nach erfolgreicher Favoriten-/Fensterauswahl, Start eines Favoriten, Citrix-Aktion sowie nach KI-Anordnung/Undo diesen Helfer statt Hide bzw. internem Close verwenden. Diese automatischen Rueckzuege sind normales Minimieren.
- X oben rechts: bisherigen residenten FormClosing-Pfad beibehalten (Hide, Prozess/Tray/Hotkey laufen weiter), damit der Taskleisteneintrag verschwindet und das Tray-Symbol bleibt. Explizites Beenden im Tray beendet weiterhin das Programm. Test-/Smoke-Modi duerfen weiterhin wirklich schliessen.
- Hotkey, Tray-Oeffnen und normaler Windows-Taskleistenklick stellen die GUI wieder her. Bestehenden Raise/Restore-Weg nutzen; keine weitere Zustandshistorie.
- Kurzes Hide fuer unverdeckten Screenshot bleibt als interne Ausnahme erhalten; CaptureDone zeigt GUI wieder. Laufende Aufnahme/Transkription laufen beim Minimieren und X weiter. Bestehende Abbruch-/Schliessensperre waehrend KI-Apply/Undo beibehalten.

## Milestones / Dateien
1. Schluesselhelfer und Keymaske: TaskPlopp.WindowLayout.ps1, TaskPlopp.Configuration.ps1. Bestehendes Key-Lesen auf festen Helfer abstimmen.
2. Hauptfenster/Rueckzug: TaskPlopp.ps1 und TaskPlopp.WindowLayout.ps1. Keine Aenderung der globalen Hotkeyregistrierung oder Aufnahme-Engine.
3. Zielgerichteter Test Test-TaskPloppKeyAndWindow.ps1; passende bestehende Resident-/Layout-/Diktat-/Transfer-Tests. README und Verifier; Themenliste aktualisieren. Plan/Review nur Dokumente bis zum Abschluss des P+-Cycles.
4. Eigencheck, Tests, G (Commit und Push), manuelle Grenzen benennen. Keine produktive Instanz waehrend Aufnahme ungeprueft neu starten.

## Verifier / automatische Abnahmetests
- Isolierte temporaere Pfade mit eindeutig kuenstlichen sk-Testwerten: DPAPI-Roundtrip, Erstsave und Ersetzen, leere/ungueltige Eingabe laesst Originalbytes gleich, kaputte DPAPI-Datei wird als unverwendbar erkannt, Speicherfehler hinterlaesst keinen neuen Key/Tempfile. Keine echte Schluesseldatei lesen/ueberschreiben fuer Tests und keine API-Anfrage.
- GUI: PasswordChar aktiv, Eingabefeld leer bei Oeffnen, eigener Keysave leert Eingabe und zeigt gruene lokale Erfolgsmeldung; Fehler bleibt im Dialog rot. Bestehender Key wird nicht angezeigt. Abbrechen anderer Einstellungen nimmt separaten Keysave nicht zurueck. Modell/Favoriten und deren Abbrechen bleiben erhalten.
- Echte Test-GUI: Minimieren ergibt Visible=true, ShowInTaskbar=true, WindowState=Minimized/IsIconic; Restore per vorhandener Funktion wird normal sichtbar. X im ResidentTest blendet aus (Visible=false), gleicher Prozess bleibt am Leben; erneutes Oeffnen funktioniert. Explizites ExitRequested schliesst wirklich.
- Automatisches Minimieren nach ausgewaehlten lokalen Aktionen sowie KI-Ergebnis/Undo durch geeignete Fixtures testen, ohne Benutzerfenster zu bewegen. Capture-Hide bleibt bis CaptureDone erhalten. Diktat- und Transfer-Regressionen pruefen; ZIP enthaelt keine Schluesseldatei oder Klartexte.
- Sourceaudit: PS5.1-Syntax, keine Compiler/C#/Popupquellen; CRLF. Keine neuen Farben.

## Manuelle Abnahme mit Tobias
- Auf ARKANIS und GANDALF: Konfiguration > Fensterordner, Key verdeckt einfuegen, API-Key speichern, gruene lokale Meldung; Fensterordner danach separat praktisch testen. API-Gueltigkeit ist ohne Liveanfrage nicht behauptet. Einrichtung braucht weder Konsole noch Adminrechte.
- Minimierbutton: Symbol bleibt in Windows-Taskleiste und laesst sich anklicken. X: Symbol verschwindet dort, Tray neben Uhr und Hotkey funktionieren weiter. Favoritenwahl/erfolgreiche Anordnung minimieren in Taskleiste. Explizit im Tray beenden funktioniert.
- WinForms-/Native-Merkmale sind automatisiert messbar; echte Shell-Darstellung/Tray-Interaktion auf beiden PCs bleibt manueller Nachweis. Keine reale Desktopuebertragung im automatischen Test.

## Review
Unabhaengig freigegeben durch transfer_plan_review. Gepruefter Inhaltsstand vor diesem Reviewvermerk: SHA256 C6B10809725B9AD66E6650FEFAC3432AC4851D85B81A2810004805DE871EFA50. Keine blockierenden Befunde. Hinweise fuer Umsetzung: UI-Aktualisierung nach erfolgreichem Schluesselaustausch nicht als fehlgeschlagenes Speichern melden; Minimieren -> X -> Hotkey und Speicherfehler bei bestehender Datei testen. Tobias hat anschliessendes X+ bereits ausdruecklich autorisiert.