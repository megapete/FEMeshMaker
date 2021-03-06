//
//  FlatMagnetostaticComplexPotentialMesh.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-05-08.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation


class FlatMagnetostaticComplexPotentialMesh: FE_Mesh
{
    var magneticBoundaries:[Int:MagneticBoundary] = [:]
    
    init(withPaths:[MeshPath], units:FE_Mesh.Units, vertices:[NSPoint], regions:[Region], holes:[NSPoint] = [], isFlat:Bool = true)
    {
        super.init(precision: .complex, units: units, withPaths: withPaths, vertices: vertices, regions: regions, isFlat:isFlat)
        
        for nextPath in withPaths
        {
            if let boundary = nextPath.boundary
            {
                if let magBoundary = boundary as? MagneticBoundary
                {
                    magneticBoundaries[magBoundary.tag] = magBoundary
                }
            }
        }
        
        self.Setup_A_Matrix()
        self.SetupComplexBmatrix()
    }
    
    override func Solve()
    {
        DLog("Solving matrix")
        let solutionVector:[Complex] = self.SolveMatrix()
        DLog("Done")
        
        DLog("Setting vertex phi values")
        self.SetNodePhiValuesTo(solutionVector)
        DLog("Done")
    }
    
    
    
    override func DataAtPoint(_ point:NSPoint) -> [(name:String, value:Complex, units:String)]
    {
        let pointValues = self.ValuesAtPoint(point)
        
        let potential = ("A:", pointValues.phi, "")
        
        // Humphries 9.49
        let Bx = pointValues.V
        let By = -pointValues.U
        
        var phaseAngleDiff = 0.0
        if Bx != Complex.ComplexZero
        {
            if By != Complex.ComplexZero
            {
                phaseAngleDiff = abs(Bx.carg - By.carg)
            }
        }
        
        // We want Exp and Exn to be on the X-axis, so we create a Complex number with a real value of |Ex| and imag of 0.
        let BxAbs = Complex(real: Bx.cabs)
        let Bxp = BxAbs * 0.5
        let Bxn = Bxp
        
        // The Ey values are a bit more complicated
        let ByAbs = By.cabs
        let Byp = Complex(real: ByAbs * cos(π / 2 + phaseAngleDiff), imag: ByAbs * sin(π / 2 + phaseAngleDiff)) * 0.5
        let Byn = Complex(real: ByAbs * cos(π / 2 - phaseAngleDiff), imag: ByAbs * sin(π / 2 - phaseAngleDiff)) * 0.5
        
        let Bp = Bxp + Byp
        let Bn = Bxn + Byn
        
        let Babs = Bp.cabs + Bn.cabs
        
        let fieldAbs = ("Bmax:", Complex(real: Babs), "T")
        let fieldX = ("Bx:", Bx, "T")
        let fieldY = ("By:", By, "T")
        
        return [potential, fieldAbs, fieldX, fieldY]
    }
    
    override func CalculateCouplingConstants(node:Node)
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
            
            let colIndexN2 = nextTriangle.corners.n2.tag // for the first triangle, this is labeled 𝜙1 in Humphries
            let colIndexN1 = nextTriangle.corners.n1.tag // for the first triangle, this is labeled 𝜙6 in Humphries
            
            var µr = Complex(real: 1.0)
            if let region = nextTriangle.region
            {
                µr = region.µRel
            }
            
            let cotanA = nextTriangle.CotanThetaA()
            
            let coeffN2 = Complex(real: cotanA / (µr.real * 2.0), imag: 0.0)
            
            let cotanB = nextTriangle.CotanThetaB()
            let coeffN1 = Complex(real: cotanB / (µr.real * 2.0), imag: 0.0)
            
            sumWi += coeffN1 + coeffN2
            
            let prevN2:Complex = self.matrixA![node.tag, colIndexN2]
            self.matrixA![node.tag, colIndexN2] = Complex(real: prevN2.real - coeffN2.real, imag: prevN2.imag - coeffN2.imag)
            
            let prevN1:Complex = self.matrixA![node.tag, colIndexN1]
            self.matrixA![node.tag, colIndexN1] = Complex(real: prevN1.real - coeffN1.real, imag: prevN1.imag - coeffN1.imag)
        }
        
        self.matrixA![node.tag, node.tag] = sumWi
    }
    
    override func CalculateRHSforNode(node:Node)
    {
        if node.marker != 0 && node.marker != Boundary.neumannTagNumber
        {
            if let magBound = self.magneticBoundaries[node.marker]
            {
                self.complexMatrixB[node.tag] = magBound.prescribedPotential
                return
            }
            else
            {
                ALog("Could not find boundary in dictionary!")
                return
            }
        }
        
        var result = Complex(real: 0.0)
        let µFactor = (self.units == .mm ? 0.001 : (self.units == .inch ? 0.001 * 25.4 : 1.0))
        let constant = Complex(real:  µ0 * µFactor / 3.0)
        
        for nextElement in node.elements
        {
            var jz0 = Complex(real: 0.0)
            if let nextRegion = nextElement.region as? ConductorRegion
            {
                jz0 = nextRegion.currentDensity
            }
            
            let area = Complex(real: nextElement.Area())
            
            // we did the division of the constant when we defined it, so multiply it now (faster, I think)
            let iTerm = jz0 * area * constant
            
            result += iTerm
        }
        
        self.complexMatrixB[node.tag] = result
    }
}
