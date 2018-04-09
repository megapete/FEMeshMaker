//
//  GeometryView.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-09.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Cocoa

class GeometryView: NSView {
    
    // The shapes to show. The Bezier path dimensions should be the actual dimensions of the objects.
    var geometry:[(path:NSBezierPath, color:NSColor)] = []
    
    // The triangles of the mesh (if any)
    var triangles:[Element] = []
    let triangleColor = NSColor.yellow
    
    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)

        // Drawing code here.
        
        triangleColor.setStroke()
        for nextTriangle in triangles
        {
            nextTriangle.ElementAsPath().stroke()
        }
        
        for nextPath in self.geometry
        {
            nextPath.color.setStroke()
            nextPath.path.stroke()
        }
    }
}
