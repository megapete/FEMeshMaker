//
//  Edge.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-06.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation

class Edge
{
    let endPoint1:Node
    let endPoint2:Node
    
    init(endPoint1:Node, endPoint2:Node)
    {
        self.endPoint1 = endPoint1
        self.endPoint2 = endPoint2
    }
}
