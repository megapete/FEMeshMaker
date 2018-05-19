//
//  Region.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-07.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This class is meant to be subclassed into concrete classes

import Foundation
import Cocoa

class Region
{
    // A BASE identifier for the region. NOTE: This MUST be GREATER or EQUAL to 1.
    // Note the following relationship between region tags and refPoints:
    // refPoint[i] has an ACTUAL tag number (as far as Triangle is concerned) = baseTag + i
    // NOTE: It is recommended to set tagBase's as multiples of 1000 (unless there is a really bizarre case where ther will be more than 1000 instances of a given boundary within a geometry).
    let tagBase:Int
    
    // An optional string descriptor for the region
    var description:String = "Region"
    // let enclosingPath:NSBezierPath
    var attributes:[String:Complex] = [:]
    var refPoints:[NSPoint] = [] // all the points in the model that refer to this Region (there should be at least one)
    var associatedTriangles:[Element] = []
    
    // Relative permittivity and permealbility of materials. These should be properly set by concrete subclasses
    var eRel:Complex = Complex(real: 1.0)
    var µRel:Complex = Complex(real: 1.0)
    
    // We don't use holes in FE_Mesh to make it easier to do triangle-finding. However, we will want the option to not show those triangles within a given region when displaying the mesh, so we define the concept of a "virtual hole"
    var isVirtualHole:Bool
    
    init(tagBase:Int, description:String = "Region", refPoints:[NSPoint] = [NSPoint(x: 0.0, y: 0.0)], isVirtualHole:Bool = false)
    {
        if tagBase < 1
        {
            ALog("Region base-tag identifier must be greater than or equal to 1")
        }
        
        self.tagBase = tagBase
        self.description = description
        // self.enclosingPath = enclosingPath
        self.refPoints = refPoints
        self.isVirtualHole = isVirtualHole
    }
    
    func TotalTriangleArea() -> Double
    {
        var result = 0.0
        
        for nextTriangle in self.associatedTriangles
        {
            result += nextTriangle.Area()
        }
        
        return result
    }
    
    func Volume(isFlat:Bool) -> Double
    {
        // for flat meshes, the volume is actually a "volume per length in z"
        if isFlat
        {
            return self.TotalTriangleArea()
        }
        
        var result = 0.0
        
        for nextTriangle in self.associatedTriangles
        {
            result += Double(nextTriangle.CenterOfMass().x) * nextTriangle.Area()
        }
        
        return 2.0 * π * result
    }
    
    func MagneticFieldEnergy(isFlat:Bool, units:FE_Mesh.Units = .meters) -> Double
    {
        // NOTE: For now, make your life easier, define all problems in meters
        var result = 0.0
        
        let µ0_fixed = µ0 * (units == .mm ? 0.001 : (units == .inch ? 0.0254 : 1.0))
        
        for nextTriangle in self.associatedTriangles
        {
            let pointValues = nextTriangle.ValuesAtCenterOfMass(coarse: true)
            
            var Bx = pointValues.V
            var By = -pointValues.U
            
            // This comes from Humphries 9.55
            if !isFlat
            {
                let r = Complex(real:nextTriangle.CenterOfMass().x)
                let oneOverR = Complex(real: 1.0) / r
                
                Bx *= -oneOverR
                By *= -oneOverR
            }
        
            var phaseAngleDiff = 0.0
            if Bx != Complex.ComplexZero
            {
                if By != Complex.ComplexZero
                {
                    phaseAngleDiff = abs(Bx.carg - By.carg)
                }
            }
            
            // We want Bxp and Bxn to be on the X-axis, so we create a Complex number with a real value of |Bx| and imag of 0.
            let BxAbs = Complex(real: Bx.cabs)
            let Bxp = BxAbs * 0.5
            let Bxn = Bxp
            
            // The Ey values are a bit more complicated
            let ByAbs = By.cabs
            let Byp = Complex(real: ByAbs * cos(π / 2 + phaseAngleDiff), imag: ByAbs * sin(π / 2 + phaseAngleDiff)) * 0.5
            let Byn = Complex(real: ByAbs * cos(π / 2 - phaseAngleDiff), imag: ByAbs * sin(π / 2 - phaseAngleDiff)) * 0.5
            
            let Bp = Bxp + Byp
            let Bn = Bxn + Byn
            
            let Babs = Bp.cabs + Bn.cabs
            
            let µm = Babs * Babs / (2.0 * µ0_fixed * self.µRel.real)
            
            result += µm * nextTriangle.Area()
        }
        
        return result
    }
    
    func ElectricFieldEnergy(isFlat:Bool, units:FE_Mesh.Units) -> Double
    {
        let ε0_fixed = ε0 * (units == .mm ? 0.001 : (units == .inch ? 0.0254 : 1.0))
        var result = 0.0
        DLog("For \(self.associatedTriangles.count) triangles")
        
        for nextTriangle in self.associatedTriangles
        {
            let values = nextTriangle.ValuesAtCenterOfMass(coarse: true)
            
            // per Humphries 2.53, both Ex and Ey are the negatives of U and V
            let Ex = -values.U
            let Ey = -values.V
            
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
