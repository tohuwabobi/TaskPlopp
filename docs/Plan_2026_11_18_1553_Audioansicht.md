# Plan: Audiogeräte sortieren und kontrastreich anzeigen

## Ziel und Umfang
In der zweispaltigen Audioansicht sind Geräte schneller zu finden und Windows-Standards sofort zu erkennen. Betroffen sind `src/TaskPlopp.Audio.ps1`, die vorhandenen Audio-Tests und die einschlägigen README-Zeilen. Die Umsetzung erfolgt ausschließlich in Windows PowerShell 5.1 mit den vorhandenen WinForms-Steuerelementen. Audio-Umschaltung, Diktat, Statusfarben, Konfiguration und native Schnittstellen bleiben unverändert. Keine neuen Pakete oder Popups.

## M1 – Gerätenamen, Ordnung und Palette
1. Einen kurzen Anzeigenamen aus dem Windows-Namen ableiten. Nur klare generische Klammerformen wie „Lautsprecher (3- Realtek(R) Audio)“ und „Mikrofon (Jabra Link 380)“ kürzen. Bei Geräten mit eigenem Namen plus Treiberklammer wie „LG ULTRAWIDE (NVIDIA High Definition Audio)“ den vorangestellten Gerätenamen anzeigen. Unklare oder leere Ableitungen fallen auf den Originalnamen zurück. Windows-Geräteidentität und Umschaltung laufen wie bisher über die Endpoint-ID.
2. Lautsprecher und Mikrofone separat nach Anzeigename sortieren, bei Gleichstand nach Originalname und dann ID. Bei gleichen Kurznamen in einer Spalte die unterscheidbaren Originalnamen auf den Buttons anzeigen. Sortierung und vorhandene Tastenzuordnung folgen weiter derselben Reihenfolge.
3. Die Palette in der vorhandenen Registrierungsreihenfolge spaltenübergreifend vergeben: zuerst alle Lautsprecher, dann alle Mikrofone. Gelb #FDE047, Rot #F87171, Blau #60A5FA, Grün #4ADE80, Pink #F472B6, Orange #FB923C. Danach wiederholen. Damit unterscheiden sich die ersten sechs Geräte. Farbe und Tastennummer bleiben beim Wechsel des Standards mit unveränderter Geräteliste stabil. Änderungen an der Geräteliste können beides neu zuordnen.
4. Die bisherige Hash-/HSV-Farbwahl, die gleichfarbige Gerätepaare erzeugt, durch die feste Liste ersetzen. Container-ID nur entfernen, wenn die Quellsuche weiterhin keinen anderen Konsumenten ergibt. README anpassen.

## M2 – Zustand und Lesbarkeit
- Schwarze Schrift auf den Farbflächen. Die gleiche Hintergrundfarbe auch für Hover und gedrückte Buttons setzen. Die vorhandene sichtbare Tastatur-Fokusmarkierung erhalten. Ein dunkler, dicker Rahmen kennzeichnet Geräte mit bestätigten Standardrollen. Im Buttontext stehen nur Tastenkürzel und Gerätename. Der Tooltip zeigt den vollständigen Windows-Namen und die bestätigten Standardrollen separat, auch bei aufgeteilten Rollen. Fehlerhafte Rollen zählen nicht.
- Gerätenamen innerhalb der Buttonbreite auf bis zu zwei Zeilen umbrechen. Bei Platzmangel kürzen, den vollständigen Windows-Namen im bestehenden Tooltip zeigen. Vorhandene Spalten und Bedienelemente weiterverwenden.

## Abnahme
- Vorhandene Audio- und Audio-UI-Tests unter Windows PowerShell 5.1 ohne Hardware-Umschaltung ausführen. Die bisherige Gleichfarben-Erwartung gezielt ersetzen.
- Synthetische Geräte in gemischter Eingangsreihenfolge mit generischen Präfixen, Originalnamen, gleichen Kurznamen und mindestens sieben Einträgen verwenden. Erwartete sichtbare Ordnung, sechs eindeutige Farben vor der Wiederholung und Tastennummern explizit prüfen.
- Standardrollen im Test umsetzen und die Ansicht aktualisieren. Rahmen und Rollenzeile im Tooltip folgen dem bestätigten Standard, Farben, Tastennummern und Klickziele bleiben stabil. Buttontext ohne Aktivitätsmarker und Rollennamen prüfen. Geteilte und fehlerhafte Rollen abdecken.
- Textkontrast unabhängig aus den tatsächlich am Button gesetzten Schrift- und Hintergrundfarben (normal, Hover und gedrückt) nachrechnen: mindestens 7:1 (berechnet 7,6:1 bis 15,9:1). Sichtprüfung in normaler Breite, Mindestbreite und großer Schrift einschließlich sichtbarem Tastaturfokus. Ein Tooltip zeigt lange Originalnamen unverändert.
- Keine Produktinstanz stoppen, keine Audiogeräte wechseln und keine Dateien außer diesem Plan ändern, solange X oder X+ für die konkrete Fassung aussteht.

KISS: Feste Farbliste und ein Anzeige-/Sortierschritt im vorhandenen Aufbau. Keine Speicherung der Farbzuordnung, kein neues Einstellungsmenü und keine Änderung der Audio-API.

## P+-Review
Unabhängig geprüft und freigegeben: b384745c6ace025fecb85ed1c3b1d040c192d9d5.
Befunde erledigt: Kontrast auch bei Hover und gedrücktem Button geprüft,
Tastaturfokus sichtbar, unterscheidbare Originalnamen bei gleichen Kurznamen.
Tobias hat danach den Aktivitätszusatz aus der Buttonbeschriftung gestrichen und PowerShell 5.1 als einzige Sprache bestätigt. Umsetzung nach X oder X+ für die überarbeitete Fassung.
Erneutes unabhängiges Review der überarbeiteten Fassung: 088106822772cfed7d76f26dc3faafd4e436ff54, freigegeben.

X+ von Tobias für diese Fassung erteilt.

## X+ – Nachweis
Audio-, Audio-UI-, Native- und Diktat-UI-Tests bestanden unter Windows PowerShell 5.1 STA. Audio-UI mit sieben synthetischen Geräten: Reihenfolge, differenzierte Namen bei Kollision, Kontrast und Palette, Aktivrahmen, Tooltip sowie stabile Tasten beim Wechsel bestätigt. Vorschauen in drei Fenster-/Schriftgrößen geprüft. Bei Mindesthöhe kann WinForms in überfüllten Spalten auch horizontale Scrollleisten anzeigen. Die Buttons passen weiterhin in beide Spalten. Die fokusabhängige Escape-Prüfung wurde auf dem Testdesktop übersprungen. Die Wiedergabe- und Aufnahmestandards wurden nicht verändert.
