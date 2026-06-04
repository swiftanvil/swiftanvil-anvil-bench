import SwiftUI

/// Surface roles in the redesigned dashboard.
///
/// Liquid Glass on iOS 26 maps each role to a `Glass` configuration; iOS 18
/// falls back to a system-default material with no manual back-port.
enum BenchmarkSurfaceRole {
    case filterBar
    case card
    case toolbarChip
}

extension View {
    /// Applies the Liquid Glass surface treatment for the supplied role when running
    /// on iOS 26 or newer; otherwise falls back to a native iOS 18 material
    /// (`ultraThinMaterial` for bars, `thinMaterial` for cards).
    @ViewBuilder
    func benchmarkSurface(_ role: BenchmarkSurfaceRole) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            modifier(BenchmarkLiquidGlassSurfaceModifier(role: role))
        } else {
            modifier(BenchmarkFallbackSurfaceModifier(role: role))
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct BenchmarkLiquidGlassSurfaceModifier: ViewModifier {
    let role: BenchmarkSurfaceRole

    func body(content: Content) -> some View {
        switch role {
        case .filterBar:
            content
                .glassEffect(.regular, in: Rectangle())
        case .card:
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .toolbarChip:
            content
                .glassEffect(.regular.interactive(), in: Capsule())
        }
    }
}

private struct BenchmarkFallbackSurfaceModifier: ViewModifier {
    let role: BenchmarkSurfaceRole

    func body(content: Content) -> some View {
        switch role {
        case .filterBar:
            content
                .background(.ultraThinMaterial)
        case .card:
            content
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .toolbarChip:
            content
                .background(.thinMaterial, in: Capsule())
        }
    }
}
