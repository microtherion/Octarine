//
//  OctSearch.swift
//  Octarine
//
//  Created by Matthias Neeracher on 18/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

class OctSearch : NSObject, NSTableViewDataSource {
    @IBOutlet weak var resultTable : NSTableView!

    override func awakeFromNib() {
        resultTable.setDraggingSourceOperationMask(.Copy, forLocal: true)
        resultTable.setDraggingSourceOperationMask(.Copy, forLocal: false)
    }

    dynamic var searchResults = [[String: AnyObject]]()

    @IBAction func searchComponents(sender: NSSearchField!) {
        let urlComponents = NSURLComponents(string: "https://octopart.com/api/v3/parts/search")!
        urlComponents.queryItems = [
            NSURLQueryItem(name: "apikey", value: OCTOPART_API_KEY),
            NSURLQueryItem(name: "q", value: sender.stringValue),
            NSURLQueryItem(name: "include[]", value: "datasheets"),
            NSURLQueryItem(name: "limit", value: "100")
        ]

        let task = OctarineSession.dataTaskWithURL(urlComponents.URL!) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            let response = try? NSJSONSerialization.JSONObjectWithData(data!, options: [])
            var newResults = [[String: AnyObject]]()
            if response != nil {
                let results    = response!["results"] as! [[String: AnyObject]]
                for result in results {
                    let item = result["item"] as! [String: AnyObject]
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
                        "uid":  stringRep(item["uid"]),
                        "part": stringRep(item["mpn"]),
                        "manu": stringRep(manu["name"]),
                        "desc": stringRep(result["snippet"]),
                        "murl": stringRep(manu["homepage_url"]),
                        "purl": stringRep(item["octopart_url"]),
                        "sheets": datasheets
                    ]
                    newResults.append(newItem)
                }
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.searchResults = newResults
            })
        }
        task.resume()
    }

    func tableView(tableView: NSTableView, writeRowsWithIndexes rowIndexes: NSIndexSet, toPasteboard pboard: NSPasteboard) -> Bool {
        let serialized = rowIndexes.map({ (index: Int) -> [String : AnyObject] in
            let part = searchResults[index]
            return ["is_part": true, "ident": part["uid"]!, "name": part["part"]!, "desc": part["desc"]!]
        })
        let urls = rowIndexes.map({ (index: Int) -> NSPasteboardItem in
            let part = searchResults[index]
            let pbitem = NSPasteboardItem()
            pbitem.setString(part["purl"] as? String, forType: "public.url")
            pbitem.setString(part["part"] as? String, forType: "public.url-name")
            return pbitem
        })
        pboard.declareTypes([kOctPasteboardType], owner: self)
        pboard.setPropertyList(serialized, forType: kOctPasteboardType)
        pboard.writeObjects(urls)

        return true
    }
}
