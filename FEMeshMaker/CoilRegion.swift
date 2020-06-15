//
//  CoilRegion.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-05-20.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation

class CoilRegion:ConductorRegion
{
    enum StrandShapes {
        case round
        case rect
    }
    
    let bounds:NSRect
    
    let N:Double // number of turns
    let Nrad:Double // number of conductors radially
    
    let strandsPerTurn:Int
    let strandDim:(radial:CGFloat, axial:CGFloat)
    let strandJ:Double
    let strandShape:StrandShapes
    
    var strandArea:CGFloat
    {
        get
        {
            if self.strandShape == .rect
            {
                return self.strandDim.radial * self.strandDim.axial
            }
            
            let r = self.strandDim.radial / 2.0
            
            return CGFloat(π) * r * r
        }
    }
    
    override var resistivity:Double
    {
        get
        {
            let totalArea = self.bounds.width * self.bounds.height
            let conductorArea = self.N * Double(self.strandArea) * Double(strandsPerTurn)
            
            return super.resistivity * Double(totalArea) / conductorArea
        }
    }
    
    init(type:CommonConductors, electrode:Electrode? = nil, currentDensity:Complex, jIsRMS:Bool = false, description:String, tagBase:Int, refPoints:[NSPoint] = [NSPoint(x: 0.0, y: 0.0)], N:Double, Nradial:Double, strandsPerTurn:Int, strandDim:(radial:CGFloat, axial:CGFloat), strandShape:StrandShapes = .rect, strandJ:Double, bounds:NSRect, isVirtualHole:Bool = false)
    {
        self.bounds = bounds
        self.N = N
        self.Nrad = Nradial
        self.strandDim = strandDim
        self.strandShape = strandShape
        self.strandJ = strandJ
        self.strandsPerTurn = strandsPerTurn
        
        if let electrodeBoundary = electrode
        {
            super.init(type: type, electrode: electrodeBoundary, currentDensity:currentDensity, jIsRMS:jIsRMS, tagBase: tagBase, refPoints: refPoints, isVirtualHole: isVirtualHole)
        }
        else
        {
            super.init(type: type, currentDensity: currentDensity, jIsRMS:jIsRMS, description: description, tagBase: tagBase, refPoints: refPoints, isVirtualHole: isVirtualHole)
        }
    }
    
    func TotalDCLossAt(tempInC:Double) -> Double
    {
        let LMT = Double(2.0 * self.bounds.origin.x + self.bounds.width) * π
        let conductorVolume = self.N * Double(self.strandsPerTurn) * Double(self.strandArea) * LMT
        
        return self.DCLossPerVolumeAt(tempInC:tempInC) * conductorVolume
    }
    
    func DCLossPerVolumeAt(tempInC:Double) -> Double
    {
        // I calculated this by hand and found out that the DC loss per volume is equal to J*J*r where 'r' is the resistivity of the strand material
        let newres = super.resistivity * self.ResistivityFactorAt(tempInC: tempInC)
        
        return self.strandJ * self.strandJ * newres
    }
    
    func TotalEddyLossAt(tempInC:Double) -> Double
    {
        // This routine assumes that the triangles that make up the region have had their valueArray set as follows: valueArray[0] = Br and valueArray[1] = Bz
        
        var result = 0.0
        
        for nextTriangle in self.associatedTriangles
        {
            let lmt = 2.0 * Double(nextTriangle.CenterOfMass().x) * π
            let volume = lmt * nextTriangle.Area()
            let lossPerVol = self.EddyLossPerVolumeWithB((r:nextTriangle.valueArray[0], z:nextTriangle.valueArray[1]), atFrequency: 60.0, atTempInC: tempInC)
            
            let loss = lossPerVol * volume
            
            result += loss
        }
        
        return result
    }
    
    func EddyLossPerVolumeWithB(_ B:(r:Complex, z:Complex), atFrequency freq:Double, atTempInC:Double) -> Double
    {
        // This all comes from Andersen's paper on Transformer Leakage Flux. Note that I have confirmed that OUTMET and OUTENG use formulas (38) and (39) from that paper without any modification, even when using FLD8 to get the B-Fields (and so current densities). If all dimensions are in meters, this returns watts per cubic meter.
        
        let BrAbs = B.r.cabs
        let BzAbs = B.z.cabs
        
        let baseFactor = super.conductivity * self.ConductivityFactorAt(tempInC: atTempInC) / 6.0 * (π * π * freq * freq)
        
        let d = Double(self.strandDim.radial)
        let w = Double(self.strandDim.axial)
        let eddyLossPerVolumeDueToAxialFlux = baseFactor * d * d * BzAbs * BzAbs
        let eddyLossPerVolumeDueToRadialFlux = baseFactor * w * w * BrAbs * BrAbs
        
        return eddyLossPerVolumeDueToAxialFlux + eddyLossPerVolumeDueToRadialFlux
    }
}
