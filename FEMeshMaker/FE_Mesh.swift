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
            return Zone(triangle: startTriangle, zone: nil)
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
        
        var foundResult = false
        while !foundResult
        {
            // Check if we're on the edge of a hole
            
            // The algorithm in the paper
            
            if triangleEdge.Org.vertex == X || triangleEdge.Dest.vertex == X
            {
                return Zone(triangle: triangleEdge.triangle, zone: nil)
            }
        }
        
        ALog("An error has occured")
        return zeroResult
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
