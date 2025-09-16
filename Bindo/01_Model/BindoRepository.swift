//
//  BindoRepository.swift
//  Bindo
//
//  Created by Sean Choi on 9/11/25.
//

import CoreData

// MARK: - 정렬 옵션
enum BindoSort {
    case createdDesc, createdAsc, nameAsc, amountDesc
}

// MARK: - CRUD API
protocol BindoRepository: AnyObject {
    func upsert(_ model: BindoList) throws
    func delete(id: UUID) throws
    func fetchAll(sortedBy sort: BindoSort) throws -> [BindoList]
    func fetch(id: UUID) throws -> BindoList?
}

//MARK: - MainVC
protocol RefreshRepository: AnyObject {
    @discardableResult
    func ensureCurrentCycle(for bindo: Bindo,
                            calendar cal: Calendar,
                            maxHops: Int) throws -> Occurence?

    func ensureAllCurrentCycles(calendar cal: Calendar) throws
}

extension RefreshRepository {
    @discardableResult
    func ensureCurrentCycle(for bindo: Bindo,
                            calendar cal: Calendar = .current,
                            maxHops: Int = 240) throws -> Occurence? {
        try ensureCurrentCycle(for: bindo, calendar: cal, maxHops: maxHops)
    }

    func ensureAllCurrentCycles() throws {
        try ensureAllCurrentCycles(calendar: .current)
    }
}

// MARK: - CalendarVC용
protocol CalendarEventsRepository: AnyObject {
    func fetchCalendarEvents(in interval: DateInterval,
                             calendar: Calendar) throws -> [CalendarEvent]
    func fetchCalendarEvents(forMonthContaining date: Date,
                             calendar: Calendar) throws -> [CalendarEvent]
}

// MARK: - StatsVC용
protocol StatsRepository: AnyObject {
    func fetchStats(in range: DateInterval,
                    granularity: StatsGranularity,
                    calendar: Calendar) throws -> [StatsBucket]
}

// MARK: - CoreData 구현
final class CoreDataBindoRepository: BindoRepository {

    private let ctx: NSManagedObjectContext
    init(context: NSManagedObjectContext = Persistence.shared.viewContext) {
        self.ctx = context
    }

    // MARK: CRUD
    func upsert(_ model: BindoList) throws {
        let req = Bindo.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", model.id as CVarArg)
        req.fetchLimit = 1

        let obj = try ctx.fetch(req).first ?? Bindo(context: ctx)
        var m = model
        m.updatedAt = Date()
        obj.apply(from: m, in: ctx)
        try ctx.save()
    }

    func delete(id: UUID) throws {
        let req = Bindo.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let e = try ctx.fetch(req).first {
            ctx.delete(e)
            try ctx.save()
        }
    }

    func fetchAll(sortedBy sort: BindoSort) throws -> [BindoList] {
        let req = Bindo.fetchRequest()
        switch sort {
        case .createdDesc:
            req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        case .createdAsc:
            req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        case .nameAsc:
            req.sortDescriptors = [NSSortDescriptor(key: "name",
                                                    ascending: true,
                                                    selector: #selector(NSString.localizedCaseInsensitiveCompare))]
        case .amountDesc:
            // baseAmount(optional) 정렬 주의: nil은 뒤로 밀릴 수 있음
            req.sortDescriptors = [NSSortDescriptor(key: "baseAmount", ascending: false)]
        }
        return try ctx.fetch(req).map(BindoList.init(_:))
    }

    func fetch(id: UUID) throws -> BindoList? {
        let req = Bindo.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try ctx.fetch(req).first.map(BindoList.init(_:))
    }
}

// MARK: - Rolling: 오늘 기준 “현재/다음 주기” 보장
extension CoreDataBindoRepository: RefreshRepository {

    /// - Returns: endDate가 `today` 이상인 Occurence (없으면 생성 or nil)
    @discardableResult
    func ensureCurrentCycle(for bindo: Bindo,
                            calendar cal: Calendar = .current,
                            maxHops: Int = 240) throws -> Occurence? {

        // interval이 없으면(DateView 전용) 생성/롤링 안 함
        guard let step = intervalStepper(of: bindo, calendar: cal) else {
            return try nextOccurrence(for: bindo, calendar: cal)
        }

        let today = cal.startOfDay(for: Date())
        let endAt = (bindo.value(forKey: "endAt") as? Date).map { cal.startOfDay(for: $0) }

        // 이미 next 존재하면 그대로 반환
        if let next = try nextOccurrence(for: bindo, calendar: cal) {
            return next
        }

        // 시드: 마지막 과거 Occurrence.endDate 또는 createdAt
        let lastPast = try lastOccurrence(for: bindo, calendar: cal)?.endDate
        let seed = cal.startOfDay(for: (lastPast ?? (bindo.createdAt ?? today)))

        // endAt 넘으면 중단
        func isPastEnd(_ d: Date) -> Bool {
            if let e = endAt { return d > e }
            return false
        }

        var currentStart = seed
        var createdAny = false
        var hops = 0

        while hops < maxHops {
            let nextEnd = step(currentStart)          
            guard nextEnd > currentStart else { break }

            if isPastEnd(nextEnd) { break }

            if nextEnd >= today {
                // 오늘 이상 → 없으면 생성
                if try fetchOccurrence(byEndDate: nextEnd, for: bindo, calendar: cal) == nil {
                    _ = try createOccurrence(for: bindo, start: currentStart, end: nextEnd)
                    createdAny = true
                }
                break
            } else {
                // 과거 누락분 보정 생성(중복 방지)
                if try fetchOccurrence(byEndDate: nextEnd, for: bindo, calendar: cal) == nil {
                    _ = try createOccurrence(for: bindo, start: currentStart, end: nextEnd)
                    createdAny = true
                }
                currentStart = nextEnd
                hops += 1
            }
        }

        if createdAny { try ctx.save() }
        return try nextOccurrence(for: bindo, calendar: cal)
    }

    /// 리스트 화면 진입 시 전체 bindo에 대해 보정(필요 시 1회 호출)
    func ensureAllCurrentCycles(calendar cal: Calendar = .current) throws {
        let req: NSFetchRequest<Bindo> = Bindo.fetchRequest()
        let all = try ctx.fetch(req)
        var touched = false
        for b in all {
            if intervalStepper(of: b, calendar: cal) != nil {
                let before = ctx.insertedObjects.count + ctx.updatedObjects.count
                _ = try ensureCurrentCycle(for: b, calendar: cal)
                let after = ctx.insertedObjects.count + ctx.updatedObjects.count
                if after > before { touched = true }
            }
        }
        if touched { try ctx.save() }
    }

    // MARK: Helpers

    /// intervalDays/months(NSNumber?) → stepper
    private func intervalStepper(of bindo: Bindo,
                                 calendar cal: Calendar) -> ((Date) -> Date)? {
        let daysNum   = bindo.value(forKey: "intervalDays") as? NSNumber
        let monthsNum = bindo.value(forKey: "intervalMonths") as? NSNumber
        let d = daysNum?.intValue ?? 0
        let m = monthsNum?.intValue ?? 0

        if d > 0 && m == 0 {
            return { cal.date(byAdding: .day, value: d, to: $0).map { cal.startOfDay(for: $0) } ?? $0 }
        }
        if m > 0 && d == 0 {
            return { cal.date(byAdding: .month, value: m, to: $0).map { cal.startOfDay(for: $0) } ?? $0 }
        }
        return nil
    }

    /// endDate가 정확히 같은 Occurence를 조회(중복 생성 방지)
    private func fetchOccurrence(byEndDate end: Date,
                                 for bindo: Bindo,
                                 calendar cal: Calendar) throws -> Occurence? {
        let day = cal.startOfDay(for: end)
        let r: NSFetchRequest<Occurence> = Occurence.fetchRequest()
        r.predicate = NSPredicate(format: "bindo == %@ AND endDate == %@", bindo, day as NSDate)
        r.fetchLimit = 1
        return try ctx.fetch(r).first
    }

    /// 새 Occurence 생성 (payAmount 정책: useBase면 baseAmount 사용)
    @discardableResult
    private func createOccurrence(for bindo: Bindo,
                                  start: Date,
                                  end: Date) throws -> Occurence {
        let o = Occurence(context: ctx)
        o.id        = UUID()
        o.bindo     = bindo
        o.startDate = start
        o.endDate   = end
        if bindo.useBase, let base = bindo.baseAmount {
            o.payAmount = base
        } else {
            // 필요 시 정책 변경 가능(직전 금액 복사 등)
            if o.payAmount == nil { o.payAmount = .zero }
        }
        return o
    }
}

// MARK: - Next / Last helpers (단일 bindo)
extension CoreDataBindoRepository {

    /// 다음 결제(오늘 이상, endDate 오름차순)
    func nextOccurrence(for bindo: Bindo, calendar cal: Calendar = .current) throws -> Occurence? {
        let r: NSFetchRequest<Occurence> = Occurence.fetchRequest()
        r.predicate = NSPredicate(format: "bindo == %@ AND endDate >= %@", bindo, cal.startOfDay(for: Date()) as NSDate)
        r.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: true)]
        r.fetchLimit = 1
        return try ctx.fetch(r).first
    }

    /// 마지막 결제(오늘 이하, endDate 내림차순)
    func lastOccurrence(for bindo: Bindo, calendar cal: Calendar = .current) throws -> Occurence? {
        let r: NSFetchRequest<Occurence> = Occurence.fetchRequest()
        r.predicate = NSPredicate(format: "bindo == %@ AND endDate <= %@", bindo, cal.startOfDay(for: Date()) as NSDate)
        r.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: false)]
        r.fetchLimit = 1
        return try ctx.fetch(r).first
    }
    func storedOccurrences(for bindo: Bindo, from: Date, to: Date) throws -> [Occurence] {
        let req: NSFetchRequest<Occurence> = Occurence.fetchRequest()
        req.predicate = NSPredicate(format: "bindo == %@ AND endDate >= %@ AND endDate <= %@",
                                    bindo, from as NSDate, to as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: true)]
        return try ctx.fetch(req)
    }

    /// 표시용 번들(next/last/endAt)
    func effectivePay(for e: Bindo,
                      calendar: Calendar = .current) throws -> (next: Date?, last: Date?, end: Date?) {
        let next = try nextOccurrence(for: e, calendar: calendar)?.endDate
        let last = try lastOccurrence(for: e, calendar: calendar)?.endDate
        let end  = e.value(forKey: "endAt") as? Date
        return (next, last, end)
    }
}

// MARK: - CalendarVC
extension CoreDataBindoRepository: CalendarEventsRepository {

    func fetchCalendarEvents(forMonthContaining date: Date,
                             calendar cal: Calendar = .current) throws -> [CalendarEvent] {
        let comps = cal.dateComponents([.year, .month], from: date)
        let monthStart = cal.date(from: comps)!
        let nextMonth  = cal.date(byAdding: .month, value: 1, to: monthStart)!
        let interval = DateInterval(start: monthStart, end: nextMonth)
        return try fetchCalendarEvents(in: interval, calendar: cal)
    }

    func fetchCalendarEvents(in interval: DateInterval,
                             calendar cal: Calendar = .current) throws -> [CalendarEvent] {

        let start = cal.startOfDay(for: interval.start)
        let end   = cal.startOfDay(for: interval.end) // exclusive

        // 1) 저장된 Occurence → 이벤트
        let occReq: NSFetchRequest<Occurence> = Occurence.fetchRequest()
        occReq.predicate = NSPredicate(format: "endDate >= %@ AND endDate < %@", start as NSDate, end as NSDate)
        occReq.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: true)]

        let occs = try ctx.fetch(occReq)
        var events: [CalendarEvent] = occs.compactMap { occ in
            guard let d = occ.endDate, let name = occ.bindo?.name else { return nil }
            return CalendarEvent(date: cal.startOfDay(for: d), title: name)
        }

        // 저장된 것의 (날짜,이름) 키셋 — 규칙 전개와 중복 방지
        var usedKeys = Set<String>()
        usedKeys.reserveCapacity(events.count)
        for e in events {
            let key = calendarKey(e.date, e.title, calendar: cal)
            usedKeys.insert(key)
        }

        // 2) 모든 Bindo 중 interval 있는 것 → 규칙 전개 (저장 X)
        let bReq: NSFetchRequest<Bindo> = Bindo.fetchRequest()
        let bindos = try ctx.fetch(bReq)

        for b in bindos {
            guard let iv = intervalFrom(b) else { continue } // DateView는 건너뜀

            // 시드: 마지막 Occurence.startDate → createdAt → interval.start
            let lastStart = try? lastOccurrence(for: b, calendar: cal)?.startDate
            let seed = lastStart ?? b.createdAt ?? start

            // 규칙 전개 (start..<end)
            let dates = BindoCalculator.occurrences(in: start..<end,
                                                    start: seed,
                                                    interval: iv,
                                                    end: b.endAt,
                                                    calendar: cal)
            let name = b.name ?? "–"

            for d in dates {
                let day = cal.startOfDay(for: d)
                let key = calendarKey(day, name, calendar: cal)
                if !usedKeys.contains(key) {
                    usedKeys.insert(key)
                    events.append(CalendarEvent(date: day, title: name))
                }
            }
        }

        // 3) 정렬 후 반환
        events.sort { $0.date < $1.date }
        return events
    }

    // MARK: - Helpers (internal)
    private func intervalFrom(_ b: Bindo) -> Interval? {
        let d = (b.value(forKey: "intervalDays") as? NSNumber)?.intValue ?? 0
        let m = (b.value(forKey: "intervalMonths") as? NSNumber)?.intValue ?? 0
        if d > 0, m == 0 { return .days(d) }
        if m > 0, d == 0 { return .months(m) }
        return nil
    }
    private func calendarKey(_ date: Date, _ title: String, calendar cal: Calendar) -> String {
        let day = cal.startOfDay(for: date).timeIntervalSince1970
        return "\(title)#\(day)"
    }
}

// MARK: - StatsVC
extension CoreDataBindoRepository: StatsRepository {

    func fetchStats(in range: DateInterval,
                    granularity: StatsGranularity,
                    calendar cal: Calendar = .current) throws -> [StatsBucket] {

        let startDay = cal.startOfDay(for: range.start)
        let endDay   = cal.startOfDay(for: range.end) // [start, end)

        // 1) 저장된 Occurence 조회(endDate 기준)
        let req: NSFetchRequest<Occurence> = Occurence.fetchRequest()
        req.predicate = NSPredicate(format: "endDate >= %@ AND endDate < %@", startDay as NSDate, endDay as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: true)]
        let stored = try ctx.fetch(req)

        // 2) 버킷 합계(저장분) + 중복 방지 셋( bindoID#endDate )
        var totals: [Date: Double] = [:]
        totals.reserveCapacity(64)

        func bucketKey(for date: Date) -> Date {
            switch granularity {
            case .month:
                // 하루 단위 버킷 (차트 step=1day와 일치)
                return cal.startOfDay(for: date)
            case .year:
                // 월 단위 버킷 (해당 월 1일)
                let c = cal.dateComponents([.year, .month], from: date)
                return cal.date(from: c)!
            }
        }

        var existing: Set<String> = []
        existing.reserveCapacity(stored.count)

        for o in stored {
            guard let end = o.endDate, let b = o.bindo else { continue }
            let key = bucketKey(for: end)
            let amount = o.payAmount?.doubleValue ?? b.baseAmount?.doubleValue ?? 0.0
            totals[key, default: 0.0] += amount

            if let bid = b.id, let endKey = endKeyString(bid: bid, end: end, cal: cal) {
                existing.insert(endKey)
            }
        }

        // 3) Interval 있는 Bindo는 규칙 전개(미래 on-the-fly), 저장 X
        let bReq: NSFetchRequest<Bindo> = Bindo.fetchRequest()
        let bindos = try ctx.fetch(bReq)

        for b in bindos {
            guard let iv = intervalFrom(b) else { continue }          // DateView는 pass
            // 시드: 마지막 Occurence.startDate → createdAt → startDay
            let seed = (try? lastOccurrence(for: b, calendar: cal)?.startDate)
                       ?? b.createdAt
                       ?? startDay

            // [startDay, endDay) 범위에서 payDay 전개 (endAt 포함 규칙은 Calculator가 처리)
            let projected = BindoCalculator.occurrences(in: startDay..<endDay,
                                                        start: seed,
                                                        interval: iv,
                                                        end: b.endAt,
                                                        calendar: cal)

            let amountPer = b.useBase ? (b.baseAmount?.doubleValue ?? 0.0) : 0.0

            for d in projected {
                // 저장된 것과 동일 날짜는 중복 금지(저장 우선)
                if let bid = b.id, let ekey = endKeyString(bid: bid, end: d, cal: cal), existing.contains(ekey) {
                    continue
                }
                let key = bucketKey(for: d)
                totals[key, default: 0.0] += amountPer
            }
        }

        // 4) 결과 버킷 정렬 반환
        let buckets: [StatsBucket] = totals
            .map { StatsBucket(periodStart: $0.key, totalAmount: $0.value, count: 0) }
            .sorted { $0.periodStart < $1.periodStart }

        return buckets
    }


    private func endKeyString(bid: UUID, end: Date, cal: Calendar) -> String? {
        let day = cal.startOfDay(for: end).timeIntervalSince1970
        return "\(bid.uuidString)#\(day)"
    }
}
