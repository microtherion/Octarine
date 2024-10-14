//
//  OctSheets.swift
//  Octarine
//
//  Created by Matthias Neeracher on 18/04/16.
//  Copyright © 2016-2017 Matthias Neeracher. All rights reserved.
//

import AppKit
import Quartz

extension PDFDocument {
    func establishTitle(_ url: URL) {
        var attr = documentAttributes
        guard nil == attr?[PDFDocumentAttribute.titleAttribute] as? String else { return }
        let outline = outlineRoot
        if let outlineTitle = outline?.child(at: 0).label {
            attr?[PDFDocumentAttribute.titleAttribute] = outlineTitle
        } else {
            attr?[PDFDocumentAttribute.titleAttribute] = url.deletingPathExtension().lastPathComponent
        }
        documentAttributes = attr
    }

    func title() -> String! {
        return documentAttributes![PDFDocumentAttribute.titleAttribute] as! String
    }

    func desc() -> String {
        return "\(title()) [\(pageCount) pages]"
    }
}

class OctSheets : NSObject, NSOutlineViewDataSource, NSSearchFieldDelegate, NSSharingServicePickerDelegate, PDFDocumentDelegate {
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
        sharingButton.sendAction(on: NSEvent.EventTypeMask.leftMouseDown)
        self.sheetStack.setVisibilityPriority(NSStackView.VisibilityPriority.notVisible,
                                              for: self.thumbnailView)
        pageChangedObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.PDFViewPageChanged, object: sheetView, queue: nil) { _ in
            self.pageChanged()
        }
    }

    deinit {
        if let pageChangedObserver = pageChangedObserver {
            NotificationCenter.default.removeObserver(pageChangedObserver)
        }
    }

    @objc dynamic var showSidebar : Bool = true { didSet { updateSidebar() } }

    func updateSidebar() {
        if showSidebar && sheetOutline != nil {
            sheetStack.setVisibilityPriority(NSStackView.VisibilityPriority.mustHold, for: outlineScroller)
        } else {
            sheetStack.setVisibilityPriority(NSStackView.VisibilityPriority.notVisible, for: outlineScroller)
        }
        outlineView.reloadData()
        if showSidebar && sheetOutline == nil {
            sheetStack.setVisibilityPriority(NSStackView.VisibilityPriority.mustHold, for: thumbnailView)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {
                self.thumbnailView.pdfView = self.sheetView
            });
        } else {
            sheetStack.setVisibilityPriority(NSStackView.VisibilityPriority.notVisible, for: thumbnailView)
        }
    }

    @objc dynamic var hideSelectionMenu : Bool = true
    @objc dynamic var dataSheets        = [String]() { didSet { loadDataSheets() } }
    @objc dynamic var dataSheetDocs     = [PDFDocument]()
    @objc dynamic var dataSheetURLs     = [URL]()
    var               nextSheetToLoad   = 0


    func loadDataSheets() {
        dataSheetDocs       = []
        dataSheetURLs       = []
        dataSheetSelection  = 0
        hideSelectionMenu   = true
        nextSheetToLoad     = -1
        loadNextSheet()
    }

    func loadNextSheet() {
        nextSheetToLoad += 1
        guard nextSheetToLoad < dataSheets.count else { return }
        if let url = URL(string: dataSheets[nextSheetToLoad]) {
            var task : URLSessionTask? = nil
            task = OctarineSession.dataTask(with: url, completionHandler: { (data: Data?, _: URLResponse?, error: Error?) in
                self.octApp.endingRequest()
                if let data = data, let doc = PDFDocument(data: data) {
                    doc.establishTitle(url)
                    DispatchQueue.main.async {
                        if !self.dataSheetURLs.contains(url) {
                            self.dataSheetDocs.append(doc)
                            self.dataSheetURLs.append(url)
                            self.hideSelectionMenu = self.dataSheetDocs.count < 2
                            if self.dataSheetDocs.count == 1 {
                                self.dataSheetSelection = 0
                            }
                        }
                        self.loadNextSheet()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.loadNextSheet()
                    }
                }
            }) 
            octApp.startingRequest()
            task!.resume()
        } else {
            loadNextSheet()
        }
    }

    @objc dynamic var dataSheetSelection = 0 {
        didSet {
            DispatchQueue.main.async(execute: {
                guard !self.dataSheetDocs.isEmpty else { return }
                let doc = self.dataSheetDocs[self.dataSheetSelection]

                self.sheetOutline   = nil
                self.found          = []
                self.lastFound      = nil

                doc.delegate = self
                self.sheetView.document = doc
                self.sheetOutline    = doc.outlineRoot
                if self.sheetOutline != nil {
                    // We want the outline to be non-trivial. Just a title won't do
                    if self.sheetOutline.numberOfChildren == 0 {
                        self.sheetOutline = nil
                    }
                }
                self.updateSidebar()
            })
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if sheetOutline == nil {
            return false
        } else if let outlineItem = item as? PDFOutline {
            return outlineItem.numberOfChildren > 0
        } else {
            return true
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if sheetOutline == nil {
            return 0
        } else if let outlineItem = item as? PDFOutline {
            return outlineItem.numberOfChildren
        } else {
            return sheetOutline.numberOfChildren
        }
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if sheetOutline == nil {
            return ""
        } else if let outlineItem = item as? PDFOutline {
            return outlineItem.child(at: index)
        } else {
            return sheetOutline.child(at: index)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        if sheetOutline == nil {
            return ""
        } else if let outlineItem = item as? PDFOutline {
            return outlineItem.label
        } else {
            return sheetOutline.label
        }
    }

    @IBAction func takeDestinationFromOutline(_: AnyObject) {
        if let outlineItem = outlineView.item(atRow: outlineView.selectedRow) as? PDFOutline {
            sheetView.go(to: outlineItem.destination!)
        }
    }

    func pageChanged() {
        guard sheetOutline != nil else { return }

        let doc         = sheetView.document
        let pageIndex   = doc?.index(for: sheetView.currentPage!)
        var closestRow  = -1

        for row in 0..<outlineView.numberOfRows {
            guard let outlineItem = outlineView.item(atRow: row) as? PDFOutline else { continue }

            let outlinePage = doc?.index(for: (outlineItem.destination?.page!)!)
            if outlinePage == pageIndex {
                closestRow = row
                break
            } else if outlinePage! > pageIndex! {
                closestRow = row>0 ? row-1 : 0
                break
            } else {
                closestRow = row
            }
        }

        if closestRow > -1 {
            outlineView.selectRowIndexes(IndexSet(integer:closestRow), byExtendingSelection: false)
            outlineView.scrollRowToVisible(closestRow)
        }
    }

    var lastFound : PDFSelection?
    @objc dynamic var found = [PDFSelection]()
    @objc dynamic var findCaseInsensitive : Bool = true { didSet { updateSearch() } }
    @objc dynamic var searchString : String = "" { didSet { updateSearch() } }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.tag == 0 {
            if findCaseInsensitive {
                menuItem.state = .on
            } else {
                menuItem.state = .off
            }
        }
        return true
    }

    @IBAction func toggleCaseInsensitive(_: AnyObject) {
        findCaseInsensitive = !findCaseInsensitive
    }
    
    func updateSearch() {
        guard let doc = sheetView.document else { return }

        if doc.isFinding {
            doc.cancelFindString()
        }
        found       = []
        lastFound   = nil
        sheetView.highlightedSelections = nil

        if searchString.lengthOfBytes(using: String.Encoding.utf8) > 1 {
            if findCaseInsensitive {
                doc.findString(searchString, with: [.caseInsensitive])
            } else {
                doc.findString(searchString, with: [])
            }
        }
    }

    func didMatchString(_ instance: PDFSelection) {
        instance.color = NSColor.yellow
        found.append(instance)
        sheetView.highlightedSelections = found
    }

    @IBAction func findAction(_ sender: AnyObject) {
        switch sender.tag {
        case 2:
            guard found.count > 0 else { break }
            if let last = lastFound, let lastIndex = found.index(of: last), lastIndex+1 < found.count
            {
                lastFound = found[lastIndex+1]
            } else {
                lastFound = found.first
            }
            let selection = lastFound?.copy() as! PDFSelection
            selection.color = nil
            sheetView.setCurrentSelection(selection, animate: true)
            sheetView.scrollSelectionToVisible(self)
        case 3:
            guard found.count > 0 else { break }
            if let last = lastFound, let lastIndex = found.index(of: last), lastIndex > 0
            {
                lastFound = found[lastIndex-1]
            } else {
                lastFound = found.last
            }
            let selection = lastFound?.copy() as! PDFSelection
            selection.color = nil
            sheetView.setCurrentSelection(selection, animate: true)
            sheetView.scrollSelectionToVisible(self)
        case 7:
            if let sel = sheetView.currentSelection {
                searchString = sel.string!
                lastFound = sel
            }
        default: break
        }
    }

    @IBAction func sheetShareMenu(_: AnyObject) {
        var items = [AnyObject]()
        if let doc = sheetView.document {
            let docURL = dataSheetURLs[dataSheetSelection]
            let tempURL = OctTemp.url.appendingPathComponent(docURL.lastPathComponent)
            try? doc.dataRepresentation()?.write(to: tempURL, options: [.atomic])
            items.append(docURL as AnyObject)
            items.append(tempURL as AnyObject)
        }
        let servicePicker = NSSharingServicePicker(items:items)
        servicePicker.delegate    = self

        servicePicker.show(relativeTo: sharingButton.bounds, of: sharingButton, preferredEdge: NSRectEdge.minY)
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        var services = proposedServices
        // Also bridge to URL-only services
        let urlOnly  = [items[0]]
        for extraService in NSSharingService.sharingServices(forItems: urlOnly)
            where !proposedServices.contains(extraService)
        {
            services.append(NSSharingService(title: extraService.title,
                image: extraService.image, alternateImage: extraService.alternateImage, handler: {
                    extraService.perform(withItems: urlOnly)
            }))
        }
        let workspace = NSWorkspace.shared
        if let pdfAppURL = workspace.urlForApplication(toOpen: items[1] as! URL) {
            let icon = workspace.icon(forFile: pdfAppURL.path)
            services.append(NSSharingService(title: (pdfAppURL.deletingPathExtension().lastPathComponent),
                image: icon, alternateImage:  nil, handler: {
                workspace.open(items[1] as! URL)
            }))
        }

        return services
    }
}
