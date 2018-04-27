//
//  GeometryViewControllerDelegate.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-27.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This is probably overkill, but I've decided to create a protocol for a GeometryViewControllerDelegate, just to get my feet wet.

import Foundation

protocol GeometryViewControllerDelegate {
    
    func FindTriangleWithPoint(point:NSPoint) -> Element?
    
    func DataForPoint(point:NSPoint) -> GeometryViewController.PointData
}
