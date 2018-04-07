//
//  Node.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-06.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation

class Node:Hashable
{
    // To get the class to conform to Hashable, we need to define hashValue and ==
    
    var hashValue: Int
    {
        // This comes from Apple's documentation on Hashable. Note that in Swift, if an operation causes an overflow, the program crashes. We don't want this behaviour, so we use the '&*' to make it rollover instead. The point of the hashValue is to reduce the number of times the underlying code actually calls '=='. That is, comparing hashCodes is really fast, while the '==' code will be slower, so the code compares hashTags first and only calls '==' if the hashCodes match.
        return self.vertex.x.hashValue ^ self.vertex.y.hashValue &* 16777619
    }
    
    static func == (lhs:Node, rhs:Node) -> Bool
    {
        return lhs.vertex.x == rhs.vertex.x && lhs.vertex.y == rhs.vertex.y
    }
    
    // Properties
    
    // A number that is used by Triangle to identify the node
    let tag:Int
    
    // The point where the node is located
    let vertex:NSPoint
    
    // The current "value" of the Node
    
    
    // A set of neighbours to the Node
    var neighbours:Set<Node> = []
    
    // The elements that have this Node as a corner
    var elements:Set<Element> = []
    
    // Designated initializer
    init(tag:Int, vertex:NSPoint)
    {
        self.tag = tag
        self.vertex = vertex
    }
    
    convenience init()
    {
        self.init(tag: -1, vertex: NSPoint(x: Double.greatestFiniteMagnitude, y: Double.greatestFiniteMagnitude))
    }
}
