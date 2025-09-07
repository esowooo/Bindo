//
//  BindoList.swift
//  Bindo
//
//  Created by Sean Choi on 9/11/25.
//

import Foundation
import CoreData   // ⚠️ NSManagedObjectContext 사용하므로 필요

// MARK: - BindoList
struct BindoList: Identifiable, Hashable {
    var id: UUID
    var name: String
    var amount: Decimal
    var startDate: Date
    var endDate: Date?
    var interval: Interval
    var option: String
    var createdAt: Date
    var updatedAt: Date
    var occurrences: [OccurrenceList]
}

extension BindoList {
    init(_ e: Bindo) {
        self.id = e.id ?? UUID()
        self.name = e.name ?? ""
        self.amount = (e.amount as Decimal?) ?? 0
        self.startDate = e.startDate ?? Date()
        self.endDate = e.endDate
        if e.intervalDays > 0 { self.interval = .days(Int(e.intervalDays)) }
        else { self.interval = .months(Int(e.intervalMonths)) }
        self.option = e.option ?? "interval"
        self.createdAt = e.createdAt ?? Date()
        self.updatedAt = e.updatedAt ?? Date()
        let occs = (e.occurrences as? Set<Occurence> ?? [])
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
            .map { o in
                OccurrenceList(
                    id: o.id ?? UUID(),
                    date: o.date ?? Date(),
                    amount: o.amount as Decimal?,
                    isLocked: o.isLocked
                )
            }
        self.occurrences = occs
    }
}

extension Bindo {
    func apply(from m: BindoList, in ctx: NSManagedObjectContext) {
        id = m.id
        name = m.name
        amount = m.amount as NSDecimalNumber
        startDate = m.startDate
        endDate = m.endDate
        option = m.option
        createdAt = m.createdAt
        updatedAt = m.updatedAt
        switch m.interval {
        case .days(let d):   intervalDays = Int16(d); intervalMonths = 0
        case .months(let m): intervalMonths = Int16(m); intervalDays = 0
        }

        // 간단 전략: 전체 교체(초기 구현에 안전)
        if let set = occurrences as? Set<Occurence> {
            set.forEach { ctx.delete($0) }
        }
        let newSet: [Occurence] = m.occurrences.map { o in
            let eo = Occurence(context: ctx)
            eo.id = o.id
            eo.date = o.date
            eo.amount = o.amount as NSDecimalNumber?
            eo.isLocked = o.isLocked
            eo.bindo = self
            return eo
        }
        occurrences = NSSet(array: newSet)
    }
}

extension BindoList {
    func intervalComponents() -> (days: Int16, months: Int16) {
        (interval.daysValue, interval.monthsValue)
    }
}

// MARK: - Occurrence List
struct OccurrenceList: Identifiable, Hashable {
    var id: UUID
    var date: Date
    var amount: Decimal?
    var isLocked: Bool

    init(id: UUID = .init(),
         date: Date,
         amount: Decimal? = nil,
         isLocked: Bool = false) {         // ✅ 기본값 추가(접근 최소화 유지)
        self.id = id
        self.date = date
        self.amount = amount
        self.isLocked = isLocked
    }
}

// MARK: - Interval Helpers
enum Interval: Hashable {
    case days(Int)
    case months(Int)

    var daysValue: Int16 {
        if case .days(let d) = self { return Int16(d) }
        return 0
    }

    var monthsValue: Int16 {
        if case .months(let m) = self { return Int16(m) }
        return 0
    }
}

extension Interval {
    static func from(days: Int16, months: Int16) -> Interval? {
        if days > 0 { return .days(Int(days)) }
        if months > 0 { return .months(Int(months)) }
        return nil
    }

    var dateComponents: DateComponents {
        switch self {
        case .days(let d):   return DateComponents(day: d)
        case .months(let m): return DateComponents(month: m)
        }
    }

    static func validate(days: Int16, months: Int16) -> Bool {
        (days > 0) != (months > 0) // 둘 중 하나만 > 0
    }
}
