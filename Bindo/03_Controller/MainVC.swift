//
//  MainVC.swift
//  Bindo
//
//  Created by Sean Choi on 9/7/25.
//

import UIKit
import CoreData

final class MainVC: BaseVC {

    // MARK: - UI
    @IBOutlet private weak var headView: UIView!
    @IBOutlet private weak var topDateLabel: UILabel!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet weak var filterBar: UIView!
    private let menu = FloatingActionMenu()
    private lazy var filterButton: UIButton = {
        var cfg = UIButton.Configuration.plain()
        cfg.cornerStyle = .medium
        cfg.image = UIImage(systemName: "line.3.horizontal.decrease")?
            .applyingSymbolConfiguration(actionSymbolConfig)
        cfg.imagePadding = 0
        cfg.baseForegroundColor = .systemGray2
        cfg.contentInsets = actionContentInsets

        let b = UIButton(configuration: cfg)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setPreferredSymbolConfiguration(actionSymbolConfig, forImageIn: .normal)

        // Outline (보더) 세팅
        b.backgroundColor = .clear
        b.layer.cornerRadius = 8
        b.layer.cornerCurve  = .continuous
        b.layer.borderWidth  = 1
        b.layer.borderColor  = UIColor.systemGray2.cgColor
        b.clipsToBounds      = true

        // 사이즈 제약(기존 액션 버튼과 동일)
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 22).isActive = true
        b.widthAnchor.constraint(greaterThanOrEqualToConstant: actionMinWidth).isActive = true
        b.setContentHuggingPriority(.defaultLow, for: .horizontal)
        b.setContentCompressionResistancePriority(.required, for: .horizontal)

        // 상태 업데이트(비활성화 시 연한 회색으로)
        b.configurationUpdateHandler = { btn in
            var c = btn.configuration ?? .plain()
            c.cornerStyle = .medium
            c.baseForegroundColor = btn.isEnabled ? .systemGray2 : .systemGray3
            btn.configuration = c

            btn.layer.borderColor = (btn.isEnabled ? UIColor.systemGray2 : UIColor.systemGray3).cgColor
            btn.layer.borderWidth = 1
            btn.layer.cornerRadius = 8
            btn.layer.cornerCurve  = .continuous
        }

        b.accessibilityLabel = "Filter"
        b.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)
        return b
    }()
    
    private let actionSymbolConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
    private let actionContentInsets = NSDirectionalEdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16)
    private let actionMinWidth: CGFloat = 35
    private func makeActionButton(
        symbol: String,
        baseBG: UIColor,
        baseFG: UIColor = AppTheme.Color.background,
        disabledBG: UIColor = .systemGray2,
        minHeight: CGFloat = 22,
        minWidth: CGFloat? = nil,
        accessibility: String,
        action: Selector,
        cornerStyle: UIButton.Configuration.CornerStyle = .medium,
        fixedCornerRadius: CGFloat? = 8
    ) -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.cornerStyle       = cornerStyle
        cfg.contentInsets     = actionContentInsets
        cfg.image             = UIImage(systemName: symbol)?.applyingSymbolConfiguration(actionSymbolConfig)
        cfg.imagePadding      = 0
        cfg.baseBackgroundColor = baseBG
        cfg.baseForegroundColor = baseFG

        let b = UIButton(configuration: cfg)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setPreferredSymbolConfiguration(actionSymbolConfig, forImageIn: .normal)

        // 사이즈 제약
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true
        let w = minWidth ?? actionMinWidth
        b.widthAnchor.constraint(greaterThanOrEqualToConstant: w).isActive = true
        b.setContentHuggingPriority(.defaultLow, for: .horizontal)
        b.setContentCompressionResistancePriority(.required, for: .horizontal)

        if let r = fixedCornerRadius {
            b.layer.cornerRadius = r
            b.layer.cornerCurve  = .continuous
            b.clipsToBounds = true
        }

        b.accessibilityLabel = accessibility
        b.addTarget(self, action: action, for: .touchUpInside)

        // 상태별 색 전환(기존 유지)
        b.configurationUpdateHandler = { btn in
            var c = btn.configuration ?? .filled()
            if btn.isEnabled {
                c.baseBackgroundColor = baseBG
                c.baseForegroundColor = baseFG
            } else {
                c.baseBackgroundColor = disabledBG
                c.baseForegroundColor = baseFG
            }
            // cornerStyle은 유지
            c.cornerStyle = cornerStyle
            // 색상 전환은 부드럽게
            let duration: TimeInterval = 0.1
            if btn.window != nil {
                UIView.transition(with: btn, duration: duration, options: .transitionCrossDissolve) {
                    btn.configuration = c
                }
            } else {
                btn.configuration = c
            }
            // 레이어 코너는 재적용(가끔 구성 갱신 시 초기화 방지)
            if let r = fixedCornerRadius {
                btn.layer.cornerRadius = r
                btn.layer.cornerCurve  = .continuous
            }
        }
        return b
    }
    
    private lazy var deleteButton: UIButton = makeActionButton(
        symbol: "trash", baseBG: AppTheme.Color.accent,
        baseFG: AppTheme.Color.background, disabledBG: .systemGray2,
        minHeight: 22, minWidth: actionMinWidth,
        accessibility: "Delete", action: #selector(deleteTapped)
    )

    private lazy var editButton: UIButton = makeActionButton(
        symbol: "square.and.pencil", baseBG: AppTheme.Color.main1,
        baseFG: AppTheme.Color.background, disabledBG: .systemGray2,
        minHeight: 22, minWidth: actionMinWidth,
        accessibility: "Edit", action: #selector(editTapped)
    )

    private lazy var cancelButton: UIButton = makeActionButton(
        symbol: "xmark", baseBG: AppTheme.Color.accent,
        baseFG: AppTheme.Color.background, disabledBG: AppTheme.Color.accent,
        minHeight: 22, minWidth: actionMinWidth,
        accessibility: "Cancel", action: #selector(cancelTapped)
    )
    
    
    
    // 오버레이. 특정 예외 뷰 영역은 통과(pointInside == false).
    private final class PassthroughOverlay: UIView {
        weak var targetVC: MainVC?
        weak var tableView: UITableView?
        var passButtons: [UIView] = []  // delete/edit/cancel 등

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            // 1) 액션 버튼은 통과 (편집 모드 유지)
            if targetVC?.isActiveScreen != true {
                return true
            }
            
            for v in passButtons {
                guard v.window != nil, !v.isHidden, v.alpha > 0.01 else { continue }
                let p = convert(point, to: v)
                if v.point(inside: p, with: event) { return false }
            }

            // 2) 셀 위면 통과(체크 토글을 위해)
            if let tv = tableView, tv.window != nil {
                let pInTable = convert(point, to: tv)
                if let ip = tv.indexPathForRow(at: pInTable) {
                    var rowRect = tv.rectForRow(at: ip)
                    rowRect = rowRect.insetBy(dx: 0, dy: -2) // 경계 여유
                    if rowRect.contains(pInTable) {
                        return false // 오버레이가 받지 않음 → 테이블이 처리
                    }
                }
            }

            // 3) 그 외(필터바/플로팅메뉴/네비바/빈 배경 등)는 오버레이가 터치 흡수 → 편집모드 종료
            return true
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            targetVC?.setEditingMode(false)
            super.touchesEnded(touches, with: event)
        }
    }
    

    // MARK: - Injection
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
    
    
    //MARK: - Properties
    private var isEditingMode = false
    private var selectedIDs = Set<UUID>()
    private var isOnWindow: Bool { isViewLoaded && view.window != nil }
    private var needsReloadOnAppear = false
    private enum Filter: String, CaseIterable {
        case all, active, expired, interval, date

        var title: String {
            switch self {
            case .all:      return "All"
            case .active:   return "Active"
            case .expired:  return "Expired"
            case .interval: return "Interval Mode"
            case .date:     return "Date Mode"
            }
        }
    }

    private let filterDefaultsKey = "MainVC.filter"
    private var currentFilter: Filter = .all
    private var longPressGR: UILongPressGestureRecognizer?
    private var suppressNextTapAfterLongPress = false
    private var editOverlay: PassthroughOverlay?
    

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTable()
        setupFloatingMenu()
        applyAppearance()
        wireLongPressForEditing()

        setupFilterBar()
        loadSavedFilterAndApply()
        
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsChanged), name: .settingsDidChange, object: nil)
        applySettingsAndReload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            try repo.ensureAllCurrentCycles()  // 저장/변경 가능
            applyFilterAndFetch()             // 최신 스냅샷 반영 + filter
            needsReloadOnAppear = false
        } catch {
            print("refresh/fetch error:", error)
        }
        resumeMainInteractions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
        if needsReloadOnAppear {
            applyFilterAndFetch()
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
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        suspendMainInteractions()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeEditOverlayIfNeeded()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .settingsDidChange, object: nil)
    }

    // MARK: - Fetch
    private func performFetch() {
        applyFilterAndFetch()
    }
    
    /// FRC에 predicate 적용 후 fetch+reload
    private func applyFilterAndFetch() {
        frc.fetchRequest.predicate = predicate(for: currentFilter)
        do {
            try frc.performFetch()
        } catch {
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
    
    private func performBatchDelete() {
        // 페이드 아웃 같은 이펙트는 생략(여러 개라 복잡해짐)
        var failed = false
        for id in selectedIDs {
            do { try repo.delete(id: id) }
            catch {
                failed = true
                print("delete failed:", error)
            }
        }
        selectedIDs.removeAll()
        updateActionButtons()
        setEditingMode(false)

        // FRC delegate가 테이블 갱신
        if failed {
            AppAlert.present(on: self,
                             title: "Error",
                             message: "Some items could not be deleted.",
                             actions: [.init(title: "OK", style: .primary)])
        }
    }
    
    
    //MARK: - Filter
    @objc private func filterButtonTapped() {
        presentFilterPicker()
    }

    @objc private func clearFilterTapped() {
        setFilter(.all, persist: true, animated: true)
    }

    // User Defaults
    private func loadSavedFilterAndApply() {
        let saved = UserDefaults.standard.string(forKey: filterDefaultsKey)
        let f = saved.flatMap { Filter(rawValue: $0) } ?? .all
        setFilter(f, persist: false, animated: false)
    }

    /// 필터를 세팅하고 저장/적용/버튼 상태까지 업데이트
    private func setFilter(_ f: Filter, persist: Bool, animated: Bool) {
        currentFilter = f
        if persist { UserDefaults.standard.set(f.rawValue, forKey: filterDefaultsKey) }

        applyFilterAndFetch()
    }
    
    private func presentFilterPicker() {
        let ac = UIAlertController(title: "Filter", message: nil, preferredStyle: .actionSheet)

        func add(_ f: Filter) {
            let action = UIAlertAction(title: f.title, style: .default) { [weak self] _ in
                self?.setFilter(f, persist: true, animated: true)
            }
            // 현재 선택된 필터 표시(체크)
            if f == currentFilter { action.setValue(true, forKey: "checked") }
            ac.addAction(action)
        }

        add(.all)
        add(.active)
        add(.expired)
        add(.interval)
        add(.date)
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad 대응
        if let pop = ac.popoverPresentationController {
            pop.sourceView = filterButton
            pop.sourceRect = filterButton.bounds
        }
        present(ac, animated: true)
    }
    
    
    private func predicate(for filter: Filter) -> NSPredicate? {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date()) as NSDate

        switch filter {
        case .all:
            return nil

        case .active:
            // “미래 지급(endDate >= today)이 하나라도 있으면” Active
            return NSPredicate(format: "SUBQUERY(occurrences, $o, $o.endDate >= %@).@count > 0", today)

        case .expired:
            // “미래 지급(endDate >= today)이 전혀 없으면” Expired
            //  (endAt 유무는 상관없이, 셀 라벨 로직과 동일하게 last 기준 만료)
            return NSPredicate(format: "SUBQUERY(occurrences, $o, $o.endDate >= %@).@count == 0", today)

        case .interval:
            return NSPredicate(format: "option != nil AND option =[c] %@", "interval")

        case .date:
            return NSPredicate(format: "option != nil AND option =[c] %@", "date")
        }
    }
    

    // MARK: - Actions
    /// + 버튼 → ReviewBindoVC(컨테이너) 푸시
    @objc private func plusTapped() {
        suspendMainInteractions()
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "NewBindoVC") as? NewBindoVC else { return }
        navigationController?.pushViewController(vc, animated: true)
        hideMenu()
    }

    @objc private func calendarButtonTapped() {
        suspendMainInteractions()
        guard let calendarVC = storyboard?.instantiateViewController(withIdentifier: "CalendarVC") as? CalendarVC else { return }
        calendarVC.modalPresentationStyle = .overCurrentContext
        calendarVC.modalTransitionStyle = .crossDissolve
        present(calendarVC, animated: true)
    }

    @objc private func statsButtonTapped() {
        suspendMainInteractions()
        guard let statsVC = storyboard?.instantiateViewController(withIdentifier: "StatsVC") as? StatsVC else { return }
        statsVC.modalPresentationStyle = .overCurrentContext
        statsVC.modalTransitionStyle = .crossDissolve
        present(statsVC, animated: true)
    }

    @objc private func setupButtonTapped() {
        suspendMainInteractions()
        guard let settingVC = storyboard?.instantiateViewController(withIdentifier: "SettingsVC") as? SettingsVC else { return }
        settingVC.modalPresentationStyle = .overCurrentContext
        settingVC.modalTransitionStyle = .crossDissolve
        present(settingVC, animated: true)
    }
    
    @objc private func editTapped() {
        guard let id = selectedIDs.first else { return }
        suspendMainInteractions()
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "NewBindoVC") as? NewBindoVC else { return }
        vc.editingID = id
        vc.repo = repo
        navigationController?.pushViewController(vc, animated: true)
        hideMenu()
    }

    @objc private func deleteTapped() {
        guard !selectedIDs.isEmpty else { return }

        let count = selectedIDs.count
        let title = "Delete?"
        let message: String
        if count == 1 {
            // 선택한 1개 이름 표시(가능하면)
            if let id = selectedIDs.first,
               let obj = frc.fetchedObjects?.first(where: { $0.id == id }) {
                message = "Remove \"\(obj.name ?? "Item")\""
            } else {
                message = "Remove selected item?"
            }
        } else {
            message = "Remove \(count) items?"
        }

        var cfg = AppAlertConfiguration()
        cfg.borderColor = AppTheme.Color.main3
        cfg.icon = UIImage(systemName: "trash.fill")

        AppAlert.present(on: self,
                         title: title,
                         message: message,
                         actions: [
                            .init(title: "Cancel", style: .cancel, handler: nil),
                            .init(title: "Delete", style: .destructive, handler: { [weak self] in
                                guard let self else { return }
                                self.performBatchDelete()
                            })
                         ],
                         configuration: cfg)
    }
    @objc private func cancelTapped() {
        setEditingMode(false)
    }
    
    
    //MARK: - Settings
    @objc private func onSettingsChanged() {
        applySettingsAndReload()
    }

    private func applySettingsAndReload() {
        configureAmountFormatter()
        tableView.reloadData()
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
        navigationItem.titleView = AppNavigation.makeBottomAlignedTitle("Bindo", offsetY: 10)

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
    
    private func setupFilterBar() {
        guard let bar = filterBar else { return }
        bar.backgroundColor = .clear
        bar.clipsToBounds = false

        if filterButton.superview == nil {
            bar.addSubview(filterButton)
            filterButton.translatesAutoresizingMaskIntoConstraints = false

            // 오른쪽 버튼 컨테이너
            let buttonsStack = UIStackView(arrangedSubviews: [deleteButton, editButton, cancelButton])
            buttonsStack.axis = .horizontal
            buttonsStack.alignment = .fill
            buttonsStack.spacing = 12
            buttonsStack.translatesAutoresizingMaskIntoConstraints = false
            bar.addSubview(buttonsStack)

            // 초기에는 숨김(편집모드에만 보임)
            buttonsStack.isHidden = !isEditingMode

            NSLayoutConstraint.activate([
                filterButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
                filterButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

                buttonsStack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
                buttonsStack.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

                // 높이 보장
                bar.heightAnchor.constraint(greaterThanOrEqualToConstant: 22)
            ])
        }
    }
    
    private func setEditingMode(_ on: Bool) {
        isEditingMode = on
        if !on { selectedIDs.removeAll() }
        if on { installEditOverlayIfNeeded() } else { removeEditOverlayIfNeeded() }
        tableView.performBatchUpdates(nil)

        // 버튼 스택 페이드 (기존 그대로)
        if let bar = filterBar,
           let stack = bar.subviews.first(where: { $0 is UIStackView && ($0 as! UIStackView).arrangedSubviews.contains(editButton) }) {

            if on {
                stack.alpha = 0
                stack.isHidden = false
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                    stack.alpha = 1
                }
            } else {
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
                    stack.alpha = 0
                }) { _ in
                    stack.isHidden = true
                }
            }
        }

        updateActionButtons()

        // 보이는 셀들만 좌우 밀림/체크 초기화 + 하이라이트 스타일
        for case let cell as BindoListCell in tableView.visibleCells {
            cell.setEditingMode(on, animated: true)
            if !on { cell.setChecked(false, animated: false) }
            cell.selectionStyle = on ? .none : .default
        }
        if on, let selected = tableView.indexPathsForSelectedRows {
            selected.forEach { tableView.deselectRow(at: $0, animated: false) }
        }

        longPressGR?.isEnabled = !on

        // 오버레이 설치/제거
        if on {
            installEditOverlayIfNeeded()
        } else {
            removeEditOverlayIfNeeded()
        }
    }
    
    private func installEditOverlayIfNeeded() {
        guard editOverlay == nil else { return }
        let host: UIView = navigationController?.view ?? view

        let overlay = PassthroughOverlay(frame: .zero)
        overlay.targetVC = self
        overlay.backgroundColor = .clear
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.tableView = tableView
        overlay.passButtons = [deleteButton, editButton, cancelButton] // 버튼만 통과

        host.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: host.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])

        // 오버레이를 최상단으로 (메뉴/필터/네비바 포함 전부 아래로)
        host.bringSubviewToFront(overlay)

        editOverlay = overlay
    }

    private func removeEditOverlayIfNeeded() {
        editOverlay?.removeFromSuperview()
        editOverlay = nil
    }
    
    
    private func updateActionButtons() {
        editButton.isEnabled = (selectedIDs.count == 1)
        deleteButton.isEnabled = !selectedIDs.isEmpty
    }
    
    private var isActiveScreen: Bool {
        guard isOnWindow else { return false }
        if let nav = navigationController {
            return nav.topViewController === self && presentedViewController == nil
        }
        return presentedViewController == nil
    }

    private func suspendMainInteractions() {
        // 편집 모드 강종료 + 제스처/테이블 비활성화 + 오버레이 입력 차단
        setEditingMode(false)
        tableView.isUserInteractionEnabled = false
        longPressGR?.isEnabled = false
        editOverlay?.isUserInteractionEnabled = false
    }

    private func resumeMainInteractions() {
        tableView.isUserInteractionEnabled = true
        longPressGR?.isEnabled = true
        editOverlay?.isUserInteractionEnabled = true
    }
    
    
    // MARK: - Formatters
    private lazy var currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.locale = .current
        return f
    }()
    
    private func configureAmountFormatter() {
        let st = SettingsStore.shared
        currencyFormatter.locale = .current
        currencyFormatter.numberStyle = .decimal
        currencyFormatter.usesGroupingSeparator = st.useComma
        currencyFormatter.minimumFractionDigits = 0
        currencyFormatter.maximumFractionDigits = 2
    }

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
            menu.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -15),
            menu.topAnchor.constraint(equalTo: host.topAnchor),
            menu.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: 15)
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

    // MARK: - Long-press
    private func wireLongPressForEditing() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.delaysTouchesBegan = true
        longPress.delaysTouchesEnded = true
        longPress.cancelsTouchesInView = true   // ← 핵심: 테이블의 선택 제스처 취소
        tableView.addGestureRecognizer(longPress)
        longPressGR = longPress
    }

    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard !isEditingMode else { return }
        guard gesture.state == .began else { return }

        suppressNextTapAfterLongPress = true   // ← 손 뗄 때 들어올 수 있는 첫 탭 1회 무시

        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        let obj = frc.object(at: indexPath)
        guard let id = obj.id else { return }

        selectedIDs = [id]
        setEditingMode(true)

        if let cell = tableView.cellForRow(at: indexPath) as? BindoListCell {
            cell.setEditingMode(true, animated: true)
            cell.setChecked(true, animated: true)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    



    // MARK: - Row display helpers
    private struct RowDisplay {
        let name: String
        let amountText: String
        let leftText: String   // Payday 라벨
        let rightText: String  // Days/Expires 라벨
    }

    private func makeRowDisplay(for e: Bindo) -> RowDisplay {
        let st = SettingsStore.shared
        let name = e.name ?? "-"

        // 금액: useBase면 baseAmount, 아니면 '다음 Occurence의 payAmount'
        let nextOcc = nextOccurrence(for: e)
        let amountDecimal: Decimal = {
            if e.useBase, let base = e.baseAmount { return base.decimalValue }
            if let pay = nextOcc?.payAmount { return pay.decimalValue }
            return e.baseAmount?.decimalValue ?? 0
        }()

        var amountText = ""
        if st.showAmount {
                let core = currencyFormatter.string(from: amountDecimal as NSDecimalNumber)
                            ?? "\(amountDecimal)"

                let symbol = st.ccySymbol
                if symbol.isEmpty {
                    amountText = core
                } else {
                    amountText = "\(symbol)\(core)"
                }
            }

        let next = nextOcc?.endDate
        let last = lastOccurrence(for: e)?.endDate

        var left = ""
        if st.showPayDay {
            left = makePayDayLeftText(next: next, last: last)
        }

        var right = ""
        if st.showDaysLeft {
            right = makeRightDaysText(for: e, next: next, last: last, end: e.endAt)
        }

        return .init(name: name, amountText: amountText, leftText: left, rightText: right)
    }

    // 왼쪽 하단: "Payday"
    private func makePayDayLeftText(next: Date?, last: Date?) -> String {
        let cal = Calendar.current
        if let next {
            return cal.isDateInToday(next) ? "Payday: Today" : "Payday: \(dateFormatter.string(from: next))"
        }
        if let last {
            return "Payday: \(dateFormatter.string(from: last))"
        }
        return "Payday: —"
    }
    
    /// progressBar의 end 기준을 우측 라벨 로직과 동일하게 맞춘다.
    private func terminalEnd(for e: Bindo) -> Date? {
        if nextOccurrence(for: e) == nil {
            return lastOccurrence(for: e)?.endDate
        }
        return nil
    }

    // 오른쪽 하단: Days/Expires 로직
    private func makeRightDaysText(for e: Bindo,
                                   next: Date?, last: Date?, end: Date?) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func dayDiff(_ a: Date, _ b: Date) -> Int { cal.dateComponents([.day], from: a, to: b).day ?? 0 }

        let endDay  = end.map  { cal.startOfDay(for: $0) }
        let nextDay = next.map { cal.startOfDay(for: $0) }

        // 0) "다음 회차 없음"이면 → 마지막 Occ 기준으로 만료 표시(가장 직관적)
        if nextDay == nil {
            if let last {
                return "Expired at \(dateFormatter.string(from: last))"  // <-- <user__selection> 제거
            }
            // 마지막도 없고 endAt만 있으면 endAt 기준으로 메시지
            if let endDay {
                if cal.isDateInToday(endDay) { return "Expires today" }
                if endDay > today { return "Expires in \(max(0, dayDiff(today, endDay))) day(s)" }
                return "Expired at \(dateFormatter.string(from: endDay))"
            }
            return "Expired"
        }

        // 1) endAt이 오늘 → 오늘 만료
        if let endDay, cal.isDateInToday(endDay) {
            return "Expires today"
        }

        // 2) endAt이 과거 → 이미 만료(가능하면 마지막 Occ 날짜로)
        if let endDay, endDay < today {
            if let last { return "Expired at \(dateFormatter.string(from: last))" }
            return "Expired at \(dateFormatter.string(from: endDay))"
        }

        // 3) endAt이 미래인 경우
        if let endDay, endDay > today {
            // 이번 회차가 마지막(next == endAt)이면 → 마지막 Occ까지 카운트다운
            if let nextDay, nextDay == endDay {
                return "Expires in \(max(0, dayDiff(today, endDay))) day(s)"
            }
            // 아직 마지막 아님 → 다음 지급일까지 남은 일수
            if let nextDay {
                let d = dayDiff(today, nextDay)
                return d <= 0 ? "0 day(s) left" : "\(d) day(s) left"
            }
            // (방어) next 계산 실패 시 endAt까지 카운트다운
            return "Expires in \(max(0, dayDiff(today, endDay))) day(s)"
        }

        // 4) endAt이 없거나(Interval) 최종 회차 아님 → 다음 Occ까지 남은 일수
        if let nextDay {
            let d = dayDiff(today, nextDay)
            return d <= 0 ? "0 days left" : "\(d) day(s) left"
        }

        // 5) 혹시 남은 게 없다면 과거 상태
        if let last { return "Expired at \(dateFormatter.string(from: last))" }
        return "Expired"
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
        
        // 선택 상태 계산
        let id = entity.id ?? UUID()
        let isChecked = selectedIDs.contains(id)
        
        cell.configure(name: vm.name,
                       amount: vm.amountText,
                       next: vm.leftText,
                       interval: vm.rightText,
                       isEditingMode: isEditingMode,
                       isChecked: isChecked)
        
        let period = currentPeriod(for: entity)
        let terminal = terminalEnd(for: entity)
        let last = lastOccurrence(for: entity)?.endDate
        cell.setProgress(start: period.start, next: period.end, endAt: terminal, last: last)
        
        cell.backgroundColor = .clear
        return cell
    }
}
    
// MARK: - TableView Delegate
extension MainVC: UITableViewDelegate {
    func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        let obj = frc.object(at: indexPath)

        if isEditingMode {
            // ← 롱프레스 직후 들어오는 첫 탭이면 무시 (체크 해제 방지)
            if suppressNextTapAfterLongPress {
                suppressNextTapAfterLongPress = false
                tv.deselectRow(at: indexPath, animated: false)
                return
            }

            guard let id = obj.id else { return }

            let willSelect = !selectedIDs.contains(id)
            if willSelect { selectedIDs.insert(id) } else { selectedIDs.remove(id) }
            updateActionButtons()

            if let cell = tv.cellForRow(at: indexPath) as? BindoListCell {
                cell.setChecked(willSelect, animated: true)
            } else {
                tv.reloadRows(at: [indexPath], with: .none)
            }
            return
        }

        // 일반 모드에서만 하이라이트 후 해제
        tv.deselectRow(at: indexPath, animated: true)

        let vc = ReviewBindoVC()
        vc.bindoID = obj.id
        vc.repo = repo
        navigationController?.pushViewController(vc, animated: true)
        hideMenu()
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
    
    func tableView(_ tv: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? BindoListCell else { return }
        let obj = frc.object(at: indexPath)
        let id  = obj.id ?? UUID()
        let isChecked = selectedIDs.contains(id)

        // 편집 모드 및 체크 상태를 재적용 (재사용 셀의 잔상 제거)
        cell.setEditingMode(isEditingMode, animated: false)
        cell.setChecked(isChecked, animated: false)
        cell.selectionStyle = isEditingMode ? .none : .default
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
                cell.selectionStyle = self.isEditingMode ? .none : .default
            }
        }
        
    }
}

// MARK: - FRC Delegate
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

    // ⬇️ 이 두 개를 “함수 밖” 최상위로 빼주세요 (지금은 내부에 중첩되어 있음)
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




