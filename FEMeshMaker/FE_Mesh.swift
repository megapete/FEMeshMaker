//
//  FE_Mesh.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-08.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// Base class for concrete finite element mesh classes

import Foundation
import Cocoa

class FE_Mesh:Mesh
{
    let precision:PCH_Matrix.precisions
    var matrixA:PCH_Matrix? = nil
    var matrixB:PCH_Matrix? = nil
    
    var bounds:NSRect = NSRect(x: 0, y: 0, width: 0, height: 0)
    
    init(precision:PCH_Matrix.precisions, withPaths:[MeshPath], vertices:[NSPoint], regions:[Region], holes:[NSPoint])
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
        
    }
    
    func Setup_A_Matrix() -> PCH_Matrix
    {
        self.matrixA = PCH_Matrix(numRows: self.nodes.count, numCols: self.nodes.count, matrixPrecision: self.precision, matrixType: .generalMatrix)
        
        for nextNode in self.nodes
        {
            CalculateCouplingConstants(node: nextNode)
        }
        
        return self.matrixA!
    }
    
    func Setup_B_Matrix() -> PCH_Matrix
    {
        self.matrixB = PCH_Matrix(numVectorElements: self.nodes.count, vectorPrecision: self.precision)
        
        for nextNode in self.nodes
        {
            CalculateRHSforRow(row: nextNode.tag)
        }
        
        return self.matrixB!
    }
    
    func CalculateCouplingConstants(node:Node)
    {
        ALog("This function must be overridden in concrete subclasses!")
    }
    
    func CalculateRHSforRow(row:Int)
    {
        ALog("This function must be overridden in concrete subclasses!")
    }
}
