 //
//  OctTree.swift
//  Octarine
//
//  Created by Matthias Neeracher on 20/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

let kOctPasteboardType = "OctPasteboardType"

var gOctTreeRoots = [OctTreeNode]()

class OctTreeNode : NSObject {
    var parent  : OctTreeNode?
    let item    : OctItem
    let path    : NSIndexPath

    private init(parent: OctTreeNode?, index: Int) {
        self.parent = parent
        let parentItem = parent?.item ?? OctItem.rootFolder()
        self.item   = parentItem.children![index] as! OctItem
        self.path   = parent?.path.indexPathByAddingIndex(index) ?? NSIndexPath(index: index)

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

    class func rootItem(index: Int) -> OctTreeNode {
        return gOctTreeRoots[index]
    }

    var children = [OctTreeNode]()

    func child(index: Int) -> OctTreeNode {
        if children.count == 0 {
            // Lazy initialization
            for index in 0..<numberOfChildren {
                children.append(OctTreeNode(parent: self, index: index))
            }
        }

        return children[index]
    }

    func isDescendantOf(node: OctTreeNode) -> Bool {
        if self == node {
            return true
        } else if path.length <= node.path.length {
            return false
        } else {
            return parent!.isDescendantOf(node)
        }
    }

    func isDescendantOfOneOf(nodes: [OctTreeNode]) -> Bool {
        for node in nodes {
            if isDescendantOf(node) {
                return true
            }
        }
        return false
    }

    func removeFromParent() {
        parentItem.mutableOrderedSetValueForKey("children").removeObject(item)
    }

    func deleteIfOrphaned() {
        if item.parents.count == 0 {
            item.managedObjectContext?.deleteObject(item)
        }
    }

    class func mapNode(node: OctTreeNode, f : (OctTreeNode) -> Bool) {
        if f(node) {
            for i in 0..<node.numberOfChildren {
                mapNode(node.child(i), f: f)
            }
        }
    }

    class func map(f : (OctTreeNode) -> Bool) {
        for i in 0..<numberOfRootItems() {
            mapNode(rootItem(i), f: f)
        }
    }
}

class OctTree : NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    @IBOutlet weak var outline : NSOutlineView!
    @IBOutlet weak var search: OctSearch!
    @IBOutlet weak var details: OctDetails!
    @IBOutlet weak var sheets: OctSheets!
    @IBOutlet weak var octApp : OctApp!

    override func awakeFromNib() {
        outline.registerForDraggedTypes([kOctPasteboardType])
        outline.setDraggingSourceOperationMask([.Move, .Copy], forLocal: true)
        outline.setDraggingSourceOperationMask([.Delete], forLocal: false)
    }

    var oldTreeRoots = [OctTreeNode]()
    func reloadTree(expanding item: OctTreeNode? = nil) {
        var expandedGroups = [String]()

        for row in 0..<outline.numberOfRows {
            if outline.isItemExpanded(outline.itemAtRow(row)) {
                expandedGroups.append((outline.itemAtRow(row) as! OctTreeNode).persistentIdentifier)
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

    @IBAction func newGroup(sender: AnyObject) {
        let selectedNode = outline.itemAtRow(outline.selectedRowIndexes.firstIndex) as? OctTreeNode
        let parentItem   = selectedNode?.parent?.item ?? OctItem.rootFolder()
        let insertAt : Int
        if let path = selectedNode?.path {
            insertAt = path.indexAtPosition(path.length-1)+sender.tag()
        } else {
            insertAt = parentItem.children?.count ?? 0
        }
        let group       = OctItem.createFolder("")
        group.name      = "New Group "+group.ident.substringToIndex(group.ident.startIndex.advancedBy(6))
        var contents    = [OctTreeNode]()
        if sender.tag()==0 {
            for row in outline.selectedRowIndexes {
                contents.append(outline.itemAtRow(row) as! OctTreeNode)
            }
        }
        outline.beginUpdates()
        let kids = parentItem.mutableOrderedSetValueForKey("children")
        kids.insertObject(group, atIndex: insertAt)
        let groupKids = group.mutableOrderedSetValueForKey("children")
        for node in contents {
            node.removeFromParent()
            groupKids.addObject(node.item)
        }
        outline.endUpdates()
        reloadTree()
        outline.editColumn(0, row: insertAt, withEvent: nil, select: true)
    }

    func newCustomPart(part: OctItem) {
        let selectedNode = outline.itemAtRow(outline.selectedRowIndexes.firstIndex) as? OctTreeNode
        let parentItem   = selectedNode?.parent?.item ?? OctItem.rootFolder()
        let insertAt : Int
        if let path = selectedNode?.path {
            insertAt = path.indexAtPosition(path.length-1)+1
        } else {
            insertAt = parentItem.children?.count ?? 0
        }
        outline.beginUpdates()
        let kids = parentItem.mutableOrderedSetValueForKey("children")
        kids.insertObject(part, atIndex: insertAt)
        outline.endUpdates()
        reloadTree()
    }
    
    func outlineView(outlineView: NSOutlineView, persistentObjectForItem item: AnyObject?) -> AnyObject? {
        return (item as? OctTreeNode)?.persistentIdentifier
    }

    func outlineView(outlineView: NSOutlineView, itemForPersistentObject object: AnyObject) -> AnyObject? {
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

    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        return (item as! OctTreeNode).isExpandable
    }

    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        return (item as? OctTreeNode)?.numberOfChildren ?? OctTreeNode.numberOfRootItems()
    }

    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if let node = item as? OctTreeNode {
            return node.child(index)
        } else {
            return OctTreeNode.rootItem(index)
        }
    }

    func outlineView(outlineView: NSOutlineView, objectValueForTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject? {
        guard let octItem = (item as? OctTreeNode)?.item,
              let column = tableColumn?.identifier
        else {
            return nil
        }
        switch column {
        case "name":
            return octItem.name
        case "desc":
            return octItem.desc
        default:
            return nil
        }
    }

    func outlineView(outlineView: NSOutlineView, setObjectValue object: AnyObject?, forTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) {
        guard let octItem = (item as? OctTreeNode)?.item,
              let column = tableColumn?.identifier
        else {
                return
        }
        switch column {
        case "name":
            octItem.name = object as? String ?? ""
        case "desc":
            octItem.desc = object as? String ?? ""
        default:
            return
        }
    }

    var draggedItems = [OctItem]()
    var draggedNodes = [OctTreeNode]()

    func outlineView(outlineView: NSOutlineView, writeItems items: [AnyObject], toPasteboard pboard: NSPasteboard) -> Bool {
        draggedNodes = items as! [OctTreeNode]
        draggedItems = draggedNodes.map { (node: OctTreeNode) -> OctItem in
            node.item
        }
        let serialized = draggedItems.map { (item: OctItem) -> [String: AnyObject] in
            item.serialized()
        }
        pboard.declareTypes([kOctPasteboardType], owner: self)
        pboard.setPropertyList(serialized, forType: kOctPasteboardType)

        return true
    }

    func outlineView(outlineView: NSOutlineView, validateDrop info: NSDraggingInfo,
                     proposedItem item: AnyObject?, proposedChildIndex index: Int) -> NSDragOperation
    {
        guard info.draggingPasteboard().availableTypeFromArray([kOctPasteboardType]) != nil else {
            return .None 
        }
        guard let draggingSource = info.draggingSource() as? NSOutlineView
            where draggingSource == outlineView else
        {
            return [.Generic, .Copy] // Drags from outside the outline always OK
        }
        guard let octNode = item as? OctTreeNode else {
            return [.Move, .Copy] // Drags into root always OK
        }
        if !octNode.isExpandable {
            return .None     // Don't allow dragging on a part
        } else if octNode.isDescendantOfOneOf(draggedNodes) {
            return .None     // Don't allow drag on dragged items or their descendents
        } else {
            return [.Move, .Copy]  // Otherwise we're good
        }
    }

    func outlineView(outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo,
                     item: AnyObject?, childIndex: Int) -> Bool
    {
        if let draggingSource = info.draggingSource() as? NSOutlineView
            where draggingSource == outlineView
        {
            // draggedNodes and draggedItems already contain an accurate representation
        } else {
            // Deserialize draggedItems from pasteboard
            draggedNodes = []
            let serialized = info.draggingPasteboard().propertyListForType(kOctPasteboardType) as! [[String: AnyObject]]
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
        var insertAtRow     = outlineView.rowForItem(item)
        if insertAtRow < 0 {
            insertAtRow     = outlineView.numberOfRows
        }

        outlineView.beginUpdates()
        //
        // If this is a move, remove from previous parent, if any
        //
        if info.draggingSourceOperationMask().contains(.Move) {
            for node in draggedNodes.reverse() {
                let path   = node.path
                let parent = node.parentItem
                let index  = path.indexAtPosition(path.length-1)
                if parent == newParent && index < insertAtIndex {
                    insertAtIndex -= 1
                }
                if outlineView.rowForItem(node) < insertAtRow {
                    insertAtRow -= 1
                }
                node.removeFromParent()
            }
        }
        for item in draggedItems {
            let kids = newParent.mutableOrderedSetValueForKey("children")
            kids.insertObject(item, atIndex: insertAtIndex)
            insertAtIndex += 1
        }
        outlineView.endUpdates()
        reloadTree(expanding: newParentNode)
        let insertedIndexes = NSIndexSet(indexesInRange: NSMakeRange(insertAtRow, draggedItems.count))
        outlineView.selectRowIndexes(insertedIndexes, byExtendingSelection: false)

        return true
    }

    func outlineView(outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAtPoint screenPoint: NSPoint, operation: NSDragOperation)
    {
        if operation.contains(.Delete) {
            outlineView.beginUpdates()
            for node in draggedNodes {
                node.removeFromParent()
                node.deleteIfOrphaned()
            }
            outlineView.endUpdates()
            reloadTree()
        }
        dispatch_async(dispatch_get_main_queue()) {
            self.oldTreeRoots = []
        }
    }

    func outlineViewSelectionDidChange(_: NSNotification) {
        let selectedItems = outline.selectedRowIndexes.map() { (row: Int) -> OctItem in
            (outline.itemAtRow(row) as! OctTreeNode).item
        }
        let standardParts = selectedItems.filter { (item: OctItem) -> Bool in
            !item.isCustomPart
        }
        var newResults = selectedItems.map { (item: OctItem) -> [String: AnyObject] in
            item.serialized()
        }
        dispatch_async(dispatch_get_main_queue()) {
            self.search.searchResults = newResults
        }

        guard standardParts.count > 0 else { return }

        let urlComponents = NSURLComponents(string: "https://octopart.com/api/v3/parts/get_multi")!
        let queryItems = [
            NSURLQueryItem(name: "apikey", value: OCTOPART_API_KEY),
            NSURLQueryItem(name: "include[]", value: "datasheets"),
            NSURLQueryItem(name: "include[]", value: "short_description"),
            ] + standardParts.map() { (item: OctItem) -> NSURLQueryItem in
                NSURLQueryItem(name: "uid[]", value: item.ident)
        }
        urlComponents.queryItems = queryItems

        let task = OctarineSession.dataTaskWithURL(urlComponents.URL!) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            let response = try? NSJSONSerialization.JSONObjectWithData(data!, options: [])
            if response != nil {
                let results    = response as! [String: AnyObject]
                for (_,result) in results {
                    let part    = OctSearch.partFromJSON(result)
                    let index   = try? newResults.indexOf { (result: [String : AnyObject]) throws -> Bool in
                        return result["ident"] as! String == part["ident"] as! String
                    }
                    if let index = index ?? nil {
                        newResults[index] = part
                    } else {
                        newResults.append(part)
                    }
                }
            }
            self.octApp.endingRequest()
            dispatch_async(dispatch_get_main_queue()) {
                self.search.searchResults = newResults
            }
        }
        octApp.startingRequest()
        task.resume()
    }

    func selectedItem() -> OctItem {
        return (outline.itemAtRow(outline.selectedRow) as! OctTreeNode).item
    }
}

class OctOutlineView : NSOutlineView {
    @IBAction func delete(_: AnyObject) {
        let nodes = selectedRowIndexes.map { (index: Int) -> OctTreeNode in
            itemAtRow(index) as! OctTreeNode
        }
        beginUpdates()
        for node in nodes {
            node.removeFromParent()
            node.deleteIfOrphaned()
        }
        endUpdates()
        (dataSource() as? OctTree)?.reloadTree()
    }

    override func validateUserInterfaceItem(item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action() == #selector(OctOutlineView.delete(_:)) {
            return selectedRowIndexes.count > 0
        }
        return super.validateUserInterfaceItem(item)
    }
}
