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
import Accelerate

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
    
    // A value that concrete subclasses of FE_Mesh can set to whatever they want (usually the triangle's internal field value)
    var value:Double = 0.0
    
    init(n0:Node, n1:Node, n2:Node, region:Region? = nil)
    {
        // self.tag = tag
        self.corners = (n0, n1, n2)
        self.region = region
        
        if let theRegion = region
        {
            theRegion.associatedTriangles.append(self)
        }
        
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
    
    func ValuesAtCenterOfMass(coarse:Bool) -> (phi:Complex, slopeX:Complex, slopeY:Complex)
    {
        if coarse
        {
            return self.ValuesAtPoint(self.CenterOfMass())
        }
        
        var result = LSF_ValuesAtPoint(self.CenterOfMass())
        
        if result.phi == Complex.ComplexNan
        {
            result = self.ValuesAtPoint(self.CenterOfMass())
        }
        
        return result
    }
    
    func ValuesAtPoint(_ point:NSPoint) -> (phi:Complex, slopeX:Complex, slopeY:Complex)
    {
        if !self.ElementAsPath().contains(point)
        {
            DLog("This triangle does not contain the point!")
            return (Complex.ComplexNan, Complex.ComplexNan, Complex.ComplexNan)
        }
        
        // The method employed here comes from Humphries, Table 7.2. Note that he calls the method "coarse" and suggests that it would be better to use a least-squares method with more vertices. Since we adopted Meeker's method of having more triangles, I think we should be okay, but if things become problematic, I will consider using least-squares (which I did, see below).
        let x0 = Complex(real: Double(self.corners.n0.vertex.x))
        let x1 = Complex(real: Double(self.corners.n1.vertex.x))
        let x2 = Complex(real: Double(self.corners.n2.vertex.x))
        
        let y0 = Complex(real: Double(self.corners.n0.vertex.y))
        let y1 = Complex(real: Double(self.corners.n1.vertex.y))
        let y2 = Complex(real: Double(self.corners.n2.vertex.y))
        
        let q0 = self.corners.n0.phi
        let q1 = self.corners.n1.phi
        let q2 = self.corners.n2.phi
        
        let A = ((q1 - q0) * (y2 - y0) - (q2 - q0) * (y1 - y0)) / ((x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0))
        let B = ((q1 - q0) * (x2 - x0) - (q2 - q0) * (x1 - x0)) / ((y1 - y0) * (x2 - x0) - (y2 - y0) * (x1 - x0))
        
        let xIn = Complex(real: point.x)
        let yIn = Complex(real: point.y)
        
        let phi = A * (xIn - x0) + B * (yIn - y0) + q0
        
        return (phi, -A, -B)
    }
    
    func LSF_ValuesAtPoint(_ thePoint:NSPoint) -> (phi:Complex, slopeX:Complex, slopeY:Complex)
    {
        // My attempt at using Least-Squares Fitting to find the value of the mesh at a point. I've used the method in Humphries section 7.2.
        
        // Note that this routine is stunningly slow, presumably because of the use of PCH_Matrix. It may be worth the agony of using LAPACK directly (or writing a specialized 6x6 matrix solving routine) instead of using PCH_Matrix.
        
        // So, I did as the above comment and its still fucking slow.
        
        // We start by getting a set of Nodes in the immediate vicinity of 'thePoint'. We need at least 6 Nodes for this to work. We will use the nodes on the corners of self, plus the set of neighbours to those points. In theory, this should easily get us at least 6 points, but there is a catch, as per Humphries: "A vertex is rejected if it is outside the solution region or if it is not connected to at least one triangle that has the same region number as the target element.", and "At Neumann boundaries an external point is added for each valid point inside the boundary. The new point has the same potential and the mirror position relative to the boundary."
        
        // TODO: Handle Neumann boundaries
        
        let minNodeCount = 6
        var nodeSet:Set<Node> = [self.corners.n0, self.corners.n1, self.corners.n2]
        
        guard let selfRegion = self.region else
        {
            ALog("Illlegal region!")
            return (Complex.ComplexNan, Complex.ComplexNan, Complex.ComplexNan)
        }
        
        // start with the corners of this element
        for nextCorner in [self.corners.n0, self.corners.n1, self.corners.n2]
        {
            // check each neighbor to make sure that it touches at least one triangle that is in the same Region as self and if so, add it to nodeSet
            for nextNeighbor in nextCorner.neighbours
            {
                var regionIsGood = false
                for nextElement in nextNeighbor.elements
                {
                    if selfRegion.associatedTriangles.contains(nextElement)
                    {
                        regionIsGood = true
                        break
                    }
                }
                
                if regionIsGood
                {
                    nodeSet.insert(nextNeighbor)
                }
            }
        }
        
        guard nodeSet.count >= minNodeCount else
        {
            DLog("Not enough nodes in set!")
            return (Complex.ComplexNan, Complex.ComplexNan, Complex.ComplexNan)
        }
        
        var bufferC = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: minNodeCount * minNodeCount)
        var bufferD = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: minNodeCount)
        
        var f:[Double] = Array(repeating: 0.0, count: minNodeCount)
        for nextNode in nodeSet
        {
            let Xi = Double(nextNode.vertex.x - thePoint.x)
            let Yi = Double(nextNode.vertex.y - thePoint.y)
            
            f[0] = 1.0
            f[1] = Xi
            f[2] = Yi
            f[3] = Xi * Xi
            f[4] = Xi * Yi
            f[5] = Yi * Yi
            
            for m in 0..<minNodeCount
            {
                bufferD[m] = __CLPK_doublecomplex(r: bufferD[m].r + nextNode.phi.real * f[m], i: bufferD[m].i + nextNode.phi.imag * f[m])
                
                for n in 0..<minNodeCount
                {
                    let mn = n * minNodeCount + m
                    bufferC[mn] = __CLPK_doublecomplex(r: bufferC[mn].r + f[m] * f[n], i: 0.0)
                }
            }
        }
        
        var n:__CLPK_integer = __CLPK_integer(minNodeCount)
        var nrhs = __CLPK_integer(1)
        var lda = n
        var ldb = n
        var ipiv = [__CLPK_integer](repeating: 0, count: minNodeCount)
        var info:__CLPK_integer = 0
        
        zgesv_(&n, &nrhs, &bufferC, &lda, &ipiv, &bufferD, &ldb, &info)
        
        if (info != 0)
        {
            DLog("Error in zgesv: \(info)")
            
            return (Complex.ComplexNan, Complex.ComplexNan, Complex.ComplexNan)
        }
        
        return (Complex(real: bufferD[0].r, imag: bufferD[0].i), Complex(real: bufferD[1].r, imag: bufferD[1].i), Complex(real: bufferD[2].r, imag: bufferD[2].i))
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
        
        let result = ((self.corners.n2.vertex.y - self.corners.n0.vertex.y) * y2MinusY1 + (self.corners.n2.vertex.x - self.corners.n0.vertex.x) * x2MinusX1)
        
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







