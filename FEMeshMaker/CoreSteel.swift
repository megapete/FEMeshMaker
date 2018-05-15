//
//  CoreSteel.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-05-09.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation

class CoreSteel: Region
{
    // For now, we don't care about different types of steel
    init(tagBase:Int, refPoints:[NSPoint])
    {
        super.init(tagBase: tagBase, description: "Core Steel", refPoints: refPoints, isVirtualHole: false)
        
        self.µRel = Complex(real: 10000.0)
    }
}
