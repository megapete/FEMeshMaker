//
//  AppController.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-06.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Cocoa

class AppController: NSObject, NSWindowDelegate
{
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var mainScrollView: NSScrollView!
    
    var geometryView:GeometryViewController? = nil
    var currentGeometryViewBounds:NSRect = NSRect(x: 0, y: 0, width: 0, height: 0)
    
    @IBOutlet weak var showTrianglesMenuItem: NSMenuItem!
    
    var currentMesh:Mesh? = nil
    
    var meshRectangle = NSRect(x: 0, y: 0, width: 0, height: 0)
    
    @IBAction func handleCreateDemo(_ sender: Any)
    {
        // Simple model
        self.meshRectangle = NSRect(x: 0.0, y: 0.0, width: 20.0, height: 40.0)
        
        let bulkOil = DielectricRegion(dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: 0.1, y: 0.1)]
        
        let tankBoundary = Electrode(tag: 1, prescribedVoltage: Complex(real: 0.0, imag: 0.0), description: "Tank")
        let tankPath = MeshPath(path: NSBezierPath(rect: meshRectangle), boundary: tankBoundary)
        
        let diskSize = NSSize(width: 2.25, height: 0.375)
        let diskPitch = 0.575
        let numDisksPerCoil = round((30.0 - Double(diskSize.height)) / diskPitch) - 1.0
        
        let lvID = 2.5
        let lvVoltsPerDisk = 12500.0 / numDisksPerCoil
        let hVID = lvID + Double(diskSize.width) + 2.0
        let hvVoltsPerDisk = 25000.0 / numDisksPerCoil
        let coilBottom = 5.0
        var diskBottom = coilBottom
        var lvDiskV = 0.0
        var hvDiskV = 0.0
        
        var nextTag = 2
        
        var meshPaths:[MeshPath] = [tankPath]
        var holes:[NSPoint] = []
        
        let diskPaper = DielectricRegion(dielectric: .PaperInOil)
        
        for i in 0..<Int(numDisksPerCoil)
        {
            let nextLVDiskRect = NSRect(origin: NSPoint(x: lvID, y: diskBottom), size: diskSize)
            let nextLVDiskName = "LV\(i+1)"
            let nextHVDiskRect = NSRect(origin: NSPoint(x: hVID, y: diskBottom), size: diskSize)
            let nextHVDiskName = "HV\(i+1)"
            
            let lvDiskPaperPath = MeshPath(path: NSBezierPath(roundedRect: nextLVDiskRect, xRadius: 0.030, yRadius: 0.030), boundary: nil)
            diskPaper.refPoints.append(NSPoint(x: nextLVDiskRect.origin.x + 0.015, y: nextLVDiskRect.origin.y + 0.1875))
            let hvDiskPaperPath = MeshPath(path: NSBezierPath(roundedRect: nextHVDiskRect, xRadius: 0.030, yRadius: 0.030), boundary: nil)
            diskPaper.refPoints.append(NSPoint(x: nextHVDiskRect.origin.x + 0.015, y: nextHVDiskRect.origin.y + 0.1875))
            
            let nextLVCopperRect = NSInsetRect(nextLVDiskRect, -0.030, -0.030)
            let nextHVCopperRect = NSInsetRect(nextHVDiskRect, -0.030, -0.030)
            
            holes.append(NSPoint(x: lvID + 1.125, y: diskBottom + 0.1875))
            holes.append(NSPoint(x: hVID + 1.125, y: diskBottom + 0.1875))
            
            let lvDiskPath = MeshPath(path: NSBezierPath(rect: nextLVCopperRect), boundary: Electrode(tag: nextTag, prescribedVoltage: Complex(real: lvDiskV, imag: 0.0), description: nextLVDiskName))
            
            nextTag += 1
            
            let hvDiskPath = MeshPath(path: NSBezierPath(rect: nextHVCopperRect), boundary: Electrode(tag: nextTag, prescribedVoltage: Complex(real: hvDiskV, imag: 0.0), description: nextHVDiskName))
            
            nextTag += 1
            meshPaths.append(contentsOf: [lvDiskPaperPath, lvDiskPath, hvDiskPaperPath, hvDiskPath])
            
            diskBottom += diskPitch
            lvDiskV += lvVoltsPerDisk
            hvDiskV += hvVoltsPerDisk
        }
        
        
        let testMesh = Mesh(withPaths: meshPaths, vertices: [], regions: [bulkOil], holes:holes)
        if !testMesh.RefineMesh()
        {
            DLog("Shoot, something didn't work")
        }
        
        self.currentMesh = testMesh
        
        // DLog("Window frame: \(self.window.frame); ContentViewFrame: \(self.window.contentView!.frame)")
        
        self.geometryView = GeometryViewController(intoWindow: self.window, intoView:self.mainScrollView)
        self.currentGeometryViewBounds = self.geometryView!.view.bounds
        
        var diskPaths:[NSBezierPath] = [tankPath.path]
        for nextPath in meshPaths
        {
            diskPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: meshRectangle, paths: diskPaths, triangles: testMesh.elements)
        
    }
    
    @IBAction func handleShowElements(_ sender: Any)
    {
        if let gView = self.geometryView
        {
            let currentState = gView.ToggleTriangles()
            
            self.showTrianglesMenuItem.state = (currentState ? .on : .off)
        }
    }
    
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize
    {
        let sizeDiff = NSSize(width: frameSize.width - self.window.frame.width, height: frameSize.height - self.window.frame.height)
        
        if let gView = self.geometryView
        {
            let sizeDiffX = sizeDiff.width * gView.currentScale
            let sizeDiffY = sizeDiff.height * gView.currentScale
            
            let oldBounds = gView.view.bounds
            
            let newBounds = NSRect(x: oldBounds.origin.x, y: oldBounds.origin.y - sizeDiffY, width: oldBounds.width + sizeDiffX, height: oldBounds.height + sizeDiffY)
            
            self.currentGeometryViewBounds = newBounds
            // gView.ZoomRect(newRect: newBounds)
            
        }
        
        return frameSize
    }
    
    func windowDidResize(_ notification: Notification) {
        
        self.geometryView?.ZoomRect(newRect: self.currentGeometryViewBounds)
        
    }
}
