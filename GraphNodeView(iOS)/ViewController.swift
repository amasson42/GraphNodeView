//
//  ViewController.swift
//  GraphNodeView(iOS)
//
//  Created by Arthur MASSON on 12/1/17.
//  Copyright © 2017 Arthur Masson. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var graphNodeView: GraphNodeView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
