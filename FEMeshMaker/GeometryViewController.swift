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
    var trianglesAreVisible:Bool = false
    
    // use the otherPaths member to draw whatever you want (should be used for debugging only - if there's something concrete required, give it it's own iVar)
    var otherPaths:[NSBezierPath] = []
    var otherPathsColors:[NSColor] = []
    
    var parentWindow:NSWindow? = nil
    
    // Initializer to stick the new input geometry view right into a window. Optionally, the new view can be added as a subView to a scroll view within the window. If nil is passed as intoView, the new view replaces the lowest-level view in the contentView of the window.
    convenience init(intoWindow:NSWindow, intoView:NSScrollView? = nil)
    {
        if !intoWindow.isVisible
        {
            intoWindow.makeKeyAndOrderFront(nil)
        }
        
        // DLog("Is the window visible: \(intoWindow.isVisible)")
        self.init(nibName: nil, bundle: nil)
        
        self.parentWindow = intoWindow
        
        if let parentView = intoView
        {
            self.view.frame = parentView.contentView.frame
            parentView.documentView = self.view
        }
        else if let winView = intoWindow.contentView
        {
            if winView.subviews.count > 0
            {
                // DLog("Window already has subview! Removing...")
                winView.subviews = []
            }
            
            // This next line is required so that the new view completely takes up the space of the window's content view
            self.view.frame = winView.frame
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
            
            // geoView.triangles = triangles
            
            //numTriangles.stringValue = "Triangles: \(triangles.count)"
        }
    }
    
    func SetOtherPaths(otherPaths:[NSBezierPath], otherColors:[NSColor])
    {
        self.otherPaths = []
        self.otherPathsColors = []
        
        self.AppendOtherPaths(otherPaths: otherPaths, otherColors: otherColors)
    }
    
    func AppendOtherPaths(otherPaths:[NSBezierPath], otherColors:[NSColor])
    {
        self.otherPaths.append(contentsOf: otherPaths)
        self.otherPathsColors.append(contentsOf: otherColors)
        
        if self.isViewLoaded
        {
            let geoView = self.view as! GeometryView
            
            geoView.otherPaths = self.otherPaths
            geoView.otherPathsColors = self.otherPathsColors
            
            geoView.needsDisplay = true
        }
    }
    
    // Zoom routines
    func ZoomAll(meshBounds:NSRect)
    {
        // We always want the outr mesh boundary to be inset by 5 points.
        let insetPoints = CGFloat(5.0)
        
        // let selfViewFrame = self.view.frame
        let xScale = meshBounds.size.width / (self.view.frame.size.width - 2.0 * insetPoints)
        let yScale = meshBounds.size.height / (self.view.frame.size.height - 2.0 * insetPoints)
        
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
        
        let insetValue = insetPoints * self.currentScale
        
        scaledMeshRect.origin.x -= insetValue
        scaledMeshRect.origin.y -= insetValue
        scaledMeshRect.size.height += insetValue * 2.0
        scaledMeshRect.size.width += insetValue * 2.0
        
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
    
    // show/hide the triangles and return whether or not they are currently visible
    func ToggleTriangles() -> Bool
    {
        let geoView = self.view as! GeometryView
        
        if self.trianglesAreVisible
        {
            geoView.triangles = []
        }
        else
        {
            geoView.triangles = self.triangles
        }
        
        geoView.needsDisplay = true
        self.trianglesAreVisible = !self.trianglesAreVisible
        
        return self.trianglesAreVisible
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
        
        geoView.otherPaths = self.otherPaths
        geoView.otherPathsColors = self.otherPathsColors
        
        // geoView.triangles = self.triangles
        
        //numTriangles.stringValue = "Triangles: \(self.triangles.count)"
    }
    
}
