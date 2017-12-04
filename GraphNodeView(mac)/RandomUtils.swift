//
//  RandomUtils.swift
//  GraphNodeView(mac)
//
//  Created by Arthur MASSON on 12/4/17.
//  Copyright © 2017 Arthur Masson. All rights reserved.
//

import Cocoa

extension NSColor {
    static func randomColor() -> NSColor {
        let red: CGFloat = arc4random() % 2 == 0 ? 0.8 : 0.2
        let green: CGFloat = arc4random() % 2 == 0 ? 0.8 : 0.2
        let blue: CGFloat = arc4random() % 2 == 0 ? 0.8 : 0.2
        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
