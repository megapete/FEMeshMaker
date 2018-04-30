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
    
    init(withPaths:[MeshPath], units:FE_Mesh.Units, vertices:[NSPoint], regions:[Region], holes:[NSPoint])
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
        
        self.Setup_A_Matrix()
        self.SetupComplexBmatrix()
    }
    
    override func Solve()
    {
        let solutionVector:[Complex] = self.SolveMatrix()
        
        self.SetNodePhiValuesTo(solutionVector)
    }
    
    override func DataAtPoint(_ point:NSPoint) -> [(name:String, value:Complex, units:String)]
    {
        let pointValues = self.ValuesAtPoint(point)
        
        let volts = ("V:", pointValues.phi, "Volts")
        let absVolts = ("|V|:", Complex(real:pointValues.phi.cabs), "Volts")
        
        let Ex = pointValues.slopeX
        let Ey = pointValues.slopeY
        
        // This comes from Andersen's paper "Finite Element Solution of Complex Potential Electric Fields", equations 19, 20, and 21
        let phaseAngleDiff = abs(Ex.carg - Ey.carg)
        
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
            
            guard let region = nextTriangle.region as? DielectricRegion else
            {
                ALog("Could not get region for triangle")
                return
            }
            
            var coeff = region.eRel /* Complex(real: Double(nextTriangle.CenterOfMass().x)) */ * Complex(real: nextTriangle.CotanThetaA()) * Complex(real: 0.5)
            
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
                    
                    coeff += region.eRel /* Complex(real: Double(nextTriangle.CenterOfMass().x)) */ * Complex(real: nextTriangle.CotanThetaB()) * Complex(real: 0.5)
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
                
                coeff += region.eRel /* Complex(real: Double(nextTriangle.CenterOfMass().x)) */ * Complex(real: nextTriangle.CotanThetaB()) * Complex(real: 0.5)
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
            
            let area = Complex(real: nextElement.Area())
            
            // we did the division of the constant when we defined it, so multiply it now (faster, I think)
            let iTerm = (rho * area) * constant
            
            result += iTerm
        }
        
        self.complexMatrixB[node.tag] = result
    }
}
