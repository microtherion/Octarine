//
//  OctItem.swift
//  Octarine
//
//  Created by Matthias Neeracher on 17/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit
import CoreData

class OctItem: NSManagedObject {
    class var managedObjectContext : NSManagedObjectContext {
        return (NSApp.delegate as! OctApp).managedObjectContext
    }

    class func createPart(name: String, desc: String, partID: String) -> OctItem
    {
        let newPart = NSEntityDescription.insertNewObjectForEntityForName("OctItem", inManagedObjectContext: managedObjectContext) as! OctItem
        newPart.isPart = true
        newPart.name   = name
        newPart.desc   = desc
        newPart.ident  = partID

        return newPart
    }

    class func createFolder(name: String) -> OctItem
    {
        let newFolder = NSEntityDescription.insertNewObjectForEntityForName("OctItem", inManagedObjectContext: managedObjectContext) as! OctItem
        newFolder.isPart = false
        newFolder.name   = name
        newFolder.desc   = ""
        newFolder.ident  = NSUUID().UUIDString

        return newFolder
    }

    class func findItemByID(ID: String) -> OctItem?
    {
        let fetchRequest        = NSFetchRequest(entityName: "OctItem")
        fetchRequest.predicate  = NSPredicate(format: "ident == %@", ID)
        let results             = try? managedObjectContext.executeFetchRequest(fetchRequest)
        
        if let fetched = results {
            return fetched[0] as? OctItem
        } else {
            return nil
        }
    }

    class func itemFromSerialized(serialized: [String: AnyObject]) -> OctItem
    {
        if let found = findItemByID(serialized["ident"] as! String) {
            return found
        } else if serialized["is_part"] as! Bool {
            return createPart(serialized["name"] as! String,
                              desc: serialized["desc"] as! String,
                              partID: serialized["ident"] as! String)
        } else {
            return createFolder(serialized["name"] as! String)
        }
    }

    func serialized() -> [String : AnyObject] {
        return ["is_part": isPart, "name": name, "desc": desc, "ident": ident];
    }

    dynamic var displayName : String {
        return (isPart ? "" : "📁") + name
    }
}
