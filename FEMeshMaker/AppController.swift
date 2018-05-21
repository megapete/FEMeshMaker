//
//  AppController.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-06.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Cocoa

class AppController: NSObject, NSWindowDelegate, GeometryViewControllerDelegate
{
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var scrollClipView: NSClipView!
    @IBOutlet weak var dummyGeoView: GeometryView!
    
    @IBOutlet weak var testScrollView: NSScrollView!
    
    var geometryView:GeometryViewController? = nil
    
    @IBOutlet weak var showTrianglesMenuItem: NSMenuItem!
    @IBOutlet weak var showContourLinesMenuItem: NSMenuItem!
    @IBOutlet weak var solveMenuItem: NSMenuItem!
    @IBOutlet weak var showFieldInfoMenuItem: NSMenuItem!
    
    
    var currentMesh:FE_Mesh? = nil
    var currentMeshIsSolved = false
    
    var meshRectangle = NSRect(x: 0, y: 0, width: 0, height: 0)
    
    @IBAction func handleShowFieldInfo(_ sender: Any)
    {
        if let gView = self.geometryView
        {
            let currentState = gView.ToggleTriangleFill()
            
            self.showFieldInfoMenuItem.state = (currentState ? .on : .off)
        }
    }
    
    func MinMaxFieldIntensity() -> (minField:Double, maxField:Double)?
    {
        guard let mesh = self.currentMesh else
        {
            DLog("No current mesh")
            return nil
        }
        
        guard let minF = mesh.minFieldIntensityTriangle, let maxF = mesh.maxFieldIntensityTriangle else
        {
            DLog("Min and max triangles not set")
            return nil
        }
        
        return (minF.value, maxF.value)
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
    {
        if menuItem == showTrianglesMenuItem
        {
            return self.geometryView != nil
        }
        else if menuItem == showContourLinesMenuItem || menuItem == showFieldInfoMenuItem
        {
            return self.currentMeshIsSolved
        }
        else if menuItem == solveMenuItem
        {
            return self.currentMesh != nil
        }
        
        return true
    }
    
    @IBAction func handleShowContourLines(_ sender: Any)
    {
        if let gView = self.geometryView
        {
            let currentState = gView.ToggleContourLines()
            
            self.showContourLinesMenuItem.state = (currentState ? .on : .off)
        }
    }
    
    // GeometryViewControllerDelegate functions
    func DataForPoint(point: NSPoint) -> GeometryViewController.PointData {
        
        var result = GeometryViewController.PointData(location: point, data: [])
        
        guard let mesh = self.currentMesh else
        {
            return result
        }
        
        if self.currentMeshIsSolved
        {
            let data = mesh.DataAtPoint(point)
            
            result.data = data
        }
        
        return result
    }
    
    func FindTriangleWithPoint(point: NSPoint) -> Element? {
        
        if let mesh = self.currentMesh
        {
            let zone = mesh.FindZoneWithPoint(X: point)
            
            if let triangle = zone.triangle
            {
                if self.currentMeshIsSolved
                {
                    DLog("V0:\(triangle.corners.n0.phi); V1:\(triangle.corners.n1.phi); V2:\(triangle.corners.n2.phi)", file: "", function: "")
                }
                
                return triangle
            }
        }
        
        return nil
    }
    
    @IBAction func handleZoomOut(_ sender: Any)
    {
        if let gView = self.geometryView
        {
            gView.ZoomWithFactor(1.0 / 1.5)
        }
    }
    
    @IBAction func handleZoomIn(_ sender: Any)
    {
        if let gView = self.geometryView
        {
            gView.ZoomWithFactor(1.5)
        }
    }
    
    @IBAction func handleZoomAll(_ sender: Any)
    {
        if let gView = self.geometryView
        {
            gView.ZoomAll()
        }
    }
    
    @IBAction func handleCreateDemo1(_ sender: Any)
    {
        // Simple model
        self.meshRectangle = NSRect(x: 0.0, y: 0.0, width: 20.0 * 25.4 / 1000.0, height: 40.0 * 25.4 / 1000.0)
        
        var currentRegionTagBase = 1
        let bulkOil = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: 0.1 * 25.4 / 1000.0, y: 0.1 * 25.4 / 1000.0)]
        currentRegionTagBase += bulkOil.refPoints.count
        
        let tankBoundary = Electrode(tag: 1, prescribedVoltage: Complex(real: 0.0, imag: 0.0), description: "Tank")
        let tankPath = MeshPath(path: NSBezierPath(rect: meshRectangle), boundary: tankBoundary)
        
        let coilRect = NSRect(x: 0.0, y: 5.0 * 25.4 / 1000.0, width: 2.25 * 25.4 / 1000.0, height: 30.0 * 25.4 / 1000.0)
        
        let lvElectrode = Electrode(tag: 2, prescribedVoltage: Complex(real: 26400.0), description: "LV")
        let lvConductor = ConductorRegion(type: .copper, electrode: lvElectrode, tagBase: 1000, refPoints: [NSPoint(x: 3.0 * 25.4 / 1000.0, y: 10.0 * 25.4 / 1000.0)], isVirtualHole: true)
        let hvElectrode = Electrode(tag: 3, prescribedVoltage: Complex(real: 120000.0 / SQRT3), description: "HV")
        let hvConductor = ConductorRegion(type: .copper, electrode: hvElectrode, tagBase: 2000, refPoints: [NSPoint(x: 7.25 * 25.4 / 1000.0, y: 10.0 * 25.4 / 1000.0)], isVirtualHole: true)
        
        var meshPaths:[MeshPath] = [tankPath]
        var holes:[NSPoint] = []
        
        // let testRegion1 = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerBoard)
        meshPaths.append(MeshPath(rect: NSOffsetRect(coilRect, 2.5 * 25.4 / 1000.0, 0.0), boundary: lvElectrode))
        // testRegion1.refPoints.append(NSPoint(x: 3.0, y: 10.0))
        holes.append(NSPoint(x: 3.0 * 25.4 / 1000.0, y: 10.0 * 25.4 / 1000.0))
        // let testRegion2 = DielectricRegion(dielectric: .TransformerBoard)
        // testRegion1.refPoints.append(NSPoint(x: 7.25, y: 10.0))
        meshPaths.append(MeshPath(rect: NSOffsetRect(coilRect, 6.75 * 25.4 / 1000.0, 0.0), boundary: hvElectrode))
        holes.append(NSPoint(x: 7.25 * 25.4 / 1000.0, y: 10.0 * 25.4 / 1000.0))
        
        let elStaticMesh = FlatElectrostaticComplexPotentialMesh(withPaths: meshPaths, units: .meters, vertices: [], regions: [bulkOil, lvConductor, hvConductor])
        
        self.currentMesh = elStaticMesh
        
        // var scrollDocView = self.testScrollView.documentView
        self.geometryView = GeometryViewController(scrollClipView: self.scrollClipView, placeholderView: self.dummyGeoView, delegate:self)
        
        
        // let actualGeoView = self.geometryView!.view
        // scrollDocView = self.testScrollView.documentView
        
        // let currentGeometryViewBounds = self.geometryView!.view.bounds
        
        var diskPaths:[NSBezierPath] = [tankPath.path]
        for nextPath in meshPaths
        {
            diskPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: meshRectangle, paths: diskPaths, triangles: elStaticMesh.elements)
        
        /* Debugging code
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
        */
        
    }
    
    @IBAction func handleCreateDemo9(_ sender: Any)
    {
        // Axi-sym magnetic with eddy losses
        // axi-symmetric magnetic demo
        var currentRegionTagBase = 1
        var currentBoundaryBase = 1
        
        let coreR:CGFloat = 215.0 / 1000.0
        let windHt:CGFloat = 1110.0  / 1000.0
        let tankR:CGFloat = 530.0  / 1000.0
        
        // let coreRectangle = NSRect(x: 0.0, y: 0.0, width: coreR, height: windHt)
        let corePath = NSBezierPath()
        corePath.move(to: NSPoint(x: coreR, y: 0.0))
        corePath.line(to: NSPoint(x: 0.0, y: 0.0))
        corePath.line(to: NSPoint(x: 0.0, y: windHt))
        corePath.line(to: NSPoint(x: coreR, y: windHt))
        let coreCenter = MagneticBoundary(tag: currentBoundaryBase, prescribedPotential: Complex.ComplexZero, description: "CoreCenter")
        currentBoundaryBase += 1
        let coreMeshPath = MeshPath(path: corePath, boundary: coreCenter)
        
        let coreSteel = CoreSteel(tagBase: currentRegionTagBase, refPoints: [NSPoint(x: 0.0001, y: 0.0001)])
        currentRegionTagBase += 1
        
        let bulkOil = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: coreR + 0.0001, y: 0.0001)]
        currentRegionTagBase += 1
        
        let tankBoundary = Boundary.NeumannBoundary()
        let tankRect = NSRect(x: coreR, y: 0.0, width: tankR - coreR, height: windHt)
        let tankMeshPath = MeshPath(rect: tankRect, boundary: tankBoundary)
        
        let lvCoilRect = NSRect(x: 244.5  / 1000.0, y: 89.3  / 1000.0, width: 34.8  / 1000.0, height: 914.5  / 1000.0)
        let lvCoilArea = 34.8 * 914.5  / 1000000.0
        let lvCurrentRMS = -266.667
        let lvCurrentPeak = lvCurrentRMS * sqrt(2.0)
        let lvTurns = 208.0
        // let lvCoilCond = ConductorRegion(type: .copper, currentDensity: Complex(real:lvCurrentPeak * lvTurns / lvCoilArea), description: "LV", tagBase: 1000, refPoints: [NSPoint(x: lvCoilRect.origin.x + lvCoilRect.width / 2.0, y: lvCoilRect.origin.y + lvCoilRect.height / 2.0)], isVirtualHole: false)
        let lvCoil = CoilRegion(type: .copper, currentDensity: Complex(real:lvCurrentPeak * lvTurns / lvCoilArea), description: "LV", tagBase: 1000, refPoints: [NSPoint(x: lvCoilRect.origin.x + lvCoilRect.width / 2.0, y: lvCoilRect.origin.y + lvCoilRect.height / 2.0)], N: lvTurns, Nradial: 3.467, strandDim: (8.55 / 1000.0, 12.55 / 1000.0), bounds: lvCoilRect, isVirtualHole: false)
        let lvCoilMeshPath = MeshPath(rect: lvCoilRect, boundary: nil)
        
        let hvCoilRect = NSRect(x: 322.7 / 1000.0, y: 89.3 / 1000.0, width: 34.1 / 1000.0, height: 914.5 / 1000.0)
        let hvCoilArea = 34.1 * 914.5 / 1000000.0
        let hvCurrentRMS = 83.674
        let hvCurrentPeak = hvCurrentRMS * sqrt(2.0)
        let hvTurns = 663.0
        // let hvCoilCond = ConductorRegion(type: .copper, currentDensity: Complex(real:hvCurrentPeak * hvTurns / hvCoilArea), description: "HV", tagBase: 2000, refPoints: [NSPoint(x: hvCoilRect.origin.x + hvCoilRect.width / 2.0, y: hvCoilRect.origin.y + hvCoilRect.height / 2.0)], isVirtualHole: false)
        let hvCoil = CoilRegion(type: .copper, currentDensity: Complex(real:hvCurrentPeak * hvTurns / hvCoilArea), description: "HV", tagBase: 2000, refPoints: [NSPoint(x: hvCoilRect.origin.x + hvCoilRect.width / 2.0, y: hvCoilRect.origin.y + hvCoilRect.height / 2.0)], N: hvTurns, Nradial: 11.84, strandDim: (2.412 / 1000.0, 11.809 / 1000.0), bounds: hvCoilRect, isVirtualHole: false)
        let hvCoilMeshPath = MeshPath(rect: hvCoilRect, boundary: nil)
        
        let meshPaths = [coreMeshPath, tankMeshPath, lvCoilMeshPath, hvCoilMeshPath]
        
        let flatMag = AxiSymMagneticWithEddyCurrents(withPaths: meshPaths, atFrequency: 60.0, units: .meters, vertices: [], regions: [coreSteel, bulkOil, lvCoil, hvCoil])
        
        self.currentMesh = flatMag
        
        DLog("Core steel triangles: \(coreSteel.associatedTriangles.count)")
        
        self.geometryView = GeometryViewController(scrollClipView: self.scrollClipView, placeholderView: self.dummyGeoView, delegate:self)
        
        var drawPaths:[NSBezierPath] = []
        for nextPath in meshPaths
        {
            drawPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: flatMag.bounds, paths: drawPaths, triangles: flatMag.elements)
    }
    
    
    @IBAction func handleCreateDemo8(_ sender: Any)
    {
        // Axi-sym magnetic demo (mm)
        var currentRegionTagBase = 1
        var currentBoundaryBase = 1
        
        let coreR:CGFloat = 215.0
        let windHt:CGFloat = 1110.0
        let tankR:CGFloat = 530.0
        
        // let coreRectangle = NSRect(x: 0.0, y: 0.0, width: coreR, height: windHt)
        let corePath = NSBezierPath()
        corePath.move(to: NSPoint(x: coreR, y: 0.0))
        corePath.line(to: NSPoint(x: 0.0, y: 0.0))
        corePath.line(to: NSPoint(x: 0.0, y: windHt))
        corePath.line(to: NSPoint(x: coreR, y: windHt))
        let coreCenter = MagneticBoundary(tag: currentBoundaryBase, prescribedPotential: Complex.ComplexZero, description: "CoreCenter")
        currentBoundaryBase += 1
        let coreMeshPath = MeshPath(path: corePath, boundary: coreCenter)
        
        let coreSteel = CoreSteel(tagBase: currentRegionTagBase, refPoints: [NSPoint(x: 0.1, y: 0.1)])
        currentRegionTagBase += 1
        
        let bulkOil = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: coreR + 0.1, y: 0.1)]
        currentRegionTagBase += 1
        
        let tankBoundary = Boundary.NeumannBoundary()
        let tankRect = NSRect(x: coreR, y: 0.0, width: tankR - coreR, height: windHt)
        let tankMeshPath = MeshPath(rect: tankRect, boundary: tankBoundary)
        
        let lvCoilRect = NSRect(x: 244.5, y: 89.3, width: 34.8, height: 914.5)
        let lvCoilArea = 34.8 * 914.5
        let lvCurrentRMS = -266.667
        let lvCurrentPeak = lvCurrentRMS * sqrt(2.0)
        let lvTurns = 208.0
        let lvCoilCond = ConductorRegion(type: .copper, currentDensity: Complex(real:lvCurrentPeak * lvTurns / lvCoilArea), description: "LV", tagBase: 1000, refPoints: [NSPoint(x: lvCoilRect.origin.x + lvCoilRect.width / 2.0, y: lvCoilRect.origin.y + lvCoilRect.height / 2.0)], isVirtualHole: false)
        let lvCoilMeshPath = MeshPath(rect: lvCoilRect, boundary: nil)
        
        let hvCoilRect = NSRect(x: 322.7, y: 89.3, width: 34.1, height: 914.5)
        let hvCoilArea = 34.1 * 914.5
        let hvCurrentRMS = 83.674
        let hvCurrentPeak = hvCurrentRMS * sqrt(2.0)
        let hvTurns = 663.0
        let hvCoilCond = ConductorRegion(type: .copper, currentDensity: Complex(real:hvCurrentPeak * hvTurns / hvCoilArea), description: "HV", tagBase: 2000, refPoints: [NSPoint(x: hvCoilRect.origin.x + hvCoilRect.width / 2.0, y: hvCoilRect.origin.y + hvCoilRect.height / 2.0)], isVirtualHole: false)
        let hvCoilMeshPath = MeshPath(rect: hvCoilRect, boundary: nil)
        
        let meshPaths = [coreMeshPath, tankMeshPath, lvCoilMeshPath, hvCoilMeshPath]
        
        let flatMag = AxiSymMagnetostaticComplexPotentialMesh(withPaths: meshPaths, units: .mm, vertices: [], regions: [coreSteel, bulkOil, lvCoilCond, hvCoilCond])
        
        self.currentMesh = flatMag
        
        DLog("Core steel triangles: \(coreSteel.associatedTriangles.count)")
        
        self.geometryView = GeometryViewController(scrollClipView: self.scrollClipView, placeholderView: self.dummyGeoView, delegate:self)
        
        var drawPaths:[NSBezierPath] = []
        for nextPath in meshPaths
        {
            drawPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: flatMag.bounds, paths: drawPaths, triangles: flatMag.elements)
    }
    
    
    @IBAction func handleCreateDemo7(_ sender: Any)
    {
        // axi-symmetric magnetic demo
        var currentRegionTagBase = 1
        var currentBoundaryBase = 1
        
        let coreR:CGFloat = 215.0 / 1000.0
        let windHt:CGFloat = 1110.0  / 1000.0
        let tankR:CGFloat = 530.0  / 1000.0
        
        // let coreRectangle = NSRect(x: 0.0, y: 0.0, width: coreR, height: windHt)
        let corePath = NSBezierPath()
        corePath.move(to: NSPoint(x: coreR, y: 0.0))
        corePath.line(to: NSPoint(x: 0.0, y: 0.0))
        corePath.line(to: NSPoint(x: 0.0, y: windHt))
        corePath.line(to: NSPoint(x: coreR, y: windHt))
        let coreCenter = MagneticBoundary(tag: currentBoundaryBase, prescribedPotential: Complex.ComplexZero, description: "CoreCenter")
        currentBoundaryBase += 1
        let coreMeshPath = MeshPath(path: corePath, boundary: coreCenter)
        
        let coreSteel = CoreSteel(tagBase: currentRegionTagBase, refPoints: [NSPoint(x: 0.0001, y: 0.0001)])
        currentRegionTagBase += 1
        
        let bulkOil = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: coreR + 0.0001, y: 0.0001)]
        currentRegionTagBase += 1
        
        let tankBoundary = Boundary.NeumannBoundary()
        let tankRect = NSRect(x: coreR, y: 0.0, width: tankR - coreR, height: windHt)
        let tankMeshPath = MeshPath(rect: tankRect, boundary: tankBoundary)
        
        let lvCoilRect = NSRect(x: 244.5  / 1000.0, y: 89.3  / 1000.0, width: 34.8  / 1000.0, height: 914.5  / 1000.0)
        let lvCoilArea = 34.8 * 914.5  / 1000000.0
        let lvCurrentRMS = -266.667
        let lvCurrentPeak = lvCurrentRMS * sqrt(2.0)
        let lvTurns = 208.0
        let lvCoilCond = ConductorRegion(type: .copper, currentDensity: Complex(real:lvCurrentPeak * lvTurns / lvCoilArea), description: "LV", tagBase: 1000, refPoints: [NSPoint(x: lvCoilRect.origin.x + lvCoilRect.width / 2.0, y: lvCoilRect.origin.y + lvCoilRect.height / 2.0)], isVirtualHole: false)
        let lvCoilMeshPath = MeshPath(rect: lvCoilRect, boundary: nil)
        
        let hvCoilRect = NSRect(x: 322.7 / 1000.0, y: 89.3 / 1000.0, width: 34.1 / 1000.0, height: 914.5 / 1000.0)
        let hvCoilArea = 34.1 * 914.5 / 1000000.0
        let hvCurrentRMS = 83.674
        let hvCurrentPeak = hvCurrentRMS * sqrt(2.0)
        let hvTurns = 663.0
        let hvCoilCond = ConductorRegion(type: .copper, currentDensity: Complex(real:hvCurrentPeak * hvTurns / hvCoilArea), description: "HV", tagBase: 2000, refPoints: [NSPoint(x: hvCoilRect.origin.x + hvCoilRect.width / 2.0, y: hvCoilRect.origin.y + hvCoilRect.height / 2.0)], isVirtualHole: false)
        let hvCoilMeshPath = MeshPath(rect: hvCoilRect, boundary: nil)
        
        let meshPaths = [coreMeshPath, tankMeshPath, lvCoilMeshPath, hvCoilMeshPath]
        
        let flatMag = AxiSymMagnetostaticComplexPotentialMesh(withPaths: meshPaths, units: .meters, vertices: [], regions: [coreSteel, bulkOil, lvCoilCond, hvCoilCond])
        
        self.currentMesh = flatMag
        
        DLog("Core steel triangles: \(coreSteel.associatedTriangles.count)")
        
        self.geometryView = GeometryViewController(scrollClipView: self.scrollClipView, placeholderView: self.dummyGeoView, delegate:self)
        
        var drawPaths:[NSBezierPath] = []
        for nextPath in meshPaths
        {
            drawPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: flatMag.bounds, paths: drawPaths, triangles: flatMag.elements)
    }
    
    
    @IBAction func handleCreateDemo6(_ sender: Any)
    {
        // Flat magnetic demo (mm)
        var currentRegionTagBase = 1
        var currentBoundaryBase = 1
        
        let coreR:CGFloat = 215.0
        let windHt:CGFloat = 1110.0
        let tankR:CGFloat = 530.0
        
        // let coreRectangle = NSRect(x: 0.0, y: 0.0, width: coreR, height: windHt)
        let corePath = NSBezierPath()
        corePath.move(to: NSPoint(x: coreR, y: 0.0))
        corePath.line(to: NSPoint(x: 0.0, y: 0.0))
        corePath.line(to: NSPoint(x: 0.0, y: windHt))
        corePath.line(to: NSPoint(x: coreR, y: windHt))
        let coreCenter = MagneticBoundary(tag: currentBoundaryBase, prescribedPotential: Complex.ComplexZero, description: "CoreCenter")
        currentBoundaryBase += 1
        let coreMeshPath = MeshPath(path: corePath, boundary: coreCenter)
        
        let coreSteel = CoreSteel(tagBase: currentRegionTagBase, refPoints: [NSPoint(x: 0.1, y: 0.1)])
        currentRegionTagBase += 1
        
        let bulkOil = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: coreR + 0.1, y: 0.1)]
        currentRegionTagBase += 1
        
        let tankBoundary = Boundary.NeumannBoundary()
        let tankRect = NSRect(x: coreR, y: 0.0, width: tankR - coreR, height: windHt)
        let tankMeshPath = MeshPath(rect: tankRect, boundary: tankBoundary)
        
        let lvCoilRect = NSRect(x: 244.5, y: 89.3, width: 34.8, height: 914.5)
        let lvCoilArea = 34.8 * 914.5
        let lvCurrentRMS = -266.667
        let lvCurrentPeak = lvCurrentRMS * sqrt(2.0)
        let lvTurns = 208.0
        let lvCoilCond = ConductorRegion(type: .copper, currentDensity: Complex(real:lvCurrentPeak * lvTurns / lvCoilArea), description: "LV", tagBase: 1000, refPoints: [NSPoint(x: lvCoilRect.origin.x + lvCoilRect.width / 2.0, y: lvCoilRect.origin.y + lvCoilRect.height / 2.0)], isVirtualHole: false)
        let lvCoilMeshPath = MeshPath(rect: lvCoilRect, boundary: nil)
        
        let hvCoilRect = NSRect(x: 322.7, y: 89.3, width: 34.1, height: 914.5)
        let hvCoilArea = 34.1 * 914.5
        let hvCurrentRMS = 83.674
        let hvCurrentPeak = hvCurrentRMS * sqrt(2.0)
        let hvTurns = 663.0
        let hvCoilCond = ConductorRegion(type: .copper, currentDensity: Complex(real:hvCurrentPeak * hvTurns / hvCoilArea), description: "HV", tagBase: 2000, refPoints: [NSPoint(x: hvCoilRect.origin.x + hvCoilRect.width / 2.0, y: hvCoilRect.origin.y + hvCoilRect.height / 2.0)], isVirtualHole: false)
        let hvCoilMeshPath = MeshPath(rect: hvCoilRect, boundary: nil)
        
        let meshPaths = [coreMeshPath, tankMeshPath, lvCoilMeshPath, hvCoilMeshPath]
        
        let flatMag = FlatMagnetostaticComplexPotentialMesh(withPaths: meshPaths, units: .mm, vertices: [], regions: [coreSteel, bulkOil, lvCoilCond, hvCoilCond])
        
        self.currentMesh = flatMag
        
        DLog("Core steel triangles: \(coreSteel.associatedTriangles.count)")
        
        self.geometryView = GeometryViewController(scrollClipView: self.scrollClipView, placeholderView: self.dummyGeoView, delegate:self)
        
        var drawPaths:[NSBezierPath] = []
        for nextPath in meshPaths
        {
            drawPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: flatMag.bounds, paths: drawPaths, triangles: flatMag.elements)
    }
    
    
    @IBAction func handleCreateDemo5(_ sender: Any)
    {
        // Flat magnetic demo
        var currentRegionTagBase = 1
        var currentBoundaryBase = 1
        
        let coreR:CGFloat = 215.0 / 1000.0
        let windHt:CGFloat = 1110.0  / 1000.0
        let tankR:CGFloat = 530.0  / 1000.0
        
        // let coreRectangle = NSRect(x: 0.0, y: 0.0, width: coreR, height: windHt)
        let corePath = NSBezierPath()
        corePath.move(to: NSPoint(x: coreR, y: 0.0))
        corePath.line(to: NSPoint(x: 0.0, y: 0.0))
        corePath.line(to: NSPoint(x: 0.0, y: windHt))
        corePath.line(to: NSPoint(x: coreR, y: windHt))
        let coreCenter = MagneticBoundary(tag: currentBoundaryBase, prescribedPotential: Complex.ComplexZero, description: "CoreCenter")
        currentBoundaryBase += 1
        let coreMeshPath = MeshPath(path: corePath, boundary: coreCenter)
        
        let coreSteel = CoreSteel(tagBase: currentRegionTagBase, refPoints: [NSPoint(x: 0.0001, y: 0.0001)])
        currentRegionTagBase += 1
        
        let bulkOil = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: coreR + 0.0001, y: 0.0001)]
        currentRegionTagBase += 1
        
        let tankBoundary = Boundary.NeumannBoundary()
        let tankRect = NSRect(x: coreR, y: 0.0, width: tankR - coreR, height: windHt)
        let tankMeshPath = MeshPath(rect: tankRect, boundary: tankBoundary)
        
        let lvCoilRect = NSRect(x: 244.5  / 1000.0, y: 89.3  / 1000.0, width: 34.8  / 1000.0, height: 914.5  / 1000.0)
        let lvCoilArea = 34.8 * 914.5  / 1000000.0
        let lvCurrentRMS = -266.667
        let lvCurrentPeak = lvCurrentRMS * sqrt(2.0)
        let lvTurns = 208.0
        let lvCoilCond = ConductorRegion(type: .copper, currentDensity: Complex(real:lvCurrentPeak * lvTurns / lvCoilArea), description: "LV", tagBase: 1000, refPoints: [NSPoint(x: lvCoilRect.origin.x + lvCoilRect.width / 2.0, y: lvCoilRect.origin.y + lvCoilRect.height / 2.0)], isVirtualHole: false)
        let lvCoilMeshPath = MeshPath(rect: lvCoilRect, boundary: nil)
        
        let hvCoilRect = NSRect(x: 322.7 / 1000.0, y: 89.3 / 1000.0, width: 34.1 / 1000.0, height: 914.5 / 1000.0)
        let hvCoilArea = 34.1 * 914.5 / 1000000.0
        let hvCurrentRMS = 83.674
        let hvCurrentPeak = hvCurrentRMS * sqrt(2.0)
        let hvTurns = 663.0
        let hvCoilCond = ConductorRegion(type: .copper, currentDensity: Complex(real:hvCurrentPeak * hvTurns / hvCoilArea), description: "HV", tagBase: 2000, refPoints: [NSPoint(x: hvCoilRect.origin.x + hvCoilRect.width / 2.0, y: hvCoilRect.origin.y + hvCoilRect.height / 2.0)], isVirtualHole: false)
        let hvCoilMeshPath = MeshPath(rect: hvCoilRect, boundary: nil)
        
        let meshPaths = [coreMeshPath, tankMeshPath, lvCoilMeshPath, hvCoilMeshPath]
        
        let flatMag = FlatMagnetostaticComplexPotentialMesh(withPaths: meshPaths, units: .meters, vertices: [], regions: [coreSteel, bulkOil, lvCoilCond, hvCoilCond])
        
        self.currentMesh = flatMag
        
        DLog("Core steel triangles: \(coreSteel.associatedTriangles.count)")
        
        self.geometryView = GeometryViewController(scrollClipView: self.scrollClipView, placeholderView: self.dummyGeoView, delegate:self)
        
        var drawPaths:[NSBezierPath] = []
        for nextPath in meshPaths
        {
            drawPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: flatMag.bounds, paths: drawPaths, triangles: flatMag.elements)
    }
    
    @IBAction func handleCreateDemo4(_ sender: Any)
    {
        self.meshRectangle = NSRect(x: 0.0, y: 0.0, width: 20.0 * 25.4 / 1000.0, height: 40.0 * 25.4 / 1000.0)
        
        var currentRegionTagBase = 1
        let bulkOil = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: 0.1 * 25.4 / 1000.0, y: 0.1 * 25.4 / 1000.0)]
        currentRegionTagBase += bulkOil.refPoints.count
        
        let tankBoundary = Electrode(tag: 1, prescribedVoltage: Complex(real: 0.0, imag: 0.0), description: "Tank")
        let tankPath = MeshPath(path: NSBezierPath(rect: meshRectangle), boundary: tankBoundary)
        
        let coilRect = NSRect(x: 0.0, y: 5.0 * 25.4 / 1000.0, width: 2.25 * 25.4 / 1000.0, height: 30.0 * 25.4 / 1000.0)
        
        let lvElectrode = Electrode(tag: 2, prescribedVoltage: Complex(real: 26400.0), description: "LV")
        let lvConductor = ConductorRegion(type: .copper, electrode: lvElectrode, tagBase: 1000, refPoints: [NSPoint(x: 3.0 * 25.4 / 1000.0, y: 10.0 * 25.4 / 1000.0)], isVirtualHole: true)
        let hvElectrode = Electrode(tag: 3, prescribedVoltage: Complex(real: 120000.0 / SQRT3), description: "HV")
        let hvConductor = ConductorRegion(type: .copper, electrode: hvElectrode, tagBase: 2000, refPoints: [NSPoint(x: 7.25 * 25.4 / 1000.0, y: 10.0 * 25.4 / 1000.0)], isVirtualHole: true)
        
        var meshPaths:[MeshPath] = [tankPath]
        var holes:[NSPoint] = []
        
        // let testRegion1 = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerBoard)
        meshPaths.append(MeshPath(rect: NSOffsetRect(coilRect, 2.5 * 25.4 / 1000.0, 0.0), boundary: lvElectrode))
        // testRegion1.refPoints.append(NSPoint(x: 3.0, y: 10.0))
        holes.append(NSPoint(x: 3.0 * 25.4 / 1000.0, y: 10.0 * 25.4 / 1000.0))
        // let testRegion2 = DielectricRegion(dielectric: .TransformerBoard)
        // testRegion1.refPoints.append(NSPoint(x: 7.25, y: 10.0))
        meshPaths.append(MeshPath(rect: NSOffsetRect(coilRect, 6.75 * 25.4 / 1000.0, 0.0), boundary: hvElectrode))
        holes.append(NSPoint(x: 7.25 * 25.4 / 1000.0, y: 10.0 * 25.4 / 1000.0))
        
        let elStaticMesh = AxiSymElectrostaticComplexPotentialMesh(withPaths: meshPaths, units: .meters, vertices: [], regions: [bulkOil, lvConductor, hvConductor])
        
        self.currentMesh = elStaticMesh
        
        // var scrollDocView = self.testScrollView.documentView
        self.geometryView = GeometryViewController(scrollClipView: self.scrollClipView, placeholderView: self.dummyGeoView, delegate:self)
        
        
        // let actualGeoView = self.geometryView!.view
        // scrollDocView = self.testScrollView.documentView
        
        // let currentGeometryViewBounds = self.geometryView!.view.bounds
        
        var diskPaths:[NSBezierPath] = [] // [tankPath.path]
        for nextPath in meshPaths
        {
            diskPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: meshRectangle, paths: diskPaths, triangles: elStaticMesh.elements)
    }
    
    
    @IBAction func handleCreateDemo3(_ sender: Any)
    {
        self.meshRectangle = NSRect(x: 0.0, y: 0.0, width: 20.0 * 25.4, height: 40.0 * 25.4)
        
        var currentRegionTagBase = 1
        let bulkOil = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: 0.1 * 25.4, y: 0.1 * 25.4)]
        currentRegionTagBase += bulkOil.refPoints.count
        
        let tankBoundary = Electrode(tag: 1, prescribedVoltage: Complex(real: 0.0, imag: 0.0), description: "Tank")
        let groundPath = NSBezierPath()
        groundPath.move(to: NSPoint(x: 20.0 * 25.4, y: 40.0 * 25.4))
        groundPath.line(to: NSPoint(x: 0.0, y: 40.0 * 25.4))
        groundPath.line(to: self.meshRectangle.origin)
        groundPath.line(to: NSPoint(x: 20 * 25.4, y: 0.0))
        let tankPath = MeshPath(path: groundPath, boundary: tankBoundary)
        let neumannPath = NSBezierPath()
        neumannPath.move(to: NSPoint(x: 20.0 * 25.4, y: 40.0 * 25.4))
        neumannPath.line(to: NSPoint(x: 20 * 25.4, y: 0.0))
        let rightsidePath = MeshPath(path: neumannPath, boundary: Boundary.NeumannBoundary())
        
        let coilRect = NSRect(x: 0.0, y: 5.0 * 25.4, width: 2.25 * 25.4, height: 30.0 * 25.4)
        
        let lvElectrode = Electrode(tag: 2, prescribedVoltage: Complex(real: 26400.0), description: "LV")
        let lvConductor = ConductorRegion(type: .copper, electrode: lvElectrode, tagBase: 1000, refPoints: [NSPoint(x: 3.0 * 25.4, y: 10.0 * 25.4)], isVirtualHole: true)
        let hvElectrode = Electrode(tag: 3, prescribedVoltage: Complex(real: 120000.0 / SQRT3), description: "HV")
        let hvConductor = ConductorRegion(type: .copper, electrode: hvElectrode, tagBase: 2000, refPoints: [NSPoint(x: 7.25 * 25.4, y: 10.0 * 25.4)], isVirtualHole: true)
        
        var meshPaths:[MeshPath] = [tankPath, rightsidePath]
        var holes:[NSPoint] = []
        
        // let testRegion1 = DielectricRegion(tagBase: currentRegionTagBase, dielectric: .TransformerBoard)
        meshPaths.append(MeshPath(rect: NSOffsetRect(coilRect, 2.5 * 25.4, 0.0), boundary: lvElectrode))
        // testRegion1.refPoints.append(NSPoint(x: 3.0, y: 10.0))
        holes.append(NSPoint(x: 3.0 * 25.4, y: 10.0 * 25.4))
        // let testRegion2 = DielectricRegion(dielectric: .TransformerBoard)
        // testRegion1.refPoints.append(NSPoint(x: 7.25, y: 10.0))
        meshPaths.append(MeshPath(rect: NSOffsetRect(coilRect, 6.75 * 25.4, 0.0), boundary: hvElectrode))
        holes.append(NSPoint(x: 7.25 * 25.4, y: 10.0 * 25.4))
        
        let elStaticMesh = FlatElectrostaticComplexPotentialMesh(withPaths: meshPaths, units: .mm, vertices: [], regions: [bulkOil, lvConductor, hvConductor])
        
        self.currentMesh = elStaticMesh
        
        // var scrollDocView = self.testScrollView.documentView
        self.geometryView = GeometryViewController(scrollClipView: self.scrollClipView, placeholderView: self.dummyGeoView, delegate:self)
        
        
        // let actualGeoView = self.geometryView!.view
        // scrollDocView = self.testScrollView.documentView
        
        // let currentGeometryViewBounds = self.geometryView!.view.bounds
        
        var diskPaths:[NSBezierPath] = [tankPath.path]
        for nextPath in meshPaths
        {
            diskPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: meshRectangle, paths: diskPaths, triangles: elStaticMesh.elements)
    }
    
    @IBAction func handleSolveDemo1(_ sender: Any)
    {
        self.currentMesh!.Solve()
        
        self.currentMeshIsSolved = true
        
        // Debug sanity checks
        #if DEBUG
        
        let currMesh = self.currentMesh!
        
        var checkElems:Set<Element> = []
        var checkNodes:Set<Node> = []
        for nextNode in currMesh.nodes
        {
            for nextNeighbour in nextNode.neighbours
            {
                checkNodes.insert(nextNeighbour)
            }
            for nextElem in nextNode.elements
            {
                checkElems.insert(nextElem)
            }
        }
        
        if checkNodes.count != currMesh.nodes.count
        {
            ALog("Too many nodes!")
        }
        
        if checkElems.count != currMesh.elements.count
        {
            ALog("Too many triangles!")
        }
        
        var regionTriangleCount = 0
        for nextRegion in currMesh.regions
        {
            regionTriangleCount += nextRegion.associatedTriangles.count
        }
        
        if regionTriangleCount != currMesh.elements.count
        {
            ALog("Regions have incorrect number of triangles!")
        }
        
        #endif
        
        DLog("Matrices solved...")
        
        let lines = self.currentMesh!.CreateContourLines()
        
        if let gView = self.geometryView
        {
            for nextLine in lines
            {
                gView.contourLines.append((path: nextLine.path , color: NSColor.blue))
            }
        }
        
        DLog("Contour lines created...")
        
        if let axiElecMesh = self.currentMesh! as? AxiSymElectrostaticComplexPotentialMesh
        {
            DLog("Calculating electrical energy")
            for nextRegion in axiElecMesh.regions
            {
                if let dielectric = nextRegion as? DielectricRegion
                {
                    // let units = (axiElecMesh.units == .inch ? "inch" : (axiElecMesh.units == .mm ? "mm" : "meter"))
                    let energy = dielectric.ElectricFieldEnergy(isFlat: true, units: axiElecMesh.units)
                    DLog("\(dielectric.description) Energy: \(energy) Joules")
                }
            }
        }
        else if let flatElecMesh = self.currentMesh! as? FlatElectrostaticComplexPotentialMesh
        {
            DLog("Calculating electrical energy")
            for nextRegion in flatElecMesh.regions
            {
                if let dielectric = nextRegion as? DielectricRegion
                {
                    let units = (flatElecMesh.units == .inch ? "inch" : (flatElecMesh.units == .mm ? "mm" : "meter"))
                    let energy = dielectric.ElectricFieldEnergy(isFlat: true, units: flatElecMesh.units)
                    DLog("\(dielectric.description) Energy: \(energy) Joules (depth 1 \(units))")
                }
            }
        }
        else if let axiMagMesh = self.currentMesh! as? AxiSymMagnetostaticComplexPotentialMesh
        {
            var totalEnergy = 0.0
            DLog("Calculating magnetic energy")
            // let units = (flatMagMesh.units == .inch ? "inch" : (flatMagMesh.units == .mm ? "mm" : "meter"))
            for nextRegion in axiMagMesh.regions
            {
                let energy = nextRegion.MagneticFieldEnergy(isFlat: false, units: axiMagMesh.units)
                totalEnergy += energy
                DLog("\(nextRegion.description) Energy: \(energy) Joules")
            }
            
            DLog("Total energy: \(totalEnergy) Joules")
        }
        else if let flatMagMesh = self.currentMesh! as? FlatMagnetostaticComplexPotentialMesh
        {
            var totalEnergy = 0.0
            DLog("Calculating magnetic energy")
            let units = (flatMagMesh.units == .inch ? "inch" : (flatMagMesh.units == .mm ? "mm" : "meter"))
            for nextRegion in flatMagMesh.regions
            {
                let energy = nextRegion.MagneticFieldEnergy(isFlat: true, units: flatMagMesh.units)
                totalEnergy += energy
                DLog("\(nextRegion.description) Energy: \(energy) Joules (depth 1 \(units))")
            }
            
            DLog("Total energy: \(totalEnergy) Joules (depth 1 \(units))")
        }
        
        
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
        let elStaticMesh = FlatElectrostaticComplexPotentialMesh(withPaths: meshPaths, units: .inch, vertices: [], regions: [bulkOil, diskPaper], holes: holes)
        
        DLog("Done. \n Creating geometry...")
        self.currentMesh = elStaticMesh
        
        self.geometryView = GeometryViewController(scrollClipView: self.scrollClipView, placeholderView: self.dummyGeoView, delegate:self)
        //self.currentGeometryViewBounds = self.geometryView!.view.bounds
        
        var diskPaths:[NSBezierPath] = [tankPath.path]
        for nextPath in meshPaths
        {
            diskPaths.append(nextPath.path)
        }
        
        self.geometryView?.SetGeometry(meshBounds: meshRectangle, paths: diskPaths, triangles: elStaticMesh.elements)
        
        /*
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
         */
        
        
    }
    
    @IBAction func handleShowElements(_ sender: Any)
    {
        if let gView = self.geometryView
        {
            let currentState = gView.ToggleTriangles()
            
            self.showTrianglesMenuItem.state = (currentState ? .on : .off)
        }
    }
    /*
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
        
        
 
    }
    */
}
