# Verifier: Standard Strg+NumPad0 und Hilfe im Hauptfenster

## Umsetzung
PowerShell 5.1, bestehende WinForms-Ansichten und Windows-Registrierung. Kein C#,
neue Pakete/Compiler, Popup, neues Fenster, Farbe oder Einstellungsfeld.
Fehlende Hotkeywerte ergeben nun Strg+NumPad0 (Modifier 2, VK 0x60). Beispiel und
aktive README-Anweisungen angepasst; gespeicherte Belegungen unveraendert.

Rechts ? / Aktualisieren / Zahnrad; ? wird in Help zum Zurueck-Pfeil. Help als dritte
Ansicht im vorhandenen ListPanel, ein schreibgeschuetzter RichTextBox-Hilfetext.
Status-RowStyle Absolute/0 und MessageBar unsichtbar; komplette Inhaltsflaeche unter
Toolbar. Beim Verlassen wieder AutoSize, vorher abgelaufene Meldungen bereinigen.
Vorherige Ansicht fuer Zurueck/Escape merken. Audio-Rueckkehr nutzt KeepMessage.
Direkte Tasks-/Audio-Renderer lassen Help stehen. Refresh in Help belaesst Status.
Der zweite Escape-Handler respektiert Handled, damit Help-Escape nicht zusaetzlich
einen Fensterauftrag abbricht. Mindestbreite aus echten Toolbarbreiten und Rahmen.

## Bestandene Tests unter Windows PowerShell 5.1 auf ARKANIS
- Hotkey: neue Defaults, 0x4002 inkl. NoRepeat, VK 0x60 gegen Oberreihen-0 0x30;
  bestehendes explizites Strg+Alt+F10 unveraendert. Bestehende Registrierung,
  Konflikte/Dateifehler, Tastaturaufnahme und Sofortspeichern weiter bestanden.
- Keyboard: in Help keine 1/0/A-Z-Favoritenaktion, Escape geht zurueck; bisherige
  Tasks-/Audio-/Space-/Dialogschutz-Pruefungen bestanden.
- Layout: normale Groesse sowie kleine Fenster, grosse Schrift, alle Toolbarbuttons
  vollstaendig sichtbar und ohne Ueberlappung. Durch berechnete Mindestbreite kann
  die vorherige Wunschbreite 420/460 nicht mehr unter das benoetigte Minimum sinken.
- Help aus Tasks/Audio, dynamischer aktueller Hotkey, RichTextBox schreibgeschuetzt,
  Schriftgroesse gleich Hauptfenster; OpenForms-Zahl bleibt unveraendert.
- Bounds: Hilfetext startet direkt unter Toolbar plus vorhandenem Innenrand und
  reicht bis unteren Innenrand. Statuszeile hat wirklich null Hoehe. Kein leerer
  Statusblock und keine aeussere horizontale Scrollbar; vertikales Textscrollen erlaubt.
- Refresh/direkte Renderer erhalten Hilfe und verdeckte Meldung; Rueckkehr von echter
  Konfiguration erhaelt Hilfe. Zurueck/Escape, Audio-Button und globales Show geprueft.
- Help-Escape durch beide echten Main-KeyDown-Handler: simuliertes LayoutJob-Objekt
  bleibt unveraendert, Cancel nicht gerufen. Test stellt vorher Fokus auf Main her
  und entfernt das Ersatzobjekt auch bei Fehlern; kein echter API-/Aufnahmeauftrag.
- Help -> Audio erhaelt Recording-Activity und Pegeldaten; eine waehrend Help gesetzte
  Erfolgsmeldung bleibt erhalten. Abgelaufene Meldung ist bei Rueckkehr sofort leer.
- Native-Quellcodeaudit, AudioUi und Autosave-Regressionen bestanden. Kein echter
  Mikrofontest, API-Aufruf, Sperrvorgang oder produktiver Hotkeywechsel.

## Visuelle Kontrolle
RichTextBox wird von DrawToBitmap nicht verlaesslich mit Text gerendert. Darum finale
Kontrolle per lokalem Screenshot ausschliesslich des aktiven eigenen Testfensters,
mit physisch korrektem DPI-Kontext und gepruefter Lage innerhalb der Arbeitsflaeche.
Erster wegen Windows-Skalierung verschobener Ausschnitt geloescht. Finale Vorschau
zeigt grossen lesbaren Text, rechte Zurueck-/Refresh-/Zahnradgruppe, keine Statusluecke.
Keine Aufnahme an einen Dienst hochgeladen, keine Vorschaubilder im Git.

## Offene manuelle Abnahme
Echter Strg+NumPad0-Druck mit NumLock an/aus und Citrix-Vollbild auf dem Test-PC.
Bei ausgeschaltetem NumLock kann Windows eine andere Taste melden; keine identische
Erkennung behauptet. Bestehende Nutzerbelegung wird beim Update bewusst beibehalten.
Hilfe per ? oeffnen, untenliegende Abschnitte scrollen, Escape/Zurueck praktisch pruefen.
