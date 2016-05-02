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
