//
//  MainVC.swift
//  Bindo
//
//  Created by Sean Choi on 9/7/25.
//

import UIKit
import CoreData

final class MainVC: UIViewController {

    // MARK: - Outlets
    @IBOutlet private weak var headView: UIView!
    @IBOutlet private weak var topDateLabel: UILabel!
    @IBOutlet private weak var tableView: UITableView!

    // MARK: - Properties
    private let menu = FloatingActionMenu()
    private let repo: (BindoRepository & RefreshRepository) = CoreDataBindoRepository()
    private lazy var ctx = Persistence.shared.viewContext

    // FRC: Bindo 최신 생성순
    private lazy var frc: NSFetchedResultsController<Bindo> = {
        let req: NSFetchRequest<Bindo> = Bindo.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let frc = NSFetchedResultsController(
            fetchRequest: req,
            managedObjectContext: ctx,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        frc.delegate = self
        return frc
    }()
    
    private var isOnWindow: Bool { isViewLoaded && view.window != nil }
    private var needsReloadOnAppear = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTable()
        setupFloatingMenu()
        applyAppearance()
        wireLongPressDeletion()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            try repo.ensureAllCurrentCycles()  // 저장/변경 가능
            try frc.performFetch()             // 최신 스냅샷 반영
            tableView.reloadData()             // 데이터소스와 UI 일치
            needsReloadOnAppear = false
        } catch {
            print("refresh/fetch error:", error)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if needsReloadOnAppear {
            try? frc.performFetch()
            tableView.reloadData()
            needsReloadOnAppear = false
        }
        showMenu()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        headView.layer.cornerRadius = AppTheme.Corner.xl
        headView.layer.cornerCurve = .continuous
        headView.clipsToBounds = true
    }

    // MARK: - Fetch
    private func performFetch() {
        do { try frc.performFetch() } catch {
            print("FRC fetch error:", error)
        }
        if tableView.window != nil {
            tableView.reloadData()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.tableView.window != nil else { return }
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Actions
    /// + 버튼 → UpdateBindoVC(컨테이너) 푸시
    @objc private func plusTapped() {
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "UpdateBindoVC") as? UpdateBindoVC else { return }
        navigationController?.pushViewController(vc, animated: true)
        hideMenu()
    }

    @objc private func calendarButtonTapped() {
        guard let calendarVC = storyboard?.instantiateViewController(withIdentifier: "CalendarVC") as? CalendarVC else { return }
        calendarVC.modalPresentationStyle = .overCurrentContext
        calendarVC.modalTransitionStyle = .crossDissolve
        present(calendarVC, animated: true)
    }

    @objc private func statsButtonTapped() {
        guard let statsVC = storyboard?.instantiateViewController(withIdentifier: "StatsVC") as? StatsVC else { return }
        statsVC.modalPresentationStyle = .overCurrentContext
        statsVC.modalTransitionStyle = .crossDissolve
        present(statsVC, animated: true)
    }

    @objc private func setupButtonTapped() {
        guard let settingVC = storyboard?.instantiateViewController(withIdentifier: "SettingsVC") as? SettingsVC else { return }
        settingVC.modalPresentationStyle = .overCurrentContext
        settingVC.modalTransitionStyle = .crossDissolve
        present(settingVC, animated: true)
    }

    // MARK: - UI
    private func applyAppearance() {
        // 배경
        view.backgroundColor = AppTheme.Color.background

        // 상단 보조 날짜 라벨
        topDateLabel.font = AppTheme.Font.caption
        topDateLabel.textColor = AppTheme.Color.main2
        topDateLabel.text = dateFormatter.string(from: Date())

        // 네비게이션 공통 스타일 적용
        AppNavigation.apply(to: navigationController)

        // 타이틀 뷰
        navigationItem.titleView = AppNavigation.makeBottomAlignedTitle("Bindos", offsetY: 10)

        // 오른쪽 + 버튼 (아이콘만)
        let addItem = AppNavigation.BarItem(
            systemImage: "plus",
            accessibilityLabel: "Add",
            action: UIAction { [weak self] _ in self?.plusTapped() }
        )
        let right = AppNavigation.makeButton(addItem, style: .plainAccent)
        AppNavigation.setItems(right: [right], for: self)
    }

    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = 80
        tableView.estimatedRowHeight = 80

        tableView.register(BindoListCell.self, forCellReuseIdentifier: "BindoListCell")

        let refresh = UIRefreshControl()
        refresh.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.performFetch()
                self.tableView.refreshControl?.endRefreshing()
            }
        }, for: .valueChanged)
        tableView.refreshControl = refresh
    }
    
    // MARK: - Formatters
    private lazy var currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        // 설정에서 현지 통화 지원 전까지는 숫자만
        f.numberStyle = .none
        f.locale = .current
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy/MM/dd"
        return df
    }()
    

    // MARK: - Floating Menu
    private func setupFloatingMenu() {
        guard menu.superview == nil else { return }
        let host: UIView = navigationController?.view ?? view
        menu.dismissOnBackgroundTap = true
        menu.alpha = 0.92
        menu.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(menu)

        NSLayoutConstraint.activate([
            menu.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            menu.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            menu.topAnchor.constraint(equalTo: host.topAnchor),
            menu.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])

        menu.onCalendar = { [weak self] in self?.calendarButtonTapped() }
        menu.onStats    = { [weak self] in self?.statsButtonTapped() }
        menu.onSettings = { [weak self] in self?.setupButtonTapped() }

        host.bringSubviewToFront(menu)
    }
    
    private func showMenu(animated: Bool = true) {
        guard menu.isHidden else { return }
        menu.alpha = 0
        menu.isHidden = false
        let target: CGFloat = 0.92
        UIView.animate(withDuration: animated ? 0.18 : 0) {
            self.menu.alpha = target
        }
    }

    private func hideMenu(animated: Bool = true) {
        guard !menu.isHidden else { return }
        UIView.animate(withDuration: animated ? 0.18 : 0, animations: {
            self.menu.alpha = 0
        }, completion: { _ in
            self.menu.isHidden = true
        })
    }

    // MARK: - Long-press 삭제
    private func wireLongPressDeletion() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.6
        tableView.addGestureRecognizer(longPress)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        let obj = frc.object(at: indexPath)

        var cfg = AppAlertConfiguration()
        cfg.borderColor = AppTheme.Color.main3
        cfg.icon = UIImage(systemName: "trash.fill")

        AppAlert.present(on: self,
                         title: "Delete?",
                         message: "Remove \"\(obj.name ?? "Item")\"",
                         actions: [
                            .init(title: "Cancel", style: .cancel, handler: nil),
                            .init(title: "Delete", style: .destructive, handler: { [weak self] in
                                self?.deleteBindo(obj, at: indexPath)
                            })
                         ],
                         configuration: cfg)
    }

    private func deleteBindo(_ obj: Bindo, at indexPath: IndexPath? = nil) {
        //  시각 효과: 삭제 전 스냅샷 페이드
        if let idx = indexPath {
            fadeOutCellSnapshot(at: idx)
        }

        guard let id = obj.id else {
            if let idx = indexPath { restoreCellAlphaIfVisible(at: idx) }
            return
        }

        do {
            try repo.delete(id: id)
            // FRC가 실제 row 삭제 애니메이션을 수행
            let h = UIImpactFeedbackGenerator(style: .light)
            h.impactOccurred()
        } catch {
            // 실패 시 알파 복구 + 에러 표시
            if let idx = indexPath { restoreCellAlphaIfVisible(at: idx) }
            AppAlert.present(on: self,
                             title: "Error",
                             message: error.localizedDescription,
                             actions: [.init(title: "OK", style: .primary)])
        }
    }
}

// MARK: - TableView DataSource
extension MainVC: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return frc.sections?.count ?? 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return frc.sections?[section].numberOfObjects ?? 0
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "BindoListCell",
                                                 for: indexPath) as! BindoListCell
        cell.contentView.alpha = 1.0
        let entity = frc.object(at: indexPath)

        let vm = makeRowDisplay(for: entity)
        cell.configure(name: vm.name, amount: vm.amountText, next: vm.leftText, interval: vm.rightText)

        // 진행도: 현재 구간(start~next)로 표시
        let period = currentPeriod(for: entity)
        cell.setProgress(start: period.start, next: period.end, endAt: entity.endAt)
        
        cell.backgroundColor = .clear
        cell.selectionStyle = .default
        return cell
    }
    
    // MARK: - Row display helpers
    private struct RowDisplay {
        let name: String
        let amountText: String
        let leftText: String   // Pay Day 라벨
        let rightText: String  // Days/Expires 라벨
    }

    private func makeRowDisplay(for e: Bindo) -> RowDisplay {
        let name = e.name ?? "-"

        // 금액: useBase면 baseAmount, 아니면 '다음 Occurence의 payAmount' 우선 사용
        let nextOcc = nextOccurrence(for: e)
        let amountDecimal: Decimal = {
            if e.useBase, let base = e.baseAmount { return base.decimalValue }
            if let pay = nextOcc?.payAmount { return pay.decimalValue }
            return e.baseAmount?.decimalValue ?? 0
        }()
        let amountText = currencyFormatter.string(from: amountDecimal as NSDecimalNumber) ?? "\(amountDecimal)"

        // 날짜 표시
        _ = Calendar.current
        let next = nextOcc?.endDate
        let last = lastOccurrence(for: e)?.endDate

        let left = makePayDayLeftText(next: next, last: last)
        let right = makeRightDaysText(for: e, next: next, last: last, end: e.endAt)

        return .init(name: name, amountText: amountText, leftText: left, rightText: right)
    }

    // 왼쪽 하단: "Pay Day"
    private func makePayDayLeftText(next: Date?, last: Date?) -> String {
        let cal = Calendar.current
        if let next {
            return cal.isDateInToday(next) ? "Pay Day: Today" : "Pay Day: \(dateFormatter.string(from: next))"
        }
        if let last {
            return "Pay Day: \(dateFormatter.string(from: last))"
        }
        return "Pay Day: —"
    }

    // 오른쪽 하단: Days/Expires 로직
    private func makeRightDaysText(for e: Bindo,
                                   next: Date?, last: Date?, end: Date?) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        func dayDiff(_ a: Date, _ b: Date) -> Int { cal.dateComponents([.day], from: a, to: b).day ?? 0 }

        // 1) next 없음 → 과거 상태
        guard let next = next else {
            if let last { return "Expired at \(dateFormatter.string(from: last))" }
            return "Expired"
        }

        let nextDay = cal.startOfDay(for: next)

        // 2) Date View: next가 '마지막'이면 Expires
        if (e.option ?? "interval").lowercased() == "date" {
            if let end = end, cal.isDate(end, inSameDayAs: nextDay) {
                return cal.isDateInToday(nextDay)
                ? "Expires today"
                : "Expires in \(max(0, dayDiff(today, nextDay))) day(s)"
            }
        }

        // 3) endDate 우선 처리 (Interval/Date 공통)
        if let end {
            let endDay = cal.startOfDay(for: end)
            if cal.isDateInToday(endDay) { return "Expires today" }
            if endDay > today         { return "Expires in \(dayDiff(today, endDay)) day(s)" }
            if endDay < today         { return "Expired at \(dateFormatter.string(from: endDay))" }
        }

        // 4) end 없음 → next 까지 남은 일수
        let d = dayDiff(today, nextDay)
        return d <= 0 ? "0 day(s) left" : "\(d) day(s) left"
    }

    // 현재 진행중인 구간 (진행도 표시용)
    private func currentPeriod(for e: Bindo) -> (start: Date?, end: Date?) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        guard let occs = (e.occurrences as? Set<Occurence>), !occs.isEmpty else {
            return (nil, nil)
        }

        // 다음 결제 주기
        let next = occs
            .compactMap { $0.endDate }
            .filter { cal.startOfDay(for: $0) >= today }
            .min()

        // 해당 next에 매칭되는 startDate
        if let next {
            let start = occs.first(where: { $0.endDate != nil && cal.isDate($0.endDate!, inSameDayAs: next) })?.startDate
            return (start, next)
        }

        // 미래가 없으면 가장 최근 과거 구간
        if let last = occs
            .compactMap({ $0.endDate })
            .filter({ cal.startOfDay(for: $0) <= today })
            .max() {

            let start = occs.first(where: { $0.endDate != nil && cal.isDate($0.endDate!, inSameDayAs: last) })?.startDate
            return (start, last)
        }

        return (nil, nil)
    }

    // 다음/마지막 Occurence 계산
    private func nextOccurrence(for e: Bindo) -> Occurence? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let occs = (e.occurrences as? Set<Occurence>), !occs.isEmpty else { return nil }

        // endAt이 있으면 그 이후는 제외
        let endAt = e.endAt.map { cal.startOfDay(for: $0) }

        return occs
            .filter { $0.endDate != nil }
            .filter { occ in
                let day = cal.startOfDay(for: occ.endDate!)
                if let endAt { guard day <= endAt else { return false } }
                return day >= today
            }
            .sorted { $0.endDate! < $1.endDate! }
            .first
    }

    private func lastOccurrence(for e: Bindo) -> Occurence? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let occs = (e.occurrences as? Set<Occurence>), !occs.isEmpty else { return nil }

        return occs
            .filter { $0.endDate != nil && cal.startOfDay(for: $0.endDate!) <= today }
            .sorted { $0.endDate! < $1.endDate! }
            .last
    }
}

// MARK: - TableView Delegate
extension MainVC: UITableViewDelegate {
    func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "UpdateBindoVC") as? UpdateBindoVC else { return }
        let obj = frc.object(at: indexPath)
        vc.editingID = obj.id
        hideMenu(animated: true)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tv: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        let entity = frc.object(at: indexPath)

        let delete = AppSwipe.deleteAction { [weak self] _, _, done in
            guard let self else { done(false); return }

            var cfg = AppAlertConfiguration()
            cfg.icon = UIImage(systemName: "trash.fill")
            cfg.borderColor = AppTheme.Color.main3

            AppAlert.present(on: self,
                             title: "Delete?",
                             message: "Remove \"\(entity.name ?? "Item")\"",
                             actions: [
                                .init(title: "Cancel", style: .cancel) { [weak self] in
                                    self?.restoreCellAlphaIfVisible(at: indexPath)
                                    done(false)
                                },
                                .init(title: "Delete", style: .destructive) { [weak self] in
                                    guard let self else { done(false); return }
                                    self.fadeOutCellSnapshot(at: indexPath)

                                    guard let id = entity.id else { done(false); return }
                                    do {
                                        try self.repo.delete(id: id)
                                        let h = UIImpactFeedbackGenerator(style: .light)
                                        h.impactOccurred()
                                        done(true)
                                    } catch {
                                        self.restoreCellAlphaIfVisible(at: indexPath)
                                        AppAlert.present(on: self,
                                                         title: "Error",
                                                         message: error.localizedDescription,
                                                         actions: [.init(title: "OK", style: .primary)])
                                        done(false)
                                    }
                                }
                             ],
                             configuration: cfg)
        }
        return AppSwipe.trailing([delete], fullSwipe: true)
    }
    
    // Delete Animation Helpers
    private func fadeOutCellSnapshot(at indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }

        cell.contentView.alpha = 0

        guard let snap = cell.contentView.snapshotView(afterScreenUpdates: false) else { return }
        let frameInTable = tableView.convert(cell.contentView.bounds, from: cell.contentView)
        snap.frame = frameInTable
        tableView.addSubview(snap)

        UIView.animate(withDuration: 0.18,
                       delay: 0,
                       options: [.curveEaseOut],
                       animations: {
                           snap.alpha = 0.0
                           snap.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                       },
                       completion: { _ in
                           snap.removeFromSuperview()
                       })
    }

    private func restoreCellAlphaIfVisible(at indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.12) {
                cell.contentView.alpha = 1.0
            }
        }
    }
}

// MARK: - FRC Delegate (정석 버전)
extension MainVC: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard isOnWindow else { needsReloadOnAppear = true; return }
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                        didChange anObject: Any,
                        at indexPath: IndexPath?,
                        for type: NSFetchedResultsChangeType,
                        newIndexPath: IndexPath?) {
            guard isOnWindow else { needsReloadOnAppear = true; return }
            switch type {
            case .insert:
                if let new = newIndexPath { tableView.insertRows(at: [new], with: .automatic) }
            case .delete:
                if let idx = indexPath   { tableView.deleteRows(at: [idx], with: .automatic) }
            case .update:
                if let idx = indexPath   { tableView.reloadRows(at: [idx], with: .automatic) }
            case .move:
                if let from = indexPath, let to = newIndexPath {
                    if from == to { tableView.reloadRows(at: [from], with: .automatic) }
                    else          { tableView.moveRow(at: from, to: to) }
                }
            @unknown default: break
            }
        }

        func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                        didChange sectionInfo: NSFetchedResultsSectionInfo,
                        atSectionIndex sectionIndex: Int,
                        for type: NSFetchedResultsChangeType) {
            guard isOnWindow else { needsReloadOnAppear = true; return }
            switch type {
            case .insert: tableView.insertSections(IndexSet(integer: sectionIndex), with: .automatic)
            case .delete: tableView.deleteSections(IndexSet(integer: sectionIndex), with: .automatic)
            default: break
            }
        }

        func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
            guard isOnWindow else { return }
            tableView.endUpdates()
        }
}
