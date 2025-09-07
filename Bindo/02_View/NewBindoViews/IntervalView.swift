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
    private let summaryLabel = AppLabel("Summary", style: .secondaryBody, tone: .main2)
    private let summaryValue = AppLabel("Next Pay Day: --", style: .caption, tone: .label)
    

    // MARK: - UI 구성요소
    private let nameLabel   = AppLabel("Name", style: .secondaryBody, tone: .main2)
    private let nameField   = AppTextField(placeholder: "", kind: .standard)

    private let amountLabel = AppLabel("Amount", style: .secondaryBody, tone: .main2)
    private let amountField = AppTextField(placeholder: "", kind: .numeric)

    private let startLabel  = AppLabel("Start Date", style: .secondaryBody, tone: .main2)
    private let startPicker = AppDatePicker(initial: Date())

    private let intervalLabel = AppLabel("Interval", style: .secondaryBody, tone: .main2)
    private let intervalValuePD  = AppPullDownField(placeholder: "Value")
    private let intervalUnitPD   = AppPullDownField(placeholder: "Unit")

    private let endSwitchRow = UIStackView()
    private let endTitle     = AppLabel("End Date (Optional)", style: .secondaryBody, tone: .main2)
    private let endToggleButton    = UIButton(type: .system)
    private let endPicker    = AppDatePicker(initial: Date())
    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium   // 예: Sep 11, 2025
        f.timeStyle = .none
        return f
    }()

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

    // IntervalUnit: 내부 표현 (week/year도 지원 → days/months로 매핑)
    private enum IntervalUnit: Int, CaseIterable {
        case days, weeks, months, years

        var title: String {
            switch self {
            case .days:   return "Day(s)"
            case .weeks:  return "Week(s)"
            case .months: return "Month(s)"
            case .years:  return "Year(s)"
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
        intervalRow.addArrangedSubview(intervalUnitPD)
        intervalRow.addArrangedSubview(intervalValuePD)
        let intervalWrap = UIView()
        intervalWrap.addSubview(intervalRow)

        // End 스위치 행 (오른쪽 끝 토글)
        let endSpacer = UIView()
        endSwitchRow.addArrangedSubview(endTitle)
        endSwitchRow.addArrangedSubview(endSpacer)
        endSwitchRow.addArrangedSubview(endToggleButton)
        
        // 스크롤 콘텐츠 루트
        scrollView.addSubview(root)

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
        intervalRow.axis = .horizontal
        intervalRow.alignment = .center
        intervalRow.distribution = .fill
        intervalRow.spacing = 12
        intervalRow.translatesAutoresizingMaskIntoConstraints = false
        intervalWrap.translatesAutoresizingMaskIntoConstraints = false

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

        // IntervalRow 내부 제약
        NSLayoutConstraint.activate([
            intervalRow.leadingAnchor.constraint(equalTo: intervalWrap.leadingAnchor),
            intervalRow.trailingAnchor.constraint(equalTo: intervalWrap.trailingAnchor),
            intervalRow.topAnchor.constraint(equalTo: intervalWrap.topAnchor),
            intervalRow.bottomAnchor.constraint(equalTo: intervalWrap.bottomAnchor)
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

        // Interval PD 폭/우선순위
        [intervalValuePD, intervalUnitPD].forEach {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

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
        root.addArrangedSubview(intervalWrap)
        root.addArrangedSubview(sep3)

        root.addArrangedSubview(startLabel)
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
    
    private func lockPulldownWidthsUsingMaxContent() {
        let values = (1...36).map { "\($0)" }
        let units  = IntervalUnit.allCases.map { $0.title }
        let font   = AppTheme.Font.body

        func width(of text: String) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: font]).width
        }
        let maxValueW = values.map(width(of:)).max() ?? 0
        let maxUnitW  = units.map(width(of:)).max() ?? 0

        let insets  = AppTheme.PullDown.contentInsets
        let padding = insets.leading + insets.trailing + 50 // 아이콘/여백 포함 여유치
        let target  = max(AppTheme.PullDown.popupMinWidth, max(maxValueW, maxUnitW) + padding)

        // 기존 제약 해제
        unitWidthC?.isActive = false
        valueWidthC?.isActive = false

        // “선호 너비”로 설정(필요시 깨질 수 있게)
        let unitEq   = intervalUnitPD.widthAnchor.constraint(equalToConstant: target)
        unitEq.priority = .defaultHigh     // 750 (필요시 시스템이 살짝 줄일 수 있음)

        let valueEq  = intervalValuePD.widthAnchor.constraint(equalToConstant: target)
        valueEq.priority = .defaultHigh

        NSLayoutConstraint.activate([unitEq, valueEq])
        unitWidthC = unitEq
        valueWidthC = valueEq
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
        DispatchQueue.main.async { [weak self] in
            self?.lockPulldownWidthsUsingMaxContent()
        }
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

        // 다음 결제일 계산
        if let next = BindoCalculator.nextPayDay(afterOrOn: Date(),
                                                 start: start,
                                                 interval: interval,
                                                 end: end) {
            let nextText = dateFormatter.string(from: next)
            var parts: [String] = ["Next Pay Day: \(nextText)"]

            // 유저가 End Date를 보이도록 설정했으면 요약에 함께 표기
            if let end = end {
                let endText = dateFormatter.string(from: end)
                parts.append("End: \(endText)")
            }

            summaryValue.text = parts.joined(separator: "   /   ")
        } else {
            // 계산 불가 시
            if let end = end {
                let endText = dateFormatter.string(from: end)
                summaryValue.text = "Next Pay Day: --   /   End: \(endText)"
            } else {
                summaryValue.text = "Next Pay Day: --"
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
    // 폼 이름(저장 시 option에 기록)
    var optionName: String { "Interval" }
    
    func buildModel() throws -> BindoList {
        // ① 공통 검증
        guard let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
        else { self.shake(); presentInfo("Required", "Please enter Name."); throw BindoFormError.missingField("Name") }

        guard let amountText = amountField.text?.trimmingCharacters(in: .whitespacesAndNewlines),!amountText.isEmpty, let amount = Decimal(string: amountText),amount > 0 else { self.shake(); presentInfo("Required", "Please enter Amount."); throw BindoFormError.missingField("Amount") }


        let start = startPicker.date
        let end: Date? = endPicker.isHidden ? nil : endPicker.date
        let interval = buildInterval()

        // ② 저장용 occurrence 날짜 선택: (A) 오늘 이후 첫 결제일 → (B) 오늘 이전 마지막 결제일(폴백)
        let today = Date()
        let nextAfterToday = BindoCalculator.nextPayDay(afterOrOn: today, start: start, interval: interval, end: end)
        let lastBeforeToday = BindoCalculator.lastPayDay(onOrBefore: today, start: start, interval: interval, end: end)

        guard let occDate = nextAfterToday ?? lastBeforeToday else {
            self.shake()
            presentInfo("Confirm", "End Date must be after the start date.")
            throw BindoFormError.invalidInterval
        }

        let occ = OccurrenceList(date: occDate, amount: amount)

        return BindoList(
            id: UUID(),
            name: name,
            amount: amount,
            startDate: start,
            endDate: end,
            interval: interval,
            option: optionName,
            createdAt: Date(),
            updatedAt: Date(),
            occurrences: [occ]
        )
    }
    
    fileprivate struct IntervalDirtySnapshopt: Hashable {
        let name: String
        let amount: String
        let startYMD: Int      // days since 1970 (stable day-level)
        let endShown: Bool
        let unitIndex: Int?    // selectedIndex can be optional
        let valueIndex: Int?
    }
    
    
    // 더티 판단은 스냅샷 기반(VC가 비교)
    func dirtySignature() -> AnyHashable {
        let cal = Calendar.current
        let ymd: (Date) -> Int = { Int(cal.startOfDay(for: $0).timeIntervalSince1970 / 86_400) }
        
        return AnyHashable(IntervalDirtySnapshopt(
            name: (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amountField.text ?? "",
            startYMD: ymd(startPicker.date),
            endShown: !endPicker.isHidden,
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
        
        // interval 기본값으로
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
