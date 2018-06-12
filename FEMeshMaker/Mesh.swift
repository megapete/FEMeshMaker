//
//  Mesh.swift
//  FEMeshMaker
//
//  Created by PeterCoolAssHuber on 2018-04-07.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This is essentially a wrapper for the Triangle program by Jonathan Richard Shewchuk. It takes simple Bezier paths as input (plus any extra points that are needed) and regions for the FE solution. Calling RefineMesh() will create all the triangles. Note that the RefineMesh routine creates structures like segments and edges that may not be used for FE programs based on Humphries methods (it uses Nodes and Triangles) but they are included here for completeness (and the possibility that I will find those structures useful as the program evolves).

import Foundation
import Cocoa

// A constant used during debugging
let PCH_USE_MAX_TRIANGLE_AREA = true

class Mesh
{
    // Counter for the tag number of newly created nodes
    var nodeIndex:Int = 0
    
    // Storage for ORIGINAL Bezier paths (if they were used). This will not change after refining the mesh.
    var bezierPaths:[NSBezierPath] = []
    
    // Nodes for the current Mesh
    var nodes:[Node] = []
    
    // Segments for the current Mesh. Note that after the call to triangulate, the entries in this array correspond to only those segments that are ON the original segments passed to the init() function.
    var segments:[Edge] = []
    
    // Edges for the current Mesh. Note that after the call to triangulate(), the entries in this array correspond to ALL the segments that make up the triangles, INCLUDING the ones in the segments array
    var edges:[Edge] = []
    
    // The vertices of "holes" (unmeshed areas) in the model
    var holes:[NSPoint] = []
    
    // Elements of the current Mesh
    var elements:[Element] = []
    
    // Regions being used in the current Mesh
    var regions:[Region] = []
    
    // Simple way of getting the region back from its tag
    var regionDict:[Int:Region] = [:]
    
    // Designated initializer
    // Basically, the geometric model to create a mesh for. Note that either withBezierPath or vertices MUST be non-empty a non-empty array. If both are empty, then a single vertex is created with coordinates equal to the largest Double and a tag equal to -1.
    init(withPaths:[MeshPath], vertices:[NSPoint], regions:[Region], holes:[NSPoint])
    {
        // If there are no paths or vertices, the routine returns with only a single node assigned, an "error" node which the calling routine can test for by checking if the Node's tag property is less than 0
        if withPaths.count + vertices.count == 0
        {
            nodes.append(Node(tag: -1, vertex: NSPoint(x: Double.greatestFiniteMagnitude, y: Double.greatestFiniteMagnitude)))
            
            return
        }
        
        // This probably isn't necessary since the nodeIndex's default value is 0, but we'll do it so that things are clear
        self.nodeIndex = 0
        
        // Get all the vertexes (if any) and convert them to nodes
        for i in 0..<vertices.count
        {
            let newNode = Node(tag: self.nodeIndex, vertex: vertices[i])
            
            nodes.append(newNode)
            
            nodeIndex += 1
        }
        
        // Paths are a bit more complicated since they are actually "code" for building a path, so the elements have to be decoded then converted into nodes and segments.
        for nextMeshPath in withPaths
        {
            let nextPath = nextMeshPath.path
            
            var nextMarker = 0
            if let boundary = nextMeshPath.boundary
            {
                nextMarker = boundary.tag
            }
            
            let elemCount = nextPath.elementCount
            
            // Initialize a couple of varables as "dummy" nodes
            var pathStartNode = Node()
            var currentNode = Node()
            
            // pointArray means different things depending on the NSBezierPath element under consideration
            let pointArray = NSPointArray.allocate(capacity: 3)
            
            for i in 0..<elemCount
            {
                let nextElement = nextPath.element(at: i, associatedPoints: pointArray)
                
                DLog("Point: \(pointArray[0])")
                if nextElement == .moveToBezierPathElement
                {
                    pathStartNode = Node(tag: self.nodeIndex, marker:nextMarker, vertex: pointArray[0])
                    
                    if self.nodes.contains(pathStartNode)
                    {
                        DLog("pathStartNode exists!")
                        
                        if let existingIndex = self.nodes.index(of: pathStartNode)
                        {
                            pathStartNode = self.nodes[existingIndex]
                        }
                        else
                        {
                            ALog("Ooh, that's a problem!")
                        }
                    }
                    else
                    {
                        self.nodeIndex += 1
                        self.nodes.append(pathStartNode)
                    }
                    
                    currentNode = pathStartNode
                }
                else if nextElement == .lineToBezierPathElement
                {
                    var newNode = Node(tag: self.nodeIndex, marker:nextMarker, vertex: pointArray[0])
                    if self.nodes.contains(newNode)
                    {
                        DLog("newNode exists!")
                        
                        if let existingIndex = self.nodes.index(of: newNode)
                        {
                            newNode = self.nodes[existingIndex]
                        }
                        else
                        {
                            ALog("Ooh, that's a problem!")
                        }
                    }
                    else
                    {
                        self.nodeIndex += 1
                        self.nodes.append(newNode)
                    }
                    
                    self.segments.append(Edge(endPoint1: currentNode, endPoint2: newNode, marker:nextMarker))
                    
                    currentNode = newNode
                }
                else if nextElement == .closePathBezierPathElement
                {
                    // The "end point" of this element is actually the original sart point of the path, so we won't add it again. If, for some reason, the current point is equal to the start point, we won't add a segment either
                    
                    if currentNode != pathStartNode
                    {
                        self.segments.append(Edge(endPoint1: currentNode, endPoint2: pathStartNode, marker:nextMarker))
                    }
                    
                    break // this is needed because NSBezierPath ends with a "moveto" the start point if it was created with an NSRect
                }
                else // must be .curveToBezierPathElement
                {
                    // Curves are a major pain in the butt. Since most of the curves we'll be using are relatively simple (they tend to be simple arcs, not weird splines, and they are usually 90 degrees), we use a simple flattening algorithm. NSBezierPath uses 4 control points to define a curve (ie: cubic Bezier curves). For now, we will arbitrarily split any curve into 5 lines (this may be adjusted for speed or accuracy at some point). 
                    
                    let segmentCount = 5
                    let tInterval = CGFloat(1.0 / CGFloat(segmentCount))
                    
                    let points:[NSPoint] = [currentNode.vertex, pointArray[0], pointArray[1], pointArray[2]]
                    
                    var t:CGFloat = tInterval
                    while t < 0.999 // careful for rounding...
                    {
                        // The PointOnCurve function is in GlobalDefs, on the off-chance we'll need it again someday
                        var newNode = Node(tag: self.nodeIndex, marker:nextMarker, vertex: PointOnCurve(points: points, t: t))
                        
                        if self.nodes.contains(newNode)
                        {
                            DLog("newNode exists!")
                            
                            if let existingIndex = self.nodes.index(of: newNode)
                            {
                                newNode = self.nodes[existingIndex]
                            }
                            else
                            {
                                ALog("Ooh, that's a problem!")
                            }
                        }
                        else
                        {
                            self.nodeIndex += 1
                            self.nodes.append(newNode)
                        }
                        
                        self.segments.append(Edge(endPoint1: currentNode, endPoint2: newNode, marker:nextMarker))
                        
                        currentNode = newNode
                        
                        t += tInterval
                    }
                    
                    // after processing the curve, currentNode points at the last point on the curve
                }
            }
            
            pointArray.deallocate()
        }
        
        
        // Triangle requires a different tag number for each "region reference point" but we don't want to save a bunch of different Regions (when most will be say, 'paper' or something). We therefore come up with a special tag number just for Triangle which is equal to the Region's tagBase plus the index of the reference point in question.
        self.regions = regions
        for nextRegion in regions
        {
            for i in 0..<nextRegion.refPoints.count
            {
                if self.regionDict[i + nextRegion.tagBase] != nil
                {
                    ALog("Duplicate region tag! Abort! Abort!")
                    return
                }
                
                self.regionDict[i + nextRegion.tagBase] = nextRegion
            }
        }
        
        self.holes = holes
    }
    
    func InitializeTriangleStruct() -> triangulateio
    {
        // There's an ugly way of using calloc in Swift, but I don't trust Apple to keep supporting it, so I did things in a more "Swifty" way.
        let zeroStruct = triangulateio(pointlist: nil, pointattributelist: nil, pointmarkerlist: nil, numberofpoints: 0, numberofpointattributes: 0, trianglelist: nil, triangleattributelist: nil, trianglearealist: nil, neighborlist: nil, numberoftriangles: 0, numberofcorners: 0, numberoftriangleattributes: 0, segmentlist: nil, segmentmarkerlist: nil, numberofsegments: 0, holelist: nil, numberofholes: 0, regionlist: nil, numberofregions: 0, edgelist: nil, edgemarkerlist: nil, normlist: nil, numberofedges: 0)
        
        return zeroStruct
    }
    
    // We default to the 'magic' minimum angle of 28.6 degrees
    func RefineMesh(withMinAngle:Double = 28.6) -> Bool
    {
        // This is the easiest (and safest) way to initialize a pointer to a struct in Swift. First, create a dummy "zeroed" struct
        let zeroStruct = triangulateio(pointlist: nil, pointattributelist: nil, pointmarkerlist: nil, numberofpoints: 0, numberofpointattributes: 0, trianglelist: nil, triangleattributelist: nil, trianglearealist: nil, neighborlist: nil, numberoftriangles: 0, numberofcorners: 0, numberoftriangleattributes: 0, segmentlist: nil, segmentmarkerlist: nil, numberofsegments: 0, holelist: nil, numberofholes: 0, regionlist: nil, numberofregions: 0, edgelist: nil, edgemarkerlist: nil, normlist: nil, numberofedges: 0)
        
        // allocate memory for the IO struct
        let inStruct = UnsafeMutablePointer<triangulateio>.allocate(capacity: 1)
        
        // initialize the memory to the zero struct
        inStruct.initialize(to: zeroStruct)
        
        // Start with the point-related fields
        let pointlist = UnsafeMutablePointer<Double>.allocate(capacity: 2 * self.nodes.count)
        let pointmarkerlist = UnsafeMutablePointer<Int32>.allocate(capacity: self.nodes.count)
        
        // We adopt the method that Meeker uses in FEMM to come up with a DefaultMeshSize. See his source code in file bd_writepoly.cpp and search for 'DefaultMeshSize'. Note that he refers to a variable called 'BoundingBoxFraction' that is set to 100.0 elsewhere. We will use this number for all regions that are not set as "LowResolution".
        var xx = Complex(real: Double(self.nodes[0].vertex.x), imag: Double(self.nodes[0].vertex.y))
        var yy = xx
        let boundingBoxFraction = 100.0
        
        for nextNode in self.nodes
        {
            pointlist[2 * nextNode.tag] = Double(nextNode.vertex.x)
            pointlist[2 * nextNode.tag + 1] = Double(nextNode.vertex.y)
            pointmarkerlist[nextNode.tag] = Int32(nextNode.marker)
            
            if Double(nextNode.vertex.x) < xx.real
            {
                xx.real = Double(nextNode.vertex.x)
            }
            if Double(nextNode.vertex.y) < xx.imag
            {
                xx.imag = Double(nextNode.vertex.y)
            }
            if Double(nextNode.vertex.x) > yy.real
            {
                yy.real = Double(nextNode.vertex.x)
            }
            if Double(nextNode.vertex.y) > yy.imag
            {
                yy.imag = Double(nextNode.vertex.y)
            }
        }
        
        let defaultMeshSize = pow((yy - xx).cabs / boundingBoxFraction, 2.0)
        
        // Set the low resolution max area to a huge number (the size of the meshbounds, actually) so that Triangle just creates enough Delaunay triangles to satisfy the minimum angle criteria
        let loResMeshSize = (yy.real - xx.real) * (yy.imag - xx.imag)
        
        inStruct.pointee.pointlist = pointlist
        inStruct.pointee.pointmarkerlist = pointmarkerlist
        inStruct.pointee.numberofpoints = Int32(self.nodes.count)
        
        // We don't use any of the triangle-related stuff on input
        // inStruct.pointee.numberofcorners = 3
        
        // Now the segment-related fields
        var useSegmentsFlag = ""
        if self.segments.count > 0
        {
            let segmentlist = UnsafeMutablePointer<Int32>.allocate(capacity: 2 * self.segments.count)
            let segmentmarkerlist = UnsafeMutablePointer<Int32>.allocate(capacity: self.segments.count)
            
            var i = 0
            for nextSegment in self.segments
            {
                segmentlist[2 * i] = Int32(nextSegment.endPoint1.tag)
                segmentlist[2 * i + 1] = Int32(nextSegment.endPoint2.tag)
                segmentmarkerlist[i] = Int32(nextSegment.marker)
                i += 1
            }
        
            inStruct.pointee.segmentlist = segmentlist
            inStruct.pointee.numberofsegments = Int32(self.segments.count)
            inStruct.pointee.segmentmarkerlist = segmentmarkerlist
            
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
        if self.regions.count > 0
        {
            let regionlist = UnsafeMutablePointer<Double>.allocate(capacity: 4 * regionDict.count)
            
            var i = 0
            for nextRegion in regions
            {
                var tagIndex = 0
                for nextRefPoint in nextRegion.refPoints
                {
                    if nextRefPoint.x == CGFloat(0.0) && nextRefPoint.y == CGFloat(0.0)
                    {
                        DLog("Region's reference point is (0,0). Did you mean to do this?")
                    }
                    
                    regionlist[4 * i] = Double(nextRefPoint.x)
                    regionlist[4 * i + 1] = Double(nextRefPoint.y)
                    regionlist[4 * i + 2] = Double(nextRegion.tagBase + tagIndex)
                    
                    // Set the mesh size according to whether or not the region's isLowRes property is true
                    var meshSize = defaultMeshSize
                    if nextRegion.isLowRes
                    {
                        meshSize = loResMeshSize
                    }
                    regionlist[4 * i + 3] = meshSize
                    
                    tagIndex += 1
                    
                    i += 1
                }
            }
            
            inStruct.pointee.regionlist = regionlist
            inStruct.pointee.numberofregions = Int32(self.regionDict.count)
            
            useRegionsFlag = "A"
        }
        
        // on entry we don't send in edge-related data
        
        // Set up the flags that we will pass to the triangulate() call. We always use -z, -D, -j, -e, and -n. The two flags -p and -A are conditionally set above. The 'q' flag is followed by the requested minimum angle
        var areaFlag = "a"
        if !PCH_USE_MAX_TRIANGLE_AREA
        {
            areaFlag = ""
        }
        
        let argString = "\(areaFlag)zDjen\(useSegmentsFlag)\(useRegionsFlag)q\(withMinAngle)"
        
        let outStruct = UnsafeMutablePointer<triangulateio>.allocate(capacity: 1)
        outStruct.initialize(to: zeroStruct)
        
        triangulate(argString, inStruct, outStruct, nil)
        
        // Deallocate all inStruct pointers that were created in Swift and then deallocate inStruct itself
        pointlist.deallocate()
        pointmarkerlist.deallocate()
        
        if inStruct.pointee.numberofsegments > 0
        {
            inStruct.pointee.segmentlist.deallocate()
            inStruct.pointee.segmentmarkerlist.deallocate()
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
        
        // Create a variable so that we don't have to write outStruct.pointee every time
        let output = outStruct.pointee
        
        // Reset the nodes property
        self.nodes = []
        for i in 0..<Int(output.numberofpoints)
        {
            let newNode = Node(tag: i, marker: Int(output.pointmarkerlist[i]), vertex: NSPoint(x: output.pointlist[2 * i], y: output.pointlist[2 * i + 1]))
            
            self.nodes.append(newNode)
        }
        
        self.nodeIndex = self.nodes.count
        
        DLog("Num nodes: \(self.nodes.count)")
        
        // Reset the segments property. Segments are those edges that are components of the original segments passed to the routine.
        self.segments = []
        for i in 0..<Int(output.numberofsegments)
        {
            let newSegment = Edge(endPoint1: self.nodes[Int(output.segmentlist[2 * i])], endPoint2: self.nodes[Int(output.segmentlist[2 * i + 1])], marker:Int(output.segmentmarkerlist[i]))
            
            self.segments.append(newSegment)
        }
        
        DLog("Num segs: \(self.segments.count)")
        
        // Reset the edges property. Edges are ALL the edges in the mesh, including those that are already in segments.
        self.edges = []
        for i in 0..<Int(output.numberofedges)
        {
            let newEdge = Edge(endPoint1: nodes[Int(output.edgelist[2 * i])], endPoint2: nodes[Int(output.edgelist[2 * i + 1])], marker:Int(output.edgemarkerlist[i]))
            
            // We do not need to set the neighbour properties of the two end Nodes because that is done in the Edge.init() function.
            
            self.edges.append(newEdge)
        }
        
        DLog("Num edges: \(self.edges.count)")
        
        // Reset the elements (triangles) property
        self.elements = []
        
        // The way triangle handles regions is a bit confusing in that it assigns an "attribute" to the triangle. However, it seems to allow multiple attributes, which I do not understand (or at least I do not understand how to input multiples in the first place).
        guard Int(output.numberoftriangleattributes) <= 1 else
        {
            ALog("WTF???")
            return false
        }
        
        let numCorners = Int(output.numberofcorners)
        
        for i in 0..<Int(output.numberoftriangles)
        {
            let triangleAttribute = Int(output.triangleattributelist[i])
            
            var triangleRegion:Region? = nil
            if triangleAttribute != 0
            {
                triangleRegion = self.regionDict[triangleAttribute]
                
                if triangleRegion == nil
                {
                    ALog("Undefined region returned for triangle")
                }
            }
            
            let newElement = Element(n0: nodes[Int(output.trianglelist[numCorners * i])], n1: nodes[Int(output.trianglelist[numCorners * i + 1])], n2: nodes[Int(output.trianglelist[numCorners * i + 2])], region: triangleRegion)
            
            if triangleAttribute == 0
            {
                ALog("Regionless triangle at CofM:\(newElement.CenterOfMass())")
            }
            
            self.elements.append(newElement)
        }
        
        DLog("Num triangles: \(self.elements.count)\n\nSetting triangle neighbours...")
        
        
        // Set the neighbour triangles for each triangle. As a for-loop this can be slow, so let's try GCD.
        // for i in 0..<self.elements.count
        DispatchQueue.concurrentPerform(iterations: self.elements.count, execute: { (i:Int) -> Void in
        
            elements[i].neighbours = []
            let neigh0 = Int(output.neighborlist[i * 3])
            if neigh0 >= 0
            {
                elements[i].neighbours.append(elements[neigh0])
            }
            
            let neigh1 = Int(output.neighborlist[i * 3 + 1])
            if neigh1 >= 0
            {
                elements[i].neighbours.append(elements[neigh1])
            }
            
            let neigh2 = Int(output.neighborlist[i * 3 + 2])
            if neigh2 >= 0
            {
                elements[i].neighbours.append(elements[neigh2])
            }
        })
 
        
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
        // triangle simply copies the regionlist and holelist from inStruct, so we want to make sure we don't free them twice
        // free(output.holelist)
        // free(output.regionlist)
        free(output.edgelist)
        free(output.edgemarkerlist)
        free(output.normlist)
        
        outStruct.deallocate()
        
        
        
        return true
    }
    
}
