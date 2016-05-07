//
//  OctPreferences.swift
//  Octarine
//
//  Created by Matthias Neeracher on 07/05/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import Cocoa

class OctPreferences: NSWindowController, NSOpenSavePanelDelegate {
    @IBOutlet weak var octApp : OctApp!

    convenience init() {
        self.init(windowNibName: "OctPreferences")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    @IBAction func resetDatabase(_: AnyObject) {
        let alert = NSAlert()
        alert.alertStyle    = .CriticalAlertStyle
        alert.messageText   = "Do you really want to reset the database? This will delete all stored items."
        alert.addButtonWithTitle("Cancel")
        alert.addButtonWithTitle("Reset")
        alert.beginSheetModalForWindow(window!) { (response: NSModalResponse) in
            if response == 1001 {
                let fetchRequest                    = NSFetchRequest(entityName: "OctItem")
                fetchRequest.predicate  = NSPredicate(format: "ident == ''")
                let results                         = try? self.octApp.managedObjectContext.executeFetchRequest(fetchRequest)

                if let results = results as? [NSManagedObject] {
                    for result in results {
                        self.octApp.managedObjectContext.deleteObject(result)
                    }
                    NSNotificationCenter.defaultCenter().postNotificationName(OCTARINE_DATABASE_RESET, object: self)
                }
            }
        }
    }

    @IBAction func migrateDatabase(_: AnyObject) {
        let defaults = NSUserDefaults.standardUserDefaults()
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles            = false
        openPanel.canChooseDirectories      = true
        openPanel.allowsMultipleSelection   = false
        openPanel.allowedFileTypes          = [kUTTypeDirectory as String]
        openPanel.delegate                  = nil
        if let path = defaults.stringForKey("DatabasePath") {
            openPanel.directoryURL          = NSURL(fileURLWithPath: path)
        }
        openPanel.beginSheetModalForWindow(window!) { (response: Int) in
            if response == NSFileHandlingPanelOKButton {
                let url         = openPanel.URL!.URLByAppendingPathComponent("Octarine.storedata")
                let coordinator = self.octApp.persistentStoreCoordinator
                let oldStore    = coordinator.persistentStores[0]
                if let _ = try? coordinator.migratePersistentStore(oldStore, toURL: url, options: nil, withType: NSSQLiteStoreType) {
                    defaults.setObject(openPanel.URL?.path, forKey: "DatabasePath")
                }
            }
        }
    }

    @IBAction func openDatabase(_: AnyObject) {
        let defaults = NSUserDefaults.standardUserDefaults()
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles            = true
        openPanel.canChooseDirectories      = false
        openPanel.allowsMultipleSelection   = false
        openPanel.allowedFileTypes          = ["storedata"]
        openPanel.delegate                  = nil
        if let path = defaults.stringForKey("DatabasePath") {
            openPanel.directoryURL          = NSURL(fileURLWithPath: path)
        }
        openPanel.beginSheetModalForWindow(window!) { (response: Int) in
            if response == NSFileHandlingPanelOKButton {
                let url         = openPanel.URL!
                let coordinator = self.octApp.persistentStoreCoordinator
                let oldStore    = coordinator.persistentStores[0]
                if let _ = try? coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil) {
                    try! coordinator.removePersistentStore(oldStore)
                    defaults.setObject(url.URLByDeletingLastPathComponent?.path, forKey: "DatabasePath")
                    NSNotificationCenter.defaultCenter().postNotificationName(OCTARINE_DATABASE_RESET, object: self)
                }
            }
        }
    }

    func panel(sender: AnyObject, shouldEnableURL url: NSURL) -> Bool {
        return url.lastPathComponent == "Octarine.storedata"
    }
}
