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
    private let repo: BindoRepository = CoreDataBindoRepository()
    private lazy var ctx = Persistence.shared.viewContext

    // FRC: Bindo 최신 생성순
    private lazy var frc: NSFetchedResultsController<Bindo> = {
        let req: NSFetchRequest<Bindo> = Bindo.fetchRequest()   // 제네릭 명시
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
        performFetch()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = AppTheme.Color.main3.withAlphaComponent(0.2)
        tableView.rowHeight = 80
        tableView.estimatedRowHeight = 80   // 성능 최적화용

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
    
    // MARK: - Table Cell Tools
    private lazy var currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .none
        //TODO: - local currency depending on setting?
//        f.numberStyle = .currency
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
        frc.sections?.count ?? 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        frc.sections?[section].numberOfObjects ?? 0
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "BindoListCell",
                                                 for: indexPath) as! BindoListCell
        cell.contentView.alpha = 1.0
        let entity = frc.object(at: indexPath)
        let vm = makeRowDisplay(for: entity)

        cell.configure(name: vm.name, amount: vm.amountText, next: vm.leftText, interval: vm.rightText)
        let pay = (try? (repo as? CoreDataBindoRepository)?.effectivePay(for: entity)) ?? (next: nil, last: nil, end: nil)
        cell.setProgress(start: entity.startDate, next: pay.next)
        cell.backgroundColor = .clear
        cell.selectionStyle = .default
        return cell
    }
    
    // MARK: - Row display helpers
    private struct RowDisplay {
        let name: String
        let amountText: String
        let leftText: String
        let rightText: String
    }

    private func makeRowDisplay(for e: Bindo) -> RowDisplay {
        let name = e.name ?? "-"
        let amount = (e.amount as Decimal?) ?? 0
        let amountText = currencyFormatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"

        let pay = (try? (repo as? CoreDataBindoRepository)?.effectivePay(for: e)) ?? (next: nil, last: nil, end: nil)
        let left = makePayDayLeftText(next: pay.next, last: pay.last)
        let right = makeRightDaysText(for: e, next: pay.next, last: pay.last, end: pay.end)

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
            if let pair = try? (repo as? CoreDataBindoRepository)?.nextTwoOccurrences(for: e),
               let first = pair.first,
               cal.isDate(first, inSameDayAs: nextDay),
               pair.second == nil {
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
                                    // 사용자가 취소하면 알파 복구
                                    self?.restoreCellAlphaIfVisible(at: indexPath)
                                    done(false)
                                },
                                .init(title: "Delete", style: .destructive) { [weak self] in
                                    guard let self else { done(false); return }
                                    // 페이드아웃 스냅샷
                                    self.fadeOutCellSnapshot(at: indexPath)

                                    guard let id = entity.id else { done(false); return }
                                    do {
                                        try self.repo.delete(id: id)
                                        // FRC가 실제 row 삭제 애니메이션 처리
                                        let h = UIImpactFeedbackGenerator(style: .light)
                                        h.impactOccurred()
                                        done(true)
                                    } catch {
                                        // 실패 시 알파 복구 + 에러 표시
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

        // 셀 내용은 잠깐 숨기고(겹침 방지), 스냅샷으로 페이드
        cell.contentView.alpha = 0

        guard let snap = cell.contentView.snapshotView(afterScreenUpdates: false) else { return }
        // 스냅샷을 테이블 좌표계로 맞춰서 덮어씌움
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

// MARK: - FRC Delegate (테이블 자동 갱신)
extension MainVC: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard tableView.window != nil else { return }
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard tableView.window != nil else { return }
        tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?, for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        guard tableView.window != nil else { return }
        switch type {
        case .insert:
            if let new = newIndexPath { tableView.insertRows(at: [new], with: .automatic) }
        case .delete:
            if let idx = indexPath { tableView.deleteRows(at: [idx], with: .automatic) }
        case .move:
            if let idx = indexPath { tableView.deleteRows(at: [idx], with: .automatic) }
            if let new = newIndexPath { tableView.insertRows(at: [new], with: .automatic) }
        case .update:
            if let idx = indexPath { tableView.reloadRows(at: [idx], with: .automatic) }
        @unknown default:
            tableView.reloadData()
        }
    }
}
