//
//  OctURLTextView.swift
//  Octarine
//
//  Created by Matthias Neeracher on 30/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

class OctURLTextField : NSTextField {
    override func awakeFromNib() {
        registerForDraggedTypes(["public.url"])
    }

    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.Copy
    }

    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard().readObjectsForClasses([NSURL.self], options: nil) as? [NSURL] {
            let url = urls[0].filePathURL ?? urls[0]
            stringValue = url.absoluteString

            if let bind = infoForBinding("value") {
                let boundObj    = bind[NSObservedObjectKey] as! NSObject
                let boundPath   = bind[NSObservedKeyPathKey] as! String

                boundObj.setValue(stringValue, forKeyPath: boundPath)
            }
            selectText(self)

            return true;
        } 
        return false
    }
}
