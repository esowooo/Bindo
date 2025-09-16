//
//  MoodViewCell.swift
//  Mood Journal
//
//  Created by Sean Choi on 8/28/25.
//

import UIKit



@MainActor
class BindoListCell: UITableViewCell {
    
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
    
    private lazy var separator = AppSeparator()


    private lazy var root: UIStackView = {
        let st = UIStackView(arrangedSubviews: [topRow, bottomRow])
        st.axis = .vertical
        st.alignment = .fill
        st.distribution = .fill
        st.spacing = 8
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

        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)
        contentView.addSubview(progressView)
        
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = .systemGray3
        contentView.addSubview(separator)


        NSLayoutConstraint.activate([
            // Root stack
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            
            // ProgressView: root 아래, separator 위
            progressView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: root.bottomAnchor, constant: 8),
            progressView.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -8),
            
            // Separator: progressView 아래, contentView에 붙임
            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: -8),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: 8),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale) // 두께 통일
        ])
    }

    // 구성
    func configure(name: String, amount: String, next: String, interval: String) {
        nameLabel.text = name
        amountLabel.text = amount
        nextLabel.text = "\(next)"
        intervalLabel.text = interval
    }
    
    
    func setProgress(start: Date?, next: Date?, endAt: Date?, today: Date = Date()) {
        let cal = Calendar.current
        let t = cal.startOfDay(for: today)

        // endAt이 과거면 무조건 숨김
        if let endAt, cal.startOfDay(for: endAt) < t {
            progressView.isHidden = true
            progressView.progress = 0
            return
        }

        guard let start, let next else {
            progressView.isHidden = true
            progressView.progress = 0
            return
        }

        let s = cal.startOfDay(for: start)
        let n = cal.startOfDay(for: next)

        if n <= s {
            // 비정상 구간 보호: 진행도 꽉 찬 상태로 표시 or 숨김 중 택1
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

