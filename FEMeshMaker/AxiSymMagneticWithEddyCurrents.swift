//
//  AxiSymMagneticWithEddyCurrents.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-05-19.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This is my attempt to reconcile Andersen's method of calculating eddy losses with Section 11.5 of Humphries book. In Humphries, he takes the sum over i of Jzoi * ai / 3 (which is the total current in ai, say Iai). This is equivalent to the term (𝛾/6)DU in equation 39 of his Eddy Loss paper (conductance time area time an electric field is equal to current, and D is twice the triangle area).

// Step 1: Set up the A-matrix for the problem. This remains unchanged throughout the calculations
// Step 2: For each coil region in the problem, do:
//          2a) Apply the field U = 1V per radian to the coil region (same as saying Jzoi = Y)
//          2b) Set everything else to 0
//          2c) Set up the B-matrix and solve the matrix system
//          2d) Use the result to calculate the currents (see note * below) in the other coil regions and fill in the ith column of the admittance matrix
// Step 3: Invert the admittance matrix (becomes an impedance matrix)
// Step 4: Using the drive currents, calculate actual U-values and convert them to Jzoi values - set up B-matrix with these values
// Step 5: Solve the final matrix system

// NOTE * : I don't know how to do this yet. Here are my attempts ayt figuring this out
// Attempt #1: Use Andersen formula (8) from his Eddy Loss paper. Here, for the U=0 regions, total I = ∑(Ii), where Ii = -j𝜔𝛾(Ai) * ai

import Foundation

class AxiSymMagneticWithEddyCurrents:FE_Mesh
{
    let frequency:Double
    var magneticBoundaries:[Int:MagneticBoundary] = [:]
    var coilRegions:[CoilRegion] = []
    let admittanceMatrix:PCH_Matrix
    
    init(withPaths:[MeshPath], atFrequency:Double, units:FE_Mesh.Units, vertices:[NSPoint], regions:[Region], holes:[NSPoint] = [])
    {
        self.frequency = atFrequency
        for nextRegion in regions
        {
            if let newCoil = nextRegion as? CoilRegion
            {
                coilRegions.append(newCoil)
            }
        }
        
        self.admittanceMatrix = PCH_Matrix(numRows: self.coilRegions.count, numCols: self.coilRegions.count, matrixPrecision: .complexPrecision, matrixType: .generalMatrix)
        
        super.init(precision: .complex, units: units, withPaths: withPaths, vertices: vertices, regions: regions, holes:holes, isFlat:false)
        
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
    }
    
    override func Solve()
    {
        var coils = self.coilRegions
        
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
        
        // It's a regular node, so we do Humphries Eq. 11.49
        var sumWi = Complex(real: 0.0)
        
        for triangle in node.elements
        {
            let nextTriangle = triangle.NormalizedOn(n0: node)
            
            let R = Double(nextTriangle.CenterOfMass().x)
            
            let colIndexN2 = nextTriangle.corners.n2.tag // for the first triangle, this is labeled 𝜙1 in Humphries
            let colIndexN1 = nextTriangle.corners.n1.tag // for the first triangle, this is labeled 𝜙6 in Humphries
            
            let µFixed = (self.units == .mm ? µ0 * 0.001 : (self.units == .inch ? µ0 * 0.001 * 25.4 : µ0))
            
            var µr = Complex(real: 1.0)
            
            var eddyTerm = 0.0
            if let region = nextTriangle.region
            {
                µr = region.µRel
                
                if region.conductivity != 0.0
                {
                    eddyTerm = 2.0 * π * self.frequency * region.conductivity * nextTriangle.Area() / 3.0
                }
            }
            
            // eddyTerm = 0.0
            
            let cotanA = nextTriangle.CotanThetaA()
            
            let coeffN2 = Complex(real: cotanA / (µr.real * µFixed * 2.0 * R), imag: 0.0)
            
            let cotanB = nextTriangle.CotanThetaB()
            let coeffN1 = Complex(real: cotanB / (µr.real * µFixed * 2.0 * R), imag: 0.0)
            
            sumWi += coeffN1 + coeffN2 - Complex(real: 0.0, imag: eddyTerm)
            
            let prevN2:Complex = self.matrixA![node.tag, colIndexN2]
            self.matrixA![node.tag, colIndexN2] = Complex(real: prevN2.real - coeffN2.real, imag: prevN2.imag - coeffN2.imag)
            
            let prevN1:Complex = self.matrixA![node.tag, colIndexN1]
            self.matrixA![node.tag, colIndexN1] = Complex(real: prevN1.real - coeffN1.real, imag: prevN1.imag - coeffN1.imag)
        }
        
        self.matrixA![node.tag, node.tag] = sumWi
    }
    
    override func CalculateRHSforNode(node: Node)
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
        // let µFactor = (self.units == .mm ? 0.001 : (self.units == .inch ? 0.001 * 25.4 : 1.0))
        let constant = Complex(real:  1.0 / 3.0)
        
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
