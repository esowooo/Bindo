//
//  AppAlertController.swift
//  Bindo
//
//  Created by Sean Choi on 9/13/25.
//

import UIKit

// MARK: - Public API

public enum AppAlertButtonStyle {
    case primary      // 강조(Accent 배경)
    case secondary    // 회색톤 배경
    case plain        // 텍스트만
    case destructive  // 빨강 텍스트
    case cancel       // 닫기 전용
}

public struct AppAlertAction {
    public let title: String
    public let style: AppAlertButtonStyle
    public let handler: (() -> Void)?

    public init(title: String, style: AppAlertButtonStyle = .primary, handler: (() -> Void)? = nil) {
        self.title = title
        self.style = style
        self.handler = handler
    }
}

/// 구성 객체: 테두리/모서리/아이콘/블러/딤/레이아웃 등
public struct AppAlertConfiguration {
    public var cornerRadius: CGFloat = AppTheme.Corner.xl
    public var cornerCurve: CALayerCornerCurve = .continuous
    public var borderWidth: CGFloat = 2
    public var borderColor: UIColor = AppTheme.Color.accent
    public var showsBlurBackground: Bool = false
    public var dimColor: UIColor = UIColor.black.withAlphaComponent(0.35)
    public var icon: UIImage? = nil
    public var iconTint: UIColor = AppTheme.Color.accent

    public var maxWidth: CGFloat = 360
    public var horizontalPadding: CGFloat = 20
    public var buttonAxis: NSLayoutConstraint.Axis = .vertical

    public var widthRatio: CGFloat = 0.7  // 화면 너비의 70%
    public var heightRatio: CGFloat = 0.33 // 화면 높이의 1/3 로 줄임
    public var allowsContentScroll: Bool = true

    public init() {}
}

/// 편의 정적 API
public enum AppAlert {
    /// 가장 간단한 호출
    @discardableResult
    public static func present(on presenter: UIViewController,
                               title: String?,
                               message: String?,
                               actions: [AppAlertAction],
                               configuration: AppAlertConfiguration = .init(),
                               animated: Bool = true) -> AppAlertController {
        let vc = AppAlertController(title: title, message: message, actions: actions, configuration: configuration)
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        presenter.present(vc, animated: animated)
        return vc
    }

    /// 상위 VC 탐색 편의
    @discardableResult
    public static func present(from view: UIView,
                               title: String?,
                               message: String?,
                               actions: [AppAlertAction],
                               configuration: AppAlertConfiguration = .init(),
                               animated: Bool = true) -> AppAlertController? {
        guard let vc = view.parentViewController else { return nil }
        return present(on: vc, title: title, message: message, actions: actions, configuration: configuration, animated: animated)
    }
    
    @discardableResult
    static func info(on vc: UIViewController,
                     title: String,
                     message: String,
                     button: String = "OK") -> AppAlertController {
        AppAlert.present(on: vc,
                         title: title,
                         message: message,
                         actions: [.init(title: button, style: .primary)])
    }
    
    @discardableResult
    static func info(from view: UIView,
                     title: String,
                     message: String,
                     button: String = "OK") -> AppAlertController? {
        AppAlert.present(from: view,
                         title: title,
                         message: message,
                         actions: [.init(title: button, style: .primary)])
    }
    
    
    
}

// MARK: - Controller

public final class AppAlertController: UIViewController {

    // 입력
    private let alertTitle: String?
    private let alertMessage: String?
    private let actions: [AppAlertAction]
    private let config: AppAlertConfiguration

    // UI
    private let dimView = UIView()
    private var blurView: UIVisualEffectView?
    private let card = UIView()
    private let vStack = UIStackView()
    private let titleLabel = AppLabel("", style: .secondaryTitle, tone: .label)
    private let messageLabel = AppLabel("", style: .body, tone: .label)
    private let iconView = UIImageView()
    private let buttonStack = UIStackView()
    private let separator = AppSeparator()

    // MARK: Init

    public init(title: String?,
                message: String?,
                actions: [AppAlertAction],
                configuration: AppAlertConfiguration = .init()) {
        self.alertTitle = title
        self.alertMessage = message
        self.actions = actions
        self.config = configuration
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        applyContent()
        wireEvents()
        animateIn()
    }

    // MARK: UI

    private func buildUI() {
        view.backgroundColor = .clear

        // Dim / Blur
        dimView.backgroundColor = config.dimColor
        dimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimView)

        if config.showsBlurBackground {
            let blur = UIBlurEffect(style: .systemMaterialDark)
            let bv = UIVisualEffectView(effect: blur)
            bv.translatesAutoresizingMaskIntoConstraints = false
            view.insertSubview(bv, aboveSubview: dimView)
            blurView = bv
        }

        // Card
        card.backgroundColor = AppTheme.Color.background
        card.layer.cornerRadius = config.cornerRadius
        card.layer.cornerCurve = config.cornerCurve
        card.layer.borderWidth = config.borderWidth
        card.layer.borderColor = config.borderColor.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        
        // 스크롤 컨테이너
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isScrollEnabled = config.allowsContentScroll
        card.addSubview(scrollView)

        // vStack 설정
        vStack.axis = .vertical
        vStack.alignment = .fill
        vStack.spacing = 14
        vStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(vStack)

        // Icon
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = config.iconTint
        iconView.setContentHuggingPriority(.required, for: .vertical)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Title/Message
        titleLabel.textAlignment = .center
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        // Buttons
        buttonStack.axis = config.buttonAxis
        buttonStack.alignment = .fill
        buttonStack.spacing = 10
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // Compose
        if config.icon != nil { vStack.addArrangedSubview(iconView) }
        if (alertTitle?.isEmpty == false) { vStack.addArrangedSubview(titleLabel) }
        if (alertMessage?.isEmpty == false) { vStack.addArrangedSubview(messageLabel) }
        vStack.addArrangedSubview(separator)
        vStack.addArrangedSubview(buttonStack)

        // Constraints (SAFE & CONTENT-DRIVEN)
        let safe = view.safeAreaLayoutGuide
        let hInset: CGFloat = 24   // 좌우 여백
        let vInset: CGFloat = 24   // 상하 여백
        let contentHPad: CGFloat = config.horizontalPadding + 20

        let contentGuide = scrollView.contentLayoutGuide
        let frameGuide   = scrollView.frameLayoutGuide

        var cs: [NSLayoutConstraint] = []

        // 1) Dim / Blur
        cs += [
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]

        if let bv = blurView {
            cs += [
                bv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                bv.topAnchor.constraint(equalTo: view.topAnchor),
                bv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ]
        }

        // 2) Card — 화면 가장자리와 충돌하지 않는 범위에서 중앙 정렬 + 상한만 둠
        cs += [
            // 중앙 정렬
            card.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: safe.centerYAnchor).settingPriority(.defaultHigh),

            // 바깥 여백 (>=, <= 로 안전하게)
            card.leadingAnchor.constraint(greaterThanOrEqualTo: safe.leadingAnchor, constant: hInset),
            card.trailingAnchor.constraint(lessThanOrEqualTo: safe.trailingAnchor, constant: -hInset),
            card.topAnchor.constraint(greaterThanOrEqualTo: safe.topAnchor, constant: vInset),
            card.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -vInset),

            // 가로 상한 (iPad 등에서 너무 넓지 않게)
            card.widthAnchor.constraint(lessThanOrEqualToConstant: config.maxWidth).settingPriority(.required)
        ]

        // 3) ScrollView — 카드에 풀핀
        cs += [
            scrollView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: card.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ]

        // 4) vStack — 가로 패딩 + 가로 스크롤 방지 + 세로 스크롤 허용
        cs += [
            vStack.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor, constant: contentHPad),
            vStack.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor, constant: -contentHPad),
            // 프레임 가로폭에 맞춰 가로 스크롤 금지
            vStack.widthAnchor.constraint(equalTo: frameGuide.widthAnchor, constant: -(contentHPad * 2)),

            // 콘텐츠가 적으면 가운데 오도록(낮은 우선순위)
            vStack.centerYAnchor.constraint(equalTo: frameGuide.centerYAnchor).settingPriority(.defaultLow),

            // 콘텐츠가 많아지면 위/아래로 스크롤 유도
            vStack.topAnchor.constraint(greaterThanOrEqualTo: contentGuide.topAnchor, constant: 20),
            vStack.bottomAnchor.constraint(lessThanOrEqualTo: contentGuide.bottomAnchor, constant: -16),

            // 아이콘 상한
            iconView.heightAnchor.constraint(lessThanOrEqualToConstant: 44)
        ]

        NSLayoutConstraint.activate(cs)

        // 라벨 정렬 그대로
        titleLabel.textAlignment = .center
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        // 버튼 스택
        buttonStack.axis = config.buttonAxis
        buttonStack.alignment = .fill
        buttonStack.spacing = 10
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
    }
    


    private func applyContent() {
        titleLabel.text = alertTitle
        messageLabel.text = alertMessage
        iconView.image = config.icon?.withRenderingMode(.alwaysTemplate)

        // Buttons
        actions.forEach { action in
            let button = makeButton(for: action)
            buttonStack.addArrangedSubview(button)
        }
    }

    private func makeButton(for action: AppAlertAction) -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        cfg.cornerStyle = .large

        var applyBorder = false

        switch action.style {
        case .primary:
            cfg.baseBackgroundColor = AppTheme.Color.accent
            cfg.baseForegroundColor = AppTheme.Color.background

        case .secondary:
            cfg.baseBackgroundColor = AppTheme.Color.main3.withAlphaComponent(0.15)
            cfg.baseForegroundColor = AppTheme.Color.background

        case .plain:
            cfg = .plain()
            cfg.baseBackgroundColor = AppTheme.Color.background
            cfg.baseForegroundColor = AppTheme.Color.label
            
        case .destructive:
            cfg.baseBackgroundColor = AppTheme.Color.accent
            cfg.baseForegroundColor = AppTheme.Color.background

        case .cancel:
            cfg.baseBackgroundColor = AppTheme.Color.background
            cfg.baseForegroundColor = AppTheme.Color.main1
            applyBorder = true
            
            
        }

        cfg.attributedTitle = AttributedString(
            action.title,
            attributes: AttributeContainer([ .font: AppTheme.Font.secondaryBody ])
        )

        let button = UIButton(configuration: cfg)

        if applyBorder {
            button.layer.cornerRadius = 8
            button.layer.cornerCurve = .continuous
            button.layer.borderWidth = 1
            button.layer.borderColor = AppTheme.Color.main3.cgColor
            button.layer.masksToBounds = true
        }

        button.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true, completion: action.handler)
        }, for: .touchUpInside)

        return button
    }

    // 탭으로 닫기(옵션): 필요하면 enable
    private func wireEvents() {
         let tap = UITapGestureRecognizer(target: self, action: #selector(dimTapped))
         dimView.addGestureRecognizer(tap)
    }

    @objc private func dimTapped() { dismiss(animated: true) }

    // MARK: Animations
    private func animateIn() {
        card.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
        card.alpha = 0
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
            self.card.transform = .identity
            self.card.alpha = 1
        }
    }

    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn]) {
            self.card.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.card.alpha = 0
            self.view.alpha = 0.98
        } completion: { _ in
            super.dismiss(animated: false, completion: completion)
        }
    }
    

}

// MARK: - Parent VC helper
private extension UIView {
    var parentViewController: UIViewController? {
        sequence(first: self.next as UIResponder?, next: { $0?.next })
            .first { $0 is UIViewController } as? UIViewController
    }
}

private extension NSLayoutConstraint {
    func settingPriority(_ p: UILayoutPriority) -> NSLayoutConstraint {
        priority = p
        return self
    }
}

