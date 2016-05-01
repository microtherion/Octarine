//
//  OctItem+CoreDataProperties.swift
//  Octarine
//
//  Created by Matthias Neeracher on 17/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension OctItem {
    @NSManaged var isPart: Bool
    @NSManaged var name: String
    @NSManaged var ident: String
    @NSManaged var desc: String
    @NSManaged var part_url: String?
    @NSManaged var manufacturer: String?
    @NSManaged var manu_url: String?
    @NSManaged var parents: NSSet
    @NSManaged var children: NSOrderedSet?
    @NSManaged var sheets: NSOrderedSet?
}
