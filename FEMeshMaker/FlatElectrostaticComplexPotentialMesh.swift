//
//  FlatElectrostaticComplexPotentialMesh.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-16.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation
import Cocoa

class FlatElectrostaticComplexPotentialMesh:FE_Mesh
{
    var electrodes:[Int:Electrode] = [:]
    
    init(withPaths:[MeshPath], vertices:[NSPoint], regions:[Region], holes:[NSPoint])
    {
        super.init(precision: .complex, withPaths: withPaths, vertices: vertices, regions: regions, holes: holes)
        
        // save the electrodes into a dictionary to make it easy to look them up
        for nextPath in withPaths
        {
            if let boundary = nextPath.boundary
            {
                if let electrode = boundary as? Electrode
                {
                    electrodes[electrode.tag] = electrode
                }
            }
        }
        
        // Create the mesh
        if !self.RefineMesh()
        {
            ALog("Could not refine mesh!")
        }
        
        self.Setup_A_Matrix()
        self.SetupComplexBmatrix()
    }
    
    override func CalculateCouplingConstants(node: Node)
    {
        // If the node is an electrode...
        if node.marker != 0
        {
            if self.electrodes[node.marker] != nil
            {
                self.matrixA![node.tag, node.tag] = 1.0
                return
            }
            else
            {
                ALog("Could not find boundary in dictionary!")
                return
            }
        }
        
        // It's a regular node, so we do Humphries Eq. 2.67 (LHS)
        var sumWi = Complex(real: 0.0)
        
        let sortedTriangles = node.SortedArrayOfTriangles()
        
        for i in 0..<sortedTriangles.count
        {
            var nextTriangle = sortedTriangles[i].NormalizedOn(n0: node)
            
            let colIndex = nextTriangle.corners.n2.tag
            
            guard let region = nextTriangle.region as? DielectricRegion else
            {
                ALog("Could not get region for triangle")
                return
            }
            
            var coeff = region.eRel * Complex(real: Double(nextTriangle.CenterOfMass().x)) * Complex(real: nextTriangle.CotanThetaA()) * Complex(real: 0.5)
            
            // We've come all the way around, back to the first triangle
            if i == sortedTriangles.count - 1
            {
                if nextTriangle.corners.n2.tag == sortedTriangles[0].corners.n1.tag
                {
                    nextTriangle = sortedTriangles[0]
                    
                    guard let region = nextTriangle.region as? DielectricRegion else
                    {
                        ALog("Could not get region for triangle")
                        return
                    }
                    
                    coeff += region.eRel * Complex(real: Double(nextTriangle.CenterOfMass().x)) * Complex(real: nextTriangle.CotanThetaB()) * Complex(real: 0.5)
                }
            }
            else // do the next adjacent triangle
            {
                nextTriangle = sortedTriangles[i + 1].NormalizedOn(n0: node)
                
                guard let region = nextTriangle.region as? DielectricRegion else
                {
                    ALog("Could not get region for triangle")
                    return
                }
                
                coeff += region.eRel * Complex(real: Double(nextTriangle.CenterOfMass().x)) * Complex(real: nextTriangle.CotanThetaB()) * Complex(real: 0.5)
            }
            
            sumWi += coeff
            
            self.matrixA![node.tag, colIndex] = Complex(real: -1.0) * coeff
        }
        
        self.matrixA![node.tag, node.tag] = sumWi
    }
    
    override func CalculateRHSforNode(node: Node)
    {
        // If the node is an electrode...
        if node.marker != 0
        {
            if let electrode = self.electrodes[node.marker]
            {
                    self.complexMatrixB[node.tag] = electrode.prescribedVoltage
                    return
            }
            else
            {
                ALog("Could not find boundary in dictionary!")
                return
            }
        }
        
        // It's a regular node, so we do Humphries Eq. 2.67 (RHS)
        var result = Complex(real: 0.0)
        let constant = Complex(real: 1.0/(3.0 * ε0))
        for nextElement in node.elements
        {
            var rho = Complex(real: 0.0)
            if let nextRegion = nextElement.region as? DielectricRegion
            {
                rho = nextRegion.rho
            }
            
            let area = Complex(real: nextElement.Area())
            
            // we did the division of the constant when we defined it, so multiply it now (faster, I think)
            let iTerm = (rho * area) * constant
            
            result += iTerm
        }
        
        self.complexMatrixB[node.tag] = result
    }
}
