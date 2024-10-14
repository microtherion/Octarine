//
//  OctCustomPart.swift
//  Octarine
//
//  Created by Matthias Neeracher on 29/04/16.
//  Copyright © 2016-2017 Matthias Neeracher. All rights reserved.
//

import AppKit

func optionalString(_ s: String) -> String? {
    return s == "" ? nil : s
}

class OctCustomPart : NSObject, NSTableViewDataSource {
    @IBOutlet weak var sheet : NSWindow!
    @IBOutlet weak var octApp: OctApp!
    @IBOutlet weak var mainWindow: NSWindow!
    @IBOutlet weak var partTree: OctTree!
    @IBOutlet weak var search: OctSearch!
    @IBOutlet weak var dataSheets: NSTableView!

    @objc dynamic var name    = "New Part"
    @objc dynamic var purl    = ""
    @objc dynamic var manu    = ""
    @objc dynamic var murl    = ""
    @objc dynamic var desc    = ""
    @objc dynamic var sheets  = [String]()
    @objc dynamic var custom  = true
    @objc dynamic var action  = "Add"

    override func awakeFromNib() {
        dataSheets.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: "public.url")])
        dataSheets.setDraggingSourceOperationMask([.move], forLocal: true)
        dataSheets.setDraggingSourceOperationMask([.delete], forLocal: false)
    }

    @IBAction func beginPartSheet(_ sender: AnyObject) {
        let createPart = sender.tag == 1
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
                    sheet.value(forKey: "url") as! String
                }
            }

            if !custom {
                fetchPartInfo(part.ident)
            }
        }
        dataSheets.reloadData()
        mainWindow.beginSheet(sheet) { (response: NSApplication.ModalResponse) in
            if (response.rawValue > 0) {
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
        mainWindow.endSheet(sheet, returnCode:NSApplication.ModalResponse(rawValue: 1))
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
        openPanel.beginSheetModal(for: sheet) { (response: NSApplication.ModalResponse) in
            if response.rawValue == NSFileHandlingPanelOKButton {
                var at = self.dataSheets.selectedRow+1
                for url in openPanel.urls {
                    self.sheets.insert((url as NSURL).filePathURL!.absoluteString, at: at)
                    at += 1
                }
                self.dataSheets.reloadData()
            }
        }
    }
    
    func deleteSelectedSheets() {
        for row in dataSheets.selectedRowIndexes.reversed() {
            sheets.remove(at: row)
        }
        dataSheets.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return sheets.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return sheets[row]
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        if let str = object as? String {
            sheets[row] = str
        }
    }

    var rowsBeingMoved : IndexSet?

    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        var urls    = [URL]()
        for row in rowIndexes {
            if let url = URL(string: sheets[row]) {
                urls.append(url)
            }
        }
        pboard.writeObjects(urls as [NSPasteboardWriting])
        rowsBeingMoved = rowIndexes

        return urls.count > 0
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard info.draggingPasteboard().availableType(from: [NSPasteboard.PasteboardType(rawValue: "public.url")]) != nil else {
            return NSDragOperation()
        }
        if dropOperation == .on {
            tableView.setDropRow(row, dropOperation: .above)
        }
        guard let draggingSource = info.draggingSource() as? NSTableView, draggingSource == tableView else
        {
            return .copy  // Drags from outside the view will copy
        }
        return .move    // Otherwise we're reordering
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        var at      = row
        tableView.beginUpdates()
        if info.draggingSourceOperationMask() == [.move] {
            for row in rowsBeingMoved!.reversed() {
                if row < at {
                    at -= 1
                }
                sheets.remove(at: row)
            }
        }
        if let urls = info.draggingPasteboard().readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                let str = url.standardizedFileURL.absoluteString
                sheets.insert(str, at: at)
                at += 1
            }
        }
        tableView.reloadData()
        tableView.endUpdates()
        return true
    }

    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation == [.delete] {
            tableView.beginUpdates()
            for row in rowsBeingMoved!.reversed() {
                sheets.remove(at: row)
            }
            tableView.reloadData()
            tableView.endUpdates()
        }
        rowsBeingMoved = nil
    }

    func fetchPartInfo(_ ident: String) {
        search.partsFromUIDs([ident]) { (parts: [[String : Any]]) in
            for part in parts {
                if part["ident"] as! String == ident {
                    DispatchQueue.main.async {
                        self.purl   = stringRep(part["purl"])
                        self.manu   = stringRep(part["manu"])
                        self.murl   = stringRep(part["murl"])
                        self.sheets = (part["sheets"] as? [String]) ?? []
                        self.dataSheets.reloadData()
                    }
                }
            }
        }
    }
}

class OctCustomPartSheets : NSTableView {
    @IBAction func delete(_: AnyObject) {
        (dataSource as? OctCustomPart)?.deleteSelectedSheets()
    }

    @IBAction func copy(_: AnyObject) {
    }

    @IBAction func paste(_: AnyObject) {
    }
    
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action! {
        case #selector(OctCustomPartSheets.delete(_:)), #selector(OctCustomPartSheets.copy(_:)):
            return selectedRowIndexes.count > 0
        default:
            return super.validateUserInterfaceItem(item)
        }
    }
}
