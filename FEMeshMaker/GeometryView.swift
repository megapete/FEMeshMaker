//
//  GeometryView.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-09.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Cocoa

class GeometryView: NSView {
    
    var lineWidth:CGFloat = 1.0
    
    // The shapes to show. The Bezier path dimensions should be the actual dimensions of the objects.
    var geometry:[(path:NSBezierPath, color:NSColor)] = []
    
    // The triangles of the mesh (if any)
    var triangles:[Element] = []
    let triangleColor = NSColor.yellow
    
    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)

        // Drawing code here.
        
        
        
        let oldLineWidth = NSBezierPath.defaultLineWidth
        
        NSBezierPath.defaultLineWidth = self.lineWidth
        
        triangleColor.setStroke()
        for nextTriangle in triangles
        {
            let trianglePath = nextTriangle.ElementAsPath()
            trianglePath.lineWidth = self.lineWidth
            nextTriangle.ElementAsPath().stroke()
        }
        
        for nextPath in self.geometry
        {
            nextPath.color.setStroke()
            nextPath.path.lineWidth = self.lineWidth
            nextPath.path.stroke()
        }
        
        NSBezierPath.defaultLineWidth = oldLineWidth
    }
}
