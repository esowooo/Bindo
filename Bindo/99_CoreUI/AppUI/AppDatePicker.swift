//
//  AppDatePicker.swift
//  Bindo
//
//  Created by Sean Choi on 9/11/25.
//

import UIKit

/// 연/월/일 선택 가능한 커스텀 PickerView (폰트/색 커스터마이즈)
public struct AppDatePickerStyle {
    public var font: UIFont
    public var textColor: UIColor
    public var tintColor: UIColor
    public var rowHeight: CGFloat
    public var showsUnitSuffix: Bool

    public init(font: UIFont = AppTheme.Font.body,
                textColor: UIColor = AppTheme.Color.label,
                tintColor: UIColor = AppTheme.Color.accent,
                rowHeight: CGFloat = 36,
                showsUnitSuffix: Bool = false) {
        self.font = font
        self.textColor = textColor
        self.tintColor = tintColor
        self.rowHeight = rowHeight
        self.showsUnitSuffix = showsUnitSuffix
    }
}

public final class AppDatePicker: UIView {

    // 공개 속성
    public var onChange: ((Date) -> Void)?
    public private(set) var date: Date { didSet { onChange?(date) } }
    public var calendar: Calendar { didSet { rebuildDataAndReload() } }
    public var locale: Locale { didSet { rebuildDataAndReload() } }
    public var minimumDate: Date? { didSet { clampDateAndReloadIfNeeded() } }
    public var maximumDate: Date? { didSet { clampDateAndReloadIfNeeded() } }
    public var style: AppDatePickerStyle { didSet { picker.reloadAllComponents() } }

    // 내부
    private let picker = UIPickerView()
    private var years: [Int] = []
    private var months: [Int] = Array(1...12)
    private var days: [Int] = Array(1...31)
    private let yearComponent = 0, monthComponent = 1, dayComponent = 2

    // 실시간 tint 반영
    private var displayLink: CADisplayLink?
    private var lastCenteredRow: [Int: Int] = [:]

    public init(initial: Date = Date(),
                calendar: Calendar = .current,
                locale: Locale = .current,
                style: AppDatePickerStyle = AppDatePickerStyle(),
                min: Date? = nil,
                max: Date? = nil) {
        self.date = initial
        self.calendar = calendar
        self.locale = locale
        self.style = style
        self.minimumDate = min
        self.maximumDate = max
        super.init(frame: .zero)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.date = Date()
        self.calendar = .current
        self.locale = .current
        self.style = AppDatePickerStyle()
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        picker.dataSource = self
        picker.delegate = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        addSubview(picker)
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: trailingAnchor),
            picker.topAnchor.constraint(equalTo: topAnchor),
            picker.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        rebuildDataAndReload()
        selectRows(for: date, animated: false)

        // 초기 진입에서도 선택행 tint 보이게
        picker.reloadAllComponents()
        DispatchQueue.main.async { [weak self] in self?.picker.reloadAllComponents() }

        startDisplayLink()
    }

    deinit { stopDisplayLink() }

    public func setDate(_ newDate: Date, animated: Bool) {
        let clamped = clampedDate(newDate)
        self.date = clamped
        selectRows(for: clamped, animated: animated)
        picker.reloadAllComponents()
    }

    // MARK: - 내부 유틸
    private func rebuildDataAndReload() {
        // 연도 범위
        let base = date
        let year = calendar.component(.year, from: base)
        let minY = minimumDate.map { calendar.component(.year, from: $0) } ?? (year - 50)
        let maxY = maximumDate.map { calendar.component(.year, from: $0) } ?? (year + 50)
        years = Array(minY...maxY)

        syncDaysToCurrentMonth()
        picker.reloadAllComponents()
        selectRows(for: clampedDate(date), animated: false)
    }

    private func syncDaysToCurrentMonth() {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let y = comps.year, let m = comps.month else { return }
        var dc = DateComponents(); dc.year = y; dc.month = m
        if let monthDate = calendar.date(from: dc),
           let range = calendar.range(of: .day, in: .month, for: monthDate) {
            days = Array(range)
        } else {
            days = Array(1...31)
        }
        let curDay = calendar.component(.day, from: date)
        if !days.contains(curDay) {
            var dc = calendar.dateComponents([.year, .month], from: date)
            dc.day = days.last
            date = calendar.date(from: dc) ?? date
        }
    }

    private func selectRows(for date: Date, animated: Bool) {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)

        if let yIdx = years.firstIndex(of: y) {
            picker.selectRow(yIdx, inComponent: yearComponent, animated: animated)
            lastCenteredRow[yearComponent] = yIdx
        }
        picker.selectRow(m - 1, inComponent: monthComponent, animated: animated)
        lastCenteredRow[monthComponent] = m - 1

        syncDaysToCurrentMonth()
        picker.reloadComponent(dayComponent)
        if let dIdx = days.firstIndex(of: d) {
            picker.selectRow(dIdx, inComponent: dayComponent, animated: animated)
            lastCenteredRow[dayComponent] = dIdx
        }
    }

    private func clampedDate(_ date: Date) -> Date {
        if let min = minimumDate, date < min { return min }
        if let max = maximumDate, date > max { return max }
        return date
    }

    private func clampDateAndReloadIfNeeded() {
        let clamped = clampedDate(self.date)
        if clamped != self.date { self.date = clamped }
        rebuildDataAndReload()
    }

    // 실시간 tint 반영: 중앙행 추적
    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    private func stopDisplayLink() { displayLink?.invalidate(); displayLink = nil }

    @objc private func tick() {
        var changed: [Int] = []
        for comp in 0..<picker.numberOfComponents {
            let center = picker.selectedRow(inComponent: comp)
            if lastCenteredRow[comp] != center {
                lastCenteredRow[comp] = center
                changed.append(comp)
            }
        }
        changed.forEach { picker.reloadComponent($0) }
    }
}

// MARK: - DataSource
extension AppDatePicker: UIPickerViewDataSource {
    public func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case yearComponent:  return years.count
        case monthComponent: return months.count
        default:             return days.count
        }
    }
}

// MARK: - Delegate
extension AppDatePicker: UIPickerViewDelegate {
    public func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        style.rowHeight
    }

    public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int,
                           forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = (view as? UILabel) ?? UILabel()
        label.textAlignment = .center
        label.font = style.font
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75

        switch component {
        case yearComponent:
            label.text = style.showsUnitSuffix ? "\(years[row]) yr" : "\(years[row])"
        case monthComponent:
            let m = months[row]
            // iOS 15: languageCode 사용
            if locale.languageCode == "en" {
                label.text = style.showsUnitSuffix ? "\(m) mo" : "\(m)"
            } else {
                label.text = style.showsUnitSuffix ? "\(m)월" : "\(m)"
            }
        default:
            let d = days[row]
            if locale.languageCode == "en" {
                label.text = style.showsUnitSuffix ? "\(d) d" : "\(d)"
            } else {
                label.text = style.showsUnitSuffix ? "\(d)일" : "\(d)"
            }
        }

        // 선택행 tint
        let centered = lastCenteredRow[component] ?? pickerView.selectedRow(inComponent: component)
        label.textColor = (row == centered) ? style.tintColor : style.textColor
        return label
    }

    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        var y = calendar.component(.year, from: date)
        var m = calendar.component(.month, from: date)
        var d = calendar.component(.day, from: date)

        switch component {
        case yearComponent:  y = years[row]
        case monthComponent: m = months[row]
        case dayComponent:   d = days[row]
        default: break
        }

        if component == yearComponent || component == monthComponent {
            let temp = calendar.date(from: DateComponents(year: y, month: m, day: 1)) ?? date
            date = temp
            syncDaysToCurrentMonth()
            picker.reloadComponent(dayComponent)
            if !days.contains(d) { d = days.last ?? d }
        }

        let newDate = calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? date
        date = newDate
        selectRows(for: date, animated: true)

        lastCenteredRow[component] = row
        picker.reloadComponent(component)
    }
}
