//
//  OctDetails.swift
//  Octarine
//
//  Created by Matthias Neeracher on 18/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

class OctDetails : NSObject {
    @IBOutlet weak var searchController : NSArrayController!
    @IBOutlet weak var octApp : OctApp!

    dynamic var detailSpecs = [[String: String]]()
    dynamic var componentSelection = IndexSet() {
        didSet {
            if componentSelection.count == 1 {
                let item = (searchController.arrangedObjects as! [[String: AnyObject]])[componentSelection.first!]
                var urlComponents = URLComponents(string: "https://octopart.com/api/v3/parts/"+(item["ident"] as! String))!
                urlComponents.queryItems = [
                    URLQueryItem(name: "apikey", value: OCTOPART_API_KEY),
                    URLQueryItem(name: "include[]", value: "specs"),
                ]
                let task = OctarineSession.dataTask(with: urlComponents.url!, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
                    guard let data = data else { return }
                    let response = try? JSONSerialization.jsonObject(with: data, options: [])
                    var specMap = [[String:String]]()
                    if let resp  = response as? [String: AnyObject],
                        let specs = resp["specs"] as? [String: AnyObject]
                    {
                        for (_, value) in specs {
                            if let metadata = value["metadata"] as? [String: AnyObject],
                                let name     = metadata["name"] as? String,
                                let value    = value["display_value"] as? String
                            {
                                specMap.append(["name": name, "value":value])
                            }
                        }
                    }
                    self.octApp.endingRequest()
                    DispatchQueue.main.async(execute: {
                        self.detailSpecs = specMap
                    })
                }) 
                octApp.startingRequest()
                task.resume()
            } else {
                DispatchQueue.main.async(execute: {
                    self.detailSpecs = [[String:String]]()
                })
            }
        }
    }
}
