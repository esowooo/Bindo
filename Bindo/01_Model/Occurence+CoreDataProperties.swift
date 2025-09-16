//
//  Occurence+CoreDataProperties.swift
//  Bindo
//
//  Created by Sean Choi on 9/16/25.
//
//

import Foundation
import CoreData


extension Occurence {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Occurence> {
        return NSFetchRequest<Occurence>(entityName: "Occurence")
    }

    @NSManaged public var endDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var payAmount: NSDecimalNumber?
    @NSManaged public var startDate: Date?
    @NSManaged public var bindo: Bindo?

}

extension Occurence : Identifiable {

}
