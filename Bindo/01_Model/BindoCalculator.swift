

import Foundation

enum BindoFormError: Error, LocalizedError {
    case missingField(String)
    case invalidInterval
    case invalidIntervalEqual
    case invalidIntervalReversed
    case notEnoughPointsForInference
    case inferredIntervalUnsupported

    var errorDescription: String? {
        switch self {
        case .missingField(let f): return "Please input \(f)"
        case .notEnoughPointsForInference: return "Need two dates minimum in order to calculate interval."
        case .inferredIntervalUnsupported: return "Couldn't identify either day or month interval."
        case .invalidInterval: return "Please enter a valid interval"
        case .invalidIntervalEqual: return "Start date and end/next date cannot be the same."
        case .invalidIntervalReversed: return "Start date must be before the end/next date."
        }
    }
}

extension BindoForm {
    @inline(__always)
    func validateStart(_ start: Date, before other: Date) throws {
        switch start.compare(other) {
        case .orderedSame:       throw BindoFormError.invalidIntervalEqual
        case .orderedDescending: throw BindoFormError.invalidIntervalReversed
        case .orderedAscending:  break
        }
    }

    @inline(__always)
    func requireAmount(_ amount: Decimal?, fieldName: String) throws -> Decimal {
        guard let v = amount, v > 0 else { throw BindoFormError.missingField(fieldName) }
        return v
    }
}


enum BindoCalculator {

    /// today 이상 첫 occurrence 날짜
    static func nextPayDay(afterOrOn today: Date,
                           start: Date,
                           interval: Interval,
                           end: Date?,
                           calendar: Calendar = .current) -> Date? {
        let cal = calendar
        let target = cal.startOfDay(for: today)
        var cur = cal.startOfDay(for: start)

        if cur >= target {
            if let end = end, cur > cal.startOfDay(for: end) { return nil }
            return cur
        }

        func step(_ d: Date) -> Date {
            switch interval {
            case .days(let n):   return cal.date(byAdding: .day, value: n, to: d) ?? d
            case .months(let n): return cal.date(byAdding: .month, value: n, to: d) ?? d
            }
        }
        
        

        // 빠른 근사 점프
        switch interval {
        case .days(let n):
            let diff = cal.dateComponents([.day], from: cur, to: target).day ?? 0
            if n > 0 { cur = cal.date(byAdding: .day, value: (diff / n) * n, to: cur) ?? cur }
        case .months(let n):
            let diff = cal.dateComponents([.month], from: cur, to: target).month ?? 0
            if n > 0 { cur = cal.date(byAdding: .month, value: (diff / n) * n, to: cur) ?? cur }
        }

        while cur < target {
            let nxt = step(cur)
            if nxt == cur { break }
            cur = nxt
            if let end = end, cur > cal.startOfDay(for: end) { return nil }
        }
        if let end = end, cur > cal.startOfDay(for: end) { return nil }
        return cur
    }
    

    /// 날짜 시퀀스에서 간격 유추 (우선 months, 아니면 days)
    static func inferInterval(from sortedDates: [Date],
                              calendar: Calendar = .current) throws -> Interval {
        guard sortedDates.count >= 2 else { throw BindoFormError.notEnoughPointsForInference }
        let cal = calendar
        let comps = zip(sortedDates, sortedDates.dropFirst()).map {
            cal.dateComponents([.month, .day], from: $0, to: $1)
        }
        if let m = comps.first?.month, m > 0, comps.allSatisfy({ $0.month == m && ($0.day ?? 0) == 0 }) {
            return .months(m)
        }
        if let d = comps.first?.day, d > 0, comps.allSatisfy({ $0.day == d }) {
            return .days(d)
        }
        throw BindoFormError.inferredIntervalUnsupported
    }
    
    /// ref(보통 today) 이하에서의 마지막 결제일 (interval 모드)
    static func previousPayDay(beforeOrOn ref: Date,
                               start: Date,
                               interval: Interval,
                               end: Date?,
                               calendar: Calendar = .current) -> Date? {
        let cal = calendar
        let target = cal.startOfDay(for: ref)
        var cur = cal.startOfDay(for: start)

        // 시작이 ref보다 미래면 과거 결제일이 없음
        if cur > target { return nil }

        // 빠른 근사 점프
        switch interval {
        case .days(let n):
            let diff = cal.dateComponents([.day], from: cur, to: target).day ?? 0
            if n > 0 { cur = cal.date(byAdding: .day, value: (diff / n) * n, to: cur) ?? cur }
        case .months(let n):
            let diff = cal.dateComponents([.month], from: cur, to: target).month ?? 0
            if n > 0 { cur = cal.date(byAdding: .month, value: (diff / n) * n, to: cur) ?? cur }
        }

        // end 제한: end가 있고 cur가 end를 넘으면 end 이전으로 한 스텝씩 뒤로
        if let end = end, cal.startOfDay(for: cur) > cal.startOfDay(for: end) {
            // 한 스텝 뒤로
            switch interval {
            case .days(let n):   cur = cal.date(byAdding: .day, value: -n, to: cur) ?? cur
            case .months(let n): cur = cal.date(byAdding: .month, value: -n, to: cur) ?? cur
            }
            if cur < cal.startOfDay(for: start) { return nil }
        }

        return cur
    }
    
    static func lastPayDay(onOrBefore ref: Date,
                           start: Date,
                           interval: Interval,
                           end: Date?) -> Date? {
        let cal = Calendar.current
        let s = cal.startOfDay(for: start)
        let r = cal.startOfDay(for: ref)
        let limit = end.map { min(cal.startOfDay(for: $0), r) } ?? r
        guard s <= limit else { return nil }

        switch interval {
        case .days(let d):
            guard d > 0 else { return nil }
            let days = cal.dateComponents([.day], from: s, to: limit).day ?? 0
            let k = max(0, days / d)
            return cal.date(byAdding: .day, value: k * d, to: s)

        case .months(let m):
            guard m > 0 else { return nil }
            let comps = cal.dateComponents([.month, .day], from: s, to: limit)
            let months = max(0, comps.month ?? 0)
            var k = months / m
            // 후보
            var candidate = cal.date(byAdding: .month, value: k * m, to: s) ?? s
            // 혹시 일자 보정으로 limit를 넘으면 한 주기 빼기
            if candidate > limit, k > 0 {
                k -= 1
                candidate = cal.date(byAdding: .month, value: k * m, to: s) ?? s
            }
            return candidate
        }
    }
    
}
