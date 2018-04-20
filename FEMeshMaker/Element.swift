//
//  Element.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-06.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// The basic triangular element that makes up the mesh.

import Foundation
import Cocoa

class Element:Hashable, CustomStringConvertible
{
    
    var description: String
    {
        let cOfM = self.CenterOfMass()
        return "CofM(\(cOfM.x), \(cOfM.y))"
    }
    
    // To get the class to conform to Hashable, we need to define hashValue and ==
    
    var hashValue: Int
    {
        return self.corners.n0.hashValue ^ self.corners.n1.hashValue ^ self.corners.n2.hashValue &* 16777619
    }
    
    static func == (lhs:Element, rhs:Element) -> Bool
    {
        let leftN0 = lhs.corners.n0
        let leftN1 = lhs.corners.n1
        let leftN2 = lhs.corners.n2
        let rightN0 = rhs.corners.n0
        let rightN1 = rhs.corners.n1
        let rightN2 = rhs.corners.n2
        
        if leftN0 == rightN0
        {
            if leftN1 == rightN1
            {
                if leftN2 == rightN2
                {
                    return true
                }
            }
            else if leftN1 == rightN2
            {
                if leftN2 == rightN1
                {
                    return true
                }
            }
        }
        else if leftN0 == rightN1
        {
            if leftN1 == rightN0
            {
                if leftN2 == rightN2
                {
                    return true
                }
            }
            else if leftN1 == rightN2
            {
                if leftN2 == rightN0
                {
                    return true
                }
            }
        }
        else if leftN0 == rightN2
        {
            if leftN1 == rightN0
            {
                if leftN2 == rightN1
                {
                    return true
                }
            }
            else if leftN1 == rightN1
            {
                if leftN2 == rightN0
                {
                    return true
                }
            }
        }
        
        return false
    }
    
    // let tag:Int
    
    var region:Region?
    
    var neighbours:[Element] = []
    
    var corners:(n0:Node, n1:Node, n2:Node)
    
    var value:Complex = Complex(real: 0.0, imag: 0.0)
    
    init(n0:Node, n1:Node, n2:Node, region:Region? = nil)
    {
        // self.tag = tag
        self.corners = (n0, n1, n2)
        self.region = region
        
        // Set self as being one of the triangles that each of the nodes is used for
        n0.elements.insert(self)
        n1.elements.insert(self)
        n2.elements.insert(self)
    }
    
    func ElementAsPath() -> NSBezierPath
    {
        let result = NSBezierPath()
        
        result.move(to: self.corners.n0.vertex)
        result.line(to: self.corners.n1.vertex)
        result.line(to: self.corners.n2.vertex)
        result.close()
        
        return result
    }
    
    func Height() -> Double
    {
        let minY = min(self.corners.n0.vertex.y, self.corners.n1.vertex.y, self.corners.n2.vertex.y)
        let maxY = max(self.corners.n0.vertex.y, self.corners.n1.vertex.y, self.corners.n2.vertex.y)
        
        return Double(maxY - minY)
    }
    
    func Width() -> Double
    {
        let minX = min(self.corners.n0.vertex.x, self.corners.n1.vertex.x, self.corners.n2.vertex.x)
        let maxX = max(self.corners.n0.vertex.x, self.corners.n1.vertex.x, self.corners.n2.vertex.x)
        
        return Double(maxX - minX)
    }
    
    func ContainsPoint(point:NSPoint) -> Bool
    {
        let path = NSBezierPath()
        path.move(to: self.corners.n0.vertex)
        path.line(to: self.corners.n1.vertex)
        path.line(to: self.corners.n2.vertex)
        path.close()
        
        return path.contains(point)
    }
    
    // This cotan function comes from Humphries Eq. 2.47
    func CotanThetaA() -> Double
    {
        let area = self.Area()
        
        if area < 0.0
        {
            ALog("Bad triangle!")
        }
        
        let y2MinusY1 = self.corners.n2.vertex.y - self.corners.n1.vertex.y
        let x2MinusX1 = self.corners.n2.vertex.x - self.corners.n1.vertex.x
        
        let result = (-(self.corners.n1.vertex.y - self.corners.n0.vertex.y) * y2MinusY1 - (self.corners.n1.vertex.x - self.corners.n0.vertex.x) * x2MinusX1)
        
        return Double(result) / (2.0 * area)
    }
    
    // This cotan function comes from Humphries Eq. 2.49
    func CotanThetaB() -> Double
    {
        let area = self.Area()
        
        if area < 0.0
        {
            ALog("Bad triangle!")
        }
        
        let y2MinusY1 = self.corners.n2.vertex.y - self.corners.n1.vertex.y
        let x2MinusX1 = self.corners.n2.vertex.x - self.corners.n1.vertex.x
        
        let result = ((self.corners.n2.vertex.y - self.corners.n0.vertex.y) * y2MinusY1 - (self.corners.n2.vertex.x - self.corners.n0.vertex.x) * x2MinusX1)
        
        return Double(result) / (2.0 * area)
    }
    
    func CenterOfMass() -> NSPoint
    {
        let resultX = (self.corners.n0.vertex.x + self.corners.n1.vertex.x + self.corners.n2.vertex.x) / 3.0
        let resultY = (self.corners.n0.vertex.y + self.corners.n1.vertex.y + self.corners.n2.vertex.y) / 3.0
        
        return NSPoint(x: resultX, y: resultY)
    }
    
    // This comes from my ObjC version of this class, which comes from Humphries Eq. 2.39
    func Area() -> Double
    {
        let result = ((self.corners.n1.vertex.x - self.corners.n0.vertex.x) * (self.corners.n2.vertex.y - self.corners.n0.vertex.y) - (self.corners.n2.vertex.x - self.corners.n0.vertex.x) * (self.corners.n1.vertex.y - self.corners.n0.vertex.y)) / 2.0
        
        return Double(result)
    }
    
    // Normalize self
    func NormalizeOn(n0:Node)
    {
        if n0 == self.corners.n0
        {
            return
        }
        else if n0 == self.corners.n1
        {
            let oldN0 = self.corners.n0
            self.corners.n0 = self.corners.n1
            self.corners.n1 = self.corners.n2
            self.corners.n2 = oldN0
        }
        else if n0 == self.corners.n2
        {
            let oldN0 = self.corners.n0
            let oldN1 = self.corners.n1
            self.corners.n0 = self.corners.n2
            self.corners.n1 = oldN0
            self.corners.n2 = oldN1
        }
        else
        {
            ALog("The node passed is not a corner of the element!")
        }
    }
    
    // Return a new node, normalized on self
    func NormalizedOn(n0:Node) -> Element
    {
        let result = Element(n0:self.corners.n0, n1:self.corners.n1, n2:self.corners.n2, region:self.region)
        
        result.NormalizeOn(n0: n0)
        
        return result
    }
    
    func HasEdge(A:Node, B:Node) -> Bool
    {
        if self.corners.n0 == A
        {
            if self.corners.n1 == B || self.corners.n2 == B
            {
                return true
            }
        }
        else if self.corners.n1 == A
        {
            if self.corners.n0 == B || self.corners.n2 == B
            {
                return true
            }
        }
        else if self.corners.n2 == A
        {
            if self.corners.n0 == B || self.corners.n1 == B
            {
                return true
            }
        }
        
        return false
    }
    
    // For the edge n0-n1 of this triangle, there will be either zero (if the edge is on a boundary) or one triangle that shares that edge. Return that triangle, if any.
    func TriangleThatShares(edge:(A:Node, B:Node)) -> Element?
    {
        let resultSet = self.corners.n0.elements.intersection(self.corners.n1.elements)
        
        if resultSet.count == 0
        {
            return nil
        }
        else if resultSet.count > 1
        {
            ALog("WTF???")
            return nil
        }
        
        return resultSet.first!
    }
}







