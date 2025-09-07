//
//  AppPullDownField.swift
//  Bindo
//
//  9/11/25 Created by Sean Choi.
//  9/11/25 Updated to custom popup table by Sean Choi.
//


import UIKit

/// 시스템 UIMenu 또는 커스텀 팝업 테이블 기반 풀다운 필드
public final class AppPullDownField: UIView {

    // MARK: - Item
    public struct Item: Hashable {
        public let title: String
        public let systemImage: String?
        public init(_ title: String, image: String? = nil) {
            self.title = title
            self.systemImage = image
        }
    }
    
    private var currentTitle: String = "Select"

    // MARK: - Display Mode
    public enum DisplayMode {
        case systemMenu
        case customPopup
    }

    // MARK: - Public API

    /// 선택 콜백 (index, item)
    public var onSelect: ((Int, Item) -> Void)?

    /// 데이터
    public var items: [Item] = [] {
        didSet { contentWidthForPopup(); rebuildUIForMode() }
    }

    /// 현재 선택 인덱스
    public private(set) var selectedIndex: Int? {
        didSet { applySelection() }
    }

    /// 표시 모드 (기본: systemMenu)
    public var displayMode: DisplayMode = .systemMenu {
        didSet { configureMode() }
    }
    
    

    // 스타일
    public var titleFont: UIFont = AppTheme.Font.body {
        didSet { contentWidthForPopup(); updateButtonAppearance() }
    }
    public var titleColor: UIColor = AppTheme.Color.label { didSet { updateButtonAppearance() } }
    public var imageName: String? = "chevron.down" { didSet { updateButtonAppearance() } }
    public var imageConfig: UIImage.SymbolConfiguration = .init(pointSize: 14, weight: .semibold) {
        didSet { updateButtonAppearance() }
    }
    public var imageColor: UIColor? = AppTheme.Color.accent { didSet { updateButtonAppearance() } }
    public var imagePlacement: NSDirectionalRectEdge = .trailing { didSet { updateButtonAppearance() } }
    public var imagePadding: CGFloat = 6 { didSet { updateButtonAppearance() } }
    public var separatorColor: UIColor = AppTheme.Color.main2 { didSet { tableView.separatorColor = separatorColor } }
    public var limitTouchToContent: Bool = true
    public var tapPadding: CGFloat = 6
    public var backgroundFill: UIColor = AppTheme.Color.background {
        didSet {
            var config = button.configuration
            config?.background.backgroundColor = backgroundFill
            button.configuration = config
        }
    }
    
    public var contentInsets: NSDirectionalEdgeInsets = AppTheme.PullDown.contentInsets {
        didSet {
            var config = button.configuration ?? .filled()
            config.contentInsets = contentInsets
            button.configuration = config
            contentWidthForPopup()
        }
    }
    public var cornerRadius: CGFloat = AppTheme.Corner.m {
        didSet {
            button.layer.cornerRadius = cornerRadius
            button.layer.masksToBounds = true
            // 배경
            var config = button.configuration ?? .filled()
            config.background.cornerRadius = cornerRadius
            button.configuration = config
        }
    }
    
    public var contentsSpacing: CGFloat = AppTheme.PullDown.popupContentsSpacing {
        didSet { contentWidthForPopup() }
    }
    

    // MARK: - Custom Popup Config

    /// 최대 표시 행 수 (초과 시 스크롤)
    public var popupMaxVisibleRows: Int = AppTheme.PullDown.popupMaxVisibleRows
    /// 행 높이
    public var popupRowHeight: CGFloat = AppTheme.PullDown.popupRowHeight
    /// 팝업 너비 (nil이면 버튼 너비와 동일)
    public var popupWidth: CGFloat?
    private var preferredPopupWidth: CGFloat = 0
    /// 팝업 코너
    public var popupCornerRadius: CGFloat = AppTheme.PullDown.popupCornerRadius
    /// 팝업 그림자
    public var popupShadowOpacity: Float = AppTheme.PullDown.popupShadowOpacity
    public var popupShadowRadius: CGFloat = AppTheme.PullDown.popupShadowRadius
    public var popupShadowOffset: CGSize = AppTheme.PullDown.popupShadowOffset
    /// 바깥 터치로 닫기 배경 알파
    public var backdropAlpha: CGFloat = AppTheme.PullDown.backdropAlpha { didSet {backdrop.backgroundColor = UIColor.black.withAlphaComponent(backdropAlpha)} }
    /// 콘텐츠 간격
    public var popupCellMargins: NSDirectionalEdgeInsets = AppTheme.PullDown.popupCellMargins
    /// 셀 사이즈
    private var buttonMinWidthConstraint: NSLayoutConstraint?
    public var minButtonWidth: CGFloat = AppTheme.PullDown.popupMinWidth {
        didSet { buttonMinWidthConstraint?.constant = minButtonWidth; contentWidthForPopup() }
    }
    public var popupExtraPadding: CGFloat = AppTheme.PullDown.popupExtraPadding {
        didSet { contentWidthForPopup() }
    }
    
    // MARK: - UI
    private let button: UIButton = {
        var config = UIButton.Configuration.filled()
        config.background.cornerRadius = AppTheme.PullDown.popupCornerRadius
        config.background.backgroundColor = AppTheme.Color.background
        config.baseForegroundColor = AppTheme.Color.main1
        config.imagePlacement = .trailing
        config.contentInsets = AppTheme.PullDown.contentInsets
        config.titleAlignment = .leading

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.layer.cornerCurve = .continuous
        button.contentHorizontalAlignment = .leading
        return button
    }()
    
    public var titleAlignment: UIButton.Configuration.TitleAlignment = .leading {
        didSet {
            var cfg = button.configuration ?? .filled()
            cfg.titleAlignment = titleAlignment
            button.configuration = cfg
        }
    }

    
    // 커스텀 팝업 구성요소
    private lazy var backdrop: UIControl = {
        let config = UIControl()
        config.translatesAutoresizingMaskIntoConstraints = false
        config.backgroundColor = UIColor.black.withAlphaComponent(backdropAlpha)
        config.addTarget(self, action: #selector(dismissPopup), for: .touchUpInside)
        return config
    }()
    private let popupContainer = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)

    // 상태
    private var popupVisible = false

    // MARK: - Init
    public init(placeholder: String? = "Select") {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        button.isAccessibilityElement = true
        button.accessibilityTraits = [.button]
        button.accessibilityLabel = "Pull down"
        buttonMinWidthConstraint = button.widthAnchor.constraint(greaterThanOrEqualToConstant: minButtonWidth)
        buttonMinWidthConstraint?.isActive = true
        self.setContentHuggingPriority(.required, for: .horizontal)
        self.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setTitle(placeholder ?? "Select")
        cornerRadius = AppTheme.Corner.m

        // 기본 모드: 시스템 메뉴
        configureMode()
        contentWidthForPopup()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    public func setItems(_ items: [Item], select index: Int? = nil) {
        self.items = items
        self.selectedIndex = index
        rebuildUIForMode()
    }


    // MARK: - Mode

    private func configureMode() {
        switch displayMode {
        case .systemMenu:
            button.showsMenuAsPrimaryAction = true
            button.changesSelectionAsPrimaryAction = false
            button.removeTarget(self, action: #selector(togglePopup), for: .touchUpInside)
            rebuildMenu()
        case .customPopup:
            // 시스템 메뉴 해제
            button.showsMenuAsPrimaryAction = false
            button.menu = nil
            // 커스텀 팝업 이벤트 연결
            button.addTarget(self, action: #selector(togglePopup), for: .touchUpInside)
        }
    }

    private func rebuildUIForMode() {
        switch displayMode {
        case .systemMenu:
            rebuildMenu()
        case .customPopup:
            // 테이블 리로드만
            tableView.reloadData()
        }
        applySelection()
    }

    // MARK: - System Menu

    private func rebuildMenu() {
        let actions = items.enumerated().map { (i, it) in
            UIAction(
                title: it.title,
                image: it.systemImage.flatMap(UIImage.init(systemName:)),
                state: (i == selectedIndex) ? .on : .off
            ) { [weak self] _ in
                guard let self else { return }
                self.selectedIndex = i
                self.onSelect?(i, it)
                self.rebuildMenu() // 체크 상태 갱신
            }
        }
        button.menu = UIMenu(children: actions)
    }

    // MARK: - Custom Popup

    @objc private func togglePopup() {
        popupVisible ? dismissPopup() : presentPopup()
    }
    
    private func contentWidthForPopup() {
        // 1) 각 아이템 타이틀의 렌더링 폭 측정
        let maxTitleW: CGFloat = items.map { item in
            (item.title as NSString).size(withAttributes: [.font: titleFont]).width
        }.max() ?? 0

        // 2) 체크표시(선택행) 폭 + 텍스트-체크 간격은 항상 포함해 일관된 폭 유지
        let checkW: CGFloat = 16
        let spacingW: CGFloat = contentsSpacing

        // 3) 버튼 contentInsets (leading/trailing)
        let insets = (button.configuration?.contentInsets ?? contentInsets)
        let lr = insets.leading + insets.trailing

        // 4) 기본 콘텐츠 폭 + 추가 여유
        let base = maxTitleW + checkW + spacingW + lr
        let computed = max(minButtonWidth, base + popupExtraPadding)

        preferredPopupWidth = computed
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard limitTouchToContent else {
            return super.point(inside: point, with: event)
        }
        // 버튼의 콘텐츠(텍스트+아이콘) 크기 추정
        let cfgInsets = (button.configuration?.contentInsets ?? contentInsets)
        let contentSize = button.intrinsicContentSize
        
        // 버튼은 .leading 정렬이므로 x는 leading 인셋부터 시작
        // y는 수직 중앙 배치
        var contentRect = CGRect(
            x: cfgInsets.leading,
            y: (bounds.height - contentSize.height) / 2,
            width: contentSize.width,
            height: contentSize.height
        )
        // 사용자가 느긋하게 탭할 수 있도록 약간의 패딩 허용
        contentRect = contentRect.insetBy(dx: -tapPadding, dy: -tapPadding)
        
        return contentRect.contains(point)
    }
    

    private func presentPopup() {
        guard let host = findTopView() else { return }
        layoutIfNeeded()
        popupVisible = true

        // 1) backdrop 추가 + 제약
        if backdrop.superview == nil {
            host.addSubview(backdrop)
            NSLayoutConstraint.activate([
                backdrop.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                backdrop.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                backdrop.topAnchor.constraint(equalTo: host.topAnchor),
                backdrop.bottomAnchor.constraint(equalTo: host.bottomAnchor)
            ])
            backdrop.alpha = 0
        }

        // 2) popupContainer 설정 + host에 추가
        popupContainer.translatesAutoresizingMaskIntoConstraints = false
        popupContainer.backgroundColor = AppTheme.Color.background
        popupContainer.layer.cornerRadius = popupCornerRadius
        popupContainer.layer.cornerCurve = .continuous
        popupContainer.layer.shadowColor = UIColor.black.cgColor
        popupContainer.layer.shadowOpacity = popupShadowOpacity
        popupContainer.layer.shadowRadius = popupShadowRadius
        popupContainer.layer.shadowOffset = popupShadowOffset
        host.addSubview(popupContainer)

        // 3) tableView 설정 + popupContainer에 추가  ←★ 이것이 먼저 필요!
        tableView.register(PullDownCell.self, forCellReuseIdentifier: "PullDownCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorInset = UIEdgeInsets(top: 0,left: popupCellMargins.leading,bottom: 0,right: popupCellMargins.trailing)
        tableView.separatorColor = separatorColor
        tableView.rowHeight = popupRowHeight
        tableView.estimatedRowHeight = 0
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 0
        tableView.tableHeaderView = UIView(frame: .init(x: 0, y: 0, width: 0, height: 0.01))
        tableView.tableFooterView = UIView(frame: .init(x: 0, y: 0, width: 0, height: 0.01))
        tableView.layer.cornerRadius = popupCornerRadius
        tableView.layer.cornerCurve = .continuous
        tableView.layer.masksToBounds = true
        tableView.backgroundColor = .clear
        popupContainer.addSubview(tableView)

        // 4) 레이아웃 계산
        let buttonFrameInHost = button.convert(button.bounds, to: host)

        /// 넓이 계산
        let targetWidth = popupWidth ?? preferredPopupWidth

        /// 높이 계산
        let visibleRows = max(1, min(popupMaxVisibleRows, items.count))
        let height = CGFloat(visibleRows) * popupRowHeight
        tableView.isScrollEnabled = items.count > visibleRows

        // 아래 공간 부족하면 위로
        let hostHeight = host.bounds.height
        let spaceBelow = hostHeight - buttonFrameInHost.maxY - 6
        let showAbove = spaceBelow < height

        // 5) 제약 추가 (공통 조상 보장된 뒤에!)
        var constraints: [NSLayoutConstraint] = [
            popupContainer.widthAnchor.constraint(equalToConstant: targetWidth),
            popupContainer.heightAnchor.constraint(equalToConstant: height),

            tableView.leadingAnchor.constraint(equalTo: popupContainer.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: popupContainer.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: popupContainer.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: popupContainer.bottomAnchor)
        ]

        if showAbove {
            constraints += [
                popupContainer.bottomAnchor.constraint(equalTo: host.topAnchor, constant: buttonFrameInHost.minY - 6),
                popupContainer.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: buttonFrameInHost.minX)
            ]
        } else {
            constraints += [
                popupContainer.topAnchor.constraint(equalTo: host.topAnchor, constant: buttonFrameInHost.maxY + 6),
                popupContainer.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: buttonFrameInHost.minX)
            ]
        }
        NSLayoutConstraint.activate(constraints)

        // 6) 애니메이션
        popupContainer.alpha = 0
        popupContainer.transform = CGAffineTransform(translationX: 0, y: showAbove ? 4 : -4)
        UIView.animate(withDuration: 0.22) {
            self.backdrop.alpha = 1
            self.popupContainer.alpha = 1
            self.popupContainer.transform = .identity
        }

        // 7) 선택행으로 스크롤
        if let idx = selectedIndex, items.indices.contains(idx) {
            DispatchQueue.main.async {
                self.tableView.scrollToRow(at: IndexPath(row: idx, section: 0), at: .middle, animated: false)
            }
        }
    }
    
    @objc private func dismissPopup() {
        guard popupVisible else { return }
        popupVisible = false
        UIView.animate(withDuration: 0.18, animations: {
            self.backdrop.alpha = 0
            self.popupContainer.alpha = 0
            self.popupContainer.transform = CGAffineTransform(translationX: 0, y: -4)
        }, completion: { _ in
            self.popupContainer.transform = .identity
            self.popupContainer.removeFromSuperview()
            self.backdrop.removeFromSuperview()
        })
    }
    
    

    private func findTopView() -> UIView? {
        if let win = self.window { return win }
        // 키 윈도우 탐색 (iOS 15+)
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let keyWindow = windowScene?.windows.first { $0.isKeyWindow }
        return keyWindow ?? superview
    }

    // MARK: - Title/Selection

    private func applySelection() {
        guard let idx = selectedIndex, items.indices.contains(idx) else { return }
        setTitle(items[idx].title)
        if displayMode == .customPopup { tableView.reloadData() }
    }

    private func setTitle(_ title: String) {
        currentTitle = title
        updateButtonAppearance()
    }

    private func updateButtonAppearance() {
        var cfg = button.configuration ?? .filled()
        
        // 타이틀
        var attrs = AttributeContainer()
        attrs.font = titleFont
        attrs.foregroundColor = titleColor
        cfg.attributedTitle = AttributedString(currentTitle, attributes: attrs)
        cfg.titleAlignment = titleAlignment
        cfg.contentInsets = contentInsets
        cfg.baseForegroundColor = titleColor
        
        // 아이콘: 선택된 Item.systemImage 우선 → 없으면 기본 imageName 사용
        var symbolName: String? = nil
        if let idx = selectedIndex, items.indices.contains(idx) {
            symbolName = items[idx].systemImage ?? imageName
        } else {
            symbolName = imageName
        }
        
        if let name = symbolName,
           let baseImage = UIImage(systemName: name)?.withConfiguration(imageConfig) {
            cfg.image = baseImage
            // 이미지 색을 텍스트와 분리해서 주고 싶다면
            if let ic = imageColor {
                cfg.imageColorTransformer = UIConfigurationColorTransformer { _ in ic }
            } else {
                cfg.imageColorTransformer = nil
            }
            cfg.imagePlacement = imagePlacement
            cfg.imagePadding = imagePadding
        } else {
            cfg.image = nil
        }
        
        button.configuration = cfg
    }
    
    public func select(index: Int?, emit: Bool = false) {
        if let i = index, !(0..<items.count).contains(i) { return }
        selectedIndex = index
        if emit, let i = index {
            onSelect?(i, items[i])
        }
    }
    
    
}

// MARK: - UITableViewDataSource / Delegate

extension AppPullDownField: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PullDownCell", for: indexPath) as! PullDownCell
        let item = items[indexPath.row]
        let checked = (indexPath.row == selectedIndex)

        // 마진/간격
        cell.contentView.directionalLayoutMargins = popupCellMargins
        cell.spacing = contentsSpacing

        // 텍스트 스타일
        cell.titleLabel.text = item.title
        cell.titleLabel.font = titleFont
        cell.titleLabel.textColor = titleColor

        // 체크 표시
        cell.checkView.isHidden = !checked

        // 셀 배경
        cell.backgroundColor = AppTheme.Color.background
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedIndex = indexPath.row
        let item = items[indexPath.row]
        onSelect?(indexPath.row, item)
        dismissPopup()
    }
}


//MARK: - Custom Cell
private final class PullDownCell: UITableViewCell {
    let titleLabel = UILabel()
    let checkView  = UIImageView(image: UIImage(systemName: "checkmark"))

    // 텍스트-체크 사이 간격
    var spacing: CGFloat = 6 {
        didSet { stack.spacing = spacing }
    }

    private let stack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.setContentHuggingPriority(.required, for: .horizontal)
        self.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        selectionStyle = .default
        backgroundColor = .clear
        tintColor = AppTheme.Color.accent

        //Content Hugging Priority
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        checkView.setContentHuggingPriority(.required, for: .horizontal)
        checkView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        checkView.tintColor = AppTheme.Color.accent
        checkView.isHidden = true

        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(checkView)

        contentView.addSubview(stack)
        

        
        let trailing = stack.trailingAnchor.constraint(
            lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor
        )
        trailing.priority = .required
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            trailing,
            stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
