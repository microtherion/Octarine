//
//  OctHelp.swift
//  Octarine
//
//  Created by Matthias Neeracher on 24/04/16.
//  Copyright © 2016 Matthias Neeracher. All rights reserved.
//

import AppKit
import Quartz

class OctHelp : NSWindowController {
    @IBOutlet weak var pdfView : PDFView!

    convenience init() {
        self.init(windowNibName:"Help")
    }

    override func windowDidLoad() {
        let helpURL = Bundle.main.url(forResource: "Help", withExtension: "pdf")
        let helpDoc = PDFDocument(url: helpURL!)
        pdfView.document = helpDoc
    }
}
