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
    var trianglesAreFilled:Bool = false
    
    var triangleMinValue:Double = Double.greatestFiniteMagnitude
    var triangleMaxValue:Double = Double.greatestFiniteMagnitude
    
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
            
            let inchLocation = NSPoint(x:data.location.x / 25.4, y:data.location.y / 25.4)
            DLog("Point: (\(data.location)); \(inchLocation)", file: "", function: "")
            
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
            
            geoView.triangles = []
            for nextTriangle in self.triangles
            {
                if let region = nextTriangle.region
                {
                    if !region.isVirtualHole
                    {
                        geoView.triangles.append(nextTriangle)
                    }
                }
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
    
    // To zoom in, factor should be >1, to zoom out it should be <1. For now, we "cheap out" and leave the origin wherever it is and zoom in or out (it would be nicer to maintain the center of the view instead of the origin).
    func ZoomWithFactor(_ factor:Double)
    {
        let zoomFactor = CGFloat(factor)
        
        // self.currentScale /= zoomFactor
        
        let oldFrame = self.view.frame
        let oldFrameCenter = NSPoint(x: oldFrame.origin.x + oldFrame.width / 2.0, y: oldFrame.origin.y + oldFrame.height / 2.0)
        let newWidth = oldFrame.width * zoomFactor
        let newHeight = oldFrame.height * zoomFactor
        let newSize = NSSize(width: newWidth, height: newHeight)
        let newOrigin = NSPoint(x: oldFrameCenter.x - newWidth / 2.0, y: oldFrameCenter.y - newHeight / 2.0)
        let newRect = NSRect(origin: newOrigin, size: newSize)
        
        ZoomRect(newFrame: newRect)
        
    }
    
    
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
    
    func TriangleFillColorFor(value:Double) ->NSColor
    {
        if self.triangleMinValue == Double.greatestFiniteMagnitude || self.triangleMaxValue == Double.greatestFiniteMagnitude
        {
            DLog("Triangle min and max not set!")
            return NSColor.white
        }
        
        let fraction = (value - self.triangleMinValue) / (self.triangleMaxValue - self.triangleMinValue)
        
        // This method does not really lend itself to electrostatic fields (maybe magnetostatic either) because there is a huge ocean of aqua and tiny triangles of yellow and pink at corners. I will try to come up with a more suitable function.
        
        // 0.00 -> Blue = (0, 0, 255)
        // 0.20 -> Aqua = (0, 255, 255)
        // 0.30 -> Green = (0, 255, 0)
        // 0.40 -> Yellow = (255, 255, 0)
        // 0.67 -> Red = (255, 0, 0)
        // 1.0 -> Pink = (255, 0, 255)
        
        if fraction <= 0.2
        {
            // Blue to Aqua
            let green = CGFloat(255.0 * fraction / 0.2)
            
            return NSColor(calibratedRed: 0.0, green: green, blue: 255.0, alpha: 1.0)
        }
        else if fraction <= 0.3
        {
            // Aqua to Green
            let blue = CGFloat(255.0 - 255.0 * (fraction - 0.2) / 0.1)
            
            return NSColor(calibratedRed: 0.0, green: 255.0, blue: blue, alpha: 1.0)
        }
        else if fraction <= 0.4
        {
            // Green to Yellow
            let red = CGFloat(255.0 * (fraction - 0.3) / 0.1)
            
            return NSColor(calibratedRed: red, green: 255.0, blue: 0.0, alpha: 1.0)
        }
        else if fraction <= 0.67
        {
            let green = CGFloat(255.0 - 255.0 * (fraction - 0.4) / 0.27)
            
            return NSColor(calibratedRed: 255.0, green: green, blue: 0.0, alpha: 1.0)
        }
        else
        {
            let blue = CGFloat(255.0 * (fraction - 0.67) / 0.33)
            
            return NSColor(calibratedRed: 255.0, green: 0.0, blue: blue, alpha: 1.0)
        }
    }
    
    func ToggleTriangleFill() -> Bool
    {
        let geoView = self.view as! GeometryView
        
        if self.trianglesAreFilled
        {
            geoView.showFieldColors = false
            // geoView.triangles = []
        }
        else
        {
            if let delegate = self.delegate
            {
                if let minMax = delegate.MinMaxFieldIntensity()
                {
                    self.triangleMinValue = minMax.minField
                    self.triangleMaxValue = minMax.maxField
                    // geoView.triangles = self.triangles
                }
                else
                {
                    DLog("Min and max fields not set")
                    return false
                }
            }
            else
            {
                DLog("Delegate not set")
                return false
            }
            
            geoView.showFieldColors = true
        }
        
        geoView.needsDisplay = true
        
        self.trianglesAreFilled = !self.trianglesAreFilled
        
        return self.trianglesAreFilled
    }
    
    // show/hide the triangles and return whether or not they are currently visible
    func ToggleTriangles() -> Bool
    {
        let geoView = self.view as! GeometryView
        
        if self.trianglesAreVisible
        {
            geoView.showTriangleOutlines = false
            // geoView.triangles = []
        }
        else
        {
            geoView.showTriangleOutlines = true
            // geoView.triangles = self.triangles
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
        
        let geoView = self.view as! GeometryView
        
        geoView.controller = self
        
        if self.meshBounds.width == 0.0 || self.meshBounds.height == 0.0
        {
            return
        }
        
        geoView.geometry = []
        
        geoView.bounds = self.meshBounds
        
        for nextPath in self.paths
        {
            geoView.geometry.append((path:nextPath, color:NSColor.black))
        }
        
        geoView.triangles = []
        for nextTriangle in self.triangles
        {
            if let region = nextTriangle.region
            {
                if !region.isVirtualHole
                {
                    geoView.triangles.append(nextTriangle)
                }
            }
        }
        
        geoView.otherPaths = self.otherPaths
        geoView.otherPathsColors = self.otherPathsColors
        
        ZoomAll()
        
        // geoView.triangles = self.triangles
        
        //numTriangles.stringValue = "Triangles: \(self.triangles.count)"
    }
    
}
