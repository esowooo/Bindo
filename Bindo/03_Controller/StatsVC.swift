//
//  StatsVC.swift
//  Bindo
//
//  Created by Sean Choi on 9/9/25.
//

import UIKit




final class StatsVC: UIViewController {
    // MARK: - IBOutlets (스토리보드 연결)
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var chartView: ContinuousChartView!
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var controlStack: UIStackView!

    @IBAction func dismissButtonPressed(_ sender: UIButton) {
        dismiss(animated: true)
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
    
    //MARK: - 주입
    var provider: StatsProvider?

    // MARK: - 상태
    private let cal = Calendar.current
    private var granularity: StatsGranularity = .month {
        didSet { applyGranularityChange() }
    }
    private var anchorDate: Date = Date()
    private var modeButtons: [UIButton] = []
    private lazy var axisOverlay: AxisOverlayView = {
        let v = AxisOverlayView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
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
    }

    // MARK: - UI 구성
    private func buildUI() {
        // 차트 기본 스타일
        chartView.layer.cornerRadius = AppTheme.Corner.l
        chartView.layer.cornerCurve  = .continuous
        chartView.clipsToBounds      = true
        chartView.backgroundColor    = .clear
        chartView.lineColor          = AppTheme.Color.accent
        chartView.fillTop            = AppTheme.Color.accent.withAlphaComponent(0.22)
        chartView.fillBottom         = AppTheme.Color.accent.withAlphaComponent(0.06)

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
    }

    private func applyTheme() {
        // 컨테이너들 둥글게
        [topView, controlStack, containerView].forEach {
            $0?.layer.cornerRadius = AppTheme.Corner.l
            $0?.layer.cornerCurve  = .continuous
            $0?.clipsToBounds = true
        }

        var cfg = UIButton.Configuration.plain()
        cfg.baseForegroundColor = AppTheme.Color.accent
        cfg.contentInsets = .init(top: 6, leading: 6, bottom: 6, trailing: 6)
        if dismissButton.currentImage == nil {
            cfg.image = UIImage(systemName: "xmark.circle.fill")
        }
        dismissButton.configuration = cfg
        dismissButton.tintColor = AppTheme.Color.accent

        controlStack.spacing = 12
        controlStack.backgroundColor = AppTheme.Color.background
    }
    
    private func setNoDataVisible(_ show: Bool, message: String = "No data available") {
        noDataLabel.text = message
        noDataLabel.isHidden = !show
    }

    // MARK: - 액션
    @objc private func modeTapped(_ sender: UIButton) {
        let newG: StatsGranularity = (sender.tag == 0) ? .month : .year
        guard newG != granularity else { return }
        granularity = newG
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

    // MARK: - 차트 렌더링
    private func renderChart() {
        guard let provider = provider else {
            chartView.configure(series: .init(startDate: Date(), step: 86_400, values: []), maxY: 1)
            setNoDataVisible(true)
            return
        }

        let range   = interval(for: anchorDate, granularity: granularity)
        var buckets = provider.stats(for: range, granularity: granularity)

        // 정렬 보장
        buckets.sort { $0.periodStart < $1.periodStart }

        // === 1) step 결정 (month=일, year=월) ===
        let step: TimeInterval
        switch granularity {
        case .month:
            step = 86_400 // 하루
        case .year:
            // "월 단위" step: anchorDate의 월 1일 기준으로 월 간격
            // 차트는 균등 step이 필요하므로 30일로 근사해도 OK. 더 정확히 하려면 overlay에서 라벨만 월로, step은 30일 근사.
            step = 86_400 * 30
        }

        // === 2) 버킷 맵으로 (periodStart -> amount) ===
        let byStart = Dictionary(uniqueKeysWithValues: buckets.map { ($0.periodStart, $0.totalAmount) })

        // === 3) 연속값 배열 생성 (빈 날/달은 0) ===
        let denseValues: [Double] = {
            var arr: [Double] = []
            var t = range.start
            while t < range.end {
                // 같은 “버킷 키”를 만드는 규칙이 provider와 동일해야 합니다.
                // - .month: day 시작(00:00)
                // - .year: month 시작(1일 00:00) -> 여기선 anchorDate 기준 월 경계로 fetch되어 올 걸 가정
                let key: Date
                switch granularity {
                case .month:
                    key = cal.startOfDay(for: t)
                case .year:
                    let comp = cal.dateComponents([.year, .month], from: t)
                    key = cal.date(from: comp)! // 월 시작
                }
                arr.append(byStart[key] ?? 0)
                t = t.addingTimeInterval(step)
            }
            return arr
        }()

        // === 4) 비어있거나 전부 0 처리 ===
        let hasEnough = denseValues.count >= 2
        let allZero   = denseValues.allSatisfy { $0 == 0 }
        guard hasEnough, !allZero else {
            chartView.configure(series: .init(startDate: range.start, step: step, values: []), maxY: 1)
            setNoDataVisible(true, message: "No data available")
            axisOverlay.configure(seriesStart: range.start, step: step, count: 0, maxY: 1, granularity: granularity, calendar: cal)
            return
        }

        // === 5) maxY 계산: 데이터기반 vs provider hint ===
        let dataMax = denseValues.max() ?? 1
        let hinted  = provider.maxY(for: granularity)
        let maxY    = max(dataMax, hinted, 1)

        chartView.pointsPerStep = (granularity == .month) ? 10 : 24
        chartView.configure(
            series: .init(startDate: range.start, step: step, values: denseValues),
            maxY: maxY
        )
        setNoDataVisible(false)

        // === 6) 축/라벨 오버레이 갱신 ===
        axisOverlay.plotInset = chartView.plotInset
        axisOverlay.configure(
            seriesStart: range.start,
            step: step,
            count: denseValues.count,
            maxY: maxY,
            granularity: granularity,
            calendar: cal
        )
    }

    // MARK: - 보조
    
  
    private func periodStart(for date: Date, granularity: StatsGranularity) -> Date {
        switch granularity {
        case .month: return cal.dateInterval(of: .month, for: date)!.start
        case .year:  return cal.dateInterval(of: .year,  for: date)!.start
        }
    }
    private func interval(for date: Date, granularity: StatsGranularity) -> DateInterval {
        switch granularity {
        case .month: return cal.dateInterval(of: .month, for: date)!
        case .year:  return cal.dateInterval(of: .year,  for: date)!
        }
    }
}

//MARK: - Bindo Repository Provider
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
        switch granularity {
        case .month: return 100
        case .year:  return 1000
        }
    }

    func title(for start: Date, granularity: StatsGranularity) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = (granularity == .month) ? "yyyy.MM" : "yyyy"
        return df.string(from: start)
    }
}

