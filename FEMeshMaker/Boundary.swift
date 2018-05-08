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
    let tag:Int
    
    let description:String
    
    var fixedValue:Complex
    
    let isNeumann:Bool
    
    init(tag:Int, fixedValue:Complex, description:String, isNeumann:Bool = false)
    {
        self.tag = tag
        self.description = description
        self.fixedValue = fixedValue
        self.isNeumann = isNeumann
    }
    
    static func NeumannBoundary() -> Boundary
    {
        return Boundary(tag: -1, fixedValue: Complex.ComplexNan, description: "Neumann Boundary", isNeumann: true)
    }
}
