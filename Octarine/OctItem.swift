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

    class func createPart(_ name: String, desc: String, partID: String) -> OctItem {
        let newPart = NSEntityDescription.insertNewObject(forEntityName: "OctItem", into: managedObjectContext) as! OctItem
        newPart.isPart = true
        newPart.name   = name
        newPart.desc   = desc
        newPart.ident  = partID

        return newPart
    }

    class func createCustomPart() -> OctItem {
        let newPart = NSEntityDescription.insertNewObject(forEntityName: "OctItem", into: managedObjectContext) as! OctItem
        newPart.isPart = true
        newPart.ident  = UUID().uuidString

        return newPart
    }
    
    class func createFolder(_ name: String) -> OctItem {
        let newFolder = NSEntityDescription.insertNewObject(forEntityName: "OctItem", into: managedObjectContext) as! OctItem
        newFolder.isPart = false
        newFolder.name   = name
        newFolder.desc   = ""
        newFolder.ident  = UUID().uuidString

        return newFolder
    }

    class func rootFolder() -> OctItem {
        let fetchRequest        = NSFetchRequest<NSFetchRequestResult>(entityName: "OctItem")
        fetchRequest.predicate  = NSPredicate(format: "ident == ''")
        let results             = try? managedObjectContext.fetch(fetchRequest)

        if let results = results, results.count>0 {
            return results[0] as! OctItem
        } else {
            let newFolder = NSEntityDescription.insertNewObject(forEntityName: "OctItem", into: managedObjectContext) as! OctItem
            newFolder.isPart = false
            newFolder.name   = ""
            newFolder.desc   = ""
            newFolder.ident  = ""

            return newFolder;
        }
    }

    class func findItemByID(_ ID: String) -> OctItem? {
        let fetchRequest        = NSFetchRequest<NSFetchRequestResult>(entityName: "OctItem")
        fetchRequest.predicate  = NSPredicate(format: "ident == %@", ID)
        let results             = try? managedObjectContext.fetch(fetchRequest)
        
        if let fetched = results, fetched.count > 0 {
            return fetched[0] as? OctItem
        } else {
            return nil
        }
    }

    class func itemFromSerialized(_ serialized: [String: AnyObject]) -> OctItem {
        if let found = findItemByID(serialized["ident"] as! String) {
            return found
        } else if serialized["is_part"] as! Bool {
            let part = createPart(serialized["name"] as! String,
                                  desc: serialized["desc"] as! String,
                                  partID: serialized["ident"] as! String)
            if part.isCustomPart {
                part.part_url       = serialized["purl"] as? String
                part.manufacturer   = serialized["manu"] as? String
                part.manu_url       = serialized["murl"] as? String
            }
            if let sheets = serialized["sheets"] as? [String] {
                part.setDataSheets(sheets)
            }

            return part
        } else {
            return createFolder(serialized["name"] as! String)
        }
    }

    func serialized() -> [String : Any] {
        var result : [String : Any] = ["is_part": isPart, "name": name, "desc": desc, "ident": ident]
        result["manu"] = manufacturer as AnyObject?
        result["murl"] = manu_url as AnyObject?
        result["purl"] = part_url as AnyObject?
        result["sheets"] = sheets?.flatMap() { (sheet) in
            (sheet as? NSManagedObject)?.value(forKey: "url") as? String
        } ?? [String]()

        return result
    }

    dynamic var displayName : String {
        return (isPart ? "" : "📁") + name
    }

    dynamic var isCustomPart : Bool {
        // Custom parts have UUIDs, standard parts have hex encoded 64 bit numbers
        return ident.lengthOfBytes(using: String.Encoding.utf8) > 16
    }

    func setDataSheets(_ sheets: [String]) {
        if sheets.count > 0 {
            // Just delete and rebuild them all
            let newSheets = mutableOrderedSetValue(forKey: "sheets")
            newSheets.removeAllObjects()
            for sheet in sheets {
                let newSheet = NSEntityDescription.insertNewObject(forEntityName: "OctDataSheet", into: OctItem.managedObjectContext)
                newSheet.setValue(sheet, forKey: "url")
                newSheets.add(newSheet)
            }
        } else {
            self.sheets = nil
        }
    }
}
