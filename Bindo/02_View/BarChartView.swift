//
//  BarChartView.swift
//  Bindo
//

import UIKit



// MARK: - Shared number formatting (plain numeric, no locale)
fileprivate func formatPlainNumber(_ v: Double) -> String {
    return (v == floor(v)) ? String(format: "%.0f", v)
                           : String(format: "%.2f", v)
}

/// 스크롤 없이 현재 선택된 범위를 화면 너비에 맞춰 그리는 막대 차트.
/// - X 라벨은 막대 아래에 함께 그림
/// - Y 축/그리드/기준선은 아래 AxisOverlayView 가 담당
final class BarChartView: UIView {

    // MARK: - Public Models
    struct Series {
        let startDate: Date      // 인덱스 0 막대의 기준 날짜(월/연의 시작일 등)
        let step: TimeInterval   // 막대 간 간격(월 모드: 약 30일, 연 모드: 약 365일) — 인덱스 계산용
        let values: [Double]     // 막대 높이
    }

    enum Granularity { case month, year }

    // MARK: - Style
    /// 플롯(그래프) 안쪽 여백 — 왼쪽 0이면 Y축이 뷰에 딱 붙음
    var plotInset: UIEdgeInsets = .init(top: 16, left: 0, bottom: 36, right: 0) { didSet { setNeedsDisplay() } }
    /// Y축과 첫 막대 사이 여백
    var axisPadding: CGFloat = 8 { didSet { setNeedsDisplay() } }
    /// 막대 폭/간격(StatsVC에서 화면폭에 맞게 계산해 주입)
    var barWidth: CGFloat = 22 { didSet { setNeedsDisplay() } }
    var barGap: CGFloat   = 14 { didSet { setNeedsDisplay() } }
    var barCorner: CGFloat = 6
    var fillColor: UIColor = AppTheme.Color.main1.withAlphaComponent(0.18)
    var lineColor: UIColor = AppTheme.Color.main1
    var xLabelFont: UIFont = AppTheme.Font.caption
    var xLabelColor: UIColor = AppTheme.Color.main2
    var highlightIndex: Int? { didSet { setNeedsDisplay() } }
    var highlightFillColor: UIColor = AppTheme.Color.accent.withAlphaComponent(0.30)
    var highlightLineColor: UIColor = AppTheme.Color.accent
    var showsHighlightValue: Bool = true { didSet { setNeedsDisplay() } }
    var valueFont: UIFont = AppTheme.Font.caption
    var valueTextColor: UIColor = AppTheme.Color.accent
    var valueBubbleColor: UIColor = AppTheme.Color.background
    var valueBubbleStrokeColor: UIColor = AppTheme.Color.accent
    var valueBubbleStrokeWidth: CGFloat = 1

    // MARK: - Data
    private var series: Series?
    private var maxY: Double = 1
    private var granularity: Granularity = .month
    private var calendar: Calendar = .current

    // MARK: - Public API
    /// 데이터 주입
    func configure(series: Series,
                   maxY: Double,
                   granularity: Granularity,
                   calendar: Calendar = .current) {
        self.series = series
        self.maxY = max(1, maxY)
        self.granularity = granularity
        self.calendar = calendar
        setNeedsDisplay()
    }

    /// 특정 막대 인덱스의 X(뷰 좌표, 막대 중앙) — 기준선 위치 계산용
    func xPositionForBar(index: Int) -> CGFloat? {
        guard let s = series, index >= 0, index < s.values.count else { return nil }
        let plot = bounds.inset(by: plotInset)
        let step = barWidth + barGap
        let totalW = CGFloat(s.values.count) * step - barGap
        // 남는 공간을 좌우로 균등 분배(가운데 정렬)
        let startX = plot.minX + axisPadding + max(0, (plot.width - axisPadding*2 - totalW) / 2)
        return startX + CGFloat(index) * step + barWidth/2
    }

    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard let s = series, let ctx = UIGraphicsGetCurrentContext() else { return }
        let values = s.values
        guard !values.isEmpty else { return }

        let plot = bounds.inset(by: plotInset)
        let step = barWidth + barGap
        let totalW = CGFloat(values.count) * step - barGap
        let startX = plot.minX + axisPadding + max(0, (plot.width - axisPadding*2 - totalW) / 2)

        // 1) 막대: 플롯 영역으로만 클리핑
        ctx.saveGState()
        ctx.clip(to: plot)

        let H = max(1, plot.height)
        func barRect(_ i: Int) -> CGRect {
            let v = max(0, values[i])
            let h = CGFloat(v / max(maxY, 1)) * H
            let x = startX + CGFloat(i) * step
            return CGRect(x: x, y: plot.maxY - h, width: barWidth, height: h)
        }

        // 채움
        for i in 0..<values.count {
            let r = barRect(i)
            let path = UIBezierPath(roundedRect: r, cornerRadius: barCorner)
            let fill = (i == highlightIndex) ? highlightFillColor : fillColor
            ctx.setFillColor(fill.cgColor)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }
        // 외곽선
        for i in 0..<values.count {
            let r = barRect(i)
            let path = UIBezierPath(roundedRect: r, cornerRadius: barCorner)
            let stroke = (i == highlightIndex) ? highlightLineColor : lineColor
            ctx.setStrokeColor(stroke.cgColor)
            ctx.setLineWidth(1)
            ctx.addPath(path.cgPath)
            ctx.strokePath()
        }
        
        if showsHighlightValue, let hi = highlightIndex, (0..<values.count).contains(hi) {
            let v = max(0, values[hi])
            // 막대 rect 함수는 기존 그대로 사용
            let H = max(1, plot.height)
            let h = CGFloat(v / max(maxY, 1)) * H
            let x = startX + CGFloat(hi) * step
            let r = CGRect(x: x, y: plot.maxY - h, width: barWidth, height: h)
            
            let text = formatPlainNumber(v)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: valueFont,
                .foregroundColor: valueTextColor
            ]
            let size = (text as NSString).size(withAttributes: attrs)
            let padH: CGFloat = 6
            let padV: CGFloat = 3
            // 기본 위치: 막대 상단 6pt 위
            var bubbleY = r.minY - size.height - 6 - 2*padV
            // 플롯 꼭대기에 닿으면 안쪽으로 내림
            let minY = plot.minY + 2
            if bubbleY < minY { bubbleY = minY }
            
            let bubbleW = size.width + 2*padH
            let bubbleH = size.height + 2*padV
            let bubbleX = r.midX - bubbleW/2
            let bubble = CGRect(x: bubbleX, y: bubbleY, width: bubbleW, height: bubbleH)
            
            let path = UIBezierPath(roundedRect: bubble, cornerRadius: bubbleH/2)
            ctx.setFillColor(valueBubbleColor.cgColor)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
            ctx.setStrokeColor(valueBubbleStrokeColor.cgColor)
            ctx.setLineWidth(valueBubbleStrokeWidth)
            ctx.addPath(path.cgPath)
            ctx.strokePath()
            
            (text as NSString).draw(at: CGPoint(x: bubble.minX + padH, y: bubble.minY + padV), withAttributes: attrs)
        }
        
        // 클리핑 해제
        ctx.restoreGState()

        // 2) X 라벨: 플롯 바깥(아래)에서 보이도록 클리핑 없이 그림
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = (granularity == .month) ? "MM" : "yyyy"

        let attrs: [NSAttributedString.Key: Any] = [
            .font: xLabelFont,
            .foregroundColor: xLabelColor
        ]
        for i in 0..<values.count {
            let d: Date
            switch granularity {
            case .month:
                d = calendar.date(byAdding: .month, value: i, to: s.startDate) ?? s.startDate
            case .year:
                d = calendar.date(byAdding: .year, value: i, to: s.startDate) ?? s.startDate
            }
            let text = df.string(from: d)
            let size = (text as NSString).size(withAttributes: attrs)
            let cx = startX + CGFloat(i) * step + barWidth/2
            let y  = plot.maxY + (plotInset.bottom - size.height) / 2
            (text as NSString).draw(at: CGPoint(x: cx - size.width/2, y: y), withAttributes: attrs)
        }
    }
}


/// Y 축/그리드/라벨 + 기준선(타이틀과 동기화)을 그리는 오버레이 뷰
final class AxisOverlayView: UIView {

    // 플롯 안쪽 여백 — BarChartView 와 동일 값으로 세팅해야 정렬됨
    var plotInset: UIEdgeInsets = .init(top: 16, left: 0, bottom: 36, right: 0) { didSet { setNeedsDisplay() } }

    private var maxY: Double = 1
    private var referenceX: CGFloat? = nil // 기준선(뷰 좌표계의 X)

    // 스타일
    private let axisColor = AppTheme.Color.main3.withAlphaComponent(0.4)
    private let gridColor = AppTheme.Color.main3.withAlphaComponent(0.2)
    private let labelColor = AppTheme.Color.main2
    private let labelFont  = AppTheme.Font.caption
    private let labelEdgePadding: CGFloat = 2

    // 데이터 주입
    func configure(maxY: Double) {
        self.maxY = max(1, maxY)
        setNeedsDisplay()
    }

    // 기준선 위치 주입(없으면 nil)
    func setReferenceX(_ x: CGFloat?) {
        self.referenceX = x
        setNeedsDisplay()
    }

    // 그리기
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let plot = rect.inset(by: plotInset)

        // 축
        ctx.setStrokeColor(axisColor.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: plot.minX, y: plot.minY))
        ctx.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        ctx.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        ctx.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        ctx.strokePath()

        // Y 그리드
        let ticks = niceTicks(min: 0, max: maxY, tickCount: 5)
           for t in ticks {
               let y = plot.maxY - CGFloat(t / maxY) * plot.height
               let text = formatPlainNumber(t)
               let attrs: [NSAttributedString.Key: Any] = [
                   .font: labelFont,
                   .foregroundColor: labelColor
               ]
               let size = (text as NSString).size(withAttributes: attrs)
               // 라벨이 완전히 보이는지 검사 (위·아래 경계)
               let labelMinY = y - size.height / 2
               let labelMaxY = y + size.height / 2
               let safeTop   = plot.minY + labelEdgePadding
               let safeBot   = plot.maxY - labelEdgePadding

               guard labelMinY >= safeTop, labelMaxY <= safeBot else {
                   // 경계에 걸리면 그리지 않음
                   continue
               }

               drawLabel(text: text,
                         at: CGPoint(x: plot.minX + 4, y: y),
                         anchor: .leftCenter)
           }
    }

    // MARK: - Utils

    private func niceTicks(min: Double, max: Double, tickCount: Int) -> [Double] {
        guard max > min, tickCount > 1 else { return [min, max] }
        let span = max - min
        let step = niceStep(span / Double(tickCount - 1))
        let niceMin = floor(min / step) * step
        let niceMax = ceil(max / step) * step
        var out: [Double] = []
        var v = niceMin
        while v <= niceMax + step * 0.5 {
            out.append(v)
            v += step
        }
        return out
    }

    private func niceStep(_ rough: Double) -> Double {
        let exp = floor(log10(rough))
        let f = rough / pow(10, exp)
        let nf: Double
        switch f {
        case ..<1.5: nf = 1
        case ..<3:   nf = 2
        case ..<7:   nf = 5
        default:     nf = 10
        }
        return nf * pow(10, exp)
    }

    private enum Anchor { case leftCenter }
    private func drawLabel(text: String, at p: CGPoint, anchor: Anchor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: labelColor
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        var o = p
        switch anchor {
        case .leftCenter:
            o.x += 4; o.y -= size.height / 2
        }
        (text as NSString).draw(at: o, withAttributes: attrs)
    }
}
