//
//  BindoRepository.swift
//  Bindo
//
//  Created by Sean Choi on 9/11/25.
//

import CoreData

// 정렬 옵션
enum BindoSort {
    case createdDesc, createdAsc, nameAsc, amountDesc
}

// MARK: - CRUD 전용
protocol BindoRepository: AnyObject {
    func upsert(_ model: BindoList) throws
    func delete(id: UUID) throws
    func fetchAll(sortedBy sort: BindoSort) throws -> [BindoList]
    func fetch(id: UUID) throws -> BindoList?
}

// MARK: - CalendarVC 전용
protocol CalendarEventsRepository: AnyObject {
    func fetchCalendarEvents(in interval: DateInterval,
                             calendar: Calendar) throws -> [CalendarEvent]
    func fetchCalendarEvents(forMonthContaining date: Date,
                             calendar: Calendar) throws -> [CalendarEvent]
}

// MARK: - StatsVC 전용
protocol StatsRepository: AnyObject {
    func fetchStats(in range: DateInterval,
                    granularity: StatsGranularity,
                    calendar: Calendar) throws -> [StatsBucket]
}

// Core Data 구현체
final class CoreDataBindoRepository: BindoRepository {
    private let ctx: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = Persistence.shared.viewContext) {
        self.ctx = context
    }
    
    func upsert(_ model: BindoList) throws {
        let req = Bindo.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", model.id as CVarArg)
        req.fetchLimit = 1
        
        let obj = try ctx.fetch(req).first ?? Bindo(context: ctx)
        
        var m = model
        m.updatedAt = Date()                 // 저장 직전 수정일 갱신
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
        case .createdDesc: req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        case .createdAsc:  req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        case .nameAsc:     req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true,
                                                                   selector: #selector(NSString.localizedCaseInsensitiveCompare))]
        case .amountDesc:  req.sortDescriptors = [NSSortDescriptor(key: "amount", ascending: false)]
        }
        return try ctx.fetch(req).map(BindoList.init(_:))
    }
    
    func fetch(id: UUID) throws -> BindoList? {
        let req = Bindo.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try ctx.fetch(req).first.map(BindoList.init(_:))
    }
    
    
    func upsertInBackground(_ models: [BindoList], completion: ((Error?) -> Void)? = nil) {
        let container = Persistence.shared
        container.performBackgroundTask { ctx in
            ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            do {
                for m in models {
                    let req: NSFetchRequest<Bindo> = Bindo.fetchRequest()
                    req.predicate = NSPredicate(format: "id == %@", m.id as CVarArg)
                    req.fetchLimit = 1
                    let obj = try ctx.fetch(req).first ?? Bindo(context: ctx)
                    obj.apply(from: m, in: ctx)
                }
                try ctx.save()
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
}


extension CoreDataBindoRepository {
    /// 오늘 이상 1개 (다음 결제일)
        func nextOccurrence(for bindo: Bindo,
                            calendar: Calendar = .current) throws -> Occurence? {
            let todayStart = calendar.startOfDay(for: Date())
            let req: NSFetchRequest<Occurence> = Occurence.fetchRequest()
            req.predicate = NSPredicate(format: "bindo == %@ AND date >= %@", bindo, todayStart as NSDate)
            req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            req.fetchLimit = 1
            return try ctx.fetch(req).first
        }

        /// 오늘 이상 최대 2개 (마지막 판단용)
        func nextTwoOccurrences(for bindo: Bindo,
                                calendar: Calendar = .current) throws -> (first: Date?, second: Date?) {
            let todayStart = calendar.startOfDay(for: Date())
            let req: NSFetchRequest<Occurence> = Occurence.fetchRequest()
            req.predicate = NSPredicate(format: "bindo == %@ AND date >= %@", bindo, todayStart as NSDate)
            req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            req.fetchLimit = 2
            let list = try ctx.fetch(req)
            return (list.first?.date, list.count >= 2 ? list[1].date : nil)
        }

        /// 오늘 이하 1개 (마지막 과거 결제일)
        func lastOccurrence(for bindo: Bindo,
                            calendar: Calendar = .current) throws -> Occurence? {
            let todayStart = calendar.startOfDay(for: Date())
            let req: NSFetchRequest<Occurence> = Occurence.fetchRequest()
            req.predicate = NSPredicate(format: "bindo == %@ AND date <= %@", bindo, todayStart as NSDate)
            req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            req.fetchLimit = 1
            return try ctx.fetch(req).first
        }

        /// 표시용 묶음 (next/last/end)
        func effectivePay(for e: Bindo,
                          calendar: Calendar = .current) throws -> (next: Date?, last: Date?, end: Date?) {
            let end = e.endDate
            if (e.option ?? "interval").lowercased() == "date" {
                let next = try nextOccurrence(for: e, calendar: calendar)?.date
                let last = try lastOccurrence(for: e, calendar: calendar)?.date
                return (next, last, end)
            } else {
                // interval 모드: 기존 그대로
                guard let start = e.startDate else { return (nil, nil, end) }
                let interval: Interval = (e.intervalDays > 0) ? .days(Int(e.intervalDays)) : .months(Int(e.intervalMonths))
                let today = calendar.startOfDay(for: Date())
                let next = BindoCalculator.nextPayDay(afterOrOn: today, start: start, interval: interval, end: end, calendar: calendar)
                let last = BindoCalculator.previousPayDay(beforeOrOn: today, start: start, interval: interval, end: end, calendar: calendar)
                return (next, last, end)
            }
        }
}


//MARK: - Calendar VC
extension CoreDataBindoRepository: CalendarEventsRepository {
    // 달력(월) 단위 편의 함수
    func fetchCalendarEvents(forMonthContaining date: Date,
                             calendar cal: Calendar = .current) throws -> [CalendarEvent] {
        // 해당 월의 [첫날 00:00, 다음달 첫날 00:00) 범위로 조회
        let comps = cal.dateComponents([.year, .month], from: date)
        let monthStart = cal.date(from: comps)!                       // yyyy-MM-01 00:00
        let nextMonth  = cal.date(byAdding: .month, value: 1, to: monthStart)!
        let interval = DateInterval(start: monthStart, end: nextMonth)
        return try fetchCalendarEvents(in: interval, calendar: cal)
    }

    // 범위 기반(일반화) 함수
    func fetchCalendarEvents(in interval: DateInterval,
                             calendar cal: Calendar = .current) throws -> [CalendarEvent] {

        let start = cal.startOfDay(for: interval.start)
        let end   = cal.startOfDay(for: interval.end) // end는 'exclusive'로 취급

        var result: [CalendarEvent] = []
        result.reserveCapacity(64)

        // 1) Occurence에 저장된 이벤트를 직접 페치 (가장 빠르고 정확)
        do {
            let req: NSFetchRequest<Occurence> = Occurence.fetchRequest()
            req.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
            req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

            let occs = try ctx.fetch(req)
            for occ in occs {
                guard let b = occ.bindo, let name = b.name, let d = occ.date else { continue }
                result.append(CalendarEvent(date: cal.startOfDay(for: d), title: name))
            }
        }

        // 2) 반복 구독(Interval 기반) 중, 해당 구간과 겹치는 항목을 골라 '계산'으로 생성
        //    - Occurence가 없거나 부분만 있는 경우 보완적 의미
        do {
            let req: NSFetchRequest<Bindo> = Bindo.fetchRequest()
            // 겹침 조건: (b.startDate < end) && (b.endDate == nil || b.endDate >= start)
            // + 반복을 가진 것만 (intervalDays > 0 || intervalMonths > 0)
            req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "startDate < %@", end as NSDate),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "endDate == nil"),
                    NSPredicate(format: "endDate >= %@", start as NSDate)
                ]),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "intervalDays > 0"),
                    NSPredicate(format: "intervalMonths > 0")
                ])
            ])
            let candidates = try ctx.fetch(req)

            for e in candidates {
                guard let name = e.name, let s = e.startDate else { continue }
                let endLimit = e.endDate
                let intervalType: Interval = (e.intervalDays > 0)
                    ? .days(Int(e.intervalDays))
                    : .months(Int(e.intervalMonths))

                // interval 구간 내 반복 발생일 생성
                switch intervalType {
                case .days(let step):
                    result.append(contentsOf: generateRepeats(name: name,
                                                              start: s,
                                                              stepDays: step,
                                                              until: endLimit,
                                                              clipTo: DateInterval(start: start, end: end),
                                                              calendar: cal))
                case .months(let step):
                    result.append(contentsOf: generateRepeatsByMonth(name: name,
                                                                     start: s,
                                                                     stepMonths: step,
                                                                     until: endLimit,
                                                                     clipTo: DateInterval(start: start, end: end),
                                                                     calendar: cal))
                }
            }
        }

        // 중복 제거(혹시 Occurence와 계산이 겹칠 수 있으므로) + 정렬
        let dedup = Set(result) // CalendarEvent: Hashable 이어야 함
        return dedup.sorted { $0.date < $1.date }
    }

    ///반복 생성 헬퍼 generateRepeats, generateRepeatsByMonth
    private func generateRepeats(name: String,
                                 start: Date,
                                 stepDays: Int,
                                 until: Date?,
                                 clipTo: DateInterval,
                                 calendar cal: Calendar) -> [CalendarEvent] {

        guard stepDays > 0 else { return [] }
        var arr: [CalendarEvent] = []

        let s0 = cal.startOfDay(for: start)
        let startClip = cal.startOfDay(for: clipTo.start)
        let endClip   = cal.startOfDay(for: clipTo.end)
        let endLimit  = until.map { cal.startOfDay(for: $0) }

        // clip 시작점으로 점프
        var d = s0
        if d < startClip {
            let daysToStart = CalendarUtils.daysBetween(s0, startClip)
            if daysToStart > 0 {
                let jumps = daysToStart / stepDays
                d = cal.date(byAdding: .day, value: jumps * stepDays, to: s0)!
                while d < startClip { d = cal.date(byAdding: .day, value: stepDays, to: d)! }
            }
        }

        while d < endClip {
            if let limit = endLimit, d > limit { break }
            if clipTo.contains(d) { arr.append(.init(date: d, title: name)) }
            d = cal.date(byAdding: .day, value: stepDays, to: d)!
        }
        return arr
    }

    private func generateRepeatsByMonth(name: String,
                                        start: Date,
                                        stepMonths: Int,
                                        until: Date?,
                                        clipTo: DateInterval,
                                        calendar cal: Calendar) -> [CalendarEvent] {

        guard stepMonths > 0 else { return [] }
        var arr: [CalendarEvent] = []

        let s0 = cal.startOfDay(for: start)
        let startClip = cal.startOfDay(for: clipTo.start)
        let endClip   = cal.startOfDay(for: clipTo.end)
        let endLimit  = until.map { cal.startOfDay(for: $0) }

        // clip 시작점으로 당기기
        var d = s0
        if d < startClip {
            while d < startClip {
                guard let n = cal.date(byAdding: .month, value: stepMonths, to: d) else { break }
                d = cal.startOfDay(for: n)
            }
        }

        while d < endClip {
            if let limit = endLimit, d > limit { break }
            if clipTo.contains(d) { arr.append(.init(date: d, title: name)) }
            guard let n = cal.date(byAdding: .month, value: stepMonths, to: d) else { break }
            d = cal.startOfDay(for: n)
        }
        return arr
    }
}


//MARK: - Stats VC
extension CoreDataBindoRepository: StatsRepository {
    func fetchStats(in range: DateInterval,
                    granularity: StatsGranularity,
                    calendar cal: Calendar = .current) throws -> [StatsBucket] {
        // 1) Occurence 직접 조회
        let req: NSFetchRequest<Occurence> = Occurence.fetchRequest()
        req.predicate = NSPredicate(format: "date >= %@ AND date < %@", range.start as NSDate, range.end as NSDate)
        let occs = try ctx.fetch(req)

        // 2) 그룹핑: 일 단위 or 월 단위
        let grouped: [Date: [Occurence]] = Dictionary(grouping: occs, by: { occ in
            switch granularity {
            case .month: return cal.startOfDay(for: occ.date!)
            case .year:
                let comps = cal.dateComponents([.year, .month], from: occ.date!)
                return cal.date(from: comps)!
            }
        })

        // 3) StatsBucket 변환
        return grouped.map { (date, list) in
            StatsBucket(
                periodStart: date,
                totalAmount: list.reduce(0.0) { sum, occ in
                    sum + (occ.bindo?.amount?.doubleValue ?? 0.0)
                },
                count: list.count
            )
        }
        .sorted { $0.periodStart < $1.periodStart }
    }
}
