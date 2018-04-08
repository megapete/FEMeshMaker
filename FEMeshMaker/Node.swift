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
    
    // The current "value" of the Node. Note that we save Complex numbers for this value, even if it is only real.
    var phi:Complex = Complex(real: 0, imag: 0)
    
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
    
    func SortedArrayOfTriangles() -> [Element]
    {
        let result = Array(self.elements).sorted { (elem1, elem2) -> Bool in
            
            let delta1 = NSPoint(x: elem1.CenterOfMass().x - self.vertex.x, y: elem1.CenterOfMass().y - self.vertex.y)
            let delta2 = NSPoint(x: elem2.CenterOfMass().x - self.vertex.x, y: elem2.CenterOfMass().y - self.vertex.y)
            
            var angle1 = atan2(delta1.y, delta1.x)
            if angle1 < 0.0
            {
                angle1 += CGFloat(2.0 * π)
            }
            
            var angle2 = atan2(delta2.y, delta2.x)
            if angle2 < 0.0
            {
                angle2 += CGFloat(2.0 * π)
            }
            
            return angle1 < angle2
            
        }
        
        return result
    }
}
