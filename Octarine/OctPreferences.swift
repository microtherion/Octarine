//
//  OctPreferences.swift
//  Octarine
//
//  Created by Matthias Neeracher on 07/05/16.
//  Copyright © 2016-2017 Matthias Neeracher. All rights reserved.
//

import Cocoa

class OctPreferences: NSWindowController, NSOpenSavePanelDelegate {
    @IBOutlet weak var octApp : OctApp!

    convenience init() {
        self.init(windowNibName: NSNib.Name(rawValue: "OctPreferences"))
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    @IBAction func resetDatabase(_: AnyObject) {
        let alert = NSAlert()
        alert.alertStyle    = .critical
        alert.messageText   = "Do you really want to reset the database? This will delete all stored items."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Reset")
        alert.beginSheetModal(for: window!, completionHandler: { (response: NSApplication.ModalResponse) in
            if response.rawValue == 1001 {
                let fetchRequest        = NSFetchRequest<NSFetchRequestResult>(entityName: "OctItem")
                fetchRequest.predicate  = NSPredicate(format: "ident == ''")
                let results             = try? self.octApp.managedObjectContext.fetch(fetchRequest)

                if let results = results as? [NSManagedObject] {
                    for result in results {
                        self.octApp.managedObjectContext.delete(result)
                    }
                    NotificationCenter.default.post(name: Notification.Name(rawValue: OCTARINE_DATABASE_RESET), object: self)
                }
            }
        }) 
    }

    @IBAction func migrateDatabase(_: AnyObject) {
        let defaults = UserDefaults.standard
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles            = false
        openPanel.canChooseDirectories      = true
        openPanel.canCreateDirectories      = true
        openPanel.allowsMultipleSelection   = false
        openPanel.allowedFileTypes          = [kUTTypeDirectory as String]
        openPanel.delegate                  = nil
        if let path = defaults.string(forKey: "DatabasePath") {
            openPanel.directoryURL          = URL(fileURLWithPath: path)
        }
        openPanel.beginSheetModal(for: window!) { (response: NSApplication.ModalResponse) in
            if response.rawValue == NSFileHandlingPanelOKButton {
                let url         = openPanel.url!.appendingPathComponent("Octarine.storedata")
                let coordinator = self.octApp.persistentStoreCoordinator
                let oldStore    = coordinator.persistentStores[0]
                if let _ = try? coordinator.migratePersistentStore(oldStore, to: url, options: nil, withType: NSSQLiteStoreType) {
                    defaults.set(openPanel.url?.path, forKey: "DatabasePath")
                }
            }
        }
    }

    @IBAction func openDatabase(_: AnyObject) {
        let defaults = UserDefaults.standard
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles            = true
        openPanel.canChooseDirectories      = false
        openPanel.allowsMultipleSelection   = false
        openPanel.allowedFileTypes          = ["storedata"]
        openPanel.delegate                  = nil
        if let path = defaults.string(forKey: "DatabasePath") {
            openPanel.directoryURL          = URL(fileURLWithPath: path)
        }
        openPanel.beginSheetModal(for: window!) { (response: NSApplication.ModalResponse) in
            if response.rawValue == NSFileHandlingPanelOKButton {
                let url         = openPanel.url!
                let coordinator = self.octApp.persistentStoreCoordinator
                let oldStore    = coordinator.persistentStores[0]
                if let _ = try? coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil) {
                    try! coordinator.remove(oldStore)
                    defaults.set(url.deletingLastPathComponent().path, forKey: "DatabasePath")
                    NotificationCenter.default.post(name: Notification.Name(rawValue: OCTARINE_DATABASE_RESET), object: self)
                }
            }
        }
    }

    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        return url.lastPathComponent == "Octarine.storedata"
    }
}
