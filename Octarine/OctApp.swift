//
//  AppDelegate.swift
//  Octarine
//
//  Created by Matthias Neeracher on 06/03/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import Cocoa
import Quartz

let OCTOPART_API_KEY = "d0347dc3"
let OctarineSession = URLSession(configuration:URLSessionConfiguration.default)

let OCTARINE_DATABASE_RESET = "OctDBReset"

class NSTempURL {
    let url : URL
    init() {
        let tempRoot    = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        url             = tempRoot.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
    }
}
let OctTemp = NSTempURL()

@objc class HasSheetsTransformer : ValueTransformer {
    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override func transformedValue(_ value: Any?) -> Any? {
        if (value as! [Any]).isEmpty {
            return ""
        } else {
            return "📕"
        }
    }
}

func stringRep(_ o: Any?) -> String
{
    return (o as? String) ?? ""
}

@objc class LinkTransformer : ValueTransformer {
    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override func transformedValue(_ value: Any?) -> Any? {
        if let s = value as? String, s != "" {
            return NSColor.blue
        } else {
            return NSColor.black
        }
    }
}

@NSApplicationMain
class OctApp: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var searchController : NSArrayController!
    @IBOutlet weak var mainTabs : NSTabView!
    @IBOutlet weak var sheets : OctSheets!
    @IBOutlet weak var help : OctHelp!

    @objc dynamic var requestPending = 0
    func startingRequest() {
        DispatchQueue.main.async {
            self.requestPending += 1
        }
    }

    func endingRequest() {
        DispatchQueue.main.async {
            self.requestPending -= 1
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        ValueTransformer.setValueTransformer(HasSheetsTransformer(), forName: NSValueTransformerName(rawValue: "HasSheetsTransformer"))
        ValueTransformer.setValueTransformer(LinkTransformer(), forName: NSValueTransformerName(rawValue: "LinkTransformer"))
        ValueTransformer.setValueTransformer(LinkTransformer(), forName: NSValueTransformerName(rawValue: "FolderTransformer"))
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file.
        let defaults = UserDefaults.standard
        if let customPath = defaults.string(forKey: "DatabasePath") {
            return URL(fileURLWithPath: customPath)
        }
        // Default to a directory named "org.aereperennius.Octarine" in the user's Application Support directory.
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[urls.count - 1]
        return appSupportURL.appendingPathComponent("org.aereperennius.Octarine")
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "Octarine", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.) This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        let fileManager = FileManager.default
        var failError: NSError? = nil
        var shouldFail = false
        var failureReason = "There was an error creating or loading the application's saved data."

        // Make sure the application files directory is there
        do {
            let properties = try (self.applicationDocumentsDirectory as NSURL).resourceValues(forKeys: [URLResourceKey.isDirectoryKey])
            if !(properties[URLResourceKey.isDirectoryKey]! as AnyObject).boolValue {
                failureReason = "Expected a folder to store application data, found a file \(self.applicationDocumentsDirectory.path)."
                shouldFail = true
            }
        } catch  {
            let nserror = error as NSError
            if nserror.code == NSFileReadNoSuchFileError {
                do {
                    try fileManager.createDirectory(atPath: self.applicationDocumentsDirectory.path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    failError = nserror
                }
            } else {
                failError = nserror
            }
        }
        
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = nil
        if failError == nil {
            coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
            let url = self.applicationDocumentsDirectory.appendingPathComponent("Octarine.storedata")
            do {
                try coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
            } catch {
                failError = error as NSError
            }
        }
        
        if shouldFail || (failError != nil) {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject?
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?
            if failError != nil {
                dict[NSUnderlyingErrorKey] = failError
            }
            let error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            NSApp.presentError(error)
            abort()
        } else {
            return coordinator!
        }
    }()

    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving and Undo support

    @IBAction func saveAction(_ sender: AnyObject!) {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        if !managedObjectContext.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                let nserror = error as NSError
                NSApp.presentError(nserror)
            }
        }
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return managedObjectContext.undoManager
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        
        if !managedObjectContext.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }
        
        if !managedObjectContext.hasChanges {
            return .terminateNow
        }
        
        do {
            try managedObjectContext.save()
        } catch {
            let nserror = error as NSError
            // Customize this code block to include application-specific recovery steps.
            let result = sender.presentError(nserror)
            if (result) {
                return .terminateCancel
            }
            
            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)
            
            let answer = alert.runModal()
            if answer == .alertFirstButtonReturn {
                return .terminateCancel
            }
        }
        // If we got here, it is time to quit.
        return .terminateNow
    }

    @IBAction func followComponentLink(_ sender: NSTableView!) {
        let item = (searchController.arrangedObjects as! [[String: AnyObject]])[sender.clickedRow]
        var url  : URL?
        switch sender.clickedColumn {
        case 0:
            sheets.dataSheets = item["sheets"] as! [String]
            if !sheets.dataSheets.isEmpty {
                mainTabs.selectTabViewItem(withIdentifier: "sheet")
            }
        case 1:
            url = URL(string: item["purl"] as! String)
        case 2:
            url = URL(string: item["murl"] as! String)
        default:
            break
        }
        if url != nil {
            NSWorkspace.shared.open(url!)
        }
    }

    @IBAction func goToOctopart(_: AnyObject!) {
        NSWorkspace.shared.open(URL(string:"https://octopart.com")!)
    }

    @IBAction func showHelp(_ sender: AnyObject!) {
        help.showWindow(sender)
    }
}

