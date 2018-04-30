//
//  FE_Mesh.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-08.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// Base class for concrete finite element mesh classes. Note that the class offers support for either Double or Complex numbers. However, derived classes are free to enforce only one type if they wish (and they should throw up a warning or something if a routine calls a function of an unsupported type). Note that derived classes MUST also adopt the FE_MeshProtocol to enforce a standardized way of accessing the mesh data.

import Foundation
import Cocoa
import Accelerate

class FE_Mesh:Mesh
{
    enum Units {
        case inch
        case mm
    }
    
    let precision:PCH_SparseMatrix.DataType
    var matrixA:PCH_SparseMatrix? = nil
    var complexMatrixB:[Complex] = []
    var doubleMatrixB:[Double] = []
    var holeZones:[MeshPath] = []
    
    let units:Units
    
    var minAbsPhiInMesh:Double = Double.greatestFiniteMagnitude
    var maxAbsPhiInMesh:Double = -Double.greatestFiniteMagnitude
    
    var bounds:NSRect = NSRect(x: 0, y: 0, width: 0, height: 0)
    
    // We store the index of triangle of the last "hit" point that was queried and use it as the start point for the next query
    var lastHitTriangle:Element? = nil
    
    init(precision:PCH_SparseMatrix.DataType, units:Units, withPaths:[MeshPath], vertices:[NSPoint], regions:[Region], holes:[NSPoint])
    {
        self.precision = precision
        self.units = units
        
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
    
    func CreateContourLines(numLines:Int = 20) -> [ContourLine]
    {
        if self.minAbsPhiInMesh == Double.greatestFiniteMagnitude || self.maxAbsPhiInMesh == Double.greatestFiniteMagnitude
        {
            DLog("Phi values have not been assigned to nodes!")
            return []
        }
        
        let voltsBetweenLines = (self.maxAbsPhiInMesh - self.minAbsPhiInMesh) / Double(numLines - 1)
        
        var paths:[NSBezierPath] = Array(repeating: NSBezierPath(), count: numLines)
        var nextPhiToCreate = self.minAbsPhiInMesh
        
        // I will try to parallelize this, which is why I have separted it from the loop below that actually creates the contour line array
        for i in 0..<numLines
        {
            SetContourPath(path: paths[i], forValue: nextPhiToCreate)
            
            nextPhiToCreate += voltsBetweenLines
        }
        
        var result:[ContourLine] = []
        nextPhiToCreate = self.minAbsPhiInMesh
        for nextPath in paths
        {
            result.append(ContourLine(path: nextPath, value: nextPhiToCreate))
            nextPhiToCreate += voltsBetweenLines
        }
        
        return result
    }
    
    func SetContourPath(path:NSBezierPath, forValue value:Double)
    {
        for nextElement in self.elements
        {
            var points:[NSPoint] = []
            
            if let n0n1 = nextElement.corners.n0.LocationOfValue(value, toNode: nextElement.corners.n1)
            {
                points.append(n0n1)
            }
            
            if let n0n2 = nextElement.corners.n0.LocationOfValue(value, toNode: nextElement.corners.n2)
            {
                points.append(n0n2)
            }
            
            if let n1n2 = nextElement.corners.n1.LocationOfValue(value, toNode: nextElement.corners.n2)
            {
                points.append(n1n2)
            }
            
            // This is pretty inefficient - it might be better to try and sort things so we just have a bunch of lineto's instead...
            if points.count == 2
            {
                path.move(to: points[0])
                path.line(to: points[1])
            }
            // else if points.count == 3 // I don't see how this could ever happen...
        }
    }
    
    func SolveMatrix() -> [Double]
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
    
    func SolveMatrix() -> [Complex]
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
            
            // While we're at it, set the max and min values of phi in the mesh
            if values[i] > self.maxAbsPhiInMesh
            {
                self.maxAbsPhiInMesh = values[i]
            }
            
            if values[i] < self.minAbsPhiInMesh
            {
                self.minAbsPhiInMesh = values[i]
            }
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
            
            // While we're at it, set the max and min absolute values of phi in the mesh
            if values[i].cabs > self.maxAbsPhiInMesh
            {
                self.maxAbsPhiInMesh = values[i].cabs
            }
            
            if values[i].cabs < self.minAbsPhiInMesh
            {
                self.minAbsPhiInMesh = values[i].cabs
            }
            
            // debugging only (will probably be optimized out in the Release build)
            if let prescribed = self.nodes[i].phiPrescribed
            {
                if values[i] != prescribed
                {
                    DLog("Got one")
                }
            }
            
        }
    }
    
    func Setup_A_Matrix()
    {
        // For a large number of nodes, this call is excruciatingly slow. I did a quick try to see if I can use a concurrentPerform call instead of the for-loop, but accessing entries caused a crash in SparseMatrix. I made the accessors in Sparsematrix thread-safe and retested, but the concurrentPerform call was even slower than the simple for-loop (I guess making SparseMatrix access thread-safe slowed it down like hell. I reverted both).
        
        self.matrixA = PCH_SparseMatrix(type: self.precision, rows: self.nodes.count, cols: self.nodes.count)
        
        // TODO: Try to make this faster.
        //
        for nextNode in self.nodes {
            
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
        let zeroResult = Zone(triangle: nil, zone: nil, pathFollowed:nil)
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
                return Zone(triangle: nil, zone: nextHole.boundary, pathFollowed:nil)
            }
        }
        
        // calling routines can trace the path followed
        let pathToPoint = NSBezierPath()
        
        // As a start point, we'll choose a random triangle in the mesh UNLESS we've already done a search in which case we'll use the last triangle as our start point. We also want to avoid a triangle where any of the points are on a boundary.
        var startingTriangle:Element? = self.lastHitTriangle
        while startingTriangle == nil
        {
            // Note that normally, drand48() should be seeded so that it is actually random from one time to the next. I don't think that this will generally be a problem, and it makes debugging easier to always have the same value, so for now I am avoiding the seeding of the random number generator.
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
        
        guard let startTriangle = startingTriangle else
        {
            DLog("Couldn't come up with a suitable element to start!")
            return zeroResult
        }
        
        
        
        // Maybe our initial guess was the right one!
        if startTriangle.ElementAsPath().contains(X)
        {
            return Zone(triangle: startTriangle, zone: nil, pathFollowed:nil)
        }
        
        // Set the n0-n1 edge of our triangle as 'e'
        let currentNodes = startTriangle.corners
        var triangleEdge = TriangleEdge(e: (currentNodes.n0, currentNodes.n1), Other: currentNodes.n2)
        
        if TriangleEdge.IsRightOf(edge: triangleEdge.e, X: X)
        {
            if let symEdge = triangleEdge.SymmetricEdge()
            {
                triangleEdge = symEdge
            }
            else
            {
                ALog("Could not get SymmetricEdge of starting triangle!")
                return zeroResult
            }
        }
        
        DLog("Starting triangle: \(triangleEdge.triangle!)")
        pathToPoint.move(to: triangleEdge.triangle!.CenterOfMass())
        
        // var badResult = false
        var OnextIsOnBoundary = false
        var DprevIsOnBoundary = false
        while true
        {
            // Check if we're on the edge of a boundary (ie: a hole)
            if OnextIsOnBoundary || DprevIsOnBoundary
            {
                // Onext or Dprev is on a boundary, and the algorithm wants to set 'e' to it. The strategy is fairly simple. Keep going in the same direction as whichever has been chosen until one of the Nodes is no longer on the boundary.
                var destNode = triangleEdge.Other
                var orgNode = triangleEdge.Org
                
                if DprevIsOnBoundary
                {
                    destNode = triangleEdge.Dest
                    orgNode = triangleEdge.Other
                }
                
                let targetDirection = orgNode.Direction(toNode: destNode)
                var foundSuitableTriangle = false
                
                while !foundSuitableTriangle
                {
                    // Sort the neighbours so that the node that causes the closest direction to the target is first in line.
                    let neighbourArray = destNode.neighbours.sorted(by: {(node1:Node, node2:Node) -> Bool in
                    
                        let direction1 = TriangleEdge.Direction(edge: (A:destNode, B:node1))
                        let direction2 = TriangleEdge.Direction(edge: (A:destNode, B:node2))
                        
                        return TriangleEdge.DirectionDifference(dir1: targetDirection, dir2: direction1) < TriangleEdge.DirectionDifference(dir1: targetDirection, dir2: direction2)
                        
                        })
                    
                    orgNode = destNode
                    
                    if let bestNeighbour = neighbourArray.first
                    {
                        if TriangleEdge.DirectionDifference(dir1: targetDirection, dir2: TriangleEdge.Direction(edge: (A:orgNode, B:bestNeighbour))) == 0.0
                        {
                            // There is a point that is in exactly the same direction and it is very likely that it is on the same boundary, so:
                            destNode = bestNeighbour
                            pathToPoint.line(to: destNode.vertex)
                            continue
                        }
                    }
                    
                    // There was no node in exactly the same direction, so go through the neighbour array and choose the first node which, when we create an edge with it, satisfies our condition that the point 'X' be to the left of edge.e. The continue with the algorithm in the paper.
                    for nextNode in neighbourArray
                    {
                        destNode = nextNode
                        
                        let triangleSet = orgNode.elements.intersection(destNode.elements)
                        // var foundSuitableTriangle = false
                        for nextTriangle in triangleSet
                        {
                            let checkTriangle =  nextTriangle.NormalizedOn(n0: orgNode)
                            
                            // DLog("Org: \(orgNode), Dest:\(destNode)")
                            // DLog("n0:\(checkTriangle.corners.n0); n1:\(checkTriangle.corners.n1); n2:\(checkTriangle.corners.n2)")
                            
                            if checkTriangle.corners.n0 == orgNode && checkTriangle.corners.n1 == destNode
                            {
                                let checkTriangleEdge = TriangleEdge(e: (Org:orgNode, Dest:destNode), Other: checkTriangle.corners.n2)
                                
                                if !TriangleEdge.IsRightOf(edge: checkTriangleEdge.e, X: X)
                                {
                                    triangleEdge = checkTriangleEdge
                                    foundSuitableTriangle = true
                                    break
                                }
                            }
                        }
                        
                        if foundSuitableTriangle
                        {
                            break
                        }
                    }
                    
                    if !foundSuitableTriangle
                    {
                        DLog("This is a problem!")
                        return Zone(triangle: nil, zone: nil, pathFollowed: pathToPoint)
                    }
                    
                }
                
                
                
                /* OLD CODE
                while destNode.marker == orgNode.marker
                {
                    var directionDifference:CGFloat = CGFloat.greatestFiniteMagnitude
                    
                    var bestNode = destNode
                    for nextNode in destNode.neighbours
                    {
                        let newDirection = TriangleEdge.Direction(edge: (A:destNode, B:nextNode))
                        let newDiff = TriangleEdge.DirectionDifference(dir1: direction, dir2: newDirection)
                        
                        if newDiff < directionDifference
                        {
                            bestNode = nextNode
                            directionDifference = newDiff
                            
                            if directionDifference == 0
                            {
                                // it ain't gonna get better than this
                                break
                            }
                        }
                    }
                    
                    orgNode = destNode
                    destNode = bestNode
                    
                    pathToPoint.line(to: destNode.vertex)
                }
                
                // At this point, we want to create a TriangleEdge with orgNode as Org and destNode as Dest. There will be up to two possible triangles that satisfy this, with (hopefully) at least one that also satisfies !IsRightOf(). We need to choose the triangle using the paper's algorithm (so basically, everything gets coded twice...)
                let triangleSet = orgNode.elements.intersection(destNode.elements)
                var foundSuitableTriangle = false
                for nextTriangle in triangleSet
                {
                    let checkTriangle =  nextTriangle.NormalizedOn(n0: orgNode)
                    
                    // DLog("Org: \(orgNode), Dest:\(destNode)")
                    // DLog("n0:\(checkTriangle.corners.n0); n1:\(checkTriangle.corners.n1); n2:\(checkTriangle.corners.n2)")
                    
                    if checkTriangle.corners.n0 == orgNode && checkTriangle.corners.n1 == destNode
                    {
                        let checkTriangleEdge = TriangleEdge(e: (Org:orgNode, Dest:destNode), Other: checkTriangle.corners.n2)
                        
                        if !TriangleEdge.IsRightOf(edge: checkTriangleEdge.e, X: X)
                        {
                            triangleEdge = checkTriangleEdge
                            foundSuitableTriangle = true
                            break
                        }
                    }
                }
 
                
                if !foundSuitableTriangle
                {
                    // The "bestNode" discovered above was in the best "direction" but a suitable triangle cannot be made using it.
                    DLog("This is a problem!")
                    return Zone(triangle: nil, zone: nil, pathFollowed: pathToPoint)
                }
                */
            }
            
            OnextIsOnBoundary = false
            DprevIsOnBoundary = false
            
            pathToPoint.line(to: triangleEdge.triangle!.CenterOfMass())
            
            // The algorithm in the paper
            if triangleEdge.Org.vertex == X || triangleEdge.Dest.vertex == X
            {
                let goodTriangle = triangleEdge.triangle
                self.lastHitTriangle = goodTriangle
                return Zone(triangle: goodTriangle, zone: nil, pathFollowed:pathToPoint)
            }
            
            let OnextTest = !TriangleEdge.IsRightOf(edge: triangleEdge.Onext, X: X)
            let DprevTest = !TriangleEdge.IsRightOf(edge: triangleEdge.Dprev, X: X)
            
            if OnextTest && DprevTest
            {
                // whichop = 3
                if TriangleEdge.DistanceBetween(edge: triangleEdge.Onext, Bpt: X) < TriangleEdge.DistanceBetween(edge: triangleEdge.Dprev, Bpt: X)
                {
                    if let newEdge = TriangleEdge(oldTriangleEdge: triangleEdge, new_e: (Org:triangleEdge.Org, Dest:triangleEdge.Other))
                    {
                        triangleEdge = newEdge
                    }
                    else
                    {
                        OnextIsOnBoundary = true
                    }
                }
                else
                {
                    if let newEdge = TriangleEdge(oldTriangleEdge: triangleEdge, new_e: (Org:triangleEdge.Other, Dest:triangleEdge.Dest))
                    {
                        triangleEdge = newEdge
                    }
                    else
                    {
                        DprevIsOnBoundary = true
                    }
                }
            }
            else if OnextTest
            {
                // whichop = 1
                if let newEdge = TriangleEdge(oldTriangleEdge: triangleEdge, new_e: (Org:triangleEdge.Org, Dest:triangleEdge.Other))
                {
                    triangleEdge = newEdge
                }
                else
                {
                    OnextIsOnBoundary = true
                }
            }
            else if DprevTest
            {
                // whichop = 2
                if let newEdge = TriangleEdge(oldTriangleEdge: triangleEdge, new_e: (Org:triangleEdge.Other, Dest:triangleEdge.Dest))
                {
                    triangleEdge = newEdge
                }
                else
                {
                    DprevIsOnBoundary = true
                }
            }
            else
            {
                // whichop = 0
                let goodTriangle = triangleEdge.triangle
                self.lastHitTriangle = goodTriangle
                return Zone(triangle: goodTriangle, zone: nil, pathFollowed:pathToPoint)
            }
            
            // badResult = true
        }
    }
    
    struct Zone {
        
        var triangle:Element? = nil
        var zone:Boundary? = nil
        
        var pathFollowed:NSBezierPath? = nil
    }
    
    func ValuesAtPoint(_ point:NSPoint) -> (phi:Complex, slopeX:Complex, slopeY:Complex)
    {
        let enclosingZone = FindZoneWithPoint(X: point)
        
        if let boundary = enclosingZone.zone
        {
            return (boundary.fixedValue, Complex(real: 0.0), Complex(real: 0.0))
        }
        
        if let triangle = enclosingZone.triangle
        {
            return triangle.ValuesAtPoint(point)
        }
        
        return (Complex.ComplexNan, Complex.ComplexNan, Complex.ComplexNan)
    }
    
    func Solve()
    {
        ALog("This function must be overridden in concrete subclasses!")
    }
    
    func DataAtPoint(_ point:NSPoint) -> [(name:String, value:Complex, units:String)]
    {
        ALog("This function must be overridden in concrete subclasses!")
        
        return []
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
