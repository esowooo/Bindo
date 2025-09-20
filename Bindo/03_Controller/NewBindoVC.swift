//
//  ReviewBindoVC.swift
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
final class NewBindoVC: BaseVC {
    
    // MARK: - UI
    @IBOutlet private weak var headView: UIView!
    @IBOutlet private weak var containerView: UIView!
    private let titleField = AppPullDownField(placeholder: "Interval")
    private var currentConstraints: [NSLayoutConstraint] = []
    
    
    // MARK: - 데이터/의존성
    var editingID: UUID?
    var repo: (BindoRepository & RefreshRepository)?
    private var editingModel: BindoList?
    
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
        let repo = self.repo ?? CoreDataBindoRepository()

        if let id = editingID, let b = try? repo.fetch(id: id) {
            editingModel = b
            // 생성 뷰 결정 (interval/date)
            if b.option.lowercased() == "date" {
                currentView = .date
            } else {
                currentView = .interval
            }
        } else {
            currentView = .interval
        }
        applyAppearance()
        performSwitch(to: currentView)
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

        var cfg = UIButton.Configuration.plain()
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 15)
        cfg.attributedTitle = AttributedString(
            "Save",
            attributes: AttributeContainer([
                .font: AppTheme.Font.body,
                .foregroundColor: AppTheme.Color.accent
            ])
        )

        let saveButton = UIButton(configuration: cfg)
        saveButton.addAction(UIAction { [weak self] _ in
            self?.saveTapped()
        }, for: .touchUpInside)

        let saveItem = UIBarButtonItem(customView: saveButton)
        AppNavigation.setItems(left: [left], right: [saveItem], for: self)

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

        // 선택 콜백 → 화면 전환 (편집 모드면 차단 + Alert)
        titleField.onSelect = { [weak self] idx, _ in
            guard let self, let kind = BindoChildView(rawValue: idx) else { return }

            // 편집 중에는 전환 금지: 선택 되돌리고 Alert만
            if self.editingModel != nil, kind != self.currentView {
                self.titleField.select(index: self.currentView.rawValue, emit: false)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                AppAlert.info(
                    on: self,
                    title: "Not Allowed",
                    message: "Can't change type for existing bindo."
                )
                return
            }

            // 신규 작성일 때만 전환
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
        // 이중 방어: 편집 모드에선 타입 전환 차단
        if editingModel != nil, newKind != currentView {
            titleField.select(index: currentView.rawValue, emit: false)
            return
        }


        currentView = newKind
        let next = childViews[newKind.rawValue]

        if let nextForm = (childViews[newKind.rawValue] as? BindoForm),
           snapshots[newKind] == nil {
            DispatchQueue.main.async { [weak self] in
                self?.snapshots[newKind] = nextForm.dirtySignature()
            }
        }

        // 1) 이전 제약 해제 & 제거
        let old = current
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints.removeAll()
        old?.removeFromSuperview()

        // 2) 새 뷰 부착
        next.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(next)

        // 3) 새 제약
        let cs: [NSLayoutConstraint] = [
            next.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            next.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            next.topAnchor.constraint(equalTo: containerView.topAnchor),
            next.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: containerBottomInset)
        ]
        NSLayoutConstraint.activate(cs)
        currentConstraints = cs
        current = next

        // 4) 타이틀 커밋
        titleField.select(index: newKind.rawValue, emit: false)

        // 5) 애니메이션
        if old == nil {
            view.layoutIfNeeded()
        } else {
            next.slideFadeIn(offsetY: 50, duration: 0.25)
        }

        // 6) 편집 모델 주입 + 스냅샷 갱신
        if let model = editingModel {
            if let v = next as? IntervalView {
                v.apply(model)
            } else if let v = next as? DateView {
                v.apply(model)
            }
            if let form = next as? BindoForm {
                snapshots[newKind] = form.dirtySignature()
            }
        }
    }

    
    
    // MARK: - 액션 (Cancel/Save)
    @objc private func saveTapped() {
        guard let form = current as? BindoForm else {
            AppAlert.info(on: self, title: "Invalid", message: "Form not found")
            return
        }
        do {
            var model = try form.buildModel()
            let repo = self.repo ?? CoreDataBindoRepository()

            if let id = editingID, let existing = try? repo.fetch(id: id) {
                let oldOpt = existing.option.lowercased()
                let newOpt = model.option.lowercased()
                if oldOpt != newOpt {
                    AppAlert.info(on: self,
                                  title: "Not allowed",
                                  message: "This item was created in \(oldOpt.capitalized) view. Changing to \(newOpt.capitalized) is restricted.")
                    return
                }

                model = BindoList(
                    id: existing.id,
                    name: model.name,
                    useBase: model.useBase,
                    baseAmount: model.baseAmount,
                    createdAt: existing.createdAt,
                    updatedAt: Date(),
                    endAt: model.endAt,
                    option: existing.option,
                    interval: model.interval,
                    occurrences: model.occurrences
                )
            }

            try repo.upsert(model)

            // 저장 후에는 Review로 돌아가지 않고 메인으로 이동
            popToMain()

        } catch {
            AppAlert.info(on: self, title: "Invalid", message: error.localizedDescription)
        }
    }
    private func popToMain() {
        guard let nav = navigationController else {
            dismiss(animated: true)
            return
        }
        if let main = nav.viewControllers.first(where: { $0 is MainVC }) {
            nav.popToViewController(main, animated: true)
        } else {
            nav.popToRootViewController(animated: true)
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


