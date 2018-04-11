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
    
    var geometryView:GeometryViewController? = nil
    
    var meshRectangle = NSRect(x: 0, y: 0, width: 0, height: 0)
    
    @IBAction func handleCreateDemo(_ sender: Any)
    {
        // Simple model
        self.meshRectangle = NSRect(x: 0.0, y: 0.0, width: 20.0, height: 40.0)
        
        let bulkOil = DielectricRegion(dielectric: .TransformerOil)
        bulkOil.refPoints = [NSPoint(x: 0.1, y: 0.1)]
        let tankPath = NSBezierPath(rect: meshRectangle)
        let rect1 = NSRect(x: 5.0, y: 5.0, width: 2.5, height: 30.0)
        let electrode1Path = /* NSBezierPath(roundedRect: rect1, xRadius: 0.25, yRadius: 0.25) */  NSBezierPath(rect: rect1)
        let testRegion = DielectricRegion(dielectric: .PaperInOil)
        // let hole1 = NSPoint(x: 5.1, y: 5.1)
        testRegion.refPoints = [NSPoint(x: 5.1, y: 5.1)]
        let electrode2Path = NSBezierPath(rect: NSRect(x: 10.0, y: 5.0, width: 2.5, height: 30.0))
        let hole2 = NSPoint(x: 10.1, y: 5.1)
        
        let testMesh = Mesh(withBezierPaths: [tankPath, electrode1Path, electrode2Path], vertices: [], regions: [bulkOil, testRegion], holes:[hole2])
        if !testMesh.RefineMesh()
        {
            DLog("Shoot, something didn't work")
        }
        
        
        
        // DLog("Window frame: \(self.window.frame); ContentViewFrame: \(self.window.contentView!.frame)")
        
        self.geometryView = GeometryViewController(intoWindow: self.window)
        
        self.geometryView?.SetGeometry(meshBounds: meshRectangle, paths: [tankPath, electrode1Path, electrode2Path], triangles: testMesh.elements)
        
    }
    
    @IBAction func handleShowElements(_ sender: Any) {
    }
    
    func windowDidResize(_ notification: Notification) {
        
        self.geometryView?.ZoomAll(meshBounds: self.meshRectangle)
    }
}
