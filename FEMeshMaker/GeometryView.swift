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
    let triangleOutlineColor = NSColor.yellow.blended(withFraction: 0.35, of: NSColor.brown)!
    
    var showTriangleOutlines:Bool = false
    var showFieldColors:Bool = false
    
    var contourLines:[(path:NSBezierPath, color:NSColor)] = []
    
    // use the otherPaths member to draw whatever you want (should be used for debugging only - if there's something concrete required, give it it's own iVar)
    var otherPaths:[NSBezierPath] = []
    var otherPathsColors:[NSColor] = []
    
    var controller:GeometryViewController? = nil
    
    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)

        // Drawing code here.
        
        let oldLineWidth = NSBezierPath.defaultLineWidth
        
        NSBezierPath.defaultLineWidth = self.lineWidth
        
        if let controller = self.controller, self.showFieldColors
        {
            for nextTriangle in triangles
            {
                let trianglePath = nextTriangle.ElementAsPath()
                trianglePath.lineWidth = self.lineWidth
                
                let triangleColor = controller.TriangleFillColorFor(value: nextTriangle.value)
                
                triangleColor.setFill()
                triangleColor.setStroke()
                
                trianglePath.stroke()
                trianglePath.fill()
            }
        }
        else if self.showTriangleOutlines
        {
            triangleOutlineColor.setStroke()
            for nextTriangle in triangles
            {
                let trianglePath = nextTriangle.ElementAsPath()
                trianglePath.lineWidth = self.lineWidth
                trianglePath.stroke()
            }
        }
        
        for nextPath in self.geometry
        {
            nextPath.color.setStroke()
            nextPath.path.lineWidth = self.lineWidth
            nextPath.path.stroke()
        }
        
        for nextLine in self.contourLines
        {
            let path = nextLine.path
            nextLine.color.setStroke()
            path.lineWidth = self.lineWidth
            path.stroke()
        }
        
        // draw any 'debug' paths using the current line width
        for i in 0..<otherPaths.count
        {
            self.otherPathsColors[i].setStroke()
            self.otherPaths[i].lineWidth = self.lineWidth
            self.otherPaths[i].stroke()
        }
        
        NSBezierPath.defaultLineWidth = oldLineWidth
    }
}
