//
//  OctSheets.swift
//  Octarine
//
//  Created by Matthias Neeracher on 18/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit
import Quartz

class OctSheets : NSObject {
    @IBOutlet weak var sheetView : PDFView!
    @IBOutlet weak var thumbnailView : PDFThumbnailView!
    @IBOutlet weak var octApp : OctApp!

    dynamic var dataSheets = [String]()
    dynamic var dataSheetSelection = NSIndexSet() {
        didSet {
            if dataSheetSelection.count == 1 {
                if let url = NSURL(string: dataSheets[dataSheetSelection.firstIndex]) {
                    let task = OctarineSession.dataTaskWithURL(url) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                        dispatch_async(dispatch_get_main_queue(), {
                            let doc = PDFDocument(data: data)
                            self.octApp.endingRequest()
                            self.sheetView.setDocument(doc)
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), {
                                self.thumbnailView.setPDFView(self.sheetView)
                            });
                        })
                    }
                    octApp.startingRequest()
                    task.resume()
                }
            }
        }
    }

}
