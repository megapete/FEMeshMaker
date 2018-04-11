//
//  Electrode.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-11.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This struct is used to define electrodes, which have a tag (used as a marker in Mesh) and a fixed-voltage value

import Foundation

class Electrode:Boundary
{
    let prescribedVoltage:Complex
    
    init(tag:Int, prescribedVoltage:Complex, description:String)
    {
        self.prescribedVoltage = prescribedVoltage
        
        super.init(tag: tag, description: description)
    }
}
