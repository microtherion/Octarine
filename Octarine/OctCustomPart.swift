//
//  OctCustomPart.swift
//  Octarine
//
//  Created by Matthias Neeracher on 29/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

func optionalString(s: String) -> String? {
    return s == "" ? nil : s
}

class OctCustomPart : NSObject, NSTableViewDataSource {
    @IBOutlet weak var sheet : NSWindow!
    @IBOutlet weak var octApp: OctApp!
    @IBOutlet weak var mainWindow: NSWindow!
    @IBOutlet weak var partTree: OctTree!
    @IBOutlet weak var dataSheets: NSTableView!

    dynamic var name    = "New Part"
    dynamic var purl    = ""
    dynamic var manu    = ""
    dynamic var murl    = ""
    dynamic var desc    = ""
    dynamic var sheets  = [String]()
    dynamic var custom  = true
    dynamic var action  = "Add"

    override func awakeFromNib() {
        dataSheets.registerForDraggedTypes(["public.url"])
        dataSheets.setDraggingSourceOperationMask([.Move], forLocal: true)
        dataSheets.setDraggingSourceOperationMask([.Delete], forLocal: false)
    }

    @IBAction func beginPartSheet(sender: AnyObject) {
        let createPart = sender.tag() == 1
        if createPart {
            // Create custom part
            name    = "New Part"
            purl    = ""
            manu    = ""
            murl    = ""
            desc    = ""
            sheets  = []
            custom  = true
            action  = "Add"
        } else {
            // Edit part
            let part = partTree.selectedItem()
            name    = part.name
            purl    = part.part_url ?? ""
            manu    = part.manufacturer ?? ""
            murl    = part.manu_url ?? ""
            desc    = part.desc
            sheets  = []
            custom  = part.isCustomPart
            action  = "Edit"

            if let partSheets = part.sheets?.array as? [NSManagedObject] {
                sheets = partSheets.map { (sheet: NSManagedObject) -> String in
                    sheet.valueForKey("url") as! String
                }
            }

            if !custom {
                fetchPartInfo(part.ident)
            }
        }
        dataSheets.reloadData()
        mainWindow.beginSheet(sheet) { (response: NSModalResponse) in
            if (response > 0) {
                let part = createPart ? OctItem.createCustomPart() : self.partTree.selectedItem()
                part.name           = self.name
                part.part_url       = optionalString(self.purl)
                part.manufacturer   = optionalString(self.manu)
                part.manu_url       = optionalString(self.murl)
                part.desc           = self.desc
                part.setDataSheets(self.sheets)

                if createPart {
                    self.partTree.newCustomPart(part)
                }
            }
        }
    }

    @IBAction func add(_: AnyObject) {
        mainWindow.endSheet(sheet, returnCode:1)
    }

    @IBAction func dismiss(_: AnyObject) {
        mainWindow.endSheet(sheet)
    }

    @IBAction func addDataSheetFile(_: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles            = true
        openPanel.canChooseDirectories      = false
        openPanel.allowsMultipleSelection   = true
        openPanel.allowedFileTypes          = [kUTTypePDF as String]
        openPanel.beginSheetModalForWindow(sheet) { (response: Int) in
            if response == NSFileHandlingPanelOKButton {
                var at = self.dataSheets.selectedRow+1
                for url in openPanel.URLs {
                    self.sheets.insert(url.filePathURL!.absoluteString, atIndex: at)
                    at += 1
                }
                self.dataSheets.reloadData()
            }
        }
    }
    func deleteSelectedSheets() {
        for row in dataSheets.selectedRowIndexes.reverse() {
            sheets.removeAtIndex(row)
        }
        dataSheets.reloadData()
    }

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return sheets.count
    }

    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        return sheets[row]
    }

    func tableView(tableView: NSTableView, setObjectValue object: AnyObject?, forTableColumn tableColumn: NSTableColumn?, row: Int) {
        if let str = object as? String {
            sheets[row] = str
        }
    }

    var rowsBeingMoved : NSIndexSet?

    func tableView(tableView: NSTableView, writeRowsWithIndexes rowIndexes: NSIndexSet, toPasteboard pboard: NSPasteboard) -> Bool {
        var urls    = [NSURL]()
        for row in rowIndexes {
            if let url = NSURL(string: sheets[row]) {
                urls.append(url)
            }
        }
        pboard.writeObjects(urls)
        rowsBeingMoved = rowIndexes

        return urls.count > 0
    }

    func tableView(tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableViewDropOperation) -> NSDragOperation {
        guard info.draggingPasteboard().availableTypeFromArray(["public.url"]) != nil else {
            return .None
        }
        if dropOperation == .On {
            tableView.setDropRow(row, dropOperation: .Above)
        }
        guard let draggingSource = info.draggingSource() as? NSTableView
            where draggingSource == tableView else
        {
            return .Copy  // Drags from outside the view will copy
        }
        return .Move    // Otherwise we're reordering
    }

    func tableView(tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableViewDropOperation) -> Bool {
        var at      = row
        tableView.beginUpdates()
        if info.draggingSourceOperationMask() == [.Move] {
            for row in rowsBeingMoved!.reverse() {
                if row < at {
                    at -= 1
                }
                sheets.removeAtIndex(row)
            }
        }
        if let urls = info.draggingPasteboard().readObjectsForClasses([NSURL.self], options: nil) as? [NSURL] {
            for url in urls {
                let str = (url.filePathURL ?? url).absoluteString
                sheets.insert(str, atIndex: at)
                at += 1
            }
        }
        tableView.reloadData()
        tableView.endUpdates()
        return true
    }

    func tableView(tableView: NSTableView, draggingSession session: NSDraggingSession, endedAtPoint screenPoint: NSPoint, operation: NSDragOperation) {
        if operation == [.Delete] {
            tableView.beginUpdates()
            for row in rowsBeingMoved!.reverse() {
                sheets.removeAtIndex(row)
            }
            tableView.reloadData()
            tableView.endUpdates()
        }
        rowsBeingMoved = nil
    }

    func fetchPartInfo(ident: String) {
        let urlComponents = NSURLComponents(string: "https://octopart.com/api/v3/parts/get_multi")!
        let queryItems = [
            NSURLQueryItem(name: "apikey", value: OCTOPART_API_KEY),
            NSURLQueryItem(name: "include[]", value: "datasheets"),
            NSURLQueryItem(name: "uid[]", value: ident)
        ]
        urlComponents.queryItems = queryItems

        let task = OctarineSession.dataTaskWithURL(urlComponents.URL!) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            let response = try? NSJSONSerialization.JSONObjectWithData(data!, options: [])
            if response != nil {
                let results    = response as! [String: AnyObject]
                for (_,result) in results {
                    let part    = OctSearch.partFromJSON(result)
                    if part["ident"] as! String == ident {
                        dispatch_async(dispatch_get_main_queue()) {
                            self.purl   = stringRep(part["purl"])
                            self.manu   = stringRep(part["manu"])
                            self.murl   = stringRep(part["murl"])
                            self.sheets = (part["sheets"] as? [String]) ?? []
                            self.dataSheets.reloadData()
                        }
                    }
                }
            }
            self.octApp.endingRequest()
        }
        octApp.startingRequest()
        task.resume()
    }
}

class OctCustomPartSheets : NSTableView {
    @IBAction func delete(_: AnyObject) {
        (dataSource() as? OctCustomPart)?.deleteSelectedSheets()
    }

    @IBAction func copy(_: AnyObject) {
    }

    @IBAction func paste(_: AnyObject) {
    }
    
    override func validateUserInterfaceItem(item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action() {
        case #selector(OctCustomPartSheets.delete(_:)), #selector(OctCustomPartSheets.copy(_:)):
            return selectedRowIndexes.count > 0
        default:
            return super.validateUserInterfaceItem(item)
        }
    }
}