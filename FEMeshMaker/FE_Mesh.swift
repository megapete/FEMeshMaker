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
fileprivate struct TriangleEdge:CustomStringConvertible
{
    var description: String
    {
        return "Edge(\(self.eOrg) - \(self.eDest)"
    }
    
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
        
        /*
        if sharedSet.count == 1
        {
            return nil
        }
        */
        
        sharedSet.remove(self.triangle)
        
        return sharedSet.first
    }
    
    // Returns a UNIT vector that represents the direction of edge.e
    func DirectionVector() -> NSPoint
    {
        return Direction(A: eOrg, B: eDest)
        
    }
    
    func IsOnBoundary() -> Bool
    {
        if eOrg.marker != 0 && eDest.marker != 0
        {
            return true
        }
        
        return false
    }
    
    func BoundaryEdge() -> (A:Node, B:Node)?
    {
        var result:(A:Node, B:Node)? = nil
        
        if eOrg.marker > 0 && eDest.marker > 0
        {
            result = (eOrg, eDest)
        }
        else if eOrg.marker > 0 && eOther.marker > 0
        {
            result = (eOrg, eOther)
        }
        else if eOther.marker > 0 && eDest.marker > 0
        {
            result = (eOther, eDest)
        }
        
        return result
    }
    
    func TriangleEdgeIsOnBoundary() -> Bool
    {
        var boundaryCounter = 0
        
        if eOrg.marker > 0
        {
            boundaryCounter += 1
        }
        if eDest.marker > 0
        {
            boundaryCounter += 1
        }
        if eOther.marker > 0
        {
            boundaryCounter += 1
        }
        
        return boundaryCounter >= 2
    }
}

// Assumes the edge goes from A to B
fileprivate func Direction(A:Node, B:Node) -> NSPoint
{
    let resultVector = NSPoint(x: B.vertex.x - A.vertex.x, y: B.vertex.y - A.vertex.y)
    let distance = DistanceBetween(A: A, B: B)
    
    return NSPoint(x: resultVector.x / distance, y: resultVector.y / distance)
}

fileprivate func Direction(A:Node, Bpt:NSPoint) -> NSPoint
{
    let resultVector = NSPoint(x: Bpt.x - A.vertex.x, y: Bpt.y - A.vertex.y)
    let distance = DistanceBetween(A: A, Bpt: Bpt)
    
    return NSPoint(x: resultVector.x / distance, y: resultVector.y / distance)
}

fileprivate func DistanceBetween(A:Node, B:Node) -> CGFloat
{
    let dX = B.vertex.x - A.vertex.x
    let dY = B.vertex.y - A.vertex.y
    
    let result = sqrt(dX * dX + dY * dY)
    
    return result
}

fileprivate func DistanceBetween(A:Node, Bpt:NSPoint) -> CGFloat
{
    let dX = Bpt.x - A.vertex.x
    let dY = Bpt.y - A.vertex.y
    
    let result = sqrt(dX * dX + dY * dY)
    
    return result
}

fileprivate func DistanceBetween(edge:(A:Node, B:Node), Bpt:NSPoint) -> CGFloat
{
    let edgeCenterX = (edge.A.vertex.x + edge.B.vertex.x) / 2.0
    let edgeCenterY = (edge.A.vertex.y + edge.B.vertex.y) / 2.0
    
    let dX = Bpt.x - edgeCenterX
    let dY = Bpt.y - edgeCenterY
    
    let result = sqrt(dX * dX + dY * dY)
    
    return result
}

// This function is used by the FindTriangleWithPoint(:) function in the FE_Mesh class below. It returns true if the point X is STRICTLY to the right of the line AB.
fileprivate func IsRightOf(edge:(A:Node, B:Node), X:NSPoint) -> Bool
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
        let zeroResult = Zone(triangle: nil, zone: nil)
        // check first to make sure the point is within our mesh's boundaries
        if !self.bounds.contains(X)
        {
            DLog("Point is outside the mesh bounds!")
            return zeroResult
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
            return zeroResult
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
                return zeroResult
            }
        }
        
        DLog("Current triangle: \(currentTriangle)")
        
        // At this point, X is guaranteed to be to the LEFT of edge.
        
        // Strategy to get around holes:
        // If edge is on a boundary:
        // Goto eDest and find its next neighbour (if any) that is also on the boundary. Continue until there is no neighbour on the boundary. Choose the neighbor that is in the same general direction as the last boundary edge and set it to edge.
        
        while true
        {
            DLog("\(edge)")
            
            if edge.TriangleEdgeIsOnBoundary()
            {
                var boundaryEdge = edge.BoundaryEdge()!
                var boundaryEdgeDirection = Direction(A: boundaryEdge.A, B: boundaryEdge.B)
                
                let edgeDirection = edge.DirectionVector()
                // For dominant direction, 0 is x, 1 is y
                let dominantDirection = (fabs(edgeDirection.x) > fabs(edgeDirection.y) ? 0 : 1)
                
                if dominantDirection == 0
                {
                    // check if the boundary edge is going in the same direction as the dominant and if not, invert things
                    if edgeDirection.x * boundaryEdgeDirection.x < 0
                    {
                        boundaryEdge = (boundaryEdge.B, boundaryEdge.A)
                        boundaryEdgeDirection = Direction(A: boundaryEdge.A, B: boundaryEdge.B)
                    }
                    else if boundaryEdgeDirection.x == 0.0 // the edge goes perfectly up-down, so set Y instead
                    {
                        if edgeDirection.y * boundaryEdgeDirection.y < 0
                        {
                            boundaryEdge = (boundaryEdge.B, boundaryEdge.A)
                            boundaryEdgeDirection = Direction(A: boundaryEdge.A, B: boundaryEdge.B)
                        }
                    }
                }
                else
                {
                    // check if the boundary edge is going in the same direction as the dominant and if not, invert things
                    if edgeDirection.y * boundaryEdgeDirection.y < 0
                    {
                        boundaryEdge = (boundaryEdge.B, boundaryEdge.A)
                        boundaryEdgeDirection = Direction(A: boundaryEdge.A, B: boundaryEdge.B)
                    }
                    else if boundaryEdgeDirection.y == 0.0 //the edge goes perfectly left-right, so set X instead
                    {
                        if edgeDirection.x * boundaryEdgeDirection.x < 0
                        {
                            boundaryEdge = (boundaryEdge.B, boundaryEdge.A)
                            boundaryEdgeDirection = Direction(A: boundaryEdge.A, B: boundaryEdge.B)
                        }
                    }
                }
                
                var direction = boundaryEdgeDirection
                
                var nextNode = boundaryEdge.B
                
                while nextNode.marker != 0
                {
                    // 1) find a neighbor node to eDest that is on the same boundary and in the same direction
                    // 2) repeat until no neighbour nodes in the same direction that are on the boundary
                    var gotBoundaryNode = false
                    for nextNeighbour in nextNode.neighbours
                    {
                        if nextNeighbour.marker == nextNode.marker
                        {
                            if Direction(A: nextNode, B: nextNeighbour) == direction
                            {
                                nextNode = nextNeighbour
                                gotBoundaryNode = true
                                break
                            }
                        }
                    }
                    
                    if !gotBoundaryNode
                    {
                        // 3) Choose a node that is in the same general direction as X. That means we find the node whose direction vector is closest to that direction.
                        var vectorDiff = NSPoint(x: Double.greatestFiniteMagnitude, y: Double.greatestFiniteMagnitude)
                        let directionToX = Direction(A: nextNode, Bpt: X)
                        var bestNode = nextNode // dummy assign to satisfy the compiler
                        for nextNeighbour in nextNode.neighbours
                        {
                            let nextDirection = Direction(A: nextNode, B: nextNeighbour)
                            let nextDirectionDiff = NSPoint(x: nextDirection.x - directionToX.x, y: nextDirection.y - directionToX.y)
                            if nextDirectionDiff.x < vectorDiff.x && nextDirectionDiff.y < vectorDiff.y
                            {
                                vectorDiff = nextDirectionDiff
                                bestNode = nextNeighbour
                            }
                        }
                        
                        /*It is possible that bestNode is still on the boundary, only in a different direction, so check for that possibility
                        if bestNode.marker > 0
                        {
                            direction = Direction(A: nextNode, B: bestNode)
                            nextNode = bestNode
                        }
                        else
                        { */
                            // 4) Create the new edge with the triangle that has eOrg on the boundary and eDest that is not
                            // There will be up to two triangles that share edge.eDest and bestNode, choose the one that is NOT right of X
                        var triangleSet = nextNode.elements.intersection(bestNode.elements)
                        
                        if triangleSet.count == 0
                        {
                            DLog("An impossible condition has occurred")
                            return zeroResult
                        }
                        
                        let newTriangle = triangleSet.removeFirst()
                        let testEdge = TriangleEdge(withTriangle: newTriangle)
                        
                        // Be an optimist:
                        if newTriangle.ElementAsPath().contains(X)
                        {
                            return Zone(triangle: newTriangle, zone: nil)
                        }
                        
                        if IsRightOf(edge: testEdge.e, X: X)
                        {
                            if triangleSet.count == 0
                            {
                                DLog("Arrrggghhhh! That didn't work!")
                                return zeroResult
                            }
                            
                            currentTriangle = triangleSet.removeFirst().NormalizedOn(n0: testEdge.eDest)
                            edge = TriangleEdge(withTriangle: currentTriangle)
                            DLog("Current triangle: \(currentTriangle)")
                        }
                        
                    }
                }
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
                    DLog("Current triangle: \(currentTriangle)")
                    DLog("\(edge)")
                }
            }
            else if whichOp == 2
            {
                if let newTriangle = edge.TriangleThatShares(edge: edge.eDprev)
                {
                    newTriangle.NormalizeOn(n0: edge.eOther)
                    currentTriangle = newTriangle
                    edge = TriangleEdge(withTriangle: currentTriangle)
                    DLog("Current triangle: \(currentTriangle)")
                    DLog("\(edge)")
                }
                else
                {
                    let test = edge.TriangleThatShares(edge: edge.eDprev)
                    DLog("Returned triangle: \(test!)")
                    
                    return zeroResult
                }
                
            }
            else if whichOp == 3
            {
                if DistanceBetween(edge: edge.eOnext, Bpt: X) < DistanceBetween(edge: edge.eDprev, Bpt: X)
                {
                    // edge = edge.Onext
                    var triangleSet = edge.eOrg.elements.intersection(edge.eOther.elements)
                    if triangleSet.count == 0
                    {
                        let test = edge.eOrg.elements.intersection(edge.eOther.elements)
                        DLog("Oh, that's a bad one")
                    }
                    else if triangleSet.count == 1
                    {
                        if triangleSet.first! == currentTriangle
                        {
                            DLog("Fuckin' shit!")
                            return zeroResult
                        }
                    }
                    else
                    {
                        DLog("Current: \(currentTriangle)")
                        for nTri in triangleSet
                        {
                            DLog("\(nTri)")
                        }
                        
                        var trianglesToRemove:[Element] = []
                        for nextTriangle in triangleSet
                        {
                            if nextTriangle == currentTriangle
                            {
                                trianglesToRemove.append(nextTriangle)
                            }
                        }
                        triangleSet.subtract(trianglesToRemove)
                    }
                    currentTriangle = triangleSet.removeFirst().NormalizedOn(n0: edge.eOrg)
                    edge = TriangleEdge(withTriangle: currentTriangle)
                    DLog("Current triangle: \(currentTriangle)")
                    DLog("\(edge)")
                }
                else
                {
                    // edge = edge.Dprev
                    var triangleSet = edge.eOther.elements.intersection(edge.eDest.elements)
                    if triangleSet.count == 0
                    {
                        let test = edge.eOther.elements.intersection(edge.eDest.elements)
                        DLog("Oh, that's a bad one")
                    }
                    else if triangleSet.count == 1
                    {
                        if triangleSet.first! == currentTriangle
                        {
                            DLog("Fuckin' shit!")
                            return zeroResult
                        }
                    }
                    else
                    {
                        DLog("Current: \(currentTriangle)")
                        for nTri in triangleSet
                        {
                            DLog("\(nTri)")
                        }
                        
                        var trianglesToRemove:[Element] = []
                        for nextTriangle in triangleSet
                        {
                            if nextTriangle == currentTriangle
                            {
                                trianglesToRemove.append(nextTriangle)
                            }
                        }
                        triangleSet.subtract(trianglesToRemove)
                    }
                    currentTriangle = triangleSet.removeFirst().NormalizedOn(n0: edge.eOther)
                    edge = TriangleEdge(withTriangle: currentTriangle)
                    DLog("Current triangle: \(currentTriangle)")
                    DLog("\(edge)")
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
