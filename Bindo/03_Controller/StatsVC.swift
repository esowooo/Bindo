//
//  StatsVC.swift
//  Bindo
//
//  Created by Sean Choi on 9/9/25.
//

import UIKit

final class StatsVC: BaseVC {
    // MARK: - IBOutlets (스토리보드 연결)
    @IBOutlet weak var chartView: BarChartView!
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var chartControlView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var controlStack: UIStackView!

    // MARK: - 주입
    var provider: StatsProvider?
    private let viewContext = Persistence.shared.viewContext

    // MARK: - 상태
    private let cal = Calendar.current
    private var granularity: StatsGranularity = .month { didSet { applyGranularityChange() } }
    private var anchorDate: Date = Date()
    private var modeButtons: [UIButton] = []
    private lazy var axisOverlay: AxisOverlayView = {
        let v = AxisOverlayView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // 범위 제어(좌/우 스팬)
    private var leftSpan: Int  = 3
    private var rightSpan: Int = 3
    private let spanStep = 1
    private let minSpan  = 0
    private let maxSpan  = 24

    private var rangeStack: UIStackView!
    private var lastLayoutSize: CGSize = .zero

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        if provider == nil {
            let repo = CoreDataBindoRepository(context: Persistence.shared.viewContext)
            provider = RepositoryStatsProvider(repo: repo) // StatsRepository만 의존
        }

        buildUI()
        buildControls(["Month", "Year"])
        applyTheme()
        anchorDate = periodStart(for: Date(), granularity: granularity)
        updateTitle()
        renderChart()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidChange(_:)),
            name: .NSManagedObjectContextObjectsDidChange,
            object: viewContext
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTitle()
        renderChart()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 차트 뷰 크기가 바뀌면(회전/초기 레이아웃) 막대 폭/간격 재계산을 위해 재렌더
        if chartView.bounds.size != lastLayoutSize {
            lastLayoutSize = chartView.bounds.size
            renderChart()
        }
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self,
            name: .NSManagedObjectContextObjectsDidChange,
            object: viewContext)
    }
    
    @objc private func contextDidChange(_ note: Notification) {
        // 필요하면 provider 재생성(캐싱이 있다면)
        if provider == nil {
            provider = RepositoryStatsProvider(repo: CoreDataBindoRepository(context: viewContext))
        }
        renderChart()
    }

    // MARK: - UI 구성
    private func buildUI() {
        // 차트 기본 스타일
        chartView.layer.cornerRadius = AppTheme.Corner.l
        chartView.layer.cornerCurve  = .continuous
        chartView.clipsToBounds      = true
        chartView.backgroundColor    = .clear
        chartView.lineColor          = AppTheme.Color.main1

        // 축 오버레이를 chartView의 서브뷰로 넣음 (같은 좌표계)
        axisOverlay.translatesAutoresizingMaskIntoConstraints = false
        axisOverlay.backgroundColor = .clear
        axisOverlay.tintColor       = AppTheme.Color.accent
        axisOverlay.isUserInteractionEnabled = false

        chartView.addSubview(axisOverlay)

        // axisOverlay를 chartView에 풀스트레치
        NSLayoutConstraint.activate([
            axisOverlay.leadingAnchor.constraint(equalTo: chartView.leadingAnchor),
            axisOverlay.trailingAnchor.constraint(equalTo: chartView.trailingAnchor),
            axisOverlay.topAnchor.constraint(equalTo: chartView.topAnchor),
            axisOverlay.bottomAnchor.constraint(equalTo: chartView.bottomAnchor)
        ])

        // No-data 라벨
        chartView.addSubview(noDataLabel)
        NSLayoutConstraint.activate([
            noDataLabel.centerXAnchor.constraint(equalTo: chartView.centerXAnchor),
            noDataLabel.centerYAnchor.constraint(equalTo: chartView.centerYAnchor),
            noDataLabel.leadingAnchor.constraint(greaterThanOrEqualTo: chartView.leadingAnchor, constant: 12),
            noDataLabel.trailingAnchor.constraint(lessThanOrEqualTo: chartView.trailingAnchor, constant: -12)
        ])
    }

    private func buildControls(_ items: [String]) {
        // 1) 모드 버튼(월/연)
        controlStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        modeButtons.removeAll()

        for (idx, title) in items.enumerated() {
            var cfg = UIButton.Configuration.filled()
            cfg.cornerStyle = .capsule
            cfg.baseBackgroundColor = AppTheme.Color.main3.withAlphaComponent(0.18)
            cfg.baseForegroundColor = AppTheme.Color.main1
            cfg.title = title
            cfg.attributedTitle = AttributedString(title, attributes: .init([
                .font: AppTheme.Font.body,
                .foregroundColor: AppTheme.Color.main1
            ]))
            cfg.contentInsets = .init(top: 8, leading: 14, bottom: 8, trailing: 14)

            let btn = UIButton(configuration: cfg)
            btn.tag = idx
            btn.addTarget(self, action: #selector(modeTapped(_:)), for: .touchUpInside)
            controlStack.addArrangedSubview(btn)
            modeButtons.append(btn)
        }
        updateModeButtons()

        // 2) 범위 제어 스택(차트 컨트롤 영역 안으로 이동)
        rangeStack?.removeFromSuperview()
        let rs = UIStackView()
        rs.axis = .horizontal
        rs.spacing = 8
        rs.alignment = .center
        rs.distribution = .equalSpacing
        rs.isLayoutMarginsRelativeArrangement = true
        rs.directionalLayoutMargins = .init(top: 0, leading: 8, bottom: 0, trailing: 8)
        rs.translatesAutoresizingMaskIntoConstraints = false

        let items: [(symbol: String, selector: Selector, a11y: String)] = [
            ("chevron.left", #selector(prevAnchorTapped),  "Previous period"),
            ("minus",        #selector(zoomoutRangeTapped), "Narrow range"),
            ("circle",  #selector(centerRangeTapped),  "Current Period"),
            ("plus",         #selector(zoominRangeTapped),  "Widen range"),
            ("chevron.right",#selector(nextAnchorTapped),   "Next period")
        ]

        for spec in items {
            var cfg = UIButton.Configuration.filled()
            cfg.cornerStyle = .capsule
            cfg.baseBackgroundColor = .clear
            cfg.baseForegroundColor = AppTheme.Color.accent
            cfg.image = UIImage(systemName: spec.symbol)
            cfg.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            cfg.contentInsets = .init(top: 8, leading: 10, bottom: 8, trailing: 10)
            cfg.title = nil
            cfg.attributedTitle = nil

            let b = UIButton(configuration: cfg)
            b.addTarget(self, action: spec.selector, for: .touchUpInside)
            b.accessibilityLabel = spec.a11y
            b.setContentHuggingPriority(.required, for: .horizontal)
            b.setContentCompressionResistancePriority(.required, for: .horizontal)
            rs.addArrangedSubview(b)
        }

        // chartControlView 안에 삽입
        guard let host = self.chartControlView else {
            assertionFailure("chartControlView is nil — connect the IBOutlet in Interface Builder.")
            return
        }
        host.addSubview(rs)

        // chartControlView 내부에 핀(상하좌우) — 레이아웃 안정
        NSLayoutConstraint.activate([
            rs.topAnchor.constraint(equalTo: host.topAnchor, constant: 0),
            rs.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: 0),
            rs.leadingAnchor.constraint(greaterThanOrEqualTo: host.leadingAnchor, constant: 8),
            rs.trailingAnchor.constraint(lessThanOrEqualTo: host.trailingAnchor, constant: -8),
            rs.centerXAnchor.constraint(equalTo: host.centerXAnchor)
        ])

        // 우선순위: 잘림 방지
        rs.isLayoutMarginsRelativeArrangement = false
        host.layoutMargins = .zero
        rs.setContentHuggingPriority(.required, for: .vertical)
        host.setContentCompressionResistancePriority(.required, for: .vertical)

        self.rangeStack = rs
    }

    private func applyTheme() {
        // 컨테이너 둥글게
        [topView, controlStack, chartControlView].forEach {
            $0?.layer.cornerRadius = AppTheme.Corner.l
            $0?.layer.cornerCurve  = .continuous
            $0?.clipsToBounds = true
            $0?.backgroundColor = AppTheme.Color.background
        }
        
        titleLabel.font = AppTheme.Font.secondaryTitle
        titleLabel.textColor = AppTheme.Color.main1
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        var cfg = UIButton.Configuration.plain()
        cfg.baseForegroundColor = AppTheme.Color.accent
        cfg.contentInsets = .init(top: 6, leading: 6, bottom: 6, trailing: 6)
        if dismissButton.currentImage == nil {
            cfg.image = UIImage(systemName: "xmark.square.fill")
        }
        dismissButton.configuration = cfg
        dismissButton.tintColor = AppTheme.Color.accent

        controlStack.spacing = 12
        chartControlView.setContentHuggingPriority(.required, for: .vertical)
        chartControlView.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private let noDataLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.numberOfLines = 0
        l.textAlignment = .center
        l.text = "No data available"
        l.textColor = AppTheme.Color.main2.withAlphaComponent(0.9)
        l.font = AppTheme.Font.secondaryBody
        l.isHidden = true
        return l
    }()

    private func setNoDataVisible(_ show: Bool, message: String = "No data available") {
        noDataLabel.text = message
        noDataLabel.isHidden = !show
    }

    // MARK: - 액션
    @IBAction func dismissButtonPressed(_ sender: UIButton) { dismiss(animated: true) }

    @objc private func modeTapped(_ sender: UIButton) {
        let newG: StatsGranularity = (sender.tag == 0) ? .month : .year
        guard newG != granularity else { return }
        granularity = newG
    }

    @objc private func prevAnchorTapped()  { anchorDate = shiftAnchor(by: -1); updateTitle(); renderChart() }
    @objc private func nextAnchorTapped()  { anchorDate = shiftAnchor(by: +1); updateTitle(); renderChart() }
    @objc private func zoominRangeTapped() { // 축소
        leftSpan  = max(minSpan, leftSpan - spanStep)
        rightSpan = max(minSpan, rightSpan - spanStep)
        renderChart()
    }
    @objc private func zoomoutRangeTapped() { // 확대
        leftSpan  = min(maxSpan, leftSpan + spanStep)
        rightSpan = min(maxSpan, rightSpan + spanStep)
        renderChart()
    }
    @objc private func centerRangeTapped() {
        anchorDate = periodStart(for: Date(), granularity: granularity)
        updateTitle()
        renderChart()
    }
    
    private func applyGranularityChange() {
        anchorDate = periodStart(for: Date(), granularity: granularity)
        updateModeButtons()
        updateTitle()
        renderChart()
    }

    private func updateModeButtons() {
        for (i, b) in modeButtons.enumerated() {
            let isOn = (i == (granularity == .month ? 0 : 1))
            var cfg = b.configuration ?? .filled()
            cfg.baseBackgroundColor = isOn ? AppTheme.Color.accent : AppTheme.Color.main3.withAlphaComponent(0.18)
            cfg.baseForegroundColor = isOn ? AppTheme.Color.background : AppTheme.Color.main1
            if let title = cfg.title {
                cfg.attributedTitle = AttributedString(title, attributes: .init([
                    .font: AppTheme.Font.body,
                    .foregroundColor: isOn ? AppTheme.Color.background : AppTheme.Color.main1
                ]))
            }
            b.configuration = cfg
        }
    }

    private func updateTitle() {
        
        titleLabel.text = provider?.title(for: anchorDate, granularity: granularity)
    }
    
    private func periodStart(for date: Date, granularity: StatsGranularity) -> Date {
        switch granularity {
        case .month: return monthStart(date)
        case .year:  return yearStart(date)
        }
    }

    // MARK: - 차트 렌더링
    private func renderChart() {
        guard let provider = provider else {
            chartView.configure(series: .init(startDate: Date(), step: 86_400, values: []),
                                maxY: 1,
                                granularity: (granularity == .month ? .month : .year),
                                calendar: cal)
            axisOverlay.plotInset = chartView.plotInset
            axisOverlay.configure(maxY: 1)
            setNoDataVisible(true)
            return
        }

        // 1) 가로 윈도우 구성 (⚠️ 앵커 기준!)
        let range = expandedInterval(for: anchorDate, granularity: granularity)

        // 2) 저장소에서 기본 버킷 가져오기 (저장+프로젝션 합산)
        let buckets = provider.stats(for: range, granularity: .month) // day-bucket → 아래에서 월/연 합산

        // 3) 월/년 막대 시리즈 만들기
        let barStarts: [Date]
        let values: [Double]
        let step: TimeInterval

        switch granularity {
        case .month:
            barStarts = monthsInRange(range)
            let byDay = Dictionary(grouping: buckets, by: { startOfDay($0.periodStart) })
            var byMonth: [Date: Double] = [:]
            for (d, arr) in byDay {
                let m = monthStart(d)
                byMonth[m, default: 0] += arr.reduce(0) { $0 + $1.totalAmount }
            }
            values = barStarts.map { byMonth[$0] ?? 0 }
            step = 86_400 * 30 // index 계산용
        case .year:
            barStarts = yearsInRange(range)
            let byMonth = Dictionary(grouping: buckets, by: { monthStart($0.periodStart) })
            var byYear: [Date: Double] = [:]
            for (m, arr) in byMonth {
                let y = yearStart(m)
                byYear[y, default: 0] += arr.reduce(0) { $0 + $1.totalAmount }
            }
            values = barStarts.map { byYear[$0] ?? 0 }
            step = 86_400 * 365
        }

        // 4) Y 상한/차트 구성
        let dataMax = values.max() ?? 1
        let hinted  = provider.maxY(for: granularity)
        let maxY    = max(dataMax, hinted, 1)
        let displayMaxY = max(1, maxY * 1.02)


        // 화면에 꽉 차는 막대 폭/간격 산정
        let bottomInset = xLabelsBottomInset()
        chartView.plotInset = .init(top: 14, left: 0, bottom: bottomInset, right: 0)
        axisOverlay.plotInset = chartView.plotInset
        

        let plotWidth = max(0, chartView.bounds.width - (chartView.plotInset.left + chartView.plotInset.right))
        let barCount  = max(values.count, 1)
        let stepPx    = (barCount > 0) ? (plotWidth / CGFloat(barCount)) : plotWidth
        let barW      = max(10, stepPx * 0.62)
        let gap       = max(4, stepPx - barW)

        chartView.barWidth = barW
        chartView.barGap   = gap

        chartView.configure(series: .init(startDate: barStarts.first ?? anchorDate, step: step, values: values),
                            maxY: displayMaxY,
                            granularity: (granularity == .month ? .month : .year),
                            calendar: cal)
        axisOverlay.configure(maxY: displayMaxY)
        setNoDataVisible(values.allSatisfy { $0 == 0 })

        // 기준선 = 앵커 막대(항상 leftSpan번째)
        let anchorIndex = min(max(0, leftSpan), max(0, barStarts.count - 1))
        chartView.highlightIndex = anchorIndex
        axisOverlay.setReferenceX(nil)
    }
    private func xLabelsBottomInset() -> CGFloat {
        // xLabelFont은 BarChartView가 가진 폰트 사용
        let h = chartView.xLabelFont.lineHeight
        // 라벨 높이 + 6pt 패딩, 최소 12 보장
        return max(12, ceil(h) + 6)
    }

    // MARK: - 날짜 유틸
    private func expandedInterval(for anchor: Date, granularity: StatsGranularity) -> DateInterval {
        switch granularity {
        case .month:
            let a0 = monthStart(anchor)
            let start = cal.date(byAdding: .month, value: -leftSpan, to: a0)!
            let end   = cal.date(byAdding: .month, value: rightSpan + 1, to: a0)! // [start, next-of-last)
            return DateInterval(start: start, end: end)
        case .year:
            let a0 = yearStart(anchor)
            let start = cal.date(byAdding: .year, value: -leftSpan, to: a0)!
            let end   = cal.date(byAdding: .year, value: rightSpan + 1, to: a0)!
            return DateInterval(start: start, end: end)
        }
    }

    private func monthsInRange(_ r: DateInterval) -> [Date] {
        var out: [Date] = []
        var d = monthStart(r.start)
        while d < r.end { out.append(d); d = cal.date(byAdding: .month, value: 1, to: d)! }
        return out
    }
    private func yearsInRange(_ r: DateInterval) -> [Date] {
        var out: [Date] = []
        var d = yearStart(r.start)
        while d < r.end { out.append(d); d = cal.date(byAdding: .year, value: 1, to: d)! }
        return out
    }
    private func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }
    private func monthStart(_ d: Date) -> Date { cal.date(from: cal.dateComponents([.year, .month], from: d))! }
    private func yearStart(_ d: Date) -> Date  { cal.date(from: cal.dateComponents([.year], from: d))! }

    private func shiftAnchor(by delta: Int) -> Date {
        switch granularity {
        case .month: return cal.date(byAdding: .month, value: delta, to: anchorDate).map(monthStart(_:))!
        case .year:  return cal.date(byAdding: .year,  value: delta, to: anchorDate).map(yearStart(_:))!
        }
    }
}

// MARK: - Bindo Repository Provider
enum StatsGranularity: CaseIterable {
    case month, year
    var title: String { self == .month ? "Month" : "Year" }
}

struct StatsBucket: Hashable {
    let periodStart: Date
    let totalAmount: Double
    let count: Int
}

protocol StatsProvider: AnyObject {
    func stats(for range: DateInterval, granularity: StatsGranularity) -> [StatsBucket]
    func maxY(for granularity: StatsGranularity) -> Double
    func title(for start: Date, granularity: StatsGranularity) -> String
}

final class RepositoryStatsProvider: StatsProvider {
    private let repo: StatsRepository
    private let cal: Calendar

    init(repo: StatsRepository, calendar: Calendar = .current) {
        self.repo = repo
        self.cal  = calendar
    }

    func stats(for range: DateInterval, granularity: StatsGranularity) -> [StatsBucket] {
        (try? repo.fetchStats(in: range, granularity: granularity, calendar: cal)) ?? []
    }

    // “권장 상한선” 역할. 필요하면 더 똑똑하게 계산해도 됨.
    func maxY(for granularity: StatsGranularity) -> Double {
        switch granularity { case .month: return 100; case .year: return 1000 }
    }

    func title(for start: Date, granularity: StatsGranularity) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = (granularity == .month) ? "yyyy.MM" : "yyyy"
        return df.string(from: start)
    }
}
