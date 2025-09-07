//
//  CalendarDayCell.swift
//  Bindo
//
//  Created by Sean Choi on 9/14/25.
//

import UIKit

final class CalendarDayCell: UICollectionViewCell {
    // UI
    private let dayLabel = UILabel()
    private let countButton = UIButton(type: .system)
    private let todayUnderbar = UIView()

    // 상태
    private(set) var isInCurrentMonth: Bool = true
    private var cellDate: Date?
    private var eventsForDay: [CalendarEvent] = []

    // VC로 전달할 콜백
    var onTapEvents: ((Date, [CalendarEvent]) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    private func buildUI() {
        contentView.backgroundColor = .clear

        // 날짜 라벨
        dayLabel.font = AppTheme.Font.body
        dayLabel.textColor = AppTheme.Color.label
        dayLabel.textAlignment = .center

        // 카운트 버튼 (배지 대신)
        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = AppTheme.Color.accent
        cfg.cornerStyle = .capsule
        cfg.contentInsets = .init(top: 2, leading: 4, bottom: 2, trailing: 4) // 작고 단단하게
        cfg.titleAlignment = .center
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = AppTheme.Font.caption
            out.foregroundColor = AppTheme.Color.background
            return out
        }
        countButton.configuration = cfg
        countButton.isHidden = true // 기본 감춤
        countButton.addAction(UIAction { [weak self] _ in
            guard
                let self = self,
                let date = self.cellDate,
                !self.eventsForDay.isEmpty
            else { return }
            self.onTapEvents?(date, self.eventsForDay)
        }, for: .touchUpInside)

        [dayLabel, todayUnderbar, countButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        todayUnderbar.backgroundColor = AppTheme.Color.accent
        todayUnderbar.layer.cornerRadius = 0
        todayUnderbar.isHidden = true

        NSLayoutConstraint.activate([
            // 날짜
            dayLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // 오늘 점 뱃지 (dayLabel 아래 작게)
            todayUnderbar.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 2),
            todayUnderbar.centerXAnchor.constraint(equalTo: dayLabel.centerXAnchor),
            todayUnderbar.widthAnchor.constraint(equalTo: dayLabel.widthAnchor, multiplier: 0.6), // 날짜보다 살짝 짧게
            todayUnderbar.heightAnchor.constraint(equalToConstant: 2), // 얇은 선

            // 카운트 버튼
            countButton.topAnchor.constraint(equalTo: todayUnderbar.bottomAnchor, constant: 6),
            countButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            countButton.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6),
            countButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 22)
        ])

        selectedBackgroundView = UIView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isInCurrentMonth = true
        cellDate = nil
        eventsForDay = []
        dayLabel.textColor = AppTheme.Color.main1
        countButton.isHidden = true
        countButton.configuration?.title = nil
        todayUnderbar.isHidden = true
    }

    /// 셀 구성
    func configure(day: Int,
                   date: Date,
                   inCurrentMonth: Bool,
                   isToday: Bool,
                   events: [CalendarEvent]) {
        self.cellDate = date
        self.eventsForDay = events
        self.isInCurrentMonth = inCurrentMonth

        dayLabel.text = "\(day)"

        // 주말 여부
        let isWeekend = CalendarUtils.cal.isDateInWeekend(date)

        // 색상 규칙:
        if !inCurrentMonth {
            dayLabel.textColor = AppTheme.Color.main3
        } else if isToday || isWeekend {
            dayLabel.textColor = AppTheme.Color.main1
        } else {
            dayLabel.textColor = AppTheme.Color.label
        }

        // 오늘 점 뱃지
        todayUnderbar.isHidden = !isToday

        // 카운트 버튼
        if events.isEmpty {
            countButton.isHidden = true
        } else {
            countButton.isHidden = false
            var cfg = countButton.configuration
            cfg?.title = "\(events.count)"
            countButton.configuration = cfg
        }
    }
}
