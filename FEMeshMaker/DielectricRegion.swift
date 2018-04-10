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
    
    // dielectric constants for commonly used transformer-related materials
    let transformerOil = 2.2
    let transformerBoard = 4.5
    let paper = 3.5
    
    // some dry-type constants
    let air = 1.00059
    let nomex = 2.7 // at approximately 8 mil thick
    
    // charge density
    let rho:Complex
    
    // relative dielectric constant (permittivity) (>= 1)
    let eRel:Complex
    
    init(tag:Int, enclosingPath:NSBezierPath, refPoints:[NSPoint], eRel:Complex, rho:Complex)
    {
        self.rho = rho
        self.eRel = eRel
        
        super.init(tag: tag, enclosingPath: enclosingPath, refPoints: refPoints)
    }
}
