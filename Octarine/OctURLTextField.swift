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
        register(forDraggedTypes: ["public.url"])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard().readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            stringValue = urls[0].standardizedFileURL.absoluteString

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
