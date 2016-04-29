//
//  OctCustomPart.swift
//  Octarine
//
//  Created by Matthias Neeracher on 29/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

class OctCustomPart : NSObject {
    @IBOutlet weak var sheet : NSWindow!
    @IBOutlet weak var mainWindow: NSWindow!

    dynamic var name        = "New Part"
    dynamic var desc        = ""
    dynamic var url         : NSURL?
    dynamic var validPart   = false

    @IBAction func beginPartSheet(_: AnyObject) {
        mainWindow.beginSheet(sheet) { (response: NSModalResponse) in
            print(response)
        }
    }

    @IBAction func validatePart(_: AnyObject) {
        validPart = url != nil && name != ""
    }

    @IBAction func add(_: AnyObject) {
        mainWindow.endSheet(sheet, returnCode:1)
    }

    @IBAction func dismiss(_: AnyObject) {
        mainWindow.endSheet(sheet)
    }
}