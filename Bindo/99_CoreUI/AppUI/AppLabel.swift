//
//  AppLabel.swift
//  Bindo
//
//  Created by Sean Choi on 9/11/25.
//

import UIKit

/// 공통 라벨 컴포넌트
/// - 스타일/색 팔레트를 AppTheme 토큰으로 통일
public final class AppLabel: UILabel {

    // MARK: - 스타일 정의
    public enum Style {
        case title
        case secondaryTitle
        case body
        case secondaryBody
        case caption
    }

    /// 색상 톤 (라이트/다크 대응은 UIColor가 알아서 처리)
    public enum Tone {
        case main1   // 기본 텍스트
        case main2   // 보조 텍스트
        case main3   // 더 옅은 텍스트
        case accent  // 포인트 컬러
        case label   // 흑백 텍스트
    }

    // MARK: - 초기화
    public init(_ text: String? = nil, style: Style = .body, tone: Tone = .main1) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        numberOfLines = 0
        setStyle(style)
        setTone(tone)
        self.text = text
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        translatesAutoresizingMaskIntoConstraints = false
        numberOfLines = 0
        setStyle(.body)
        setTone(.main1)
    }

    // MARK: - 공개 메서드
    public func setStyle(_ style: Style) {
        switch style {
        case .title:          font = AppTheme.Font.title
        case .secondaryTitle: font = AppTheme.Font.secondaryTitle
        case .body:           font = AppTheme.Font.body
        case .secondaryBody:  font = AppTheme.Font.secondaryBody
        case .caption:        font = AppTheme.Font.caption
        }
    }

    public func setTone(_ tone: Tone) {
        switch tone {
        case .main1:  textColor = AppTheme.Color.main1
        case .main2:  textColor = AppTheme.Color.main2
        case .main3:  textColor = AppTheme.Color.main3
        case .accent: textColor = AppTheme.Color.accent
        case .label:   textColor = AppTheme.Color.label
        }
    }
}
