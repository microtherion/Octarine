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

    @IBAction func importBOM(_: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles            = true
        openPanel.canChooseDirectories      = false
        openPanel.allowsMultipleSelection   = false
        openPanel.allowedFileTypes          = [kUTTypeText as String]
        openPanel.beginSheetModalForWindow(NSApp.mainWindow!) { (response: Int) in
            if response == NSFileHandlingPanelOKButton {
                if let bom = try? String(contentsOfURL: openPanel.URL!, usedEncoding: nil) {
                    // Sniff separators
                    let delimSet = NSCharacterSet(charactersInString: "\t,;")
                    var tabCount    = 0
                    var commaCount  = 0
                    var semiCount   = 0
                    var range = bom.startIndex..<bom.endIndex
                    while let found = bom.rangeOfCharacterFromSet(delimSet, options: [], range: range) {
                        if bom[found] == "\t" {
                            tabCount += 1
                        } else if bom[found] == "," {
                            commaCount += 1
                        } else {
                            semiCount += 1
                        }
                        range = found.endIndex..<range.endIndex
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
                    let parser = CHCSVParser(delimitedString: bom, delimiter: delim)
                    parser.sanitizesFields = true
                    parser.delegate = self
                    parser.parse()
                }
            }
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

        let queryData = try! NSJSONSerialization.dataWithJSONObject(queries, options: [])
        let queryStr  = String(data: queryData, encoding: NSUTF8StringEncoding)!
        let urlComponents = NSURLComponents(string: "https://octopart.com/api/v3/parts/match")!
        urlComponents.queryItems = [
            NSURLQueryItem(name: "apikey", value: OCTOPART_API_KEY),
            NSURLQueryItem(name: "include[]", value: "datasheets"),
            NSURLQueryItem(name: "include[]", value: "short_description"),
            NSURLQueryItem(name: "limit", value: "100"),
            NSURLQueryItem(name: "queries", value: queryStr),
        ]

        let task = OctarineSession.dataTaskWithURL(urlComponents.URL!) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            let response = try? NSJSONSerialization.JSONObjectWithData(data!, options: [])
            var newResults = [[String: AnyObject]]()
            if response != nil, let results = response!["results"] as? [[String: AnyObject]] {
                for result in results {
                    for item in result["items"] as! [[String: AnyObject]] {
                        newResults.append(OctSearch.partFromJSON(item))
                    }
                }
            }
            self.octApp.endingRequest()
            dispatch_async(dispatch_get_main_queue(), {
                self.search.searchResults += newResults
                self.querySKUs()
            })
        }
        octApp.startingRequest()
        task.resume()
    }

    func parserDidEndDocument(_: CHCSVParser!) {
        dispatch_async(dispatch_get_main_queue(), {
            self.search.searchResults = []
        })
        firstSKUInquiry = 0
        querySKUs()
    }

    var parsingHeader = false
    func parser(_: CHCSVParser!, didBeginLine recordNumber: UInt) {
        parsingHeader = recordNumber == 1
    }

    func parser(_: CHCSVParser!, didReadField field: String!, atIndex fieldIndex: Int) {
        if parsingHeader {
            if field.rangeOfString("Mouser") != nil {
                skuFieldIndex = fieldIndex // Mouser BOM
            } else if skuFieldIndex < 0 {  // Pick the first of these
                if field.rangeOfString("Part Number") != nil    // Digikey BOM
                    || field.rangeOfString("partname") != nil   // KiCad BOM
                    || field.rangeOfString("Value") != nil      // Eagle
                {
                    skuFieldIndex = fieldIndex
                }
            }
        } else if fieldIndex == skuFieldIndex {
            if skus.indexOf(field) == nil {
                skus.append(field)
            }
        }
    }

    func parser(parser: CHCSVParser!, didFailWithError error: NSError!) {
        print(error)
    }
}