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
    dynamic var componentSelection = NSIndexSet() {
        didSet {
            if componentSelection.count == 1 {
                let item = (searchController.arrangedObjects as! [[String: AnyObject]])[componentSelection.firstIndex]
                let urlComponents = NSURLComponents(string: "https://octopart.com/api/v3/parts/"+(item["uid"] as! String))!
                urlComponents.queryItems = [
                    NSURLQueryItem(name: "apikey", value: OCTOPART_API_KEY),
                    NSURLQueryItem(name: "include[]", value: "specs"),
                ]
                let task = OctarineSession.dataTaskWithURL(urlComponents.URL!) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                    let response = try? NSJSONSerialization.JSONObjectWithData(data!, options: [])
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
                    dispatch_async(dispatch_get_main_queue(), {
                        self.detailSpecs = specMap
                    })
                }
                octApp.startingRequest()
                task.resume()
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    self.detailSpecs = [[String:String]]()
                })
            }
        }
    }
}