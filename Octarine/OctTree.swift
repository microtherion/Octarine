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
        outline.setDraggingSourceOperationMask(NSDragOperation.Every, forLocal: true)
        outline.setDraggingSourceOperationMask(NSDragOperation.None, forLocal: false)
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

    func outlineView(outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: AnyObject?, proposedChildIndex index: Int) -> NSDragOperation {
        if info.draggingPasteboard().availableTypeFromArray([kOctPasteboardType]) == nil {
            return NSDragOperation.None // Only allow reordering drags
        }
        let octItem = item as? OctItem
        if let octItem = octItem {
            if octItem.isPart {
                return NSDragOperation.None // Don't allow dragging on a part
            } else if itemIsDescendentOfDrag(outlineView, item: octItem) {
                return NSDragOperation.None // Don't allow drag on member of dragged items or a descendent thereof
            }
        }
        return NSDragOperation.Generic
    }

    func outlineView(outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: AnyObject?, childIndex: Int) -> Bool {
        let octItem = item as? OctItem
        var insertAtIndex = childIndex
        if octItem != nil && insertAtIndex == NSOutlineViewDropOnItemIndex {
            insertAtIndex = octItem?.children?.count ?? 0
        }
        outlineView.beginUpdates()
        for item in draggedItems {
        }
        outlineView.endUpdates()

        return true
    }

}
