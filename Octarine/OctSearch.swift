//
//  OctSearch.swift
//  Octarine
//
//  Created by Matthias Neeracher on 18/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

class OctSearch : NSObject, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var resultTable : NSTableView!
    @IBOutlet weak var octApp : OctApp!
    @IBOutlet weak var sheets: OctSheets!

    override func awakeFromNib() {
        resultTable.setDraggingSourceOperationMask(.Copy, forLocal: true)
        resultTable.setDraggingSourceOperationMask(.Copy, forLocal: false)
    }

    dynamic var searchResults = [[String: AnyObject]]() {
        didSet {
            if searchResults.count == 1 {
                resultTable.selectRowIndexes(NSIndexSet(index: 0), byExtendingSelection: false)
                updateDataSheets()
            }
        }
    }

    func focusSearchResults() {
        self.octApp.window.makeFirstResponder(resultTable)
    }
    
    class func partFromJSON(item: AnyObject?) -> [String: AnyObject] {
        let item = item as! [String: AnyObject]
        let manu = item["manufacturer"] as! [String: AnyObject]

        var datasheets = [String]()
        if let ds = item["datasheets"] as? [[String: AnyObject]] {
            for sheet in ds {
                if let url = sheet["url"] as? String {
                    datasheets.append(url)
                }
            }
        }

        let newItem : [String: AnyObject] = [
            "ident":    stringRep(item["uid"]),
            "name":     stringRep(item["mpn"]),
            "manu":     stringRep(manu["name"]),
            "desc":     stringRep(item["short_description"]),
            "murl":     stringRep(manu["homepage_url"]),
            "purl":     stringRep(item["octopart_url"]),
            "sheets":   datasheets
        ]

        return newItem
    }

    var partFromUIDCache = [String: [String: AnyObject]]()
    var cacheExpiry = NSDate(timeIntervalSinceNow: 86400)

    func partsFromCachedUIDs(uids: [String], completion:([[String: AnyObject]]) -> Void) {
        var results = [[String: AnyObject]]()
        for uid in uids {
            if let cached = partFromUIDCache[uid] {
                results.append(cached)
            }
        }
        completion(results)
    }

    func partsFromUIDs(uids: [String], completion:([[String: AnyObject]]) -> Void) {
        let now = NSDate()
        if now.compare(cacheExpiry) == .OrderedDescending {
            // Flush cache to comply with Octopart terms of use
            partFromUIDCache = [:]
            cacheExpiry = NSDate(timeIntervalSinceNow: 86400)
        }
        let uidsToFetch = uids.filter { (uid: String) -> Bool in
            return partFromUIDCache.indexForKey(uid) == nil
        }

        guard uidsToFetch.count > 0 else {
            partsFromCachedUIDs(uids, completion: completion)
            return
        }

        let urlComponents = NSURLComponents(string: "https://octopart.com/api/v3/parts/get_multi")!
        let queryItems = [
            NSURLQueryItem(name: "apikey", value: OCTOPART_API_KEY),
            NSURLQueryItem(name: "include[]", value: "datasheets"),
            NSURLQueryItem(name: "include[]", value: "short_description"),
            ] + uidsToFetch.map() { (uid: String) -> NSURLQueryItem in
                NSURLQueryItem(name: "uid[]", value: uid)
        }
        urlComponents.queryItems = queryItems

        let task = OctarineSession.dataTaskWithURL(urlComponents.URL!) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            let response = try? NSJSONSerialization.JSONObjectWithData(data!, options: [])
            if let results = response as? [String: AnyObject] where results["class"] == nil {
                for (_,result) in results {
                    var part    = OctSearch.partFromJSON(result)
                    self.partFromUIDCache[part["ident"] as! String] = part
                }
            }
            self.octApp.endingRequest()
            self.partsFromCachedUIDs(uids, completion: completion)
        }
        octApp.startingRequest()
        task.resume()
    }

    @IBAction func searchComponents(sender: NSSearchField!) {
        let urlComponents = NSURLComponents(string: "https://octopart.com/api/v3/parts/search")!
        urlComponents.queryItems = [
            NSURLQueryItem(name: "apikey", value: OCTOPART_API_KEY),
            NSURLQueryItem(name: "q", value: sender.stringValue),
            NSURLQueryItem(name: "include[]", value: "datasheets"),
            NSURLQueryItem(name: "include[]", value: "short_description"),
            NSURLQueryItem(name: "limit", value: "100")
        ]

        let task = OctarineSession.dataTaskWithURL(urlComponents.URL!) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            let response = try? NSJSONSerialization.JSONObjectWithData(data!, options: [])
            var newResults = [[String: AnyObject]]()
            if response != nil {
                let results    = response!["results"] as! [[String: AnyObject]]
                for result in results {
                    newResults.append(OctSearch.partFromJSON(result["item"]))
                }
            }
            self.octApp.endingRequest()
            dispatch_async(dispatch_get_main_queue(), {
                self.focusSearchResults()
                self.searchResults = newResults
            })
        }
        octApp.startingRequest()
        task.resume()
    }

    func tableView(tableView: NSTableView, writeRowsWithIndexes rowIndexes: NSIndexSet, toPasteboard pboard: NSPasteboard) -> Bool {
        let serialized = rowIndexes.map({ (index: Int) -> [String : AnyObject] in
            let part = searchResults[index]
            return ["is_part": true, "ident": part["ident"]!, "name": part["name"]!, "desc": part["desc"]!]
        })
        let urls = rowIndexes.map({ (index: Int) -> NSPasteboardItem in
            let part = searchResults[index]
            let pbitem = NSPasteboardItem()
            pbitem.setString(part["purl"] as? String, forType: "public.url")
            pbitem.setString(part["name"] as? String, forType: "public.url-name")
            return pbitem
        })
        pboard.declareTypes([kOctPasteboardType], owner: self)
        pboard.setPropertyList(serialized, forType: kOctPasteboardType)
        pboard.writeObjects(urls)

        return true
    }

    func updateDataSheets() {
        if resultTable.selectedRowIndexes.count == 1 {
            let newSheets = searchResults[resultTable.selectedRow]["sheets"] as? [String] ?? []
            sheets.dataSheets = newSheets
            if newSheets.count > 0 {
                sheets.dataSheetSelection = 0
            }
        } else {
            sheets.dataSheets = []
        }
    }

    func tableViewSelectionDidChange(_: NSNotification) {
        updateDataSheets()
    }
}
