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
    
    func ElectricFieldEnergy(isFlat:Bool, units:FE_Mesh.Units) -> Double
    {
        let ε0_fixed = ε0 * (units == .mm ? 0.001 : (units == .inch ? 0.0254 : 1.0))
        var result = 0.0
        DLog("For \(self.associatedTriangles.count) triangles")
        var currentTriangle = 0
        
        for nextTriangle in self.associatedTriangles
        {
            currentTriangle += 1
            
            let values = nextTriangle.ValuesAtCenterOfMass(coarse: true)
            
            let Ex = values.slopeX
            let Ey = values.slopeY
            
            // This comes from Andersen's paper "Finite Element Solution of Complex Potential Electric Fields", equations 19, 20, and 21
            
            var phaseAngleDiff = 0.0
            if Ex != Complex.ComplexZero
            {
                if Ey != Complex.ComplexZero
                {
                    phaseAngleDiff = abs(Ex.carg - Ey.carg)
                }
            }
            
            // We want Exp and Exn to be on the X-axis, so we create a Complex number with a real value of |Ex| and imag of 0.
            let ExAbs = Complex(real: Ex.cabs)
            let Exp = ExAbs * 0.5
            let Exn = Exp
            
            // The Ey values are a bit more complicated
            let EyAbs = Ey.cabs
            let Eyp = Complex(real: EyAbs * cos(π / 2 + phaseAngleDiff), imag: EyAbs * sin(π / 2 + phaseAngleDiff)) * 0.5
            let Eyn = Complex(real: EyAbs * cos(π / 2 - phaseAngleDiff), imag: EyAbs * sin(π / 2 - phaseAngleDiff)) * 0.5
            
            let Ep = Exp + Eyp
            let En = Exn + Eyn
            
            let Eabs = Ep.cabs + En.cabs
            
            if isFlat
            {
                result += self.eRel.real * ε0_fixed * Eabs * Eabs * nextTriangle.Area() / 2.0
            }
            else
            {
                result += π * Double(nextTriangle.CenterOfMass().x) * self.eRel.real * ε0_fixed * Eabs * Eabs * nextTriangle.Area()
            }
        }
        
        return result
    }
}
