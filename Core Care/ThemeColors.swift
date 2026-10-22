//
//  ThemeColors.swift
//  Core Care
//
//  Centralised adaptive colour tokens and glossy card styles for Light / Dark mode support.
//  Usage: Color.appBackground, Color.cardBackground, Color.textPrimary, .glossyCard(), .adaptiveCard()
//

import SwiftUI

// MARK: - Adaptive Semantic Colours
extension Color {

    // MARK: Backgrounds
    /// Main screen background  (white / system-dark)
    static let appBackground     = Color(UIColor.systemBackground)
    /// Slightly tinted background for sections
    static let appBackground2    = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 1.0)
            : UIColor.secondarySystemBackground
    })
    
    /// Card / surface colour – rich obsidian translucent glass in dark mode, crisp card surface in light mode
    static let cardBackground    = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 0.88)
            : UIColor.secondarySystemBackground
    })
    
    /// Grouped table-style background
    static let groupedBackground = Color(UIColor.systemGroupedBackground)

    // MARK: Text
    /// Primary label  (near-black / white)
    static let textPrimary       = Color(UIColor.label)
    /// Secondary label  (medium-grey / light-grey)
    static let textSecondary     = Color(UIColor.secondaryLabel)
    /// Tertiary label
    static let textTertiary      = Color(UIColor.tertiaryLabel)

    // MARK: Separators & Fills
    static let appSeparator      = Color(UIColor.separator)
    static let appFill           = Color(UIColor.systemFill)
    static let appSecondaryFill  = Color(UIColor.secondarySystemFill)

    // MARK: Brand
    /// CoreCare brand blue  (#2D7A9A) — asset already defined in xcassets
    static let coreBlueBrand     = Color("coreblue")
    /// Accent / action colour – brighter in dark mode
    static let appAccent         = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.65, blue: 1.00, alpha: 1)
            : UIColor(red: 0.24, green: 0.55, blue: 1.00, alpha: 1)
    })

    // MARK: Status
    static let statusSuccess     = Color(UIColor.systemGreen)
    static let statusWarning     = Color(UIColor.systemOrange)
    static let statusError       = Color(UIColor.systemRed)
    static let statusInfo        = Color(UIColor.systemBlue)

    // MARK: Hero gradient colours
    static let heroGradientStart = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.16, blue: 0.26, alpha: 1)
            : UIColor(red: 0.24, green: 0.55, blue: 1.00, alpha: 1)
    })
    static let heroGradientEnd   = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.25, green: 0.18, blue: 0.38, alpha: 1)
            : UIColor(red: 0.45, green: 0.32, blue: 0.95, alpha: 1)
    })

    /// Card shadow – deep ambient elevation in dark mode, crisp clean elevation in light mode
    static let cardShadow        = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.45)
            : UIColor.black.withAlphaComponent(0.08)
    })
    
    /// Card border stroke for clear elevation and glossy light reflection
    static let cardBorder        = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.18)
            : UIColor.black.withAlphaComponent(0.06)
    })
    
    /// Subtle ambient colored glow around card edges in dark mode
    static let cardGlow          = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.25, green: 0.45, blue: 0.80, alpha: 0.10)
            : UIColor.clear
    })
}

// MARK: - Adaptive Gradient Helpers
extension LinearGradient {

    /// Main hero gradient (blue→purple), adapts to dark mode
    static var appHero: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.heroGradientStart, .heroGradientEnd]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// Splash / landing screen background gradient
    static var appSplash: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.appBackground,
                Color.appAccent.opacity(0.05),
                Color(UIColor.systemCyan).opacity(0.08)
            ]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// AI / teal action gradient
    static var appAI: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(UIColor { tc in
                    tc.userInterfaceStyle == .dark
                        ? UIColor(red: 0.10, green: 0.70, blue: 0.55, alpha: 1)
                        : UIColor(red: 0.15, green: 0.85, blue: 0.65, alpha: 1)
                }),
                Color(UIColor { tc in
                    tc.userInterfaceStyle == .dark
                        ? UIColor(red: 0.05, green: 0.58, blue: 0.45, alpha: 1)
                        : UIColor(red: 0.08, green: 0.75, blue: 0.58, alpha: 1)
                })
            ]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    
    /// Glossy surface directional gradient with luminous top highlight
    static var glossyCardSurface: LinearGradient {
        LinearGradient(
            colors: [
                Color(UIColor { tc in
                    tc.userInterfaceStyle == .dark
                        ? UIColor(red: 0.15, green: 0.18, blue: 0.25, alpha: 0.90)
                        : UIColor(white: 1.0, alpha: 0.98)
                }),
                Color(UIColor { tc in
                    tc.userInterfaceStyle == .dark
                        ? UIColor(red: 0.09, green: 0.11, blue: 0.16, alpha: 0.85)
                        : UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 0.92)
                })
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Directional specular border stroke (light catches top-left and fades to bottom-right)
    static var glossyCardBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color(UIColor { tc in
                    tc.userInterfaceStyle == .dark
                        ? UIColor.white.withAlphaComponent(0.26)
                        : UIColor.white.withAlphaComponent(0.85)
                }),
                Color(UIColor { tc in
                    tc.userInterfaceStyle == .dark
                        ? UIColor.white.withAlphaComponent(0.10)
                        : UIColor.black.withAlphaComponent(0.06)
                }),
                Color(UIColor { tc in
                    tc.userInterfaceStyle == .dark
                        ? UIColor.white.withAlphaComponent(0.04)
                        : UIColor.black.withAlphaComponent(0.02)
                })
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Modifier — Glossy Card with Specular Shine
struct GlossyCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 18
    var borderTint: Color? = nil
    var showInnerSheen: Bool = true
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 1. Frosted Material Layer
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // 2. Glossy Surface Gradient
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient.glossyCardSurface)
                    
                    // 3. Specular Inner Sheen Reflection (Top Glass Light Catch in Dark Mode)
                    if showInnerSheen && colorScheme == .dark {
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.03),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 38)
                            Spacer()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    
                    // 4. Directional Specular Border Stroke
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            borderTint != nil
                                ? LinearGradient(
                                    colors: [
                                        borderTint!.opacity(colorScheme == .dark ? 0.50 : 0.40),
                                        borderTint!.opacity(colorScheme == .dark ? 0.22 : 0.15),
                                        Color.cardBorder
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient.glossyCardBorder,
                            lineWidth: colorScheme == .dark ? 1.2 : 1.0
                        )
                }
            )
            // 5. Deep Ambient Drop Shadow
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.48) : Color.cardShadow,
                radius: colorScheme == .dark ? 14 : 10,
                x: 0,
                y: colorScheme == .dark ? 7 : 4
            )
            // 6. Ambient Optical Rim Dispersion in Dark Mode
            .shadow(
                color: colorScheme == .dark
                    ? (borderTint?.opacity(0.14) ?? Color.cardGlow)
                    : Color.clear,
                radius: 16,
                x: 0,
                y: 0
            )
    }
}

// MARK: - View Modifier — Adaptive Card
struct AdaptiveCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 18
    var borderTint: Color? = nil
    
    func body(content: Content) -> some View {
        content
            .modifier(GlossyCardModifier(cornerRadius: cornerRadius, borderTint: borderTint))
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a premium glossy card appearance with dark mode glassmorphism, specular light catch, and depth.
    func glossyCard(cornerRadius: CGFloat = 18, borderTint: Color? = nil, showInnerSheen: Bool = true) -> some View {
        modifier(GlossyCardModifier(cornerRadius: cornerRadius, borderTint: borderTint, showInnerSheen: showInnerSheen))
    }
    
    /// Applies the standard CoreCare card appearance (adaptive background + glossy specular depth).
    func adaptiveCard(cornerRadius: CGFloat = 18, borderTint: Color? = nil) -> some View {
        modifier(AdaptiveCardModifier(cornerRadius: cornerRadius, borderTint: borderTint))
    }
}
