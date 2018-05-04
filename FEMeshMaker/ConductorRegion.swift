//
//  ConductorRegion.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-05-03.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation
import Cocoa

// Conductor regions are zones that (usually) have a presribed potential and/or constant current density throughout the region.

class ConductorRegion: Region
{
    enum CommonConductors {
        case copper
        case aluminum
        case silver
    }
    
    let type:CommonConductors
    
    // resistivity in ohm-meters
    var resistivity:Double
    {
        get
        {
            if self.type == .copper
            {
                return 1.68E-8
            }
            else if self.type == .aluminum
            {
                return 2.65E-8
            }
            else if self.type == .silver
            {
                return 1.59E-8
            }
            else
            {
                DLog("Unknown type")
                return -1.0
            }
        }
    }
    
    var conductivity:Double
    {
        get
        {
            return 1.0 / self.resistivity
        }
    }
    
    // The electrode with which the conductor is associated, if any. If this region has a prescribed voltage, then it should be set in the electrode and then the electrode set here.
    var electrode:Electrode?
    
    var currentDensity:Complex
    
    init(type:CommonConductors, electrode:Electrode, currentDensity:Complex, tagBase:Int, refPoints:[NSPoint] = [NSPoint(x: 0.0, y: 0.0)], isVirtualHole:Bool = false)
    {
        self.type = type
        self.electrode = electrode
        self.currentDensity = currentDensity
        
        super.init(tagBase: tagBase, description: electrode.description, refPoints: refPoints, isVirtualHole: isVirtualHole)
    }
    
    init(type:CommonConductors, currentDensity:Complex, description:String, tagBase:Int, refPoints:[NSPoint] = [NSPoint(x: 0.0, y: 0.0)], isVirtualHole:Bool = false)
    {
        self.type = type
        self.electrode = nil
        self.currentDensity = currentDensity
        
        super.init(tagBase: tagBase, description: description, refPoints: refPoints, isVirtualHole: isVirtualHole)
    }
    
    init(type:CommonConductors, electrode:Electrode, tagBase:Int, refPoints:[NSPoint] = [NSPoint(x: 0.0, y: 0.0)], isVirtualHole:Bool = false)
    {
        self.type = type
        self.electrode = electrode
        self.currentDensity = Complex.ComplexZero
        
        super.init(tagBase: tagBase, description: electrode.description, refPoints: refPoints, isVirtualHole: isVirtualHole)
    }
}