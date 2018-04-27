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
    var prescribedVoltage:Complex {
        
        get
        {
            return self.fixedValue
        }
        
        set
        {
            self.fixedValue = newValue
        }
    }
    
    init(tag:Int, prescribedVoltage:Complex, description:String)
    {
        super.init(tag: tag, fixedValue:prescribedVoltage, description: description)
    }
}
