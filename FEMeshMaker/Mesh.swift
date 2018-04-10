//
//  Mesh.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-07.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This is essentially a wrapper for the Triangle program by Jonathan Richard Shewchuk. It takes simple Bezier paths as input (plus any extra points that are needed) and regions for the FE solution. Calling RefineMesh() will create all the triangles.

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
    
    // The vertices of "holes" (unmeshed areas) in the model
    var holes:[NSPoint] = []
    
    // Elements of the current Mesh
    var elements:[Element] = []
    
    // Regions being used in the current Mesh
    var regions:[Region] = []
    
    var regionDict:[Int:Region] = [:]
    
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
                    // The "end point" of this element is actually the original sart point of the path, so we won't add it again. If, for some reason, the current point is equal to the start point, we won't add an edge
                    
                    if currentNode != pathStartNode
                    {
                        self.segments.append(Edge(endPoint1: currentNode, endPoint2: pathStartNode))
                    }
                }
                else // must be .curveToBezierPathElement
                {
                    // Curves are a major pain in the butt. Since most of the curves we'll be using are relatively simple (they tend to be simple arcs, not weird splines), we use a simple flattening algorithm. NSBezierPath uses 4 control points to define a curve (ie: cubic Bezier curves). For now, we will arbitrarily split any curve into 10 lines (this may be adjusted for speed or accuracy at some point).
                    
                    let segmentCount = 10
                    let tInterval = CGFloat(1.0 / CGFloat(segmentCount))
                    
                    let points:[NSPoint] = [currentNode.vertex, pointArray[0], pointArray[1], pointArray[2]]
                    
                    var t:CGFloat = tInterval
                    while t < 0.999 // careful for rounding...
                    {
                        // The PointOnCurve function is in GlobalDefs, on the off chance we'll need it again someday
                        let newNode = Node(tag: self.nodeIndex, vertex: PointOnCurve(points: points, t: t))
                        self.nodeIndex += 1
                        
                        self.nodes.append(newNode)
                        self.segments.append(Edge(endPoint1: currentNode, endPoint2: newNode))
                        
                        currentNode = newNode
                        
                        t += tInterval
                    }
                    
                    // after processing the curve, currentNode points at the last point on the curve
                }
            }
            
            pointArray.deallocate()
        }
        
        self.regions = regions
        for nextRegion in regions
        {
            self.regionDict.updateValue(nextRegion, forKey: nextRegion.tag)
        }
    }
    
    func AllocateAndInitializeTriangleStruct() -> UnsafeMutablePointer<triangulateio>
    {
        // There's an ugly way of using calloc in Swift, but I don't trust Apple to keep supporting it, so I did things in a more "Swifty" way.
        
        let result = UnsafeMutablePointer<triangulateio>.allocate(capacity: 1)
        
        var theStruct = result.pointee
        
        theStruct.pointlist = nil
        theStruct.pointattributelist = nil
        theStruct.pointmarkerlist = nil
        theStruct.numberofpoints = 0
        theStruct.numberofpointattributes = 0
        
        theStruct.trianglelist = nil
        theStruct.triangleattributelist = nil
        theStruct.trianglearealist = nil
        theStruct.neighborlist = nil
        theStruct.numberoftriangles = 0
        theStruct.numberofcorners = 0
        theStruct.numberoftriangleattributes = 0
        
        theStruct.segmentlist = nil
        theStruct.segmentmarkerlist = nil
        theStruct.numberofsegments = 0
        
        theStruct.holelist = nil
        theStruct.numberofholes = 0
        
        theStruct.regionlist = nil
        theStruct.numberofregions = 0
        
        theStruct.edgelist = nil
        theStruct.edgemarkerlist = nil
        theStruct.normlist = nil
        theStruct.numberofedges = 0
        
        return result
    }
    
    // We default to the 'magic' minimum angle of 28.6 degrees
    func RefineMesh(withMinAngle:Double = 28.6) -> Bool
    {
        // allocate memory for the IO struct, setting everything to nil/0
        let inStruct = AllocateAndInitializeTriangleStruct()
        
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
        // inStruct.pointee.numberofpointattributes = 0
        // inStruct.pointee.pointattributelist = nil
        // inStruct.pointee.pointmarkerlist = nil
        
        // We don't use any of the triangle-related stuff on input
        // inStruct.pointee.trianglelist = nil
        // inStruct.pointee.triangleattributelist = nil
        // inStruct.pointee.trianglearealist = nil
        // inStruct.pointee.neighborlist = nil
        // inStruct.pointee.numberoftriangles = 0
        // inStruct.pointee.numberofcorners = 0
        // inStruct.pointee.numberoftriangleattributes = 0
        
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
        
        // holes (we don't need to set any flags, seeing as how we don't set the 'r' flag (see triangle.h)
        if self.holes.count > 0
        {
            let holelist = UnsafeMutablePointer<Double>.allocate(capacity: 2 * self.holes.count)
            
            var i = 0
            for nextHole in self.holes
            {
                holelist[2 * i] = Double(nextHole.x)
                holelist[2 * i + 1] = Double(nextHole.y)
                i += 1
            }
            
            inStruct.pointee.holelist = holelist
            inStruct.pointee.numberofholes = Int32(self.holes.count)
        }
        
        // Region-related data
        var useRegionsFlag = ""
        inStruct.pointee.regionlist = nil
        if self.regions.count > 0
        {
            var totalRegionDataCount = 0
            for nextRegion in regions
            {
                guard nextRegion.refPoints.count > 0 else
                {
                    ALog("Illegal to create a region without any reference points!")
                    return false
                }
                
                totalRegionDataCount += nextRegion.refPoints.count
            }
            
            let regionlist = UnsafeMutablePointer<Double>.allocate(capacity: 4 * totalRegionDataCount)
            
            var i = 0
            for nextRegion in regions
            {
                for nextRefPoint in nextRegion.refPoints
                {
                    if nextRefPoint.x == CGFloat(0.0) && nextRefPoint.y == CGFloat(0.0)
                    {
                        DLog("Region's reference point is (0,0). Did you mean to do this?")
                    }
                    
                    regionlist[4 * i] = Double(nextRefPoint.x)
                    regionlist[4 * i + 1] = Double(nextRefPoint.y)
                    regionlist[4 * i + 2] = Double(nextRegion.tag)
                    regionlist[4 * i + 2] = 0.0 // unused
                    i += 1
                }
            }
            
            inStruct.pointee.regionlist = regionlist
            inStruct.pointee.numberofregions = Int32(self.regions.count)
            
            useRegionsFlag = "A"
        }
        
        // Set up the flags that we will pass to the triangulate() call. We always use -z, -j, -e, and -n. The two flags -p and -A are conditionally set above. The 'q' flag is followed by the requested minimum angle
        let argString = "zjen\(useSegmentsFlag)\(useRegionsFlag)q\(withMinAngle)"
        
        let outStruct = AllocateAndInitializeTriangleStruct()
        
        triangulate(argString, inStruct, outStruct, nil)
        
        // Deallocate all inStruct pointers that were created in Swift and then deallocate inStruct itself
        pointlist.deallocate()
        
        if inStruct.pointee.numberofsegments > 0
        {
            inStruct.pointee.segmentlist.deallocate()
        }
        
        if inStruct.pointee.numberofregions > 0
        {
            inStruct.pointee.regionlist.deallocate()
        }
        
        if inStruct.pointee.numberofholes > 0
        {
            inStruct.pointee.holelist.deallocate()
        }
        
        inStruct.deallocate()
        
        // Transfer all the new data from outStruct to the properties of self
        var output = outStruct.pointee
        
        self.nodes = []
        for i in 0..<Int(output.numberofpoints)
        {
            let newNode = Node(tag: i, vertex: NSPoint(x: output.pointlist[2 * i], y: output.pointlist[2 * i + 1]))
            
            nodes.append(newNode)
        }
        
        self.segments = []
        for i in 0..<Int(output.numberofsegments)
        {
            let newSegment = Edge(endPoint1: nodes[Int(output.segmentlist[2 * i])], endPoint2: nodes[Int(output.segmentlist[2 * i + 1])])
            
            segments.append(newSegment)
        }
        
        self.edges = []
        for i in 0..<Int(output.numberofedges)
        {
            let newEdge = Edge(endPoint1: nodes[Int(output.edgelist[2 * i])], endPoint2: nodes[Int(output.edgelist[2 * i + 1])])
            
            edges.append(newEdge)
        }
        
        self.elements = []
        let numTriAttr = Int(output.numberoftriangleattributes)
        for i in 0..<Int(output.numberoftriangles)
        {
            var triRegion:Region? = nil
            if numTriAttr > 0
            {
                let triRegionTag = Int(output.triangleattributelist[numTriAttr * i])
                triRegion = self.regionDict[triRegionTag]
            }
            
            let newElement = Element(n0: nodes[Int(output.trianglelist[3 * i])], n1: nodes[Int(output.trianglelist[3 * i + 1])], n2: nodes[Int(output.trianglelist[3 * i + 2])], region: triRegion)
            
            self.elements.append(newElement)
        }
        
        // triangle simply copies the regionlist and holelist from inStruct, so we want to make sure we don't free them twice
        output.regionlist = nil
        output.holelist = nil
        
        // We need to free all the memory that triangle (may have) malloc'd
        free(output.pointlist)
        free(output.pointattributelist)
        free(output.pointmarkerlist)
        free(output.trianglelist)
        free(output.triangleattributelist)
        free(output.trianglearealist)
        free(output.neighborlist)
        free(output.segmentlist)
        free(output.segmentmarkerlist)
        // free(output.holelist)
        // free(output.regionlist)
        free(output.edgelist)
        free(output.edgemarkerlist)
        free(output.normlist)
        
        outStruct.deallocate()
        
        return true
    }
    
}
