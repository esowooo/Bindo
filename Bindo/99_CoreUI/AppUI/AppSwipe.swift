//
//  AppSwipe.swift
//  Bindo
//
//  Created by Sean Choi on 9/13/25.
//
//TODO: - Need to Create Custom Style if want to modify further

import UIKit

public enum AppSwipeStyle {
    case primary
    case warning
    case destructive
    case custom(UIColor)
}

public enum AppSwipeIcon {
    case system(String,
                pointSize: CGFloat = 17,
                weight: UIImage.SymbolWeight = .semibold,
                scale: UIImage.SymbolScale = .medium,
                tint: UIColor? = nil)
    case image(UIImage)
    case none
}

public struct AppSwipe {
    /// 공통 색상 매핑
    private static func backgroundColor(for style: AppSwipeStyle) -> UIColor {
        switch style {
        case .primary:     return AppTheme.Color.accent
        case .warning:     return AppTheme.Color.main3
        case .destructive: return .systemRed
        case .custom(let color): return color
        }
    }

    /// 아이콘 생성 유틸
    private static func makeIcon(_ icon: AppSwipeIcon) -> UIImage? {
        switch icon {
        case .none: return nil
        case .image(let img): return img
        case .system(let name, let pointSize, let weight, let scale, let tint):
            let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight, scale: scale)
            var img = UIImage(systemName: name, withConfiguration: config)
            if let tint {
                img = img?.withTintColor(tint, renderingMode: .alwaysOriginal)
            }
            return img
        }
    }

    /// 커스텀 액션 팩토리
    public static func action(title: String? = nil,
                              icon: AppSwipeIcon = .none,
                              style: AppSwipeStyle = .primary,
                              handler: @escaping (UIContextualAction, UIView, @escaping (Bool)->Void) -> Void) -> UIContextualAction {
        let act = UIContextualAction(style: .normal, title: title, handler: handler)
        act.backgroundColor = backgroundColor(for: style)
        act.image = makeIcon(icon)
        return act
    }

    /// 삭제 전용 단축 생성기
    public static func deleteAction(
        title: String = "Delete",
        icon: AppSwipeIcon = .system("trash.fill",
                                     pointSize: 20,
                                     weight: .bold,
                                     scale: .medium,
                                     tint: .white),
        backgroundColor: UIColor = AppTheme.Color.accent,
        handler: @escaping (UIContextualAction, UIView, @escaping (Bool)->Void) -> Void
    ) -> UIContextualAction {
        let action = self.action(title: title, icon: icon, style: .custom(backgroundColor), handler: handler)
        return action
    }

    /// 구성 빌더
    public static func trailing(_ actions: [UIContextualAction], fullSwipe: Bool = true) -> UISwipeActionsConfiguration {
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = fullSwipe
        return config
    }

    public static func leading(_ actions: [UIContextualAction], fullSwipe: Bool = false) -> UISwipeActionsConfiguration {
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = fullSwipe
        return config
    }
}
