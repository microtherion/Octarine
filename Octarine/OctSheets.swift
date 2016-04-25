//
//  OctSheets.swift
//  Octarine
//
//  Created by Matthias Neeracher on 18/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit
import Quartz

class OctSheets : NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    @IBOutlet weak var sheetView : PDFView!
    @IBOutlet weak var sheetStack : NSStackView!
    @IBOutlet weak var thumbnailView : PDFThumbnailView!
    @IBOutlet weak var outlineScroller : NSScrollView!
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var octApp : OctApp!

    var pageChangedObserver : AnyObject?

    override func awakeFromNib() {
        self.sheetStack.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible,
                                              forView: self.thumbnailView)
        pageChangedObserver = NSNotificationCenter.defaultCenter().addObserverForName(PDFViewPageChangedNotification, object: sheetView, queue: nil) { _ in
            self.pageChanged()
        }
    }

    deinit {
        if let pageChangedObserver = pageChangedObserver {
            NSNotificationCenter.defaultCenter().removeObserver(pageChangedObserver)
        }
    }

    dynamic var sheetOutline : PDFOutline! = nil
    dynamic var dataSheets = [String]()
    dynamic var dataSheetSelection = NSIndexSet() {
        didSet {
            if dataSheetSelection.count == 1 {
                if let url = NSURL(string: dataSheets[dataSheetSelection.firstIndex]) {
                    let task = OctarineSession.dataTaskWithURL(url) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                        dispatch_async(dispatch_get_main_queue(), {
                            let doc = PDFDocument(data: data)
                            self.octApp.endingRequest()
                            self.sheetOutline    = nil
                            self.sheetView.setDocument(doc)
                            self.sheetOutline    = doc.outlineRoot()
                            if self.sheetOutline != nil {
                                // We want the outline to be non-trivial. Just a title won't do
                                if self.sheetOutline.numberOfChildren() == 0 {
                                    self.sheetOutline = nil
                                }
                            }
                            if self.sheetOutline != nil {
                                self.sheetStack.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible,
                                    forView: self.thumbnailView)
                                self.sheetStack.setVisibilityPriority(NSStackViewVisibilityPriorityMustHold,
                                    forView: self.outlineScroller)
                                self.outlineView.reloadData()
                            } else {
                                self.sheetStack.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible,
                                    forView: self.outlineScroller)
                                self.sheetStack.setVisibilityPriority(NSStackViewVisibilityPriorityMustHold,
                                    forView: self.thumbnailView)
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), {
                                    self.thumbnailView.setPDFView(self.sheetView)
                                });
                            }
                        })
                    }
                    octApp.startingRequest()
                    task.resume()
                }
            }
        }
    }

    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        if sheetOutline == nil {
            return false
        } else if let outlineItem = item as? PDFOutline {
            return outlineItem.numberOfChildren() > 0
        } else {
            return true
        }
    }

    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if sheetOutline == nil {
            return 0
        } else if let outlineItem = item as? PDFOutline {
            return outlineItem.numberOfChildren()
        } else {
            return sheetOutline.numberOfChildren()
        }
    }

    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if sheetOutline == nil {
            return ""
        } else if let outlineItem = item as? PDFOutline {
            return outlineItem.childAtIndex(index)
        } else {
            return sheetOutline.childAtIndex(index)
        }
    }

    func outlineView(outlineView: NSOutlineView, objectValueForTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject? {
        if sheetOutline == nil {
            return ""
        } else if let outlineItem = item as? PDFOutline {
            return outlineItem.label()
        } else {
            return sheetOutline.label()
        }
    }

    @IBAction func takeDestinationFromOutline(_: AnyObject) {
        let outlineItem = outlineView.itemAtRow(outlineView.selectedRow) as! PDFOutline
        sheetView.goToDestination(outlineItem.destination())
    }

    func pageChanged() {
        guard sheetOutline != nil else { return }

        let doc         = sheetView.document()
        let pageIndex   = doc.indexForPage(sheetView.currentPage())
        var closestRow  = -1

        for row in 0..<outlineView.numberOfRows {
            guard let outlineItem = outlineView.itemAtRow(row) as? PDFOutline else { continue }

            let outlinePage = doc.indexForPage(outlineItem.destination().page())
            if outlinePage == pageIndex {
                closestRow = row
                break
            } else if outlinePage > pageIndex {
                closestRow = row>0 ? row-1 : 0
                break
            } else {
                closestRow = row
            }
        }

        if closestRow > -1 {
            outlineView.selectRowIndexes(NSIndexSet(index:closestRow), byExtendingSelection: false)
            outlineView.scrollRowToVisible(closestRow)
        }
    }
}
