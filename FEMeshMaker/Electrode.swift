//
//  Electrode.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-11.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This struct is used to define electrodes, which have a tag (used as a marker in Mesh) and a fixed-voltage value

import Foundation

struct Electrode
{
    let tag:Int
    
    let description:String
    
    let prescribedVoltage:Complex
}
