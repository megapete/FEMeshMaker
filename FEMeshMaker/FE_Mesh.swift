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

// This function is used by the FindTriangleWithPoint(:) function in the FE_Mesh class below. It returns true if the point X is STRICTLY to the right of the line AB.
fileprivate func IsRightOf(edge:(A:NSPoint, B:NSPoint), X:NSPoint) -> Bool
{
    // For a vector from A to B, and point X,
    // let result = ((Bx - Ax) * (Xy - Ay) - (By - Ay) * (Xx - Ax))
    // if result > 0, X is to the left of AB, < 0 to the Right, =0 on the line
    
    let result = ((edge.B.x - edge.A.x) * (X.y - edge.A.y) - (edge.B.y - edge.A.y) * (X.x - edge.A.x))
    
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
    func FindTriangleWithPoint(X:NSPoint)
    {
        
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
