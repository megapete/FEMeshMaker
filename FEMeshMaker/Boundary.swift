//
//  Boundary.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-04-11.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// Base class for boundaries and other surfaces with fixed values

import Foundation

class Boundary
{
    let tag:Int
    
    let description:String
    
    init(tag:Int, description:String)
    {
        self.tag = tag
        self.description = description
    }
}
