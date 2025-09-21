//
//  CalendarVC.swift
//  Bindo
//
//  Created by Sean Choi on 9/9/25.
//

import UIKit


/// 외부(Repo/CoreData)에서 달 범위의 이벤트를 공급하기 위한 인터페이스
public protocol CalendarEventSource: AnyObject {
    /// 주어진 날짜 구간에 속하는 이벤트들을 반환
    func events(in interval: DateInterval) -> [CalendarEvent]
}


class CalendarVC: BaseVC {
    
    //Outlets
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var calendarView: UICollectionView!
    
    @IBOutlet weak var monthLabel: UILabel!
    @IBOutlet weak var dismissButton: UIButton!
    
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var prevButton: UIButton!
    private lazy var titleTapButton: UIButton = {
        var cfg = UIButton.Configuration.plain()
        cfg.cornerStyle = .capsule
        cfg.baseBackgroundColor = .clear
        cfg.baseForegroundColor = AppTheme.Color.accent
        cfg.contentInsets = .zero

        let b = UIButton(configuration: cfg)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.isHidden = true
        b.alpha = 0

        b.layer.borderWidth = 1
        b.layer.cornerRadius = 12
        b.layer.borderColor = AppTheme.Color.background.cgColor

        b.addAction(UIAction { [weak self] _ in
            self?.jumpToCurrentMonth()
        }, for: .touchUpInside)
        return b
    }()
    
    // Dependencies
    var eventSource: CalendarEventSource?
    private let viewContext = Persistence.shared.viewContext
    
    //Properties
    private var currentMonth: Date = Date()  // 현재 표시 중인 월(아무 날짜든 OK)
    private var gridFirstDay: Date = Date()  // 그리드 첫 칸 날짜(전달 포함)
    private var gridLastDay: Date = Date()   // 그리드 마지막 칸 날짜(다음달 포함)
    private var eventsByDay: [Date: [CalendarEvent]] = [:] // startOfDay 키
    private var days: [DayInfo] = []            // 캘린더 셀용 UI 모델
    
    //Collection Cell
    private let columns = 7
    private let rows = 6
    private let hSpacing: CGFloat = 6    // 열 사이 간격
    private let vSpacing: CGFloat = 10  // 행 사이 간격
    
    private lazy var outsideTapGR: UITapGestureRecognizer = {
        let g = UITapGestureRecognizer(target: self, action: #selector(handleOutsideTap(_:)))
        g.cancelsTouchesInView = false
        g.delegate = self
        return g
    }()
    
    //Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        if eventSource == nil {
            let repo = CoreDataBindoRepository(context: Persistence.shared.viewContext)
            eventSource = RepoEventSource(repo: repo) // CalendarEventsRepository만 의존
        }
        style()
        wireEvents()
        setupCollection()
        reloadMonth(animated: false)
        addSwipeGestures()
        view.addGestureRecognizer(outsideTapGR)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidChange(_:)),
            name: .NSManagedObjectContextObjectsDidChange,
            object: viewContext
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadMonth(animated: false)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self,
            name: .NSManagedObjectContextObjectsDidChange,
            object: viewContext)
    }
    
    @objc private func contextDidChange(_ note: Notification) {
        // 현재 그리드 범위 안의 변경인지까지 필터링 가능하지만 우선 전체 리로드
        reloadMonth(animated: false)
    }
    
    //Outlet Methods
    @IBAction func dismissButtonPressed(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    
    //User Defined Methods
    private func style() {
        
        // 상단 뷰 라운드
        topView.layer.cornerRadius = AppTheme.Corner.l
        topView.layer.cornerCurve = .continuous
        topView.clipsToBounds = true
        
        if titleTapButton.superview == nil {
            topView.addSubview(titleTapButton)
            // 라벨 뒤로 넣어 배경만 보이게
            if let label = monthLabel {
                topView.insertSubview(titleTapButton, belowSubview: label)
                NSLayoutConstraint.activate([
                    titleTapButton.leadingAnchor.constraint(equalTo: label.leadingAnchor, constant: -2),
                    titleTapButton.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: 2),
                    titleTapButton.topAnchor.constraint(equalTo: label.topAnchor, constant: -4),
                    titleTapButton.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
                    titleTapButton.centerYAnchor.constraint(equalTo: label.centerYAnchor)
                ])
            } else {
                // 라벨 연결이 없을 때 안전 대체(상단 오른쪽)
                topView.addSubview(titleTapButton)
                NSLayoutConstraint.activate([
                    titleTapButton.topAnchor.constraint(equalTo: topView.topAnchor, constant: 8),
                    titleTapButton.trailingAnchor.constraint(equalTo: topView.trailingAnchor, constant: -8),
                    titleTapButton.heightAnchor.constraint(equalToConstant: 28),
                    titleTapButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
                ])
            }
        }
        
        // 월 라벨
        monthLabel.font = AppTheme.Font.secondaryTitle
        monthLabel.textColor = AppTheme.Color.main1
        
        // 버튼
        func configButton(_ btn: UIButton, name: String) {
            var cfg = UIButton.Configuration.plain()
            cfg.preferredSymbolConfigurationForImage = .init(pointSize: 24, weight: .thin, scale: .medium)
            cfg.baseForegroundColor = AppTheme.Color.accent
            cfg.image = UIImage(systemName: name)
            btn.configuration = cfg
        }
        configButton(prevButton, name: "chevron.left")
        configButton(nextButton, name: "chevron.right")
    }
    
    // MARK: - Wiring
    private func wireEvents() {
        prevButton.addAction(UIAction { [weak self] _ in
            self?.shiftMonth(by: -1)
        }, for: .touchUpInside)
        
        nextButton.addAction(UIAction { [weak self] _ in
            self?.shiftMonth(by: 1)
        }, for: .touchUpInside)
    }
    
    private func addSwipeGestures() {
        let left = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        left.direction = .left
        let right = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        right.direction = .right
        calendarView.addGestureRecognizer(left)
        calendarView.addGestureRecognizer(right)
    }
    
    @objc private func handleSwipe(_ g: UISwipeGestureRecognizer) {
        switch g.direction {
        case .left:  shiftMonth(by: 1)
        case .right: shiftMonth(by: -1)
        default: break
        }
    }
    
    @objc private func jumpToCurrentMonth() {
        currentMonth = CalendarUtils.startOfMonth(Date())
        reloadMonth(animated: true)
    }

    // (옵션) 타이틀 라벨 탭도 허용했을 때
    @objc private func jumpToCurrentMonthViaTap() { jumpToCurrentMonth() }
    
    
    
    // MARK: - Data
    private func shiftMonth(by delta: Int) {
        if let m = CalendarUtils.cal.date(byAdding: .month, value: delta, to: currentMonth) {
            currentMonth = m
            reloadMonth(animated: true)
        }
    }
    
    private func reloadMonth(animated: Bool) {
        // 월 텍스트
        let comps = CalendarUtils.cal.dateComponents([.year, .month], from: currentMonth)
        let ym = String(format: "%04d • %02d", comps.year ?? 0, comps.month ?? 0)
        monthLabel.text = ym

        // 그리드 범위 (전달 말일~다음달 초일 포함)
        let (first, last) = CalendarUtils.monthGridInterval(for: currentMonth)
        gridFirstDay = first
        gridLastDay = last

        // 이벤트 로드 (마지막 칸 다음날 0시까지)
        let interval = DateInterval(
            start: first,
            end: CalendarUtils.cal.date(byAdding: .day, value: 1, to: last)!
        )
        if let source = eventSource {
            let events = source.events(in: interval)
            eventsByDay = Dictionary(grouping: events, by: { CalendarUtils.cal.startOfDay(for: $0.date) })
        } else {
            eventsByDay = [:]
        }

        // 42칸 DayInfo 빌드
        var tmp: [DayInfo] = []
        tmp.reserveCapacity(42)
        for i in 0..<42 {
            let d = CalendarUtils.cal.date(byAdding: .day, value: i, to: first)!
            let dayNumber = CalendarUtils.cal.component(.day, from: d)
            let inCurrent = CalendarUtils.cal.isDate(d, equalTo: currentMonth, toGranularity: .month)
            let today = CalendarUtils.cal.isDateInToday(d)
            tmp.append(DayInfo(date: d, day: dayNumber, inCurrentMonth: inCurrent, isToday: today))
        }
        days = tmp

        // 리로드
        if animated {
            UIView.transition(with: calendarView, duration: 0.22, options: .transitionCrossDissolve) {
                self.calendarView.reloadData()
            }
        } else {
            calendarView.reloadData()
        }
        updateCurrentBadge()
    }
    
    
    private func setupCollection() {
        // 컬렉션뷰 기본 설정
        calendarView.dataSource = self
        calendarView.delegate   = self
        calendarView.backgroundColor = .clear
        calendarView.alwaysBounceVertical = false
        calendarView.showsVerticalScrollIndicator = false
        calendarView.isScrollEnabled = false    // 월은 스와이프 제스처로 전환
        
        calendarView.register(CalendarDayCell.self, forCellWithReuseIdentifier: "DayCell")
        
        // Flow 레이아웃 보정 (스토리보드 기본 Flow를 쓰는 경우라도 안전하게)
        if let flow = calendarView.collectionViewLayout as? UICollectionViewFlowLayout {
            flow.scrollDirection = .vertical
            flow.minimumInteritemSpacing = 0
            flow.minimumLineSpacing = 0
            flow.sectionInset = .zero
        }
    }
    
    
    private func isCurrentDisplayedMonth() -> Bool {
        CalendarUtils.cal.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    private func updateCurrentBadge() {
        let shouldShow = !isCurrentDisplayedMonth()
        guard shouldShow != !titleTapButton.isHidden else { return }

        if shouldShow {
            monthLabel.textColor = AppTheme.Color.main1
            titleTapButton.isHidden = false
            UIView.animate(withDuration: 0.18) { self.titleTapButton.alpha = 1; self.monthLabel.textColor = AppTheme.Color.accent }
        } else {
            UIView.animate(withDuration: 0.18, animations: {
                self.monthLabel.textColor = AppTheme.Color.main1
                self.titleTapButton.alpha = 0
            }, completion: { _ in
                self.monthLabel.textColor = AppTheme.Color.main1
                self.titleTapButton.isHidden = true
            })
        }
    }
    
    
}

// MARK: - UICollectionViewDataSource & DelegateFlowLayout
extension CalendarVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // 7x6 = 42칸 고정
        return 42
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "DayCell",
            for: indexPath
        ) as? CalendarDayCell else { return UICollectionViewCell() }

        let dayInfo = days[indexPath.item]
        let date = dayInfo.date
        let events = eventsByDay[CalendarUtils.cal.startOfDay(for: date)] ?? [] 

        cell.configure(day: dayInfo.day,
                       date: date,
                       inCurrentMonth: dayInfo.inCurrentMonth,
                       isToday: dayInfo.isToday,
                       events: events)

        cell.onTapEvents = { [weak self] date, events in
            guard let self = self else { return }
            let df = DateFormatter()
            df.calendar = CalendarUtils.cal
            df.locale = .current
            df.dateFormat = "yyyy・MM・dd"

            let title = df.string(from: date)
            let message = events.map(\.title).joined(separator: "\n")
            
            var cfg = AppAlertConfiguration()
            cfg.borderColor = AppTheme.Color.main3
            AppAlert.present(on: self,
                             title: title,
                             message: message,
                             actions: [.init(title: NSLocalizedString("calendar.ok", comment: "CalendarVC.swift: OK button"),style: .cancel)],
                             configuration: cfg)
            
//            self.present(alert, animated: true)
        }

        return cell
    }
    
    func collectionView(_ cv: UICollectionView,
                        layout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let totalH = hSpacing * CGFloat(columns - 1)
        let w = floor((cv.bounds.width - totalH) / CGFloat(columns))
        let h = w * 1.45   // ← 세로 여유(배지 2~3줄 고려) 1.30~1.45로 조정
        return CGSize(width: w, height: h)
    }
    
    func collectionView(_ cv: UICollectionView,
                        layout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { hSpacing }

    func collectionView(_ cv: UICollectionView,
                        layout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat { vSpacing }
}


extension CalendarVC: UIGestureRecognizerDelegate {
    @objc private func handleOutsideTap(_ g: UITapGestureRecognizer) {
        guard g.state == .ended else { return }
        guard presentedViewController == nil, !isBeingDismissed else { return }

        let p = g.location(in: view)
        if !topView.frame.contains(p) {
            dismiss(animated: true)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}



//MARK: - Bindo Repository Adaptor
final class RepoEventSource: CalendarEventSource {
    private let repo: CalendarEventsRepository
    private let cal = CalendarUtils.cal
    init(repo: CalendarEventsRepository) { self.repo = repo }
    
    func events(in interval: DateInterval) -> [CalendarEvent] {
        (try? repo.fetchCalendarEvents(in: interval, calendar: cal)) ?? []
    }
}



//MARK: - Calendar Event, Calendar Unit
/// 캘린더에 표시할 이벤트(= 구독 Payday)
public struct CalendarEvent: Hashable {
    public let date: Date
    public let title: String   // 구독 이름
    public init(date: Date, title: String) {
        self.date = date
        self.title = title
    }
}

struct DayInfo {
    let date: Date
    let day: Int
    let inCurrentMonth: Bool
    let isToday: Bool
}

import Foundation

enum CalendarUtils {
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        c.timeZone = .current
        return c
    }()
    
    /// 해당 월의 첫날(자정)
    static func startOfMonth(_ date: Date) -> Date {
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps)!
    }
    
    /// 해당 월의 마지막날(자정)
    static func endOfMonth(_ date: Date) -> Date {
        let start = startOfMonth(date)
        let next = cal.date(byAdding: DateComponents(month: 1, day: 0), to: start)!
        return cal.date(byAdding: .day, value: -1, to: next)!
    }
    
    /// 그리드용: 7×6 채우기 위해, 전달말일/다음달초 포함한 표시 범위
    static func monthGridInterval(for date: Date) -> (first: Date, last: Date) {
        let start = startOfMonth(date)
        let weekday = cal.component(.weekday, from: start) // 1: Sun ... 7: Sat
        let leading = (weekday - cal.firstWeekday + 7) % 7
        let first = cal.date(byAdding: .day, value: -leading, to: start)!
        
        let end = endOfMonth(date)
        let lastWeekday = cal.component(.weekday, from: end)
        let trailing = (7 - ((lastWeekday - cal.firstWeekday + 7) % 7) - 1 + 7) % 7
        let last = cal.date(byAdding: .day, value: trailing, to: end)!
        return (first, last)
    }
    
    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let s = cal.startOfDay(for: a)
        let e = cal.startOfDay(for: b)
        return cal.dateComponents([.day], from: s, to: e).day ?? 0
    }
    
    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        cal.isDate(a, inSameDayAs: b)
    }
}

