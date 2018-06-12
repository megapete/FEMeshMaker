//
//  AxiSymMagneticWithEddyCurrents.swift
//  FEMeshMaker
//
//  Created by Peter Huber on 2018-05-19.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This is my attempt to reconcile Andersen's method of calculating eddy losses with Section 11.5 of Humphries book. In Humphries, he takes the sum over i of Jzoi * ai / 3 (which is the total current in ai, say Iai). This is equivalent to the term (𝛾/6)DU in equation 39 of his Eddy Loss paper (conductance times area times an electric field is equal to current, and D is twice the triangle area).

// Step 1: Set up the A-matrix for the problem. This remains unchanged throughout the calculations
// Step 2: For each coil region in the problem, do:
//          2a) Apply the field U = 1V per radian to the coil region (same as saying Jzoi = 𝛾)
//          2b) Set everything else to 0
//          2c) Set up the B-matrix and solve the matrix system
//          2d) Use the result to calculate the currents (see note * below) in the other coil regions and fill in the ith column of the admittance matrix
// Step 3: Invert the admittance matrix (becomes an impedance matrix)
// Step 4: Using the drive currents, calculate actual U-values and convert them to Jzoi values - set up B-matrix with these values
// Step 5: Solve the final matrix system

// NOTE * : I don't know how to do this yet. Here are my attempts at figuring this out
// Attempt #1: Use Andersen formula (8) from his Eddy Loss paper. Here, for the U=0 regions, total I = ∑(Ii), where Ii = -j𝜔𝛾(Ai) * ai
// Attempt #2: I was calculating the total current for the U=1 the same way as the U=0 zones, which is obviously incorrect.
// Attempt #3: Success! (I think!). I added a "* R" term when calculating the eddy term in coupling constants and got close. I then started thinking about how U is actually a voltage field "per radian" and I decided to divide the eddy term calculation by 2π and suddenly I was getting the same answer (in terms of energy, anyway) as Andersen. Now I need to check whether the complex B-fields give me the same eddy loss values...

import Foundation

class AxiSymMagneticWithEddyCurrents:FE_Mesh
{
    let frequency:Double
    var magneticBoundaries:[Int:MagneticBoundary] = [:]
    var coilRegions:[CoilRegion] = []
    var coilTotalCurrents:PCH_Matrix
    
    var currentsAreRMS:Bool = false
    
    init(withPaths:[MeshPath], atFrequency:Double, units:FE_Mesh.Units, vertices:[NSPoint], regions:[Region], holes:[NSPoint] = [])
    {
        self.frequency = atFrequency
        var rmsIsSet:Bool = false
        
        for nextRegion in regions
        {
            if let newCoil = nextRegion as? CoilRegion
            {
                if !rmsIsSet
                {
                    self.currentsAreRMS = newCoil.J_isRMS
                    rmsIsSet = true
                }
                else
                {
                    if newCoil.J_isRMS != self.currentsAreRMS
                    {
                        DLog("The coil \(newCoil.description) does not have the same RMS value (\(self.currentsAreRMS)) as a previous coil - ignoring!")
                    }
                }
                
                coilRegions.append(newCoil)
            }
        }
        
        self.coilTotalCurrents = PCH_Matrix(numVectorElements: self.coilRegions.count, vectorPrecision: .complexPrecision)
        
        ZAssert(self.coilRegions.count > 0, message: "At least one coil must be defined for this class")
        
        super.init(precision: .complex, units: units, withPaths: withPaths, vertices: vertices, regions: regions, holes:holes, isFlat:false)
        
        for i in 0..<self.coilRegions.count
        {
            self.coilTotalCurrents[i, 0] = self.coilRegions[i].currentDensity * self.coilRegions[i].TotalTriangleArea()
        }
        
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
        
        let admittanceMatrix = PCH_Matrix(numRows: self.coilRegions.count, numCols: self.coilRegions.count, matrixPrecision: .complexPrecision, matrixType: .generalMatrix)
        
        for i in 0..<self.coilRegions.count
        {
            CreateRHSforU_CoilRegion(coil: self.coilRegions[i])
            
            let solutionVector:[Complex] = self.SolveMatrix()
            self.SetNodePhiValuesTo(solutionVector)
            
            // DLog("U = 1 total current: \(coils[i].conductivity * coils[i].TotalTriangleArea())")
            
            // let calculatedCurrent = TotalCurrent(coil: coils[i])
            // DLog("Total current of U=1 coil after matrix solution: \(calculatedCurrent), |I| = \(calculatedCurrent.cabs)")
            
            for j in 0..<self.coilRegions.count
            {
                var calculatedCurrent = Complex.ComplexZero
                
                if j == i
                {
                    calculatedCurrent = Complex(real:self.coilRegions[j].conductivity * self.coilRegions[j].TotalTriangleArea())
                }
                else
                {
                    calculatedCurrent = TotalCurrent(coil: self.coilRegions[j], U:(0.0))
                }
                
                admittanceMatrix[j, i] = calculatedCurrent
            }
        }
        
        guard let impedanceMatrix = admittanceMatrix.Inverse() else
        {
            ALog("Could not invert the admittance matrix!")
            return
        }
        
        guard let Uvector = impedanceMatrix.MultiplyBy(self.coilTotalCurrents) else
        {
            ALog("Could not multiply impedance matrix by currents!")
            return
        }
        
        // Now, using the fact that J = 𝛾E, and U is an electric field (like E):
        for i in 0..<self.coilRegions.count
        {
            DLog("Current density of \(self.coilRegions[i].description) before adjustment: \(self.coilRegions[i].currentDensity)")
            self.coilRegions[i].currentDensity = Uvector[i, 0] * Complex(real: self.coilRegions[i].conductivity /*, imag: self.coilRegions[i].conductivity */)
            DLog("Current density after adjustment: \(self.coilRegions[i].currentDensity)")
        }
 
        
        self.SetupComplexBmatrix()
        
        let solutionVector:[Complex] = self.SolveMatrix()
        self.SetNodePhiValuesTo(solutionVector)
    }
    
    func TotalCurrent(coil:CoilRegion, U:Double) -> Complex
    {
        // total I = ∑(Ii), where Ii = 𝛾(U -j𝜔(Ai)) * ai
        
        var result:Complex = Complex.ComplexZero
        for nextTriangle in coil.associatedTriangles
        {
            let elementValues = self.ValuesAtPoint(nextTriangle.CenterOfMass())
            let Ai = elementValues.phi
            let 𝜔 = 2.0 * π * self.frequency
            let 𝛾 = coil.conductivity
            
            result += Complex(real: U, imag: -Ai * 𝜔) * 𝛾 * nextTriangle.Area()
        }
        
        return result
    }
    
    override func DataAtPoint(_ point:NSPoint) -> [(name:String, value:Complex, units:String)]
    {
        let pointValues = self.ValuesAtPoint(point)
        
        let potential = ("A:", pointValues.phi, "")
        
        // Humphries 9.49
        let Bx = pointValues.V * sqrt(2)
        let By = -pointValues.U * sqrt(2)
        
        var phaseAngleDiff = 0.0
        if Bx != Complex.ComplexZero
        {
            if By != Complex.ComplexZero
            {
                phaseAngleDiff = abs(Bx.carg - By.carg)
            }
        }
        
        // We want Bxp and Bxn to be on the X-axis, so we create a Complex number with a real value of |Bx| and imag of 0.
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
                    let area = nextTriangle.Area()
                    let conductivity = region.conductivity
                    // DLog("Area: \(area); conductivity: \(conductivity)")
                    eddyTerm = /* 2.0 * π * */ self.frequency * conductivity * area * R / 3.0
                }
            }
            
            // eddyTerm = 0.0
            
            let cotanA = nextTriangle.CotanThetaA()
            
            let coeffN2 = Complex(real: cotanA / (µr.real * µFixed * 2.0 * R), imag: 0.0)
            
            let cotanB = nextTriangle.CotanThetaB()
            let coeffN1 = Complex(real: cotanB / (µr.real * µFixed * 2.0 * R), imag: 0.0)
            
            sumWi += ((coeffN1 + coeffN2) - Complex(real: 0.0, imag: eddyTerm))
            
            let prevN2:Complex = self.matrixA![node.tag, colIndexN2]
            self.matrixA![node.tag, colIndexN2] = Complex(real: prevN2.real - coeffN2.real, imag: prevN2.imag - coeffN2.imag)
            
            let prevN1:Complex = self.matrixA![node.tag, colIndexN1]
            self.matrixA![node.tag, colIndexN1] = Complex(real: prevN1.real - coeffN1.real, imag: prevN1.imag - coeffN1.imag)
        }
        
        self.matrixA![node.tag, node.tag] = sumWi
    }
    
    func CreateRHSforU_CoilRegion(coil:CoilRegion)
    {
        var RHS_Matrix = Array(repeating: Complex.ComplexNan, count: self.nodes.count)
        let totalCoilArea = coil.TotalTriangleArea()
        
        for node in self.nodes
        {
            if node.marker != 0 && node.marker != Boundary.neumannTagNumber
            {
                if let magBound = self.magneticBoundaries[node.marker]
                {
                    RHS_Matrix[node.tag] = magBound.prescribedPotential
                }
                else
                {
                    ALog("Could not find boundary in dictionary!")
                    return
                }
            }
            else
            {
                var result = Complex(real: 0.0)
                
                for nextElement in node.elements
                {
                    if let nextRegion = nextElement.region as? CoilRegion
                    {
                        if nextRegion.tagBase == coil.tagBase
                        {
                            let area = nextElement.Area()
                            
                            let jz0 = nextRegion.conductivity * area / totalCoilArea
                            
                            let iTerm = jz0 * area / 3.0
                            
                            result += Complex(real:iTerm)
                        }
                    }
                }
                
                RHS_Matrix[node.tag] = result
            }
        }
        
        self.complexMatrixB = RHS_Matrix
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
