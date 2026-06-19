import AppKit
import SwiftUI

struct WindowFrontOnAppear: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        bringToFront(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        bringToFront(from: nsView)
    }

    private func bringToFront(from view: NSView) {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            guard let window = view.window else { return }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

enum AppWindows {
    static func open(_ openWindow: OpenWindowAction, id: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: id)

        let title = id == "settings" ? "Settings" : "About Grafana Scope"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            for window in NSApplication.shared.windows where window.title.contains(title) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    static func fromHex(_ hex: String) -> Color {
        Color(hex: hex)
    }

    func toHex() -> String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.white
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}

func formatUpdated(_ date: Date?) -> String {
    guard let date else { return "Not updated" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateStyle = .none
    formatter.timeStyle = .medium
    return formatter.string(from: date)
}

enum HexColor {
    static func nsColor(from hex: String) -> NSColor {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        return NSColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    static func from(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        return String(
            format: "#%02X%02X%02X",
            Int(rgb.redComponent * 255),
            Int(rgb.greenComponent * 255),
            Int(rgb.blueComponent * 255)
        )
    }
}

struct PopoverColorWell: NSViewRepresentable {
    @Binding var hex: String
    var onChange: () -> Void

    func makeNSView(context: Context) -> ColorWellButton {
        let button = ColorWellButton()
        button.coordinator = context.coordinator
        button.syncColor(hex: hex)
        return button
    }

    func updateNSView(_ button: ColorWellButton, context: Context) {
        button.coordinator = context.coordinator
        button.syncColor(hex: hex)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hex: $hex, onChange: onChange)
    }

    final class Coordinator: NSObject {
        var hex: Binding<String>
        var onChange: () -> Void

        init(hex: Binding<String>, onChange: @escaping () -> Void) {
            self.hex = hex
            self.onChange = onChange
        }

        func applyHex(_ value: String) {
            hex.wrappedValue = value
            onChange()
        }
    }
}

struct InlineColorEditor: View {
    @Binding var hex: String
    let onApply: (String) -> Void

    @State private var red: Double = 48
    @State private var green: Double = 209
    @State private var blue: Double = 88

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Custom color")
                    .font(.headline)
                Spacer()
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: previewHex))
                    .frame(width: 36, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            }

            channelSlider("Red", value: $red)
            channelSlider("Green", value: $green)
            channelSlider("Blue", value: $blue)

            Text(previewHex.uppercased())
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 260)
        .onAppear(perform: loadFromHex)
        .onChange(of: red) { _ in publish() }
        .onChange(of: green) { _ in publish() }
        .onChange(of: blue) { _ in publish() }
    }

    private var previewHex: String {
        String(
            format: "#%02X%02X%02X",
            Int(red.rounded()),
            Int(green.rounded()),
            Int(blue.rounded())
        )
    }

    private func channelSlider(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(width: 42, alignment: .leading)
                .font(.caption)
            Slider(value: value, in: 0...255, step: 1)
            Text("\(Int(value.wrappedValue.rounded()))")
                .font(.caption.monospaced())
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func loadFromHex() {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        red = Double((value >> 16) & 0xFF)
        green = Double((value >> 8) & 0xFF)
        blue = Double(value & 0xFF)
    }

    private func publish() {
        onApply(previewHex)
    }
}

final class ColorWellButton: NSButton {
    weak var coordinator: PopoverColorWell.Coordinator?
    private var popover: NSPopover?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .shadowlessSquare
        isBordered = true
        title = ""
        target = self
        action = #selector(togglePopover)
        contentTintColor = nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func syncColor(hex: String) {
        let color = HexColor.nsColor(from: hex)
        image = swatchImage(color: color)
    }

    @objc private func togglePopover() {
        if let popover, popover.isShown {
            popover.performClose(self)
            return
        }

        guard let coordinator else { return }

        let editor = InlineColorEditor(hex: coordinator.hex) { newHex in
            coordinator.applyHex(newHex)
            self.syncColor(hex: newHex)
        }

        let host = NSHostingController(rootView: editor)
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 288, height: 210)
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = host
        pop.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
        popover = pop
    }

    private func swatchImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 44, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        NSColor.separatorColor.setStroke()
        color.setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4).fill()
        NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4).stroke()
        image.unlockFocus()
        return image
    }
}
