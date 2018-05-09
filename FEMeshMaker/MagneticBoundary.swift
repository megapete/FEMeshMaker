//
//  MagneticBoundary.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-05-09.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This class exists to set a magnetic boundary with a fixed magnetic potential (eg: the center of a core leg)

import Foundation

class MagneticBoundary: Boundary
{
    var prescribedPotential:Complex
    {
        get
        {
            return self.fixedValue
        }
        
        set
        {
            self.fixedValue = newValue
        }
    }
    
    init(tag:Int, prescribedPotential:Complex, description:String)
    {
        super.init(tag: tag, fixedValue:prescribedPotential, description: description)
    }
}
