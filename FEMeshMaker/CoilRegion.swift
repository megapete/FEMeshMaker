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
    
    let strandDim:(radial:CGFloat, axial:CGFloat)
    
    override var resistivity:Double
    {
        get
        {
            let totalArea = self.bounds.width * self.bounds.height
            let conductorArea = self.N * Double(self.strandDim.radial * self.strandDim.axial)
            
            return super.resistivity * Double(totalArea) / conductorArea
        }
    }
    
    init(type:CommonConductors, electrode:Electrode? = nil, currentDensity:Complex, jIsRMS:Bool = false, description:String, tagBase:Int, refPoints:[NSPoint] = [NSPoint(x: 0.0, y: 0.0)], N:Double, Nradial:Double, strandDim:(radial:CGFloat, axial:CGFloat), bounds:NSRect, isVirtualHole:Bool = false)
    {
        self.bounds = bounds
        self.N = N
        self.Nrad = Nradial
        self.strandDim = strandDim
        
        if let electrodeBoundary = electrode
        {
            super.init(type: type, electrode: electrodeBoundary, currentDensity:currentDensity, jIsRMS:jIsRMS, tagBase: tagBase, refPoints: refPoints, isVirtualHole: isVirtualHole)
        }
        else
        {
            super.init(type: type, currentDensity: currentDensity, jIsRMS:jIsRMS, description: description, tagBase: tagBase, refPoints: refPoints, isVirtualHole: isVirtualHole)
        }
    }
}
