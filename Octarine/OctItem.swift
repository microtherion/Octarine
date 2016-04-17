//
//  OctItem.swift
//  Octarine
//
//  Created by Matthias Neeracher on 17/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import Foundation
import CoreData

class OctItem: NSManagedObject {
    class func createPartInManagedObjectContext(moc: NSManagedObjectContext,
                                            name: String, desc: String, part: String) -> OctItem
    {
        let newPart = NSEntityDescription.insertNewObjectForEntityForName("OctItem", inManagedObjectContext: moc) as! OctItem
        newPart.name   = name
        newPart.desc   = desc
        newPart.part   = part

        return newPart
    }

    class func createFolderInManagedObjectContext(moc: NSManagedObjectContext,
                                                  name: String) -> OctItem
    {
        let newFolder = NSEntityDescription.insertNewObjectForEntityForName("OctItem", inManagedObjectContext: moc) as! OctItem
        newFolder.name   = name
        newFolder.desc   = ""
        newFolder.part   = nil

        return newFolder
    }

    dynamic var isLeaf : Bool {
        return part != nil;
    }

    dynamic var displayName : String {
        return (isLeaf ? "" : "📁") + name
    }
}
