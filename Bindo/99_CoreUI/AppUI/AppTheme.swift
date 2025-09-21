
//
//  AppTheme.swift
//  CoreUI
//
//  기본 색상/폰트 토큰 정의
//

import UIKit


// AppTheme.swift

import UIKit

// MARK: - Language routing for fonts
private enum AppLanguage {
    case latin, korean, japanese
    static var current: AppLanguage {
        let id = Bundle.main.preferredLocalizations.first?.lowercased()
              ?? Locale.preferredLanguages.first?.lowercased()
              ?? Locale.current.identifier.lowercased()
        if id.hasPrefix("ko") { return .korean }
        if id.hasPrefix("ja") { return .japanese }
        return .latin
    }
}

private struct FontFamily {
    let regular: String
    let medium:  String
    let semibold:String
    let bold:    String
}

private func family(for lang: AppLanguage) -> FontFamily {
    switch lang {
    case .latin:
        return .init(
            regular: "Quicksand-Regular",
            medium:  "Quicksand-Medium",
            semibold:"Quicksand-SemiBold",
            bold:    "Quicksand-Bold"
        )
    case .korean:
        return .init(
            regular: "AppleSDGothicNeo-Regular",
            medium:  "AppleSDGothicNeo-Medium",
            semibold:"AppleSDGothicNeo-SemiBold",
            bold:    "AppleSDGothicNeo-Bold"
        )
    case .japanese:
        return .init(
            regular: "HiraginoSans-W3",
            medium:  "HiraginoSans-W4",
            semibold:"HiraginoSans-W6",
            bold:    "HiraginoSans-W7"
        )
    }
}

private func themedFont(name: String, size: CGFloat, weight: UIFont.Weight, textStyle: UIFont.TextStyle) -> UIFont {
    let base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base) // Dynamic Type
}

public enum AppTheme {

    public enum Color {
        public static var background: UIColor { .color1 }
        public static var main1: UIColor { .color4 }
        public static var main2: UIColor { .color3 }
        public static var main3: UIColor { .color2 } // 보조 텍스트2 / 더 옅은색
        public static var accent: UIColor { .color5 }
        public static var label: UIColor { .color6 }
    }

    // MARK: - Fonts (언어별 자동 스위칭)
    public enum Font {
        private static var fam: FontFamily { family(for: AppLanguage.current) }

        public static var title: UIFont {
            themedFont(name: fam.semibold, size: 24, weight: .semibold, textStyle: .title2)
        }
        public static var secondaryTitle: UIFont {
            themedFont(name: fam.semibold, size: 20, weight: .semibold, textStyle: .headline)
        }
        public static var body: UIFont {
            themedFont(name: fam.regular, size: 16, weight: .regular, textStyle: .body)
        }
        public static var secondaryBody: UIFont {
            themedFont(name: fam.regular, size: 12, weight: .regular, textStyle: .footnote)
        }
        public static var caption: UIFont {
            themedFont(name: fam.regular, size: 10, weight: .regular, textStyle: .caption2)
        }
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s:  CGFloat = 8
        public static let m:  CGFloat = 12
        public static let l:  CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Corner {
        public static let s: CGFloat = 6
        public static let m: CGFloat = 8
        public static let l: CGFloat = 12
        public static let xl: CGFloat = 14
    }

    public enum Shadow {
        public static func applyCard(to layer: CALayer) {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.08
            layer.shadowRadius = 10
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.masksToBounds = false
        }
    }

    public enum Control {
        public static let fieldHeight: CGFloat = 40
        public static let buttonHeight: CGFloat = 44
        public static let pickerMinHeight: CGFloat = 180
        public static let separatorThickness: CGFloat = 1.0 / UIScreen.main.scale
    }

    enum PullDown {
        static let popupMinWidth: CGFloat = 50
        static let popupExtraPadding: CGFloat = 15
        static let popupRowHeight: CGFloat = 40
        static let popupMaxVisibleRows: Int = 6
        static let popupCornerRadius: CGFloat = AppTheme.Corner.l
        static let popupShadowOpacity: Float = 0.12
        static let popupShadowRadius: CGFloat = 10
        static let popupShadowOffset: CGSize = .init(width: 0, height: 4)
        static let backdropAlpha: CGFloat = 0.15
        static let contentInsets: NSDirectionalEdgeInsets = .init(top: 6, leading: 12, bottom: 6, trailing: 15)
        static let popupCellMargins: NSDirectionalEdgeInsets = .init(top: 0, leading: 10, bottom: 0, trailing: 10)
        static let popupContentsSpacing: CGFloat = 15
    }
}
// MARK: - Helpers (확장 안전 접근)
private extension UIColor {
    static func performIfAvailable(_ name: String) -> UIColor? {
        let sel = NSSelectorFromString(name)
        guard self.responds(to: sel) else { return nil }
        let unmanaged = self.perform(sel)
        return unmanaged?.takeUnretainedValue() as? UIColor
    }
}

private extension UIFont {
    static func performIfAvailable(_ name: String) -> UIFont? {
        let sel = NSSelectorFromString(name)
        guard self.responds(to: sel) else { return nil }
        let unmanaged = self.perform(sel)
        return unmanaged?.takeUnretainedValue() as? UIFont
    }
}
