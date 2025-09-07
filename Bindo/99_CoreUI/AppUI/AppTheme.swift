
//
//  AppTheme.swift
//  CoreUI
//
//  기본 색상/폰트 토큰 정의
//

import UIKit

// MARK: - Font Type (커스텀 폰트)
private enum FontType: String {
    case quickSandBold     = "Quicksand-Bold"
    case quicksandSemiBold = "Quicksand-SemiBold"
    case quickSandMedium   = "Quicksand-Medium"
    case quickSandRegular  = "Quicksand-Regular"
    case quickSandLight    = "Quicksand-Light"
    
    var name: String { rawValue }
}

//MARK: - App Theme
public enum AppTheme {
    
    // MARK: - Colors (5가지 고정, 필요 시 확장)
    public enum Color {
        public static var background: UIColor { .color1 }
        public static var main1: UIColor { .color4 }    // 기본 텍스트
        public static var main2: UIColor { .color3 }    // 보조 텍스트 / 옅은색
        public static var main3: UIColor { .color2 }    // 보조 텍스트2 / 더 옅은색
        public static var accent: UIColor { .color5 }
        public static var label: UIColor { .color6 }
    }
    
    // MARK: - Fonts (5종류, 필요 시 확장)
    public enum Font {
        public static var title: UIFont {
            UIFont(name: FontType.quicksandSemiBold.rawValue, size: 24)
            ?? .systemFont(ofSize: 24, weight: .semibold)
        }
        public static var secondaryTitle: UIFont {
            UIFont(name: FontType.quicksandSemiBold.rawValue, size: 20)
            ?? .systemFont(ofSize: 20, weight: .semibold)
        }
        public static var body: UIFont {
            UIFont(name: FontType.quickSandRegular.rawValue, size: 16)
            ?? .systemFont(ofSize: 16, weight: .regular)
        }
        public static var secondaryBody: UIFont {
            UIFont(name: FontType.quickSandRegular.rawValue, size: 12)
            ?? .systemFont(ofSize: 14, weight: .regular)
        }
        public static var caption: UIFont {
            UIFont(name: FontType.quickSandRegular.rawValue, size: 10)
            ?? .systemFont(ofSize: 12, weight: .regular)
        }
    }
    
    // MARK: - Spacing
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s:  CGFloat = 8
        public static let m:  CGFloat = 12
        public static let l:  CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }
    
    
    // MARK: - Corner Radius
    public enum Corner {
        public static let s: CGFloat = 6
        public static let m: CGFloat = 8
        public static let l: CGFloat = 12
        public static let xl: CGFloat = 14
    }
    
    
    
    // MARK: - Shadow (카드/팝오버 등에 사용)
    public enum Shadow {
        public static func applyCard(to layer: CALayer) {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.08
            layer.shadowRadius = 10
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.masksToBounds = false
        }
    }
    
    
    // MARK: - Control Sizes (자주 쓰는 컴포넌트 크기)
    public enum Control {
        public static let fieldHeight: CGFloat = 40
        public static let buttonHeight: CGFloat = 44
        public static let pickerMinHeight: CGFloat = 180
        public static let separatorThickness: CGFloat = 1.0 / UIScreen.main.scale
    }
    
    //MARK: - Pull Down
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
