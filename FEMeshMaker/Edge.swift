//
//  Edge.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-06.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation

class Edge:Hashable
{
    var hashValue: Int
    {
        return self.endPoint1.hashValue ^ self.endPoint2.hashValue &* 16777619
    }
    
    static func == (lhs:Edge, rhs:Edge) -> Bool
    {
        if lhs.endPoint1 == rhs.endPoint1
        {
            if (lhs.endPoint2 == rhs.endPoint2)
            {
                return true
            }
        }
        else if lhs.endPoint1 == rhs.endPoint2
        {
            if lhs.endPoint2 == rhs.endPoint1
            {
                return true
            }
        }
        
        return false
    }
    
    let endPoint1:Node
    let endPoint2:Node
    let marker:Int
    
    init(endPoint1:Node, endPoint2:Node)
    {
        // We'll arbitrarily set the marker to either of the endpoint markers that are non-zero (giving preference to endpoint1). Of course, in actuality, the two endpoints SHOULD have the same marker.
        if endPoint1.marker != 0
        {
            self.marker = endPoint1.marker
        }
        else if endPoint2.marker != 0
        {
            self.marker = endPoint2.marker
        }
        else
        {
            self.marker = 0
        }
        
        self.endPoint1 = endPoint1
        self.endPoint2 = endPoint2
        
        endPoint1.neighbours.insert(endPoint2)
        endPoint2.neighbours.insert(endPoint1)
    }
}
