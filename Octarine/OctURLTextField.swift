//
//  OctURLTextView.swift
//  Octarine
//
//  Created by Matthias Neeracher on 30/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

class OctURLTextField : NSTextField {
    @IBOutlet weak var customPart : OctCustomPart!
    
    override func awakeFromNib() {
        registerForDraggedTypes(["public.url"])
    }

    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.Copy
    }

    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard().readObjectsForClasses([NSURL.self], options: nil) as? [NSURL] {
            let url = urls[0].filePathURL ?? urls[0]
            customPart.path = url.absoluteString
            selectText(self)

            return true;
        } 
        return false
    }
}
