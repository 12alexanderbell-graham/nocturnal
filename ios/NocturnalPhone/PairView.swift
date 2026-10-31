import SwiftUI

/// Until this phone has a key. Full screen green, like the computer when it keeps working.
/// First the welcome: the mark, the name, one line, and Pair a Computer. Then pairing: the name moves to the bar, the
/// camera opens right on the page and reads the code Nocturnal shows on the computer; the code can also be pasted or typed.
/// Typing "demo" opens a pretend computer instead, for App Review and anyone without a computer to hand; nothing on
/// screen offers it.
struct PairView: View {
    @Environment(Computer.self) private var computer
    @State private var step = Step.welcome
    @State private var typing = false
    @State private var code = ""
    @State private var error: String?
    @FocusState private var fieldFocused: Bool
    @Namespace private var ns

    enum Step { case welcome, pair }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= Theme.wide
            VStack(spacing: 0) {
                switch step {
                case .welcome: welcome
                case .pair where wide: pairWide(geo.size)
                case .pair: pair(geo.size)
                }
                if step == .welcome || !wide {
                    bottom
                        .padding(.bottom, Theme.bottom - 14)
                }
            }
            .padding(.horizontal, Theme.side)
            .frame(maxWidth: wide && step == .pair ? .infinity : Theme.column)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        // Back and the name are system toolbar items, so iOS places them on every screen (the top bar on an iPhone,
        // the side strip by the clock on iPhone Duo's outer screen).
        .toolbar {
            if step == .pair {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.left") {
                        typing = false
                        fieldFocused = false
                        code = ""
                        error = nil
                        step = .welcome
                    }
                    .accessibilityIdentifier("back")
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppMark")
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 26, height: 26)
                            .clipShape(.rect(cornerRadius: 26 * 0.225, style: .continuous))
                            .accessibilityHidden(true)
                        Text("Nocturnal").font(.headline)
                    }
                }
            }
        }
        .animation(Theme.grow, value: step)
        .animation(Theme.chrome, value: typing)
        .sensoryFeedback(.error, trigger: error) { _, new in new != nil }
    }

    // MARK: Welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()
            mark(size: 120)
                .rise(0)
            Text("Nocturnal")
                .font(.system(.largeTitle, weight: .bold))
                .padding(.top, 24)
                .rise(1)
            Text("Keeps your computer working with the lid shut while your agents work. See it and steer it from here.")
                .font(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.top, 10)
                .rise(2)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Pair

    private func pair(_ size: CGSize) -> some View {
        let side = min(size.width - Theme.side * 2 - 24, size.height * 0.42)
        return VStack(spacing: 0) {
            Spacer(minLength: 12)
            camera(side)
            instructions
                .padding(.top, 22)
            errorLine
                .padding(.top, 10)
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
    }

    /// A wide screen: the camera on the left; the words, the error and the buttons beside it.
    private func pairWide(_ size: CGSize) -> some View {
        let side = min(size.height * 0.62, (size.width - Theme.side * 2 - Theme.split) / 2, 440)
        return HStack(spacing: Theme.split) {
            camera(side)
            VStack(spacing: 0) {
                instructions
                errorLine
                    .padding(.top, 10)
                bottom
                    .padding(.top, 24)
            }
            .frame(width: min(side, 380))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func camera(_ side: CGFloat) -> some View {
        CameraFinder(found: pairFrom)
            .frame(width: side, height: side)
            .clipShape(.rect(cornerRadius: 40, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            }
            .transition(.scale(scale: 0.9).combined(with: .offset(y: 30)))
            .rise(0)
    }

    private var instructions: some View {
        Text("On your computer, open Nocturnal and choose Pair a Phone. Point the camera at the code.")
            .font(.body)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 330)
            .rise(1)
    }

    private var errorLine: some View {
        Text(error ?? " ")
            .font(.headline)
            .foregroundStyle(Theme.red)
            .multilineTextAlignment(.center)
            .lineLimit(2, reservesSpace: true)
            .accessibilityIdentifier("pairError")
    }

    // MARK: Bottom

    private var bottom: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: Theme.gap) {
                switch step {
                case .welcome:
                    Button { step = .pair } label: {
                        Text("Pair a Computer")
                            .font(.headline)
                            .foregroundStyle(Theme.deep)
                            .frame(maxWidth: .infinity, minHeight: Theme.band)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(Press(scale: 0.97))
                    .glassEffect(.clear.tint(.white).interactive(), in: .capsule)
                    .glassEffectID("left", in: ns)
                    .accessibilityIdentifier("next")
                case .pair where typing:
                    TextField("Pairing code", text: $code)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($fieldFocused)
                        .onSubmit(pairFromField)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, minHeight: Theme.band)
                        .glassEffect(.clear.interactive(), in: .capsule)
                        .glassEffectID("left", in: ns)
                        .accessibilityIdentifier("codeField")
                    circle("arrow.up", "Pair", id: "right", prominent: !code.isEmpty, action: pairFromField)
                        .disabled(code.isEmpty)
                        .accessibilityIdentifier("submit")
                case .pair:
                    Button {
                        guard let text = UIPasteboard.general.string, !text.isEmpty else {
                            withAnimation(Theme.chrome) { error = "Copy the code on your computer first, then paste." }
                            return
                        }
                        pairFrom(text)
                    } label: {
                        Label("Paste Code", systemImage: "doc.on.clipboard")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: Theme.band)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(Press(scale: 0.97))
                    .glassEffect(.clear.interactive(), in: .capsule)
                    .glassEffectID("left", in: ns)
                    .accessibilityIdentifier("paste")
                    circle("keyboard", "Type the code", id: "right", prominent: false) {
                        typing = true
                        fieldFocused = true
                    }
                    .accessibilityIdentifier("type")
                }
            }
        }
    }

    private func circle(_ symbol: String, _ label: String, id: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(prominent ? Theme.deep : .white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Theme.band, height: Theme.band)
                .contentShape(.circle)
        }
        .buttonStyle(Press())
        .glassEffect(prominent ? .clear.tint(.white).interactive() : .clear.interactive(), in: .circle)
        .glassEffectID(id, in: ns)
        .accessibilityLabel(label)
    }

    private func mark(size: CGFloat) -> some View {
        Image("AppMark")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
            .accessibilityHidden(true)
    }

    // MARK: Pairing

    private func pairFromField() { pairFrom(code) }

    private func pairFrom(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased() == "demo" {
            error = nil
            fieldFocused = false
            computer.startDemo()
            return
        }
        guard let p = Pairing(text: text) else {
            withAnimation(Theme.chrome) { error = "That isn't a Nocturnal pairing code." }
            return
        }
        error = nil
        fieldFocused = false
        computer.pair(p)
    }
}

#Preview {
    NavigationStack { PairView().background(Ground(awake: 1).ignoresSafeArea()) }.environment(Computer())
}
