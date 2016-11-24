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
        resultTable.setDraggingSourceOperationMask(.copy, forLocal: true)
        resultTable.setDraggingSourceOperationMask(.copy, forLocal: false)
    }

    dynamic var searchResults = [[String: Any]]() {
        didSet {
            if searchResults.count == 1 {
                resultTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                updateDataSheets()
            }
        }
    }

    func focusSearchResults() {
        self.octApp.window.makeFirstResponder(resultTable)
    }
    
    class func partFromJSON(_ item: [String: Any]) -> [String: Any] {
        let manu = item["manufacturer"] as! [String: Any]

        var datasheets = [String]()
        if let ds = item["datasheets"] as? [[String: Any]] {
            for sheet in ds {
                if let url = sheet["url"] as? String {
                    datasheets.append(url)
                }
            }
        }

        let newItem : [String: Any] = [
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

    var partFromUIDCache = [String: [String: Any]]()
    var cacheExpiry = Date(timeIntervalSinceNow: 86400)

    func partsFromCachedUIDs(_ uids: [String], completion:([[String: Any]]) -> Void) {
        var results = [[String: Any]]()
        for uid in uids {
            if let cached = partFromUIDCache[uid] {
                results.append(cached)
            }
        }
        completion(results)
    }

    func partsFromUIDs(_ uids: [String], completion:@escaping ([[String: Any]]) -> Void) {
        let now = Date()
        if now.compare(cacheExpiry) == .orderedDescending {
            // Flush cache to comply with Octopart terms of use
            partFromUIDCache = [:]
            cacheExpiry = Date(timeIntervalSinceNow: 86400)
        }
        let uidsToFetch = uids.filter { (uid: String) -> Bool in
            return partFromUIDCache.index(forKey: uid) == nil
        }

        guard uidsToFetch.count > 0 else {
            partsFromCachedUIDs(uids, completion: completion)
            return
        }

        var urlComponents = URLComponents(string: "https://octopart.com/api/v3/parts/get_multi")!
        let queryItems = [
            URLQueryItem(name: "apikey", value: OCTOPART_API_KEY),
            URLQueryItem(name: "include[]", value: "datasheets"),
            URLQueryItem(name: "include[]", value: "short_description"),
            ] + uidsToFetch.map() { (uid: String) -> URLQueryItem in
                URLQueryItem(name: "uid[]", value: uid)
        }
        urlComponents.queryItems = queryItems

        let task = OctarineSession.dataTask(with: urlComponents.url!, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
            let response = try? JSONSerialization.jsonObject(with: data!, options: [])
            if let results = response as? [String: Any], results["class"] == nil {
                for (_,result) in results {
                    if let json = result as? [String: Any] {
                        var part    = OctSearch.partFromJSON(json)
                        self.partFromUIDCache[part["ident"] as! String] = part
                    }
                }
            }
            self.octApp.endingRequest()
            self.partsFromCachedUIDs(uids, completion: completion)
        }) 
        octApp.startingRequest()
        task.resume()
    }

    @IBAction func searchComponents(_ sender: NSSearchField!) {
        var urlComponents = URLComponents(string: "https://octopart.com/api/v3/parts/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "apikey", value: OCTOPART_API_KEY),
            URLQueryItem(name: "q", value: sender.stringValue),
            URLQueryItem(name: "include[]", value: "datasheets"),
            URLQueryItem(name: "include[]", value: "short_description"),
            URLQueryItem(name: "limit", value: "100")
        ]

        let task = OctarineSession.dataTask(with: urlComponents.url!, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
            guard let data = data else { return }
            let response = try? JSONSerialization.jsonObject(with: data, options: [])
            var newResults = [[String: Any]]()
            if let response = response as? [String: Any],
               let results  = response["results"] as? [[String: Any]]
            {
                for result in results {
                    if let item = result["item"] as? [String: Any] {
                        newResults.append(OctSearch.partFromJSON(item))
                    }
                }
            }
            self.octApp.endingRequest()
            DispatchQueue.main.async(execute: {
                self.focusSearchResults()
                self.searchResults = newResults
            })
        }) 
        octApp.startingRequest()
        task.resume()
    }

    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        let serialized = rowIndexes.map({ (index: Int) -> [String : Any] in
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

    func tableViewSelectionDidChange(_: Notification) {
        updateDataSheets()
    }
}
