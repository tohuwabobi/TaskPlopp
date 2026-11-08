# Verifier: Hotkey durch Tastendruck aufnehmen

Auf Wunsch von Tobias ersetzt eine Aufnahme die Auswahlliste und Modifier-Haekchen.
Button klicken -> Aufforderung im bestehenden Konfigurationsfenster -> Tastendruck
-> bestehende Pruefung/Registrierung und Sofortspeicherung. Keine Popups, neuen Farben,
Pakete oder C#-Quellen. Weiter PowerShell 5.1. Bestehende Konfiguration bleibt lesbar.

Normale Tastaturereignisse am fokussierten Aufnahmefeld; waehrend Aufnahme zusaetzlich
ein 25-ms-WinForms-Timer fuer gedrueckte Tasten, einschliesslich Sondertasten und Win.
Nur das aktuelle Down-Bit von GetAsyncKeyState, nicht das unzuverlaessige Pressed-Bit.
Bereits beim Start gehaltene Tasten werden fuer Polling erst nach erneutem Druecken
beruecksichtigt. Keine dauerhafte Tastenerkennung, kein Hook, kein Tastaturprotokoll.
Escape/Button/Tabwechsel/Fokusverlust/Schliessen stoppen; Timer wird beim Schliessen
entsorgt. Bei Fokusverlust letzte Abfrage, falls eine Sondertaste ihre bisherige App
oeffnet. Das verhindert die Standardaktion einer bisher unregistrierten Sondertaste
nicht allgemein; ein sehr kurzer anderweitig abgefangener Druck kann unerkannt bleiben.

Buchstaben/Ziffern/Numpad/F-Tasten/Navigation mit Zusatztaste, Browser/Medien/Starttasten
auch alleine. Escape ist Abbruch, F12 bleibt reserviert. Nur Modifier werden ignoriert.
Belegte/ungueltige Kombination oder Schreibfehler: bisheriger Hotkey bleibt erhalten.

PS5.1-Tests bestanden:
- Synthetische echte WinForms-KeyDown-Ereignisse: Strg+Alt+Umschalt+P sofort
  gespeichert/angezeigt; Modifier alleine aendern nichts; Taschenrechner ohne Modifier.
- Sondertasten-Polling beim Deactivate mit Ersatzdaten: LaunchMail wird gespeichert.
- Escape, Button-Abbruch und Tabwechsel; nackter Buchstabe und F12 ersetzen nichts.
- Reale Windows-Registrierung der Taschenrechner-Taste ohne Modifier und synthetische
  WM_HOTKEY-Benachrichtigung an WakeEvent; anschliessend sauber freigegeben.
- Bestehender echter Hotkey-Wechsel/Konflikt/Schreibfehler, Native-Quellcodeaudit,
  Sofortspeichern und ZIP-Transfer bestanden. Produktive Belegung nicht veraendert.

Manuell noch offen: nach Neustart echte Logitech-Taste aufnehmen, danach TaskPlopp
per dieser Taste oeffnen; auch im Citrix-Vollbild pruefen. Keine umfassende Garantie
fuer Sondertasten, die Logitech-Treiber oder Windows vor TaskPlopp anderweitig verarbeiten.

Quellen:
https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.form.keypreview
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getasynckeystate
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey
