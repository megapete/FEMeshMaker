//
//  MeshPath.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-04-11.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation
import Cocoa

class MeshPath
{
    let path:NSBezierPath
    
    let boundary:Boundary?
    
    init(path:NSBezierPath, boundary:Boundary?)
    {
        self.path = path
        self.boundary = boundary
    }
}
