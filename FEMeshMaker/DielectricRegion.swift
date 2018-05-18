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
    
    enum CommonDielectrics:Int {
        case Vacuum = 0
        case TransformerOil = 1
        case TransformerBoard = 2
        case PaperInOil = 3
        case Air = 4
        case Nomex = 5
    }
    
    // charge density
    let rho:Complex
    
    init(tagBase:Int, description:String = "Vacuum", refPoints:[NSPoint] = [], eRel:Complex = Complex(real:1.0, imag:0.0), rho:Complex = Complex(real:0.0, imag:0.0))
    {
        self.rho = rho
        
        super.init(tagBase: tagBase, description: description, refPoints: refPoints)
        
        self.eRel = eRel
    }
    
    // Convenience initializer for common dielectric materials. Note that it is up the calling routine to manually set the reference point(s) for the region after its creation.
    convenience init(tagBase:Int, dielectric:CommonDielectrics, rho:Complex = Complex(real:0.0, imag:0.0))
    {
        var eRel = 1.0
        var desc = "Vacuum"
        
        switch dielectric {
            
        case .TransformerOil:
            eRel = 2.2
            desc = "Transformer Oil"
            
        case .TransformerBoard:
            eRel = 4.5
            desc = "Transformer Board"
            
        case .PaperInOil:
            eRel = 3.5
            desc = "Oil-soaked Paper"
            
        case .Air:
            eRel = 1.00059
            desc = "Air"
            
        case .Nomex:
            eRel = 2.7 // at 7 to 10 mil thickness
            desc = "Nomex"
            
        default:
            eRel = 1.0 // vacuum
        }
        
        self.init(tagBase: tagBase, description: desc, eRel: Complex(real: eRel, imag: 0.0), rho:rho)
    }
    
    
}
