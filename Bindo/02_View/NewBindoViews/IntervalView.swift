//
//  IntervalView.swift
//  Bindo
//
//  Created by Sean Choi on 9/9/25.
//
import UIKit


// MARK: - IntervalView (Default Form)
final class IntervalView: UIView {
    
    // 중복 빌드 방지(선택)
    private var didBuildUI = false
    // Root Stack
    private let root = UIStackView()
    // Scroll View
    private let scrollView = UIScrollView()
    // Bottom View
    private let bottomBar = UIView()
    private let bottomSeparator = AppSeparator()
    private let bottomStack = UIStackView()
    private let summaryBadge = UIView()
    private let summaryLabel = AppLabel(
        NSLocalizedString("intervalView.summary.title", comment: "IntervalView.swift: Summary"),
        style: .secondaryBody,
        tone: .main2
    )
    private let summaryValue = AppLabel(
        NSLocalizedString("intervalView.summary.nextDash", comment: "IntervalView.swift: Next Payday: --"),
        style: .caption,
        tone: .label
    )
    
    
    // MARK: - UI 구성요소
    private let nameLabel   = AppLabel(
        NSLocalizedString("intervalView.name", comment: "IntervalView.swift: Name"),
        style: .secondaryBody,
        tone: .main2
    )
    private let nameField   = AppTextField(placeholder: "", kind: .standard)
    
    private let amountLabel = AppLabel(
        NSLocalizedString("intervalView.amount", comment: "IntervalView.swift: Amount"),
        style: .secondaryBody,
        tone: .main2
    )
    private let amountField = AppTextField(placeholder: "", kind: .numeric)
    
    private let startLabel  = AppLabel(
        NSLocalizedString("intervalView.startDate", comment: "IntervalView.swift: Start Date"),
        style: .secondaryBody,
        tone: .main2
    )
    private let startPicker = AppDatePicker(initial: Date())
    
    private let intervalLabel = AppLabel(
        NSLocalizedString("intervalView.interval", comment: "IntervalView.swift: Interval"),
        style: .secondaryBody,
        tone: .main2
    )
    private let intervalValuePD  = AppPullDownField(placeholder:
        NSLocalizedString("intervalView.value.placeholder", comment: "IntervalView.swift: Value")
    )
    private let intervalUnitPD   = AppPullDownField(placeholder:
        NSLocalizedString("intervalView.unit.placeholder", comment: "IntervalView.swift: Unit")
    )
    
    private let endSwitchRow = UIStackView()
    private let endTitle     = AppLabel(
        NSLocalizedString("intervalView.endDateOptional", comment: "IntervalView.swift: End Date (Optional)"),
        style: .secondaryBody,
        tone: .main2
    )
    private let endToggleButton    = UIButton(type: .system)
    private let endPicker    = AppDatePicker(initial: Date())
    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()
    // Start 섹션 오른쪽 체크박스 + 라벨
    private let includeRow   = UIStackView()
    private let includeBtn   = UIButton(type: .system)
    private let includeLabel = AppLabel(
        NSLocalizedString("intervalView.includeToday", comment: "IntervalView.swift: Include as Payday"),
        style: .secondaryBody,
        tone: .main2
    )
    private let intervalPrefix = AppLabel(
        NSLocalizedString("intervalView.onceIn", comment: "IntervalView.swift: Once in"),
        style: .body,
        tone: .label
    )
    
    // 구분선
    private let sep1 = AppSeparator()
    private let sep2 = AppSeparator()
    private let sep3 = AppSeparator()
    private let sep4 = AppSeparator()
    
    // 내부 상태
    private var intervalValue: Int = 1
    private var intervalUnit: IntervalUnit = .months
    private var unitWidthC: NSLayoutConstraint?
    private var valueWidthC: NSLayoutConstraint?
    private var includeTodayAsPayday: Bool = false
    
    // IntervalUnit: 내부 표현 (week/year도 지원 → days/months로 매핑)
    private enum IntervalUnit: Int, CaseIterable {
        case days, weeks, months, years
        
        var title: String {
            switch self {
            case .days:
                return NSLocalizedString("intervalView.unit.days", comment: "IntervalView.swift: Day(s)")
            case .weeks:
                return NSLocalizedString("intervalView.unit.weeks", comment: "IntervalView.swift: Week(s)")
            case .months:
                return NSLocalizedString("intervalView.unit.months", comment: "IntervalView.swift: Month(s)")
            case .years:
                return NSLocalizedString("intervalView.unit.years", comment: "IntervalView.swift: Year(s)")
            }
        }
    }
    
    @discardableResult
    private func presentInfo(_ title: String, _ message: String) -> AppAlertController? {
        AppAlert.info(from: self, title: title, message: message)
    }
    
    
    // MARK: - 초기화
    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
        stylePullDowns()
        configureIntervalPickers()
        wireEvents()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
        stylePullDowns()
        configureIntervalPickers()
        wireEvents()
    }
    
    
    // MARK: - UI 빌드
    private func buildUI() {
        if didBuildUI { return }
        didBuildUI = true
        
        backgroundColor = .clear
        // includeRow(체크박스 + 텍스트)
        includeRow.axis = .horizontal
        includeRow.alignment = .center
        includeRow.spacing = 6

        var cbCfg = UIButton.Configuration.plain()
        cbCfg.contentInsets = .zero
        cbCfg.image = UIImage(systemName: "square")
        cbCfg.baseForegroundColor = .systemGray2
        includeBtn.configuration = cbCfg
        includeBtn.setPreferredSymbolConfiguration(.init(pointSize: 14, weight: .semibold),
                                                   forImageIn: .normal)
        includeLabel.textColor = .systemGray2
        
        let startHeaderRow = UIStackView()
        let startSpacer = UIView()
        
        // ─────────────────────────────────────
        // 1) 뷰 계층 설정
        // ─────────────────────────────────────
        addSubview(scrollView)
        addSubview(bottomBar)
        
        bottomBar.addSubview(bottomSeparator)
        bottomBar.addSubview(bottomStack)
        
        // 배지 내부 라벨
        summaryBadge.addSubview(summaryLabel)
        
        // Interval 행(값/단위)
        let intervalRow = UIStackView()
        intervalRow.addArrangedSubview(intervalPrefix)
        intervalRow.addArrangedSubview(intervalValuePD)
        intervalRow.addArrangedSubview(intervalUnitPD)

        let intervalTailSpacer = UIView()
        intervalRow.addArrangedSubview(intervalTailSpacer)

        
        // End 스위치 행 (오른쪽 끝 토글)
        let endSpacer = UIView()
        endSwitchRow.addArrangedSubview(endTitle)
        endSwitchRow.addArrangedSubview(endSpacer)
        endSwitchRow.addArrangedSubview(endToggleButton)
        
        // 스크롤 콘텐츠 루트
        scrollView.addSubview(root)
        
        // includeRow 구성요소 부착
        includeRow.addArrangedSubview(includeBtn)
        includeRow.addArrangedSubview(includeLabel)

        // 헤더 조립
        startHeaderRow.addArrangedSubview(startLabel)
        startHeaderRow.addArrangedSubview(startSpacer)
        startHeaderRow.addArrangedSubview(includeRow)
        
        // ─────────────────────────────────────
        // 2) 기본 스타일 적용
        // ─────────────────────────────────────
        
        translatesAutoresizingMaskIntoConstraints = false
        
        // ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        
        // Include Start
        startHeaderRow.axis = .horizontal
        startHeaderRow.alignment = .center
        startHeaderRow.distribution = .fill
        startHeaderRow.spacing = 8
        startSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        startSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Bottom Bar
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.axis = .vertical
        bottomStack.alignment = .center
        bottomStack.spacing = 8
        
        // Summary Badge
        summaryBadge.translatesAutoresizingMaskIntoConstraints = false
        summaryBadge.backgroundColor = AppTheme.Color.main3.withAlphaComponent(0.15)
        summaryBadge.layer.cornerCurve = .continuous
        summaryBadge.layer.cornerRadius = AppTheme.Corner.l
        summaryBadge.layer.masksToBounds = true
        
        // Summary Label
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.textAlignment = .center
        
        // Root Stack
        root.axis = .vertical
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        
        // Interval Row
        intervalTailSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        intervalTailSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        intervalRow.axis = .horizontal
        intervalRow.alignment = .center
        intervalRow.distribution = .fill
        intervalRow.spacing = 12
        intervalRow.isLayoutMarginsRelativeArrangement = true
        intervalRow.directionalLayoutMargins = .init(top: 0, leading: 8, bottom: 0, trailing: 0)
        [intervalValuePD, intervalUnitPD].forEach {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        intervalPrefix.textAlignment = .left
        intervalPrefix.setContentHuggingPriority(.required, for: .horizontal)
        intervalPrefix.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        // End Switch Row
        endSwitchRow.axis = .horizontal
        endSwitchRow.alignment = .center
        endSwitchRow.spacing = 8
        
        // Toggle 기본 스타일
        var cfg = UIButton.Configuration.plain()
        cfg.baseForegroundColor = AppTheme.Color.accent
        cfg.image = UIImage(systemName: "plus.circle")
        cfg.contentInsets = .init(top: 6, leading: 6, bottom: 6, trailing: 6)
        endToggleButton.configuration = cfg
        endToggleButton.setPreferredSymbolConfiguration(.init(pointSize: 16, weight: .semibold), forImageIn: .normal)
        
        // 기본 상태: End Date 숨김
        endPicker.isHidden = true
        
        
        // ─────────────────────────────────────
        // 3) 제약(오토레이아웃)
        // ─────────────────────────────────────
        // ScrollView ↔︎ View
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor)
        ])
        
        // Bottom Bar ↔︎ Safe Area
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 8),
            bottomBar.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -8),
            bottomBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])
        
        bottomBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        
        // Bottom Separator(상단 선)
        bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomSeparator.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            bottomSeparator.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            bottomSeparator.topAnchor.constraint(equalTo: bottomBar.topAnchor)
        ])
        
        // Bottom Stack 여백(높이 슬림)
        NSLayoutConstraint.activate([
            bottomStack.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 6),
            bottomStack.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -6),
            bottomStack.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 10),
            bottomStack.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor, constant: -6)
        ])
        
        
        
        // Badge 안 패딩(타이트)
        NSLayoutConstraint.activate([
            summaryLabel.leadingAnchor.constraint(equalTo: summaryBadge.leadingAnchor, constant: 8),
            summaryLabel.trailingAnchor.constraint(equalTo: summaryBadge.trailingAnchor, constant: -8),
            summaryLabel.topAnchor.constraint(equalTo: summaryBadge.topAnchor, constant: 2),
            summaryLabel.bottomAnchor.constraint(equalTo: summaryBadge.bottomAnchor, constant: -2)
        ])
        
        // Root(스크롤 콘텐츠) — content/frame 레이아웃 가이드
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            root.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            
            // 가로 스크롤 방지: 좌우 16 여백과 일치(-32)
            root.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        
        
        // ─────────────────────────────────────
        // 4) 우선순위/배치(스택에 실제 추가)
        // ─────────────────────────────────────
        // BottomStack: [Badge][Value]
        bottomStack.addArrangedSubview(summaryBadge)
        bottomStack.addArrangedSubview(summaryValue)
        summaryBadge.setContentHuggingPriority(.required, for: .horizontal)
        summaryBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        summaryValue.setContentHuggingPriority(.defaultLow, for: .horizontal)
        summaryValue.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        
        // End 스위치 행: spacer는 유연하게
        endSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        endSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Root 섹션 배치
        root.addArrangedSubview(nameLabel)
        root.addArrangedSubview(nameField)
        root.addArrangedSubview(sep1)
        
        root.addArrangedSubview(amountLabel)
        root.addArrangedSubview(amountField)
        root.addArrangedSubview(sep2)
        
        root.addArrangedSubview(intervalLabel)
        root.addArrangedSubview(intervalRow)
        root.addArrangedSubview(sep3)
        
        root.addArrangedSubview(startHeaderRow)
        root.addArrangedSubview(startPicker)
        root.addArrangedSubview(sep4)
        
        root.addArrangedSubview(endSwitchRow)
        root.addArrangedSubview(endPicker)
        
        
        // 입력 필드 인셋/툴바
        nameField.addDoneToolbar()
        amountField.addDoneToolbar()
        nameField.contentInsets = .init(top: 0, leading: 12, bottom: 0, trailing: 12)
        amountField.contentInsets = .init(top: 0, leading: 12, bottom: 0, trailing: 12)
        
    }
    
    // MARK: - PullDown 스타일 (AppTheme 토큰 + Custom Popup)
    private func stylePullDowns() {
        [intervalValuePD, intervalUnitPD].forEach { $0.displayMode = .customPopup }
    }
    
    
    // MARK: - Interval PullDown 구성
    private func configureIntervalPickers() {
        // 값: 1...36
        let values = (1...36).map { AppPullDownField.Item("\($0)") }
        intervalValuePD.setItems(values, select: 0) // 기본 1
        
        // 단위: Day/Week/Month/Year
        let units = IntervalUnit.allCases.map { AppPullDownField.Item($0.title) }
        if let defaultUnitIndex = IntervalUnit.allCases.firstIndex(of: .months) {
            intervalUnitPD.setItems(units, select: defaultUnitIndex)
        } else {
            intervalUnitPD.setItems(units, select: 0)
        }
        updateNextPayLabel()
    }
    
    // MARK: - 이벤트 바인딩
    private func wireEvents() {
        intervalValuePD.onSelect = { [weak self] idx, _ in
            guard let self else { return }
            self.intervalValue = max(1, idx + 1)
            self.updateNextPayLabel()
        }
        intervalUnitPD.onSelect = { [weak self] idx, _ in
            guard let self else { return }
            guard let unit = IntervalUnit.allCases[safe: idx] else { return }
            self.intervalUnit = unit
            self.updateNextPayLabel()
        }
        endToggleButton.addTarget(self, action: #selector(toggleEndDate), for: .touchUpInside)
        startPicker.onChange = { [weak self] _ in self?.updateNextPayLabel() }
        endPicker.onChange = { [weak self] _ in
            guard let self else { return }
            self.updateNextPayLabel()
            self.layoutIfNeeded()
            let target = self.summaryValue
            let rectInScroll = target.convert(target.bounds, to: self.scrollView)
            self.scrollView.scrollRectToVisible(rectInScroll.insetBy(dx: 0, dy: -12), animated: true)
        }
        includeBtn.addTarget(self, action: #selector(toggleIncludeToday), for: .touchUpInside)
        let includeTap = UITapGestureRecognizer(target: self, action: #selector(toggleIncludeToday))
        includeLabel.isUserInteractionEnabled = true
        includeLabel.addGestureRecognizer(includeTap)
    }
    
    @objc private func toggleEndDate() {
        let willShow = endPicker.isHidden
        endPicker.isHidden = !willShow
        
        var cfg = endToggleButton.configuration ?? .plain()
        cfg.image = UIImage(systemName: willShow ? "minus.circle" : "plus.circle")
        cfg.baseForegroundColor = willShow ? AppTheme.Color.main2 : AppTheme.Color.accent
        endToggleButton.configuration = cfg
        
        UIView.animate(withDuration: 0.2, animations: {
            self.layoutIfNeeded()
        }, completion: { _ in
            // 펼친 경우, 요약이 보이도록 스크롤
            if willShow {
                let target = self.summaryValue
                let rectInScroll = target.convert(target.bounds, to: self.scrollView)
                self.scrollView.scrollRectToVisible(rectInScroll.insetBy(dx: 0, dy: -12), animated: true)
            }
        })
        updateNextPayLabel()
    }
    @objc private func toggleIncludeToday() {
        includeTodayAsPayday.toggle()
        let on = includeTodayAsPayday

        let newImageName = on ? "checkmark.square.fill" : "square"
        let newTint: UIColor = on ? AppTheme.Color.accent : .systemGray2

        // 살짝 눌렀다 튕기는 느낌
        let pop: CGFloat = 0.96
        includeBtn.transform = .identity
        UIView.animate(withDuration: 0.08, animations: {
            self.includeBtn.transform = CGAffineTransform(scaleX: pop, y: pop)
        }, completion: { _ in
            UIView.animate(withDuration: 0.18,
                           delay: 0,
                           usingSpringWithDamping: 0.9,
                           initialSpringVelocity: 0,
                           options: [.allowUserInteraction],
                           animations: {
                self.includeBtn.transform = .identity
            })
        })

        // 아이콘/컬러는 크로스디졸브로 전환
        UIView.transition(with: includeBtn,
                          duration: 0.18,
                          options: .transitionCrossDissolve,
                          animations: {
            var cfg = self.includeBtn.configuration ?? .plain()
            cfg.image = UIImage(systemName: newImageName)
            cfg.baseForegroundColor = newTint
            self.includeBtn.configuration = cfg
            self.includeBtn.tintColor = newTint
        })

        UIView.transition(with: includeLabel,
                          duration: 0.18,
                          options: .transitionCrossDissolve,
                          animations: {
            self.includeLabel.textColor = newTint
        })

        updateNextPayLabel()
    }
    
    // MARK: - 유틸
    private func buildInterval() -> Interval {
        let n = max(1, intervalValue)
        switch intervalUnit {
        case .days:   return .days(n)
        case .weeks:  return .days(n * 7)
        case .months: return .months(n)
        case .years:  return .months(n * 12)
        }
    }
    
    private func parseAmount(_ text: String?) -> Decimal? {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        // 지역화 고려: 단순 Decimal(string:) 기반
        return Decimal(string: t)
    }
    
    private func updateNextPayLabel() {
        let start = startPicker.date
        let end: Date? = endPicker.isHidden ? nil : endPicker.date
        let interval = buildInterval()
        
        if includeTodayAsPayday {
            // 체크 시: 첫 급여일은 start 자체
            let nextText = dateFormatter.string(from: start)
            var parts: [String] = [
                String(format: NSLocalizedString("intervalView.summary.nextFmt", comment: "IntervalView.swift: Next Payday: %@"), nextText)
            ]
            if let end = end {
                parts.append(String(format: NSLocalizedString("intervalView.summary.endFmt", comment: "IntervalView.swift: End: %@"),
                                    dateFormatter.string(from: end)))
            }
            summaryValue.text = parts.joined(separator: "   /   ")
            return
        }
        
        // 다음 결제일 계산
        if let next = BindoCalculator.nextPayDay(afterOrOn: Date(),
                                                 start: start,
                                                 interval: interval,
                                                 end: end,
                                                 calendar: .current) {
            let nextText = dateFormatter.string(from: next)
            var parts: [String] = [
                String(format: NSLocalizedString("intervalView.summary.nextFmt", comment: "IntervalView.swift: Next Payday: %@"), nextText)
            ]
            
            // 유저가 End Date를 보이도록 설정했으면 요약에 함께 표기
            if let end = end {
                let endText = dateFormatter.string(from: end)
                parts.append(String(format: NSLocalizedString("intervalView.summary.endFmt", comment: "IntervalView.swift: End: %@"), endText))
            }
            
            summaryValue.text = parts.joined(separator: "   /   ")
        } else {
            // 계산 불가 시
            if let end = end {
                let endText = dateFormatter.string(from: end)
                summaryValue.text = String(
                    format: NSLocalizedString("intervalView.summary.nextDashEndFmt", comment: "IntervalView.swift: Next Payday: --   /   End: %@"),
                    endText
                )
            } else {
                summaryValue.text = NSLocalizedString("intervalView.summary.nextDash", comment: "IntervalView.swift: Next Payday: --")
            }
        }
    }
    
    
}

// MARK: - 안전 인덱스 헬퍼
private extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


// MARK: - BindoForm
extension IntervalView: BindoForm {
    // 폼 이름(저장 시 option에 기록) → 데이터 구분자이므로 현지화하지 않음
    var optionName: String { "Interval" }
    
    private func computeEndDate(start: Date, interval: Interval, calendar cal: Calendar = .current) -> Date {
        let s = cal.startOfDay(for: start)
        switch interval {
        case .days(let d):
            return cal.startOfDay(for: cal.date(byAdding: .day, value: max(1, d), to: s) ?? s)
        case .months(let m):
            return cal.startOfDay(for: cal.date(byAdding: .month, value: max(1, m), to: s) ?? s)
        }
    }
    
    func buildModel() throws -> BindoList {
        // 검증 1,2: Missing Fields
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            self.shake()
            _ = presentInfo(
                NSLocalizedString("intervalView.alert.required.title", comment: "IntervalView.swift: Required"),
                NSLocalizedString("intervalView.alert.required.name", comment: "IntervalView.swift: Please enter Name.")
            )
            throw BindoFormError.missingField(
                NSLocalizedString("intervalView.field.name", comment: "IntervalView.swift: Name")
            )
        }
        guard
            let amountText = amountField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            let amount = Decimal(string: amountText), amount > 0
        else {
            self.shake()
            _ = presentInfo(
                NSLocalizedString("intervalView.alert.required.title", comment: "IntervalView.swift: Required"),
                NSLocalizedString("intervalView.alert.required.amount", comment: "IntervalView.swift: Please enter Amount.")
            )
            throw BindoFormError.missingField(
                NSLocalizedString("intervalView.field.amount", comment: "IntervalView.swift: Amount")
            )
        }
        
        // ② 폼 → 필드 매핑
        let today    = Date()
        let start    = startPicker.date
        let interval = buildInterval()
        let endAt    = endPicker.isHidden ? nil : endPicker.date
        
        // 검증3: endAt < startDate 차단
        if let endAt, Calendar.current.startOfDay(for: endAt) < Calendar.current.startOfDay(for: start) {
            self.shake()
            _ = presentInfo(
                NSLocalizedString("intervalView.alert.invalid.title", comment: "IntervalView.swift: Invalid Interval"),
                NSLocalizedString("intervalView.alert.invalid.endEarlier", comment: "IntervalView.swift: End Date cannot be earlier than Start Date.")
            )
            throw BindoFormError.inferredIntervalUnsupported
        }
        
        let cal = Calendar.current
        let firstEndPreview: Date = includeTodayAsPayday
            ? cal.startOfDay(for: start)
            : computeEndDate(start: start, interval: interval, calendar: cal)
        
        // 검증 4: 첫 사이클 종료가 endAt을 초과하면 저장 금지 (endAt 포함 규칙)
        if let endAt, cal.startOfDay(for: firstEndPreview) > cal.startOfDay(for: endAt) {
            self.shake()
            _ = presentInfo(
                NSLocalizedString("intervalView.alert.invalid.title", comment: "IntervalView.swift: Invalid Interval"),
                String(format: NSLocalizedString("intervalView.alert.invalid.firstExceeds",
                                                 comment: "IntervalView.swift: First payday will be %@ which exceeds End Date."),
                       dateFormatter.string(from: firstEndPreview))
            )
            throw BindoFormError.incorrectInterval
        }
        
        // ③ 첫 Occurence 생성
        let firstEnd = firstEndPreview
        let firstOcc = OccurrenceList(
            id: UUID(),
            startDate: start,
            endDate: firstEnd,
            payAmount: amount
        )
        
        // ④ BindoList 구성 (Occurrence 포함)
        return BindoList(
            id: UUID(),
            name: name,
            useBase: true,          // interval은 baseAmount 사용
            baseAmount: amount,     // Bindo.baseAmount
            createdAt: today,       // today
            updatedAt: today,       // today
            endAt: endAt,           // 선택
            option: optionName,     // "interval"
            interval: interval,     // Bindo.intervalDays / Months 로 저장됨
            occurrences: [firstOcc] // 첫 Occurence 동시 저장
        )
    }
    
    
    fileprivate struct IntervalDirtySnapshopt: Hashable {
        let name: String
        let amount: String
        let startYMD: Int
        let endShown: Bool
        let endYMD: Int?
        let unitIndex: Int?
        let valueIndex: Int?
    }
    
    // 더티 판단은 스냅샷 기반(VC가 비교)
    func dirtySignature() -> AnyHashable {
        let cal = Calendar.current
        let dayKey: (Date) -> Int = { Int(cal.startOfDay(for: $0).timeIntervalSince1970 / 86_400) }
        return AnyHashable(IntervalDirtySnapshopt(
            name: (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amountField.text ?? "",
            startYMD: dayKey(startPicker.date),
            endShown: !endPicker.isHidden,
            endYMD: endPicker.isHidden ? nil : dayKey(endPicker.date),
            unitIndex: intervalUnitPD.selectedIndex,
            valueIndex: intervalValuePD.selectedIndex
        ))
    }
    
    // discard 시 간단 초기화
    func reset() {
        nameField.text = ""
        amountField.text = ""
        startPicker.setDate(Date(), animated: false)
        
        // end 숨김 + 토글 UI 원복
        endPicker.isHidden = true
        var cfg = endToggleButton.configuration ?? .plain()
        cfg.image = UIImage(systemName: "plus.circle")
        cfg.baseForegroundColor = AppTheme.Color.accent
        endToggleButton.configuration = cfg
        
        includeTodayAsPayday = false
        var cfg2 = includeBtn.configuration ?? .plain()
        cfg2.image = UIImage(systemName: "square")
        cfg2.baseForegroundColor = .systemGray2
        includeBtn.configuration = cfg2
        includeLabel.textColor = .systemGray2
        
        // interval 기본값
        intervalValuePD.select(index: 0, emit: false) // 1
        if let monthsIndex = IntervalView.IntervalUnit.allCases.firstIndex(of: .months) {
            intervalUnitPD.select(index: monthsIndex, emit: false)
        } else {
            intervalUnitPD.select(index: 0, emit: false)
        }
        
        updateNextPayLabel()
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    
}


//MARK: - Update Bindo
// IntervalView.swift
extension IntervalView {
    func apply(_ m: BindoList) {
        nameField.text = m.name
        amountField.text = m.baseAmount.map { NumberFormatter().string(from: $0 as NSDecimalNumber) } ?? ""

        startPicker.setDate(m.occurrences.first?.startDate ?? Date(), animated: false)
        if let endAt = m.endAt {
            endPicker.setDate(endAt, animated: false)
            endPicker.isHidden = false
            var cfg = endToggleButton.configuration ?? .plain()
            cfg.image = UIImage(systemName: "minus.circle")
            cfg.baseForegroundColor = AppTheme.Color.main2
            endToggleButton.configuration = cfg
        } else {
            endPicker.isHidden = true
        }
        
        // Checkbox
        if let first = m.occurrences.first, Calendar.current.isDate(first.startDate, inSameDayAs: first.endDate) {
            includeTodayAsPayday = true
            var cfg = includeBtn.configuration ?? .plain()
            cfg.image = UIImage(systemName: "checkmark.square.fill")
            cfg.baseForegroundColor = AppTheme.Color.accent
            includeBtn.configuration = cfg
            includeLabel.textColor = AppTheme.Color.accent
        }

        // interval 값 복원
        switch m.interval {
        case .months(let mm):
            if let idx = IntervalUnit.allCases.firstIndex(of: .months) {
                intervalUnitPD.select(index: idx, emit: false)
            }
            intervalValuePD.select(index: mm - 1, emit: false)
        case .days(let dd):
            if dd % 7 == 0 {
                if let idx = IntervalUnit.allCases.firstIndex(of: .weeks) {
                    intervalUnitPD.select(index: idx, emit: false)
                }
                intervalValuePD.select(index: (dd / 7) - 1, emit: false)
            } else {
                if let idx = IntervalUnit.allCases.firstIndex(of: .days) {
                    intervalUnitPD.select(index: idx, emit: false)
                }
                intervalValuePD.select(index: dd - 1, emit: false)
            }
        case .none:
            break
        }
        updateNextPayLabel()
    }
}
