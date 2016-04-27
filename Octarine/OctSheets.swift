//
//  OctSheets.swift
//  Octarine
//
//  Created by Matthias Neeracher on 18/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit
import Quartz

extension PDFDocument {
    func establishTitle(url: NSURL) {
        var attr = documentAttributes()
        guard nil == attr[PDFDocumentTitleAttribute] as? String else { return }
        let outline = outlineRoot()
        if let outlineTitle = outline?.childAtIndex(0)?.label() {
            attr[PDFDocumentTitleAttribute] = outlineTitle
        } else {
            attr[PDFDocumentTitleAttribute] = url.URLByDeletingPathExtension?.lastPathComponent
        }
        setDocumentAttributes(attr)
    }

    func title() -> String! {
        return documentAttributes()[PDFDocumentTitleAttribute] as! String
    }

    func desc() -> String {
        return "\(title()) [\(pageCount()) pages]"
    }
}

class OctSheets : NSObject, NSOutlineViewDataSource, NSSearchFieldDelegate, NSSharingServicePickerDelegate {
    @IBOutlet weak var sheetView : PDFView!
    @IBOutlet weak var sheetStack : NSStackView!
    @IBOutlet weak var thumbnailView : PDFThumbnailView!
    @IBOutlet weak var outlineScroller : NSScrollView!
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var octApp : OctApp!
    @IBOutlet weak var sharingButton: NSButton!
    @IBOutlet weak var sheetSelection: NSPopUpButton!

    var sheetOutline : PDFOutline! = nil
    var pageChangedObserver : AnyObject?

    override func awakeFromNib() {
        sharingButton.sendActionOn(Int(NSEventMask.LeftMouseDownMask.rawValue))
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

    dynamic var hideSelectionMenu : Bool = true
    dynamic var dataSheets        = [String]() { didSet { loadDataSheets() } }
    dynamic var dataSheetDocs     = [PDFDocument]()

    var dataSheetTasks            = [NSURLSessionTask]()
    func loadDataSheets() {
        dataSheetDocs       = []
        dataSheetSelection  = 0
        hideSelectionMenu   = true
        octApp.startingRequest()
        for sheet in dataSheets {
            if let url = NSURL(string: sheet) {
                var task : NSURLSessionTask? = nil
                task = OctarineSession.dataTaskWithURL(url) { (data: NSData?, _: NSURLResponse?, error: NSError?) in
                    let doc = PDFDocument(data: data)
                    doc.establishTitle(url)
                    dispatch_async(dispatch_get_main_queue()) {
                        self.dataSheetDocs.append(doc)
                        self.hideSelectionMenu = self.dataSheetDocs.count < 2
                        self.dataSheetTasks = self.dataSheetTasks.filter({ $0 != task })
                        if self.dataSheetTasks.count == 0 {
                            self.octApp.endingRequest()
                            self.dataSheetSelection  = 0
                        }
                    }
                }
                dataSheetTasks.append(task!)
                task!.resume()
            }
        }
    }

    dynamic var dataSheetSelection = 0 {
        didSet {
            dispatch_async(dispatch_get_main_queue(), {
                guard !self.dataSheetDocs.isEmpty else { return }
                let doc = self.dataSheetDocs[self.dataSheetSelection]

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

    @IBAction func sheetShareMenu(_: AnyObject) {
        var items = [AnyObject]()
        if let doc = sheetView.document() {
            let docURL = dataSheetDocs[dataSheetSelection].documentURL()
            let tempURL = OctTemp.url.URLByAppendingPathComponent(docURL.lastPathComponent!)
            doc.dataRepresentation().writeToURL(tempURL, atomically: true)
            items.append(docURL)
            items.append(tempURL)
        }
        let servicePicker = NSSharingServicePicker(items:items)
        servicePicker.delegate    = self

        servicePicker.showRelativeToRect(sharingButton.bounds, ofView: sharingButton, preferredEdge: NSRectEdge.MinY)
    }

    func sharingServicePicker(sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [AnyObject], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        var services = proposedServices
        // Also bridge to URL-only services
        let urlOnly  = [items[0]]
        for extraService in NSSharingService.sharingServicesForItems(urlOnly)
            where !proposedServices.contains(extraService)
        {
            services.append(NSSharingService(title: extraService.title,
                image: extraService.image, alternateImage: extraService.alternateImage, handler: {
                    extraService.performWithItems(urlOnly)
            }))
        }
        let workspace = NSWorkspace.sharedWorkspace()
        if let pdfAppURL = workspace.URLForApplicationToOpenURL(items[1] as! NSURL) {
            let icon = workspace.iconForFile(pdfAppURL.path!)
            services.append(NSSharingService(title: (pdfAppURL.URLByDeletingPathExtension?.lastPathComponent)!,
                image: icon, alternateImage:  nil, handler: {
                workspace.openURL(items[1] as! NSURL)
            }))
        }

        return services
    }
}
