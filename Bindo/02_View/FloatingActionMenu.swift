import UIKit

/// 플로팅 액션 메뉴 (Calendar / Stats / Settings)
/// - AppTheme 토큰 사용
/// - iOS 15+
final class FloatingActionMenu: UIView {

    // MARK: - 상태
    enum State { case closed, open }
    private(set) var state: State = .closed

    // MARK: - 외부 콜백
    var onCalendar: (() -> Void)?
    var onStats: (() -> Void)?
    var onSettings: (() -> Void)?

    // MARK: - UI
    private let mainButton = UIButton(type: .system)
    private let stack = UIStackView()
    private let calendarButton = FloatingActionMenu.makeActionButton(title: "Calendar", systemImage: "calendar")
    private let statsButton    = FloatingActionMenu.makeActionButton(title: "Stats",    systemImage: "chart.bar.fill")
    private let settingsButton = FloatingActionMenu.makeActionButton(title: "Settings", systemImage: "gearshape")

    private lazy var backdrop: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
//        control.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        control.backgroundColor = .clear
        control.isUserInteractionEnabled = true
        control.addTarget(self, action: #selector(close), for: .touchUpInside)
        control.accessibilityLabel = "Dismiss Menu"
        return control
    }()
    
    public var dismissOnBackgroundTap: Bool = true {
        didSet { backdrop.isUserInteractionEnabled = dismissOnBackgroundTap }
    }

    // 고정 크기(원형)
    private let mainSize: CGFloat = 56

    // MARK: - 초기화
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - 빌드
    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true

        // 메인 버튼
        mainButton.translatesAutoresizingMaskIntoConstraints = false
        configureMainButton()
        mainButton.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        mainButton.accessibilityLabel = "Open Menu"

        // 스택(액션 버튼들)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .trailing
        stack.isHidden = true

        // 액션 버튼 초기 상태/타깃
        [calendarButton, statsButton, settingsButton].forEach { button in
            button.alpha = 0.0
            button.transform = CGAffineTransform(translationX: 0, y: 8)
            button.layer.cornerCurve = .continuous
        }
        calendarButton.addTarget(self, action: #selector(calendarTapped), for: .touchUpInside)
        statsButton.addTarget(self,    action: #selector(statsTapped),    for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)

        // 계층
        addSubview(stack)
        addSubview(mainButton)
        stack.addArrangedSubview(calendarButton)
        stack.addArrangedSubview(statsButton)
        stack.addArrangedSubview(settingsButton)

        // 제약
        NSLayoutConstraint.activate([
            // 메인 버튼 크기
            mainButton.widthAnchor.constraint(equalToConstant: mainSize),
            mainButton.heightAnchor.constraint(equalToConstant: mainSize),

            // safeArea에 마진으로 붙이기
            mainButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -18),
            mainButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -18),

            // 스택: 메인 버튼 위로
            stack.trailingAnchor.constraint(equalTo: mainButton.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: mainButton.topAnchor, constant: -12)
        ])
    }

    /// 메인 버튼 외형 설정 (AppTheme 토큰)
    private func configureMainButton() {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = AppTheme.Color.accent.withAlphaComponent(0.92)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = .init(top: 14, leading: 14, bottom: 14, trailing: 14)
        config.image = UIImage(systemName: "list.bullet")
        config.preferredSymbolConfigurationForImage = .init(pointSize: 18, weight: .semibold)
        mainButton.configuration = config

        mainButton.layer.cornerRadius = mainSize / 2
        mainButton.layer.cornerCurve = .continuous
        mainButton.layer.shadowColor = UIColor.black.cgColor
        mainButton.layer.shadowOpacity = 0.18
        mainButton.layer.shadowRadius = 8
        mainButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        mainButton.tintColor = .white
    }

    // 액션 버튼 공통 스타일 (AppTheme 토큰)
    private static func makeActionButton(title: String, systemImage: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = AppTheme.Color.accent
        config.baseForegroundColor = .white
        config.image = UIImage(systemName: systemImage)
        config.imagePadding = 8
        config.imagePlacement = .leading
        config.titleAlignment = .leading
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        config.cornerStyle = .fixed
        config.attributedTitle = AttributedString(title, attributes: .init([
            .font : AppTheme.Font.body
        ]))

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        button.layer.cornerRadius = 14
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 6
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.widthAnchor.constraint(equalToConstant: 180).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    // MARK: - 히트 테스트 (열림/닫힘에 따라 터치 영역 제한)
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        switch state {
        case .closed:
            // 닫힌 상태: 플로팅 메인 버튼만 터치 허용
            let hitRect = mainButton.frame.insetBy(dx: -10, dy: -10)
            return hitRect.contains(point)
        case .open:
            // 열린 상태: 메뉴 전체가 터치 '가로채기' (아래 뷰로 전달 차단)
            return bounds.contains(point)
        }
    }

    // MARK: - 열기/닫기
    @objc private func toggle() {
        state == .closed ? open() : close()
    }

    func open() {
        guard state == .closed else { return }
        state = .open

        self.alpha = 1

        // backdrop을 메뉴(self)의 0번 인덱스로 추가 (항상 모든 컨텐츠 위에 덮임)
        if backdrop.superview == nil {
            insertSubview(backdrop, at: 0)
            NSLayoutConstraint.activate([
                backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
                backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
                backdrop.topAnchor.constraint(equalTo: topAnchor),
                backdrop.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
        backdrop.isHidden = false
        backdrop.isUserInteractionEnabled = dismissOnBackgroundTap
        backdrop.alpha = 1

        // 스택 표시 & 해프틱
        stack.isHidden = false
        UISelectionFeedbackGenerator().selectionChanged()

        // 배경 페이드인
//        UIView.animate(withDuration: 0.22) { self.backdrop.alpha = 1 }

        // 메인 버튼 전환
        UIView.animate(withDuration: 0.45,
                       delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.4,
                       options: [.curveEaseOut]) {
            var config = self.mainButton.configuration
            config?.image = UIImage(systemName: "xmark")
            config?.baseBackgroundColor = AppTheme.Color.accent
            self.mainButton.configuration = config
        }

        // 액션 버튼 순차 등장
        let buttons = [calendarButton, statsButton, settingsButton]
        for (i, button) in buttons.enumerated() {
            UIView.animate(withDuration: 0.28, delay: 0.05 * Double(i), options: [.curveEaseOut]) {
                button.alpha = 1.0
                button.transform = .identity
            }
        }
    }

    @objc func close() {
        guard state == .open else { return }
        state = .closed
        
        backdrop.isHidden = true

        self.alpha = 0.92

//        // 배경 페이드아웃 (뷰는 유지, alpha만 0으로)
//        UIView.animate(withDuration: 0.22, animations: {
//            self.backdrop.alpha = 0
//        }, completion: { _ in
//            self.backdrop.isHidden = true
//        })

        // 메인 버튼 복원
        UIView.animate(withDuration: 0.45,
                       delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.4,
                       options: [.curveEaseOut]) {
            var config = self.mainButton.configuration
            config?.image = UIImage(systemName: "list.bullet")
            config?.baseBackgroundColor = AppTheme.Color.accent.withAlphaComponent(0.92)
            self.mainButton.configuration = config
        }

        // 액션 버튼 숨기기
        let buttons = [calendarButton, statsButton, settingsButton]
        for (i, button) in buttons.enumerated() {
            UIView.animate(withDuration: 0.20, delay: 0.02 * Double(i), options: [.curveEaseIn]) {
                button.alpha = 0.0
                button.transform = CGAffineTransform(translationX: 0, y: 8)
            } completion: { _ in
                if button == buttons.last { self.stack.isHidden = true }
            }
        }
    }
    

    // MARK: - 버튼 핸들러
    @objc private func calendarTapped() {
        onCalendar?()
        close()
    }
    @objc private func statsTapped() {
        onStats?()
        close()
    }
    @objc private func settingsTapped() {
        onSettings?()
        close()
    }

    // MARK: - 편의: 어디서든 붙이는 헬퍼(선택)
    /// 호스트 VC 위에 오버레이로 추가
    func present(over host: UIViewController) {
        guard let root = host.view, superview == nil else { return }
        root.addSubview(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: root.leadingAnchor),
            trailingAnchor.constraint(equalTo: root.trailingAnchor),
            topAnchor.constraint(equalTo: root.topAnchor),
            bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        root.bringSubviewToFront(self)
    }
}
