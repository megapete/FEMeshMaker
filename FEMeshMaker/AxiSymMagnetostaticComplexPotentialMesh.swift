//
//  AxiSymMagnetostaticComplexPotentialMesh.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-05-19.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation

class AxiSymMagnetostaticComplexPotentialMesh:FlatMagnetostaticComplexPotentialMesh
{
    init(withPaths:[MeshPath], units:FE_Mesh.Units, vertices:[NSPoint], regions:[Region], holes:[NSPoint] = [])
    {
        super.init(withPaths: withPaths, units: units, vertices: vertices, regions: regions, holes: holes, isFlat:false)
    }
    
    override func CalculateCouplingConstants(node: Node)
    {
        if node.marker != 0 && node.marker != Boundary.neumannTagNumber
        {
            if self.magneticBoundaries[node.marker] != nil
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
        
        // It's a regular node, so we do Humphries Eq. 9.54
        var sumWi = Complex(real: 0.0)
        
        for triangle in node.elements
        {
            let nextTriangle = triangle.NormalizedOn(n0: node)
            
            let R = Double(nextTriangle.CenterOfMass().x)
            
            let colIndexN2 = nextTriangle.corners.n2.tag // for the first triangle, this is labeled 𝜙1 in Humphries
            let colIndexN1 = nextTriangle.corners.n1.tag // for the first triangle, this is labeled 𝜙6 in Humphries
            
            var µr = Complex(real: 1.0)
            if let region = nextTriangle.region
            {
                µr = region.µRel
            }
            
            let cotanA = nextTriangle.CotanThetaA()
            
            let coeffN2 = Complex(real: cotanA / (µr.real * 2.0 * R), imag: 0.0)
            
            let cotanB = nextTriangle.CotanThetaB()
            let coeffN1 = Complex(real: cotanB / (µr.real * 2.0 * R), imag: 0.0)
            
            sumWi += coeffN1 + coeffN2
            
            let prevN2:Complex = self.matrixA![node.tag, colIndexN2]
            self.matrixA![node.tag, colIndexN2] = Complex(real: prevN2.real - coeffN2.real, imag: prevN2.imag - coeffN2.imag)
            
            let prevN1:Complex = self.matrixA![node.tag, colIndexN1]
            self.matrixA![node.tag, colIndexN1] = Complex(real: prevN1.real - coeffN1.real, imag: prevN1.imag - coeffN1.imag)
        }
        
        self.matrixA![node.tag, node.tag] = sumWi
    }
    
    // Note: We don't need to override the CalculateRHSforNode because the parent class' method is exactly what we need
}
