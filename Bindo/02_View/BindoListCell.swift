//
//  MoodViewCell.swift
//  Mood Journal
//
//  Created by Sean Choi on 8/28/25.
//

import UIKit



@MainActor
class BindoListCell: UITableViewCell {
    private var checkboxWidthConstraint: NSLayoutConstraint!
    private let expandedCheckboxWidth: CGFloat = 24
    private let expandedSpacing: CGFloat = 12
    private var lastIsChecked: Bool = false
    private lazy var separator = AppSeparator()

    
    // 상단
    private let nameLabel: UILabel = {
        let lb = UILabel()
        lb.font = AppTheme.Font.body
        lb.textColor = AppTheme.Color.label
        lb.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return lb
    }()

    private let amountLabel: UILabel = {
        let lb = UILabel()
        lb.font = AppTheme.Font.body
        lb.textColor = AppTheme.Color.label
        lb.textAlignment = .right
        lb.setContentCompressionResistancePriority(.required, for: .horizontal)
        return lb
    }()

    // 하단
    private let nextLabel: UILabel = {
        let lb = UILabel()
        lb.font = AppTheme.Font.secondaryBody
        lb.textColor = .systemGray2
        lb.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return lb
    }()

    private let intervalLabel: UILabel = {
        let lb = UILabel()
        lb.font = AppTheme.Font.secondaryBody
        lb.textColor = .systemGray2
        lb.textAlignment = .right
        lb.setContentCompressionResistancePriority(.required, for: .horizontal)
        return lb
    }()

    private lazy var topRow: UIStackView = {
        let st = UIStackView(arrangedSubviews: [nameLabel, amountLabel])
        st.axis = .horizontal
        st.alignment = .fill
        st.distribution = .fill
        st.spacing = 8
        return st
    }()

    private lazy var bottomRow: UIStackView = {
        let st = UIStackView(arrangedSubviews: [nextLabel, intervalLabel])
        st.axis = .horizontal
        st.alignment = .fill
        st.distribution = .fill
        st.spacing = 8
        return st
    }()
    
    //  Progress bar
    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.progressTintColor = AppTheme.Color.main2
        pv.trackTintColor = AppTheme.Color.main3.withAlphaComponent(0.25)
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.transform = CGAffineTransform(scaleX: 1, y: 1.4)
        pv.layer.cornerRadius = 3
        pv.clipsToBounds = true
        pv.subviews.forEach { $0.layer.cornerRadius = 3 }
        pv.progress = 0
        return pv
    }()
    
    private let checkboxView: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.isUserInteractionEnabled = false
        b.tintColor = .systemGray2
        b.setImage(UIImage(systemName: "circle"), for: .normal)
        b.setImage(UIImage(systemName: "checkmark.circle"), for: .selected)
        b.isHidden = true
        return b
    }()
    
    private func applyCheckboxTint(animated: Bool) {
        let target = checkboxView.isSelected ? AppTheme.Color.accent : UIColor.systemGray2
        guard animated else {
            checkboxView.tintColor = target
            return
        }
        UIView.transition(with: checkboxView,
                          duration: 0.18,
                          options: .transitionCrossDissolve,
                          animations: {
            self.checkboxView.tintColor = target
        })
    }
    
    func setChecked(_ checked: Bool, animated: Bool) {
        let before = checkboxView.isSelected
        checkboxView.isSelected = checked
        
        applyCheckboxTint(animated: animated)
        guard animated, before != checked else { return }

        // 이미지 크로스디졸브 + 살짝 바운스
        if let iv = checkboxView.imageView {
            UIView.transition(with: iv,
                              duration: 0.18,
                              options: .transitionCrossDissolve,
                              animations: nil,
                              completion: nil)
        }
        let bounce: CGFloat = 1.12
        checkboxView.transform = CGAffineTransform(scaleX: bounce, y: bounce)
        UIView.animate(withDuration: 0.22,
                       delay: 0,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.5,
                       options: .curveEaseOut,
                       animations: { self.checkboxView.transform = .identity },
                       completion: nil)

        lastIsChecked = checked
    }
    
    func setEditingMode(_ on: Bool, animated: Bool) {
        let targetWidth = on ? expandedCheckboxWidth : 0
        let targetAlpha: CGFloat = on ? 1 : 0
        let targetSpacing: CGFloat = on ? expandedSpacing : 0
        selectionStyle = on ? .none : .default
        checkboxView.isAccessibilityElement = on

        let apply = {
            self.checkboxWidthConstraint.constant = targetWidth
            self.checkboxView.alpha = targetAlpha
            self.rowContainer.spacing = targetSpacing
            self.contentView.layoutIfNeeded()
        }

        if animated {
            if on { self.checkboxView.transform = CGAffineTransform(translationX: -6, y: 0) }
            // 표시 쪽은 미리 보이게, 숨김 쪽은 애니 후 감춤
            if on { self.checkboxView.isHidden = false }

            UIView.animate(withDuration: 0.18,
                           delay: 0,
                           options: [.curveEaseInOut, .allowUserInteraction],
                           animations: {
                apply()
                self.checkboxView.transform = .identity
            }, completion: { _ in
                if !on { self.checkboxView.isHidden = true }
            })
        }  else {
            apply()
            checkboxView.isHidden = !on
        }
    }
    

    private lazy var root: UIStackView = {
        let st = UIStackView(arrangedSubviews: [topRow, bottomRow])
        st.axis = .vertical
        st.alignment = .fill
        st.distribution = .fill
        st.spacing = 8
        return st
    }()
    
    private lazy var rowContainer: UIStackView = {
        let st = UIStackView(arrangedSubviews: [checkboxView, root])
        st.axis = .horizontal
        st.alignment = .fill
        st.distribution = .fill
        st.spacing = 12
        return st
    }()
    

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    private func buildUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        rowContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowContainer)
        contentView.addSubview(progressView)

        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = .systemGray3
        contentView.addSubview(separator)

        // 체크박스 width 제약 초기값 0
        checkboxWidthConstraint = checkboxView.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            rowContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            rowContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rowContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            progressView.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: rowContainer.bottomAnchor, constant: 8),
            progressView.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -8),

            separator.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor, constant: -8),
            separator.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor, constant: 8),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            // 체크박스 폭 제약 활성화
            checkboxWidthConstraint
        ])
    }

    // 구성
    func configure(name: String, amount: String, next: String, interval: String,
                   isEditingMode: Bool, isChecked: Bool) {
        nameLabel.text = name
        amountLabel.text = amount
        nextLabel.text = next
        intervalLabel.text = interval

        setEditingMode(isEditingMode, animated: false)
        setChecked(isChecked, animated: false)
    }
    
override func prepareForReuse() {
    super.prepareForReuse()
    contentView.alpha = 1

    // 편집 UI 기본값 확실히 원복
    checkboxView.alpha = 0
    checkboxView.isHidden = true
    setEditingMode(false, animated: false)
    setChecked(false, animated: false)
}
    
    func setProgress(start: Date?, next: Date?, endAt: Date?, last: Date?, today: Date = Date()) {
        let cal = Calendar.current
        let t = cal.startOfDay(for: today)

        // --- 1) endAt이 과거거나 오늘 → 무조건 숨김
        if let endAt, cal.startOfDay(for: endAt) <= t {
            progressView.isHidden = true
            progressView.progress = 0
            return
        }

        // --- 2) 더 이상 발생할 Occurrence가 없는 경우
        if let endAt, let last {
            if cal.startOfDay(for: last) < cal.startOfDay(for: endAt),
               cal.startOfDay(for: last) <= t {
                progressView.isHidden = true
                progressView.progress = 0
                return
            }
        }

        // --- 3) 오늘이 종료일 → 0 days left → 꽉 찬 progress
        if let next {
            let n = cal.startOfDay(for: next)
            if n == t {
                progressView.isHidden = false
                progressView.progress = 1.0
                return
            }
        }

        // --- 4) 정상적인 진행도 계산
        guard let start, let next else {
            progressView.isHidden = true
            progressView.progress = 0
            return
        }

        let s = cal.startOfDay(for: start)
        let n = cal.startOfDay(for: next)

        if n <= s {
            progressView.isHidden = false
            progressView.progress = 1
            return
        }

        let total   = max(1, cal.dateComponents([.day], from: s, to: n).day ?? 0)
        let elapsed = min(max(0, cal.dateComponents([.day], from: s, to: t).day ?? 0), total)
        let value   = Float(elapsed) / Float(total)

        progressView.isHidden = false
        progressView.setProgress(value, animated: false)
    }
}

