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

        b.accessibilityLabel = NSLocalizedString("main.filter.button", comment: "MainVC.swift: Filter button a11y label")
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

        b.accessibilityLabel = NSLocalizedString(accessibility, comment: "MainVC.swift: action button a11y")
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
        accessibility: "button.delete", action: #selector(deleteTapped)
    )

    private lazy var editButton: UIButton = makeActionButton(
        symbol: "square.and.pencil", baseBG: AppTheme.Color.main1,
        baseFG: AppTheme.Color.background, disabledBG: .systemGray2,
        minHeight: 22, minWidth: actionMinWidth,
        accessibility: "button.edit", action: #selector(editTapped)
    )

    private lazy var cancelButton: UIButton = makeActionButton(
        symbol: "xmark", baseBG: AppTheme.Color.accent,
        baseFG: AppTheme.Color.background, disabledBG: AppTheme.Color.accent,
        minHeight: 22, minWidth: actionMinWidth,
        accessibility: "button.cancel", action: #selector(cancelTapped)
    )
    
    // 오버레이…
    private final class PassthroughOverlay: UIView {
        weak var targetVC: MainVC?
        weak var tableView: UITableView?
        var passButtons: [UIView] = []

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            if targetVC?.isActiveScreen != true { return true }
            for v in passButtons {
                guard v.window != nil, !v.isHidden, v.alpha > 0.01 else { continue }
                let p = convert(point, to: v)
                if v.point(inside: p, with: event) { return false }
            }
            if let tv = tableView, tv.window != nil {
                let pInTable = convert(point, to: tv)
                if let ip = tv.indexPathForRow(at: pInTable) {
                    var rowRect = tv.rectForRow(at: ip)
                    rowRect = rowRect.insetBy(dx: 0, dy: -2)
                    if rowRect.contains(pInTable) { return false }
                }
            }
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
            case .all:      return NSLocalizedString("main.filter.all", comment: "MainVC.swift: All filter")
            case .active:   return NSLocalizedString("main.filter.active", comment: "MainVC.swift: Active filter")
            case .expired:  return NSLocalizedString("main.filter.expired", comment: "MainVC.swift: Expired filter")
            case .interval: return NSLocalizedString("main.filter.interval", comment: "MainVC.swift: Interval Mode filter")
            case .date:     return NSLocalizedString("main.filter.date", comment: "MainVC.swift: Date Mode filter")
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
            try repo.ensureAllCurrentCycles()
            applyFilterAndFetch()
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
        if let idx = indexPath { fadeOutCellSnapshot(at: idx) }
        guard let id = obj.id else {
            if let idx = indexPath { restoreCellAlphaIfVisible(at: idx) }
            return
        }
        do {
            try repo.delete(id: id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            if let idx = indexPath { restoreCellAlphaIfVisible(at: idx) }
            AppAlert.present(on: self,
                             title: NSLocalizedString("error.title", comment: "MainVC.swift: Error title"),
                             message: error.localizedDescription,
                             actions: [.init(title: NSLocalizedString("button.ok", comment: "MainVC.swift: OK"),
                                             style: .primary)])
        }
    }
    
    private func performBatchDelete() {
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

        if failed {
            AppAlert.present(on: self,
                             title: NSLocalizedString("error.title", comment: "MainVC.swift: Error title"),
                             message: NSLocalizedString("main.alert.someDeleteFailed", comment: "MainVC.swift: Some items could not be deleted."),
                             actions: [.init(title: NSLocalizedString("button.ok", comment: "MainVC.swift: OK"),
                                             style: .primary)])
        }
    }
    
    //MARK: - Filter
    @objc private func filterButtonTapped() { presentFilterPicker() }
    @objc private func clearFilterTapped() { setFilter(.all, persist: true, animated: true) }

    private func loadSavedFilterAndApply() {
        let saved = UserDefaults.standard.string(forKey: filterDefaultsKey)
        let f = saved.flatMap { Filter(rawValue: $0) } ?? .all
        setFilter(f, persist: false, animated: false)
    }

    private func setFilter(_ f: Filter, persist: Bool, animated: Bool) {
        currentFilter = f
        if persist { UserDefaults.standard.set(f.rawValue, forKey: filterDefaultsKey) }
        applyFilterAndFetch()
    }
    
    private func presentFilterPicker() {
        let ac = UIAlertController(
            title: NSLocalizedString("main.filter.title", comment: "MainVC.swift: Filter sheet title"),
            message: nil,
            preferredStyle: .actionSheet
        )

        func add(_ f: Filter) {
            let action = UIAlertAction(title: f.title, style: .default) { [weak self] _ in
                self?.setFilter(f, persist: true, animated: true)
            }
            if f == currentFilter { action.setValue(true, forKey: "checked") }
            ac.addAction(action)
        }

        add(.all); add(.active); add(.expired); add(.interval); add(.date)
        ac.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "MainVC.swift: Cancel"),
                                   style: .cancel))

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
            return NSPredicate(format: "SUBQUERY(occurrences, $o, $o.endDate >= %@).@count > 0", today)
        case .expired:
            return NSPredicate(format: "SUBQUERY(occurrences, $o, $o.endDate >= %@).@count == 0", today)
        case .interval:
            return NSPredicate(format: "option != nil AND option =[c] %@", "interval")
        case .date:
            return NSPredicate(format: "option != nil AND option =[c] %@", "date")
        }
    }
    
    // MARK: - Actions
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
        let title = NSLocalizedString("main.alert.deleteTitle", comment: "MainVC.swift: Delete? alert title")
        let message: String
        if count == 1 {
            if let id = selectedIDs.first,
               let obj = frc.fetchedObjects?.first(where: { $0.id == id }) {
                message = String(
                    format: NSLocalizedString("main.alert.removeItem", comment: "MainVC.swift: Remove 1 item"),
                    obj.name ?? NSLocalizedString("main.item", comment: "MainVC.swift: Default item name")
                )
            } else {
                message = NSLocalizedString("main.alert.removeSelected", comment: "MainVC.swift: Remove selected item")
            }
        } else {
            message = String(
                format: NSLocalizedString("main.alert.removeItems", comment: "MainVC.swift: Remove multiple items"),
                count
            )
        }

        var cfg = AppAlertConfiguration()
        cfg.borderColor = AppTheme.Color.main3
        cfg.icon = UIImage(systemName: "trash.fill")

        AppAlert.present(on: self,
                         title: title,
                         message: message,
                         actions: [
                            .init(title: NSLocalizedString("button.cancel", comment: "MainVC.swift: Cancel"),
                                  style: .cancel,
                                  handler: nil),
                            .init(title: NSLocalizedString("button.delete", comment: "MainVC.swift: Delete"),
                                  style: .destructive,
                                  handler: { [weak self] in
                                      self?.performBatchDelete()
                                  })
                         ],
                         configuration: cfg)
    }
    @objc private func cancelTapped() { setEditingMode(false) }
    
    //MARK: - Settings
    @objc private func onSettingsChanged() { applySettingsAndReload() }
    private func applySettingsAndReload() {
        configureAmountFormatter()
        tableView.reloadData()
    }
    
    // MARK: - UI
    private func applyAppearance() {
        view.backgroundColor = AppTheme.Color.background
        topDateLabel.font = AppTheme.Font.caption
        topDateLabel.textColor = AppTheme.Color.main2
        topDateLabel.text = dateFormatter.string(from: Date())

        AppNavigation.apply(to: navigationController)

        navigationItem.titleView = AppNavigation.makeBottomAlignedTitle(
            NSLocalizedString("app.name", comment: "MainVC.swift: App Title"),
            offsetY: 10
        )

        let addItem = AppNavigation.BarItem(
            systemImage: "plus",
            accessibilityLabel: NSLocalizedString("button.add", comment: "MainVC.swift: Add a11y"),
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

            let buttonsStack = UIStackView(arrangedSubviews: [deleteButton, editButton, cancelButton])
            buttonsStack.axis = .horizontal
            buttonsStack.alignment = .fill
            buttonsStack.spacing = 12
            buttonsStack.translatesAutoresizingMaskIntoConstraints = false
            bar.addSubview(buttonsStack)
            buttonsStack.isHidden = !isEditingMode

            NSLayoutConstraint.activate([
                filterButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
                filterButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

                buttonsStack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
                buttonsStack.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

                bar.heightAnchor.constraint(greaterThanOrEqualToConstant: 22)
            ])
        }
    }
    
    private func setEditingMode(_ on: Bool) {
        isEditingMode = on
        if !on { selectedIDs.removeAll() }
        if on { installEditOverlayIfNeeded() } else { removeEditOverlayIfNeeded() }
        tableView.performBatchUpdates(nil)

        if let bar = filterBar,
           let stack = bar.subviews.first(where: { $0 is UIStackView && ($0 as! UIStackView).arrangedSubviews.contains(editButton) }) {

            if on {
                stack.alpha = 0
                stack.isHidden = false
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) { stack.alpha = 1 }
            } else {
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
                    stack.alpha = 0
                }) { _ in stack.isHidden = true }
            }
        }

        updateActionButtons()

        for case let cell as BindoListCell in tableView.visibleCells {
            cell.setEditingMode(on, animated: true)
            if !on { cell.setChecked(false, animated: false) }
            cell.selectionStyle = on ? .none : .default
        }
        if on, let selected = tableView.indexPathsForSelectedRows {
            selected.forEach { tableView.deselectRow(at: $0, animated: false) }
        }

        longPressGR?.isEnabled = !on
        if on { installEditOverlayIfNeeded() } else { removeEditOverlayIfNeeded() }
    }
    
    private func installEditOverlayIfNeeded() {
        guard editOverlay == nil else { return }
        let host: UIView = navigationController?.view ?? view

        let overlay = PassthroughOverlay(frame: .zero)
        overlay.targetVC = self
        overlay.backgroundColor = .clear
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.tableView = tableView
        overlay.passButtons = [deleteButton, editButton, cancelButton]

        host.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: host.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
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
        UIView.animate(withDuration: animated ? 0.18 : 0) { self.menu.alpha = target }
    }
    private func hideMenu(animated: Bool = true) {
        guard !menu.isHidden else { return }
        UIView.animate(withDuration: animated ? 0.18 : 0, animations: {
            self.menu.alpha = 0
        }, completion: { _ in self.menu.isHidden = true })
    }

    // MARK: - Long-press
    private func wireLongPressForEditing() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.delaysTouchesBegan = true
        longPress.delaysTouchesEnded = true
        longPress.cancelsTouchesInView = true
        tableView.addGestureRecognizer(longPress)
        longPressGR = longPress
    }
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard !isEditingMode else { return }
        guard gesture.state == .began else { return }
        suppressNextTapAfterLongPress = true

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
    private struct RowDisplay { let name, amountText, leftText, rightText: String }

    private func makeRowDisplay(for e: Bindo) -> RowDisplay {
        let st = SettingsStore.shared
        let name = e.name ?? "-"
        let nextOcc = nextOccurrence(for: e)
        let amountDecimal: Decimal = {
            if e.useBase, let base = e.baseAmount { return base.decimalValue }
            if let pay = nextOcc?.payAmount { return pay.decimalValue }
            return e.baseAmount?.decimalValue ?? 0
        }()
        var amountText = ""
        if st.showAmount {
            let core = currencyFormatter.string(from: amountDecimal as NSDecimalNumber) ?? "\(amountDecimal)"
            let symbol = st.ccySymbol
            amountText = symbol.isEmpty ? core : "\(symbol)\(core)"
        }
        let next = nextOcc?.endDate
        let last = lastOccurrence(for: e)?.endDate

        var left = ""
        if st.showPayDay { left = makePayDayLeftText(next: next, last: last) }

        var right = ""
        if st.showDaysLeft {
            right = makeRightDaysText(for: e, next: next, last: last, end: e.endAt)
        }
        return .init(name: name, amountText: amountText, leftText: left, rightText: right)
    }

    private func makePayDayLeftText(next: Date?, last: Date?) -> String {
        let cal = Calendar.current
        if let next {
            return cal.isDateInToday(next)
            ? NSLocalizedString("main.payday.today", comment: "MainVC.swift: Payday today")
            : String(format: NSLocalizedString("main.payday.date", comment: "MainVC.swift: Payday with date"),
                     dateFormatter.string(from: next))
        }
        if let last {
            return String(format: NSLocalizedString("main.payday.date", comment: "MainVC.swift: Payday with last date"),
                          dateFormatter.string(from: last))
        }
        return NSLocalizedString("main.payday.none", comment: "MainVC.swift: No payday")
    }
    
    private func terminalEnd(for e: Bindo) -> Date? {
        if nextOccurrence(for: e) == nil { return lastOccurrence(for: e)?.endDate }
        return nil
    }

    private func makeRightDaysText(for e: Bindo, next: Date?, last: Date?, end: Date?) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func dayDiff(_ a: Date, _ b: Date) -> Int { cal.dateComponents([.day], from: a, to: b).day ?? 0 }

        let endDay  = end.map  { cal.startOfDay(for: $0) }
        let nextDay = next.map { cal.startOfDay(for: $0) }

        // (로직 0) “다음 회차 없음” → 마지막 Occ 기준 만료
        if nextDay == nil {
            if let last {
                return String(format: NSLocalizedString("main.expires.expiredAt", comment: "MainVC.swift: Expired at last date"),
                              dateFormatter.string(from: last))
            }
            if let endDay {
                if cal.isDateInToday(endDay) {
                    return NSLocalizedString("main.expires.today", comment: "MainVC.swift: Expires today")
                }
                if endDay > today {
                    return String(format: NSLocalizedString("main.expires.inDays", comment: "MainVC.swift: Expires in n days"),
                                  max(0, dayDiff(today, endDay)))
                }
                return String(format: NSLocalizedString("main.expires.expiredAt", comment: "MainVC.swift: Expired at endAt"),
                              dateFormatter.string(from: endDay))
            }
            return NSLocalizedString("main.expires.default", comment: "MainVC.swift: Expired fallback")
        }

        if let endDay, cal.isDateInToday(endDay) {
            return NSLocalizedString("main.expires.today", comment: "MainVC.swift: Expires today")
        }
        if let endDay, endDay < today {
            if let last { return String(format: NSLocalizedString("main.expires.expiredAt", comment: "MainVC.swift: Expired at last date"),
                                        dateFormatter.string(from: last)) }
            return String(format: NSLocalizedString("main.expires.expiredAt", comment: "MainVC.swift: Expired at endAt"),
                          dateFormatter.string(from: endDay))
        }

        if let endDay, endDay > today {
            if let nextDay, nextDay == endDay {
                return String(format: NSLocalizedString("main.expires.inDays", comment: "MainVC.swift: Expires in n days"),
                              max(0, dayDiff(today, endDay)))
            }
            if let nextDay {
                let d = dayDiff(today, nextDay)
                return d <= 0 ? NSLocalizedString("main.daysLeft.zero", comment: "MainVC.swift: 0 days left")
                              : String(format: NSLocalizedString("main.daysLeft.n", comment: "MainVC.swift: n days left"), d)
            }
            return String(format: NSLocalizedString("main.expires.inDays", comment: "MainVC.swift: Expires in n days"),
                          max(0, dayDiff(today, endDay)))
        }

        if let nextDay {
            let d = dayDiff(today, nextDay)
            return d <= 0 ? NSLocalizedString("main.daysLeft.zero", comment: "MainVC.swift: 0 days left")
                          : String(format: NSLocalizedString("main.daysLeft.n", comment: "MainVC.swift: n days left"), d)
        }

        if let last { return String(format: NSLocalizedString("main.expires.expiredAt", comment: "MainVC.swift: Expired at last date"),
                                    dateFormatter.string(from: last)) }
        return NSLocalizedString("main.expires.default", comment: "MainVC.swift: Expired")
    }

    private func currentPeriod(for e: Bindo) -> (start: Date?, end: Date?) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        guard let occs = (e.occurrences as? Set<Occurence>), !occs.isEmpty else { return (nil, nil) }

        let next = occs.compactMap { $0.endDate }
            .filter { cal.startOfDay(for: $0) >= today }
            .min()

        if let next {
            let start = occs.first(where: { $0.endDate != nil && cal.isDate($0.endDate!, inSameDayAs: next) })?.startDate
            return (start, next)
        }
        if let last = occs.compactMap({ $0.endDate })
            .filter({ cal.startOfDay(for: $0) <= today }).max() {
            let start = occs.first(where: { $0.endDate != nil && cal.isDate($0.endDate!, inSameDayAs: last) })?.startDate
            return (start, last)
        }
        return (nil, nil)
    }

    private func nextOccurrence(for e: Bindo) -> Occurence? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let occs = (e.occurrences as? Set<Occurence>), !occs.isEmpty else { return nil }
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

// MARK: - TableView DataSource/Delegate (unchanged except alerts)
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
extension MainVC: UITableViewDelegate {
    func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        let obj = frc.object(at: indexPath)
        if isEditingMode {
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
                             title: NSLocalizedString("main.alert.deleteTitle", comment: "MainVC.swift: Delete?"),
                             message: String(format: NSLocalizedString("main.alert.removeItem", comment: "MainVC.swift: Remove \"%@\""),
                                             entity.name ?? NSLocalizedString("main.item", comment: "MainVC.swift: Default item name")),
                             actions: [
                                .init(title: NSLocalizedString("button.cancel", comment: "MainVC.swift: Cancel"),
                                      style: .cancel) { [weak self] in
                                          self?.restoreCellAlphaIfVisible(at: indexPath)
                                          done(false)
                                      },
                                .init(title: NSLocalizedString("button.delete", comment: "MainVC.swift: Delete"),
                                      style: .destructive) { [weak self] in
                                          guard let self else { done(false); return }
                                          self.fadeOutCellSnapshot(at: indexPath)
                                          guard let id = entity.id else { done(false); return }
                                          do {
                                              try self.repo.delete(id: id)
                                              UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                              done(true)
                                          } catch {
                                              self.restoreCellAlphaIfVisible(at: indexPath)
                                              AppAlert.present(on: self,
                                                               title: NSLocalizedString("error.title", comment: "MainVC.swift: Error"),
                                                               message: error.localizedDescription,
                                                               actions: [.init(title: NSLocalizedString("button.ok", comment: "MainVC.swift: OK"),
                                                                               style: .primary)])
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
        cell.setEditingMode(isEditingMode, animated: false)
        cell.setChecked(isChecked, animated: false)
        cell.selectionStyle = isEditingMode ? .none : .default
    }
    private func fadeOutCellSnapshot(at indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        cell.contentView.alpha = 0
        guard let snap = cell.contentView.snapshotView(afterScreenUpdates: false) else { return }
        let frameInTable = tableView.convert(cell.contentView.bounds, from: cell.contentView)
        snap.frame = frameInTable
        tableView.addSubview(snap)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut], animations: {
            snap.alpha = 0.0
            snap.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }, completion: { _ in snap.removeFromSuperview() })
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




