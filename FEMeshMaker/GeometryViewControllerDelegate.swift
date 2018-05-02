//
//  GeometryViewControllerDelegate.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-27.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This is probably overkill, but I've decided to create a protocol for a GeometryViewControllerDelegate, just to get my feet wet.

import Foundation
import Cocoa

protocol GeometryViewControllerDelegate
{
    func FindTriangleWithPoint(point:NSPoint) -> Element?
    
    func DataForPoint(point:NSPoint) -> GeometryViewController.PointData
    
    func MinMaxFieldIntensity() -> (minField:Double, maxField:Double)?
}
