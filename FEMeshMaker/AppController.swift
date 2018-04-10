//
//  AppController.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-06.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Cocoa

class AppController: NSObject
{

    @IBOutlet weak var window: NSWindow!
    
    @IBAction func handleCreateDemo(_ sender: Any)
    {
        // Simple model
        let meshRectangle = NSRect(x: 0.0, y: 0.0, width: 20.0, height: 20.0)
        let tankPath = NSBezierPath(rect: meshRectangle)
        let electrodePath = NSBezierPath(rect: NSRect(x: 5.0, y: 10.0, width: 7.5, height: 5.0))
        
        let testMesh = Mesh(withBezierPaths: [tankPath, electrodePath], vertices: [], regions: [])
        if !testMesh.RefineMesh()
        {
            DLog("Shoot, something didn't work")
        }
        
        let geometryView = GeometryViewController(intoWindow: self.window)
        
        geometryView.SetGeometry(meshBounds: meshRectangle, paths: [tankPath, electrodePath], triangles: testMesh.elements)
        
    }
    
    @IBAction func handleShowElements(_ sender: Any) {
    }
}
