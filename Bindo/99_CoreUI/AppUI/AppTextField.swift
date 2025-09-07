//
//  AppTextField.swift
//  Bindo
//
//  Created by Sean Choi on 9/11/25.
//

import UIKit

/// 공통 텍스트필드 컴포넌트
/// - 외형/폰트/색/패딩을 AppTheme 토큰으로 통일
/// - 필요 시 키보드 상단에 Done 버튼을 손쉽게 추가 가능
public final class AppTextField: UITextField {

    // MARK: - 스타일 정의
    public enum Kind {
        case standard         // 일반 입력
        case numeric          // 숫자/금액
        case email            // 이메일
        case password         // 비밀번호
        case search           // 검색
    }

    /// 내부 좌우 패딩
    public var contentInsets: NSDirectionalEdgeInsets = .init(top: 0, leading: 10, bottom: 0, trailing: 10) {
        didSet { setNeedsLayout() }
    }

    // MARK: - 내부 패딩 뷰
    private let leftPad = UIView()
    private let rightPad = UIView()

    // MARK: - 초기화
    public init(placeholder: String? = nil, kind: Kind = .standard) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppTheme.Color.background
        textColor = AppTheme.Color.label
        font = AppTheme.Font.body
        borderStyle = .none
        layer.cornerCurve = .continuous
        clipsToBounds = true
        layer.borderWidth = 1
        layer.borderColor = AppTheme.Color.main2.cgColor

        self.placeholder = placeholder
        apply(kind: kind)

        // 패딩 적용
        leftViewMode = .always
        rightViewMode = .always
        leftView = leftPad
        rightView = rightPad
        updatePaddingViews()

        // 고정 높이(필요시 오버라이드 가능)
        heightAnchor.constraint(greaterThanOrEqualToConstant: AppTheme.Control.fieldHeight).isActive = true
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppTheme.Color.background
        textColor = AppTheme.Color.accent
        font = AppTheme.Font.body
        borderStyle = .none
        layer.cornerCurve = .continuous
        clipsToBounds = true
        layer.borderWidth = 1
        layer.borderColor = AppTheme.Color.main2.cgColor
        leftViewMode = .always
        rightViewMode = .always
        leftView = leftPad
        rightView = rightPad
        updatePaddingViews()
        heightAnchor.constraint(greaterThanOrEqualToConstant: AppTheme.Control.fieldHeight).isActive = true
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updatePaddingViews()
        layer.cornerRadius = bounds.height/2
    }

    // MARK: - 스타일 적용
    public func apply(kind: Kind) {
        clearButtonMode = .whileEditing

        switch kind {
        case .standard:
            keyboardType = .default
            autocorrectionType = .no
            spellCheckingType = .no
            textContentType = .none
            isSecureTextEntry = false
            

        case .numeric:
            keyboardType = .decimalPad
            textContentType = .oneTimeCode
            isSecureTextEntry = false

        case .email:
            keyboardType = .emailAddress
            textContentType = .emailAddress
            autocapitalizationType = .none
            isSecureTextEntry = false

        case .password:
            keyboardType = .default
            textContentType = .password
            isSecureTextEntry = true
            autocapitalizationType = .none
            autocorrectionType = .no
            spellCheckingType = .no

        case .search:
            keyboardType = .default
            returnKeyType = .search
            autocorrectionType = .no
            spellCheckingType = .no
            textContentType = .none
            isSecureTextEntry = false
        }
    }

    // MARK: - Done 버튼 추가 (숫자패드 등)
    /// 키보드 상단에 'Done' 버튼을 추가
    public func addDoneToolbar(title: String = "Done",
                                 color: UIColor = AppTheme.Color.accent,
                                 font: UIFont = AppTheme.Font.secondaryTitle,
                                 onTap: (() -> Void)? = nil) {
        let bar = AppAccessoryBar()
        bar.configureDone(title: title, color: color, font: font)
        bar.onDone = { [weak self] in
            onTap?()
            self?.resignFirstResponder()
        }
        inputAccessoryView = bar
    }


    // MARK: - 내부 패딩 처리
    private func updatePaddingViews() {
        let h = bounds.height > 0 ? bounds.height : AppTheme.Control.fieldHeight
        leftPad.frame = CGRect(x: 0, y: 0, width: contentInsets.leading, height: h)
        rightPad.frame = CGRect(x: 0, y: 0, width: contentInsets.trailing, height: h)
    }
}
