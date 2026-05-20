# WhisperWriter — Installation auf Windows mit NVIDIA-GPU

Kostenlose, lokale Spracheingabe per Hotkey für Windows. Hält F9 → reden → loslassen → Text erscheint im aktiven Textfeld. Alles läuft offline auf deinem PC.

## Voraussetzungen

- **Windows 10 / 11**
- **Python 3.10** (3.11 geht auch, 3.12+ nicht — manche Pakete unterstützen es noch nicht)
  - Download: https://www.python.org/downloads/release/python-31011/
  - Bei Installation **"Add Python to PATH"** anhaken
- **Git für Windows**: https://git-scm.com/download/win
- **NVIDIA-Grafikkarte** mit aktuellem Treiber empfohlen (RTX 20-Serie oder neuer)
  - Ohne GPU geht's auch, aber langsam (Sätze brauchen mehrere Sekunden statt Millisekunden)
- **Mindestens 5 GB freier Speicher** (Modell + Dependencies)

---

## Installation

Öffne PowerShell oder Git Bash und führe folgende Schritte aus.

### 1. Repository klonen

```bash
mkdir C:\Tools
cd C:\Tools
git clone https://github.com/savbell/whisper-writer.git
cd whisper-writer
```

### 2. Virtuelle Python-Umgebung anlegen

```bash
python -m venv venv
venv\Scripts\activate
python -m pip install --upgrade pip
```

### 3. Audio-Bibliothek `av` als Binary installieren

Der gepinnte alte `av==11.0.0` aus der requirements.txt baut nicht mehr für Python 3.10 — daher zuerst eine neuere Binary-Version:

```bash
pip install --only-binary=:all: av
```

### 4. Requirements bereinigen und installieren

Die mitgelieferte `requirements.txt` ist UTF-16 codiert und pinnt `av` auf eine kaputte Version. Saubere Variante erstellen:

```bash
python -c "open('requirements-clean.txt','w',encoding='utf-8').writelines(l for l in open('requirements.txt',encoding='utf-16') if not l.lower().startswith('av=='))"
pip install -r requirements-clean.txt
```

### 5. PyTorch mit CUDA-Unterstützung

Nur wenn du eine NVIDIA-GPU hast:

```bash
pip install torch --index-url https://download.pytorch.org/whl/cu121
```

Ohne NVIDIA-GPU einfach `pip install torch` (CPU-Version).

### 6. Aktualisierte Whisper-Engine + cuDNN-Bibliotheken

Die mitgelieferte `ctranslate2`-Version ist veraltet und bringt fehlende cuDNN-Probleme. Auf neue Version upgraden:

```bash
pip install -U ctranslate2 faster-whisper nvidia-cudnn-cu12 nvidia-cublas-cu12
```

### 7. WICHTIG: main.py patchen (PyQt5/CUDA-Konflikt umgehen)

**Ohne diesen Patch crasht das Programm beim Modell-Laden mit Segmentation Fault.** Grund: PyQt5 und ctranslate2 streiten sich um native Threading-Bibliotheken, wenn Qt zuerst initialisiert wird.

Öffne `src\main.py` in einem Editor und ersetze die ersten 11 Zeilen:

**Vorher:**
```python
import os
import sys
import time
from audioplayer import AudioPlayer
from pynput.keyboard import Controller
from PyQt5.QtCore import QObject, QProcess
from PyQt5.QtGui import QIcon
from PyQt5.QtWidgets import QApplication, QSystemTrayIcon, QMenu, QAction, QMessageBox

from key_listener import KeyListener
from result_thread import ResultThread
from ui.main_window import MainWindow
from ui.settings_window import SettingsWindow
from ui.status_window import StatusWindow
from transcription import create_local_model
from input_simulation import InputSimulator
from utils import ConfigManager
```

**Nachher:**
```python
import os
import sys
import time

# Modell VOR Qt laden (sonst Segfault auf Windows)
from transcription import create_local_model
from utils import ConfigManager
ConfigManager.initialize()
_PRELOADED_MODEL = None
if ConfigManager.config_file_exists() and not ConfigManager.get_config_section('model_options').get('use_api'):
    _PRELOADED_MODEL = create_local_model()

from audioplayer import AudioPlayer
from pynput.keyboard import Controller
from PyQt5.QtCore import QObject, QProcess
from PyQt5.QtGui import QIcon
from PyQt5.QtWidgets import QApplication, QSystemTrayIcon, QMenu, QAction, QMessageBox

from key_listener import KeyListener
from result_thread import ResultThread
from ui.main_window import MainWindow
from ui.settings_window import SettingsWindow
from ui.status_window import StatusWindow
from input_simulation import InputSimulator
```

Zusätzlich: in `initialize_components()` die Zeile

```python
self.local_model = create_local_model() if not model_options.get('use_api') else None
```

ersetzen durch:

```python
self.local_model = _PRELOADED_MODEL if not model_options.get('use_api') else None
if not model_options.get('use_api') and self.local_model is None:
    self.local_model = create_local_model()
```

### 8. Konfiguration anlegen

Erstelle die Datei `src\config.yaml` mit folgendem Inhalt (Werte nach Wunsch anpassen):

```yaml
model_options:
  use_api: false
  common:
    language: de        # ISO-Code, oder null für Auto-Erkennung (DE/EN/RU/...)
    temperature: 0.0
    initial_prompt: null
  local:
    model: large-v3     # tiny / base / small / medium / large-v3
    device: cuda        # cuda für GPU, cpu für CPU
    compute_type: float16   # float16 (GPU), int8 (CPU schnell)
    condition_on_previous_text: true
    vad_filter: true
    model_path: null

recording_options:
  activation_key: f9          # F-Taste oder z.B. ctrl+alt+space
  input_backend: auto
  recording_mode: hold_to_record   # hold_to_record / press_to_toggle / voice_activity_detection / continuous
  sound_device: null
  sample_rate: 16000
  silence_duration: 900
  min_duration: 100

post_processing:
  writing_key_press_delay: 0.005
  remove_trailing_period: false
  add_trailing_space: true
  remove_capitalization: false
  input_method: pynput

misc:
  print_to_terminal: true
  hide_status_window: false
  noise_on_completion: false
```

### 9. Start-Skript anlegen

Erstelle die Datei `start.bat` direkt im `whisper-writer`-Ordner:

```bat
@echo off
cd /d "%~dp0"
call venv\Scripts\activate.bat
set "PATH=%CD%\venv\Lib\site-packages\torch\lib;%PATH%"
set PYTHONUNBUFFERED=1
python -u run.py > whisperwriter.log 2>&1
echo.
echo === Programm beendet. Logs: ===
echo.
type whisperwriter.log
pause
```

Das Setzen von `PATH` auf den Torch-Lib-Ordner ist entscheidend — dort liegen die cuDNN-DLLs, die ctranslate2 zur Laufzeit braucht.

---

## Erste Nutzung

Doppelklick auf `start.bat`.

**Beim allerersten Start** lädt das Programm das gewählte Modell aus dem Internet herunter:
- `large-v3` ≈ 3 GB (beste Qualität, ~10 GB VRAM mit float16)
- `medium` ≈ 1.5 GB
- `small` ≈ 500 MB

Wird einmalig nach `%USERPROFILE%\.cache\huggingface\` gespeichert — künftige Starts laden in ~10 Sekunden.

**Diktieren:**
1. Cursor in irgendein Textfeld setzen (Word, Browser, Chat — egal wo)
2. **F9 gedrückt halten** und reden
3. **F9 loslassen** → Text wird eingefügt

Status-Fenster zeigt was gerade passiert (Aufnahme / Transkription / Fertig).

---

## Modell-Empfehlungen je nach Hardware

| GPU / CPU | Modell | compute_type |
|---|---|---|
| RTX 30/40-Serie (8+ GB VRAM) | `large-v3` | `float16` |
| RTX 20-Serie / GTX 1660 (6 GB) | `medium` | `float16` |
| Schwächere GPU oder CPU-only | `small` oder `base` | `int8` (Device: `cpu`) |

---

## Troubleshooting

**Programm crasht direkt nach "Creating local model..."**
→ Patch aus Schritt 7 wurde nicht (komplett) angewendet. Modell muss VOR PyQt5-Import geladen werden.

**Fehler "Could not locate cudnn_ops_infer64_8.dll"**
→ Schritt 6 (cuDNN-Update) wurde übersprungen, oder PATH in `start.bat` zeigt nicht auf `torch\lib`.

**F9 reagiert in bestimmten Apps nicht (z.B. Spielen, manchen Admin-Programmen)**
→ Diese Programme blockieren globale Hotkeys. Programm als Administrator starten kann helfen, oder anderen Hotkey wählen.

**Falsches Mikrofon wird benutzt**
→ Im venv: `python -m sounddevice` zeigt Geräteliste mit Indexnummern. Den Index in `config.yaml` unter `sound_device` eintragen.

**Englische Wörter werden nicht erkannt obwohl `language: de`**
→ Auf `language: null` umstellen (Auto-Erkennung). Funktioniert für alle 99 Whisper-Sprachen.

**Logs ansehen** — bei Problemen liegen Logs in `whisper-writer\whisperwriter.log`.

---

## Quelle

WhisperWriter ist ein Open-Source-Projekt von Sav Bell:
https://github.com/savbell/whisper-writer

Diese Anleitung dokumentiert die Schritte, die nötig sind, weil die mitgelieferte requirements.txt veraltet ist und es einen unbekannten PyQt5/ctranslate2-Konflikt auf modernen Windows-Installationen gibt.
