//
//  Mesh.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-07.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

import Foundation
import Cocoa

class Mesh
{
    // Counter for the tag number of newly created nodes
    var nodeIndex:Int = 0
    
    // Storage for ORIGINAL Bezier paths (if they were used). This will not change after refining the mesh.
    var bezierPaths:[NSBezierPath] = []
    
    // Nodes for the current Mesh
    var nodes:[Node] = []
    
    // Segments for the current Mesh
    var segments:[Edge] = []
    
    // Edges for the current Mesh
    var edges:[Edge] = []
    
    // Elements of the current Mesh
    var elements:[Element] = []
    
    // Regions being used in the current Mesh
    var regions:[Region] = []
    
    // Designated initializer
    // Basically, the geometric model to create a mesh for. Note that either withBezierPath or vertices MUST be non-empty a non-empty array. If both are empty, then a single vertex is created with coordinates equal to the largest Double and a tag equal to -1.
    init(withBezierPaths:[NSBezierPath], vertices:[NSPoint], regions:[Region])
    {
        if withBezierPaths.count + vertices.count == 0
        {
            nodes.append(Node(tag: -1, vertex: NSPoint(x: Double.greatestFiniteMagnitude, y: Double.greatestFiniteMagnitude)))
            
            return
        }
        
        for nextVertex in vertices
        {
            let newNode = Node(tag: self.nodeIndex, vertex: nextVertex)
            
            nodes.append(newNode)
            
            nodeIndex += 1
        }
        
        for nextPath in withBezierPaths
        {
            let elemCount = nextPath.elementCount
            
            var pathStartNode = Node()
            var currentNode = Node()
            
            let pointArray = NSPointArray.allocate(capacity: 3)
            
            for i in 0..<elemCount
            {
                let nextElement = nextPath.element(at: i, associatedPoints: pointArray)
                
                if nextElement == .moveToBezierPathElement
                {
                    pathStartNode = Node(tag: self.nodeIndex, vertex: pointArray[0])
                    self.nodeIndex += 1
                    
                    currentNode = pathStartNode
                    
                    self.nodes.append(pathStartNode)
                }
                else if nextElement == .lineToBezierPathElement
                {
                    let newNode = Node(tag: self.nodeIndex, vertex: pointArray[0])
                    self.nodeIndex += 1
                    
                    self.nodes.append(newNode)
                    self.segments.append(Edge(endPoint1: currentNode, endPoint2: newNode))
                    
                    currentNode = newNode
                }
                else if nextElement == .closePathBezierPathElement
                {
                    // The "end point" of this element is actually the original sart point of the path, so we won't add it again
                    self.segments.append(Edge(endPoint1: currentNode, endPoint2: pathStartNode))
                }
                else
                {
                    ALog("Curves are not implemented!")
                }
            }
            
            pointArray.deallocate()
        }
    }
    
    func RefineMesh(withMinAngle:Double) -> Bool
    {
        // allocate memory for the IO struct
        let inStruct = UnsafeMutablePointer<triangulateio>.allocate(capacity: 1)
        
        // Start with the point-related fields
        let pointlist = UnsafeMutablePointer<Double>.allocate(capacity: 2 * self.nodes.count)
        
        for nextNode in self.nodes
        {
            pointlist[2 * nextNode.tag] = Double(nextNode.vertex.x)
            pointlist[2 * nextNode.tag + 1] = Double(nextNode.vertex.y)
        }
        
        inStruct.pointee.pointlist = pointlist
        inStruct.pointee.numberofpoints = Int32(self.nodes.count)
        
        // We don't use point attributes or point markers, so we set things according to the triangle.h file
        inStruct.pointee.numberofpointattributes = 0
        inStruct.pointee.pointattributelist = nil
        inStruct.pointee.pointmarkerlist = nil
        
        // We don't use any of the triangle-related stuff on input
        inStruct.pointee.trianglelist = nil
        inStruct.pointee.triangleattributelist = nil
        inStruct.pointee.trianglearealist = nil
        inStruct.pointee.neighborlist = nil
        inStruct.pointee.numberoftriangles = 0
        inStruct.pointee.numberofcorners = 0
        inStruct.pointee.numberoftriangleattributes = 0
        
        // Now the segment-related fields
        var useSegmentsFlag = ""
        inStruct.pointee.segmentmarkerlist = nil
        if self.segments.count > 0
        {
            let segmentlist = UnsafeMutablePointer<Int32>.allocate(capacity: 2 * self.segments.count)
            
            var i = 0
            for nextSegment in self.segments
            {
                segmentlist[2 * i] = Int32(nextSegment.endPoint1.tag)
                segmentlist[2 * i + 1] = Int32(nextSegment.endPoint2.tag)
                i += 1
            }
        
            inStruct.pointee.segmentlist = segmentlist
            inStruct.pointee.numberofsegments = Int32(self.segments.count)
            
            useSegmentsFlag = "p"
        }
        else
        {
            inStruct.pointee.segmentlist = nil
            inStruct.pointee.numberofsegments = 0
        }
        
        // We don't use holes
        inStruct.pointee.holelist = nil
        inStruct.pointee.numberofholes = 0
        
        
        inStruct.deallocate()
        pointlist.deallocate()
        
        if inStruct.pointee.numberofsegments > 0
        {
            inStruct.pointee.segmentlist.deallocate()
        }
        
        return true
    }
    
}
