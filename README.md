# TypeCraft

TypeCraft is a macOS application designed to automate typing with human-like characteristics. It simulates realistic typing patterns by introducing variations in speed, thinking pauses, and even occasional typos that are quickly corrected.

## How it Works

The app works by requesting **Accessibility Permissions** from macOS. This allows it to send system-wide keyboard events to the currently active application.

### Key Features:
- **Human-like Variations**: Random speed variations and thinking pauses.
- **Realistic Typos**: Occasional wrong-key presses based on QWERTY layout proximity, followed by automatic corrections.
- **Presets**: Multiple typing styles from "Casual Typist" to "Robot".
- **Safety Mechanism**: Requires 3 mouse clicks after starting to begin typing, ensuring you have time to focus the correct window.
- **Energy Efficient**: Uses macOS App Nap management to conserve battery when idle.

## How to Compile and Run

### Prerequisites
- macOS 13.0 or later
- Xcode or Swift Command Line Tools

### Build and Run locally
You can build the app directly using the provided build script:

```bash
./build.sh
```

This will create a `dist/TypeCraft.app` bundle. You can then open it:

```bash
open "dist/TypeCraft.app"
```

### Create an Installer Package
If you want to create a `.pkg` installer that installs the app to your `/Applications` folder:

```bash
./package.sh
```

This will generate a `dist/TypeCraft-1.0.0.pkg` file.

## Usage Instructions

1. **Grant Permissions**: On first launch, the app will request Accessibility permissions. You must enable it in `System Settings > Privacy & Security > Accessibility`.
2. **Enter Text**: Type or paste the text you want to be typed into the main window.
3. **Configure Settings**: Choose a preset or manually adjust speed, pauses, and typo frequency.
4. **Start**: Click the "Start" button.
5. **Focus Target**: Click 3 times anywhere on the screen. The app will start typing into whichever window is focused after the 3rd click.
6. **Control**: You can pause or stop the typing at any time from the app's floating panel or the menu bar icon.

