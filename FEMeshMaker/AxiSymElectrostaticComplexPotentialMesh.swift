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
    init(withPaths:[MeshPath], units:FE_Mesh.Units, vertices:[NSPoint], regions:[Region], holes:[NSPoint] = [])
    {
        super.init(withPaths: withPaths, units: units, vertices: vertices, regions: regions, holes: holes, isFlat: false)
    }
    
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
        
        // It's a regular node, so we do Humphries Eq. 2.77 & 2.78
        var sumWi = Complex(real: 0.0)
        
        for triangle in node.elements
        {
            let nextTriangle = triangle.NormalizedOn(n0: node)
            
            let colIndexN2 = nextTriangle.corners.n2.tag // for the first triangle, this is labeled 𝜙1 in Humphries
            let colIndexN1 = nextTriangle.corners.n1.tag // for the first triangle, this is labeled 𝜙6 in Humphries
            
            let region = nextTriangle.region! as! DielectricRegion
            
            let cotanA_r = nextTriangle.CotanThetaA() * Double(nextTriangle.CenterOfMass().x)
            let Er = region.eRel
            let coeffN2 = Complex(real: Er.real * cotanA_r / 2.0, imag: Er.imag * cotanA_r / 2.0)
            
            let cotanB_r = nextTriangle.CotanThetaB() * Double(nextTriangle.CenterOfMass().x)
            let coeffN1 = Complex(real: Er.real * cotanB_r / 2.0, imag: Er.imag * cotanB_r / 2.0)
            
            sumWi += coeffN1 + coeffN2
            
            let prevN2:Complex = self.matrixA![node.tag, colIndexN2]
            self.matrixA![node.tag, colIndexN2] = Complex(real: prevN2.real - coeffN2.real, imag: prevN2.imag - coeffN2.imag)
            
            let prevN1:Complex = self.matrixA![node.tag, colIndexN1]
            self.matrixA![node.tag, colIndexN1] = Complex(real: prevN1.real - coeffN1.real, imag: prevN1.imag - coeffN1.imag)
        }
        
        self.matrixA![node.tag, node.tag] = sumWi
    }
    
    override func CalculateRHSforNode(node: Node)
    {
        // If the node is an electrode...
        if node.marker != 0 && node.marker != Boundary.neumannTagNumber
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
