//
//  OctSheets.swift
//  Octarine
//
//  Created by Matthias Neeracher on 18/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit
import Quartz

class OctSheets : NSObject, NSOutlineViewDataSource, NSSearchFieldDelegate {
    @IBOutlet weak var sheetView : PDFView!
    @IBOutlet weak var sheetStack : NSStackView!
    @IBOutlet weak var thumbnailView : PDFThumbnailView!
    @IBOutlet weak var outlineScroller : NSScrollView!
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var octApp : OctApp!

    var sheetOutline : PDFOutline! = nil
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

    dynamic var showSidebar : Bool = true { didSet { updateSidebar() } }

    func updateSidebar() {
        if showSidebar && sheetOutline != nil {
            sheetStack.setVisibilityPriority(NSStackViewVisibilityPriorityMustHold, forView: outlineScroller)
            outlineView.reloadData()
        } else {
            sheetStack.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible, forView: outlineScroller)
        }
        if showSidebar && sheetOutline == nil {
            sheetStack.setVisibilityPriority(NSStackViewVisibilityPriorityMustHold, forView: thumbnailView)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), {
                self.thumbnailView.setPDFView(self.sheetView)
            });
        } else {
            sheetStack.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible, forView: thumbnailView)
        }
    }

    dynamic var dataSheets = [String]()
    dynamic var dataSheetSelection = NSIndexSet() {
        didSet {
            if dataSheetSelection.count == 1 {
                if let url = NSURL(string: dataSheets[dataSheetSelection.firstIndex]) {
                    let task = OctarineSession.dataTaskWithURL(url) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                        dispatch_async(dispatch_get_main_queue(), {
                            let doc = PDFDocument(data: data)
                            self.octApp.endingRequest()

                            self.sheetOutline   = nil
                            self.found          = []
                            self.lastFound      = nil

                            doc.setDelegate(self)
                            self.sheetView.setDocument(doc)
                            self.sheetOutline    = doc.outlineRoot()
                            if self.sheetOutline != nil {
                                // We want the outline to be non-trivial. Just a title won't do
                                if self.sheetOutline.numberOfChildren() == 0 {
                                    self.sheetOutline = nil
                                }
                            }
                            self.updateSidebar()
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
        if let outlineItem = outlineView.itemAtRow(outlineView.selectedRow) as? PDFOutline {
            sheetView.goToDestination(outlineItem.destination())
        }
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

    var lastFound : PDFSelection?
    dynamic var found = [PDFSelection]()
    dynamic var findCaseInsensitive : Bool = true { didSet { updateSearch() } }
    dynamic var searchString : String = "" { didSet { updateSearch() } }

    override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        if menuItem.tag == 0 {
            if findCaseInsensitive {
                menuItem.state = NSOnState
            } else {
                menuItem.state = NSOffState
            }
        }
        return true
    }

    @IBAction func toggleCaseInsensitive(_: AnyObject) {
        findCaseInsensitive = !findCaseInsensitive
    }
    
    func updateSearch() {
        guard let doc = sheetView.document() else { return }

        if doc.isFinding() {
            doc.cancelFindString()
        }
        found       = []
        lastFound   = nil
        sheetView.setHighlightedSelections(nil)

        if searchString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 1 {
            doc.findString(searchString, withOptions: findCaseInsensitive ? 1 : 0)
        }
    }

    override func didMatchString(instance: PDFSelection!) {
        instance.setColor(NSColor.yellowColor())
        found.append(instance)
        sheetView.setHighlightedSelections(found)
    }

    @IBAction func findAction(sender: AnyObject) {
        switch sender.tag?() ?? 0 {
        case 2:
            guard found.count > 0 else { break }
            if let last = lastFound, let lastIndex = found.indexOf(last)
                where lastIndex+1 < found.count
            {
                lastFound = found[lastIndex+1]
            } else {
                lastFound = found.first
            }
            let selection = lastFound?.copy() as! PDFSelection
            selection.setColor(nil)
            sheetView.setCurrentSelection(selection, animate: true)
            sheetView.scrollSelectionToVisible(self)
        case 3:
            guard found.count > 0 else { break }
            if let last = lastFound, let lastIndex = found.indexOf(last)
                where lastIndex > 0
            {
                lastFound = found[lastIndex-1]
            } else {
                lastFound = found.last
            }
            let selection = lastFound?.copy() as! PDFSelection
            selection.setColor(nil)
            sheetView.setCurrentSelection(selection, animate: true)
            sheetView.scrollSelectionToVisible(self)
        case 7:
            if let sel = sheetView.currentSelection() {
                searchString = sel.string()
                lastFound = sel
            }
        default: break
        }
    }

}
