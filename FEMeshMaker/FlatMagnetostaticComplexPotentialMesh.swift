//
//  FlatMagnetostaticComplexPotentialMesh.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-05-08.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation


class FlatMagnetostaticComplexPotentialMesh: FE_Mesh
{
    init(withPaths:[MeshPath], units:FE_Mesh.Units, vertices:[NSPoint], regions:[Region], holes:[NSPoint] = [])
    {
        super.init(precision: .complex, units: units, withPaths: withPaths, vertices: vertices, regions: regions)
        
        self.Setup_A_Matrix()
        self.SetupComplexBmatrix()
    }
    
    override func Solve()
    {
        
    }
    
    override func DataAtPoint(_ point:NSPoint) -> [(name:String, value:Complex, units:String)]
    {
        
        
        return []
    }
    
    override func CalculateCouplingConstants(node:Node)
    {
        
    }
    
    override func CalculateRHSforNode(node:Node)
    {
        
    }
}
