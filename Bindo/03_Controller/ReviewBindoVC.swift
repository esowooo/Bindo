//
//  ReviewBindoVC.swift
//  Bindo
//
//  Created by Sean Choi on 2025/09/17.
//

import UIKit
import CoreData

/// 리뷰 + 편집 진입 전용 화면
/// - 현재 값은 읽기 전용으로 표시
/// - 우상단 Edit 탭 → NewBindoVC(editingID 세팅)로 푸시하여 편집
/// - Save 버튼은 이 VC에서는 항상 비활성(편집 상태 아님)
final class ReviewBindoVC: BaseVC {

    // MARK: - Input
    /// 편집/리뷰 대상 Bindo ID (필수)
    var bindoID: UUID!

    // MARK: - Deps
    var repo: (BindoRepository & RefreshRepository)?

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let content = UIStackView()

    // 공통 섹션
    private let nameLabel   = AppLabel(NSLocalizedString("review.name",         comment: "ReviewBindoVC.swift: Name"),         style: .secondaryBody, tone: .main2)
    private let nameValue   = AppLabel("--", style: .body, tone: .label)

    private let createdLabel = AppLabel(NSLocalizedString("review.createdDate", comment: "ReviewBindoVC.swift: Created Date"), style: .secondaryBody, tone: .main2)
    private let createdValue = AppLabel("--", style: .body, tone: .label)
    
    private let startLabel  = AppLabel(NSLocalizedString("review.startDate",    comment: "ReviewBindoVC.swift: Start Date"),   style: .secondaryBody, tone: .main2)
    private let startValue  = AppLabel("--", style: .body, tone: .label)

    private let endLabel    = AppLabel(NSLocalizedString("review.endDate",      comment: "ReviewBindoVC.swift: End Date"),     style: .secondaryBody, tone: .main2)
    private let endValue    = AppLabel("--", style: .body, tone: .label)

    private let optionLabel = AppLabel(NSLocalizedString("review.option",       comment: "ReviewBindoVC.swift: Option"),       style: .secondaryBody, tone: .main2)
    private let optionValue = AppLabel("--", style: .body, tone: .label)

    private let sep1 = AppSeparator()
    private let sep2 = AppSeparator()
    private let sep3 = AppSeparator()
    private let sep4 = AppSeparator()
    private let sep5 = AppSeparator()

    // Occurrence 리스트
    private let occBadge = UIView()
    private let occTitle = AppLabel(NSLocalizedString("review.paymentHistory", comment: "ReviewBindoVC.swift: Payment History"), style: .secondaryBody, tone: .main1)
    private let occStack = UIStackView()

    // 컬럼 레이아웃 상수 (필요시 조절)
    private let indexColWidth: CGFloat = 30
    private let columnGap: CGFloat = 30
    private lazy var dateColWidth: CGFloat = {
        measureText(NSLocalizedString("review.col.paymentDate", comment: "ReviewBindoVC.swift: Payment Date column header"),
                    font: AppTheme.Font.body)
    }()

    private func measureText(_ text: String, font: UIFont) -> CGFloat {
        let size = (text as NSString).size(withAttributes: [.font: font])
        return ceil(size.width) + 4
    }
    
    // 빈 상태
    private let emptyOccLabel = AppLabel(NSLocalizedString("review.noPayments", comment: "ReviewBindoVC.swift: No saved payments."),
                                         style: .caption, tone: .main3)

    // 포맷터 (숫자 고정 포맷 유지)
    private lazy var df: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()
    private lazy var nf: NumberFormatter = {
        let n = NumberFormatter()
        n.locale = Locale(identifier: "en_US_POSIX")
        n.numberStyle = .decimal
        n.usesGroupingSeparator = false
        n.minimumFractionDigits = 0
        n.maximumFractionDigits = 2
        return n
    }()

    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        precondition(bindoID != nil, "bindoID must be set before presenting ReviewBindoVC")

        applyAppearance()
        buildUI()
        loadAndRender()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.backgroundColor = AppTheme.Color.background
    }

    // MARK: - Nav / Appearance
    private func applyAppearance() {
        AppNavigation.apply(to: navigationController)

        let backItem = AppNavigation.BarItem(
            systemImage: "chevron.backward",
            accessibilityLabel: NSLocalizedString("button.back", comment: "ReviewBindoVC.swift: Back"),
            action: UIAction { [weak self] _ in self?.cancelTapped() }
        )
        let left = AppNavigation.makeButton(backItem, style: .plainAccent)

        // Edit버튼
        let editItem = AppNavigation.BarItem(
            systemImage: "square.and.pencil",
            accessibilityLabel: NSLocalizedString("button.edit", comment: "ReviewBindoVC.swift: Edit"),
            action: UIAction { [weak self] _ in self?.editTapped() }
        )
        let editBtn = AppNavigation.makeButton(editItem, style: .plainAccent)

        AppNavigation.setItems(left: [left], right: [editBtn], for: self)

        // 타이틀
        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("review.title", comment: "ReviewBindoVC.swift: Review title")
        titleLabel.font = AppTheme.Font.body
        titleLabel.textColor = AppTheme.Color.label
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = .clear
        navigationItem.titleView = titleLabel
    }

    private func buildUI() {
        // 스크롤/스택 기본
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 12

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        // 공통 필드 + 구분선
        content.addArrangedSubview(nameLabel)
        content.addArrangedSubview(nameValue)
        content.addArrangedSubview(sep1)

        content.addArrangedSubview(createdLabel)
        content.addArrangedSubview(createdValue)
        content.addArrangedSubview(sep2)
        
        content.addArrangedSubview(startLabel)
        content.addArrangedSubview(startValue)
        content.addArrangedSubview(sep3)

        content.addArrangedSubview(endLabel)
        content.addArrangedSubview(endValue)
        content.addArrangedSubview(sep4)

        content.addArrangedSubview(optionLabel)
        content.addArrangedSubview(optionValue)
        content.addArrangedSubview(sep5)

        // ── Payment History 배지
        occBadge.backgroundColor = AppTheme.Color.main3.withAlphaComponent(0.15)
        occBadge.layer.cornerRadius = AppTheme.Corner.l
        occBadge.layer.cornerCurve = .continuous
        occBadge.translatesAutoresizingMaskIntoConstraints = false

        occTitle.translatesAutoresizingMaskIntoConstraints = false
        occBadge.addSubview(occTitle)

        NSLayoutConstraint.activate([
            occTitle.centerXAnchor.constraint(equalTo: occBadge.centerXAnchor),
            occTitle.topAnchor.constraint(equalTo: occBadge.topAnchor, constant: 6),
            occTitle.bottomAnchor.constraint(equalTo: occBadge.bottomAnchor, constant: -6),
            occTitle.leadingAnchor.constraint(equalTo: occBadge.leadingAnchor, constant: 20),
            occTitle.trailingAnchor.constraint(equalTo: occBadge.trailingAnchor, constant: -20)
        ])
        
        // 배지 홀더(가운데 정렬용)
        let badgeHolder = UIView()
        badgeHolder.translatesAutoresizingMaskIntoConstraints = false
        badgeHolder.addSubview(occBadge)
        NSLayoutConstraint.activate([
            occBadge.centerXAnchor.constraint(equalTo: badgeHolder.centerXAnchor),
            occBadge.topAnchor.constraint(equalTo: badgeHolder.topAnchor),
            occBadge.bottomAnchor.constraint(equalTo: badgeHolder.bottomAnchor)
        ])
        content.addArrangedSubview(badgeHolder)
        
        // ── Payment History 리스트
        occStack.axis = .vertical
        occStack.spacing = 8
        content.addArrangedSubview(occStack)
    }

    // MARK: - Data
    private func loadAndRender() {
        let repo = self.repo ?? CoreDataBindoRepository()
        do {
            guard let bindo = try repo.fetch(id: bindoID) else {
                AppAlert.info(on: self,
                              title: NSLocalizedString("review.notFound", comment: "ReviewBindoVC.swift: Not Found"),
                              message: NSLocalizedString("review.missing",  comment: "ReviewBindoVC.swift: The item is missing."))
                return
            }
            render(bindo)
        } catch {
            AppAlert.info(on: self,
                          title: NSLocalizedString("error.title", comment: "ReviewBindoVC.swift: Error"),
                          message: error.localizedDescription)
        }
    }

    private func render(_ b: BindoList) {
        // 공통
        nameValue.text = b.name
        createdValue.text = df.string(from: b.createdAt)
        if let firstStart = b.occurrences.sorted(by: { $0.startDate < $1.startDate }).first?.startDate {
            startValue.text = df.string(from: firstStart)
        } else {
            startValue.text = "—"
        }
        endValue.text = b.endAt.map(df.string(from:)) ?? "—"
        optionValue.text = b.option.capitalized

        // Occurrence 렌더
        while let v = occStack.arrangedSubviews.first {
            occStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        let occurrences = b.occurrences.sorted { $0.endDate < $1.endDate }
        if occurrences.isEmpty {
            occStack.addArrangedSubview(emptyOccLabel)
        } else {
            // 헤더
            occStack.addArrangedSubview(makeOccurrenceHeader())
            // 행들
            for (i, occ) in occurrences.enumerated() {
                occStack.addArrangedSubview(makeOccurrenceRow(occ, index: i + 1))
            }
        }
    }

    // MARK: - Helpers
    private func makeOccurrenceHeader() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let idxH    = AppLabel(NSLocalizedString("review.col.no",          comment: "ReviewBindoVC.swift: No."),           style: .secondaryBody, tone: .main2)
        let dateH   = AppLabel(NSLocalizedString("review.col.paymentDate", comment: "ReviewBindoVC.swift: Payment Date"),  style: .secondaryBody, tone: .main2)
        let amountH = AppLabel(NSLocalizedString("review.col.amount",      comment: "ReviewBindoVC.swift: Amount"),        style: .secondaryBody, tone: .main2)

        [idxH, dateH, amountH].forEach {
            $0.numberOfLines = 1
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }

        NSLayoutConstraint.activate([
            // 인덱스 헤더
            idxH.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            idxH.topAnchor.constraint(equalTo: container.topAnchor),
            idxH.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            idxH.widthAnchor.constraint(equalToConstant: indexColWidth),

            // 날짜 헤더: 인덱스 뒤 + 간격
            dateH.leadingAnchor.constraint(equalTo: idxH.trailingAnchor, constant: columnGap),
            dateH.topAnchor.constraint(equalTo: container.topAnchor),
            dateH.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            dateH.widthAnchor.constraint(equalToConstant: dateColWidth),

            // 금액 헤더: 날짜 컬럼 뒤 + 간격
            amountH.leadingAnchor.constraint(equalTo: dateH.trailingAnchor, constant: columnGap),
            amountH.topAnchor.constraint(equalTo: container.topAnchor),
            amountH.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            amountH.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])

        [idxH, dateH, amountH].forEach {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        return container
    }
    
    private func makeOccurrenceRow(_ occ: OccurrenceList, index: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let idx = AppLabel("\(index)", style: .body, tone: .label)
        let dateValue = AppLabel(df.string(from: occ.endDate), style: .body, tone: .label)

        let amtCore = nf.string(from: occ.payAmount as NSDecimalNumber) ?? "\(occ.payAmount)"
        let sym = SettingsStore.shared.ccySymbol
        let amtValue = AppLabel(sym.isEmpty ? amtCore : "\(sym)\(amtCore)", style: .body, tone: .label)

        [idx, dateValue, amtValue].forEach {
            $0.numberOfLines = 1
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }

        NSLayoutConstraint.activate([
            // 인덱스
            idx.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            idx.topAnchor.constraint(equalTo: container.topAnchor),
            idx.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            idx.widthAnchor.constraint(equalToConstant: indexColWidth),

            // 날짜 값
            dateValue.leadingAnchor.constraint(equalTo: idx.trailingAnchor, constant: columnGap),
            dateValue.topAnchor.constraint(equalTo: container.topAnchor),
            dateValue.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            dateValue.widthAnchor.constraint(equalToConstant: dateColWidth),

            // 금액 값
            amtValue.leadingAnchor.constraint(equalTo: dateValue.trailingAnchor, constant: columnGap),
            amtValue.topAnchor.constraint(equalTo: container.topAnchor),
            amtValue.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            amtValue.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])

        [idx, dateValue, amtValue].forEach {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        return container
    }

    // MARK: - Actions
    @objc private func cancelTapped() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    /// 편집 진입: NewBindoVC를 편집 모드로 푸시 (editingID 전달)
    @objc private func editTapped() {
        let sb = UIStoryboard(name: "Main", bundle: nil) // 스토리보드 사용 중이면 ID 연결 필요
        guard let vc = sb.instantiateViewController(withIdentifier: "NewBindoVC") as? NewBindoVC else {
            assertionFailure("Storyboard doesn't have VC with ID 'NewBindoVC'")
            return
        }
        vc.editingID = bindoID
        vc.repo = self.repo   // 주입
        navigationController?.pushViewController(vc, animated: true)
    }
}
