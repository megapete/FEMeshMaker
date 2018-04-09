//
//  GeometryViewController.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-09.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Cocoa

class GeometryViewController: NSViewController
{
    var currentScale:CGFloat = 1.0
    
    // Zoom routines
    func ZoomAll(meshBounds:NSRect)
    {
        let xScale = meshBounds.size.width / self.view.frame.size.width
        let yScale = meshBounds.size.height / self.view.frame.size.height
        
        var scaledMeshRect = meshBounds
        
        if xScale > yScale
        {
            self.currentScale = xScale
            scaledMeshRect.size.height = self.view.frame.size.height * xScale
        }
        else
        {
            self.currentScale = yScale
            scaledMeshRect.size.width = self.view.frame.size.width * yScale
        }
        
        ZoomRect(newRect: scaledMeshRect)
    }
    
    // To zoom in, factor should be >1, to zoom out it should be <1. For now, we "cheap out" and leave the origin wherever it is and zoom in or out (it would be nicer to maintain the center of the view instead of the origin).
    func ZoomWithFactor(_ factor:Double)
    {
        let zoomFactor = CGFloat(factor)
        
        self.currentScale *= zoomFactor
        
        let newRect = NSRect(origin: self.view.bounds.origin, size: NSSize(width: self.view.bounds.width * zoomFactor, height: self.view.bounds.height * zoomFactor))
        
        ZoomRect(newRect: newRect)
        
    }
    
    func ZoomRect(newRect:NSRect)
    {
        self.view.bounds = newRect
        
        self.view.needsDisplay = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}
