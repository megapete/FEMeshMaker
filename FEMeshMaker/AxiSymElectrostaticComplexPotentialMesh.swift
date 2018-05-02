//
//  AxiSymElectrostaticComplexPotentialMesh.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-04-30.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation

class AxiSymElectrostaticComplexPotentialMesh: FlatElectrostaticComplexPotentialMesh
{
    override func CalculateCouplingConstants(node: Node)
    {
        // If the node is an electrode...
        if node.marker != 0
        {
            if self.electrodes[node.marker] != nil
            {
                self.matrixA![node.tag, node.tag] = Complex(real: 1.0)
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
        
        let firstTriangle = sortedTriangles[0].NormalizedOn(n0: node)
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
                if nextTriangle.corners.n2.tag == firstTriangle.corners.n1.tag
                {
                    nextTriangle = firstTriangle
                    
                    guard let region = nextTriangle.region as? DielectricRegion else
                    {
                        ALog("Could not get region for triangle")
                        return
                    }
                    
                    coeff += region.eRel * Complex(real: Double(nextTriangle.CenterOfMass().x)) * Complex(real: nextTriangle.CotanThetaB()) * Complex(real: 0.5)
                }
                else
                {
                    DLog("Break (or boundary) at node: \(node)")
                    
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
        let εFactor = (self.units == .mm ? 0.001 : 0.001 * 25.4)
        let constant = Complex(real: 1.0 / (3.0 * ε0 * εFactor))
        for nextElement in node.elements
        {
            var rho = Complex(real: 0.0)
            if let nextRegion = nextElement.region as? DielectricRegion
            {
                rho = nextRegion.rho
            }
            
            let r = Complex(real: nextElement.CenterOfMass().x)
            let area = Complex(real: nextElement.Area())
            
            // we did the division of the constant when we defined it, so multiply it now (faster, I think)
            let iTerm = (r * rho * area) * constant
            
            result += iTerm
        }
        
        self.complexMatrixB[node.tag] = result
    }
}
