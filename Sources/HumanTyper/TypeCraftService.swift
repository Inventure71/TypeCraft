import Foundation
import AppKit
import Combine
import CoreGraphics

struct TypingSettings: Codable, Equatable {
    var name: String = "Custom"
    
    var baseSpeedCPM: Double = 200          // characters per minute (base)
    var speedVariation: Double = 30         // percentage variation in speed
    
    var thinkingPauseChance: Double = 5     // % chance of a "thinking" pause
    var thinkingPauseMinMs: Double = 500    // minimum thinking pause (ms)
    var thinkingPauseMaxMs: Double = 2000   // maximum thinking pause (ms)
    
    var pauseAfterPeriod: Double = 300      // ms pause after . ! ?
    var pauseAfterComma: Double = 150       // ms pause after , ; :
    var pauseAfterNewline: Double = 500     // ms pause after newline
    var pauseAfterParagraph: Double = 1000  // ms pause after double newline
    
    var makeTypos: Bool = true
    var typoChance: Double = 3              // % chance of typo per character
    var typoNoticeDelayMin: Double = 100    // min ms before noticing typo
    var typoNoticeDelayMax: Double = 500    // max ms before noticing typo
    
    // burst typing (typing faster for short bursts)
    var burstTypingEnabled: Bool = true
    var burstChance: Double = 10            // % chance to start a burst
    var burstLengthMin: Int = 3             // min characters in burst
    var burstLengthMax: Int = 8             // max characters in burst
    var burstSpeedMultiplier: Double = 1.5  // how much faster during burst
    
    var pauseBetweenWords: Double = 80      // extra ms pause after space
    var wordSpeedVariation: Double = 20     // % variation between words
    
    static let presets: [TypingSettings] = [
        .casualTypist,
        .fastTypist,
        .carefulTypist,
        .beginnerTypist,
        .robotLike
    ]
    
    static var casualTypist: TypingSettings {
        var s = TypingSettings()
        s.name = "Casual Typist"
        s.baseSpeedCPM = 180
        s.speedVariation = 35
        s.thinkingPauseChance = 8
        s.makeTypos = true
        s.typoChance = 4
        s.burstTypingEnabled = true
        s.burstChance = 15
        return s
    }
    
    static var fastTypist: TypingSettings {
        var s = TypingSettings()
        s.name = "Fast Typist"
        s.baseSpeedCPM = 350
        s.speedVariation = 20
        s.thinkingPauseChance = 2
        s.thinkingPauseMinMs = 200
        s.thinkingPauseMaxMs = 800
        s.pauseAfterPeriod = 150
        s.pauseAfterComma = 80
        s.makeTypos = true
        s.typoChance = 2
        s.burstTypingEnabled = true
        s.burstChance = 20
        s.burstSpeedMultiplier = 1.8
        return s
    }
    
    static var carefulTypist: TypingSettings {
        var s = TypingSettings()
        s.name = "Careful Typist"
        s.baseSpeedCPM = 120
        s.speedVariation = 15
        s.thinkingPauseChance = 12
        s.thinkingPauseMinMs = 800
        s.thinkingPauseMaxMs = 3000
        s.pauseAfterPeriod = 500
        s.pauseAfterComma = 250
        s.makeTypos = false
        s.burstTypingEnabled = false
        return s
    }
    
    static var beginnerTypist: TypingSettings {
        var s = TypingSettings()
        s.name = "Beginner Typist"
        s.baseSpeedCPM = 80
        s.speedVariation = 50
        s.thinkingPauseChance = 15
        s.thinkingPauseMinMs = 1000
        s.thinkingPauseMaxMs = 4000
        s.pauseAfterPeriod = 600
        s.pauseAfterComma = 400
        s.pauseAfterNewline = 1000
        s.makeTypos = true
        s.typoChance = 8
        s.typoNoticeDelayMin = 300
        s.typoNoticeDelayMax = 1000
        s.burstTypingEnabled = false
        s.pauseBetweenWords = 200
        return s
    }
    
    static var robotLike: TypingSettings {
        var s = TypingSettings()
        s.name = "Robot (Consistent)"
        s.baseSpeedCPM = 300
        s.speedVariation = 5
        s.thinkingPauseChance = 0
        s.pauseAfterPeriod = 100
        s.pauseAfterComma = 50
        s.pauseAfterNewline = 100
        s.makeTypos = false
        s.burstTypingEnabled = false
        s.pauseBetweenWords = 50
        s.wordSpeedVariation = 5
        return s
    }
}

class PresetManager: ObservableObject {
    @Published var customPresets: [TypingSettings] = []
    
    private let saveKey = "TypeCraft.CustomPresets"
    
    init() {
        loadCustomPresets()
    }
    
    func savePreset(_ settings: TypingSettings) {
        var preset = settings
        if preset.name.isEmpty || preset.name == "Custom" {
            preset.name = "Custom \(customPresets.count + 1)"
        }
        customPresets.append(preset)
        saveCustomPresets()
    }
    
    func deletePreset(at index: Int) {
        guard index < customPresets.count else { return }
        customPresets.remove(at: index)
        saveCustomPresets()
    }
    
    private func saveCustomPresets() {
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func loadCustomPresets() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let presets = try? JSONDecoder().decode([TypingSettings].self, from: data) {
            customPresets = presets
        }
    }
}

enum TyperState: Equatable {
    case idle
    case waitingForClicks(count: Int)
    case typing
    case paused
    
    var isActive: Bool {
        switch self {
        case .typing, .paused, .waitingForClicks:
            return true
        case .idle:
            return false
        }
    }
}

class TypeCraftService: ObservableObject {
    @Published var state: TyperState = .idle
    @Published var debugMessage: String = ""
    @Published var progress: Double = 0
    @Published var currentCharIndex: Int = 0
    
    private var textToType: String = ""
    private var settings: TypingSettings = TypingSettings()
    private var clickCount: Int = 0
    private var globalMonitor: Any?
    private var typingTask: Task<Void, Never>?
    private var isPaused: Bool = false
    private var savedCharIndex: Int = 0  // for resume
    
    // adjacent keys for realistic typos (qwerty layout)
    private let adjacentKeys: [Character: [Character]] = [
        "a": ["s", "q", "z", "w"],
        "b": ["v", "g", "h", "n"],
        "c": ["x", "d", "f", "v"],
        "d": ["s", "e", "r", "f", "c", "x"],
        "e": ["w", "r", "d", "s", "3", "4"],
        "f": ["d", "r", "t", "g", "v", "c"],
        "g": ["f", "t", "y", "h", "b", "v"],
        "h": ["g", "y", "u", "j", "n", "b"],
        "i": ["u", "o", "k", "j", "8", "9"],
        "j": ["h", "u", "i", "k", "m", "n"],
        "k": ["j", "i", "o", "l", "m", ","],
        "l": ["k", "o", "p", ";", "."],
        "m": ["n", "j", "k", ","],
        "n": ["b", "h", "j", "m"],
        "o": ["i", "p", "l", "k", "9", "0"],
        "p": ["o", "l", "[", "0", "-"],
        "q": ["w", "a", "1", "2"],
        "r": ["e", "t", "f", "d", "4", "5"],
        "s": ["a", "w", "e", "d", "x", "z"],
        "t": ["r", "y", "g", "f", "5", "6"],
        "u": ["y", "i", "j", "h", "7", "8"],
        "v": ["c", "f", "g", "b"],
        "w": ["q", "e", "s", "a", "2", "3"],
        "x": ["z", "s", "d", "c"],
        "y": ["t", "u", "h", "g", "6", "7"],
        "z": ["a", "s", "x"]
    ]
    
    func start(text: String, settings: TypingSettings) {
        guard state == .idle else { return }
        
        let details = checkAccessibilityDetailed()
        updateDebug("Accessibility: \(details.granted ? "✓" : "✗")")
        
        if !details.granted {
            updateDebug("ERROR: Enable accessibility for: \(details.bundleId)")
            return
        }
        
        self.textToType = text
        self.settings = settings
        self.clickCount = 0
        self.currentCharIndex = 0
        self.savedCharIndex = 0
        self.progress = 0
        self.isPaused = false
        
        updateDebug("Waiting for 3 clicks...")
        state = .waitingForClicks(count: 0)
        startClickMonitoring()
    }
    
    func pause() {
        guard state == .typing else { return }
        isPaused = true
        savedCharIndex = currentCharIndex  // save position
        typingTask?.cancel()
        typingTask = nil
        state = .paused
        updateDebug("Paused at character \(currentCharIndex)")
    }
    
    func resume() {
        guard state == .paused else { return }
        // reset click count and ask for 3 clicks again
        clickCount = 0
        updateDebug("Waiting for 3 clicks to resume...")
        state = .waitingForClicks(count: 0)
        startClickMonitoring()
    }
    
    func stop() {
        stopClickMonitoring()
        typingTask?.cancel()
        typingTask = nil
        isPaused = false
        savedCharIndex = 0
        DispatchQueue.main.async {
            self.state = .idle
            self.progress = 0
            self.currentCharIndex = 0
            self.updateDebug("Stopped")
        }
    }
    
    func checkAccessibility() -> Bool {
        return AXIsProcessTrusted()
    }
    
    func checkAccessibilityDetailed() -> (granted: Bool, bundleId: String, executablePath: String) {
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let executablePath = Bundle.main.executablePath ?? "unknown"
        let trusted = AXIsProcessTrusted()
        return (trusted, bundleId, executablePath)
    }
    
    private func updateDebug(_ message: String) {
        DispatchQueue.main.async {
            self.debugMessage = message
            print("🔍 [TypeCraft] \(message)")
        }
    }
    
    private func startClickMonitoring() {
        stopClickMonitoring()  // clear any existing monitor
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.handleClick()
        }
    }
    
    private func stopClickMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
    
    private func handleClick() {
        clickCount += 1
        updateDebug("Click \(clickCount)/3")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.clickCount >= 3 {
                self.stopClickMonitoring()
                self.isPaused = false
                self.state = .typing
                
                if self.savedCharIndex > 0 {
                    self.currentCharIndex = self.savedCharIndex
                    self.updateDebug("Resuming from character \(self.savedCharIndex)...")
                } else {
                    self.updateDebug("Starting to type...")
                }
                self.beginTyping()
            } else {
                self.state = .waitingForClicks(count: self.clickCount)
            }
        }
    }
    
    private func beginTyping() {
        typingTask = Task { [weak self] in
            guard let self = self else { return }
            
            // initial delay
            try? await Task.sleep(nanoseconds: 400_000_000)
            
            let chars = Array(self.textToType)
            let totalChars = chars.count
            var burstRemaining = 0
            var previousChar: Character? = nil
            
            // get previous char if resuming
            if self.currentCharIndex > 0 && self.currentCharIndex < totalChars {
                previousChar = chars[self.currentCharIndex - 1]
            }
            
            var index = self.currentCharIndex
            while index < totalChars {
                if Task.isCancelled { break }
                
                while self.isPaused {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if Task.isCancelled { break }
                }
                if Task.isCancelled { break }
                
                let char = chars[index]
                
                let currentIndex = index
                await MainActor.run {
                    self.currentCharIndex = currentIndex
                    self.progress = Double(currentIndex) / Double(totalChars)
                }
                
                // check for paragraph break (double newline)
                let isParagraphBreak = char == "\n" && previousChar == "\n"
                
                // thinking pause (random chance)
                if self.settings.thinkingPauseChance > 0 && 
                   Double.random(in: 0...100) < self.settings.thinkingPauseChance {
                    let pause = Double.random(in: self.settings.thinkingPauseMinMs...self.settings.thinkingPauseMaxMs)
                    try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000))
                }
                
                // determine if we're in burst mode
                if burstRemaining == 0 && self.settings.burstTypingEnabled &&
                   Double.random(in: 0...100) < self.settings.burstChance {
                    burstRemaining = Int.random(in: self.settings.burstLengthMin...self.settings.burstLengthMax)
                }
                
                let inBurst = burstRemaining > 0
                if inBurst { burstRemaining -= 1 }
                
                // check for typo (only for letters, not for newlines/special chars)
                let shouldTypo = self.settings.makeTypos &&
                    Double.random(in: 0...100) < self.settings.typoChance &&
                    char.isLetter
                
                if shouldTypo {
                    let typoChar = self.getTypoCharacter(for: char)
                    await self.typeCharacter(typoChar)
                    
                    // notice delay
                    let noticeDelay = Double.random(
                        in: self.settings.typoNoticeDelayMin...self.settings.typoNoticeDelayMax
                    )
                    try? await Task.sleep(nanoseconds: UInt64(noticeDelay * 1_000_000))
                    
                    await self.pressBackspace()
                    
                    // small pause before correction
                    try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 50...150) * 1_000_000))
                }
                
                await self.typeCharacter(char)
                
                var delay = 60000.0 / self.settings.baseSpeedCPM // base delay in ms
                
                // apply speed variation
                let variation = delay * (self.settings.speedVariation / 100.0)
                delay += Double.random(in: -variation...variation)
                
                // apply burst speed
                if inBurst {
                    delay /= self.settings.burstSpeedMultiplier
                }
                
                // punctuation pauses
                if ".!?".contains(char) {
                    delay += self.settings.pauseAfterPeriod
                } else if ",;:".contains(char) {
                    delay += self.settings.pauseAfterComma
                } else if char == " " {
                    delay += self.settings.pauseBetweenWords
                } else if char == "\n" {
                    delay += isParagraphBreak ? self.settings.pauseAfterParagraph : self.settings.pauseAfterNewline
                }
                
                // word-level variation
                if char == " " && self.settings.wordSpeedVariation > 0 {
                    let wordVariation = delay * (self.settings.wordSpeedVariation / 100.0)
                    delay += Double.random(in: -wordVariation...wordVariation)
                }
                
                // ensure minimum delay
                delay = max(20, delay)
                
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000))
                
                previousChar = char
                index += 1
            }
            
            await MainActor.run {
                self.state = .idle
                self.progress = 1.0
                self.savedCharIndex = 0
                self.updateDebug("✓ Finished typing \(totalChars) characters")
            }
        }
    }
    
    private func getTypoCharacter(for char: Character) -> Character {
        let lowerChar = Character(char.lowercased())
        if let adjacent = adjacentKeys[lowerChar], !adjacent.isEmpty {
            let typo = adjacent.randomElement()!
            return char.isUppercase ? Character(typo.uppercased()) : typo
        }
        return char
    }
    
    @MainActor
    private func typeCharacter(_ char: Character) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // handle newline specially - use return key
        if char == "\n" {
            let returnKeyCode: CGKeyCode = 36
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: true) {
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: false) {
                keyUp.post(tap: .cghidEventTap)
            }
            return
        }
        
        // handle tab
        if char == "\t" {
            let tabKeyCode: CGKeyCode = 48
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: tabKeyCode, keyDown: true) {
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: tabKeyCode, keyDown: false) {
                keyUp.post(tap: .cghidEventTap)
            }
            return
        }
        
        // regular character - use unicode
        var chars = Array(String(char).utf16)
        guard !chars.isEmpty else { return }
        
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            keyDown.post(tap: .cghidEventTap)
        }
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            keyUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    @MainActor
    private func pressBackspace() {
        let source = CGEventSource(stateID: .hidSystemState)
        let backspaceKeyCode: CGKeyCode = 51
        
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: backspaceKeyCode, keyDown: true) {
            keyDown.post(tap: .cghidEventTap)
        }
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: backspaceKeyCode, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
