//
//  DielectricRegion.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-04-08.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation
import Cocoa

class DielectricRegion: Region {
    
    // charge density
    let rho:Complex
    
    // relative dielectric constant (permittivity) (>= 1)
    let eRel:Complex
    
    init(tag:Int, enclosingPath:NSBezierPath, eRel:Complex, rho:Complex)
    {
        self.rho = rho
        self.eRel = eRel
        
        super.init(tag: tag, enclosingPath: enclosingPath)
    }
}
