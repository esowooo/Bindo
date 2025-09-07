//
//  AppAccessoryBar.swift
//  Bindo
//
//  Created by Sean Choi on 9/14/25.
//

// CoreUI/Sources/AppUI/AppAccessoryBar.swift
import UIKit

final class AppAccessoryBar: UIView {
    // 액션 콜백
    var onDone: (() -> Void)?

    private let stack = UIStackView()
    private let spacer = UIView()
    private let doneButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    // 높이만 명시, 너비는 시스템이 화면 폭으로 지정
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }

    private func buildUI() {
        backgroundColor = AppTheme.Color.background

        // 스택 구성: [spacer, Done]
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        spacer.translatesAutoresizingMaskIntoConstraints = false

        var cfg = UIButton.Configuration.plain()
        cfg.baseForegroundColor = AppTheme.Color.accent
        var attrs = AttributeContainer()
        attrs.font = AppTheme.Font.secondaryTitle
        cfg.attributedTitle = AttributedString("Done", attributes: attrs)
        doneButton.configuration = cfg
        doneButton.addAction(UIAction { [weak self] _ in self?.onDone?() }, for: .touchUpInside)

        addSubview(stack)
        stack.addArrangedSubview(spacer)
        stack.addArrangedSubview(doneButton)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

//MARK: - Public
extension AppAccessoryBar {
    // 공개 API: 버튼 타이틀/색/폰트 설정
    func configureDone(title: String,
                       color: UIColor = AppTheme.Color.accent,
                       font: UIFont = AppTheme.Font.secondaryTitle) {
        var cfg = UIButton.Configuration.plain()
        cfg.baseForegroundColor = color
        var attrs = AttributeContainer()
        attrs.font = font
        cfg.attributedTitle = AttributedString(title, attributes: attrs)
        doneButton.configuration = cfg
    }
    
    
    
    
}
