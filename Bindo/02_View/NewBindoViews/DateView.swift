//
//  DateView.swift
//  Bindo
//

import UIKit

// MARK: - 날짜/금액 1행 뷰
final class OccurrenceRowView: UIView {
    // UI
    private let rowStack = UIStackView()
    
    var index: Int? {
        didSet {
            if let i = index {
                // "Next Payday %d"
                occLabel.text = String(
                    format: NSLocalizedString("dateView.nextPayday.index",
                                              comment: "DateView.swift: Next Payday %d"),
                    i
                )
                occLabel.isHidden = false
            } else {
                occLabel.isHidden = true
            }
        }
    }
    
    private let occLabel = AppLabel(
        NSLocalizedString("dateView.nextPayday",
                          comment: "DateView.swift: Next Payday"),
        style: .secondaryBody,
        tone: .main2
    )
    private let nextPicker = AppDatePicker(initial: Date())
    
    // Amount 필드 편집 가능 여부 제어
    var isAmountEditable: Bool = true {
        didSet {
            amountField.isEnabled = isAmountEditable
            // 시각 피드백(비활성화 시 살짝 흐리게)
            amountField.alpha = isAmountEditable ? 1.0 : 0.55
        }
    }
    private let amountLabel = AppLabel(
        NSLocalizedString("dateView.amount", comment: "DateView.swift: Amount"),
        style: .secondaryBody,
        tone: .main2
    )
    private let amountField = AppTextField(placeholder: "")
    private let removeButton: UIButton = {
        var cfg = UIButton.Configuration.plain()
        cfg.baseForegroundColor = AppTheme.Color.accent
        cfg.image = UIImage(systemName: "minus.circle.fill")
        let button = UIButton(configuration: cfg)
        button.setPreferredSymbolConfiguration(.init(pointSize: 16, weight: .semibold), forImageIn: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    private let sep = AppSeparator()

    // 이벤트
    var onRemove: (() -> Void)?
    private let isRemovable: Bool
    var onChange: (() -> Void)?

    // 포맷터 (Decimal 파싱)
    private lazy var decimalFmt: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        return formatter
    }()

    init(removable: Bool = true) {
        self.isRemovable = removable
        super.init(frame: .zero)
        buildUI()
        wireEvents()
    }
    required init?(coder: NSCoder) {
        self.isRemovable = true
        super.init(coder: coder)
        buildUI()
        wireEvents()
    }

    private func buildUI() {
        translatesAutoresizingMaskIntoConstraints = false

        // ── Title Row: [occLabel] --- spacer --- [removeButton]
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 8

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        titleRow.addArrangedSubview(occLabel)
        titleRow.addArrangedSubview(spacer)
        if isRemovable { titleRow.addArrangedSubview(removeButton) }

        // ── Root(rowStack): vertical( titleRow, nextPicker, amountRow )
        rowStack.axis = .vertical
        rowStack.alignment = .fill
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        // TitleRow
        rowStack.addArrangedSubview(titleRow)

        // Next Payday Picker (단독 행)
        rowStack.addArrangedSubview(nextPicker)

        // Amount Row
        let amountRow = UIStackView()
        amountRow.axis = .horizontal
        amountRow.alignment = .center
        amountRow.spacing = 8
        amountRow.addArrangedSubview(amountLabel)
        amountRow.addArrangedSubview(amountField)
        rowStack.addArrangedSubview(amountRow)

        // 우선순위(라벨 고정, 필드 확장, 버튼 고정)
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        amountField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        amountField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addSubview(rowStack)
        addSubview(sep)

        // 기본 표시: index 세팅 전까지 숨김
        occLabel.isHidden = true

        amountField.keyboardType = .decimalPad
        amountField.addDoneToolbar()

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: topAnchor),

            sep.topAnchor.constraint(equalTo: rowStack.bottomAnchor, constant: 8),
            sep.leadingAnchor.constraint(equalTo: leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // picker/버튼 크기 정책
        nextPicker.setContentHuggingPriority(.required, for: .horizontal)
        if isRemovable {
            removeButton.setContentHuggingPriority(.required, for: .horizontal)
            removeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
    }

    private func wireEvents() {
        if isRemovable {
            removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        }
        // 날짜 변경 시 알림
        nextPicker.onChange = { [weak self] _ in
            self?.onChange?()
        }
        // 금액 변경 시 알림
        amountField.addTarget(self, action: #selector(amountEditingChanged), for: .editingChanged)
    }
    @objc private func removeTapped() { onRemove?() }
    @objc private func amountEditingChanged() { onChange?() }

    // 외부 접근자
    var nextDate: Date {
        get { nextPicker.date }
        set { nextPicker.setDate(newValue, animated: false) }
    }
    var amount: Decimal? {
        get {
            guard let t = amountField.text, !t.isEmpty else { return nil }
            if let n = decimalFmt.number(from: t) { return n.decimalValue }
            return Decimal(string: t)
        }
        set {
            if let v = newValue {
                amountField.text = decimalFmt.string(from: v as NSDecimalNumber)
            } else {
                amountField.text = nil
            }
        }
    }

    // 편의: 금액 필드에 포커스
    @discardableResult
    func focusAmount() -> Bool {
        amountField.becomeFirstResponder()
    }
}



// MARK: - DateView
final class DateView: UIView {

    // UI 루트
    private let scrollView = UIScrollView()
    private let root = UIStackView()
    private let bottomBar = UIView()
    private let bottomSeparator = AppSeparator()
    private let bottomStack = UIStackView()
    
    // 섹션: 이름
    private let nameLabel = AppLabel(
        NSLocalizedString("dateView.name", comment: "DateView.swift: Name"),
        style: .secondaryBody,
        tone: .main2
    )
    private let nameField = AppTextField(placeholder: "")
    private let sep1 = AppSeparator()

    // 섹션: Start (단일)
    private let startLabel = AppLabel(
        NSLocalizedString("dateView.startDate", comment: "DateView.swift: Start Date"),
        style: .secondaryBody,
        tone: .main2
    )
    private let startPicker = AppDatePicker(initial: Date())
    private let sepStart = AppSeparator()
    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter
    }()
    
    // 기본 NextPayDay (삭제 불가)
    private let baseRow = OccurrenceRowView(removable: false)

    
    // 체크박스(버튼 스타일) + 라벨
    private let useBaseAmountCheck: UIButton = {
        var cfg = UIButton.Configuration.plain()
        cfg.image = UIImage(systemName: "square") // 기본: 체크 해제
        cfg.imagePadding = 8
        cfg.baseForegroundColor = AppTheme.Color.accent
        let button = UIButton(configuration: cfg)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    private let copyAmountLabel = AppLabel(
        NSLocalizedString("dateView.copyAmount",
                          comment: "DateView.swift: Use base amount for additional paydays"),
        style: .secondaryBody,
        tone: .main2
    )
    private let copyAmountRow = UIStackView()

    // 체크박스 상태
    private var copyAmountEnabled = false

    // 섹션: 발생행 목록 (Next/Amount)
    private let occStack = UIStackView()
    private var occurrenceCount: Int { 1 + rows.count }
    private let addRowButton: UIButton = {
        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = AppTheme.Color.accent.withAlphaComponent(0.12)
        cfg.baseForegroundColor = AppTheme.Color.accent
        cfg.cornerStyle = .capsule

        cfg.attributedTitle = AttributedString(
            NSLocalizedString("dateView.addRow", comment: "DateView.swift: Add row"),
            attributes: AttributeContainer([ .font: AppTheme.Font.secondaryBody ])
        )

        let plusImage = UIImage(systemName: "plus")
        let resized = plusImage?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        )
        cfg.image = resized
        cfg.imagePadding = 6

        let button = UIButton(configuration: cfg)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // 섹션: 요약
    private let summaryBadge = UIView()
    private let summaryLabel = AppLabel(
        NSLocalizedString("dateView.summary", comment: "DateView.swift: Summary"),
        style: .secondaryBody,
        tone: .main2
    )
    private let summaryValue = AppLabel("--", style: .caption, tone: .label)

    
    // 내부 상태
    private var rows: [OccurrenceRowView] = []


    // interval 산출 (월 차가 있으면 months, 아니면 days)
    private static func deriveInterval(start: Date, next: Date) -> Interval {
        let cal = Calendar.current
        let s = cal.startOfDay(for: start)
        let n = cal.startOfDay(for: next)
        let cmps = cal.dateComponents([.month, .day], from: s, to: n)
        if let m = cmps.month, m > 0 { return .months(m) }
        let d = cmps.day ?? 0
        return .days(max(1, d))
    }

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
        wireEvents()
        preloadFirstOccurrence()
        baseRow.index = 1
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
        wireEvents()
        preloadFirstOccurrence()
        baseRow.index = 1
    }

    // MARK: - UI 구성
    private func buildUI() {
        backgroundColor = .clear

        // 1) 뷰 계층
        addSubview(scrollView)
        addSubview(bottomBar)
        bottomBar.addSubview(bottomSeparator)
        bottomBar.addSubview(bottomStack)
        summaryBadge.addSubview(summaryLabel)
        bottomStack.addArrangedSubview(summaryBadge)
        bottomStack.addArrangedSubview(summaryValue)
        scrollView.addSubview(root)

        // 2) 기본 스타일
        [scrollView, bottomBar, bottomSeparator, bottomStack, summaryBadge, summaryLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        scrollView.alwaysBounceVertical = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive

        bottomStack.axis = .vertical
        bottomStack.alignment = .center
        bottomStack.spacing = 8

        summaryBadge.setContentHuggingPriority(.required, for: .horizontal)
        summaryBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        summaryBadge.backgroundColor = AppTheme.Color.main3.withAlphaComponent(0.15)
        summaryBadge.layer.cornerRadius = AppTheme.Corner.l
        summaryBadge.layer.cornerCurve = .continuous

        summaryLabel.setContentHuggingPriority(.required, for: .horizontal)
        summaryLabel.textAlignment = .center
        
        summaryValue.setContentHuggingPriority(.defaultLow, for: .horizontal)
        summaryValue.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        root.translatesAutoresizingMaskIntoConstraints = false
        root.axis = .vertical
        root.spacing = 12
        
        // 3) 제약
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor)
        ])
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            bottomBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])
        bottomBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        
        NSLayoutConstraint.activate([
            summaryLabel.leadingAnchor.constraint(equalTo: summaryBadge.leadingAnchor, constant: 8),
            summaryLabel.trailingAnchor.constraint(equalTo: summaryBadge.trailingAnchor, constant: -8),
            summaryLabel.topAnchor.constraint(equalTo: summaryBadge.topAnchor, constant: 2),
            summaryLabel.bottomAnchor.constraint(equalTo: summaryBadge.bottomAnchor, constant: -2)
        ])
        NSLayoutConstraint.activate([
            bottomSeparator.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            bottomSeparator.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            bottomSeparator.topAnchor.constraint(equalTo: bottomBar.topAnchor),

            bottomStack.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 6),
            bottomStack.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -6),
            bottomStack.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 10),
            bottomStack.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor, constant: -6)
        ])
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            root.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            root.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        
        // 4) 배치
        root.addArrangedSubview(nameLabel)
        root.addArrangedSubview(nameField)
        root.addArrangedSubview(sep1)

        root.addArrangedSubview(startLabel)
        root.addArrangedSubview(startPicker)
        root.addArrangedSubview(sepStart)
        
        root.addArrangedSubview(baseRow)
        
        copyAmountRow.axis = .horizontal
        copyAmountRow.alignment = .center
        copyAmountRow.spacing = 8
        copyAmountRow.translatesAutoresizingMaskIntoConstraints = false
        copyAmountRow.addArrangedSubview(useBaseAmountCheck)
        copyAmountRow.addArrangedSubview(copyAmountLabel)
        root.addArrangedSubview(copyAmountRow)

        occStack.axis = .vertical
        occStack.spacing = 8
        root.addArrangedSubview(occStack)

        root.addArrangedSubview(addRowButton)
        
        nameField.addDoneToolbar()
    }

    private func wireEvents() {
        addRowButton.addTarget(self, action: #selector(addRowTapped), for: .touchUpInside)
        startPicker.onChange = { [weak self] _ in
            self?.updateSummary()
        }

        baseRow.onChange = { [weak self] in
            guard let self else { return }
            self.updateSummary()
            if self.copyAmountEnabled, let base = self.baseRow.amount {
                self.rows.forEach { row in
                    if row.isAmountEditable == false { row.amount = base }
                }
            }
        }

        // 체크박스 토글
        useBaseAmountCheck.addAction(UIAction { [weak self] _ in
            self?.toggleCopyAmount()
        }, for: .touchUpInside)
    }

    @objc private func addRowTapped() {
        // 메시지: 날짜 먼저 입력 요청
        let start = startPicker.date
        let baseNext = baseRow.nextDate
        guard baseNext > start else {
            self.shake()
            endAfterStartAlert()
            return
        }
        // 메시지: 금액 입력 요청
        if copyAmountEnabled {
            if baseRow.amount == nil || (baseRow.amount ?? 0) <= 0 {
                self.shake()
                showBaseRowRequiredAlert()
                _ = baseRow.focusAmount()
                return
            }
        }
        addRow()
    }
    
    private func toggleCopyAmount() {
        let turningOn = !copyAmountEnabled

        // ON 전환 시: base amount가 없으면 알럿 + 체크박스 원복
        if turningOn {
            let base = baseRow.amount ?? 0
            if base <= 0 {
                self.shake()
                showBaseAmountMissingAlert()
                copyAmountEnabled = false
                updateCopyAmountCheckboxIcon()
                return
            }
        }
        if turningOn, !rows.isEmpty {
            // 덮어쓰기 확인
            showOverwriteAmountsAlert { [weak self] confirmed in
                guard let self else { return }
                if confirmed {
                    self.copyAmountEnabled = true
                    self.updateCopyAmountCheckboxIcon()
                    self.applyCopyAmountToRows()
                } else {
                    // 사용자가 취소 → 다시 false로 회귀
                    self.copyAmountEnabled = false
                    self.updateCopyAmountCheckboxIcon()
                }
            }
        } else {
            // 단순 토글
            copyAmountEnabled.toggle()
            updateCopyAmountCheckboxIcon()

            if copyAmountEnabled {
                applyCopyAmountToRows()  // 현재 행들에 즉시 반영
            } else {
                // OFF → 모두 편집 가능
                rows.forEach { $0.isAmountEditable = true }
            }
        }
    }
    
    private func updateCopyAmountCheckboxIcon() {
        var cfg = useBaseAmountCheck.configuration ?? .plain()
        cfg.image = UIImage(systemName: copyAmountEnabled ? "checkmark.square.fill" : "square")
        useBaseAmountCheck.configuration = cfg
        copyAmountLabel.alpha = copyAmountEnabled ? 1.0 : 0.7
    }
    
    private func applyCopyAmountToRows() {
        guard copyAmountEnabled else { return }
        guard let base = baseRow.amount, base > 0 else {
            // 베이스 금액이 없으면 잠그지 않음
            rows.forEach { $0.isAmountEditable = true }
            return
        }
        rows.forEach { row in
            row.amount = base
            row.isAmountEditable = false
        }
    }

    private func preloadFirstOccurrence() {
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: startPicker.date) {
            baseRow.nextDate = next
        }
        updateSummary()
    }

    // 추가/삭제/변경
    @discardableResult
    private func addRow() -> OccurrenceRowView {
        let row = OccurrenceRowView(removable: true)
        row.index = rows.count + 2
        
        row.onChange = { [weak self] in self?.updateSummary() }
        row.onRemove = { [weak self, weak row] in
            guard let self, let row else { return }
            self.removeRow(row)
        }
        
        if copyAmountEnabled, let base = baseRow.amount {
            row.amount = base
            row.isAmountEditable = false
        } else {
            row.isAmountEditable = true
        }
        
        occStack.addArrangedSubview(row)
        rows.append(row)
        updateSummary()
        return row
    }

    private func removeRow(_ row: OccurrenceRowView) {
        if let idx = rows.firstIndex(where: { $0 === row }) {
            rows.remove(at: idx)

            UIView.animate(withDuration: 0.15, animations: {
                row.isHidden = true
                row.alpha = 0.0
                self.layoutIfNeeded()
            }, completion: { _ in
                row.removeFromSuperview()

                // 인덱스 갱신
                for (i, row) in self.rows.enumerated() {
                    row.index = i + 2
                }
                self.updateSummary()
            })
        }
    }

    private func updateSummary() {
        let count = occurrenceCount
        let start = startPicker.date
        let lastNext = ([baseRow.nextDate] + rows.map { $0.nextDate }).max()
        let df = DateView.dateFormatter
        
        var parts: [String] = []
        parts.append(
            String(format: NSLocalizedString("dateView.summary.paydays",
                                             comment: "DateView.swift: Payday(s): %d"),
                   count)
        )
        parts.append(
            String(format: NSLocalizedString("dateView.summary.start",
                                             comment: "DateView.swift: Start: %@"),
                   df.string(from: start))
        )
        if let e = lastNext {
            parts.append(
                String(format: NSLocalizedString("dateView.summary.end",
                                                 comment: "DateView.swift: End: %@"),
                       df.string(from: e))
            )
        }

        summaryValue.text = parts.joined(separator: "  /  ")
    }
    
    @discardableResult
    private func presentInfo(_ title: String, _ message: String) -> AppAlertController? {
        AppAlert.info(from: self, title: title, message: message)
    }

    private func showBaseAmountMissingAlert() {
        presentInfo(
            NSLocalizedString("dateView.alert.required.title",
                              comment: "DateView.swift: Required"),
            NSLocalizedString("dateView.alert.baseMissing",
                              comment: "DateView.swift: Please enter Amount first.")
        )
    }

    private func showBaseRowRequiredAlert() {
        presentInfo(
            NSLocalizedString("dateView.alert.required.title",
                              comment: "DateView.swift: Required"),
            NSLocalizedString("dateView.alert.amountRequired",
                              comment: "DateView.swift: Please enter the Amount.")
        )
    }

    private func endAfterStartAlert() {
        presentInfo(
            NSLocalizedString("dateView.alert.confirm.title",
                              comment: "DateView.swift: Confirm"),
            NSLocalizedString("dateView.alert.endAfterStart",
                              comment: "DateView.swift: End Date must be after the start date.")
        )
    }

    private func showOverwriteAmountsAlert(_ completion: @escaping (Bool) -> Void) {
        var cfg = AppAlertConfiguration()
        cfg.borderColor = AppTheme.Color.main3
        cfg.icon = UIImage(systemName: "exclamationmark.triangle.fill")

        AppAlert.present(from: self,
                         title: NSLocalizedString("dateView.alert.overwrite.title",
                                                  comment: "DateView.swift: Confirm"),
                         message: NSLocalizedString("dateView.alert.overwrite.message",
                                                    comment: "DateView.swift: Do you want to overwrite all paydays amount with base amount?"),
                         actions: [
                            .init(title: NSLocalizedString("button.cancel",
                                                           comment: "DateView.swift: Cancel"),
                                  style: .cancel) { completion(false) },
                            .init(title: NSLocalizedString("button.ok",
                                                           comment: "DateView.swift: OK"),
                                  style: .primary) { completion(true) }
                         ],
                         configuration: cfg)
    }
    

    // 상위 VC 탐색
    private var parentViewController: UIViewController? {
        sequence(first: self.next as UIResponder?, next: { $0?.next })
            .first { $0 is UIViewController } as? UIViewController
    }
}


// MARK: - BindoForm
extension DateView: BindoForm {
    var optionName: String { "date" } // 데이터 구분자(현지화 X)

    func buildModel() throws -> BindoList {
        // 1) 공통 입력
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else {
            throw BindoFormError.missingField(
                NSLocalizedString("dateView.field.name",
                                  comment: "DateView.swift: Name")
            )
        }

        let start = startPicker.date

        // 2) 기본 행(삭제 불가) 수집 + 검증
        let baseNext = baseRow.nextDate
        try validateStart(start, before: baseNext)

        // 3) 추가 행 수집 (원본 순서로: 날짜/금액 쌍)
        var pairs: [(date: Date, amount: Decimal?)] = []
        pairs.append((date: baseNext, amount: baseRow.amount)) // baseRow 먼저
        for row in rows {
            let next = row.nextDate
            try validateStart(start, before: next)
            pairs.append((date: next, amount: row.amount))
        }

        // 4) 정렬 + 중복 제거(가장 이른 날짜부터)
        pairs.sort { $0.date < $1.date }
        var dedup: [(date: Date, amount: Decimal?)] = []
        var seen = Set<Date>()
        for p in pairs {
            let day = Calendar.current.startOfDay(for: p.date)
            if seen.insert(day).inserted {
                dedup.append((date: day, amount: p.amount))
            }
        }

        // 5) useBase 스위치 처리
        let useBase = copyAmountEnabled
        var baseAmount: Decimal? = nil
        if useBase {
            // 켜려면 baseRow.amount가 필수
            baseAmount = try requireAmount(
                baseRow.amount,
                fieldName: NSLocalizedString("dateView.field.amount",
                                             comment: "DateView.swift: Amount")
            )
        }

        // 6) Occurrence 체인 생성
        var occurrences: [OccurrenceList] = []
        var curStart = Calendar.current.startOfDay(for: start)

        for (date, amtOpt) in dedup {
            // payAmount 결정
            let pay: Decimal
            if useBase {
                pay = baseAmount! // 위에서 검증 완료
            } else {
                pay = try requireAmount(
                    amtOpt,
                    fieldName: NSLocalizedString("dateView.field.amountInRows",
                                                 comment: "DateView.swift: Amount in rows")
                )
            }
            // start < end 재검증(보수)
            try validateStart(curStart, before: date)

            let occ = OccurrenceList(
                id: UUID(),
                startDate: curStart,
                endDate: date,
                payAmount: pay
            )
            occurrences.append(occ)
            curStart = date // 다음 구간의 시작 = 이번 end
        }

        // 7) endAt = 마지막 endDate (없을 수도)
        let endAt = occurrences.last?.endDate

        // 8) 모델 구성 (DateView는 interval을 쓰지 않으므로 nil)
        return BindoList(
            id: UUID(),
            name: name,
            useBase: useBase,
            baseAmount: useBase ? baseAmount : nil,
            createdAt: Date(),
            updatedAt: Date(),
            endAt: endAt,
            option: optionName,        // "date"
            interval: nil,             // 규칙 없음 (개별 발생)
            occurrences: occurrences   // 최소 1개
        )
    }

    struct RowSig: Hashable {
        let ymd: Int
        let amount: String
        let editable: Bool
    }

    struct DateDirtySnapshopt: Hashable {
        let name: String
        let startYMD: Int
        let baseNextYMD: Int
        let baseAmount: String
        let rows: [RowSig]
    }

    func dirtySignature() -> AnyHashable {
        let cal = Calendar.current
        let ymd: (Date) -> Int = { Int(cal.startOfDay(for: $0).timeIntervalSince1970 / 86_400) }

        let baseAmtSig = baseRow.amount.map { "\($0)" } ?? ""

        let rowSigs: [RowSig] = rows.map {
            RowSig(
                ymd: ymd($0.nextDate),
                amount: $0.amount.map { "\($0)" } ?? "",
                editable: $0.isAmountEditable
            )
        }

        return AnyHashable(DateDirtySnapshopt(
            name: (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            startYMD: ymd(startPicker.date),
            baseNextYMD: ymd(baseRow.nextDate),
            baseAmount: baseAmtSig,
            rows: rowSigs
        ))
    }

    func reset() {
        // (기존 그대로)
        nameField.text = ""
        startPicker.setDate(Date(), animated: false)

        if let next = Calendar.current.date(byAdding: .month, value: 1, to: startPicker.date) {
            baseRow.nextDate = next
        } else {
            baseRow.nextDate = startPicker.date
        }
        baseRow.amount = nil

        rows.forEach { $0.removeFromSuperview() }
        rows.removeAll()

        copyAmountEnabled = false
        updateCopyAmountCheckboxIcon()

        updateSummary()
        setNeedsLayout()
        layoutIfNeeded()
    }
}

//MARK: - Update Bindo
extension DateView {
    func apply(_ m: BindoList) {
        nameField.text = m.name
        startPicker.setDate(m.occurrences.first?.startDate ?? Date(), animated: false)

        copyAmountEnabled = m.useBase
        updateCopyAmountCheckboxIcon()

        // occurrence 채우기
        rows.forEach { $0.removeFromSuperview() }
        rows.removeAll()

        let sorted = m.occurrences.sorted(by: { $0.startDate < $1.startDate })
        if let first = sorted.first {
            baseRow.nextDate = first.endDate
            if m.useBase {
                baseRow.amount = m.baseAmount
            } else {
                baseRow.amount = first.payAmount
            }
        }

        for (i, occ) in sorted.dropFirst().enumerated() {
            let row = addRow()
            row.index = i + 2
            row.nextDate = occ.endDate
            if m.useBase {
                row.amount = m.baseAmount
                row.isAmountEditable = false
            } else {
                row.amount = occ.payAmount
                row.isAmountEditable = true
            }
        }

        updateSummary()
    }
}
