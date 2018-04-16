//
//  MeshPath.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-04-11.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation
import Cocoa

class MeshPath
{
    let path:NSBezierPath
    
    let boundary:Boundary?
    
    init(path:NSBezierPath, boundary:Boundary?)
    {
        self.path = path
        self.boundary = boundary
    }
    
    // Use this initializer to add points in the corner of a rectangle to make a finer mesh there. The constant 500 and the use of the average line lengths are from Meeker.
    convenience init(rect:NSRect, boundary:Boundary?)
    {
        let lineFraction:CGFloat = 500.0
        let dl = (rect.width + rect.height) / 2.0 / lineFraction
        
        let path = NSBezierPath()
        
        path.move(to: rect.origin) // bottom left
        path.relativeLine(to: NSPoint(x: dl, y: 0.0))
        path.relativeLine(to: NSPoint(x: rect.width - 2.0 * dl, y: 0.0))
        path.relativeLine(to: NSPoint(x: dl, y: 0.0)) // bottom right
        path.relativeLine(to: NSPoint(x: 0.0, y: dl))
        path.relativeLine(to: NSPoint(x: 0.0, y: rect.height - 2.0 * dl))
        path.relativeLine(to: NSPoint(x: 0.0, y: dl)) // top right
        path.relativeLine(to: NSPoint(x: -dl, y: 0.0))
        path.relativeLine(to: NSPoint(x: -(rect.width - 2.0 * dl), y: 0.0))
        path.relativeLine(to: NSPoint(x: -dl, y: 0.0)) // top left
        path.relativeLine(to: NSPoint(x: 0.0, y: -dl))
        path.relativeLine(to: NSPoint(x: 0.0, y: -(rect.height - 2.0 * dl)))
        path.close() // back to the origin
        
        self.init(path: path, boundary: boundary)
    }
}
