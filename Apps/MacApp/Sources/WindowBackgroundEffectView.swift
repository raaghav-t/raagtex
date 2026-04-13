import AppKit
import Shared
import SwiftUI

struct WindowBackgroundEffectConfiguration {
    var enableBackgroundBlur: Bool
    var blurStrength: Double
    var blurMaterial: BackgroundBlurMaterial
    var blurBlendMode: BackgroundBlurBlendMode
    var tintColor: Color
    var tintOpacity: Double
    var fallbackBlurRadius: Double
    var rendererPreference: BackgroundRendererPreference
}

enum WindowBackgroundRenderingPath: String {
    case nativeMaterialBlur
    case cssBackdropBlur
    case frameworkBlur
    case tintOnlyFallback
}

struct WindowBackgroundEffectView: View {
    let configuration: WindowBackgroundEffectConfiguration

    var body: some View {
        ZStack {
            switch resolvedPath {
            case .nativeMaterialBlur:
                NativeMaterialBlurLayer(
                    material: configuration.blurMaterial,
                    blendMode: configuration.blurBlendMode,
                    strength: configuration.blurStrength
                )
            case .frameworkBlur:
                // Framework-level fallback blur (still lower fidelity than native backdrop blur).
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .blur(radius: max(0, configuration.fallbackBlurRadius * 0.08), opaque: false)
                    .opacity(configuration.enableBackgroundBlur ? min(max(configuration.blurStrength, 0.0), 1.0) : 0)
            case .cssBackdropBlur:
                // CSS backdrop blur is not available in this native AppKit stack.
                Color.clear
            case .tintOnlyFallback:
                Color.clear
            }

            if effectiveTintOpacity > 0.001 {
                // Tint is an independent layer above blur. Tint-only is *not* real blur; it only
                // shifts color/opacity and does not sample/blur pixels behind the window.
                Rectangle()
                    .fill(configuration.tintColor.opacity(effectiveTintOpacity))
            }
        }
        // Keep this as a pure background layer so text, caret, and selection stay crisp.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var resolvedPath: WindowBackgroundRenderingPath {
        if configuration.enableBackgroundBlur == false {
            return .tintOnlyFallback
        }

        switch configuration.rendererPreference {
        case .nativeMaterialBlur:
            guard NSClassFromString("NSVisualEffectView") != nil else {
                return .tintOnlyFallback
            }
            return .nativeMaterialBlur
        case .frameworkBlur:
            return .frameworkBlur
        case .cssBackdropBlur:
            return .cssBackdropBlur
        case .tintOnlyFallback:
            return .tintOnlyFallback
        }
    }

    private var effectiveTintOpacity: Double {
        min(max(configuration.tintOpacity, 0.0), 0.35)
    }
}

private struct NativeMaterialBlurLayer: NSViewRepresentable {
    let material: BackgroundBlurMaterial
    let blendMode: BackgroundBlurBlendMode
    let strength: Double

    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView(frame: .zero)
        // Native macOS blur path: this layer handles real backdrop sampling/blur.
        effectView.blendingMode = blendMode.nsBlendMode
        effectView.state = .active
        effectView.isEmphasized = false
        effectView.material = material.nsMaterial
        return effectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.blendingMode = blendMode.nsBlendMode
        nsView.material = material.nsMaterial
        // NSVisualEffectView does not expose a blur-radius API. Slider drives effect intensity
        // by controlling visibility of the native material layer (not by adding tint).
        let clampedStrength = min(max(strength, 0.0), 1.0)
        nsView.alphaValue = clampedStrength
        nsView.isHidden = clampedStrength <= 0.001
        nsView.state = clampedStrength <= 0.001 ? .inactive : .active
    }
}

private extension BackgroundBlurMaterial {
    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .underWindowBackground:
            return .underWindowBackground
        case .hudWindow:
            return .hudWindow
        case .sidebar:
            return .sidebar
        case .windowBackground:
            return .windowBackground
        }
    }
}

private extension BackgroundBlurBlendMode {
    var nsBlendMode: NSVisualEffectView.BlendingMode {
        switch self {
        case .behindWindow:
            return .behindWindow
        case .withinWindow:
            return .withinWindow
        }
    }
}
