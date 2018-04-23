//
//  TriangleEdge.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-04-22.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation

// This struct is used to help do hit testing in FindTriangleWithPoint() in the FE_mesh class. It is based on the structure described in the paper http://www.cl.cam.ac.uk/techreports/UCAM-CL-TR-728.pdf.

struct TriangleEdge:CustomStringConvertible
{
    var description: String
    {
        return "e(\(self.Org) - \(self.Dest)"
    }
    
    var Org:Node    // n0
    var Dest:Node   // n1
    var Other:Node  // n2
    
    var Onext:(A:Node, B:Node) {
        get
        {
            return (self.Org, self.Other)
        }
    }
    
    var Dprev:(A:Node, B:Node) {
        get
        {
            return (self.Other, self.Dest)
        }
    }
    
    var e:(A:Node, B:Node) {
        get
        {
            return (self.Org, self.Dest)
        }
    }
    
    var triangle:Element? {
        get
        {
            return self.Org.elements.intersection(self.Dest.elements).intersection(self.Other.elements).first
        }
    }
    
    init(e:(Org:Node, Dest:Node), Other:Node)
    {
        self.Org = e.Org
        self.Dest = e.Dest
        self.Other = Other
    }
    
    init?(oldTriangleEdge:TriangleEdge, new_e:(Org:Node, Dest:Node))
    {
        let oldTriangleCheck = oldTriangleEdge.triangle
        
        guard let oldTriangle = oldTriangleCheck else
        {
            ALog("Could not find triangle!")
            return nil
        }
        
        var triangleSet = new_e.Org.elements.intersection(new_e.Dest.elements)
        
        if triangleSet.count == 1
        {
            return nil
        }
        
        var triangleToRemove:Element?
        for nextTriangle in triangleSet
        {
            if nextTriangle == oldTriangle
            {
                triangleToRemove = nextTriangle
                break
            }
        }
        
        triangleSet.remove(triangleToRemove!)
        
        let newTriangle = triangleSet.first!.NormalizedOn(n0: new_e.Org)
        
        self.init(e: new_e, Other: newTriangle.corners.n2)
    }
    
    // A convenient way to flip e
    func SymmetricEdge() -> TriangleEdge?
    {
        return TriangleEdge(oldTriangleEdge: self, new_e: (self.Dest, self.Org))
    }
    
    // Some utility functions that I have declared as static members of the struct to avoid namespace issues
    
    // Convenient way to find the direction of an edge
    static func Direction(edge:(A:Node, B:Node)) -> NSPoint
    {
        return edge.A.Direction(toNode: edge.B)
    }
    
    
    static func DirectionDifference(dir1:NSPoint, dir2:NSPoint) -> CGFloat
    {
        let angle1 = atan2(dir1.y, dir1.x)
        let angle2 = atan2(dir2.y, dir2.x)
        
        var result = fabs(Double(angle1 - angle2))
        if result > π
        {
            result = 2.0 * π - result
        }
        
        return CGFloat(result)
    }
    
    
    // The distance between an edge and a point is the distance from the edge's center point and the other point
    static func DistanceBetween(edge:(A:Node, B:Node), Bpt:NSPoint) -> CGFloat
    {
        let edgeCenterX = (edge.A.vertex.x + edge.B.vertex.x) / 2.0
        let edgeCenterY = (edge.A.vertex.y + edge.B.vertex.y) / 2.0
        
        let dX = Bpt.x - edgeCenterX
        let dY = Bpt.y - edgeCenterY
        
        let result = sqrt(dX * dX + dY * dY)
        
        return result
    }
    
    // This function is used by the FindTriangleWithPoint(:) function in the FE_Mesh class below. It returns true if the point X is STRICTLY to the right of the line AB.
    static func IsRightOf(edge:(A:Node, B:Node), X:NSPoint) -> Bool
    {
        // For a vector from A to B, and point X,
        // let result = ((Bx - Ax) * (Xy - Ay) - (By - Ay) * (Xx - Ax))
        // if result > 0, X is to the left of AB, < 0 to the Right, =0 on the line
        let x1 = edge.A.vertex.x
        let y1 = edge.A.vertex.y
        let x2 = edge.B.vertex.x
        let y2 = edge.B.vertex.y
        
        let x = X.x
        let y = X.y
        
        let result = (x - x1) * (y2 - y1) - (y - y1) * (x2 - x1)
        
        return result > 0.0
    }
}


