//
//  AppSeparator.swift
//  Bindo
//
//  Created by Sean Choi on 9/11/25.
//

import UIKit

/// 1px 헤어라인 구분선
public final class AppSeparator: UIView {
    init(color: UIColor = AppTheme.Color.main3 , thickness: CGFloat = AppTheme.Control.separatorThickness) {
        super.init(frame: .zero)
        backgroundColor = color
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: thickness).isActive = true
    }
    
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
