import SwiftUI
import AppKit

class FloatingPanel: NSWindow {
    private var hostingView: NSHostingView<PanelContentView>?
    
    init(typerService: TypeCraftService) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let panelWidth: CGFloat = 600
        let panelHeight: CGFloat = 650
        
        let panelX = screenFrame.midX - (panelWidth / 2)
        let panelY = screenFrame.minY + 20
        
        let contentRect = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)
        
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        
        let contentView = PanelContentView(typerService: typerService, closeAction: { [weak self] in
            self?.orderOut(nil)
        })
        
        hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

struct PanelContentView: View {
    @ObservedObject var typerService: TypeCraftService
    @StateObject private var presetManager = PresetManager()
    var closeAction: () -> Void
    
    @State private var textToType: String = ""
    @State private var settings = TypingSettings()
    @State private var selectedTab: Int = 0
    @State private var showingSavePreset: Bool = false
    @State private var newPresetName: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            topBar
            
            ScrollView {
                VStack(spacing: 14) {
                    textInputSection
                    
                    if typerService.state.isActive {
                        progressSection
                    }
                    
                    if !typerService.debugMessage.isEmpty {
                        debugSection
                    }
                    
                    presetsSection
                    
                    tabsRow
                    
                    tabContent
                    
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 600, height: 650)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 0.98)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showingSavePreset) {
            savePresetSheet
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: closeAction) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.gray.opacity(0.7))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Text to Type")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(textToType.count) chars • \(textToType.components(separatedBy: "\n").count) lines")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.7))
            }
            
            TextEditor(text: $textToType)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Progress")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(typerService.currentCharIndex)/\(textToType.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * typerService.progress)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var debugSection: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            Text(typerService.debugMessage)
                .font(.caption)
                .foregroundColor(.yellow.opacity(0.9))
                .lineLimit(2)
            Spacer()
        }
        .padding(8)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Presets")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                
                Button(action: { showingSavePreset = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Save Current")
                    }
                    .font(.caption)
                    .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // built-in presets
                    ForEach(TypingSettings.presets, id: \.name) { preset in
                        PresetButton(
                            name: preset.name,
                            isSelected: settings.name == preset.name,
                            isCustom: false
                        ) {
                            settings = preset
                        }
                    }
                    
                    // custom presets
                    ForEach(Array(presetManager.customPresets.enumerated()), id: \.offset) { index, preset in
                        PresetButton(
                            name: preset.name,
                            isSelected: settings.name == preset.name,
                            isCustom: true,
                            onDelete: {
                                presetManager.deletePreset(at: index)
                            }
                        ) {
                            settings = preset
                        }
                    }
                }
            }
        }
    }
    
    private var tabsRow: some View {
        HStack(spacing: 6) {
            // settings tabs
            TabButton(title: "Speed", icon: "speedometer", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            TabButton(title: "Pauses", icon: "pause.circle", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            TabButton(title: "Typos", icon: "exclamationmark.triangle", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
            TabButton(title: "Burst", icon: "bolt", isSelected: selectedTab == 3) {
                selectedTab = 3
            }
            
            Spacer()
            
            // accessibility buttons
            Button(action: testAccessibility) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption)
                    .padding(6)
                    .background(typerService.checkAccessibility() ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundColor(typerService.checkAccessibility() ? .green : .red)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Test Accessibility")
            
            Button(action: openAccessibilitySettings) {
                Image(systemName: "gear")
                    .font(.caption)
                    .padding(6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Open Accessibility Settings")
        }
    }
    
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case 0: speedSettingsView
            case 1: pauseSettingsView
            case 2: typoSettingsView
            case 3: burstSettingsView
            default: EmptyView()
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
    
    private var speedSettingsView: some View {
        VStack(spacing: 12) {
            SliderWithField(label: "Base Speed (CPM)", value: $settings.baseSpeedCPM, range: 50...500, step: 10, color: .cyan)
            SliderWithField(label: "Speed Variation %", value: $settings.speedVariation, range: 0...50, step: 5, color: .orange)
            SliderWithField(label: "Pause Between Words (ms)", value: $settings.pauseBetweenWords, range: 0...200, step: 10, color: .green)
            SliderWithField(label: "Word Speed Variation %", value: $settings.wordSpeedVariation, range: 0...50, step: 5, color: .purple)
        }
    }
    
    private var pauseSettingsView: some View {
        VStack(spacing: 12) {
            SliderWithField(label: "Thinking Pause Chance %", value: $settings.thinkingPauseChance, range: 0...20, step: 1, color: .yellow)
            HStack(spacing: 12) {
                SliderWithField(label: "Min (ms)", value: $settings.thinkingPauseMinMs, range: 100...2000, step: 100, color: .yellow)
                SliderWithField(label: "Max (ms)", value: $settings.thinkingPauseMaxMs, range: 500...5000, step: 100, color: .yellow)
            }
            Divider().background(Color.white.opacity(0.1))
            SliderWithField(label: "Pause After Period (ms)", value: $settings.pauseAfterPeriod, range: 0...1000, step: 50, color: .cyan)
            SliderWithField(label: "Pause After Comma (ms)", value: $settings.pauseAfterComma, range: 0...500, step: 25, color: .cyan)
            SliderWithField(label: "Pause After Newline (ms)", value: $settings.pauseAfterNewline, range: 0...2000, step: 100, color: .green)
            SliderWithField(label: "Pause After Paragraph (ms)", value: $settings.pauseAfterParagraph, range: 0...3000, step: 100, color: .green)
        }
    }
    
    private var typoSettingsView: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $settings.makeTypos) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.pink)
                    Text("Enable Typos").foregroundColor(.white)
                }
            }
            .toggleStyle(.switch)
            .tint(.pink)
            
            if settings.makeTypos {
                SliderWithField(label: "Typo Chance %", value: $settings.typoChance, range: 0...15, step: 0.5, color: .pink)
                HStack(spacing: 12) {
                    SliderWithField(label: "Notice Delay Min (ms)", value: $settings.typoNoticeDelayMin, range: 50...500, step: 25, color: .pink)
                    SliderWithField(label: "Notice Delay Max (ms)", value: $settings.typoNoticeDelayMax, range: 100...1000, step: 50, color: .pink)
                }
            }
        }
    }
    
    private var burstSettingsView: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $settings.burstTypingEnabled) {
                HStack {
                    Image(systemName: "bolt.fill").foregroundColor(.orange)
                    Text("Enable Burst Typing").foregroundColor(.white)
                }
            }
            .toggleStyle(.switch)
            .tint(.orange)
            
            if settings.burstTypingEnabled {
                SliderWithField(label: "Burst Chance %", value: $settings.burstChance, range: 0...30, step: 1, color: .orange)
                HStack(spacing: 12) {
                    SliderWithField(label: "Min Length", value: Binding(get: { Double(settings.burstLengthMin) }, set: { settings.burstLengthMin = Int($0) }), range: 1...10, step: 1, color: .orange)
                    SliderWithField(label: "Max Length", value: Binding(get: { Double(settings.burstLengthMax) }, set: { settings.burstLengthMax = Int($0) }), range: 3...20, step: 1, color: .orange)
                }
                SliderWithField(label: "Burst Speed Multiplier", value: $settings.burstSpeedMultiplier, range: 1.0...3.0, step: 0.1, color: .orange)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            switch typerService.state {
            case .idle:
                Button(action: startTyping) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start (Click 3x to begin)")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(textToType.isEmpty)
                
            case .waitingForClicks:
                Button(action: { typerService.stop() }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Cancel")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
            case .typing:
                Button(action: { typerService.pause() }) {
                    HStack {
                        Image(systemName: "pause.fill")
                        Text("Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: [.yellow.opacity(0.8), .orange], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: { typerService.stop() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: [.red.opacity(0.8), .pink], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
            case .paused:
                Button(action: { typerService.resume() }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Resume (Click 3x)")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: { typerService.stop() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: [.red.opacity(0.8), .pink], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var savePresetSheet: some View {
        VStack(spacing: 16) {
            Text("Save Preset")
                .font(.headline)
            
            TextField("Preset Name", text: $newPresetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            
            HStack {
                Button("Cancel") {
                    showingSavePreset = false
                    newPresetName = ""
                }
                
                Button("Save") {
                    var preset = settings
                    preset.name = newPresetName.isEmpty ? "Custom" : newPresetName
                    presetManager.savePreset(preset)
                    showingSavePreset = false
                    newPresetName = ""
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 280)
    }
    
    private var statusColor: Color {
        switch typerService.state {
        case .idle: return .gray
        case .waitingForClicks: return .yellow
        case .typing: return .green
        case .paused: return .orange
        }
    }
    
    private var statusText: String {
        switch typerService.state {
        case .idle: return "Ready"
        case .waitingForClicks(let count): return "Click \(3 - count) more time\(3 - count == 1 ? "" : "s")"
        case .typing: return "Typing..."
        case .paused: return "Paused"
        }
    }
    
    private func startTyping() {
        settings.name = "Custom"
        typerService.start(text: textToType, settings: settings)
    }
    
    private func testAccessibility() {
        let details = typerService.checkAccessibilityDetailed()
        typerService.debugMessage = details.granted 
            ? "✓ Accessibility: GRANTED - Ready to type!"
            : "✗ Accessibility: NOT GRANTED - Look for: \(details.bundleId)"
    }
    
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct PresetButton: View {
    let name: String
    let isSelected: Bool
    let isCustom: Bool
    var onDelete: (() -> Void)? = nil
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
                
                if isCustom && isHovering {
                    Button(action: { onDelete?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
            .foregroundColor(isSelected ? .cyan : .gray)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isCustom ? Color.purple.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
            .foregroundColor(isSelected ? .cyan : .gray)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct SliderWithField: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let color: Color
    
    @State private var textValue: String = ""
    @FocusState private var isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(spacing: 8) {
                Slider(value: $value, in: range, step: step)
                    .tint(color)
                    .frame(maxWidth: .infinity)
                
                TextField("", text: $textValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 60)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
                    .foregroundColor(.white)
                    .focused($isEditing)
                    .onSubmit {
                        if let newValue = Double(textValue) {
                            value = max(0, newValue)
                        }
                        textValue = formatValue(value)
                    }
                    .onChange(of: value) { newVal in
                        if !isEditing {
                            textValue = formatValue(newVal)
                        }
                    }
                    .onAppear {
                        textValue = formatValue(value)
                    }
            }
        }
    }
    
    private func formatValue(_ val: Double) -> String {
        step >= 1 ? String(Int(val)) : String(format: "%.1f", val)
    }
}
