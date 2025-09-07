//
//  LineChartView.swift
//  Bindo
//
//  Created by Sean Choi on 9/15/25.
//

import UIKit

/// 날짜→값 시계열을 길게 스크롤해서 보여주는 차트
final class ContinuousChartView: UIView, UIScrollViewDelegate {
    
    // 공개 API
    struct Series {
        let startDate: Date
        let step: TimeInterval      // 샘플 간 간격(초). 예: 하루 = 86400
        let values: [Double]        // 균등 간격 시계열
    }
    
    var lineColor: UIColor = AppTheme.Color.accent
    var fillTop: UIColor = AppTheme.Color.accent.withAlphaComponent(0.18)
    var fillBottom: UIColor = AppTheme.Color.accent.withAlphaComponent(0.06)
    var lineWidth: CGFloat = 3
    var plotInset: UIEdgeInsets = .init(top: 16, left: 32, bottom: 28, right: 12)
    
    
    // 스크롤/스케일
    var pointsPerStep: CGFloat = 8 { didSet { relayout() } } // 1샘플 = n pt
    var contentInsetX: CGFloat = 16 { didSet { relayout() } } // 좌우 여백
    
    private let scrollView = UIScrollView()
    private let canvas = ChartCanvasView()
    
    private var series: Series?
    private var maxY: Double = 1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }
    
    private func build() {
        backgroundColor = .clear
        
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = true
        addSubview(scrollView)
        
        canvas.isOpaque = false
        scrollView.addSubview(canvas)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        relayout()
    }
    
    private func relayout() {
        guard let s = series else { return }
        // 전체 폭 = (values.count - 1) * pointsPerStep + 좌우 인셋
        let width = max(bounds.width, CGFloat(max(s.values.count - 1, 0)) * pointsPerStep + contentInsetX * 2)
        let height = bounds.height
        scrollView.contentSize = CGSize(width: width, height: height)
        canvas.frame = CGRect(origin: .zero, size: scrollView.contentSize)
        canvas.config = .init(
            series: s,
            maxY: maxY,
            pointsPerStep: pointsPerStep,
            contentInsetX: contentInsetX,
            lineColor: lineColor,
            fillTop: fillTop,
            fillBottom: fillBottom,
            lineWidth: lineWidth,
            plotInset: plotInset
        )
        canvas.setNeedsDisplay()
    }
    
    // 외부에서 데이터 주입
    func configure(series: Series, maxY: Double) {
        self.series = series
        self.maxY = max(1, maxY)
        relayout()
    }
    
    // 스크롤 중 보이는 영역만 다시 그리기
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        canvas.setNeedsDisplay()
    }
}

/// 실제 그리기 담당
private final class ChartCanvasView: UIView {
    struct Config {
        let series: ContinuousChartView.Series
        let maxY: Double
        let pointsPerStep: CGFloat
        let contentInsetX: CGFloat
        let lineColor: UIColor
        let fillTop: UIColor
        let fillBottom: UIColor
        let lineWidth: CGFloat
        let plotInset: UIEdgeInsets          // ← 추가
    }
    var config: Config!
    
    override func draw(_ rect: CGRect) {
        guard let cfg = config else { return }
        guard cfg.series.values.count >= 2 else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        
        let values = cfg.series.values
        
        // 동일한 플롯 사각형(축/그리드와 완전 동일)
        let plot = bounds.inset(by: cfg.plotInset)
        let H = plot.height
        
        // 그려야 하는 구간 계산 (가시 영역)
        let leftIndex  = max(0, Int(((rect.minX - cfg.contentInsetX) / cfg.pointsPerStep).rounded(.down)))
        let rightIndex = min(values.count - 1, Int(((rect.maxX - cfg.contentInsetX) / cfg.pointsPerStep).rounded(.up)))
        
        // 좌표 매핑 (plot 사각형 기준)
        func y(_ v: Double) -> CGFloat {
            let r = CGFloat(v / max(cfg.maxY, 1))
            return plot.maxY - r * H
        }
        func x(_ i: Int) -> CGFloat {
            plot.minX + CGFloat(i) * cfg.pointsPerStep
        }
        
        // 다운샘플링: 1px에 여러포인트면 간단히 stride로 줄이기
        let pixelStep = max(1, Int(ceil(1.0 / Double(cfg.pointsPerStep))))
        let strideStep = max(1, pixelStep)
        
        // 라인 경로
        let line = UIBezierPath()
        var started = false
        var minYForX = CGFloat.infinity
        var maxYForX = -CGFloat.infinity
        var lastX = CGFloat.leastNormalMagnitude
        
        var i = leftIndex
        while i <= rightIndex {
            let xi = x(i)
            let yi = y(values[i])
            if !started {
                started = true
                lastX = xi
                minYForX = yi
                maxYForX = yi
            }
            if abs(xi - lastX) < 1 {
                minYForX = min(minYForX, yi)
                maxYForX = max(maxYForX, yi)
            } else {
                if line.isEmpty { line.move(to: CGPoint(x: lastX, y: minYForX)) }
                else            { line.addLine(to: CGPoint(x: lastX, y: minYForX)) }
                if maxYForX != minYForX {
                    line.addLine(to: CGPoint(x: lastX, y: maxYForX))
                }
                lastX = xi
                minYForX = yi
                maxYForX = yi
            }
            i += strideStep
        }
        if started {
            if line.isEmpty { line.move(to: CGPoint(x: lastX, y: minYForX)) }
            else            { line.addLine(to: CGPoint(x: lastX, y: minYForX)) }
            if maxYForX != minYForX {
                line.addLine(to: CGPoint(x: lastX, y: maxYForX))
            }
        }
        
        // 채움은 plot 하단까지 닫기
        let fill = UIBezierPath(cgPath: line.cgPath)
        fill.addLine(to: CGPoint(x: line.currentPoint.x, y: plot.maxY))
        fill.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        fill.close()
        
        ctx.saveGState()
        ctx.addPath(fill.cgPath)
        ctx.setFillColor(cfg.fillTop.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        
        ctx.addPath(line.cgPath)
        ctx.setStrokeColor(cfg.lineColor.cgColor)
        ctx.setLineWidth(cfg.lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
    }
}

//MARK: - AxisOverlay
final class AxisOverlayView: UIView {
    
    // 설정값
    private var seriesStart: Date = .distantPast
    private var step: TimeInterval = 86_400
    private var count: Int = 0
    private var maxY: Double = 1
    private var granularity: StatsGranularity = .month
    private var cal: Calendar = .current
    var plotInset: UIEdgeInsets = .init(top: 16, left: 32, bottom: 28, right: 12)
    
    
    // 스타일
    private let axisColor = AppTheme.Color.main3.withAlphaComponent(0.4)
    private let gridColor = AppTheme.Color.main3.withAlphaComponent(0.2)
    private let labelColor = AppTheme.Color.main2
    private let labelFont = AppTheme.Font.caption
    
    func configure(seriesStart: Date,
                   step: TimeInterval,
                   count: Int,
                   maxY: Double,
                   granularity: StatsGranularity,
                   calendar: Calendar)
    {
        self.seriesStart = seriesStart
        self.step = step
        self.count = count
        self.maxY = max(1, maxY)
        self.granularity = granularity
        self.cal = calendar
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
            guard count > 0 else { return }
            let ctx = UIGraphicsGetCurrentContext()!

            // 차트와 동일한 플롯 사각형
            let plot = rect.inset(by: plotInset)

            // 축
            ctx.setStrokeColor(axisColor.cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: plot.minX, y: plot.minY))
            ctx.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
            ctx.move(to: CGPoint(x: plot.minX, y: plot.maxY))
            ctx.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            ctx.strokePath()

            // Y 그리드/라벨 (동일)
            let yTicks = niceTicks(min: 0, max: maxY, tickCount: 5)
            ctx.setStrokeColor(gridColor.cgColor)
            ctx.setLineWidth(0.5)
            for t in yTicks {
                let y = plot.maxY - CGFloat(t / maxY) * plot.height
                ctx.move(to: CGPoint(x: plot.minX, y: y))
                ctx.addLine(to: CGPoint(x: plot.maxX, y: y))
            }
            ctx.strokePath()
            for t in yTicks {
                let y = plot.maxY - CGFloat(t / maxY) * plot.height
                drawLabel(text: yLabel(for: t), at: CGPoint(x: plot.minX - 4, y: y), anchor: .rightCenter)
            }

            // X 라벨/그리드
            let xTickDates = xTicks()
            let stepWidth  = plot.width / CGFloat(max(1, count - 1))
            for d in xTickDates {
                let i = round(d.timeIntervalSince(seriesStart) / step)
                guard i >= 0, i < Double(count) else { continue }
                let x = plot.minX + CGFloat(i) * stepWidth

                ctx.setStrokeColor(gridColor.cgColor)
                ctx.setLineWidth(0.5)
                ctx.move(to: CGPoint(x: x, y: plot.minY))
                ctx.addLine(to: CGPoint(x: x, y: plot.maxY))
                ctx.strokePath()

                drawLabel(text: xLabel(for: d), at: CGPoint(x: x, y: plot.maxY + 2), anchor: .topCenter)
            }
        }
    
    // MARK: - 라벨 유틸
    
    private func yLabel(for v: Double) -> String {
        if v >= 1_000_000 { return String(format: "%.1fm", v/1_000_000) }
        if v >= 1_000 { return String(format: "%.1fk", v/1_000) }
        if v == floor(v) { return String(format: "%.0f", v) }
        return String(format: "%.2f", v)
    }
    
    private func xLabel(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        switch granularity {
        case .month:
            df.dateFormat = "d" // 일
        case .year:
            df.dateFormat = "MMM" // Jan, Feb...
        }
        return df.string(from: date)
    }
    
    /// 월/일 기준 틱 날짜 생성
    private func xTicks() -> [Date] {
        switch granularity {
        case .month:
            let rng = cal.range(of: .day, in: .month, for: seriesStart) ?? (1..<29)
            // 5~7개로 downsample
            let days = Array(rng)
            let stride = max(1, days.count / 6)
            return days.stride(by: stride).compactMap { day -> Date? in
                var c = cal.dateComponents([.year, .month], from: seriesStart)
                c.day = day
                return cal.date(from: c)
            }
        case .year:
            // 12개월 중 6개 라벨 정도
            let months = Array(1...12)
            let stride = 2
            return months.stride(by: stride).compactMap { m -> Date? in
                var c = cal.dateComponents([.year], from: seriesStart)
                c.month = m
                c.day = 1
                return cal.date(from: c)
            }
        }
    }
    
    /// 보기 좋은 눈금 (D3의 nice ticks와 유사한 간단 버전)
    private func niceTicks(min: Double, max: Double, tickCount: Int) -> [Double] {
        guard max > min, tickCount > 1 else { return [min, max] }
        let span = max - min
        let step = niceStep(span / Double(tickCount - 1))
        let niceMin = floor(min / step) * step
        let niceMax = ceil(max / step) * step
        var ticks: [Double] = []
        var v = niceMin
        while v <= niceMax + step*0.5 {
            ticks.append(v)
            v += step
        }
        return ticks
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
    
    private enum Anchor {
        case rightCenter, topCenter
    }
    private func drawLabel(text: String, at p: CGPoint, anchor: Anchor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: labelColor
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        var origin = p
        switch anchor {
        case .rightCenter:
            origin.x -= size.width + 4
            origin.y -= size.height/2
        case .topCenter:
            origin.x -= size.width/2
            // p는 축 바로 위(아래) 기준, 약간 내려그림
        }
        (text as NSString).draw(at: origin, withAttributes: attrs)
    }
}

// 작은 헬퍼
private extension Array where Element == Int {
    func stride(by n: Int) -> [Int] {
        guard n > 0 else { return self }
        var out: [Int] = []
        var i = 0
        while i < count {
            out.append(self[i])
            i += n
        }
        if let last = self.last, out.last != last { out.append(last) }
        return out
    }
}
