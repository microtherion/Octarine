//
//  OctCustomPart.swift
//  Octarine
//
//  Created by Matthias Neeracher on 29/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

class OctCustomPart : NSObject, NSTableViewDataSource {
    @IBOutlet weak var sheet : NSWindow!
    @IBOutlet weak var mainWindow: NSWindow!
    @IBOutlet weak var partTree: OctTree!
    @IBOutlet weak var dataSheets: NSTableView!

    var name    = "New Part"
    var purl    = ""
    var manu    = ""
    var murl    = ""
    var desc    = ""
    var sheets  = [String]()

    override func awakeFromNib() {
        dataSheets.registerForDraggedTypes(["public.url"])
        dataSheets.setDraggingSourceOperationMask([.Move], forLocal: true)
        dataSheets.setDraggingSourceOperationMask([.Delete], forLocal: false)
    }

    @IBAction func beginPartSheet(_: AnyObject) {
        mainWindow.beginSheet(sheet) { (response: NSModalResponse) in
            if (response > 0) {
                let part = OctItem.createCustomPart()
                part.name               = self.name
                if self.purl != "" {
                    part.part_url       = self.purl
                }
                if self.manu != "" {
                    part.manufacturer   = self.manu
                }
                if self.murl != "" {
                    part.manu_url       = self.murl
                }
                part.desc           = self.desc
                part.setDataSheets(self.sheets)

                self.partTree.newCustomPart(part)
            }
        }
    }

    @IBAction func add(_: AnyObject) {
        mainWindow.endSheet(sheet, returnCode:1)
    }

    @IBAction func dismiss(_: AnyObject) {
        mainWindow.endSheet(sheet)
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