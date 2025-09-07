//
//  AppSeparator.swift
//  Bindo
//
//  Created by Sean Choi on 9/11/25.
//

import UIKit

/// 1px 헤어라인 구분선
public final class AppSeparator: UIView {
    public init(color: UIColor = AppTheme.Color.main3) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = color
        heightAnchor.constraint(equalToConstant: AppTheme.Control.separatorThickness).isActive = true
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
