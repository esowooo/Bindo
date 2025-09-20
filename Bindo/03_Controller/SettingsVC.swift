//
//  SettingsVC.swift
//  Bindo
//

import UIKit

final class SettingsVC: BaseVC {
    
    // MARK: - Outlets (스토리보드 연결됨)
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dismissbutton: UIButton!
    
    // MARK: - UI (코드 구성)
    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()
    
    // Rows – 컨트롤만 미리 잡아두면 나중에 바인딩 쉬움
    private let statusBarSwitch   = UISwitch()
    private let ccyField          = AppPullDownField(placeholder: "None")
    
    private let commaSwitch       = UISwitch()
    private let payDaySwitch      = UISwitch()
    private let daysLeftSwitch    = UISwitch()
    private let amountSwitch      = UISwitch()
    private let exportButton      = UIButton(type: .system)
    private let claimButton       = UIButton(type: .system)
    
    private lazy var outsideTapGR: UITapGestureRecognizer = {
        let g = UITapGestureRecognizer(target: self, action: #selector(handleOutsideTap(_:)))
        g.cancelsTouchesInView = false
        g.delegate = self
        return g
    }()
    

    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        loadSettingsIntoUI()
        bindSettingsActions()
        view.addGestureRecognizer(outsideTapGR)
    }
    
    // MARK: - Actions
    @IBAction func dismissButtonPressed(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    
    // MARK: - Setup
    private func configureUI() {
        buildBaseLayout()
        buildRows()
        applyTheme()
        [statusBarSwitch, commaSwitch, payDaySwitch, daysLeftSwitch, amountSwitch].forEach {
            configureToggle($0)
        }
    }
    
    private func loadSettingsIntoUI() {
        let store = SettingsStore.shared
        
        statusBarSwitch.isOn = !store.isStatusBarHidden
        commaSwitch.isOn    = store.useComma
        payDaySwitch.isOn   = store.showPayDay
        daysLeftSwitch.isOn = store.showDaysLeft
        amountSwitch.isOn   = store.showAmount
        
        let idx   = SettingsStore.CurrencyCatalog.index(of: store.ccyCode)
        let items = SettingsStore.CurrencyCatalog.pullDownItems()
        ccyField.setItems(items, select: idx)
    }
    
    private func bindSettingsActions() {
        // 상태바
        statusBarSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            SettingsStore.shared.isStatusBarHidden = !self.statusBarSwitch.isOn
            // 즉시 반영
            self.setNeedsStatusBarAppearanceUpdate()
            self.view.window?.windowScene?
                .keyWindowTopController()?
                .setNeedsStatusBarAppearanceUpdate()
        }, for: .valueChanged)
        
        // CCY 선택
        ccyField.onSelect = { [weak self] index, _ in
            guard self != nil else { return }
            let code = SettingsStore.CurrencyCatalog.codes[index]
            SettingsStore.shared.ccyCode = code
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
        
        // 나머지 스위치
        commaSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            SettingsStore.shared.useComma = self.commaSwitch.isOn
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }, for: .valueChanged)
        
        payDaySwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            SettingsStore.shared.showPayDay = self.payDaySwitch.isOn
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }, for: .valueChanged)
        
        daysLeftSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            SettingsStore.shared.showDaysLeft = self.daysLeftSwitch.isOn
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }, for: .valueChanged)
        
        amountSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            SettingsStore.shared.showAmount = self.amountSwitch.isOn
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }, for: .valueChanged)
        
        exportButton.addAction(UIAction { [weak self] _ in
            self?.exportCSVTapped()
        }, for: .touchUpInside)
        
        claimButton.addAction(UIAction { [weak self] _ in
            self?.sendFeedbackTapped()
        }, for: .touchUpInside)
    }
    
    // MARK: - Build Base Layout
    private func buildBaseLayout() {
        // ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        containerView.addSubview(scrollView)
        
        // StackView
        stackView.axis = .vertical
        stackView.spacing = AppTheme.Spacing.l
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // Constraints
        NSLayoutConstraint.activate([
            // scrollView pinned to containerView
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // stackView pinned to scrollView content layout guide
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: AppTheme.Spacing.l),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -AppTheme.Spacing.l),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppTheme.Spacing.l),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.xl),
            
            // stackView width == scrollView frame width (수평 스크롤 방지)
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -AppTheme.Spacing.l * 2)
        ])
    }
    
    // MARK: - Build Rows
    private func buildRows() {
        // Section Header Helper
        func sectionHeader(_ text: String) -> UIView {
            let l = UILabel()
            l.font = AppTheme.Font.secondaryTitle
            l.textColor = AppTheme.Color.label
            l.text = text
            return l
        }
        
        // Toggle Row Helper
        func toggleRow(title: String, toggle: UISwitch, subtitle: String? = nil) -> UIView {
            let titleLabel = UILabel()
            titleLabel.font = AppTheme.Font.body
            titleLabel.textColor = AppTheme.Color.label
            titleLabel.text = title
            
            let h = UIStackView(arrangedSubviews: [titleLabel, toggle])
            h.axis = .horizontal
            h.alignment = .center
            h.distribution = .fill
            h.spacing = AppTheme.Spacing.m
            
            toggle.onTintColor = AppTheme.Color.accent
            
            if let subtitle {
                let sub = UILabel()
                sub.font = AppTheme.Font.caption
                sub.textColor = AppTheme.Color.main3
                sub.text = subtitle
                sub.numberOfLines = 0
                
                let v = UIStackView(arrangedSubviews: [h, sub])
                v.axis = .vertical
                v.spacing = AppTheme.Spacing.xs
                return v
            }
            return h
        }
        
        // Button Row Helper
        func actionButtonRow(title: String, button: UIButton, systemImage: String? = nil) -> UIView {
            var cfg = UIButton.Configuration.filled()
            cfg.baseBackgroundColor = AppTheme.Color.accent
            cfg.baseForegroundColor = AppTheme.Color.background
            cfg.cornerStyle = .capsule
            cfg.contentInsets = .init(top: 10, leading: 16, bottom: 10, trailing: 16)
            cfg.title = title
            if let systemImage {
                cfg.image = UIImage(systemName: systemImage)
                cfg.imagePadding = 8
                cfg.preferredSymbolConfigurationForImage = .init(pointSize: 16, weight: .semibold)
            }
            button.configuration = cfg
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: AppTheme.Control.buttonHeight).isActive = true
            
            let container = UIView()
            button.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(button)
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                button.topAnchor.constraint(equalTo: container.topAnchor),
                button.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            return container
        }
        
        // PullDown Row for CCY
        func pullDownRow(title: String, field: AppPullDownField, placeholder: String = "None") -> UIView {
            // 1) 라벨
            let titleLabel = UILabel()
            titleLabel.font = AppTheme.Font.body
            titleLabel.textColor = AppTheme.Color.label
            titleLabel.text = title
            titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            titleLabel.setContentHuggingPriority(.required, for: .horizontal)
            
            // 2) 필드 스타일 (한 줄 최적화)
            field.titleFont     = AppTheme.Font.body
            field.titleColor    = AppTheme.Color.label
            field.imageName     = "chevron.down"
            field.imageColor    = AppTheme.Color.accent
            field.contentInsets = .init(top: 8, leading: 14, bottom: 8, trailing: 6)
            field.cornerRadius  = AppTheme.Corner.m
            field.backgroundFill = AppTheme.Color.background
            field.titleAlignment = .center
            field.heightAnchor
                .constraint(greaterThanOrEqualToConstant: AppTheme.Control.fieldHeight)
                .isActive = true
            
            // 3) 가로 스택: 라벨 | 스페이서 | 필드
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            let h = UIStackView(arrangedSubviews: [titleLabel, spacer, field])
            h.alignment = .center
            h.distribution = .fill
            
            // 필드가 오른쪽에서 충분히 넓어지도록
            field.setContentHuggingPriority(.required, for: .horizontal)
            field.setContentCompressionResistancePriority(.required, for: .horizontal)
            // 최소 너비(옵션): 너무 짧아지지 않게
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true
            
            return h
        }
        
        // ─────────────────────────────────────────────────
        
        // ── SECTION: App
        //        stackView.addArrangedSubview(sectionSeparatorView())
        stackView.addArrangedSubview(sectionHeader("App"))
        stackView.addArrangedSubview(sectionSeparatorView())
        stackView.addArrangedSubview(toggleRow(title: "Show Status Bar", toggle: statusBarSwitch))
        
        // ── SECTION: Main
        stackView.addArrangedSubview(sectionHeader("Main"))
        stackView.addArrangedSubview(sectionSeparatorView())
        stackView.addArrangedSubview(pullDownRow(title: "CCY Display", field: ccyField, placeholder: "None"))
        stackView.addArrangedSubview(rowSeparatorView())
        stackView.addArrangedSubview(toggleRow(title: "Use Comma Separator", toggle: commaSwitch))
        stackView.addArrangedSubview(rowSeparatorView())
        stackView.addArrangedSubview(toggleRow(title: "Show Payday", toggle: payDaySwitch))
        stackView.addArrangedSubview(rowSeparatorView())
        stackView.addArrangedSubview(toggleRow(title: "Show Days Left", toggle: daysLeftSwitch))
        stackView.addArrangedSubview(rowSeparatorView())
        stackView.addArrangedSubview(toggleRow(title: "Show Amount", toggle: amountSwitch))
        
        // ── SECTION: Tools
        stackView.addArrangedSubview(sectionHeader("Tools"))
        stackView.addArrangedSubview(sectionSeparatorView())
        stackView.addArrangedSubview(actionButtonRow(title: "Export CSV", button: exportButton, systemImage: "square.and.arrow.up"))
        stackView.addArrangedSubview(actionButtonRow(title: "Send Feedback", button: claimButton, systemImage: "paperplane"))
        
    }
    
    func sectionSeparatorView() -> UIView {
        AppSeparator(
            color: .accent,
            thickness: 1
        )
    }
    func rowSeparatorView() -> UIView {
        AppSeparator(color: AppTheme.Color.accent.withAlphaComponent(0.8))
    }
    
    private func configureToggle(_ toggle: UISwitch, scale: CGFloat = 0.86) {
        toggle.onTintColor = AppTheme.Color.accent
        toggle.transform = CGAffineTransform(scaleX: scale, y: scale)
        // 탭 영역 확보(시각적 크기는 줄어도 터치 타깃은 충분히)
        toggle.widthAnchor.constraint(greaterThanOrEqualToConstant: 51).isActive = true
        toggle.heightAnchor.constraint(greaterThanOrEqualToConstant: 31).isActive = true
    }
    
    
    
    // MARK: - Theme
    private func applyTheme() {
        containerView?.backgroundColor = .clear
        
        // Title
        titleLabel.text = "Settings"
        titleLabel.font = AppTheme.Font.secondaryTitle
        titleLabel.textColor = AppTheme.Color.label
        
        // Dismiss
        var cfg = UIButton.Configuration.plain()
        cfg.baseForegroundColor = AppTheme.Color.accent
        cfg.image = UIImage(systemName: "xmark.square.fill")
        cfg.preferredSymbolConfigurationForImage = .init(pointSize: 18, weight: .semibold)
        dismissbutton.configuration = cfg
        
        // 카드 느낌 (옵션)
        [topView, containerView].forEach {
            $0?.layer.cornerRadius = AppTheme.Corner.l
            $0?.layer.cornerCurve = .continuous
            $0?.clipsToBounds = true
            AppTheme.Shadow.applyCard(to: $0!.layer)
        }
    }
    
}
    
    //MARK: - Gesture
extension SettingsVC: UIGestureRecognizerDelegate {
    @objc private func handleOutsideTap(_ g: UITapGestureRecognizer) {
        guard g.state == .ended else { return }
        guard presentedViewController == nil, !isBeingDismissed else { return }

        let p = g.location(in: view)
        // topView 바깥이면 닫기
        if !topView.frame.contains(p) {
            dismiss(animated: true)
        }
    }
        
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
    

    



//MARK: - Setting Store
import Foundation

final class SettingsStore {
    static let shared = SettingsStore()
    private init() {}
    
    private let kStatusBarHidden = "settings.statusBarHidden"
    var isStatusBarHidden: Bool {
        get { UserDefaults.standard.bool(forKey: kStatusBarHidden) }
        set { UserDefaults.standard.set(newValue, forKey: kStatusBarHidden) }
    }
    
    private var currencySymbolCache: [String:String] = [:]
    enum CurrencyCatalog {
        static let codes: [String] = [
            "None",
            "AED", "AUD", "BRL", "CAD", "CHF", "CLP", "CNY", "COP", "CZK",
            "DKK", "EUR", "GBP", "HKD", "HUF", "IDR", "ILS", "INR", "ISK",
            "JPY", "KRW", "MXN", "MYR", "NOK", "NZD", "PEN", "PHP", "PLN",
            "RON", "RUB", "SAR", "SEK", "SGD", "THB", "TRY", "TWD", "USD", "ZAR"
        ]
        private static func defaultFallback(for code: String) -> String {
            switch code {
            case "USD": return "$"
            case "EUR": return "€"
            case "JPY": return "¥"
            case "CNY": return "¥"
            case "KRW": return "₩"
            case "GBP": return "£"
            case "AUD": return "A$"
            case "CAD": return "C$"
            case "NZD": return "NZ$"
            case "HKD": return "HK$"
            case "SGD": return "S$"
            case "CHF": return "CHF"   // 스위스 프랑은 심볼보다는 코드 그대로 쓰는 경우가 많음
            case "SEK": return "kr"    // 스웨덴 크로나
            case "NOK": return "kr"    // 노르웨이 크로네
            case "DKK": return "kr"    // 덴마크 크로네
            case "CZK": return "Kč"    // 체코 코루나
            case "HUF": return "Ft"    // 헝가리 포린트
            case "PLN": return "zł"    // 폴란드 즈워티
            case "RON": return "lei"   // 루마니아 레우
            case "RUB": return "₽"     // 러시아 루블
            case "TRY": return "₺"     // 터키 리라
            case "INR": return "₹"     // 인도 루피
            case "IDR": return "Rp"    // 인도네시아 루피아
            case "MYR": return "RM"    // 말레이시아 링깃
            case "PHP": return "₱"     // 필리핀 페소
            case "THB": return "฿"     // 태국 바트
            case "MXN": return "MX$"   // 멕시코 페소
            case "BRL": return "R$"    // 브라질 헤알
            case "CLP": return "CLP$"  // 칠레 페소
            case "COP": return "COL$"  // 콜롬비아 페소
            case "PEN": return "S/."   // 페루 솔
            case "ZAR": return "R"     // 남아공 랜드
            case "AED": return "د.إ"   // UAE 디르함
            case "ILS": return "₪"     // 이스라엘 셰켈
            case "SAR": return "﷼"     // 사우디 리얄
            case "ISK": return "kr"    // 아이슬란드 크로나
            default: return ""          // 모르는 건 공백
            }
        }
        
        static func index(of code: String) -> Int {
            codes.firstIndex(of: code.uppercased()) ?? 0
        }
        
        // AppPullDownField용 아이템 변환
        static func pullDownItems() -> [AppPullDownField.Item] {
            codes.map { AppPullDownField.Item($0) }
        }
        
        // 저장 전 유효성 보정
        static func validated(_ code: String) -> String {
            let up = code.uppercased()
            return codes.contains(up) ? up : "None"
        }
        
        static func symbol(for code: String) -> String {
            let key = code.uppercased()
            guard key != "NONE", !key.isEmpty else { return "" }
            
            if let cached = SettingsStore.shared.currencySymbolCache[key] {
                return cached
            }
            
            // 1) 중립 로케일에서 대표 심볼 얻기
            let fmt = NumberFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.numberStyle = .currency
            fmt.currencyCode = key
            let raw = fmt.currencySymbol ?? ""
            
            // 2) 유니코드 카테고리로 정규화(통화 심볼만 추출)
            var sym = normalizeCurrencySymbol(from: raw)
            
            // 3) 실패 시 Locale 스캔 → 정규화
            if sym.isEmpty,
               let altRaw = Locale.availableIdentifiers
                .lazy
                .map({ Locale(identifier: $0) })
                .first(where: { $0.currencyCode?.uppercased() == key })?
                .currencySymbol {
                sym = normalizeCurrencySymbol(from: altRaw)
            }
            
            // 4) 그래도 없으면 최소 폴백
            if sym.isEmpty { sym = defaultFallback(for: key) }
            
            SettingsStore.shared.currencySymbolCache[key] = sym
            return sym
        }
        
        private static func normalizeCurrencySymbol(from raw: String) -> String {
            // 예: "JP¥" → "¥", "US$" → "$"
            let onlyCurrencyScalars = raw.unicodeScalars.filter {
                $0.properties.generalCategory == .currencySymbol
            }
            return String(String.UnicodeScalarView(onlyCurrencyScalars))
        }
    }
    
    var ccySymbol: String {
        CurrencyCatalog.symbol(for: ccyCode)
    }
    
    // 저장 시 유효성 보정
    var ccyCode: String {
        get { UserDefaults.standard.string(forKey: kCCY) ?? "None" }
        set { UserDefaults.standard.set(CurrencyCatalog.validated(newValue), forKey: kCCY) }
    }
    private var kCCY: String { "settings.main.ccy" }
    private var kUseComma: String { "settings.main.useComma" }
    private var kShowPayDay: String { "settings.main.showPayDay" }
    private var kShowDaysLeft: String { "settings.main.showDaysLeft" }
    private var kShowAmount: String { "settings.main.showAmount" }
    
    var useComma: Bool {
        get { UserDefaults.standard.object(forKey: kUseComma) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: kUseComma) }
    }
    var showPayDay: Bool {
        get { UserDefaults.standard.object(forKey: kShowPayDay) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: kShowPayDay) }
    }
    var showDaysLeft: Bool {
        get { UserDefaults.standard.object(forKey: kShowDaysLeft) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: kShowDaysLeft) }
    }
    var showAmount: Bool {
        get { UserDefaults.standard.object(forKey: kShowAmount) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: kShowAmount) }
    }
}


extension Notification.Name {
    static let settingsDidChange = Notification.Name("settings.didChange")
}


//MARK: - Status Bar
import UIKit

class BaseVC: UIViewController {
    override var prefersStatusBarHidden: Bool {
        SettingsStore.shared.isStatusBarHidden
    }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
}

// RootNavigationController.swift
import UIKit

final class RootNavigationController: UINavigationController {
    override var childForStatusBarHidden: UIViewController? { topViewController }
    override var childForStatusBarStyle: UIViewController? { topViewController }
}
extension UIWindowScene {
    func keyWindowTopController() -> UIViewController? {
        guard let win = windows.first(where: { $0.isKeyWindow }) else { return nil }
        var top = win.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        if let nav = top as? UINavigationController { return nav.topViewController }
        if let tab = top as? UITabBarController { return tab.selectedViewController }
        return top
    }
}


//MARK: - Export
extension SettingsVC {
    private func exportCSVTapped() {
        do {
            let ctx = CoreDataContextProvider.shared.viewContext
            let url = try CSVExporter.exportBindoAndOccurrences(context: ctx)

            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let pop = av.popoverPresentationController {
                pop.sourceView = exportButton
                pop.sourceRect = exportButton.bounds
            }
            present(av, animated: true)
        } catch {
            presentAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}


import CoreData
// Core Data Context Provider (안전하게 컨텍스트 구하기)
final class CoreDataContextProvider {
    static let shared = CoreDataContextProvider()
    private init() {}

    var viewContext: NSManagedObjectContext {
        Persistence.shared.viewContext
    }

    /// 대용량/백그라운드 내보내기용이 필요하면 이걸 사용
    func newBackgroundContext() -> NSManagedObjectContext {
        Persistence.shared.newBackgroundContext()
    }
}

// MARK: - CSV Exporter
enum CSVExporter {
    enum ExportError: Error {
        case noData
        case fileWriteFailed
    }

    /// 헤더: Name, Created Date, End Date, Payment Date, Payment Amount
    static func exportBindoAndOccurrences(context: NSManagedObjectContext) throws -> URL {
        // 1) Fetch Bindo + Prefetch occurrences
        let req = NSFetchRequest<Bindo>(entityName: "Bindo")
        req.includesPropertyValues = true
        req.relationshipKeyPathsForPrefetching = ["occurrences"]
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let bindos = try context.fetch(req)

        // 2) 포맷터
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy/MM/dd"

        // 금액: 로케일 영향 없는 문자열 (소수점 최대 2자리)
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "en_US_POSIX")
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = false
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2

        // 3) CSV 빌드
        var rows: [String] = []
        rows.append(csvLine([
            "Name", "Created Date", "End Date",
            "Payment Date", "Payment Amount"
        ]))

        for b in bindos {
            let name = b.name ?? ""
            let created = (b.createdAt).map(df.string(from:)) ?? ""
            let end = (b.endAt).map(df.string(from:)) ?? ""

            // occurrences 정렬(저장된 내역만)
            let occs: [Occurence] = (b.occurrences as? Set<Occurence> ?? [])
                .sorted { ($0.endDate ?? .distantPast) < ($1.endDate ?? .distantPast) }

            // Occurrence가 하나도 없으면 스킵 (요청: 이력만 내보냄)
            guard !occs.isEmpty else { continue }

            for o in occs {
                let payDate = (o.endDate).map(df.string(from:)) ?? ""
                let amountDec = o.payAmount?.decimalValue ?? 0
                let amount = nf.string(from: amountDec as NSDecimalNumber) ?? "\(amountDec)"

                rows.append(csvLine([name, created, end, payDate, amount]))
            }
        }

        guard rows.count > 1 else { throw ExportError.noData }

        let csv = rows.joined(separator: "\n")

        // 4) 파일 저장 (UTF-8 with BOM: Excel 호환)
        let bom = Data([0xEF, 0xBB, 0xBF])
        guard var data = csv.data(using: .utf8) else { throw ExportError.fileWriteFailed }
        data = bom + data

        let tmp = FileManager.default.temporaryDirectory
        let filename = "bindo_export_\(Int(Date().timeIntervalSince1970)).csv"
        let url = tmp.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)

        return url
    }

    // 셀 값 CSV 이스케이프 처리
    private static func csvEscape(_ s: String) -> String {
        // 따옴표/콤마/줄바꿈 포함 시 "…"로 감싸고 내부 "는 ""로 이스케이프
        if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }

    private static func csvLine(_ cols: [String]) -> String {
        cols.map(csvEscape).joined(separator: ",")
    }
}


//MARK: - Feedback
import MessageUI

extension SettingsVC: MFMailComposeViewControllerDelegate {
    
    @objc func sendFeedbackTapped() {
        guard MFMailComposeViewController.canSendMail() else {
            if let url = URL(string: "mailto:feedback@myapp.com?subject=[Feedback]%20Bindo%20App") {
                UIApplication.shared.open(url, options: [:]) { success in
                    if !success {
                        // 메일 앱 대체제도 없는 경우 → Alert 표시
                        let alert = UIAlertController(
                            title: "Mail Not Available",
                            message: "Please install or configure a mail app to send feedback.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            } else {
                // URL 생성조차 실패한 경우도 대비
                let alert = UIAlertController(
                    title: "Mail Not Available",
                    message: "Please install or configure a mail app to send feedback.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
            return
        }
        
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients(["feedback@myapp.com"]) // 앱용 이메일
        composer.setSubject("[Feedback] Bindo App")
        
        // 자동 정보 추가
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let systemVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        
        let body = """

        Please write your feedback above this line.

        -------------------
        App Version: \(appVersion) (\(buildNumber))
        Device: \(deviceModel)
        iOS: \(systemVersion)
        """
        
        composer.setMessageBody(body, isHTML: false)
        
        present(composer, animated: true)
    }
    
    // 닫기 핸들러
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true)
    }
}

