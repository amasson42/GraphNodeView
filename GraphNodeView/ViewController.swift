//
//  ViewController.swift
//  GraphNodeView
//
//  Created by Arthur Masson on 01/12/2017.
//  Copyright © 2017 Arthur Masson. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var graphNodeView: GraphNodeView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

