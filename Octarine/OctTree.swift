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

    class func numberOfRootItems() -> Int {
        if gOctTreeRoots.count == 0 {
            // Lazy initialization
            if let roots = OctItem.rootFolder().children {
                for index in 0..<roots.count {
                    gOctTreeRoots.append(OctTreeNode(parent: nil, index: index))
                }
                print("Roots", gOctTreeRoots)
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
}

class OctTree : NSObject, NSOutlineViewDataSource {
    @IBOutlet weak var outline : NSOutlineView!

    override func awakeFromNib() {
        outline.registerForDraggedTypes([kOctPasteboardType])
        outline.setDraggingSourceOperationMask([.Move, .Copy], forLocal: true)
        outline.setDraggingSourceOperationMask(.None, forLocal: false)
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
            return .None // Only allow reordering drags
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

        outlineView.beginUpdates()
        //
        // If this is a move, remove from previous parent, if any
        //
        if info.draggingSourceOperationMask().contains(.Move) {
            for node in draggedNodes {
                let path   = node.path
                let parent = node.parentItem
                let index  = path.indexAtPosition(path.length-1)
                if parent == newParent && index < insertAtIndex {
                    insertAtIndex -= 1
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
        gOctTreeRoots = []
        outlineView.reloadData()

        return true
    }
}
