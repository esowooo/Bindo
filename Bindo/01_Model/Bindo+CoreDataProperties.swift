//
//  Bindo+CoreDataProperties.swift
//  Bindo
//
//  Created by Sean Choi on 9/16/25.
//
//

import Foundation
import CoreData


extension Bindo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Bindo> {
        return NSFetchRequest<Bindo>(entityName: "Bindo")
    }

    @NSManaged public var amount: NSDecimalNumber?
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var intervalDays: Int16
    @NSManaged public var intervalMonths: Int16
    @NSManaged public var name: String?
    @NSManaged public var option: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var occurrences: NSSet?

}

// MARK: Generated accessors for occurrences
extension Bindo {

    @objc(addOccurrencesObject:)
    @NSManaged public func addToOccurrences(_ value: Occurence)

    @objc(removeOccurrencesObject:)
    @NSManaged public func removeFromOccurrences(_ value: Occurence)

    @objc(addOccurrences:)
    @NSManaged public func addToOccurrences(_ values: NSSet)

    @objc(removeOccurrences:)
    @NSManaged public func removeFromOccurrences(_ values: NSSet)

}

extension Bindo : Identifiable {

}
