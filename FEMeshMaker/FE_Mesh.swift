//
//  FE_Mesh.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-08.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// Base class for concrete finite element mesh classes. Note that the class offers support for either Double or Complex numbers. However, derived classes are free to enforce only one type if they wish (and they should throw up a warning or something if a routine calls a function of an unsupported type)

import Foundation
import Cocoa
import Accelerate



// This struct is used to help do hit testing in FIndTriangleWithPoint() in the FE_mesh class below
fileprivate struct TriangleEdge {
    
    let triangle:Element
    
    var eOrg:Node    // n0
    var eDest:Node   // n1
    var eOther:Node  // n2
    
    var eOnext:(A:Node, B:Node) {
        get
        {
            return (eOrg, eOther)
        }
    }
    
    var eDprev:(A:Node, B:Node) {
        get
        {
            return (eOther, eDest)
        }
    }
    
    var e:(A:Node, B:Node) {
        get
        {
            return (eOrg, eDest)
        }
    }
    
    init(withTriangle:Element)
    {
        self.triangle = withTriangle
        self.eOrg = withTriangle.corners.n0
        self.eDest = withTriangle.corners.n1
        self.eOther = withTriangle.corners.n2
    }
    
    func TriangleThatShares(edge:(A:Node, B:Node)) -> Element?
    {
        var sharedSet = edge.A.elements.intersection(edge.B.elements)
        
        if sharedSet.count == 1
        {
            return nil
        }
        
        sharedSet.remove(self.triangle)
        
        return sharedSet.first
    }
    
    // Returns a UNIT vector that represents the direction of edge.e
    func DirectionVector() -> NSPoint
    {
        let resultVector = NSPoint(x: eDest.vertex.x - eOrg.vertex.x, y: eDest.vertex.y - eOrg.vertex.y)
        let distance = DistanceBetween(A: self.eOrg, B: self.eDest)
        
        return NSPoint(x: resultVector.x / distance, y: resultVector.y / distance)
    }
    
    func IsOnBoundary() -> Bool
    {
        if eOrg.marker != 0 && eDest.marker != 0
        {
            return true
        }
        
        return false
    }
}

fileprivate func DistanceBetween(A:Node, B:Node) -> CGFloat
{
    let dX = B.vertex.x - A.vertex.x
    let dY = B.vertex.y - A.vertex.y
    
    let result = sqrt(dX * dX + dY * dY)
    
    return result
}

// This function is used by the FindTriangleWithPoint(:) function in the FE_Mesh class below. It returns true if the point X is STRICTLY to the right of the line AB.
fileprivate func IsRightOf(edge:(A:Node, B:Node), X:NSPoint) -> Bool
{
    // For a vector from A to B, and point X,
    // let result = ((Bx - Ax) * (Xy - Ay) - (By - Ay) * (Xx - Ax))
    // if result > 0, X is to the left of AB, < 0 to the Right, =0 on the line
    
    let result = ((edge.B.vertex.x - edge.A.vertex.x) * (X.y - edge.A.vertex.y) - (edge.B.vertex.y - edge.A.vertex.y) * (X.x - edge.A.vertex.x))
    
    return result < 0.0
}


class FE_Mesh:Mesh
{
    let precision:PCH_SparseMatrix.DataType
    var matrixA:PCH_SparseMatrix? = nil
    var complexMatrixB:[Complex] = []
    var doubleMatrixB:[Double] = []
    var holeZones:[MeshPath] = []
    
    var bounds:NSRect = NSRect(x: 0, y: 0, width: 0, height: 0)
    
    // We store the index of triangle of the last "hit" point that was queried and use it as the start point for the next query
    var lastHitTriangle:Element? = nil
    
    init(precision:PCH_SparseMatrix.DataType,  withPaths:[MeshPath], vertices:[NSPoint], regions:[Region], holes:[NSPoint])
    {
        self.precision = precision
        
        super.init(withPaths: withPaths, vertices: vertices, regions: regions, holes: holes)
        
        guard self.RefineMesh() else
        {
            ALog("Call to RefineMesh() failed!")
            return
        }
        
        var minPoint = NSPoint(x: Double.greatestFiniteMagnitude, y: Double.greatestFiniteMagnitude)
        var maxPoint = NSPoint(x: -Double.greatestFiniteMagnitude, y: -Double.greatestFiniteMagnitude)
        
        for nextNode in self.nodes
        {
            minPoint.x = min(minPoint.x, nextNode.vertex.x)
            minPoint.y = min(minPoint.y, nextNode.vertex.y)
            maxPoint.x = max(maxPoint.x, nextNode.vertex.x)
            maxPoint.y = max(maxPoint.y, nextNode.vertex.y)
        }
        
        self.bounds = NSRect(origin: minPoint, size: NSSize(width: maxPoint.x - minPoint.x, height: maxPoint.y - minPoint.y))
        
        // Hole zones are saved to do hit-testing later on.
        for nextHole in holes
        {
            var holeContainers:[MeshPath] = []
            for i in 0..<withPaths.count
            {
                if withPaths[i].path.contains(nextHole)
                {
                    holeContainers.append(withPaths[i])
                }
            }
            
            if holeContainers.count == 1
            {
                self.holeZones.append(holeContainers[0])
                continue
            }
            
            while holeContainers.count > 1
            {
                let pathToCheck = holeContainers.removeFirst()
                var pathIsInnermost = true
                for nextContainer in holeContainers
                {
                    if pathToCheck.path.bounds.contains(nextContainer.path.bounds)
                    {
                        pathIsInnermost = false
                        break
                    }
                }
                
                if pathIsInnermost
                {
                    holeContainers.removeAll()
                    holeContainers.append(pathToCheck)
                }
            }
            
            self.holeZones.append(holeContainers[0])
        }
        
        
    }
    
    func Solve() -> [Double]
    {
        // The first thing we do is convert A into a format recognized by the Apple routines
        guard let Apch = self.matrixA else
        {
            DLog("The A matrix has not been defined")
            return []
        }
        
        if self.doubleMatrixB.count == 0
        {
            DLog("The B matrix has not been defined")
            return []
        }
        
        guard Apch.cols == Apch.rows && Apch.rows == self.doubleMatrixB.count else
        {
            DLog("Illegal dimensions!")
            return []
        }
        
        let Asp = Apch.CreateSparseMatrix()
        
        // Use QR factorization
        let A = SparseFactor(SparseFactorizationQR, Asp)
        
        let B = PCH_SparseMatrix.CreateDenseVectorForDoubleVector(values: self.doubleMatrixB)
        
        let X = PCH_SparseMatrix.CreateEmptyVectorForDoubleVector(count: self.doubleMatrixB.count)
        
        SparseSolve(A, B, X)
        
        var result:[Double] = []
        for i in 0..<self.doubleMatrixB.count
        {
            result.append(X.data[i])
        }
        
        // The calling routine is responsible for getting rid of all the memory allocated by PCH_SparseMatrix routines. This is kind of ugly and I will consider moving this work back to the class.
        Asp.data.deallocate()
        Asp.structure.columnStarts.deallocate()
        Asp.structure.rowIndices.deallocate()
        
        B.data.deallocate()
        X.data.deallocate()
        
        // Apple routine for the factorization
        SparseCleanup(A)
        
        return result
    }
    
    func Solve() -> [Complex]
    {
        // The first thing we do is convert A into a format recognized by the Apple routines
        guard let Apch = self.matrixA else
        {
            DLog("The A matrix has not been defined")
            return []
        }
        
        if self.complexMatrixB.count == 0
        {
            DLog("The B matrix has not been defined")
            return []
        }
        
        guard Apch.cols == Apch.rows && Apch.rows == self.complexMatrixB.count else
        {
            DLog("Illegal dimensions!")
            return []
        }
        
        let Asp = Apch.CreateSparseMatrix()
        
        // Use QR factorization
        let A = SparseFactor(SparseFactorizationQR, Asp)
        
        let B = PCH_SparseMatrix.CreateDenseMatrixForComplexVector(values: self.complexMatrixB)
        
        let X = PCH_SparseMatrix.CreateEmptyMatrixForComplexVector(count: self.complexMatrixB.count)
        
        SparseSolve(A, B, X)
        
        var result:[Complex] = []
        for i in 0..<self.complexMatrixB.count
        {
            let real = X.data[2 * i]
            let imag = X.data[2 * i + 1]
            
            result.append(Complex(real: real, imag: imag))
        }
        
        // The calling routine is responsible for getting rid of all the memory allocated by PCH_SparseMatrix routines. This is kind of ugly and I will consider moving this work back to the class.
        Asp.data.deallocate()
        Asp.structure.columnStarts.deallocate()
        Asp.structure.rowIndices.deallocate()
        
        B.data.deallocate()
        X.data.deallocate()
        
        // Apple routine for the factorization
        SparseCleanup(A)
        
        return result
    }
    
    func SetNodePhiValuesTo(_ values:[Double])
    {
        if values.count != self.nodes.count
        {
            ALog("Mismatched number of values to number of nodes")
            return
        }
        
        for i in 0..<values.count
        {
            self.nodes[i].phi = Complex(real: values[i])
        }
    }
    
    func SetNodePhiValuesTo(_ values:[Complex])
    {
        if values.count != self.nodes.count
        {
            ALog("Mismatched number of values to number of nodes")
            return
        }
        
        for i in 0..<values.count
        {
            self.nodes[i].phi = values[i]
        }
    }
    
    func Setup_A_Matrix()
    {
        self.matrixA = PCH_SparseMatrix(type: self.precision, rows: self.nodes.count, cols: self.nodes.count)
        
        for nextNode in self.nodes
        {
            CalculateCouplingConstants(node: nextNode)
        }
    }
    
    func SetupComplexBmatrix()
    {
        self.complexMatrixB = Array(repeating: Complex.ComplexNan, count: self.nodes.count)
        for nextNode in self.nodes
        {
            CalculateRHSforNode(node: nextNode)
        }
    }
    
    func SetupDoubleBmatrix()
    {
        self.doubleMatrixB = Array(repeating: Double.greatestFiniteMagnitude, count: self.nodes.count)
        for nextNode in self.nodes
        {
            CalculateRHSforNode(node: nextNode)
        }
    }
    
    // This function uses the "better" algorithm on page 10 of this document: http://www.cl.cam.ac.uk/techreports/UCAM-CL-TR-728.pdf
    // The point could be in a triangle or in a "hole" (usually a section with a prescribed-value boundary zone), which means we can return either one.
    func FindZoneWithPoint(X:NSPoint) -> Zone
    {
        var result = Zone(triangle: nil, zone: nil)
        // check first to make sure the point is within our mesh's boundaries
        if !self.bounds.contains(X)
        {
            DLog("Point is outside the mesh bounds!")
            return result
        }
        
        // Now do the simple test to see if X is in one of the mesh "holes"
        for nextHole in self.holeZones
        {
            if nextHole.path.contains(X)
            {
                return Zone(triangle: nil, zone: nextHole.boundary)
            }
        }
        
        // As a start point, we'll choose a random triangle in the mesh UNLESS we've already done a search in which case we'll use the last triangle as our start point. We also want to avoid a triangle where any of the points are on a boundary.
        var startingTriangle:Element? = self.lastHitTriangle
        while startingTriangle == nil
        {
            let triangleIndex = (self.lastHitTriangle == nil ? Int(drand48() * Double(self.elements.count - 1)) : -1)
            startingTriangle = self.elements[triangleIndex]
            
            if let corners = startingTriangle?.corners
            {
                if corners.n0.marker != 0 || corners.n1.marker != 0 || corners.n2.marker != 0
                {
                    startingTriangle = nil
                }
            }
        }
        
        guard var currentTriangle = startingTriangle else
        {
            DLog("Couldn't come up with a suitable element to start!")
            return result
        }
        
        // Maybe our initial guess was the right one!
        if currentTriangle.ElementAsPath().contains(X)
        {
            return Zone(triangle: currentTriangle, zone: nil)
        }
        
        var edge = TriangleEdge(withTriangle: currentTriangle)
        if IsRightOf(edge: edge.e, X: X)
        {
            if let newTriangle = edge.TriangleThatShares(edge: edge.e)
            {
                newTriangle.NormalizeOn(n0: edge.eDest)
                currentTriangle = newTriangle
                edge = TriangleEdge(withTriangle: currentTriangle)
            }
            else
            {
                DLog("This should NOT happen!")
                return result
            }
        }
        
        // At this point, X is guaranteed to be to the LEFT of edge.
        
        // Strategy to get around holes:
        // If edge is on a boundary:
        // Goto eDest and find its next neighbour (if any) that is also on the boundary. Continue until there is no neighbour on the boundary. Choose the neighbor that is in the same general direction as the last boundary edge and set it to edge.
        
        while true
        {
            if edge.IsOnBoundary()
            {
                let direction = edge.DirectionVector()
                
                // 1) find a neighbor node to eDest that is on the same boundary and in the same direction
                // 2) repeat until no neighbour nodes in the same direction that are on teh boundary
                // 3) choose a node that is in the same general direction
                // 4) Create the new edge with the triangle that has eOrg on the boundary and eDest that is not
            }
            
            if currentTriangle.ElementAsPath().contains(X)
            {
                return Zone(triangle: currentTriangle, zone: nil)
            }
            
            var whichOp = 0
            if !IsRightOf(edge: edge.eOnext, X: X)
            {
                whichOp += 1
            }
            if !IsRightOf(edge: edge.eDprev, X: X)
            {
                whichOp += 2
            }
            
            if whichOp == 0
            {
                return Zone(triangle: currentTriangle, zone: nil)
            }
            else if whichOp == 1
            {
                if let newTriangle = edge.TriangleThatShares(edge: edge.eOnext)
                {
                    newTriangle.NormalizeOn(n0: edge.eOrg)
                    currentTriangle = newTriangle
                    edge = TriangleEdge(withTriangle: currentTriangle)
                }
                else
                {
                    // TODO: Fix this to take care of holes! This is where the real fun will happen
                    DLog("The edge is on a boundary!")
                    return result
                }
            }
            else if whichOp == 2
            {
                if let newTriangle = edge.TriangleThatShares(edge: edge.eDprev)
                {
                    newTriangle.NormalizeOn(n0: edge.eOther)
                    currentTriangle = newTriangle
                    edge = TriangleEdge(withTriangle: currentTriangle)
                }
                else
                {
                    // TODO: Fix this to take care of holes! This is where the real fun will happen
                    DLog("The edge is on a boundary!")
                    return result
                }
            }
        }
        
        //return result
    }
    
    struct Zone {
        
        var triangle:Element? = nil
        var zone:Boundary? = nil
    }
    
    func CalculateCouplingConstants(node:Node)
    {
        ALog("This function must be overridden in concrete subclasses!")
    }
    
    func CalculateRHSforNode(node:Node)
    {
        ALog("This function must be overridden in concrete subclasses!")
    }
}
