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
    
    var meshBounds = NSRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    var paths:[NSBezierPath] = []
    var triangles:[Element] = []
    
    // Initializer to stick the new input geometry view right into a window
    convenience init(intoWindow:NSWindow)
    {
        if !intoWindow.isVisible
        {
            intoWindow.makeKeyAndOrderFront(nil)
        }
        
        // DLog("Is the window visible: \(intoWindow.isVisible)")
        self.init(nibName: nil, bundle: nil)
        
        if let winView = intoWindow.contentView
        {
            if winView.subviews.count > 0
            {
                // DLog("Window already has subview! Removing...")
                winView.subviews = []
            }
            
            winView.addSubview(self.view)
        }
    }
    
    func SetGeometry(meshBounds:NSRect, paths:[NSBezierPath], triangles:[Element])
    {
        self.meshBounds = meshBounds
        self.paths = paths
        self.triangles = triangles
        
        if self.isViewLoaded
        {
            let geoView = self.view as! GeometryView
            
            ZoomAll(meshBounds: meshBounds)
            
            geoView.geometry = []
            
            for nextPath in paths
            {
                geoView.geometry.append((path:nextPath, color:NSColor.black))
            }
            
            geoView.triangles = triangles
            
            //numTriangles.stringValue = "Triangles: \(triangles.count)"
        }
    }
    
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
        
        let geoView = self.view as! GeometryView
        geoView.lineWidth = self.currentScale
        
        self.view.needsDisplay = true
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if self.meshBounds.width == 0.0 || self.meshBounds.height == 0.0
        {
            return
        }
        
        let geoView = self.view as! GeometryView
        
        ZoomAll(meshBounds: self.meshBounds)
        
        geoView.geometry = []
        
        for nextPath in self.paths
        {
            geoView.geometry.append((path:nextPath, color:NSColor.black))
        }
        
        geoView.triangles = self.triangles
        
        //numTriangles.stringValue = "Triangles: \(self.triangles.count)"
    }
    
}
