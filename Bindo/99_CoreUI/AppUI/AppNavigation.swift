//
//  AppNavigation.swift
//  Bindo
//
//  Created by Sean Choi on 9/11/25.
//

import UIKit

/// 공통 네비게이션 바 & 바버튼 구성 유틸 (iOS 15+)
public enum AppNavigation {

    // MARK: - 기본 Appearance
    public static func standard() -> UINavigationBarAppearance {
        let ap = UINavigationBarAppearance()
        ap.configureWithOpaqueBackground()
        ap.backgroundColor = AppTheme.Color.background
        ap.titleTextAttributes = [
            .foregroundColor: AppTheme.Color.main1,
            .font: AppTheme.Font.secondaryTitle
        ]
        ap.largeTitleTextAttributes = [
            .foregroundColor: AppTheme.Color.main1,
            .font: AppTheme.Font.title
        ]
        ap.shadowColor = .clear
        return ap
    }

    /// 네비게이션 컨트롤러에 공통 스타일 적용
    public static func apply(to nav: UINavigationController?) {
        guard let nav else { return }
        let ap = standard()
        nav.navigationBar.standardAppearance = ap
        nav.navigationBar.scrollEdgeAppearance = ap
        nav.navigationBar.compactAppearance = ap
        nav.navigationBar.tintColor = AppTheme.Color.accent
    }

    // MARK: - TitleView
    public static func makeTitleView(_ text: String) -> UIView {
        let label = AppLabel(text, style: .secondaryTitle, tone: .main1)
        let container = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
    
    public static func makeBottomAlignedTitle(_ text: String, offsetY: CGFloat = 0) -> UIView {
        let label = AppLabel(text, style: .secondaryTitle, tone: .main1)
        label.textAlignment = .center

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            // 아래로 내리고 싶을수록 +값
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: offsetY)
        ])
        
        container.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        return container
    }

    // MARK: - Bar Button 스타일
    public struct BarStyle {
        public var tint: UIColor
        public var background: UIColor?   // nil이면 투명(plain)
        public var corner: CGFloat
        public var contentInsets: NSDirectionalEdgeInsets
        public var symbolPointSize: CGFloat
        public var symbolWeight: UIImage.SymbolWeight

        public init(tint: UIColor = AppTheme.Color.accent,
                    background: UIColor? = nil,
                    corner: CGFloat = AppTheme.Corner.m,
                    contentInsets: NSDirectionalEdgeInsets = .init(top: 6, leading: 10, bottom: 6, trailing: 10),
                    symbolPointSize: CGFloat = 17,
                    symbolWeight: UIImage.SymbolWeight = .semibold) {
            self.tint = tint
            self.background = background
            self.corner = corner
            self.contentInsets = contentInsets
            self.symbolPointSize = symbolPointSize
            self.symbolWeight = symbolWeight
        }

        public static var plainAccent: BarStyle { .init() }
        public static var filledAccent: BarStyle { .init(tint: .white, background: AppTheme.Color.accent) }
    }

    public struct BarItem {
        public let systemImage: String
        public let accessibilityLabel: String?
        public let action: UIAction

        public init(systemImage: String,
                    accessibilityLabel: String? = nil,
                    action: UIAction) {
            self.systemImage = systemImage
            self.accessibilityLabel = accessibilityLabel
            self.action = action
        }
    }

    /// 커스텀 UIButton 기반 UIBarButtonItem 생성 (타이틀 없이 아이콘만)
    public static func makeButton(_ item: BarItem, style: BarStyle = .plainAccent) -> UIBarButtonItem {
        let button: UIButton
        var cfg: UIButton.Configuration
        if let bg = style.background {
            cfg = .filled()
            cfg.baseBackgroundColor = bg
            cfg.baseForegroundColor = style.tint
            cfg.background.cornerRadius = style.corner
        } else {
            cfg = .plain()
            cfg.baseForegroundColor = style.tint
        }
        cfg.contentInsets = style.contentInsets
        cfg.image = UIImage(systemName: item.systemImage)
        cfg.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: style.symbolPointSize, weight: style.symbolWeight)

        button = UIButton(configuration: cfg)
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = style.corner
        button.addAction(item.action, for: .touchUpInside)
        button.accessibilityLabel = item.accessibilityLabel ?? item.systemImage

        // 고정 높이(네비바 터치 타겟 확보)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: AppTheme.Control.buttonHeight)
        ])

        return UIBarButtonItem(customView: button)
    }

    // MARK: - 좌/우 아이템 일괄 적용
    public static func setItems(left: [UIBarButtonItem] = [],
                                right: [UIBarButtonItem] = [],
                                for vc: UIViewController) {
        vc.navigationItem.leftBarButtonItems = left
        vc.navigationItem.rightBarButtonItems = right
    }
}
