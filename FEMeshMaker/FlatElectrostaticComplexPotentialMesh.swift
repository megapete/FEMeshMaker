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
    
    init(withPaths:[MeshPath], units:FE_Mesh.Units, vertices:[NSPoint], regions:[Region], holes:[NSPoint] = [])
    {
        super.init(precision: .complex, units:units, withPaths: withPaths, vertices: vertices, regions: regions, holes: holes)
        
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
        
        // For any nodes that are part of a triangle that is "inside" a conductor, set its marker according to the enclosing electrode
        for nextNode in self.nodes
        {
            for nextTriangle in nextNode.elements
            {
                if let region = nextTriangle.region as? ConductorRegion
                {
                    if let electrode = region.electrode
                    {
                        nextNode.marker = electrode.tag
                        break
                    }
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
        
        DLog("Setting electric fields")
        self.SetElectricFields()
        DLog("Done")
    }
    
    func SetElectricFields()
    {
        var maxFieldIntensity = -Double.greatestFiniteMagnitude
        var maxFieldIntensityTriangle:Element? = nil
        var minFieldIntensity = Double.greatestFiniteMagnitude
        var minFieldIntensityTriangle:Element? = nil
    
        for nextTriangle in self.elements
        {
            let pointValues = nextTriangle.ValuesAtCenterOfMass(coarse: true)
            
            let Ex = pointValues.slopeX
            let Ey = pointValues.slopeY
            
            // This comes from Andersen's paper "Finite Element Solution of Complex Potential Electric Fields", equations 19, 20, and 21
            var phaseAngleDiff = 0.0
            if Ex != Complex.ComplexZero
            {
                if Ey != Complex.ComplexZero
                {
                    phaseAngleDiff = abs(Ex.carg - Ey.carg)
                }
            }
            
            // We want Exp and Exn to be on the X-axis, so we create a Complex number with a real value of |Ex| and imag of 0.
            let ExAbs = Complex(real: Ex.cabs)
            let Exp = ExAbs * 0.5
            let Exn = Exp
            
            // The Ey values are a bit more complicated
            let EyAbs = Ey.cabs
            let Eyp = Complex(real: EyAbs * cos(π / 2 + phaseAngleDiff), imag: EyAbs * sin(π / 2 + phaseAngleDiff)) * 0.5
            let Eyn = Complex(real: EyAbs * cos(π / 2 - phaseAngleDiff), imag: EyAbs * sin(π / 2 - phaseAngleDiff)) * 0.5
            
            let Ep = Exp + Eyp
            let En = Exn + Eyn
            
            let Eabs = Ep.cabs + En.cabs
            
            if Eabs < minFieldIntensity
            {
                minFieldIntensity = Eabs
                minFieldIntensityTriangle = nextTriangle
            }
            
            if Eabs > maxFieldIntensity
            {
                maxFieldIntensity = Eabs
                maxFieldIntensityTriangle = nextTriangle
            }
            
            nextTriangle.value = Eabs
        }
        
        self.maxFieldIntensityTriangle = maxFieldIntensityTriangle
        self.minFieldIntensityTriangle = minFieldIntensityTriangle
    }
    
    override func DataAtPoint(_ point:NSPoint) -> [(name:String, value:Complex, units:String)]
    {
        let pointValues = self.ValuesAtPoint(point)
        
        let volts = ("V:", pointValues.phi, "Volts")
        let absVolts = ("|V|:", Complex(real:pointValues.phi.cabs), "Volts")
        
        let Ex = pointValues.slopeX
        let Ey = pointValues.slopeY
        
        // This comes from Andersen's paper "Finite Element Solution of Complex Potential Electric Fields", equations 19, 20, and 21
        
        var phaseAngleDiff = 0.0
        if Ex != Complex.ComplexZero
        {
            if Ey != Complex.ComplexZero
            {
                phaseAngleDiff = abs(Ex.carg - Ey.carg)
            }
        }
        
        // We want Exp and Exn to be on the X-axis, so we create a Complex number with a real value of |Ex| and imag of 0.
        let ExAbs = Complex(real: Ex.cabs)
        let Exp = ExAbs * 0.5
        let Exn = Exp
        
        // The Ey values are a bit more complicated
        let EyAbs = Ey.cabs
        let Eyp = Complex(real: EyAbs * cos(π / 2 + phaseAngleDiff), imag: EyAbs * sin(π / 2 + phaseAngleDiff)) * 0.5
        let Eyn = Complex(real: EyAbs * cos(π / 2 - phaseAngleDiff), imag: EyAbs * sin(π / 2 - phaseAngleDiff)) * 0.5
        
        let Ep = Exp + Eyp
        let En = Exn + Eyn
        
        let Eabs = Ep.cabs + En.cabs
        
        let units = (self.units == .inch ? "inch" : "mm")
        let absField = ("|E|:", Complex(real:Eabs), "V/\(units)")
        let fieldX = ("Ex:", Ex, "V/\(units)")
        let fieldY = ("Ey:", Ey, "V/\(units)")
        
        return [volts, absVolts, fieldX, fieldY, absField]
    }
    
    override func CalculateCouplingConstants(node: Node)
    {
        // If the node is on an electrode surface...
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
        
        /* Debugging stuff
        DLog("Node n0 vertex: \(node.vertex)")
        var triIndex = 1
        for theTriangle in sortedTriangles
        {
            let triangle = theTriangle.NormalizedOn(n0: node)
            DLog("\nn0:\(triangle.corners.n0.vertex), n1:\(triangle.corners.n1.vertex), n2:\(triangle.corners.n2.vertex)")
            DLog("\nTriangle #\(triIndex): (n0:\(triangle.corners.n0.tag), n1:\(triangle.corners.n1.tag), n2:\(triangle.corners.n2.tag); CofM:\(triangle.CenterOfMass())")
            triIndex += 1
        }
        */
        
        
        
        let firstTriangle = sortedTriangles[0].NormalizedOn(n0: node)
        for i in 0..<sortedTriangles.count
        {
            var nextTriangle = sortedTriangles[i].NormalizedOn(n0: node)
            
            let colIndex = nextTriangle.corners.n2.tag
            
            let region = nextTriangle.region! as! DielectricRegion
            
            /* OLD CODE (may have been slow)
            guard let region = nextTriangle.region as? DielectricRegion else
            {
                ALog("Could not get region for triangle")
                return
            }
            */
            
            let cotanA = nextTriangle.CotanThetaA()
            let Er = region.eRel
            var coeff = Complex(real: Er.real * cotanA, imag: Er.imag * cotanA)
            
            // We've come all the way around, back to the first triangle
            if i == sortedTriangles.count - 1
            {
                if nextTriangle.corners.n2.tag == firstTriangle.corners.n1.tag
                {
                    nextTriangle = firstTriangle
                    
                    let region = nextTriangle.region! as! DielectricRegion
                    
                    /* OLD CODE (may have been slow)
                     guard let region = nextTriangle.region as? DielectricRegion else
                     {
                        ALog("Could not get region for triangle")
                        return
                     }
                     */
                    
                    let cotanB = nextTriangle.CotanThetaB()
                    let Er = region.eRel
                    
                    // coeff += region.eRel * Complex(real: nextTriangle.CotanThetaB())
                    coeff = Complex(real: coeff.real + Er.real * cotanB, imag: coeff.imag + Er.imag * cotanB)
                }
                else
                {
                    DLog("Break (or boundary) at node: \(node)")
                    
                }
            }
            else // do the next adjacent triangle
            {
                let prevTriangle = nextTriangle
                
                nextTriangle = sortedTriangles[i + 1].NormalizedOn(n0: node)
                
                if prevTriangle.corners.n2.tag == nextTriangle.corners.n1.tag
                {
                    let region = nextTriangle.region! as! DielectricRegion
                    
                    /* OLD CODE (may have been slow)
                     guard let region = nextTriangle.region as? DielectricRegion else
                     {
                        ALog("Could not get region for triangle")
                        return
                     }
                     */
                    
                    let cotanB = nextTriangle.CotanThetaB()
                    let Er = region.eRel
                    
                    // coeff += region.eRel * Complex(real: nextTriangle.CotanThetaB())
                    coeff = Complex(real: coeff.real + Er.real * cotanB, imag: coeff.imag + Er.imag * cotanB)
                }
                else
                {
                    DLog("Break (or boundary) at node: \(node)")
                }
            }
            
            sumWi += coeff * 0.5
            
            self.matrixA![node.tag, colIndex] = Complex(real: -coeff.real * 0.5, imag: -coeff.imag * 0.5)
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
            
            let area = Complex(real: nextElement.Area())
            
            // we did the division of the constant when we defined it, so multiply it now (faster, I think)
            let iTerm = (rho * area) * constant
            
            result += iTerm
        }
        
        self.complexMatrixB[node.tag] = result
    }
}
