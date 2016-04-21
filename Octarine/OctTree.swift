//
//  OctTree.swift
//  Octarine
//
//  Created by Matthias Neeracher on 20/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

let kOctPasteboardType = "OctPasteboardType"

class OctTree : NSObject, NSOutlineViewDataSource {
    @IBOutlet weak var outline : NSOutlineView!

    override func awakeFromNib() {
        outline.registerForDraggedTypes([kOctPasteboardType])
        outline.setDraggingSourceOperationMask([.Move, .Copy], forLocal: true)
        outline.setDraggingSourceOperationMask(.None, forLocal: false)
    }

    var draggedNodes : [NSTreeNode] = []
    var draggedItems : [OctItem]    = []
    func outlineView(outlineView: NSOutlineView, writeItems items: [AnyObject], toPasteboard pboard: NSPasteboard) -> Bool {
        draggedNodes = items as! [NSTreeNode]
        draggedItems = draggedNodes.map { (node: NSTreeNode) -> OctItem in
            node.representedObject as! OctItem
        }
        let serialized = draggedItems.map { (item: OctItem) -> [String: AnyObject] in
            item.serialized()
        }
        pboard.declareTypes([kOctPasteboardType], owner: self)
        pboard.setPropertyList(serialized, forType: kOctPasteboardType)

        return true
    }

    func itemIsDescendentOfDrag(outlineView: NSOutlineView, item: OctItem) -> Bool {
        if draggedItems.contains(item) {
            return true
        } else {
            for parent in item.parents {
                if itemIsDescendentOfDrag(outlineView, item: parent as! OctItem) {
                    return true
                }
            }
            return false
        }
    }

    func outlineView(outlineView: NSOutlineView, validateDrop info: NSDraggingInfo,
                     proposedItem item: AnyObject?, proposedChildIndex index: Int) -> NSDragOperation
    {
        guard info.draggingPasteboard().availableTypeFromArray([kOctPasteboardType]) != nil else {
            return NSDragOperation.None // Only allow reordering drags
        }
        guard let draggingSource = info.draggingSource() as? NSOutlineView
            where draggingSource == outlineView else
        {
            return NSDragOperation.Generic // Drags from outside the outline always OK
        }
        guard let octItem = item?.representedObject as? OctItem else {
            return NSDragOperation.Generic // Drags into root always OK
        }
        if octItem.isPart {
            return NSDragOperation.None     // Don't allow dragging on a part
        } else if itemIsDescendentOfDrag(outlineView, item: octItem) {
            return NSDragOperation.None     // Don't allow drag on dragged items or their descendents
        } else {
            return NSDragOperation.Generic // Otherwise we're good
        }
    }

    func outlineView(outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo,
                     item: AnyObject?, childIndex: Int) -> Bool
    {
        outlineView.beginUpdates()
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
        let octItem = item?.representedObject as? OctItem
        var insertAtIndex = childIndex
        if octItem != nil && insertAtIndex == NSOutlineViewDropOnItemIndex {
            insertAtIndex = octItem?.children?.count ?? 0
        }
        //
        // If this is a move, remove from previous parent, if any
        //
        if info.draggingSourceOperationMask().contains(.Move) {
            for (index, item) in draggedItems.enumerate() {
                if let parent = draggedNodes[index].parentNode?.representedObject {
                    item.mutableSetValueForKey("parents").removeObject(parent)
                }
            }
        }
        if let octItem = octItem {
            for item in draggedItems {
                let kids = octItem.mutableOrderedSetValueForKey("children")
                kids.insertObject(item, atIndex: insertAtIndex)
                insertAtIndex += 1
            }
        }
        outlineView.endUpdates()

        return true
    }

}
