//
//  BindoList.swift
//  Bindo
//
//  Created by Sean Choi on 9/11/25.
//

import Foundation
import CoreData

// MARK: - Interval
enum Interval: Hashable {
    case days(Int)
    case months(Int)

    var daysValue: Int16 {
        if case .days(let d) = self {
            return Int16(clamping: d)
        }
        return 0
    }
    var monthsValue: Int16 {
        if case .months(let m) = self {
            return Int16(clamping: m)
        }
        return 0
    }

    /// CoreData(Int16?) -> Interval?
    static func from(days: Int16?, months: Int16?) -> Interval? {
        let d = Int(days ?? 0)
        let m = Int(months ?? 0)
        if d > 0, m == 0 { return .days(d) }
        if m > 0, d == 0 { return .months(m) }
        return nil
    }

    /// CoreData(NSNumber?) -> Interval?
    static func from(days: NSNumber?, months: NSNumber?) -> Interval? {
        let d = days?.intValue ?? 0
        let m = months?.intValue ?? 0
        if d > 0, m == 0 { return .days(d) }
        if m > 0, d == 0 { return .months(m) }
        return nil
    }

    /// 둘 중 하나만 > 0 이면 true (Int16?)
    static func validate(days: Int16?, months: Int16?) -> Bool {
        let hasD = (days ?? 0) > 0
        let hasM = (months ?? 0) > 0
        return hasD != hasM
    }

    /// 둘 중 하나만 > 0 이면 true (NSNumber?)
    static func validate(days: NSNumber?, months: NSNumber?) -> Bool {
        let hasD = (days?.intValue ?? 0) > 0
        let hasM = (months?.intValue ?? 0) > 0
        return hasD != hasM
    }
}

// MARK: - OccurrenceList (Occurence의 DTO)
struct OccurrenceList: Identifiable, Hashable {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var payAmount: Decimal

    init(id: UUID = .init(),
         startDate: Date,
         endDate: Date,
         payAmount: Decimal) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.payAmount = payAmount
    }
}

// MARK: - BindoList (Bindo의 DTO)
struct BindoList: Identifiable, Hashable {
    var id: UUID
    var name: String
    var useBase: Bool
    var baseAmount: Decimal?          // optional
    var createdAt: Date
    var updatedAt: Date
    var endAt: Date?                  // optional (intervalView에서 제한/ dateView는 마지막 Occurence에 대응)
    var option: String                // "interval" | "date" 등
    var interval: Interval?           // intervalDays | intervalMonths를 합성 (없으면 nil)
    var occurrences: [OccurrenceList] // DateView 입력/저장분
}

// MARK: - CoreData <-> DTO 매핑
extension BindoList {
    init(_ e: Bindo) {
        self.id         = e.id ?? UUID()
        self.name       = e.name ?? ""
        self.useBase    = e.useBase
        self.baseAmount = e.baseAmount?.decimalValue
        self.createdAt  = e.createdAt ?? Date()
        self.updatedAt  = e.updatedAt ?? Date()
        self.endAt      = e.endAt
        self.option     = e.option ?? "interval"

        // interval 복원: KVC로 NSNumber?를 얻어서 호환성 있게 처리
        let daysNum   = e.value(forKey: "intervalDays") as? NSNumber
        let monthsNum = e.value(forKey: "intervalMonths") as? NSNumber
        self.interval = Interval.from(days: daysNum, months: monthsNum)

        let occs = (e.occurrences as? Set<Occurence> ?? [])
            .sorted { ($0.endDate ?? .distantPast) < ($1.endDate ?? .distantPast) }
            .compactMap { o -> OccurrenceList? in
                guard let sd = o.startDate, let ed = o.endDate else { return nil }
                let amount = o.payAmount?.decimalValue ?? 0
                return OccurrenceList(id: o.id ?? UUID(),
                                      startDate: sd,
                                      endDate: ed,
                                      payAmount: amount)
            }
        self.occurrences = occs
    }
}

extension Bindo {
    /// DTO -> CoreData
    func apply(from m: BindoList, in ctx: NSManagedObjectContext) {
        id         = m.id
        name       = m.name
        useBase    = m.useBase
        baseAmount = m.baseAmount.map { NSDecimalNumber(decimal: $0) }
        createdAt  = m.createdAt
        updatedAt  = m.updatedAt
        endAt      = m.endAt
        option     = m.option

        // Interval 반영 (required + 0 sentinel 전략)
        if let iv = m.interval {
            switch iv {
            case .days(let d):
                let v = max(0, min(d, Int(Int16.max)))
                setValue(NSNumber(value: v), forKey: "intervalDays")
                setValue(NSNumber(value: 0), forKey: "intervalMonths")
            case .months(let mo):
                let v = max(0, min(mo, Int(Int16.max)))
                setValue(NSNumber(value: 0), forKey: "intervalDays")
                setValue(NSNumber(value: v), forKey: "intervalMonths")
            }
        } else {
            // interval 없음: 두 필드 모두 0 (required + sentinel)
            setValue(NSNumber(value: 0), forKey: "intervalDays")
            setValue(NSNumber(value: 0), forKey: "intervalMonths")
        }

        // 기존 Occurence 제거 후 재생성
        if let set = occurrences as? Set<Occurence> {
            set.forEach { ctx.delete($0) }
        }
        let newSet: [Occurence] = m.occurrences.map { o in
            let eo = Occurence(context: ctx)
            eo.id        = o.id
            eo.startDate = o.startDate
            eo.endDate   = o.endDate
            eo.payAmount = NSDecimalNumber(decimal: o.payAmount)
            eo.bindo     = self
            return eo
        }
        occurrences = NSSet(array: newSet)
    }
}
