# ---------------------------------------------------------
# FULL MIDI APP INSTALLER (UI + AUDIO→MIDI + ALL FEATURES)
# ---------------------------------------------------------

Write-Host "FULL MIDI APP SETUP STARTING..." -ForegroundColor Cyan

# Detect script directory and project dir
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectDir = Join-Path $ScriptDir "midi_app"

Write-Host "Project directory: $ProjectDir" -ForegroundColor Cyan

# Create project folder
if (!(Test-Path $ProjectDir)) {
    Write-Host "Creating midi_app folder..." -ForegroundColor Green
    New-Item -ItemType Directory -Path $ProjectDir | Out-Null
} else {
    Write-Host "midi_app already exists." -ForegroundColor Yellow
}

# Create subfolders
$folders = @("core", "security", "ui", "widgets")
foreach ($f in $folders) {
    $path = Join-Path $ProjectDir $f
    if (!(Test-Path $path)) {
        Write-Host "Creating folder: $f" -ForegroundColor Green
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

Write-Host "Writing Python files..." -ForegroundColor Green

# ---------------- app_main.py ----------------
@"
import customtkinter as ctk
from ui.main_window import MainWindow
from core.app_state import AppState
from core.config_manager import ConfigManager


def main():
    ctk.set_appearance_mode("system")
    ctk.set_default_color_theme("blue")

    app_state = AppState()
    config = ConfigManager()

    app = MainWindow(app_state=app_state, config=config)
    app.mainloop()


if __name__ == "__main__":
    main()
"@ | Set-Content (Join-Path $ProjectDir "app_main.py")

# ---------------- core/app_state.py ----------------
@"
class AppState:
    def __init__(self):
        self.version = "1.0.0"
        self.owner_verified = False
        self.logs = []

    def add_log(self, message: str):
        self.logs.append(message)
        print(message)
"@ | Set-Content (Join-Path $ProjectDir "core/app_state.py")

# ---------------- core/config_manager.py ----------------
@"
import json
from pathlib import Path


class ConfigManager:
    def __init__(self, config_path: Path | None = None):
        if config_path is None:
            config_path = Path(__file__).resolve().parent.parent / "config.json"
        self.config_path = config_path
        self.settings = {
            "theme": "system",
            "midi_input_device": None,
            "midi_output_device": None,
        }
        self.load()

    def load(self):
        if self.config_path.exists():
            try:
                data = json.loads(self.config_path.read_text(encoding="utf-8"))
                self.settings.update(data)
            except Exception:
                pass

    def save(self):
        try:
            self.config_path.write_text(
                json.dumps(self.settings, indent=2), encoding="utf-8"
            )
        except Exception:
            pass
"@ | Set-Content (Join-Path $ProjectDir "core/config_manager.py")
# ---------------- core/image_to_midi.py ----------------
@"
import pytesseract
from PIL import Image
from .text_to_midi import TextToMidiConverter


class ImageToMidiConverter:
    def __init__(self):
        self.text_converter = TextToMidiConverter()

    def convert(self, image_path: str, output_path: str):
        try:
            text = pytesseract.image_to_string(Image.open(image_path))
            return self.text_converter.convert(text, output_path)
        except Exception as e:
            return False, str(e)
"@ | Set-Content (Join-Path $ProjectDir "core/image_to_midi.py")

# ---------------- core/midi_tools.py ----------------
@"
from mido import MidiFile, MidiTrack


class MidiTools:
    def transpose(self, input_path: str, output_path: str, semitones: int):
        mid = MidiFile(input_path)
        out = MidiFile()

        for track in mid.tracks:
            new_track = MidiTrack()
            for msg in track:
                if msg.type in ("note_on", "note_off"):
                    msg.note += semitones
                new_track.append(msg)
            out.tracks.append(new_track)

        out.save(output_path)
        return True, f"Saved transposed MIDI to {output_path}"
"@ | Set-Content (Join-Path $ProjectDir "core/midi_tools.py")

# ---------------- security/machine_key.py ----------------
@"
import platform
import uuid


class MachineKey:
    def get_key(self) -> str:
        node = platform.node()
        return f"{node}-{uuid.getnode()}"
"@ | Set-Content (Join-Path $ProjectDir "security/machine_key.py")

# ---------------- security/owner_code_manager.py ----------------
@"
from .machine_key import MachineKey


class OwnerCodeManager:
    def __init__(self):
        self.machine_key = MachineKey()

    def validate(self, code: str) -> bool:
        mk = self.machine_key.get_key()
        expected = mk.replace("-", "")[-6:][::-1]
        return code == expected
"@ | Set-Content (Join-Path $ProjectDir "security/owner_code_manager.py")

# ---------------- widgets/experimental_badge.py ----------------
@"
import customtkinter as ctk


class ExperimentalBadge(ctk.CTkLabel):
    def __init__(self, master, text="Experimental", **kwargs):
        super().__init__(
            master,
            text=text,
            fg_color="#FFB347",
            text_color="black",
            corner_radius=8,
            padx=8,
            pady=4,
            **kwargs,
        )
"@ | Set-Content (Join-Path $ProjectDir "widgets/experimental_badge.py")

# ---------------- ui/settings_page.py ----------------
@"
import customtkinter as ctk


class SettingsPage(ctk.CTkFrame):
    def __init__(self, master, app_state, config, on_theme_change):
        super().__init__(master)
        self.app_state = app_state
        self.config = config
        self.on_theme_change = on_theme_change

        self._build()

    def _build(self):
        title = ctk.CTkLabel(self, text="Settings", font=("Segoe UI", 20, "bold"))
        title.pack(pady=(20, 10))

        theme_label = ctk.CTkLabel(self, text="Theme")
        theme_label.pack(pady=(10, 5))

        self.theme_option = ctk.CTkOptionMenu(
            self,
            values=["system", "light", "dark"],
            command=self._theme_changed,
        )
        self.theme_option.set(self.config.settings.get("theme", "system"))
        self.theme_option.pack(pady=(0, 10))

        midi_label = ctk.CTkLabel(self, text="MIDI settings (placeholder)")
        midi_label.pack(pady=(20, 5))

        self.midi_info = ctk.CTkLabel(self, text="Device selection and routing will go here.")
        self.midi_info.pack()

    def _theme_changed(self, value: str):
        if callable(self.on_theme_change):
            self.on_theme_change(value)
"@ | Set-Content (Join-Path $ProjectDir "ui/settings_page.py")

# ---------------- ui/logs_page.py ----------------
@"
import customtkinter as ctk


class LogsPage(ctk.CTkFrame):
    def __init__(self, master, app_state):
        super().__init__(master)
        self.app_state = app_state

        title = ctk.CTkLabel(self, text="Logs", font=("Segoe UI", 20, "bold"))
        title.pack(pady=(20, 10))

        self.textbox = ctk.CTkTextbox(self, width=600, height=400)
        self.textbox.pack(padx=20, pady=10, fill="both", expand=True)

        self.refresh_button = ctk.CTkButton(self, text="Refresh Logs", command=self.refresh)
        self.refresh_button.pack(pady=(0, 10))

    def refresh(self):
        self.textbox.delete("1.0", "end")
        for line in self.app_state.logs:
            self.textbox.insert("end", line + "\n")
        self.textbox.see("end")
"@ | Set-Content (Join-Path $ProjectDir "ui/logs_page.py")

# ---------------- ui/convert_page.py ----------------
@"
import customtkinter as ctk
from tkinter import filedialog
from core.audio_to_midi import AudioToMidiConverter
from core.text_to_midi import TextToMidiConverter
from core.image_to_midi import ImageToMidiConverter
from core.midi_tools import MidiTools


class ConvertPage(ctk.CTkFrame):
    def __init__(self, master, app_state):
        super().__init__(master)
        self.app_state = app_state

        self.audio = AudioToMidiConverter()
        self.text = TextToMidiConverter()
        self.image = ImageToMidiConverter()
        self.tools = MidiTools()

        self._build()

    def _build(self):
        title = ctk.CTkLabel(self, text="Conversions", font=("Segoe UI", 20, "bold"))
        title.pack(pady=20)

        audio_btn = ctk.CTkButton(self, text="Audio → MIDI", command=self._audio_to_midi)
        audio_btn.pack(pady=10)

        text_btn = ctk.CTkButton(self, text="Text → MIDI", command=self._text_to_midi)
        text_btn.pack(pady=10)

        img_btn = ctk.CTkButton(self, text="Image → MIDI", command=self._image_to_midi)
        img_btn.pack(pady=10)

        trans_btn = ctk.CTkButton(self, text="Transpose MIDI", command=self._transpose)
        trans_btn.pack(pady=10)

    def _audio_to_midi(self):
        src = filedialog.askopenfilename()
        if not src:
            return
        dst = filedialog.asksaveasfilename(defaultextension=".mid")
        if not dst:
            return
        ok, msg = self.audio.convert(src, dst)
        self.app_state.add_log(msg)

    def _text_to_midi(self):
        src = filedialog.askopenfilename()
        if not src:
            return
        with open(src, "r", encoding="utf-8") as f:
            text = f.read()
        dst = filedialog.asksaveasfilename(defaultextension=".mid")
        if not dst:
            return
        ok, msg = self.text.convert(text, dst)
        self.app_state.add_log(msg)

    def _image_to_midi(self):
        src = filedialog.askopenfilename()
        if not src:
            return
        dst = filedialog.asksaveasfilename(defaultextension=".mid")
        if not dst:
            return
        ok, msg = self.image.convert(src, dst)
        self.app_state.add_log(msg)

    def _transpose(self):
        src = filedialog.askopenfilename()
        if not src:
            return
        dst = filedialog.asksaveasfilename(defaultextension=".mid")
        if not dst:
            return
        ok, msg = self.tools.transpose(src, dst, semitones=5)
        self.app_state.add_log(msg)
"@ | Set-Content (Join-Path $ProjectDir "ui/convert_page.py")
# ---------------- ui/main_window.py ----------------
@"
import customtkinter as ctk
from ui.settings_page import SettingsPage
from ui.logs_page import LogsPage
from ui.convert_page import ConvertPage
from widgets.experimental_badge import ExperimentalBadge


class MainWindow(ctk.CTk):
    def __init__(self, app_state, config):
        super().__init__()
        self.app_state = app_state
        self.config = config

        self.title("MIDI App")
        self.geometry("900x600")

        ctk.set_appearance_mode(self.config.settings.get("theme", "system"))

        self._build_layout()
        self._show_home()

    def _build_layout(self):
        self.grid_columnconfigure(0, weight=0)
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        self.sidebar = ctk.CTkFrame(self, width=200)
        self.sidebar.grid(row=0, column=0, sticky="nsw")
        self.sidebar.grid_propagate(False)

        title_label = ctk.CTkLabel(self.sidebar, text="MIDI App", font=("Segoe UI", 18, "bold"))
        title_label.pack(pady=(20, 10))

        ExperimentalBadge(self.sidebar, text="Experimental Build").pack(pady=(0, 20))

        self.home_button = ctk.CTkButton(self.sidebar, text="Home", command=self._show_home)
        self.home_button.pack(fill="x", padx=10, pady=5)

        self.convert_button = ctk.CTkButton(self.sidebar, text="Convert", command=self._show_convert)
        self.convert_button.pack(fill="x", padx=10, pady=5)

        self.settings_button = ctk.CTkButton(self.sidebar, text="Settings", command=self._show_settings)
        self.settings_button.pack(fill="x", padx=10, pady=5)

        self.logs_button = ctk.CTkButton(self.sidebar, text="Logs", command=self._show_logs)
        self.logs_button.pack(fill="x", padx=10, pady=5)

        self.content = ctk.CTkFrame(self)
        self.content.grid(row=0, column=1, sticky="nsew")
        self.content.grid_rowconfigure(0, weight=1)
        self.content.grid_columnconfigure(0, weight=1)

        self.status_bar = ctk.CTkLabel(self, text=f"Version {self.app_state.version}", anchor="w")
        self.status_bar.grid(row=1, column=0, columnspan=2, sticky="ew")

        self.current_page = None
        self.settings_page = SettingsPage(self.content, self.app_state, self.config, on_theme_change=self._on_theme_change)
        self.logs_page = LogsPage(self.content, self.app_state)
        self.convert_page = ConvertPage(self.content, self.app_state)

    def _clear_content(self):
        for child in self.content.winfo_children():
            child.grid_forget()

    def _show_home(self):
        self._clear_content()
        frame = ctk.CTkFrame(self.content)
        frame.grid(row=0, column=0, sticky="nsew")

        label = ctk.CTkLabel(frame, text="MIDI App Loaded", font=("Segoe UI", 24, "bold"))
        label.pack(pady=40)

        info = ctk.CTkLabel(
            frame,
            text="Full MIDI hub:\n- Audio → MIDI\n- Text/Image → MIDI\n- MIDI tools\n- Logging & settings",
            justify="left",
        )
        info.pack(pady=10)

        self.current_page = frame
        self.app_state.add_log("Navigated to Home")

    def _show_settings(self):
        self._clear_content()
        self.settings_page.grid(row=0, column=0, sticky="nsew")
        self.current_page = self.settings_page
        self.app_state.add_log("Navigated to Settings")

    def _show_logs(self):
        self._clear_content()
        self.logs_page.refresh()
        self.logs_page.grid(row=0, column=0, sticky="nsew")
        self.current_page = self.logs_page
        self.app_state.add_log("Navigated to Logs")

    def _show_convert(self):
        self._clear_content()
        self.convert_page.grid(row=0, column=0, sticky="nsew")
        self.current_page = self.convert_page
        self.app_state.add_log("Navigated to Convert")

    def _on_theme_change(self, theme: str):
        ctk.set_appearance_mode(theme)
        self.config.settings["theme"] = theme
        self.config.save()
        self.app_state.add_log(f"Theme changed to {theme}")
"@ | Set-Content (Join-Path $ProjectDir "ui/main_window.py")

Write-Host "Python files written." -ForegroundColor Green

# ---------------- VIRTUAL ENV + DEPENDENCIES ----------------

$EnvPath = Join-Path $ProjectDir "env"

if (Test-Path $EnvPath) {
    Write-Host "Removing old virtual environment..." -ForegroundColor Yellow
    Remove-Item $EnvPath -Recurse -Force
}

Write-Host "Creating virtual environment..." -ForegroundColor Green
python -m venv $EnvPath

Write-Host "Activating virtual environment..." -ForegroundColor Green
& (Join-Path $EnvPath "Scripts\Activate.ps1")

Write-Host "Installing dependencies (this may take a while)..." -ForegroundColor Green
pip install --upgrade pip
pip install customtkinter pillow cryptography==41.0.7 basic-pitch mido pytesseract

Write-Host "FULL SETUP COMPLETE." -ForegroundColor Green
Write-Host "To run the app:" -ForegroundColor Cyan
Write-Host "  cd `"$ProjectDir`"" -ForegroundColor Cyan
Write-Host "  .\env\Scripts\Activate.ps1" -ForegroundColor Cyan
Write-Host "  python app_main.py" -ForegroundColor Cyan
