//
//  BindoCalculator.swift
//  Bindo
//
//  Updated for: Optional interval model + Occurence-as-history
//

import Foundation

// MARK: - Errors

enum BindoFormError: Error, LocalizedError {
    case missingField(String)
    case invalidInterval
    case invalidIntervalEqual
    case invalidIntervalReversed
    case notEnoughPointsForInference
    case inferredIntervalUnsupported
    case incorrectInterval

    var errorDescription: String? {
        switch self {
        case .missingField(let f):
            // "Please input %@"
            let fmt = NSLocalizedString("bindoFormError.missingField",
                                        comment: "BindoCalculator.swift: Please input %@")
            return String(format: fmt, f)

        case .notEnoughPointsForInference:
            return NSLocalizedString("bindoFormError.notEnoughPointsForInference",
                                     comment: "BindoCalculator.swift: Need two dates minimum in order to calculate interval.")

        case .inferredIntervalUnsupported:
            return NSLocalizedString("bindoFormError.inferredIntervalUnsupported",
                                     comment: "BindoCalculator.swift: Couldn't identify either day or month interval.")

        case .invalidInterval:
            return NSLocalizedString("bindoFormError.invalidInterval",
                                     comment: "BindoCalculator.swift: Please enter a valid interval")

        case .invalidIntervalEqual:
            return NSLocalizedString("bindoFormError.invalidIntervalEqual",
                                     comment: "BindoCalculator.swift: Start date and end/next date cannot be the same.")

        case .invalidIntervalReversed:
            return NSLocalizedString("bindoFormError.invalidIntervalReversed",
                                     comment: "BindoCalculator.swift: Start date must be before the end/next date.")

        case .incorrectInterval:
            return NSLocalizedString("bindoFormError.incorrectInterval",
                                     comment: "BindoCalculator.swift: End Date/Interval setup is incorrect.")
        }
    }
}

// MARK: - Common validations used by forms

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

// MARK: - Calculator

enum BindoCalculator {

    // MARK: Public: next/last

    /// today 이상 첫 결제일
    static func nextPayDay(for bindo: Bindo,
                           repo: BindoRepository,
                           calendar cal: Calendar = .current) -> Date? {
        if let interval = intervalOf(bindo, calendar: cal) {
            let start = seedStart(for: bindo, repo: repo, calendar: cal)
            return nextPayDay(afterOrOn: Date(),
                              start: start,
                              interval: interval,
                              end: bindo.endAt,
                              calendar: cal)
        } else {
            return try? (repo as? CoreDataBindoRepository)?
                .nextOccurrence(for: bindo, calendar: cal)?
                .endDate
        }
    }

    /// today 이하 마지막 결제일
    static func lastPayDay(for bindo: Bindo,
                           repo: BindoRepository,
                           calendar cal: Calendar = .current) -> Date? {
        if let interval = intervalOf(bindo, calendar: cal) {
            let start = seedStart(for: bindo, repo: repo, calendar: cal)
            return lastPayDay(onOrBefore: Date(),
                              start: start,
                              interval: interval,
                              end: bindo.endAt,
                              calendar: cal)
        } else {
            return try? (repo as? CoreDataBindoRepository)?
                .lastOccurrence(for: bindo, calendar: cal)?
                .endDate
        }
    }

    // MARK: Public: interval inference
    /// 날짜 시퀀스에서 간격 유추 (우선 months, 아니면 days)
    static func inferInterval(from dates: [Date], calendar cal: Calendar = .current) throws -> Interval {
        let sorted = dates.sorted()
        guard sorted.count >= 2 else { throw BindoFormError.notEnoughPointsForInference }

        let first = sorted[0], second = sorted[1]
        let dc = cal.dateComponents([.month, .day], from: first, to: second)
        if let m = dc.month, m > 0 {
            // 월 단위 가설 검증: 모든 i에 대해 cal.date(byAdding: .month, value: m, to: sorted[i]) == sorted[i+1]
            let monthlyOK = zip(sorted, sorted.dropFirst()).allSatisfy { a, b in
                guard let step = cal.date(byAdding: .month, value: m, to: cal.startOfDay(for: a)) else { return false }
                return cal.isDate(step, inSameDayAs: b)
            }
            if monthlyOK { return .months(m) }
        }
        if let d = dc.day, d > 0 {
            let dailyOK = zip(sorted, sorted.dropFirst()).allSatisfy { a, b in
                guard let step = cal.date(byAdding: .day, value: d, to: cal.startOfDay(for: a)) else { return false }
                return cal.isDate(step, inSameDayAs: b)
            }
            if dailyOK { return .days(d) }
        }
        throw BindoFormError.inferredIntervalUnsupported
    }

    // MARK: Public: range queries (rule-based)

    /// 특정 "월" 안의 payDay들 (interval 기반)
    static func occurrences(inMonthOf anchor: Date,
                            start: Date,
                            interval: Interval,
                            end: Date?,
                            calendar: Calendar = .current) -> [Date] {
        let cal = calendar
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: anchor)),
              let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }
        // [monthStart, monthEnd) 범위에서 전개
        let dates = occurrences(in: monthStart..<monthEnd,
                                start: start, interval: interval, end: end, calendar: cal)
        return dates
    }

    /// 가시 범위 내 payDay들 (interval 기반)
    static func occurrences(in range: Range<Date>,
                            start: Date,
                            interval: Interval,
                            end: Date?,
                            calendar: Calendar = .current) -> [Date] {
        let cal = calendar
        let until = min(range.upperBound, end ?? range.upperBound)
        let all = rollForwardDates(start: start, interval: interval, endAt: end, until: until, calendar: cal)
        let lower = cal.startOfDay(for: range.lowerBound)
        return all.filter { $0 >= lower && $0 < until }
    }

    /// 마지막 발생일에서 N개 앞으로 미리보기
    static func projectForward(from last: Date,
                               interval: Interval,
                               count: Int,
                               calendar: Calendar = .current) -> [Date] {
        guard count > 0, let step = makeStep(interval, calendar: calendar) else { return [] }
        var cur = calendar.startOfDay(for: last)
        var out: [Date] = []
        for _ in 0..<count {
            let n = step(cur)
            if n == cur { break }
            out.append(n)
            cur = n
        }
        return out
    }

    // MARK: Public: View Occurrence 생성 (금액 포함)

    /// interval 기반 on-the-fly 생성 (뷰 표시용)
    static func makeViewOccurrences(start: Date,
                                    interval: Interval,
                                    endAt: Date?,
                                    baseAmount: Decimal?,
                                    useBase: Bool,
                                    in range: ClosedRange<Date>,
                                    calendar: Calendar = .current) -> [OccurrenceList] {
        let cal = calendar
        let dates = occurrences(in: range.lowerBound..<range.upperBound,
                                start: start, interval: interval, end: endAt, calendar: cal)
        let base = (useBase ? baseAmount : nil)
        return dates.map { d in
            let prev = lastPayDay(onOrBefore: d, start: start, interval: interval, end: endAt, calendar: cal) ?? start
            return OccurrenceList(id: UUID(), startDate: prev, endDate: d, payAmount: base ?? 0)
        }
    }

    /// interval이 **없는** Bindo: 저장된 Occurence를 그대로 뷰 모델로 변환
    static func makeViewOccurrencesFromStored(
        bindo: Bindo,
        repo: BindoRepository,
        in range: ClosedRange<Date>,
        calendar: Calendar = .current
    ) -> [OccurrenceList] {
        guard let core = repo as? CoreDataBindoRepository else { return [] }
        let lower = calendar.startOfDay(for: range.lowerBound)
        let upper = calendar.startOfDay(for: range.upperBound)

        let stored: [Occurence] = (try? core.storedOccurrences(for: bindo, from: lower, to: upper)) ?? []

        return stored.compactMap { o -> OccurrenceList? in
            guard let s = o.startDate, let e = o.endDate else { return nil }
            let pay: Decimal = o.payAmount?.decimalValue
                            ?? bindo.baseAmount?.decimalValue
                            ?? 0
            return OccurrenceList(
                id: o.id ?? UUID(),
                startDate: s,
                endDate: e,
                payAmount: pay
            )
        }
    }

    // MARK: - Internals

    /// Interval 복원: intervalDays / intervalMonths (NSNumber?) → Interval?
    private static func intervalOf(_ b: Bindo, calendar: Calendar) -> Interval? {
        let d = (b.value(forKey: "intervalDays") as? NSNumber)?.intValue ?? 0
        let m = (b.value(forKey: "intervalMonths") as? NSNumber)?.intValue ?? 0
        if d > 0 && m == 0 { return .days(d) }
        if m > 0 && d == 0 { return .months(m) }
        return nil
    }

    /// rule 기반 계산 시 시드: 마지막 Occurence.startDate → createdAt → today
    private static func seedStart(for bindo: Bindo,
                                  repo: BindoRepository,
                                  calendar cal: Calendar) -> Date {
        if let core = repo as? CoreDataBindoRepository,
           let last = try? core.lastOccurrence(for: bindo, calendar: cal),
           let s = last.startDate {
            return s
        }
        return bindo.createdAt ?? Date()
    }

    /// ref 이상 첫 payDay (규칙 기반)
    static func nextPayDay(afterOrOn ref: Date,
                           start: Date,
                           interval: Interval,
                           end: Date?,
                           calendar: Calendar = .current) -> Date? {
        guard let step = makeStep(interval, calendar: calendar) else { return nil }
        let cal = calendar   // 🔧 오타 수정
        let refDay = cal.startOfDay(for: ref)
        let endDay = end.map { cal.startOfDay(for: $0) }
        var cur = cal.startOfDay(for: start)

        var hops = 0
        while true {
            let next = step(cur)
            if next == cur { return nil }              // 안전장치
            if let e = endDay, next > e { return nil } // endAt 포함: next == e 허용
            if next >= refDay { return next }          // ref 이상 첫 결제일
            cur = next
            hops += 1
            if hops >= 100_000 { return nil }          // 안전장치
        }
    }

    /// ref 이하 마지막 payDay (규칙 기반)
    private static func lastPayDay(onOrBefore ref: Date,
                                   start: Date,
                                   interval: Interval,
                                   end: Date?,
                                   calendar: Calendar) -> Date? {
        let cal = calendar
        let ref = cal.startOfDay(for: ref)
        let until = end ?? ref
        let items = rollForwardDates(start: start, interval: interval, endAt: end,
                                     until: until, calendar: cal, maxHops: 100_000)
        return items.last(where: { $0 <= ref })
    }

    @inline(__always)
    private static func makeStep(_ interval: Interval,
                                 calendar: Calendar) -> ((Date) -> Date)? {
        switch interval {
        case .days(let n):
            guard n > 0 else { return nil }
            return { date in
                let added = calendar.date(byAdding: .day, value: n, to: date)
                return added.map { calendar.startOfDay(for: $0) } ?? date
            }
        case .months(let n):
            guard n > 0 else { return nil }
            return { date in
                let added = calendar.date(byAdding: .month, value: n, to: date)
                return added.map { calendar.startOfDay(for: $0) } ?? date
            }
        }
    }

    /// start ~ limit까지 interval 규칙으로 전개 (endAt 고려; 결과는 **endDate들**)
    private static func rollForwardDates(start: Date,
                                         interval: Interval,
                                         endAt: Date?,
                                         until limit: Date,
                                         calendar: Calendar,
                                         maxHops: Int = 10_000) -> [Date] {
        guard let step = makeStep(interval, calendar: calendar) else { return [] }

        var dates: [Date] = []

        let start = calendar.startOfDay(for: start)
        let lim   = calendar.startOfDay(for: limit)
        let hardEnd = endAt.map { calendar.startOfDay(for: $0) }

        guard start <= lim else { return [] }
        if let e = hardEnd, start > e { return [] }

        var cur = start
        var hops = 0

        while cur <= lim {
            let next = step(cur)
            if next == cur { break }                 // 안전장치
            if let e = hardEnd, next > e { break }   // endAt 초과 시 종료
            dates.append(next)                       // next가 이번 주기의 payDay(endDate)
            cur = next
            hops += 1
            if hops >= maxHops { break }
        }
        return dates
    }
}
