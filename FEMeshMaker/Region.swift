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
    // A numerical identifier for the region. NOTE: This MUST be GREATER or EQUAL to 1.
    let tag:Int
    
    var description:String = ""
    let enclosingPath:NSBezierPath
    var attributes:[String:Complex] = [:]
    var refPoints:[NSPoint] = [] // all the points in the model that refer to this Region (there should be at least one)
    var associatedTriangles:[Element] = []
    
    init(tag:Int, enclosingPath:NSBezierPath, refPoints:[NSPoint] = [NSPoint(x: 0.0, y: 0.0)])
    {
        if tag < 1
        {
            ALog("Region tag identifier must be greater than or equal to 1")
        }
        
        self.tag = tag
        self.enclosingPath = enclosingPath
        self.refPoints = refPoints
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
    
    
}
