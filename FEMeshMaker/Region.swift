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
    // A BASE identifier for the region. NOTE: This MUST be GREATER or EQUAL to 1.
    // Note the following relationship between region tags and refPoints:
    // refPoint[i] has an ACTUAL tag number (as far as Triangle is concerned) = baseTag + i
    // NOTE: It is recommended to set tagBase's as multiples of 1000 (unless there is a really bizarre case where ther will be more than 1000 instances of a given boundary within a geometry).
    let tagBase:Int
    
    // An optional string descriptor for the region
    var description:String = "Region"
    // let enclosingPath:NSBezierPath
    var attributes:[String:Complex] = [:]
    var refPoints:[NSPoint] = [] // all the points in the model that refer to this Region (there should be at least one)
    var associatedTriangles:[Element] = []
    
    // Relative permittivity and permealbility of materials. These should be properly set by concrete subclasses
    var eRel:Complex = Complex(real: 1.0)
    var µRel:Complex = Complex(real: 1.0)
    
    // We don't use holes in FE_Mesh to make it easier to do triangle-finding. However, we will want the option to not show those triangles within a given region when displaying the mesh, so we define the concept of a "virtual hole"
    var isVirtualHole:Bool
    
    init(tagBase:Int, description:String = "Region", refPoints:[NSPoint] = [NSPoint(x: 0.0, y: 0.0)], isVirtualHole:Bool = false)
    {
        if tagBase < 1
        {
            ALog("Region base-tag identifier must be greater than or equal to 1")
        }
        
        self.tagBase = tagBase
        self.description = description
        // self.enclosingPath = enclosingPath
        self.refPoints = refPoints
        self.isVirtualHole = isVirtualHole
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
    
    func Volume(isFlat:Bool) -> Double
    {
        // for flat meshes, the volume is actually a "volume per length in z"
        if isFlat
        {
            return self.TotalTriangleArea()
        }
        
        var result = 0.0
        
        for nextTriangle in self.associatedTriangles
        {
            result += Double(nextTriangle.CenterOfMass().x) * nextTriangle.Area()
        }
        
        return 2.0 * π * result
    }
    
}
