//
//  Region.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-07.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This class is meant to be subclassed into concrete classes

import Foundation
import Cocoa

class Region
{
    // A numerical identifier for the region. NOTE: This must be GREATER or EQUAL to 1.
    let tag:Int
    
    var description:String = ""
    let enclosingPath:NSBezierPath
    var attributes:[String:Complex] = [:]
    var associatedTriangles:[Element] = []
    
    init(tag:Int, enclosingPath:NSBezierPath)
    {
        self.tag = tag
        self.enclosingPath = enclosingPath
    }
    
    func TotalTriangleArea() -> Double
    {
        var result = 0.0
        
        for nextTriangle in self.associatedTriangles
        {
            result += nextTriangle.Area()
        }
        
        return result
    }
    
    func CenterOfMass() -> NSPoint
    {
        if self.associatedTriangles.count == 0
        {
            DLog("No triangles defined for region!")
            return NSPoint(x: Double.greatestFiniteMagnitude, y: Double.greatestFiniteMagnitude)
        }
        
        // return the average of all the center of masses of the associated triangles
        
        var xTotal:CGFloat = 0.0
        var yTotal:CGFloat = 0.0
        
        for nextTriangle in self.associatedTriangles
        {
            let nextCenter = nextTriangle.CenterOfMass()
            
            xTotal += nextCenter.x
            yTotal += nextCenter.y
        }
        
        let triangleCount = CGFloat(self.associatedTriangles.count)
        
        return NSPoint(x: xTotal / triangleCount, y: yTotal / triangleCount)
    }
}
