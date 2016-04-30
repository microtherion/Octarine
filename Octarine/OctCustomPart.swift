//
//  OctCustomPart.swift
//  Octarine
//
//  Created by Matthias Neeracher on 29/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit

class OctCustomPart : NSObject, NSTextFieldDelegate {
    @IBOutlet weak var sheet : NSWindow!
    @IBOutlet weak var mainWindow: NSWindow!
    @IBOutlet weak var partTree: OctTree!

    dynamic var name        = "New Part"
    dynamic var desc        = ""
    dynamic var path        = "" { didSet { validatePart(self) } }
    dynamic var validPart   = false

    @IBAction func beginPartSheet(_: AnyObject) {
        mainWindow.beginSheet(sheet) { (response: NSModalResponse) in
            if (response > 0) {
                self.partTree.newCustomPart(self.name, desc: self.desc, url: self.path)
            }
        }
    }

    override func controlTextDidChange(obj: NSNotification) {
        print(obj)
    }

    @IBAction func validatePart(_: AnyObject) {
        validPart = NSURL(string: path) != nil && name != ""
    }

    @IBAction func add(_: AnyObject) {
        mainWindow.endSheet(sheet, returnCode:1)
    }

    @IBAction func dismiss(_: AnyObject) {
        mainWindow.endSheet(sheet)
    }
}