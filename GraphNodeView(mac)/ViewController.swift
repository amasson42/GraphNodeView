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
    
    @IBAction func setDataSource(_ sender: Any) {
        graphNodeView.dataSource = self
        graphNodeView.delegate = self
    }
}

extension ViewController: GraphNodeViewDataSource {
    
    func graphNodeView(_ graphNodeView: GraphNodeView, linksForNodeNamed name: String) -> [String] {
        switch name {
        case "Alpha":
            return ["Bravo"]
        case "Bravo":
            return ["Charlie"]
        case "Charlie":
            return ["Bravo"]
        default:
            return []
        }
    }
    
    func namesOfAllNodes(in graphNodeView: GraphNodeView) -> [String] {
        return ["Alpha", "Bravo", "Charlie"]
    }
    
}

extension ViewController: GraphNodeViewDelegate {
    
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return 0
    }
}
