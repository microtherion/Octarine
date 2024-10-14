 //
//  OctTree.swift
//  Octarine
//
//  Created by Matthias Neeracher on 20/04/16.
//  Copyright © 2016-2017 Matthias Neeracher. All rights reserved.
//

import AppKit

 let kOctPasteboardType = NSPasteboard.PasteboardType(rawValue:"OctPasteboardType")

var gOctTreeRoots = [OctTreeNode]()

class OctTreeNode : NSObject {
    var parent  : OctTreeNode?
    let item    : OctItem
    let path    : IndexPath

    fileprivate init(parent: OctTreeNode?, index: Int) {
        self.parent = parent
        let parentItem = parent?.item ?? OctItem.rootFolder()
        self.item   = parentItem.children![index] as! OctItem
        self.path   = parent?.path.appending(index) ?? IndexPath(index: index)

        super.init()
    }

    var isExpandable : Bool {
        return !item.isPart
    }

    var numberOfChildren : Int {
        return item.children?.count ?? 0
    }

    var parentItem : OctItem {
        return parent?.item ?? OctItem.rootFolder()
    }

    var persistentIdentifier : String {
        return item.ident + "[" + parentItem.ident + "]"
    }

    class func numberOfRootItems() -> Int {
        if gOctTreeRoots.count == 0 {
            // Lazy initialization
            if let roots = OctItem.rootFolder().children {
                for index in 0..<roots.count {
                    gOctTreeRoots.append(OctTreeNode(parent: nil, index: index))
                }
            }
        }
        return gOctTreeRoots.count
    }

    class func rootItem(_ index: Int) -> OctTreeNode {
        return gOctTreeRoots[index]
    }

    var children = [OctTreeNode]()

    func child(_ index: Int) -> OctTreeNode {
        if children.count == 0 {
            // Lazy initialization
            for index in 0..<numberOfChildren {
                children.append(OctTreeNode(parent: self, index: index))
            }
        }

        return children[index]
    }

    func isDescendantOf(_ node: OctTreeNode) -> Bool {
        if self == node {
            return true
        } else if path.count <= node.path.count {
            return false
        } else {
            return parent!.isDescendantOf(node)
        }
    }

    func isDescendantOfOneOf(_ nodes: [OctTreeNode]) -> Bool {
        for node in nodes {
            if isDescendantOf(node) {
                return true
            }
        }
        return false
    }

    func removeFromParent() {
        parentItem.mutableOrderedSetValue(forKey: "children").remove(item)
    }

    func deleteIfOrphaned() {
        if item.parents.count == 0 {
            OctItem.managedObjectContext.delete(item)
        }
    }

    class func mapNode(_ node: OctTreeNode, f : (OctTreeNode) -> Bool) {
        if f(node) {
            for i in 0..<node.numberOfChildren {
                mapNode(node.child(i), f: f)
            }
        }
    }

    class func map(_ f : (OctTreeNode) -> Bool) {
        for i in 0..<numberOfRootItems() {
            mapNode(rootItem(i), f: f)
        }
    }
}

var OCT_FOLDER  : NSImage?
var OCT_PART    : NSImage?

class OctTree : NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    @IBOutlet weak var outline : NSOutlineView!
    @IBOutlet weak var search: OctSearch!
    @IBOutlet weak var details: OctDetails!
    @IBOutlet weak var sheets: OctSheets!
    @IBOutlet weak var octApp : OctApp!

    override func awakeFromNib() {
        outline.registerForDraggedTypes([kOctPasteboardType])
        outline.setDraggingSourceOperationMask([.move, .copy], forLocal: true)
        outline.setDraggingSourceOperationMask([.delete], forLocal: false)

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: OCTARINE_DATABASE_RESET), object: nil, queue: OperationQueue.main) { (_: Notification) in
            gOctTreeRoots = []

            self.outline.reloadData()
        }
    }

    var oldTreeRoots = [OctTreeNode]()
    func reloadTree(expanding item: OctTreeNode? = nil) {
        var expandedGroups = [String]()

        for row in 0..<outline.numberOfRows {
            if outline.isItemExpanded(outline.item(atRow: row)) {
                expandedGroups.append((outline.item(atRow: row) as! OctTreeNode).persistentIdentifier)
            }
        }
        if let item=item {
            let identifier = item.persistentIdentifier
            if !expandedGroups.contains(identifier) {
                expandedGroups.append(identifier)
            }
        }

        oldTreeRoots  = gOctTreeRoots
        gOctTreeRoots = []
        outline.reloadData()

        OctTreeNode.map() { (group: OctTreeNode) -> Bool in
            if expandedGroups.contains(group.persistentIdentifier) {
                self.outline.expandItem(group)
                return true
            } else {
                return false
            }
        }
    }

    @IBAction func newGroup(_ sender: AnyObject) {
        let selectedNode = outline.item(atRow: outline.selectedRowIndexes.first!) as? OctTreeNode
        let parentItem   = selectedNode?.parent?.item ?? OctItem.rootFolder()
        let insertAt : Int
        if let path = selectedNode?.path {
            insertAt = path.last!+sender.tag
        } else {
            insertAt = parentItem.children?.count ?? 0
        }
        let group       = OctItem.createFolder("")
        group.name      = "New Group "+group.ident[..<group.ident.characters.index(group.ident.startIndex, offsetBy: 6)]
        var contents    = [OctTreeNode]()
        if sender.tag==0 {
            for row in outline.selectedRowIndexes {
                contents.append(outline.item(atRow: row) as! OctTreeNode)
            }
        }
        outline.beginUpdates()
        let kids = parentItem.mutableOrderedSetValue(forKey: "children")
        kids.insert(group, at: insertAt)
        let groupKids = group.mutableOrderedSetValue(forKey: "children")
        for node in contents {
            node.removeFromParent()
            groupKids.add(node.item)
        }
        outline.endUpdates()
        reloadTree()
        OctTreeNode.map { (node: OctTreeNode) -> Bool in
            if node.item == group {
                self.outline.editColumn(0, row: self.outline.row(forItem: node), with: nil, select: true)

                return false
            } else {
                return !node.item.isPart
            }
        }
    }

    func newCustomPart(_ part: OctItem) {
        let selectedNode = outline.item(atRow: outline.selectedRowIndexes.first!) as? OctTreeNode
        let parentItem   = selectedNode?.parent?.item ?? OctItem.rootFolder()
        let insertAt : Int
        if let path = selectedNode?.path {
            insertAt = path.last!+1
        } else {
            insertAt = parentItem.children?.count ?? 0
        }
        outline.beginUpdates()
        let kids = parentItem.mutableOrderedSetValue(forKey: "children")
        kids.insert(part, at: insertAt)
        outline.endUpdates()
        reloadTree()
        OctTreeNode.map { (node: OctTreeNode) -> Bool in
            if node.item == part {
                self.outline.selectRowIndexes(IndexSet(integer: self.outline.row(forItem: node)), byExtendingSelection: false)
            }
            return !node.item.isPart
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        return (item as? OctTreeNode)?.persistentIdentifier
    }

    func outlineView(_ outlineView: NSOutlineView, itemForPersistentObject object: Any) -> Any? {
        if let identifier = object as? String {
            var found : OctTreeNode?
            OctTreeNode.map() { (node: OctTreeNode) -> Bool in
                guard found==nil else { return false }
                if node.persistentIdentifier == identifier {
                    found = node
                    return false
                } else {
                    return true
                }
            }
            return found
        } else {
            return nil
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return (item as! OctTreeNode).isExpandable
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return (item as? OctTreeNode)?.numberOfChildren ?? OctTreeNode.numberOfRootItems()
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? OctTreeNode {
            return node.child(index)
        } else {
            return OctTreeNode.rootItem(index)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let tableColumn = tableColumn else { return nil }
        guard let octItem = (item as? OctTreeNode)?.item else { return nil }

        switch tableColumn.identifier.rawValue {
        case "name":
            return octItem.name
        case "desc":
            return octItem.desc
        default:
            return nil
        }
    }

    @IBAction func updateOutlineValue(_ sender: AnyObject) {
        guard let view = sender as? NSView else { return }
        let row = outline.row(for: view)
        let col = outline.column(for: view)

        guard let octItem = (outline.item(atRow: row) as? OctTreeNode)?.item else { return }
        guard let value   = (sender as? NSTextField)?.stringValue else { return }
        let tableColumn = outline.tableColumns[col]

        switch tableColumn.identifier.rawValue {
        case "name":
            octItem.name    = value
        case "desc":
            octItem.desc    = value
        default:
            break
        }

        outlineViewSelectionDidChange(Notification(name:Notification.Name(rawValue: "dummy"), object:self))
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        let view = outlineView.makeView(withIdentifier: tableColumn.identifier, owner: self) as! NSTableCellView

        guard let octItem = (item as? OctTreeNode)?.item else { return nil }

        switch tableColumn.identifier.rawValue {
        case "name":
            if OCT_FOLDER == nil {
                let frameSize   = view.imageView!.frame.size
                OCT_FOLDER      = NSImage(named: NSImage.Name(rawValue: "oct_folder"))
                let folderSize  = OCT_FOLDER!.size
                OCT_FOLDER!.size =  NSMakeSize(folderSize.width*(frameSize.height/folderSize.height), frameSize.height)
                OCT_PART        = NSImage(named: NSImage.Name(rawValue: "oct_part"))
                let partSize    = OCT_PART!.size
                OCT_PART!.size  =  NSMakeSize(partSize.width*(frameSize.height/partSize.height), frameSize.height)
            }
            if octItem.isPart {
                view.imageView?.image   = OCT_PART
            } else {
                view.imageView?.image   = OCT_FOLDER
            }
        default:
            break
        }

        return view
    }

    var draggedItems = [OctItem]()
    var draggedNodes = [OctTreeNode]()

    func outlineView(_ outlineView: NSOutlineView, writeItems items: [Any], to pboard: NSPasteboard) -> Bool {
        draggedNodes = items as! [OctTreeNode]
        draggedItems = draggedNodes.map { (node: OctTreeNode) -> OctItem in
            node.item
        }
        let serialized = draggedItems.map { (item: OctItem) in
            item.serialized()
        }
        pboard.declareTypes([kOctPasteboardType], owner: self)
        pboard.setPropertyList(serialized, forType: kOctPasteboardType)

        return true
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo,
                     proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation
    {
        guard info.draggingPasteboard().availableType(from: [kOctPasteboardType]) != nil else {
            return NSDragOperation() 
        }
        guard let draggingSource = info.draggingSource() as? NSOutlineView, draggingSource == outlineView else
        {
            return [.generic, .copy] // Drags from outside the outline always OK
        }
        guard let octNode = item as? OctTreeNode else {
            return [.move, .copy] // Drags into root always OK
        }
        if !octNode.isExpandable {
            return NSDragOperation()     // Don't allow dragging on a part
        } else if octNode.isDescendantOfOneOf(draggedNodes) {
            return NSDragOperation()     // Don't allow drag on dragged items or their descendents
        } else {
            return [.move, .copy]  // Otherwise we're good
        }
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo,
                     item: Any?, childIndex: Int) -> Bool
    {
        if let draggingSource = info.draggingSource() as? NSOutlineView, draggingSource == outlineView
        {
            // draggedNodes and draggedItems already contain an accurate representation
        } else {
            // Deserialize draggedItems from pasteboard
            draggedNodes = []
            let serialized = info.draggingPasteboard().propertyList(forType: kOctPasteboardType) as! [[String: AnyObject]]
            draggedItems = serialized.map({ (item: [String: AnyObject]) -> OctItem in
                return OctItem.itemFromSerialized(item)
            })
        }
        let newParentNode   = item as? OctTreeNode
        let newParent       = newParentNode?.item ?? OctItem.rootFolder()
        var insertAtIndex   = childIndex
        if insertAtIndex == NSOutlineViewDropOnItemIndex {
            insertAtIndex   = newParent.children?.count ?? 0
        }
        var insertAtRow     = outlineView.row(forItem: item)
        if insertAtRow < 0 {
            insertAtRow     = outlineView.numberOfRows
        }

        outlineView.beginUpdates()
        //
        // If this is a move, remove from previous parent, if any
        //
        if info.draggingSourceOperationMask().contains(.move) {
            for node in draggedNodes.reversed() {
                let path   = node.path
                let parent = node.parentItem
                let index  = path.last!
                if parent == newParent && index < insertAtIndex {
                    insertAtIndex -= 1
                }
                if outlineView.row(forItem: node) < insertAtRow {
                    insertAtRow -= 1
                }
                node.removeFromParent()
            }
        }
        for item in draggedItems {
            let kids = newParent.mutableOrderedSetValue(forKey: "children")
            kids.insert(item, at: insertAtIndex)
            insertAtIndex += 1
        }
        outlineView.endUpdates()
        reloadTree(expanding: newParentNode)
        let insertedIndexes = IndexSet(integersIn: Range(NSMakeRange(insertAtRow, draggedItems.count)) ?? 0..<0)
        outlineView.selectRowIndexes(insertedIndexes, byExtendingSelection: false)

        return true
    }

    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation)
    {
        if operation.contains(.delete) {
            outlineView.beginUpdates()
            for node in draggedNodes {
                node.removeFromParent()
                node.deleteIfOrphaned()
            }
            outlineView.endUpdates()
            reloadTree()
        }
        DispatchQueue.main.async {
            self.oldTreeRoots = []
        }
    }

    func selectedItems() -> [OctItem] {
        return outline.selectedRowIndexes.map() { (row: Int) -> OctItem in
            (outline.item(atRow: row) as! OctTreeNode).item
        }
    }

    func outlineViewSelectionDidChange(_: Notification) {
        let selection = selectedItems()
        let standardParts = selection.filter { (item: OctItem) -> Bool in
            !item.isCustomPart
        }
        var newResults = selection.map { (item: OctItem) -> [String: Any] in
            item.serialized()
        }
        DispatchQueue.main.async {
            self.search.searchResults = newResults
        }

        guard standardParts.count > 0 else { return }

        search.partsFromUIDs(standardParts.map {$0.ident}) { (parts: [[String : Any]]) in
            for part in parts {
                let index   = try? newResults.index { (result: [String : Any]) throws -> Bool in
                    return (result["ident"] as! String) == (part["ident"] as! String)
                }
                if let index = index ?? nil {
                    let storedPart      = newResults[index]
                    var newPart         = part
                    newPart["name"]     = storedPart["name"]
                    newPart["desc"]     = storedPart["desc"]
                    newResults[index]   = newPart
                } else {
                    newResults.append(part)
                }
            }
            DispatchQueue.main.async {
                self.search.searchResults = newResults
            }
        }
    }

    func selectedItem() -> OctItem {
        return (outline.item(atRow: outline.selectedRow) as! OctTreeNode).item
    }
}

class OctOutlineView : NSOutlineView {
    @IBAction func delete(_: AnyObject) {
        let nodes = selectedRowIndexes.map { (index: Int) -> OctTreeNode in
            item(atRow: index) as! OctTreeNode
        }
        beginUpdates()
        for node in nodes {
            node.removeFromParent()
            node.deleteIfOrphaned()
        }
        endUpdates()
        (dataSource as? OctTree)?.reloadTree()
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(OctOutlineView.delete(_:)) {
            return selectedRowIndexes.count > 0
        }
        return super.validateUserInterfaceItem(item)
    }
}
