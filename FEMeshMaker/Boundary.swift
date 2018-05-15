//
//  Boundary.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-04-11.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// Base class for boundaries and other surfaces with fixed values

import Foundation

class Boundary
{
    static let neumannTagNumber = 32000
    
    let tag:Int
    
    let description:String
    
    var fixedValue:Complex
    
    let isNeumann:Bool
    
    var associatedEdges:[Edge] = []
    
    init(tag:Int, fixedValue:Complex, description:String, isNeumann:Bool = false)
    {
        self.tag = tag
        self.description = description
        self.fixedValue = fixedValue
        self.isNeumann = isNeumann
    }
    
    static func NeumannBoundary() -> Boundary
    {
        return Boundary(tag: Boundary.neumannTagNumber, fixedValue: Complex.ComplexNan, description: "Neumann Boundary", isNeumann: true)
    }
    
    func SurfaceArea(isFlat:Bool) -> Double
    {
        var result = 0.0
        if isFlat
        {
            for nextEdge in self.associatedEdges
            {
                result += Double(nextEdge.Length())
            }
        }
        else
        {
            for nextEdge in self.associatedEdges
            {
                let averageR = Double((nextEdge.endPoint1.vertex.x + nextEdge.endPoint2.vertex.x) / 2.0)
                
                result += 2.0 * π * averageR * Double(nextEdge.Length())
            }
        }
        
        return result
    }
}
