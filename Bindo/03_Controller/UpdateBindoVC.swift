//
//  UpdateBindoVC.swift
//  Bindo
//
//  Created by Sean Choi on 9/9/25.
//

import UIKit



// MARK: - 폼 프로토콜 (각 Child VC가 채택)
protocol BindoForm where Self: UIView {
    var optionName: String { get }
    func buildModel() throws -> BindoList
    func dirtySignature() -> AnyHashable
    func reset()
}


// MARK: - Child 종류
enum BindoChildView: Int, CaseIterable {
    case interval, date
    
    var title: String {
        switch self {
        case .interval: return "Interval"
        case .date:   return "Date"
        }
    }
}



// MARK: - 컨테이너 VC
final class UpdateBindoVC: UIViewController {
    
    // MARK: - UI
    @IBOutlet private weak var headView: UIView!
    @IBOutlet private weak var containerView: UIView!
    private let titleField = AppPullDownField(placeholder: "Interval")
    private var currentConstraints: [NSLayoutConstraint] = []
    
    
    // MARK: - 데이터/의존성
    var editingID: UUID?
    private let repo: BindoRepository = CoreDataBindoRepository()
    
    
    private lazy var childViews: [UIView] = [
        IntervalView(),
        DateView()
    ]
    private var current: UIView?
    private var currentView: BindoChildView = .interval
    
    // 레이아웃 토큰(컨테이너 하단 여백)
    private let containerBottomInset: CGFloat = -35
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        if let id = editingID, let _ = try? repo.fetch(id: id) {
            // TODO: 폼에 model 주입(Interval/DateView 각각의 setValue 계열 구현 필요)
        }
        currentView = .interval
        applyAppearance()
        performSwitch(to: .interval)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 배경/카드
        view.backgroundColor = AppTheme.Color.background
        
        containerView.layer.cornerRadius = AppTheme.Corner.l
        containerView.layer.cornerCurve = .continuous
        containerView.clipsToBounds = true
        containerView.backgroundColor = AppTheme.Color.background
        
        headView.backgroundColor = AppTheme.Color.background
        headView.layer.cornerRadius = AppTheme.Corner.l
        headView.layer.cornerCurve = .continuous
        headView.clipsToBounds = true
    }
    
    // MARK: - Appearance (공통 테마)
    private func applyAppearance() {
        AppNavigation.apply(to: navigationController)

        // 좌/우 버튼은 유지
        let backItem = AppNavigation.BarItem(
            systemImage: "chevron.backward",
            accessibilityLabel: "Back",
            action: UIAction { [weak self] _ in self?.cancelTapped() }
        )
        let left = AppNavigation.makeButton(backItem, style: .plainAccent)

        let saveItem = AppNavigation.BarItem(
            systemImage: "tray.and.arrow.down",
            accessibilityLabel: "Save",
            action: UIAction { [weak self] _ in self?.saveTapped() }
        )
        let right = AppNavigation.makeButton(saveItem, style: .plainAccent)

        AppNavigation.setItems(left: [left], right: [right], for: self)

        // AppPullDownField 구성
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.displayMode = .customPopup         // 커스텀 팝업 사용
        titleField.titleFont = AppTheme.Font.body
        titleField.titleColor = AppTheme.Color.label // 버튼 표시 색
        titleField.backgroundFill = .clear            // 네비바 배경에 녹이기
        titleField.contentInsets = AppTheme.PullDown.contentInsets
        titleField.titleAlignment = .center

        // 아이템 & 초기 선택
        let items = BindoChildView.allCases.map { AppPullDownField.Item($0.title) }
        titleField.setItems(items)
        titleField.select(index: currentView.rawValue, emit: false)

        // 선택 콜백 → 화면 전환
        titleField.onSelect = { [weak self] idx, _ in
            guard let self, let kind = BindoChildView(rawValue: idx) else { return }
            self.titleField.select(index: self.currentView.rawValue, emit: false)
            self.requestSwitch(to: kind)
        }

        // 네비 타이틀에 장착 + 최소 사이즈
        navigationItem.titleView = titleField
    }
    
    
    // MARK: - 화면 전환
    // 사용자가 탭했을 때 호출: 더티면 경고 → OK 시 전환
    private var snapshots: [BindoChildView: AnyHashable] = [:]

    // 화면 전환 요청
    private func requestSwitch(to newKind: BindoChildView) {
        guard newKind != currentView else { return }

        if let form = (childViews[currentView.rawValue] as? BindoForm) {
            let sig = form.dirtySignature()

            // baseline이 있을 때만 비교
            if let old = snapshots[currentView], old != sig {
                var cfg = AppAlertConfiguration()
                cfg.borderColor = AppTheme.Color.main3
                cfg.icon = UIImage(systemName: "exclamationmark.triangle.fill")
                
                AppAlert.present(
                    on: self,
                    title: "Discard changes?",
                    message: "You have unsaved inputs. Switching will delete current inputs.",
                    actions: [
                        .init(title: "Cancel", style: .cancel) { [weak self] in
                            // 타이틀 되돌리기
                            guard let self else { return }
                            self.titleField.select(index: self.currentView.rawValue, emit: false)
                        },
                        .init(title: "OK", style: .destructive) { [weak self] in
                            guard let self else { return }
                            form.reset()
                            self.snapshots[self.currentView] = form.dirtySignature()
                            self.performSwitch(to: newKind)
                        }
                    ],
                    configuration: cfg
                )
                return
            }
        }

        performSwitch(to: newKind)
    }
    
    // 실제 전환: 제약 정리 → 새 뷰 부착
    private func performSwitch(to newKind: BindoChildView) {
        currentView = newKind
        let next = childViews[newKind.rawValue]

        if let nextForm = (childViews[newKind.rawValue] as? BindoForm),
           snapshots[newKind] == nil {
            DispatchQueue.main.async { [weak self] in
                self?.snapshots[newKind] = nextForm.dirtySignature()
            }
        }

        // 1) 이전 제약 해제 & 제거 (old 참조 유지)
        let old = current
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints.removeAll()
        old?.removeFromSuperview()

        // 2) 새 뷰 부착
        next.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(next)

        // 3) 새 제약 생성/적용  ← 오타 수정: containerView.trailingAnchor
        let cs: [NSLayoutConstraint] = [
            next.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            next.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            next.topAnchor.constraint(equalTo: containerView.topAnchor),
            next.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: containerBottomInset)
        ]
        NSLayoutConstraint.activate(cs)
        currentConstraints = cs
        current = next

        // 4) 타이틀 커밋(지연 커밋 유지)
        titleField.select(index: newKind.rawValue, emit: false)

        // 5) 살짝 애니메이션
        if old == nil {
            view.layoutIfNeeded()
        } else {
            next.slideFadeIn(offsetY: 50, duration: 0.25)
        }
    }

    
    
    // MARK: - 액션 (Cancel/Save)
    @objc private func saveTapped() {
        guard let form = current as? BindoForm else {
            AppAlert.info(on: self, title: "Invalid", message: "Form not found")
            return
        }
        do {
            var model = try form.buildModel() // IntervalView가 첫 Occ 포함해서 반환

            if let id = editingID, let existing = try? repo.fetch(id: id) {
                // 🔒 option 변경 금지
                let oldOpt = existing.option.lowercased()
                let newOpt = model.option.lowercased()
                if oldOpt != newOpt {
                    AppAlert.info(on: self,
                                  title: "Not allowed",
                                  message: "This item was created in \(oldOpt.capitalized) view. Changing to \(newOpt.capitalized) is restricted.")
                    return
                }

                // 편집: id/createdAt 유지, updatedAt만 today로 갱신
                model = BindoList(
                    id: existing.id,
                    name: model.name,
                    useBase: model.useBase,
                    baseAmount: model.baseAmount,
                    createdAt: existing.createdAt,  // 보존
                    updatedAt: Date(),              // 갱신
                    endAt: model.endAt,
                    option: existing.option,        // 보존
                    interval: model.interval,
                    occurrences: model.occurrences  // 폼에서 온 첫 Occ(필요 시 교체)
                )
            }

            try repo.upsert(model)
            cancelTapped()
        } catch {
            AppAlert.info(on: self, title: "Invalid", message: error.localizedDescription)
        }
    }
    
    @objc private func cancelTapped() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
    
}
