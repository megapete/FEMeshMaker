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
