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
    
    var currentMesh:FE_Mesh? = nil
    
    var meshRectangle = NSRect(x: 0, y: 0, width: 0, height: 0)
    
    
    @IBAction func handleZoomAll(_ sender: Any)
    {
        if let gView = self.geometryView
        {
            gView.ZoomAll(meshBounds: self.meshRectangle)
        }
    }
    
    @IBAction func handleCreateDemo1(_ sender: Any)
    {
        // Simple model
        self.meshRectangle = NSRect(x: 0.0, y: 0.0, width: 20.0, height: 40.0)
        
        var currentRegionTagBase = 1
        let bulkOil = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: 0.1, y: 0.1)]
        currentRegionTagBase += bulkOil.refPoints.count
        
        let tankBoundary = Electrode(tag: 1, prescribedVoltage: Complex(real: 0.0, imag: 0.0), description: "Tank")
        let tankPath = MeshPath(path: NSBezierPath(rect: meshRectangle), boundary: tankBoundary)
        
        let coilRect = NSRect(x: 0.0, y: 5.0, width: 2.25, height: 30.0)
        
        let lvElectrode = Electrode(tag: 1, prescribedVoltage: Complex(real: 26400.0), description: "LV")
        let hvElectrode = Electrode(tag: 2, prescribedVoltage: Complex(real: 120000.0 / SQRT3), description: "HV")
        
        var meshPaths:[MeshPath] = [tankPath]
        var holes:[NSPoint] = []
        
        // let testRegion1 = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerBoard)
        meshPaths.append(MeshPath(rect: NSOffsetRect(coilRect, 2.5, 0.0), boundary: lvElectrode))
        // testRegion1.refPoints.append(NSPoint(x: 3.0, y: 10.0))
        holes.append(NSPoint(x: 3.0, y: 10.0))
        // let testRegion2 = DielectricRegion(dielectric: .TransformerBoard)
        // testRegion1.refPoints.append(NSPoint(x: 7.25, y: 10.0))
        meshPaths.append(MeshPath(rect: NSOffsetRect(coilRect, 6.75, 0.0), boundary: hvElectrode))
        holes.append(NSPoint(x: 7.25, y: 10.0))
        
        let elStaticMesh = FlatElectrostaticComplexPotentialMesh(withPaths: meshPaths, vertices: [], regions: [bulkOil], holes: holes)
        
        self.currentMesh = elStaticMesh
        
        self.geometryView = GeometryViewController(intoWindow: self.window, intoView:self.mainScrollView)
        self.currentGeometryViewBounds = self.geometryView!.view.bounds
        
        var diskPaths:[NSBezierPath] = [tankPath.path]
        for nextPath in meshPaths
        {
            diskPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: meshRectangle, paths: diskPaths, triangles: elStaticMesh.elements)
        
        let testZone = elStaticMesh.FindZoneWithPoint(X: NSPoint(x: 5.5, y: 20.0))
        if let testTriangle = testZone.triangle
        {
            DLog("Got triangle with \(testTriangle) and n0:\(testTriangle.corners.n0); n2:\(testTriangle.corners.n1); n3:\(testTriangle.corners.n2)")
            
            if let path = testZone.pathFollowed
            {
                self.geometryView?.SetOtherPaths(otherPaths: [path], otherColors: [NSColor.red])
            }
        }
        
        let testZone2 = elStaticMesh.FindZoneWithPoint(X: NSPoint(x: 9.3, y: 8.25))
        if let testTriangle2 = testZone2.triangle
        {
            DLog("Got triangle 2 with \(testTriangle2) and n0:\(testTriangle2.corners.n0); n2:\(testTriangle2.corners.n1); n3:\(testTriangle2.corners.n2)")
            if let path = testZone2.pathFollowed
            {
                self.geometryView?.AppendOtherPaths(otherPaths: [path], otherColors: [NSColor.blue])
            }
        }
        
    }
    
    @IBAction func handleSolveDemo1(_ sender: Any)
    {
        let result:[Complex] = self.currentMesh!.Solve()
        
        DLog("And it worked: \(result[295])")
    }
    
    
    
    @IBAction func handleCreateDemo(_ sender: Any)
    {
        // More realistic model
        self.meshRectangle = NSRect(x: 0.0, y: 0.0, width: 20.0, height: 40.0)
        
        var currentRegionTagBase = 1
        let bulkOil = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: 0.1, y: 0.1)]
        currentRegionTagBase += bulkOil.refPoints.count
        
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
        
        let diskPaper = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .PaperInOil)
        DLog("Creating discs...")
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
            
            let nextLVCopperRect = NSInsetRect(nextLVDiskRect, 0.030, 0.030)
            let nextHVCopperRect = NSInsetRect(nextHVDiskRect, 0.030, 0.030)
            
            holes.append(NSPoint(x: lvID + 1.125, y: diskBottom + 0.1875))
            holes.append(NSPoint(x: hVID + 1.125, y: diskBottom + 0.1875))
            
            let lvDiskPath = MeshPath(rect: nextLVCopperRect, boundary: Electrode(tag: nextTag, prescribedVoltage: Complex(real: lvDiskV, imag: 0.0), description: nextLVDiskName))
            
            nextTag += 1
            
            let hvDiskPath = MeshPath(rect: nextHVCopperRect, boundary: Electrode(tag: nextTag, prescribedVoltage: Complex(real: hvDiskV, imag: 0.0), description: nextHVDiskName))
            
            nextTag += 1
            meshPaths.append(contentsOf: [lvDiskPaperPath, lvDiskPath, hvDiskPaperPath, hvDiskPath])
            
            diskBottom += diskPitch
            lvDiskV += lvVoltsPerDisk
            hvDiskV += hvVoltsPerDisk
        }
        
        // This line added to indicate how we would add another Region
        currentRegionTagBase += diskPaper.refPoints.count
        
        DLog("Creating mesh...")
        let elStaticMesh = FlatElectrostaticComplexPotentialMesh(withPaths: meshPaths, vertices: [], regions: [bulkOil, diskPaper], holes: holes)
        
        DLog("Done. \n Creating geometry...")
        self.currentMesh = elStaticMesh
        
        self.geometryView = GeometryViewController(intoWindow: self.window, intoView:self.mainScrollView)
        self.currentGeometryViewBounds = self.geometryView!.view.bounds
        
        var diskPaths:[NSBezierPath] = [tankPath.path]
        for nextPath in meshPaths
        {
            diskPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: meshRectangle, paths: diskPaths, triangles: elStaticMesh.elements)
        
        DLog("Done. \nSearching for point 1...")
        let zone1 = elStaticMesh.FindZoneWithPoint(X: NSPoint(x: 5.5, y: 23.0))
        if let testTriangle1 = zone1.triangle
        {
            DLog("Got triangle 1 with \(testTriangle1) and n0:\(testTriangle1.corners.n0); n2:\(testTriangle1.corners.n1); n3:\(testTriangle1.corners.n2)")
        }
        if let path = zone1.pathFollowed
        {
            self.geometryView?.AppendOtherPaths(otherPaths: [path], otherColors: [NSColor.red])
        }
        
        let zone2 = elStaticMesh.FindZoneWithPoint(X: NSPoint(x: 9.3, y: 8.25))
        if let testTriangle2 = zone2.triangle
        {
            DLog("Got triangle 2 with \(testTriangle2) and n0:\(testTriangle2.corners.n0); n2:\(testTriangle2.corners.n1); n3:\(testTriangle2.corners.n2)")
        }
        else
        {
            DLog("An error occurred")
        }
        if let path = zone2.pathFollowed
        {
            self.geometryView?.AppendOtherPaths(otherPaths: [path], otherColors: [NSColor.blue])
        }
        
        
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
