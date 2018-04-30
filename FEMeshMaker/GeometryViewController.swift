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
    
    var contourLines:[(path:NSBezierPath, color:NSColor)] = []
    var contourLinesAreVisible = false
    
    // use the otherPaths member to draw whatever you want (should be used for debugging only - if there's something concrete required, give it it's own iVar)
    var otherPaths:[NSBezierPath] = []
    var otherPathsColors:[NSColor] = []
    
    var scrollClipView:NSClipView? = nil
    var placeholderView:GeometryView? = nil
    
    // My first-ever delegate! (I think)
    var delegate:GeometryViewControllerDelegate? = nil
    
    
    
    override var acceptsFirstResponder: Bool
    {
        return true
    }
    
    struct PointData
    {
        let location:NSPoint
        
        var data:[(name:String, value:Complex, units:String)] = []
    }
    
    // Initializer to stick the new input geometry view right into a window. Optionally, the new view can be added as a subView to a scroll view within the window. If nil is passed as intoView, the new view replaces the lowest-level view in the contentView of the window.
    convenience init(scrollClipView:NSClipView, placeholderView:GeometryView, delegate:GeometryViewControllerDelegate? = nil)
    {
        self.init(nibName: nil, bundle: nil)
        
        self.scrollClipView = scrollClipView
        self.placeholderView = placeholderView
        self.delegate = delegate
        
        // we need to access self.view to get the view to actually load on accounta its lazy
        let _ = self.view
    }
    
    
    override func mouseDown(with event: NSEvent)
    {
        let pointInView = self.view.convert(event.locationInWindow, from: nil)
        DLog("Got mouseDown with point: \(pointInView)")
        
        if let delegate = self.delegate
        {
            if let element = delegate.FindTriangleWithPoint(point: pointInView)
            {
                DLog("Triangle: \(element)")
            }
        }
    }
    
    override func rightMouseDown(with event: NSEvent)
    {
        let point = self.view.convert(event.locationInWindow, from: nil)
        
        if let delegate = self.delegate
        {
            let data = delegate.DataForPoint(point: point)
            
            DLog("Point: (\(data.location))", file: "", function: "")
            
            for nextData in data.data
            {
                DLog("\(nextData.name) \(nextData.value) \(nextData.units)", file: "", function: "")
            }
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
            
            geoView.geometry = []
            
            for nextPath in paths
            {
                geoView.geometry.append((path:nextPath, color:NSColor.black))
            }
            
            geoView.bounds = meshBounds
            
            ZoomAll()
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
    
    func ZoomAll()
    {
        guard let clipView = self.scrollClipView else
        {
            DLog("No clip view!")
            return
        }
        
        ZoomRect(newFrame: clipView.bounds)
    }
    
    func ZoomRect(newFrame:NSRect)
    {
        // NOTE: If newFrame is less than clipView.bounds, this next call won't do anything
        self.view.frame = newFrame
        
        let inset = CGFloat(5.0)
        
        let xScale = self.meshBounds.width / (newFrame.width - 2.0 * inset)
        let yScale = self.meshBounds.height / (newFrame.height - 2.0 * inset)
        
        let newScale = max(xScale, yScale)
        self.currentScale = newScale
        
        self.view.bounds.origin.x = -inset * newScale
        self.view.bounds.origin.y = -inset * newScale
        self.view.bounds.size.width = newFrame.width * newScale
        self.view.bounds.size.height = newFrame.height * newScale
        
        guard let geoView = self.view as? GeometryView else
        {
            DLog("Bad view!")
            return
        }
        
        geoView.lineWidth = newScale
    
        self.view.needsDisplay = true
    }
    
    // Zoom routines
    
    /* Old code
    func ZoomAll(meshBounds:NSRect)
    {
        self.view.frame = self.scrollClipView!.frame
        
        // We always want the outer mesh boundary to be inset by 5 points.
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
    */
    
    // To zoom in, factor should be >1, to zoom out it should be <1. For now, we "cheap out" and leave the origin wherever it is and zoom in or out (it would be nicer to maintain the center of the view instead of the origin).
    func ZoomWithFactor(_ factor:Double)
    {
        let zoomFactor = CGFloat(factor)
        
        // self.currentScale /= zoomFactor
        
        let oldFrame = self.view.frame
        let newRect = NSRect(origin: oldFrame.origin, size: NSSize(width: oldFrame.width * zoomFactor, height: oldFrame.height * zoomFactor))
        
        ZoomRect(newFrame: newRect)
        
    }
    
    /* Old Code
    func ZoomRect(newRect:NSRect)
    {
        self.view.bounds = newRect
        
        let geoView = self.view as! GeometryView
        geoView.lineWidth = self.currentScale
        
        self.view.needsDisplay = true
    }
    */
    
    func ToggleContourLines() -> Bool
    {
        let geoView = self.view as! GeometryView
        
        if self.contourLinesAreVisible
        {
            geoView.contourLines = []
        }
        else
        {
            geoView.contourLines = self.contourLines
        }
        
        geoView.needsDisplay = true
        self.contourLinesAreVisible = !self.contourLinesAreVisible
        
        return self.contourLinesAreVisible
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
    
    // Override loadView() to replace the dummy view with our view
    override func loadView()
    {
        super.loadView()
        
        if let dummyView = self.placeholderView
        {
            self.view.frame = dummyView.frame
            
            self.scrollClipView!.replaceSubview(dummyView, with: self.view)
            self.scrollClipView!.documentView = self.view
        }
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if self.meshBounds.width == 0.0 || self.meshBounds.height == 0.0
        {
            return
        }
        
        let geoView = self.view as! GeometryView
        
        geoView.geometry = []
        
        geoView.bounds = self.meshBounds
        
        for nextPath in self.paths
        {
            geoView.geometry.append((path:nextPath, color:NSColor.black))
        }
        
        geoView.otherPaths = self.otherPaths
        geoView.otherPathsColors = self.otherPathsColors
        
        ZoomAll()
        
        // geoView.triangles = self.triangles
        
        //numTriangles.stringValue = "Triangles: \(self.triangles.count)"
    }
    
}
