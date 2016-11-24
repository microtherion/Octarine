//
//  OctBOM.swift
//  Octarine
//
//  Created by Matthias Neeracher on 05/05/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

class OctBOM : NSObject, CHCSVParserDelegate {
    @IBOutlet weak var octApp: OctApp!
    @IBOutlet weak var search: OctSearch!
    @IBOutlet weak var octTree: OctTree!

    @IBAction func importBOM(_: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles            = true
        openPanel.canChooseDirectories      = false
        openPanel.allowsMultipleSelection   = false
        openPanel.allowedFileTypes          = [kUTTypeText as String]
        openPanel.beginSheetModal(for: NSApp.mainWindow!) { (response: Int) in
            if response == NSFileHandlingPanelOKButton {
                var enc = String.Encoding.utf8
                if let bom = try? String(contentsOf: openPanel.url!, usedEncoding: &enc) {
                    // Sniff separators
                    let delimSet = CharacterSet(charactersIn: "\t,;")
                    var tabCount    = 0
                    var commaCount  = 0
                    var semiCount   = 0
                    var range = bom.startIndex..<bom.endIndex
                    while let found = bom.rangeOfCharacter(from: delimSet, options: []) {
                        if bom[found] == "\t" {
                            tabCount += 1
                        } else if bom[found] == "," {
                            commaCount += 1
                        } else {
                            semiCount += 1
                        }
                        range = found.upperBound..<range.upperBound
                    }
                    let delim : unichar
                    if tabCount >= commaCount {
                        if tabCount >= semiCount {
                            delim   = unichar(UnicodeScalar("\t").value)
                        } else {
                            delim   = unichar(UnicodeScalar(";").value)
                        }
                    } else if commaCount >= semiCount {
                        delim       = unichar(UnicodeScalar(",").value)
                    } else {
                        delim       = unichar(UnicodeScalar(";").value)
                    }
                    if let parser = CHCSVParser(delimitedString: bom, delimiter: delim) {
                        parser.sanitizesFields = true
                        parser.delegate = self
                        parser.parse()
                    }
                }
            }
        }
    }

    @IBAction func exportBOM(_: AnyObject) {
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["csv"]
        savePanel.beginSheetModal(for: NSApp.mainWindow!) { (response: Int) in
            if response == NSFileHandlingPanelOKButton {
                var items       = [OctItem]()
                var uids        = [String]()
                var selection   = self.octTree.selectedItems()

                // Flatten selection
                while selection.count > 0 {
                    let item = selection.removeFirst()
                    if item.isPart && items.index(of: item) == nil {
                        items.append(item)
                        if !item.isCustomPart {
                            uids.append(item.ident)
                        }
                    } else if let kids = item.children?.array as? [OctItem] {
                        selection += kids
                    }
                }

                self.search.partsFromUIDs(uids, completion: { (_: [[String : Any]]) in
                    self.writeBOM(savePanel.url!.path, items: items)
                })
            }
        }
    }

    func writeBOM(_ path: String, items: [OctItem]) {
        guard let writer = CHCSVWriter(forWritingToCSVFile: path) else { return }
        let fields : NSArray = ["Part Number", "Manufacturer", "Description"]
        writer.writeLine(ofFields: fields)
        for item in items {
            var part : [String: Any]?
            if item.isCustomPart {
                part = search.partFromUIDCache[item.ident]
            }
            writer.writeField(part?["name"] ?? item.name)
            writer.writeField(part?["manu"] ?? item.manufacturer ?? "")
            writer.writeField(item.desc)
            writer.finishLine()
        }
    }

    var skus = [String]()
    var skuFieldIndex = -1
    func parserDidBeginDocument(_: CHCSVParser!) {
        skus = []
        skuFieldIndex = -1
    }

    var firstSKUInquiry = 0
    func querySKUs() {
        guard firstSKUInquiry < skus.count else { return }

        let range   = firstSKUInquiry..<min(firstSKUInquiry+20, skus.count)
        let queries = skus[range].map { (sku: String) -> [String: String] in
            ["mpn_or_sku": sku]
        }
        firstSKUInquiry += 20

        let queryData = try! JSONSerialization.data(withJSONObject: queries, options: [])
        let queryStr  = String(data: queryData, encoding: String.Encoding.utf8)!
        var urlComponents = URLComponents(string: "https://octopart.com/api/v3/parts/match")!
        urlComponents.queryItems = [
            URLQueryItem(name: "apikey", value: OCTOPART_API_KEY),
            URLQueryItem(name: "include[]", value: "datasheets"),
            URLQueryItem(name: "include[]", value: "short_description"),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "queries", value: queryStr),
        ]

        let task = OctarineSession.dataTask(with: urlComponents.url!, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
            let response = try? JSONSerialization.jsonObject(with: data!, options: [])
            var newResults = [[String: Any]]()
            if let response = response as? [String: Any], let results = response["results"] as? [[String: Any]] {
                for result in results {
                    for item in result["items"] as! [[String: Any]] {
                        newResults.append(OctSearch.partFromJSON(item))
                    }
                }
            }
            self.octApp.endingRequest()
            DispatchQueue.main.async(execute: {
                self.search.searchResults += newResults
                self.querySKUs()
            })
        }) 
        octApp.startingRequest()
        task.resume()
    }

    func parserDidEndDocument(_: CHCSVParser!) {
        DispatchQueue.main.async(execute: {
            self.search.focusSearchResults()
            self.search.searchResults = []
        })
        firstSKUInquiry = 0
        querySKUs()
    }

    var parsingHeader = false
    func parser(_: CHCSVParser!, didBeginLine recordNumber: UInt) {
        parsingHeader = recordNumber == 1
    }

    func parser(_: CHCSVParser!, didReadField field: String!, at fieldIndex: Int) {
        if parsingHeader {
            if field.range(of: "Mouser") != nil {
                skuFieldIndex = fieldIndex // Mouser BOM
            } else if skuFieldIndex < 0 {  // Pick the first of these
                if field.range(of: "Part Number") != nil    // Digikey BOM
                    || field.range(of: "partname") != nil   // KiCad BOM
                    || field.range(of: "Value") != nil      // Eagle
                {
                    skuFieldIndex = fieldIndex
                }
            }
        } else if fieldIndex == skuFieldIndex {
            if skus.index(of: field) == nil {
                skus.append(field)
            }
        }
    }

    func parser(_ parser: CHCSVParser!, didFailWithError error: Error!) {
        print(error)
    }
}
