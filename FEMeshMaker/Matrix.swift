//
//  PCH_Matrix.swift
//  MatrixTesting
//
//  Created by Peter Huber on 2016-01-26.
//  Copyright © 2016 Huberis Technologies. All rights reserved.

// UPDATE 2018-04-08: Removed the Complex class definition, which has been moved to the PCH_Defs file

//
// My very own matrix class, based on BLAS and SparseBLAS. This is essentially a Swift-coded rewrite of PCH_BLAS_Matrix (which was written in Objective-C and used a C-library (SparseLib with UMFPack) for sparse matrices). It worked well, but it was a major pain because including libraries in XCode is majorly painful. Also, if I ever sell anything based on this class, I would have needed to do it under the GNU license to use UMFPack.

// All this is complicated by the fact that Apple's implementation of Sparse BLAS is not in accordance with the standard - they've created their own interface to the routines and have not exposed any of the direct SparseBLAS calls. And, they haven't implemented Complex data types for their implementation, which means that to use it, I'll have to convert complex numbers to 2x2 matrices, execute the Sparse BLAS function(s), then convert back.

// The Sparse BLAS solving routine expects the matrix to be in triangular form. The strategy here is to do an LU factorization of the sparse matrix A. So, first we do PA=LU (where P is the "permutation matrix" and is representative of the reordering of rows that may be required - this is the IPIV argument in many LAPACK routines). Then, AX=B becomes LUX=PB. This can be solved by doing LY=PB and then UX=Y. Now, this is good, because the Sparse BLAS provides triangular solve routines. However, it does not provide sparse LU factorization. One strategy is to create a general matrix from the sparse matrix. We then can do a factorization using DGETRF. The two triangular matrices L and U must then be converted back to sparse types, and the two solves can be done (simple!). However, some poor schmuck already did lots of the testing we'll need to do. See https://forums.developer.apple.com/thread/27631 Note that he says in a follow-up post that it's really not worth the work (presumably since the only way to use BLAS factoring is to recreate the sparse matrix as a general one). I will try and find/implement a sparse factorization algorithm.

// I have decided to implement the recursive algorithm described in the paper "Recursive approach in sparse matrix LU factorization" by "J. Dongarra et al". The function names are similar to their LAPACK analogues, but are prefixed by "PCH_Sparse_" for all the functions. Also note that I have decided to make these functions global because they're recursive.


/*
    Notes:

    1) All buffers are in COLUMN-MAJOR order
    2) Access (both setting and getting) is via a comma-separated square bracket subscript (like arrays). So, to get at the element at row 5, column 9: element = matrix[5,9].
*/

import Cocoa
import Foundation
import Accelerate



// Operators for PCH_Matrix (just to be cool)
func *(left:PCH_Matrix, right:PCH_Matrix) -> PCH_Matrix?
{
    return left.MultiplyBy(right)
}

func *(left:Double, right:PCH_Matrix) -> PCH_Matrix
{
    let result = PCH_Matrix(sourceMatrix: right)!
    
    for row in 0..<result.numRows
    {
        for col in 0..<result.numCols
        {
            result[row,col] *= left
        }
    }
    
    return result
}

func +(left:PCH_Matrix, right:PCH_Matrix) -> PCH_Matrix
{
    return left.AddSubtract(right)
}

func += (left: inout PCH_Matrix, right:PCH_Matrix)
{
    left = left + right
}

func -(left:PCH_Matrix, right:PCH_Matrix) -> PCH_Matrix
{
    return left.AddSubtract(right, isAdd: false)
}


/*
// Operators for Complex types

/// Operator '+' for the Complex struct
func +(left:Complex, right:Complex) -> Complex
{
    return Complex(real: left.real + right.real, imag: left.imag + right.imag)
}

/// Operator '-' for the Complex struct
func -(left:Complex, right:Complex) -> Complex
{
    return Complex(real: left.real - right.real, imag: left.imag - right.imag)
}

/// Operator '*' (multiplication) for the Complex struct
func *(left:Complex, right:Complex) -> Complex
{
    // Note: This method comes from https://en.wikipedia.org/wiki/Complex_number#Elementary_operations
    
    let a = left.real
    let b = left.imag
    
    let c = right.real
    let d = right.imag
    
    return Complex(real: a*c - b*d, imag: b*c + a*d)
}

/// Operator '/' (division) for the Complex struct
func /(left:Complex, right:Complex) -> Complex
{
    // Note: This method comes from https://en.wikipedia.org/wiki/Complex_number#Elementary_operations
    
    let a = left.real
    let b = left.imag
    
    let c = right.real
    let d = right.imag
    
    ZAssert(c != 0.0 || d != 0.0, message: "Attempt to divide complex number by 0")
    
    let denominator = c*c + d*d
    
    return Complex(real: (a*c + b*d) / denominator, imag: (b*c - a*d) / denominator)
}


/// Create a structure for complex numbers that we'll use in this class
struct Complex:CustomStringConvertible
{
    var real:Double
    var imag:Double
    
    /// Absolute value
    var cabs:Double
    {
        return sqrt(self.real * self.real + self.imag * self.imag)
    }
    
    /// Argument (angle) in radians
    var carg:Double
    {
        let x = self.real
        let y = self.imag
        
        ZAssert(x != 0.0 || y != 0.0, message: "Cannot compute argument of 0")
        
        if (x > 0.0)
        {
            return atan(y / x)
        }
        else if (x < 0.0 && y >= 0.0)
        {
            return atan(y / x) + π
        }
        else if (x < 0.0 && y < 0.0)
        {
            return atan(y / x) - π
        }
        else if (x == 0.0 && y > 0.0)
        {
            return π / 2.0
        }
        else
        {
            return -π / 2.0
        }
    }
    
    /// Simple conjugate function
    var conjugate:Complex
    {
        return Complex(real: self.real, imag: -self.imag)
    }
    
    // This is what shows up in 'print' statements
    var description:String
    {
        var result = ""
        
        if (self.real == 0.0 && self.imag == 0.0)
        {
            result = "0.0"
        }
        
        if (self.real != 0.0)
        {
            result += "\(self.real)"
        }
        
        if (self.imag != 0.0)
        {
            if (self.real != 0.0)
            {
                result += " "
                
                if (self.imag < 0)
                {
                    result += "- "
                }
                else
                {
                    result += "+ "
                }
                
                result += "\(abs(self.imag))i"
            }
            else
            {
                result = "\(self.imag)i"
            }
        }
        
        return result
    }
}
 */
/**
    A struct that will be used for the keys in the dictionary that will store a sparse matrix
*/
struct sparseKeyType:Hashable
{
    
    let row:Int
    let col:Int
    
    // I found this hash function somewhere on the net
    internal var hashValue: Int {
        return self.row.hashValue << MemoryLayout<Int>.size ^ self.col.hashValue
    }
}

/// The == function must be defined for Hashable types
internal func ==(lhs:sparseKeyType, rhs:sparseKeyType) -> Bool
{
    return (lhs.row == rhs.row) && (lhs.col == rhs.col)
}


/// The minimum dimension to use for a sparse matrix (during debugging, this will be artificially low. Otherwise, it should be set to around 500)
let PCH_Sparse_MinDimension = 250

/// Helper struct to speed up operations where submatrices are just read from supermatrices (ie: they are unchanged by the routine). Note that for now, only double-precision access is available.
struct PCH_SubMatrix
{
    let matrix:PCH_Matrix
    
    let rowStart:Int
    let rowEnd:Int
    let colStart:Int
    let colEnd:Int
    
    var numRows:Int
    {
        return rowEnd - rowStart + 1
    }
    
    var numCols:Int
    {
        return colEnd - colStart + 1
    }
    
    /**
        Read-only access to the values in the matrix
    */
    subscript(row: Int, column: Int) -> Double
    {
        get
        {
            return matrix[rowStart + row, colStart + column]
        }
    }
    
    /**
        Designated initializer to allow checking the parameters.
        
        - parameter matrix: The PCH_Matrix that holds the submatrix
        - parameter rowStart: The first row of matrix to use in the submatrix
        - parameter rowEnd: The last row of matrix to use in the submatrix
        - parameter colStart: The first column of matrix to use in the submatrix
        - parameter colEnd: The last column of matrix to use in the submatrix
    */
    init(matrix:PCH_Matrix, rowStart:Int, rowEnd:Int, colStart:Int, colEnd:Int)
    {
        ZAssert(rowStart >= 0 && rowStart <= rowEnd && rowEnd < matrix.numRows && colStart >= 0 && colStart <= colEnd && colEnd < matrix.numCols, message: "Illegal index")
        
        self.matrix = matrix
        self.rowStart = rowStart
        self.rowEnd = rowEnd
        self.colStart = colStart
        self.colEnd = colEnd
    }
    
    /**
        Designated initializer to create a submatrix from a submatrix
    */
    init(submatrix:PCH_SubMatrix, rowStart:Int, rowEnd:Int, colStart:Int, colEnd:Int)
    {
        ZAssert(rowStart >= 0 && rowStart <= rowEnd && rowEnd < submatrix.numRows && colStart >= 0 && colStart <= colEnd && colEnd < submatrix.numCols, message: "Illegal index")
        
        self.matrix = submatrix.matrix
        self.rowStart = submatrix.rowStart + rowStart
        self.rowEnd = submatrix.rowStart + rowEnd
        self.colStart = submatrix.colStart + colStart
        self.colEnd = submatrix.colStart + colEnd
    }
    
    /**
        Convenience initializer to create a submatrix that represents the whole submatrix
    */
    init(submatrix:PCH_SubMatrix)
    {
        self.init(submatrix: submatrix, rowStart: 0, rowEnd: submatrix.numRows - 1, colStart: 0, colEnd: submatrix.numCols - 1)
    }
    
    /**
        Convenience initializer to create a submatrix that represents the whole matrix
    */
    init(matrix:PCH_Matrix)
    {
        self.init(matrix: matrix, rowStart: 0, rowEnd: matrix.numRows - 1, colStart: 0, colEnd: matrix.numCols - 1)
    }
}


/**
    The xGETRF function for double-precision sparse matrices
*/
func PCH_Sparse_dgetrf(_ A:PCH_SubMatrix) -> PCH_Matrix
{
    #if DEBUG
    // Only square matrices are allowed
    ZAssert(A.numRows == A.numCols, message: "Only square matrices can be factored")
    #endif
    
    if A.numCols == 1
    {
        return PCH_Matrix(subMatrix: A, convertToGE: false)
    }
    
    let n1 = A.numRows / 2
    
    // var A11 = A.Submatrix(fromRow: 0, toRow: n1-1, fromCol: 0, toCol: n1-1, convertToGE: false)
    var A11 = PCH_SubMatrix(submatrix: A, rowStart: 0, rowEnd: n1-1, colStart: 0, colEnd: n1-1)
    A11 = PCH_SubMatrix(matrix: PCH_Sparse_dgetrf(A11))
    
    
    // var A21 = A.Submatrix(fromRow: n1, toRow: A.numRows-1, fromCol: 0, toCol: n1-1, convertToGE: false)
    var A21 = PCH_SubMatrix(submatrix: A, rowStart: n1, rowEnd: A.numRows-1, colStart: 0, colEnd: n1-1)
    
    // The xTRSM call only accesses the upper triangle so we can simply pass the whole matrix A11
    A21 = PCH_SubMatrix(matrix: PCH_Sparse_dtrsm(U: A11, B: A21))
    
    // var A12 = A.Submatrix(fromRow: 0, toRow: n1-1, fromCol: n1, toCol: A.numCols-1, convertToGE: false)
    var A12 = PCH_SubMatrix(submatrix: A, rowStart: 0, rowEnd: n1-1, colStart: n1, colEnd: A.numCols - 1)
    
    A12 = PCH_SubMatrix(matrix: PCH_Sparse_dtrsm(L: A11, B: A12))
    
    // var A22 = A.Submatrix(fromRow: n1, toRow: A.numRows-1, fromCol: n1, toCol: A.numCols-1, convertToGE: false)
    var A22 = PCH_SubMatrix(submatrix: A, rowStart: n1, rowEnd: A.numRows-1, colStart: n1, colEnd: A.numCols - 1)
    
    A22 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: A21, B: A12, C: A22))
    
    A22 = PCH_SubMatrix(matrix: PCH_Sparse_dgetrf(A22))
    
    // reassemble the matrix into its LU form
    let result = PCH_Matrix(numRows: A.numRows, numCols: A.numCols, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.sparseMatrix)
    
    var rowBase = 0
    var colBase = 0
    
    // A11
    for row in 0..<n1
    {
        for col in 0..<n1
        {
            // let value:__CLPK_doublereal = A11[row,col]
            // result[rowBase + row, colBase + col] = value
            
            result.sparseDoubleDict![sparseKeyType(row: rowBase+row, col: colBase+col)] = A11.matrix.sparseDoubleDict![sparseKeyType(row: row, col: col)]

        }
    }
    
    // A21
    rowBase = n1
    for row in 0..<A21.numRows
    {
        for col in 0..<n1
        {
            // let value:__CLPK_doublereal = A21[row,col]
            // result[rowBase + row, colBase + col] = value
            
            result.sparseDoubleDict![sparseKeyType(row: rowBase+row, col: colBase+col)] = A21.matrix.sparseDoubleDict![sparseKeyType(row: row, col: col)]

        }
    }
    
    // A12
    rowBase = 0
    colBase = n1
    for row in 0..<n1
    {
        for col in 0..<A12.numCols
        {
            // let value:__CLPK_doublereal = A12[row,col]
            // result[rowBase + row, colBase + col] = value
            
            result.sparseDoubleDict![sparseKeyType(row: rowBase+row, col: colBase+col)] = A12.matrix.sparseDoubleDict![sparseKeyType(row: row, col: col)]

        }
    }
    
    // A22
    rowBase = n1
    for row in 0..<A22.numRows
    {
        for col in 0..<A22.numCols
        {
            // let value:__CLPK_doublereal = A22[row,col]
            // result[rowBase + row, colBase + col] = value
            
            result.sparseDoubleDict![sparseKeyType(row: rowBase+row, col: colBase+col)] = A22.matrix.sparseDoubleDict![sparseKeyType(row: row, col: col)]

        }
    }
    
    return result
}

/**
    The xGEMM function for double-precision sparse matrices
*/
func PCH_Sparse_dgemm(alpha:__CLPK_doublereal, beta:__CLPK_doublereal, A:PCH_SubMatrix, B:PCH_SubMatrix, C:PCH_SubMatrix) -> PCH_Matrix
{
    // after testing, consider putting these ZAsserts into an "#if DEBUG" block
    
    #if DEBUG
    ZAssert(A.matrix.matrixPrecision == PCH_Matrix.precisions.doublePrecision && B.matrix.matrixPrecision == PCH_Matrix.precisions.doublePrecision && C.matrix.matrixPrecision == PCH_Matrix.precisions.doublePrecision, message: "All matrices must be double precision")
    
    ZAssert(A.numCols == B.numRows, message: "A and B cannot be multiplied (A.rows is not equal to B.cols")
    
    ZAssert(A.numRows == C.numRows && B.numCols == C.numCols, message: "C cannot be added to the product of A and B (incompatible dimensions)")
    #endif
    
    var result:PCH_Matrix
    // First we check whether the dimension of the matrices is less than or equal to the minimum. If it is, we call dense BLAS.
    if (C.numRows < PCH_Sparse_MinDimension || C.numCols < PCH_Sparse_MinDimension)
    {
        let m = __CLPK_integer(C.numRows)
        let n = __CLPK_integer(C.numCols)
        let k = __CLPK_integer(A.numCols)
        
        let lda = m
        let ldb = k
        let ldc = m
        
        let a = PCH_Matrix(subMatrix: A, convertToGE: true).doubleBuffer!
        let b = PCH_Matrix(subMatrix: B, convertToGE: true).doubleBuffer!
        var cc = PCH_Matrix(subMatrix: C, convertToGE: true).doubleBuffer!
        
        cblas_dgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, m, n, k, alpha, a, lda, b, ldb, beta, &cc, ldc)
        
        result = PCH_Matrix(numRows: C.numRows, numCols: C.numCols, buffer: cc, matrixType: PCH_Matrix.types.sparseMatrix)!
    }
    else
    {
        let nRA = A.numRows / 2
        let nCA = A.numCols / 2
        
        /*
            let A11 = A.Submatrix(fromRow: 0, toRow: nRA-1, fromCol: 0, toCol: nCA-1, convertToGE:false)
            let A21 = A.Submatrix(fromRow: nRA, toRow: A.numRows-1, fromCol: 0, toCol: nCA-1, convertToGE: false)
            let A12 = A.Submatrix(fromRow: 0, toRow: nRA-1, fromCol: nCA, toCol: A.numCols-1, convertToGE: false)
            let A22 = A.Submatrix(fromRow: nRA, toRow: A.numRows-1, fromCol: nCA, toCol: A.numCols-1, convertToGE: false)
        */
        let A11 = PCH_SubMatrix(submatrix: A, rowStart: 0, rowEnd: nRA-1, colStart: 0, colEnd: nCA-1)
        let A21 = PCH_SubMatrix(submatrix: A, rowStart: nRA, rowEnd: A.numRows-1, colStart: 0, colEnd: nCA-1)
        let A12 = PCH_SubMatrix(submatrix: A, rowStart: 0, rowEnd: nRA-1, colStart: nCA, colEnd: A.numCols-1)
        let A22 = PCH_SubMatrix(submatrix: A, rowStart: nRA, rowEnd: A.numRows-1, colStart: nCA, colEnd: A.numCols-1)
        
        let nRB = B.numRows / 2
        let nCB = B.numCols / 2
        
        /*
            let B11 = B.Submatrix(fromRow: 0, toRow: nRB-1, fromCol: 0, toCol: nCB-1, convertToGE:false)
            let B21 = B.Submatrix(fromRow: nRB, toRow: B.numRows-1, fromCol: 0, toCol: nCB-1, convertToGE: false)
            let B12 = B.Submatrix(fromRow: 0, toRow: nRB-1, fromCol: nCB, toCol: B.numCols-1, convertToGE: false)
            let B22 = B.Submatrix(fromRow: nRB, toRow: B.numRows-1, fromCol: nCB, toCol: B.numCols-1, convertToGE: false)
        */
        let B11 = PCH_SubMatrix(submatrix: B, rowStart: 0, rowEnd: nRB-1, colStart: 0, colEnd: nCB-1)
        let B21 = PCH_SubMatrix(submatrix: B, rowStart: nRB, rowEnd: B.numRows-1, colStart: 0, colEnd: nCB-1)
        let B12 = PCH_SubMatrix(submatrix: B, rowStart: 0, rowEnd: nRB-1, colStart: nCB, colEnd: B.numCols-1)
        let B22 = PCH_SubMatrix(submatrix: B, rowStart: nRB, rowEnd: B.numRows-1, colStart: nCB, colEnd: B.numCols-1)
        
        let nRC = C.numRows / 2
        let nCC = C.numCols / 2
        
        /*
            var C11 = C.Submatrix(fromRow: 0, toRow: nRC-1, fromCol: 0, toCol: nCC-1, convertToGE:false)
            var C21 = C.Submatrix(fromRow: nRC, toRow: C.numRows-1, fromCol: 0, toCol: nCC-1, convertToGE: false)
            var C12 = C.Submatrix(fromRow: 0, toRow: nRC-1, fromCol: nCC, toCol: C.numCols-1, convertToGE: false)
            var C22 = C.Submatrix(fromRow: nRC, toRow: C.numRows-1, fromCol: nCC, toCol: C.numCols-1, convertToGE: false)
        */
        var C11 = PCH_SubMatrix(submatrix: C, rowStart: 0, rowEnd: nRC-1, colStart: 0, colEnd: nCC-1)
        var C21 = PCH_SubMatrix(submatrix: C, rowStart: nRC, rowEnd: C.numRows-1, colStart: 0, colEnd: nCC-1)
        var C12 = PCH_SubMatrix(submatrix: C, rowStart: 0, rowEnd: nRC-1, colStart: nCC, colEnd: C.numCols-1)
        var C22 = PCH_SubMatrix(submatrix: C, rowStart: nRC, rowEnd: C.numRows-1, colStart: nCC, colEnd: C.numCols-1)
        
        // avoid "double timing"
        // xGEMM_time += NSProcessInfo().systemUptime - callStartTime
        
        C11 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: A11, B: B11, C: C11))
        C21 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: A21, B: B11, C: C21))
        C11 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: A12, B: B21, C: C11))
        C21 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: A22, B: B21, C: C21))
        C12 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: A11, B: B12, C: C12))
        C12 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: A12, B: B22, C: C12))
        C22 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: A21, B: B12, C: C22))
        C22 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: A22, B: B22, C: C22))
        
        // callStartTime = NSProcessInfo().systemUptime
        
        // reassemble the B matrix from the submatrices
        result = PCH_Matrix(numRows: C.numRows, numCols: C.numCols, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.sparseMatrix)
        
        var rowBase = 0
        var colBase = 0
        
        // C11
        for row in 0..<nRC
        {
            for col in 0..<nCC
            {
                result.sparseDoubleDict![sparseKeyType(row: rowBase+row, col: colBase+col)] = C11.matrix.sparseDoubleDict![sparseKeyType(row: row, col: col)]
                
                // let value:__CLPK_doublereal = C11[row,col]
                // result![rowBase + row, colBase + col] = value
            }
        }
        
        // C21
        rowBase = nRC
        for row in 0..<C21.numRows
        {
            for col in 0..<nCC
            {
                result.sparseDoubleDict![sparseKeyType(row: rowBase+row, col: colBase+col)] = C21.matrix.sparseDoubleDict![sparseKeyType(row: row, col: col)]

                // let value:__CLPK_doublereal = C21[row,col]
                // result![rowBase + row, colBase + col] = value
            }
        }
        
        // C12
        rowBase = 0
        colBase = nCC
        for row in 0..<nRC
        {
            for col in 0..<C12.numCols
            {
                result.sparseDoubleDict![sparseKeyType(row: rowBase+row, col: colBase+col)] = C12.matrix.sparseDoubleDict![sparseKeyType(row: row, col: col)]

                // let value:__CLPK_doublereal = C12[row,col]
                // result![rowBase + row, colBase + col] = value
            }
        }
        
        // C22
        rowBase = nRC
        for row in 0..<C22.numRows
        {
            for col in 0..<C22.numCols
            {
                result.sparseDoubleDict![sparseKeyType(row: rowBase+row, col: colBase+col)] = C22.matrix.sparseDoubleDict![sparseKeyType(row: row, col: col)]

                // let value:__CLPK_doublereal = C22[row,col]
                // result![rowBase + row, colBase + col] = value
            }
        }
    }
    
    return result
}

/** The xTRSM function for sparse matrices where the A argument is a lower triangular matrix (parameter L). This is for double-precision matrices
 
 */
func PCH_Sparse_dtrsm(L:PCH_SubMatrix, B:PCH_SubMatrix) -> PCH_Matrix
{
    // See the more complete notes in the upper-triangular version of this function for more detailed explanantions of what's going on here.
    
    // after testing, consider putting these ZAsserts into an "#if DEBUG" block
    
    #if DEBUG
    // ZAssert(L.matrixType == PCH_Matrix.types.upperTriangularMatrix, message: "The U matrix must be upper triangular")
    
    // The L matrix has to be square, so let's make sure of that.
    ZAssert(L.numRows == L.numCols, message: "The L matrix must be square")
    
    // And finally, the two matrices have to have the same dimension
    ZAssert(L.numCols == B.numRows, message: "L and B must have compatible dimensions")
    
    ZAssert(L.matrix.matrixPrecision == PCH_Matrix.precisions.doublePrecision && B.matrix.matrixPrecision == PCH_Matrix.precisions.doublePrecision, message: "Both matrices must be double precision")
    #endif
    
    // var callStartTime = NSProcessInfo().systemUptime
    
    var result:PCH_Matrix?
    
    // First we check whether the dimension of the matrices is less than or equal to the minimum. If it is, we call dense BLAS.
    if (L.numRows < PCH_Sparse_MinDimension) || (B.numRows < PCH_Sparse_MinDimension)
    {
        // var side:Int8 = Int8("L".utf8.first!)
        // var uplo:Int8 = Int8("L".utf8.first!)
        // var transa:Int8 = Int8("N".utf8.first!)
        // var diag = Int8("U".utf8.first!)
        
        let m = __CLPK_integer(B.numRows)
        let n = __CLPK_integer(B.numCols)
        let alpha = __CLPK_doublereal(1.0)
        
        let a = PCH_Matrix(subMatrix: L, convertToGE: true).doubleBuffer!
        var b = PCH_Matrix(subMatrix: B, convertToGE: true).doubleBuffer!
        
        let lda = m
        let ldb = m
        
        cblas_dtrsm(CblasColMajor, CblasLeft, CblasLower, CblasNoTrans, CblasUnit, m, n, alpha, a, lda, &b, ldb)
        
        result = PCH_Matrix(numRows: B.numRows, numCols: B.numCols, buffer: b, matrixType: PCH_Matrix.types.sparseMatrix)
    }
    else
    {
        // If we get here, we're ready to start executing the algorithm
        
        // Calculate the boundaries for the submatrices, taking into account that the dimension may be an odd number
        let n1 = B.numRows / 2
        
        // var B11 = B.Submatrix(fromRow:0, toRow: n1-1, fromCol: 0, toCol: n1-1, convertToGE:false)
        var B11 = PCH_SubMatrix(submatrix: B, rowStart: 0, rowEnd: n1-1, colStart: 0, colEnd: n1-1)
        
        // var B21 = B.Submatrix(fromRow:n1, toRow: B.numRows-1, fromCol: 0, toCol: n1-1, convertToGE:false)
        var B21 = PCH_SubMatrix(submatrix: B, rowStart: n1, rowEnd: B.numRows-1, colStart: 0, colEnd: n1-1)
        
        // var B12 = B.Submatrix(fromRow:0, toRow: n1-1, fromCol: n1, toCol: B.numCols-1, convertToGE:false)
        var B12 = PCH_SubMatrix(submatrix: B, rowStart: 0, rowEnd: n1-1, colStart: n1, colEnd: B.numCols-1)
        
        // var B22 = B.Submatrix(fromRow:n1, toRow: B.numRows-1, fromCol: n1, toCol: B.numCols-1, convertToGE:false)
        var B22 = PCH_SubMatrix(submatrix: B, rowStart: n1, rowEnd: B.numRows-1, colStart: n1, colEnd: B.numCols-1)
        
        // let L11 = L.Submatrix(fromRow:0, toRow: n1-1, fromCol: 0, toCol: n1-1, convertToGE:false)
        let L11 = PCH_SubMatrix(submatrix: L, rowStart: 0, rowEnd: n1-1, colStart: 0, colEnd: n1-1)
        
        // let L21 = L.Submatrix(fromRow:n1, toRow: L.numRows-1, fromCol: 0, toCol: n1-1)
        let L21 = PCH_SubMatrix(submatrix: L, rowStart: n1, rowEnd: L.numRows-1, colStart: 0, colEnd: n1-1)
        
        // let L22 = L.Submatrix(fromRow:n1, toRow: L.numRows-1, fromCol: n1, toCol: L.numCols-1, convertToGE:false)
        let L22 = PCH_SubMatrix(submatrix: L, rowStart: n1, rowEnd: L.numRows-1, colStart: n1, colEnd: L.numCols-1)
        
        B11 = PCH_SubMatrix(matrix: PCH_Sparse_dtrsm(L: L11, B: B11))
        
        B21 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: L21, B: B11, C: B21))
        
        B21 = PCH_SubMatrix(matrix: PCH_Sparse_dtrsm(L: L22, B: B21))
        
        B12 = PCH_SubMatrix(matrix: PCH_Sparse_dtrsm(L: L11, B: B12))
        
        // The paper shows L12 in the next call, which does not exist. I assume it was an error and should read L21 (this is confirmed by testing)
        B22 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: L21, B: B12, C: B22))
        
        B22 = PCH_SubMatrix(matrix: PCH_Sparse_dtrsm(L: L22, B: B22))
        
        // reassemble the B matrix from the submatrices
        result = PCH_Matrix(numRows: B.numRows, numCols: B.numCols, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.sparseMatrix)
        
        var rowBase = 0
        var colBase = 0
        
        // B11
        for row in 0..<n1
        {
            for col in 0..<n1
            {
                let value:__CLPK_doublereal = B11[row,col]
                result![rowBase + row, colBase + col] = value
            }
        }
        
        // B21
        rowBase = n1
        for row in 0..<B21.numRows
        {
            for col in 0..<n1
            {
                let value:__CLPK_doublereal = B21[row,col]
                result![rowBase + row, colBase + col] = value
            }
        }
        
        // B12
        rowBase = 0
        colBase = n1
        for row in 0..<n1
        {
            for col in 0..<B12.numCols
            {
                let value:__CLPK_doublereal = B12[row,col]
                result![rowBase + row, colBase + col] = value
            }
        }
        
        // B22
        rowBase = n1
        for row in 0..<B22.numRows
        {
            for col in 0..<B22.numCols
            {
                let value:__CLPK_doublereal = B22[row,col]
                result![rowBase + row, colBase + col] = value
            }
        }
    }
    
    return result!
}
 
/** The xTRSM function for sparse matrices where the A argument is an upper triangular matrix (parameter U). This is for double-precision matrices
 
*/
func PCH_Sparse_dtrsm(U:PCH_SubMatrix, B:PCH_SubMatrix) -> PCH_Matrix
{
    // after testing, consider putting these ZAsserts into an "#if DEBUG" block
    
    #if DEBUG
    // ZAssert(U.matrixType == PCH_Matrix.types.upperTriangularMatrix, message: "The U matrix must be upper triangular")
    
    // The U matrix passed to the routine must be square, so let's make sure of that.
    ZAssert(U.numRows == U.numCols, message: "The U matrix must be square")
    
    // And finally, the two matrices have to have compatible dimensions
    ZAssert(U.numRows == B.numCols, message: "U and B must have compatible dimensions")
    
    ZAssert(U.matrix.matrixPrecision == PCH_Matrix.precisions.doublePrecision && B.matrix.matrixPrecision == PCH_Matrix.precisions.doublePrecision, message: "Both matrices must be double precision")
    
    #endif
    // var callStartTime = NSProcessInfo().systemUptime
    var result:PCH_Matrix?
    
    // First we check whether the dimension of the matrices is less than or equal to the minimum. If it is, we call dense BLAS.
    if (U.numRows < PCH_Sparse_MinDimension) || (B.numRows < PCH_Sparse_MinDimension)
    {
        // var side:Int8 = Int8("R".utf8.first!)
        // var uplo:Int8 = Int8("U".utf8.first!)
        // var transa:Int8 = Int8("N".utf8.first!)
        // var diag = transa
        
        let m = __CLPK_integer(B.numRows)
        let n = __CLPK_integer(B.numCols)
        let alpha = __CLPK_doublereal(1.0)
        
        // let tstA = PCH_Matrix(sourceMatrix: U, newMatrixType: PCH_Matrix.types.generalMatrix)
        
        let a = PCH_Matrix(subMatrix: U, convertToGE: true).doubleBuffer!
        var b = PCH_Matrix(subMatrix: B, convertToGE: true).doubleBuffer!
        
        let lda = n
        let ldb = m
        
        cblas_dtrsm(CblasColMajor, CblasRight, CblasUpper, CblasNoTrans, CblasNonUnit, m, n, alpha, a, lda, &b, ldb)
        
        result = PCH_Matrix(numRows: B.numRows, numCols: B.numCols, buffer: b, matrixType: PCH_Matrix.types.sparseMatrix)
    }
    else
    {
        // If we get here, we're ready to start executing the algorithm. 
        /*
            And speaking of the algorithm, there are a few points to be made here that are not specifially mentioned in the actual paper. First of all, the U matrix that is passed in has to be SQUARE.         */
        
        // Calculate the boundaries for the submatrices, taking into account that the dimension may be an odd number
        let n1 = B.numRows / 2
        // let n2b = B.numRows - n1b
        
        //var B11 = B.Submatrix(fromRow:0, toRow: n1-1, fromCol: 0, toCol: n1-1, convertToGE:false)
        var B11 = PCH_SubMatrix(submatrix: B, rowStart: 0, rowEnd: n1-1, colStart: 0, colEnd: n1-1)
        
        //var B21 = B.Submatrix(fromRow:n1, toRow: B.numRows-1, fromCol: 0, toCol: n1-1, convertToGE:false)
        var B21 = PCH_SubMatrix(submatrix: B, rowStart: n1, rowEnd: B.numRows-1, colStart: 0, colEnd: n1-1)
        
        //var B12 = B.Submatrix(fromRow:0, toRow: n1-1, fromCol: n1, toCol: B.numCols-1, convertToGE:false)
        var B12 = PCH_SubMatrix(submatrix: B, rowStart: 0, rowEnd: n1-1, colStart: n1, colEnd: B.numCols-1)
        
        //var B22 = B.Submatrix(fromRow:n1, toRow: B.numRows-1, fromCol: n1, toCol: B.numCols-1, convertToGE:false)
        var B22 = PCH_SubMatrix(submatrix: B, rowStart: n1, rowEnd: B.numRows-1, colStart: n1, colEnd: B.numCols-1)
        
        // let n1u = U.numRows / 2
        // let n2u = U.numRows - n1u
        
        // let U11 = U.Submatrix(fromRow:0, toRow: n1-1, fromCol: 0, toCol: n1-1, convertToGE:false)
        let U11 = PCH_SubMatrix(submatrix: U, rowStart: 0, rowEnd: n1-1, colStart: 0, colEnd: n1-1)
        
        // let U12 = U.Submatrix(fromRow:0, toRow: n1-1, fromCol: n1, toCol: U.numCols-1)
        let U12 = PCH_SubMatrix(submatrix: U, rowStart: 0, rowEnd: n1-1, colStart: n1, colEnd: U.numCols-1)
        
        // let U22 = U.Submatrix(fromRow:n1, toRow: U.numRows-1, fromCol: n1, toCol: U.numCols-1, convertToGE:false)
        let U22 = PCH_SubMatrix(submatrix: U, rowStart: n1, rowEnd: U.numRows-1, colStart: n1, colEnd: U.numCols-1)
        
        B11 = PCH_SubMatrix(matrix: PCH_Sparse_dtrsm(U: U11, B: B11))
        B21 = PCH_SubMatrix(matrix: PCH_Sparse_dtrsm(U: U11, B: B21))
        // callStartTime = NSProcessInfo().systemUptime
        
        B22 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: B21, B: U12, C: B22))
        
        // avoid timimg recursive call twice
        // xTRSM_U_time += NSProcessInfo().systemUptime - callStartTime
        B22 = PCH_SubMatrix(matrix: PCH_Sparse_dtrsm(U: U22, B: B22))
        // callStartTime = NSProcessInfo().systemUptime
        
        B12 = PCH_SubMatrix(matrix: PCH_Sparse_dgemm(alpha: -1.0, beta: 1.0, A: B11, B: U12, C: B12))
        
        // avoid timimg recursive call twice
        // xTRSM_U_time += NSProcessInfo().systemUptime - callStartTime
        B12 = PCH_SubMatrix(matrix: PCH_Sparse_dtrsm(U: U22, B: B12))
        // callStartTime = NSProcessInfo().systemUptime
        
        // reassemble the B matrix from the submatrices
        result = PCH_Matrix(numRows: B.numRows, numCols: B.numCols, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.sparseMatrix)
        
        var rowBase = 0
        var colBase = 0
        
        // B11
        for row in 0..<n1
        {
            for col in 0..<n1
            {
                let value:__CLPK_doublereal = B11[row,col]
                result![rowBase + row, colBase + col] = value
            }
        }
        
        // B21
        rowBase = n1
        for row in 0..<B21.numRows
        {
            for col in 0..<n1
            {
                let value:__CLPK_doublereal = B21[row,col]
                result![rowBase + row, colBase + col] = value
            }
        }
        
        // B12
        rowBase = 0
        colBase = n1
        for row in 0..<n1
        {
            for col in 0..<B12.numCols
            {
                let value:__CLPK_doublereal = B12[row,col]
                result![rowBase + row, colBase + col] = value
            }
        }
        
        // B22
        rowBase = n1
        for row in 0..<B22.numRows
        {
            for col in 0..<B22.numCols
            {
                let value:__CLPK_doublereal = B22[row,col]
                result![rowBase + row, colBase + col] = value
            }
        }
    }
    
    // xTRSM_U_time += NSProcessInfo().systemUptime - callStartTime
    
    return result!
}

/**
    Matrix class. 
    
    Allowed numerical types are Double and Complex.
    
    Note that Complex actually implies "double complex".
    
    Access (both setting and getting) is via a comma-separated square bracket subscript (like arrays). So, to get at the element at row 5, column 9: element = matrix[5,9].
*/

class PCH_Matrix:CustomStringConvertible
{
    /// The number of rows in the matrix
    let numRows:Int
    
    /// The number of columns in the matrix
    let numCols:Int
    
    /// The precision types available
    enum precisions {
        case doublePrecision
        case complexPrecision
    }
    
    /// The precision of the matrix
    let matrixPrecision:precisions
    
    var isVector:Bool
    {
        return (self.numCols == 1 || self.numRows == 1)
    }
    
    /// The types of matrices that can be created. Note that not all types will actually be available in the original implementation of the class.
    enum types {
        case generalMatrix
        case bandedMatrix
        case upperTriangularMatrix
        case lowerTriangularMatrix
        case positiveDefinite
        case symmetricMatrix
        case diagonalMatrix
        case sparseMatrix
    }
    
    /// The type of the matrix
    let matrixType:types
    
    /// The buffer for doublePrecision matrices
    var doubleBuffer:[__CLPK_doublereal]? = nil
    
    /// The buffer for doubleComplex matrices
    var complexBuffer:[__CLPK_doublecomplex]? = nil
    
    /// The dictionaries for sparse matrices. These represent the original sparse matrix, which may or may not be triangular. Sparse matrix solving is actually done on a triangular matrix that is "similar" to the original.
    var sparseDoubleDict:[sparseKeyType:Double]? = nil
    var sparseComplexDict:[sparseKeyType:Complex]? = nil
    
    /// The number of sub- and super-diagonals for banded matrices
    private let subDiagonals:Int
    private let superDiagonals:Int
    
    /// As simple description function to display matrices with 'print' (the output is quite ugly and not nicely formatted)
    var description:String
    {
        var result = ""
        
        for i in 0..<self.numRows
        {
            result += "\n| "
            
            for j in 0..<self.numCols
            {
                if (j == self.numCols - 1)
                {
                    if (self.matrixPrecision == precisions.doublePrecision)
                    {
                        let value:Double = self[i,j]
                        result += "\(value) |"
                    }
                    else
                    {
                        let value:Complex = self[i,j]
                        result += "\(value) |"
                    }
                }
                else
                {
                    if (self.matrixPrecision == precisions.doublePrecision)
                    {
                        let value:Double = self[i,j]
                        result += "\(value)   "
                    }
                    else
                    {
                        let value:Complex = self[i,j]
                        result += "\(value)   "
                    }
                }
            }
        }
        
        return result
    }
    
    /// Define a two-index subscript accessor for our matrix. This one is for double precision
    subscript(row: Int, column: Int) -> Double {
        get
        {
            ZAssert(row >= 0 && row < self.numRows && column >= 0 && column < self.numCols, message: "Index out of range!")
            
            // ZAssert(self.matrixPrecision == precisions.doublePrecision, message: "Trying to access double value from a complex matrix!")
            
            if (self.matrixType == types.sparseMatrix)
            {
                let theKey = sparseKeyType(row: row, col: column)
                
                if let result = self.sparseDoubleDict![theKey]
                {
                    return result
                }
                else
                {
                    // By definition, indices that don't exist in a sparse matrix are equal to zero
                    return 0.0
                }
            }
            else if (self.matrixType == types.bandedMatrix) || (self.matrixType == types.lowerTriangularMatrix) || (self.matrixType == types.upperTriangularMatrix)
            {
                let kl = self.subDiagonals
                let ku = self.superDiagonals
                
                // ZAssert(((row <= column + kl) && (column <= row + ku)), message: "Index out of bounds for banded matrix!")
                
                // Everything outside the band is a zero
                if (row > column + kl) || (column > row + ku)
                {
                    return 0.0
                }
                
                // The index into the array comes from my old PCH_BLAS_Matrix class. I haven't quite figured out how I managed to come up with it - I must have been very, very smart once.
                
                // Actually, now, in a sort of "handwaving" way, I think I get it. This has to do with the note on the netlib site that says "When a band matrix is supplied for LU factorization, space must be allowed to store an additional kl superdiagonals, generated by fill-in as a result of row interchanges. This means that the matrix is stored according to the above scheme, but with kl + ku superdiagonals". This directly implies that the actual number of rows in the matrix is kl + (kl + ku) + 1 = (2 * kl + ku + 1) and that the row index (offset) is actually ((kl + ku) + 1 + i - j). Of course, in the non-Fortran world, arrays are 0-based, which means we don't need the 1, and so the index here is actually (kl + ku + row - column).
                
                return self.doubleBuffer![column * (2 * kl + ku + 1) + kl + ku + row - column]
            }
            else if (self.matrixType == types.symmetricMatrix) || (self.matrixType == types.positiveDefinite)
            {
                // The class uses "UPLO = U" symantics for symmetric matrices, so:
                var useRow = row
                var useCol = column
                
                if (column < row)
                {
                    swap(&useRow, &useCol)
                }
                
                return self.doubleBuffer![useRow + useCol * (useCol + 1) / 2]
            }
            else if (self.matrixType == types.diagonalMatrix)
            {
                if (row != column)
                {
                    return 0.0
                }
                
                return self.doubleBuffer![row]
            }
            else if (self.matrixType == types.generalMatrix)
            {
                return self.doubleBuffer![column * self.numRows + row]
            }
            else
            {
                ALog("Accessors are not yet defined for this type of matrix!")
                return 0.0
            }
        }
        set
        {
            ZAssert(row >= 0 && row < self.numRows && column >= 0 && column < self.numCols, message: "Index out of range!")
            
            // ZAssert(self.matrixPrecision == precisions.doublePrecision, message: "Trying to access double value from a complex matrix!")
            
            if (self.matrixType == types.sparseMatrix)
            {
                let theKey = sparseKeyType(row: row, col: column)
                
                if (newValue == 0.0)
                {
                    self.sparseDoubleDict!.removeValue(forKey: theKey)
                }
                else
                {
                    self.sparseDoubleDict![theKey] = newValue
                }
            }
            else if (self.matrixType == types.bandedMatrix) || (self.matrixType == types.lowerTriangularMatrix) || (self.matrixType == types.upperTriangularMatrix)
            {
                let kl = self.subDiagonals
                let ku = self.superDiagonals
                
                ZAssert(((row <= column + kl) && (column <= row + ku)), message: "Index out of bounds for banded matrix!")
                
                self.doubleBuffer![column * (2 * kl + ku + 1) + kl + ku + row - column] = newValue
            }
            else if (self.matrixType == types.symmetricMatrix) || (self.matrixType == types.positiveDefinite)
            {
                // The class uses "UPLO = U" symantics for symmetric matrices, so:
                var useRow = row
                var useCol = column
                
                if (column < row)
                {
                    swap(&useRow, &useCol)
                }
                
                self.doubleBuffer![useRow + useCol * (useCol + 1) / 2] = newValue
            }
            else if (self.matrixType == types.diagonalMatrix)
            {
                ZAssert(row == column, message: "Cannot set off-diagonal element of a diagonal matrix!")
                
                self.doubleBuffer![row] = newValue
            }
            else if (self.matrixType == types.generalMatrix)
            {
                self.doubleBuffer![column * self.numRows + row] = newValue
            }
            else
            {
                ALog("Accessors are not yet defined for this type of matrix!")
            }
        }
    }
    
    subscript(row: Int, column: Int) -> Complex {
        get
        {
            ZAssert(row >= 0 && row < self.numRows && column >= 0 && column < self.numCols, message: "Index out of range!")
            
            ZAssert(self.matrixPrecision == precisions.complexPrecision, message: "Trying to access complex value from a double matrix!")
            
            if (self.matrixType == types.sparseMatrix)
            {
                let theKey = sparseKeyType(row: row, col: column)
                
                if let result = self.sparseComplexDict![theKey]
                {
                    return result
                }
                else
                {
                    // By definition, indices that don't exist in a sparse matrix are equal to zero
                    return Complex(real: 0.0, imag: 0.0)
                }
            }
            else if (self.matrixType == types.bandedMatrix) || (self.matrixType == types.lowerTriangularMatrix) || (self.matrixType == types.upperTriangularMatrix)
            {
                let kl = self.subDiagonals
                let ku = self.superDiagonals
                
                // ZAssert(((row <= column + kl) && (column <= row + ku)), message: "Index out of bounds for banded matrix!")
                
                // Everything outside the band is a zero
                if (row > column + kl) || (column > row + ku)
                {
                    return Complex(real: 0.0, imag: 0.0)
                }
                
                let value = complexBuffer![column * (2 * kl + ku + 1) + kl + ku + row - column]
                
                return Complex(real:value.r, imag: value.i)
            }
            else if (self.matrixType == types.symmetricMatrix) || (self.matrixType == types.positiveDefinite)
            {
                // The class uses "UPLO = U" symantics for symmetric matrices, so:
                var useRow = row
                var useCol = column
                
                if (column < row)
                {
                    swap(&useRow, &useCol)
                }
                
                let value = self.complexBuffer![useRow + useCol * (useCol + 1) / 2]
                
                return Complex(real:value.r, imag: value.i)
            }
            else if (self.matrixType == types.diagonalMatrix)
            {
                if (row != column)
                {
                    return Complex(real: 0.0, imag: 0.0)
                }
                
                let value = self.complexBuffer![row]
                
                return Complex(real:value.r, imag: value.i)
            }
            else if (self.matrixType == types.generalMatrix)
            {
                let value = complexBuffer![column * self.numRows + row]
                
                return Complex(real:value.r, imag: value.i)
            }
            else
            {
                ALog("Accessors are not yet defined for this type of matrix!")
                return Complex(real: 0.0, imag: 0.0)
            }
        }
        set
        {
            ZAssert(row >= 0 && row < self.numRows && column >= 0 && column < self.numCols, message: "Index out of range!")
            
            ZAssert(self.matrixPrecision == precisions.complexPrecision, message: "Trying to access complex value from a double matrix!")
            
            if (self.matrixType == types.sparseMatrix)
            {
                let theKey = sparseKeyType(row: row, col: column)
                
                if (newValue.real == 0.0 && newValue.imag == 0.0)
                {
                    self.sparseComplexDict!.removeValue(forKey: theKey)
                }
                else
                {
                    self.sparseComplexDict![theKey] = newValue
                }
            }
            else if (self.matrixType == types.bandedMatrix) || (self.matrixType == types.lowerTriangularMatrix) || (self.matrixType == types.upperTriangularMatrix)
            {
                let kl = self.subDiagonals
                let ku = self.superDiagonals
                
                ZAssert(((row <= column + kl) && (column <= row + ku)), message: "Index out of bounds for banded matrix!")
                
                let newValueDC = __CLPK_doublecomplex(r: newValue.real, i: newValue.imag)
                
                // let index:Int = column * (2 * kl + ku + 1) + kl + ku + row - column
                
                self.complexBuffer![column * (2 * kl + ku + 1) + kl + ku + row - column] = newValueDC
            }
            else if (self.matrixType == types.symmetricMatrix) || (self.matrixType == types.positiveDefinite)
            {
                // The class uses "UPLO = U" symantics for symmetric matrices, so:
                var useRow = row
                var useCol = column
                
                if (column < row)
                {
                    swap(&useRow, &useCol)
                }
                
                let newValueDC = __CLPK_doublecomplex(r: newValue.real, i: newValue.imag)
                
                self.complexBuffer![useRow + useCol * (useCol + 1) / 2] = newValueDC
            }
            else if (self.matrixType == types.diagonalMatrix)
            {
                ZAssert(row == column, message: "Cannot set off-diagonal element of a diagonal matrix!")
                
                let newValueDC = __CLPK_doublecomplex(r: newValue.real, i: newValue.imag)
                
                self.complexBuffer![row] = newValueDC
            }
            else if (self.matrixType == types.generalMatrix)
            {
                let newValueDC = __CLPK_doublecomplex(r: newValue.real, i: newValue.imag)
                
                self.complexBuffer![column * self.numRows + row] = newValueDC
            }
            else
            {
                ALog("Accessors are not yet defined for this type of matrix!")
            }
        }
    }
    
    /**
        Designated initializer
        - parameter numRows: The number of rows in the matrix
        - parameter numCols: The numner of columns in the matrix
        - parameter matrixPrecision: The precision of the matrix entries
        - parameter matrixType: The type of matrix
        - parameter subDiagonals: For banded matrices, the number of diagonals below the main diagonal that hold non-zero values
        - parameter superDiagonals: For banded matrices, the number of diagonals above the main diagonal that hold non-zero values
    */
    init(numRows:Int, numCols:Int, matrixPrecision:precisions, matrixType:types, subDiagonals:Int = 0, superDiagonals:Int = 0)
    {
        ZAssert((numRows > 0) && (numCols > 0), message: "There must be a positive, non-zero number of rows and columns!")
        
        if (matrixType == types.bandedMatrix)
        {
            ZAssert(subDiagonals > 0 && superDiagonals > 0, message: "There must be a positive, non-zero number of sub- and super-diagonals for banded matrices!")
            
            self.subDiagonals = subDiagonals
            self.superDiagonals = superDiagonals
        }
        else if (matrixType == types.lowerTriangularMatrix)
        {
            self.subDiagonals = numRows - 1
            self.superDiagonals = 0
        }
        else if (matrixType == types.upperTriangularMatrix)
        {
            self.subDiagonals = 0
            self.superDiagonals = numRows - 1
        }
        else
        {
            self.subDiagonals = 0
            self.superDiagonals = 0
        }
        
        self.numRows = numRows
        self.numCols = numCols
        self.matrixPrecision = matrixPrecision
        
        
        
        if (matrixType == types.sparseMatrix)
        {
            if (matrixPrecision == precisions.doublePrecision)
            {
                self.sparseDoubleDict = Dictionary()
            }
            else
            {
                self.sparseComplexDict = Dictionary()
            }
            
            self.matrixType = matrixType
        }
        else
        {
            var useType = matrixType
            
            // initialize the number of saved elements for a general matrix
            var numElements = numRows * numCols
            
            if (matrixType == types.bandedMatrix)
            {
                // This is calculated per http://www.netlib.org/lapack/lug/node124.html. Note that since many of the routines we call do an LU factorization, we need to add an extra kl elements (kl is subDiagonals).
                
                numElements = numCols * (2 * subDiagonals + superDiagonals + 1)
            }
            else if (matrixType == types.lowerTriangularMatrix)
            {
                // This is calculated per http://www.netlib.org/lapack/lug/node124.html. 
                numElements = numCols * (2 * self.subDiagonals + 1)
            }
            else if (matrixType == types.upperTriangularMatrix)
            {
                // This is calculated per http://www.netlib.org/lapack/lug/node124.html.
                numElements = numCols * (2 * self.superDiagonals + 1)
            }
            else if (matrixType == types.symmetricMatrix) || (matrixType == types.positiveDefinite)
            {
                ZAssert(numCols == numRows, message: "Symmetric (and positive definite) matrices must be square!")
                
                // This is a bit odd. Interestingly, there is no advantage to using the symmetric type in terms of the memory used (it's still numRows * numCols) by LAPACK. I assume that there is an advantage in the computational methods. However, within the class, we will use the PACKED storage method (described at http://www.netlib.org/lapack/lug/node123.html ) and then unpack it as required for the computational methods. Note that the class uses "UPLO = U" symantics for symmetric matrices storage and access.
                
                numElements = numRows + numCols * (numCols - 1) / 2
            }
            else if (matrixType == types.diagonalMatrix)
            {
                ZAssert(numCols == numRows, message: "Diagonal matrices must be square!")
                
                // Diagonal matrices aren't actually defined in BLAS, so we'll roll our own. In the end, this works fine because banded matrices with ku and kl equal to zero (ie: a diagonal matrix) are stored exactly this way.
                
                numElements = numRows
            }
            else
            {
                // DLog("Initializing general matrix")
                useType = types.generalMatrix
            }
            
            self.matrixType = useType
            
            if (matrixPrecision == precisions.doublePrecision)
            {
                self.doubleBuffer = [__CLPK_doublereal](repeating: 0.0, count: numElements)
            }
            else
            {
                self.complexBuffer = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: numElements)
            }
        }
    }
    
    /**
        Convenience initializer for creating vectors. Note that for now, it is assumed that vector types are "general" matrices. This may change if I find that it would be handy to represent vectors as other types.
     
        - parameter numVectorElements: The number of elements in the vector
        - parameter vectorPrecision: The precision of the elements in the vector
    */
    convenience init(numVectorElements:Int, vectorPrecision:precisions)
    {
        self.init(numRows:numVectorElements, numCols:1, matrixPrecision:vectorPrecision, matrixType:types.generalMatrix)
    }
    
    
    /**
        Special initializer to create a sparse double-precision matrix using an existing dictionary. It is assumed that the dictionary is already in the correct format (no checking is done).
     
        - parameter numRows: The number of rows in the matrix
        - parameter numCols: The numner of columns in the matrix
        - parameter doubleDictionary: The dictionary to use to create the new matrix
    
    */
    
    init(numRows:Int, numCols:Int, doubleDictionary:[sparseKeyType:Double])
    {
        ZAssert((numRows > 0) && (numCols > 0), message: "There must be a positive, non-zero number of rows and columns!")
        
        self.numRows = numRows
        self.numCols = numCols
        self.matrixPrecision = precisions.doublePrecision
        self.matrixType = types.sparseMatrix
        self.subDiagonals = 0
        self.superDiagonals = 0
        
        self.sparseDoubleDict = doubleDictionary
    }
    
    /**
     Special initializer to create a sparse complex-precision matrix using an existing dictionary. It is assumed that the dictionary is already in the correct format (no checking is done).
     
     - parameter numRows: The number of rows in the matrix
     - parameter numCols: The numner of columns in the matrix
     - parameter doubleDictionary: The dictionary to use to create the new matrix
     
     */
    
    init(numRows:Int, numCols:Int, complexDictionary:[sparseKeyType:Complex])
    {
        ZAssert((numRows > 0) && (numCols > 0), message: "There must be a positive, non-zero number of rows and columns!")
        
        self.numRows = numRows
        self.numCols = numCols
        self.matrixPrecision = precisions.doublePrecision
        self.matrixType = types.sparseMatrix
        self.subDiagonals = 0
        self.superDiagonals = 0
        
        self.sparseComplexDict = complexDictionary
    }
    
    
    /**
        Special initializer to create a non-sparse double-precision matrix using a buffer. If the matrix that will be created is sparse, the buffer must be in "general matrix" format.
     - note: The buffer passed to this routine **must** be in *column-major* form.
     - note: The buffer that is passed must be in the format expected by the matrixType (no checking is performed by this routine)
     
         - parameter numRows: The number of rows in the matrix
         - parameter numCols: The numner of columns in the matrix
         - parameter buffer: The buffer to use to create the new matrix
         - parameter matrixType: The type of matrix
         - parameter subDiagonals: For banded matrices, the number of diagonals below the main diagonal that hold non-zero values
         - parameter superDiagonals: For banded matrices, the number of diagonals above the main diagonal that hold non-zero values
     
        - returns: A new PCH_Matrix object, or nil if the object could not be created
    */
    
    init?(numRows:Int, numCols:Int, buffer:[__CLPK_doublereal], matrixType:types, subDiagonals:Int = 0, superDiagonals:Int = 0)
    {
        ZAssert((numRows > 0) && (numCols > 0), message: "There must be a positive, non-zero number of rows and columns!")
        
        if (matrixType == types.bandedMatrix)
        {
            ZAssert(subDiagonals > 0 && superDiagonals > 0, message: "There must be a positive, non-zero number of sub- and super-diagonals for banded matrices!")
            
            self.subDiagonals = subDiagonals
            self.superDiagonals = superDiagonals
        }
        else
        {
            self.subDiagonals = 0
            self.superDiagonals = 0
        }
        
        self.numRows = numRows
        self.numCols = numCols
        self.matrixPrecision = precisions.doublePrecision
        self.matrixType = matrixType
        
        if (matrixType == types.sparseMatrix)
        {
            // ALog("Cannot create a sparse matrix using this initializer")
            self.sparseDoubleDict = Dictionary()
            
            for row in 0..<numRows
            {
                for col in 0..<numCols
                {
                    let value = buffer[col * numRows + row]
                    
                    // TODO: Consider making this a "less-than some small number" instead of "equal to zero"
                    if (value != 0.0)
                    {
                        let key = sparseKeyType(row: row, col: col)
                        self.sparseDoubleDict![key] = value
                    }
                }
            }
        }
        else
        {
            self.doubleBuffer = buffer
        }
    }
    
    /**
     Special initializer to create a non-sparse complex-precision matrix using a [Complex] buffer. Note that this initializer will fail if the matrix type is sparse.
     
     - note: The buffer passed to this routine **must** be in *column-major* form.
     - note: The buffer that is passed must be in the format expected by the matrixType (no checking is performed by this routine)
     
     - parameter numRows: The number of rows in the matrix
     - parameter numCols: The numner of columns in the matrix
     - parameter buffer: The buffer to use to create the new matrix
     - parameter matrixType: The type of matrix
     - parameter subDiagonals: For banded matrices, the number of diagonals below the main diagonal that hold non-zero values
     - parameter superDiagonals: For banded matrices, the number of diagonals above the main diagonal that hold non-zero values
     
     - returns: A new PCH_Matrix object, or nil if the object could not be created
     
     */
    convenience init?(numRows:Int, numCols:Int, buffer:[Complex], matrixType:types, subDiagonals:Int = 0, superDiagonals:Int = 0)
    {
        var clpkArray = [__CLPK_doublecomplex]()
        
        for nextNum in buffer
        {
            clpkArray.append(__CLPK_doublecomplex(r: nextNum.real, i: nextNum.imag))
        }
        
        self.init(numRows: numRows, numCols: numCols, buffer: clpkArray, matrixType: matrixType, subDiagonals: subDiagonals, superDiagonals: superDiagonals)
    }
    
    /**
     Special initializer to create a non-sparse complex-precision matrix using a [__CLPK_doublecomplex] buffer. Note that this initializer will fail if the matrix type is sparse.
     
     - note: The buffer passed to this routine **must** be in *column-major* form.
     
     - parameter numRows: The number of rows in the matrix
     - parameter numCols: The numner of columns in the matrix
     - parameter buffer: The buffer to use to create the new matrix
     - parameter matrixType: The type of matrix
     - parameter subDiagonals: For banded matrices, the number of diagonals below the main diagonal that hold non-zero values
     - parameter superDiagonals: For banded matrices, the number of diagonals above the main diagonal that hold non-zero values
     
     - returns: A new PCH_Matrix object, or nil if the object could not be created
     
     */
    
    init?(numRows:Int, numCols:Int, buffer:[__CLPK_doublecomplex], matrixType:types, subDiagonals:Int = 0, superDiagonals:Int = 0)
    {
        ZAssert((numRows > 0) && (numCols > 0), message: "There must be a positive, non-zero number of rows and columns!")
        
        if (matrixType == types.bandedMatrix)
        {
            ZAssert(subDiagonals > 0 && superDiagonals > 0, message: "There must be a positive, non-zero number of sub- and super-diagonals for banded matrices!")
            
            self.subDiagonals = subDiagonals
            self.superDiagonals = superDiagonals
        }
        else
        {
            self.subDiagonals = 0
            self.superDiagonals = 0
        }
        
        self.numRows = numRows
        self.numCols = numCols
        self.matrixPrecision = precisions.complexPrecision
        self.matrixType = matrixType
        
        if (matrixType == types.sparseMatrix)
        {
            ALog("Cannot create a sparse matrix using this initializer")
            
            return nil
        }
        else
        {
            self.complexBuffer = buffer
        }
    }
    
    /**
        Initializer to convert a PCH_SubMatrix to a PCH_Matrix
     
        - note: Sparse-matrix routines should use PCH_SubMatrix structure whenever possible in order to speed up operations and reduce memory overhead
     
        - parameter subMatrix: The structure that holds the information needed to create teh PCH_Matrix
        - parameter: convertToGE: A flag that indicates that the returned matrix should be first converted to a general matrix. Note that this only has an effect on sparse matrices (all other matrix types are converted to GE)
    */
    convenience init(subMatrix:PCH_SubMatrix, convertToGE:Bool)
    {
        let numRows = subMatrix.rowEnd - subMatrix.rowStart + 1
        let numCols = subMatrix.colEnd - subMatrix.colStart + 1
        let srcMatrix = subMatrix.matrix
        
        if (srcMatrix.matrixType == types.sparseMatrix && !convertToGE)
        {
            self.init(numRows: numRows, numCols: numCols, matrixPrecision: srcMatrix.matrixPrecision, matrixType: types.sparseMatrix)
            
            /*
            if (srcMatrix.matrixPrecision == precisions.doublePrecision)
            {
                // TODO: See if there's a better way to mask out the unneeded members of srcMatrix
                for (key, value) in srcMatrix.sparseDoubleDict!
                {
                    if (key.row >= subMatrix.rowStart && key.row <= subMatrix.rowEnd && key.col >= subMatrix.colStart && key.col <= subMatrix.colEnd)
                    {
                        self[key.row - subMatrix.rowStart, key.col - subMatrix.colStart] = value
                    }
                }
            }
            else
            {
                for (key, value) in srcMatrix.sparseComplexDict!
                {
                    if (key.row >= subMatrix.rowStart && key.row <= subMatrix.rowEnd && key.col >= subMatrix.colStart && key.col <= subMatrix.colEnd)
                    {
                        self[key.row - subMatrix.rowStart, key.col - subMatrix.colStart] = value
                    }
                }
            }
            */
        }
        /*
        else if (srcMatrix.matrixType == types.sparseMatrix)
        {
            self.init(numRows: numRows, numCols: numCols, matrixPrecision: srcMatrix.matrixPrecision, matrixType: types.generalMatrix)
            
            if (srcMatrix.matrixPrecision == precisions.doublePrecision)
            {
                // TODO: See if there's a better way to mask out the unneeded members of srcMatrix
                for (key, value) in srcMatrix.sparseDoubleDict!
                {
                    if (key.row >= subMatrix.rowStart && key.row <= subMatrix.rowEnd && key.col >= subMatrix.colStart && key.col <= subMatrix.colEnd)
                    {
                        self[key.row - subMatrix.rowStart, key.col - subMatrix.colStart] = value
                    }
                }
            }
            else
            {
                ALog("Cannot carry out complex-precision conversion for sparse matrices (not implemented)")
            }
        }
        */
        else
        {
            self.init(numRows: numRows, numCols: numCols, matrixPrecision: srcMatrix.matrixPrecision, matrixType: types.generalMatrix)
        }
            for row in subMatrix.rowStart...subMatrix.rowEnd
            {
                for col in subMatrix.colStart...subMatrix.colEnd
                {
                    if (self.matrixPrecision == precisions.doublePrecision)
                    {
                        let value:Double = srcMatrix[row,col]
                        self[row - subMatrix.rowStart, col - subMatrix.colStart] = value
                    }
                    else
                    {
                        let value:Complex = srcMatrix[row,col]
                        self[row - subMatrix.rowStart, col - subMatrix.colStart] = value
                    }
                }
            }
        
    }
    
    /**
        Copy / Conversion initializer. The type of the matrix can be changed, but the precision of the matrix cannot.
     
        - note: This initializer can fail if the source matrix cannot be converted to the new type.
     
        - remark: Any matrix type can be converted to general matrix, but other types obviously depend on the structure of the source matrix.
     
        - todo: Implement the ability to change to different matrix types (for now, the routine can only convert to general matrices)
     
        - parameter sourceMatrix: The matrix to copy
        - parameter newMatrixType: Optional parameter used to convert the matrix to a new type
    */
    convenience init?(sourceMatrix:PCH_Matrix, newMatrixType:types? = nil)
    {
        if ((newMatrixType == nil) || (newMatrixType == sourceMatrix.matrixType))
        {
            if (sourceMatrix.matrixPrecision == precisions.doublePrecision)
            {
                if (sourceMatrix.matrixType == types.sparseMatrix)
                {
                    self.init(numRows:sourceMatrix.numRows, numCols:sourceMatrix.numCols, doubleDictionary:sourceMatrix.sparseDoubleDict!)
                }
                else
                {
                    self.init(numRows:sourceMatrix.numRows, numCols:sourceMatrix.numCols, buffer:sourceMatrix.doubleBuffer!, matrixType:sourceMatrix.matrixType, subDiagonals:sourceMatrix.subDiagonals, superDiagonals:sourceMatrix.superDiagonals)
                }
            }
            else
            {
                if (sourceMatrix.matrixType == types.sparseMatrix)
                {
                    self.init(numRows:sourceMatrix.numRows, numCols:sourceMatrix.numCols, complexDictionary:sourceMatrix.sparseComplexDict!)
                }
                else
                {
                    self.init(numRows:sourceMatrix.numRows, numCols:sourceMatrix.numCols, buffer:sourceMatrix.complexBuffer!, matrixType:sourceMatrix.matrixType, subDiagonals:sourceMatrix.subDiagonals, superDiagonals:sourceMatrix.superDiagonals)
                }
            }
            
            return
        }
        
        // If we get here, we need to do a conversion.
        
        if (newMatrixType == types.generalMatrix)
        {
            self.init(numRows:sourceMatrix.numRows, numCols:sourceMatrix.numCols, matrixPrecision:sourceMatrix.matrixPrecision, matrixType:newMatrixType!)
            
            if (sourceMatrix.matrixPrecision == precisions.doublePrecision)
            {
                if (sourceMatrix.matrixType == types.sparseMatrix)
                {
                    for (key, value) in sourceMatrix.sparseDoubleDict!
                    {
                        self[key.row, key.col] = value
                    }
                }
                else if (sourceMatrix.matrixType == types.diagonalMatrix)
                {
                    for nextVal in 0..<sourceMatrix.numRows
                    {
                        self[nextVal, nextVal] = sourceMatrix.doubleBuffer![nextVal]
                    }
                }
                else if (sourceMatrix.matrixType == types.upperTriangularMatrix)
                {
                    for row in 0..<sourceMatrix.numRows
                    {
                        for col in row..<sourceMatrix.numCols
                        {
                            let newValue:Double = sourceMatrix[row,col]
                            self[row,col] = newValue
                        }
                    }
                }
                else if (sourceMatrix.matrixType == types.lowerTriangularMatrix)
                {
                    for col in 0..<sourceMatrix.numCols
                    {
                        for row in col..<sourceMatrix.numRows
                        {
                            let newValue:Double = sourceMatrix[row,col]
                            self[row,col] = newValue
                        }
                    }
                }
                else if ((sourceMatrix.matrixType == types.symmetricMatrix) || (sourceMatrix.matrixType == types.positiveDefinite))
                {
                    for row in 0..<sourceMatrix.numRows
                    {
                        for col in row..<sourceMatrix.numCols
                        {
                            let newValue:Double = sourceMatrix[row,col]
                            self[row,col] = newValue
                            if (row != col)
                            {
                                self[col,row] = newValue
                            }
                        }
                    }
                }
                else if (sourceMatrix.matrixType == types.bandedMatrix)
                {
                    for row in 0..<sourceMatrix.numRows
                    {
                        for col in 0..<sourceMatrix.numCols
                        {
                            let kl = sourceMatrix.subDiagonals
                            let ku = sourceMatrix.superDiagonals
                            
                            if !(row > col + kl) || (col > row + ku)
                            {
                                self[row,col] = sourceMatrix.doubleBuffer![col * (2 * kl + ku + 1) + kl + ku + row - col]
                            }
                        }
                    }
                }
                else
                {
                    ALog("Unimplemented matrix type")
                }
                
            }
            else
            {
                if (sourceMatrix.matrixType == types.sparseMatrix)
                {
                    for (key, value) in sourceMatrix.sparseComplexDict!
                    {
                        self[key.row, key.col] = value
                    }
                }
                else if (sourceMatrix.matrixType == types.diagonalMatrix)
                {
                    for nextVal in 0..<sourceMatrix.numRows
                    {
                        let newValue:__CLPK_doublecomplex = sourceMatrix.complexBuffer![nextVal]
                        self[nextVal, nextVal] = Complex(real: newValue.r, imag: newValue.i)
                    }
                }
                else if (sourceMatrix.matrixType == types.upperTriangularMatrix)
                {
                    for row in 0..<sourceMatrix.numRows
                    {
                        for col in row..<sourceMatrix.numCols
                        {
                            let newValue:Complex = sourceMatrix[row,col]
                            self[row,col] = newValue
                        }
                    }
                }
                else if (sourceMatrix.matrixType == types.lowerTriangularMatrix)
                {
                    for col in 0..<sourceMatrix.numCols
                    {
                        for row in col..<sourceMatrix.numRows
                        {
                            let newValue:Complex = sourceMatrix[row,col]
                            self[row,col] = newValue
                        }
                    }
                }
                else if ((sourceMatrix.matrixType == types.symmetricMatrix) || (sourceMatrix.matrixType == types.positiveDefinite))
                {
                    for row in 0..<sourceMatrix.numRows
                    {
                        for col in row..<sourceMatrix.numCols
                        {
                            let newValue:Complex = sourceMatrix[row,col]
                            self[row,col] = newValue
                            if (row != col)
                            {
                                self[col,row] = newValue
                            }
                        }
                    }
                }
                else if (sourceMatrix.matrixType == types.bandedMatrix)
                {
                    for row in 0..<sourceMatrix.numRows
                    {
                        for col in 0..<sourceMatrix.numCols
                        {
                            let kl = sourceMatrix.subDiagonals
                            let ku = sourceMatrix.superDiagonals
                            
                            if !(row > col + kl) || (col > row + ku)
                            {
                                let newValue:__CLPK_doublecomplex = sourceMatrix.complexBuffer![col * (2 * kl + ku + 1) + kl + ku + row - col]
                                self[row,col] = Complex(real: newValue.r, imag: newValue.i)
                            }
                        }
                    }
                }
                else
                {
                    ALog("Unimplemented matrix type")
                    return nil
                }
            }
            
        }
        else
        {
            ALog("Conversion is not implemented for that type of matrix")
            return nil
        }
        
        return
    }
    
    /**
        Set an entire row of a matrix to the values in a vector.
    */
    
    func SetRow(_ rowNum:Int, vector:PCH_Matrix)
    {
        if (vector.matrixPrecision == precisions.doublePrecision)
        {
            self.SetRow(rowNum, buffer: vector.doubleBuffer!)
            return
        }
        
        ZAssert(self.matrixPrecision == vector.matrixPrecision, message: "Vector's precision must match matrix precision")
        ZAssert(rowNum < self.numRows && rowNum >= 0, message: "Illegal row number")
        ZAssert(vector.numCols == 1, message: "The vector parameter must have only one column 9ie: it must be a vector)")
        ZAssert(self.numCols == vector.numRows, message: "The matrix must have the same number of columns as elements in the vector")
        
        for i in 0..<self.numCols
        {
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                let number:Double = vector[i, 0]
                self[rowNum, i] = number
            }
            else
            {
                ALog("This function is not implemented for non-double precisions")
            }
        }
    }
    
    /**
        Set an entire row in a double-precision matrix to the values passed in via buffer. Usually, buffer.count is equal to self.numCols. If buffer.count < self.numCols, then the rest of the row is padded with zeroes. If buffer.count > self.numCols, only the first self.numCols values are set.
        
        - parameter: rowNum: The row that will be replaced by the passed-in buffer
        - parameter: buffer: The array of Doubles that will be used
    */
    func SetRow(_ rowNum:Int, buffer:[Double])
    {
        ZAssert(self.matrixPrecision == precisions.doublePrecision, message: "This function is for double-precision values")
        
        ZAssert(rowNum < self.numRows && rowNum >= 0, message: "Illegal row number")
        
        var useBuffer = buffer
    
        if (buffer.count < self.numCols)
        {
            let zeroesToAdd = self.numCols - buffer.count
            
            for _ in 0..<zeroesToAdd
            {
                useBuffer.append(0.0)
            }
        }
        else if (buffer.count > self.numCols)
        {
            let numsToRemove = buffer.count - self.numCols
            
            for _ in 0..<numsToRemove
            {
                useBuffer.removeLast()
            }
        }
        
        for col in 0..<useBuffer.count
        {
            self[rowNum, col] = useBuffer[col]
        }
    }
    
    /**
     Add an entire column to a double-precision matrix.
     
     - parameter colNum: The column number that will be set to the values in colBuffer
     - parameter colBuffer: An array of values that will be stored in the column colNum.
     
     - note: If there are *less* entries in **colBuffer** than the number of rows in the matrix, the missing values will be padded with zeroes. If there are *more* entries in **colBuffer** than the number of rows in the matrix, then the extra entries are ignored.
     
    */
    func AddColumn(_ colNum:Int, colBuffer:[Double])
    {
        ZAssert(colNum >= 0 && colNum < self.numCols, message: "Illegal column number")
        
        if (colBuffer.count > self.numRows)
        {
            DLog("Too many rows in buffer - using the first \(self.numRows) entries only")
        }
        
        if (colBuffer.count < self.numRows)
        {
            DLog("Not enough rows in buffer to fill the column - missing rows will get zeroes")
        }

        for row in 0..<self.numRows
        {
            if (row >= colBuffer.count)
            {
                self[row, colNum] = 0.0
            }
            else
            {
                self[row, colNum] = colBuffer[row]
            }
        }
    }
    
    /**
     Add an entire column to a complex-precision matrix.
     
     - parameter colNum: The column number that will be set to the values in colBuffer
     - parameter colBuffer: An array of values that will be stored in the column colNum.
     
     - note: If there are *less* entries in **colBuffer** than the number of rows in the matrix, the missing values will be padded with zeroes. If there are *more* entries in **colBuffer** than the number of rows in the matrix, then the extra entries are ignored.
     
     */
    func AddColumn(_ colNum:Int, colBuffer:[Complex])
    {
        ZAssert(colNum >= 0 && colNum < self.numCols, message: "Illegal column number")
        
        if (colBuffer.count > self.numRows)
        {
            DLog("Too many rows in buffer - using the first \(self.numRows) entries only")
        }
        
        if (colBuffer.count < self.numRows)
        {
            DLog("Not enough rows in buffer to fill the column - missing rows will get zeroes")
        }
        
        for row in 0..<self.numRows
        {
            if (row >= colBuffer.count)
            {
                self[row, colNum] = Complex(real: 0.0, imag: 0.0)
            }
            else
            {
                self[row, colNum] = colBuffer[row]
            }
        }
    }
    
    
    
    /**
        Add an entire row to a double-precision matrix.
     
        - parameter rowNum: The row number that will be set to the values in rowBuffer
        - parameter rowBuffer: An array of values that will be stored in the row rowNum.
        
        - note: If there are *less* entries in **rowBuffer** than the number of columns in the matrix, the missing values will be padded with zeroes. If there are *more* entries in **rowBuffer** than the number of columns in the matrix, then the extra entries are ignored.
     
    */
    func AddRow(_ rowNum:Int, rowBuffer:[Double])
    {
        ZAssert(rowNum >= 0 && rowNum < self.numRows, message: "Illegal row number")
        
        if (rowBuffer.count > self.numCols)
        {
            DLog("Too many columns in buffer - using the first \(self.numCols) entries only")
        }
        
        if (rowBuffer.count < self.numCols)
        {
            DLog("Not enough columns in buffer to fill the row - missing columns will get zeroes")
        }
        
        for column in 0..<self.numCols
        {
            if (column >= rowBuffer.count)
            {
                self[rowNum, column] = 0.0
            }
            else
            {
                self[rowNum, column] = rowBuffer[column]
            }
        }
    }
    
    /**
     Add an entire row to a complex-precision matrix.
     
     - parameter rowNum: The row number that will be set to the values in rowBuffer
     - parameter rowBuffer: An array of values that will be stored in the row rowNum.
     
     - note: If there are *less* entries in **rowBuffer** than the number of columns in the matrix, the missing values will be padded with zeroes. If there are *more* entries in **rowBuffer** than the number of columns in the matrix, then the extra entries are ignored.
     
     */
    func AddRow(_ rowNum:Int, rowBuffer:[Complex])
    {
        ZAssert(rowNum >= 0 && rowNum < self.numRows, message: "Illegal row number")
        
        if (rowBuffer.count > self.numCols)
        {
            DLog("Too many columns in buffer - using the first \(self.numCols) entries only")
        }
        
        if (rowBuffer.count < self.numCols)
        {
            DLog("Not enough columns in buffer to fill the row - missing columns will get zeroes")
        }
        
        for column in 0..<self.numCols
        {
            if (column >= rowBuffer.count)
            {
                self[rowNum, column] = Complex(real: 0.0, imag: 0.0)
            }
            else
            {
                self[rowNum, column] = rowBuffer[column]
            }
        }
    }
    
    /**
        Extract a submatrix from self. The returned submatrix will usually be a general matrix, unless self is sparse, in which case it will usually not change (that is, it will also be sparse). The calling routine sets a flag to indicate what sort of submatrix to return.
     
        - parameter fromRow: The first row to include in the submatrix
        - parameter: toRow: The last row to include in the submatrix
        - parameter: fromCol: The first column to include in the submatrix
        - parameter: toCol: The last column to include in the submatrix
        - parameter: convertToGE: A flag that indicates that the returned matrix should be first converted to a general matrix.
    */
    func Submatrix(fromRow:Int, toRow:Int, fromCol:Int, toCol:Int, convertToGE:Bool = true) -> PCH_Matrix
    {
        ZAssert(fromRow >= 0 && toRow < self.numRows && fromRow <= toRow  && fromCol >= 0 && toCol < self.numCols && fromCol <= toCol, message: "Illegal index")
        
        var result:PCH_Matrix?
        
        if (self.matrixType == types.sparseMatrix && !convertToGE)
        {
            result = PCH_Matrix(numRows: toRow - fromRow + 1, numCols: toCol - fromCol + 1, matrixPrecision: self.matrixPrecision, matrixType: types.sparseMatrix)
            
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                for (key, value) in self.sparseDoubleDict!
                {
                    if (key.row >= fromRow && key.row <= toRow && key.col >= fromCol && key.col <= toCol)
                    {
                        result![key.row - fromRow, key.col - fromCol] = value
                    }
                }
            }
            else
            {
                for (key, value) in self.sparseComplexDict!
                {
                    if (key.row >= fromRow && key.row <= toRow && key.col >= fromCol && key.col <= toCol)
                    {
                        result![key.row - fromRow, key.col - fromCol] = value
                    }
                }
            }
        }
        else if (!convertToGE)
        {
            result = PCH_Matrix(numRows: toRow - fromRow + 1, numCols: toCol - fromCol + 1, matrixPrecision: self.matrixPrecision, matrixType: self.matrixType)
            
            for row in fromRow...toRow
            {
                for col in fromCol...toCol
                {
                    if (self.matrixPrecision == precisions.doublePrecision)
                    {
                        let value:Double = self[row,col]
                        result![row - fromRow, col - fromCol] = value
                    }
                    else
                    {
                        let value:Complex = self[row,col]
                        result![row - fromRow, col - fromCol] = value
                    }
                }
            }
        }
        else
        {
            result = PCH_Matrix(numRows: toRow - fromRow + 1, numCols: toCol - fromCol + 1, matrixPrecision: self.matrixPrecision, matrixType: types.generalMatrix)
            
            for row in fromRow...toRow
            {
                for col in fromCol...toCol
                {
                    if (self.matrixPrecision == precisions.doublePrecision)
                    {
                        let value:Double = self[row,col]
                        result![row - fromRow, col - fromCol] = value
                    }
                    else
                    {
                        let value:Complex = self[row,col]
                        result![row - fromRow, col - fromCol] = value
                    }
                }
            }
        }
        
        return result!
    }
    
    /**
        Compute the eigenvalues of a matrix
     
        - returns: An array of Complex values that are the eigenvalues of the matrix, or an empty array if the function fails
    */
    func Eigenvalues() -> [Complex]
    {
        ZAssert(self.numRows == self.numCols, message: "Eigenvalues can only be computed for square matrices")
        
        var result = [Complex]()
        
        if (self.matrixType == types.generalMatrix)
        {
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                var jobvl:Int8 = 78 // 'N'
                var jobvr:Int8 = 78
                
                var n = __CLPK_integer(self.numRows)
                var Am = self.doubleBuffer!
                var lda = n
                
                var wr = [__CLPK_doublereal](repeating: 0.0, count: self.numRows)
                var wi = [__CLPK_doublereal](repeating: 0.0, count: self.numRows)
                
                // The vl and vr arrays are used for eigenvectors (not implemented at this point)
                var vl = [__CLPK_doublereal](repeating: 0.0, count: self.numRows)
                var ldvl = __CLPK_integer(n)
                
                var vr = [__CLPK_doublereal](repeating: 0.0, count: self.numRows)
                var ldvr = __CLPK_integer(n)
                
                var optWork = [__CLPK_doublereal](repeating: 0.0, count: 1)
                var lWork:__CLPK_integer = -1 // First time through, we need to find the optimium size for WORK
                
                var info = __CLPK_integer(0)
                
                dgeev_(&jobvl, &jobvr, &n, &Am, &lda, &wr, &wi, &vl, &ldvl, &vr, &ldvr, &optWork, &lWork, &info)
                
                var actualWork = [__CLPK_doublereal](repeating: 0.0, count: Int(optWork[0]))
                lWork = __CLPK_integer(optWork[0])
                
                dgeev_(&jobvl, &jobvr, &n, &Am, &lda, &wr, &wi, &vl, &ldvl, &vr, &ldvr, &actualWork, &lWork, &info)
                
                if (info != 0)
                {
                    DLog("Error in dgeev: \(info)")
                }
                else
                {
                    for index in 0..<self.numRows
                    {
                        result.append(Complex(real: wr[index], imag: wi[index]))
                    }
                }
            }
            else
            {
                var jobvl:Int8 = 78 // 'N'
                var jobvr:Int8 = 78
                
                var n = __CLPK_integer(self.numRows)
                var Am = self.complexBuffer!
                var lda = n
                
                var w = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: self.numRows)
                
                // The vl and vr arrays are used for eigenvectors (not implemented at this point)
                var vl = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: self.numRows)
                var ldvl = __CLPK_integer(n)
                
                var vr = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: self.numRows)
                var ldvr = __CLPK_integer(n)
                
                var optWork = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: 1)
                var lWork:__CLPK_integer = -1 // First time through, we need to find the optimium size for WORK
                var rWork = [__CLPK_doublereal](repeating: 0.0, count: 2 * self.numRows)
                
                var info = __CLPK_integer(0)
                
                zgeev_(&jobvl, &jobvr, &n, &Am, &lda, &w, &vl, &ldvl, &vr, &ldvr, &optWork, &lWork, &rWork, &info)
                
                var actualWork = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: Int(optWork[0].r))
                lWork = __CLPK_integer(optWork[0].r)
                
                zgeev_(&jobvl, &jobvr, &n, &Am, &lda, &w, &vl, &ldvl, &vr, &ldvr, &actualWork, &lWork, &rWork, &info)
                
                if (info != 0)
                {
                    DLog("Error in dgeev: \(info)")
                }
                else
                {
                    for index in 0..<self.numRows
                    {
                        result.append(Complex(real: w[index].r, imag: w[index].i))
                    }
                }
            }
        }
        else
        {
            DLog("Eigenvalue computation has not been implemented for this type of matrix")
        }
        
        return result
    }
    
    /**
        Get the inverse of the matrix. Self is unchanged.
     
        - returns: A new matrix that is the inverse of the target, or nil if the inverse does not exist
    */
    func Inverse() -> PCH_Matrix?
    {
        var m:__CLPK_integer = __CLPK_integer(self.numRows)
        var n:__CLPK_integer = __CLPK_integer(self.numCols)
        var lda = m
        var ipiv = [__CLPK_integer](repeating: 0, count: min(self.numRows, self.numCols))
        var info:__CLPK_integer = 0
        
        if (self.matrixType == types.generalMatrix)
        {
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                // Do an LU factorization of self
                var A = self.doubleBuffer!
                
                dgetrf_(&m, &n, &A, &lda, &ipiv, &info)
                
                if (info != 0)
                {
                    DLog("Error in dgetrf: \(info)")
                    
                    return nil
                }
                
                n = __CLPK_integer(self.numCols)
                lda = n
                var optWork = [__CLPK_doublereal](repeating: 0.0, count: 1)
                var lWork:__CLPK_integer = -1 // First time through, we need to find the optimium size for WORK
                
                dgetri_(&n, &A, &lda, &ipiv, &optWork, &lWork, &info)
                
                var actualWork = [__CLPK_doublereal](repeating: 0.0, count: Int(optWork[0]))
                lWork = n // this can be optimized (see netlib)
                
                dgetri_(&n, &A, &lda, &ipiv, &actualWork, &lWork, &info)
                
                if (info != 0)
                {
                    DLog("Error in dgetri: \(info)")
                    
                    return nil
                }
                
                return PCH_Matrix(numRows: self.numRows, numCols: self.numCols, buffer: A, matrixType: self.matrixType)
            }
            else
            {
                // Do an LU factorization of self
                var A = self.complexBuffer!
                
                zgetrf_(&m, &n, &A, &lda, &ipiv, &info)
                
                if (info != 0)
                {
                    DLog("Error in zgetrf: \(info)")
                    
                    return nil
                }
                
                n = __CLPK_integer(self.numCols)
                lda = n
                var optWork = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: 1)
                var lWork:__CLPK_integer = -1 // First time through, we need to find the optimium size for WORK
                
                zgetri_(&n, &A, &lda, &ipiv, &optWork, &lWork, &info)
                
                var actualWork = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: Int(optWork[0].r))
                
                lWork = n // this can be optimized (see netlib)
                
                zgetri_(&n, &A, &lda, &ipiv, &actualWork, &lWork, &info)
                
                if (info != 0)
                {
                    DLog("Error in zgetri: \(info)")
                    
                    return nil
                }
                
                return PCH_Matrix(numRows: self.numRows, numCols: self.numCols, buffer: A, matrixType: self.matrixType)
            }
        }
        else
        {
            ALog("Inversion has not been implemented for this matrix type!")
            
            return nil
        }
        
    }
    
    /**
        Add/subtract self (A) and matrix X and return the result in B
     
        - parameter X: The X matrix
        - parameter isAdd: If 'true' then return A+X, otherwise return A-X
        
        - returns: The B matrix (same type as self (A))
    */
    func AddSubtract(_ X:PCH_Matrix, isAdd:Bool = true) -> PCH_Matrix
    {
        ZAssert(self.numRows == X.numRows && self.numCols == X.numCols, message: "A and X matrices must have identical dimensions!")
        ZAssert(self.matrixPrecision == X.matrixPrecision, message: "Both matrices must be of the same precision")
        
        let B = PCH_Matrix(sourceMatrix: self)!
        
        for row in 0..<self.numRows
        {
            for col in 0..<self.numCols
            {
                if (self.matrixPrecision == precisions.doublePrecision)
                {
                    let result:Double = (isAdd ? self[row,col] + X[row,col] : self[row,col] - X[row,col])
                    B[row,col] = result
                }
                else
                {
                    let result:Complex = (isAdd ? self[row,col] + X[row,col] : self[row,col] - X[row,col])
                    B[row,col] = result
                }
            }
        }
        
        return B
    }
    
    /**
        Multiply the matrix A by the matrix X and return B. For now, only general matrices can be multiplied. This will change according to need.
     
        - parameter X: The X matrix
     
        - returns: The B matrix (always a general matrix, except if A and X are both diagonal, in which case B is also diagonal)
    */
    func MultiplyBy(_ X:PCH_Matrix) -> PCH_Matrix?
    {
        ZAssert(self.numCols == X.numRows, message: "A-matrix numCols must be equal to X-matrix numRows")
        ZAssert(self.matrixPrecision == X.matrixPrecision, message: "Both matrices must be of the same precision")
        
        let m = __CLPK_integer(self.numRows)
        let n = __CLPK_integer(X.numCols)
        let k = __CLPK_integer(self.numCols)
        
        let lda = m
        let ldb = k
        let ldc = m
        
        if (self.matrixType == types.generalMatrix) && (X.matrixType == types.generalMatrix)
        {
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                var B = [__CLPK_doublereal](repeating: 0.0, count: Int(ldc * n))
                var Abuf = self.doubleBuffer!
                var Xbuf = X.doubleBuffer!
                
                if (X.isVector)
                {
                    cblas_dgemv(CblasColMajor, CblasNoTrans, m, k, 1.0, &Abuf, lda, &Xbuf, 1, 0.0, &B, 1)
                }
                else
                {
                    cblas_dgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, m, n, k, 1.0, &Abuf, lda, &Xbuf, ldb, 0.0, &B, ldc)
                }
                
                return PCH_Matrix(numRows: Int(ldc), numCols: Int(n), buffer: B, matrixType: types.generalMatrix)
            }
            else
            {
                var B = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: Int(ldc * n))
                var Abuf = self.complexBuffer!
                var Xbuf = X.complexBuffer!
                
                var alpha = __CLPK_doublecomplex(r: 1.0, i: 0.0)
                var beta = __CLPK_doublecomplex(r: 0.0, i: 0.0)
                
                if (X.isVector)
                {
                    cblas_zgemv(CblasColMajor, CblasNoTrans, m, k, &alpha, &Abuf, lda, &Xbuf, 1, &beta, &B, 1)
                }
                else
                {
                    cblas_zgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, m, n, k, &alpha, &Abuf, lda, &Xbuf, ldb, &beta, &B, ldc)
                }
                
                return PCH_Matrix(numRows: Int(ldc), numCols: Int(n), buffer: B, matrixType: types.generalMatrix)
            }
        }
        else if (self.matrixType == types.generalMatrix) && (X.matrixType == types.diagonalMatrix)
        {
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                var B = [__CLPK_doublereal](repeating: 0.0, count: self.numRows * X.numCols)
                
                for nextRow in 0..<self.numRows
                {
                    for nextCol in 0..<X.numCols
                    {
                        B[nextCol * self.numRows + nextRow] = X.doubleBuffer![nextCol] * self.doubleBuffer![nextCol * self.numRows + nextRow]
                    }
                }
                
                return PCH_Matrix(numRows: self.numRows, numCols: X.numCols, buffer: B, matrixType: types.generalMatrix)
            }
            else
            {
                var B = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: self.numRows * X.numCols)
                
                for nextRow in 0..<self.numRows
                {
                    let leftValue:Complex = X[nextRow, nextRow]
                    
                    for nextCol in 0..<X.numCols
                    {
                        let value:Complex = leftValue * self[nextRow, nextCol]
                        
                        B[nextCol * self.numRows + nextRow] = __CLPK_doublecomplex(r: value.real, i: value.imag)
                    }
                }
                
                return PCH_Matrix(numRows: self.numRows, numCols: X.numCols, buffer: B, matrixType: types.generalMatrix)
            }
        }
        else if (self.matrixType == types.diagonalMatrix) && (X.matrixType == types.generalMatrix)
        {
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                var B = [__CLPK_doublereal](repeating: 0.0, count: self.numRows * X.numCols)
                
                for nextRow in 0..<self.numRows
                {
                    for nextCol in 0..<X.numCols
                    {
                        B[nextCol * self.numRows + nextRow] = self.doubleBuffer![nextRow] * X.doubleBuffer![nextCol * X.numRows + nextRow]
                    }
                }
                
                return PCH_Matrix(numRows: self.numRows, numCols: X.numCols, buffer: B, matrixType: types.generalMatrix)
            }
            else
            {
                var B = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: self.numRows * X.numCols)
                
                for nextRow in 0..<self.numRows
                {
                    let leftValue:Complex = self[nextRow, nextRow]
                    
                    for nextCol in 0..<X.numCols
                    {
                        let value:Complex = leftValue * X[nextRow, nextCol]
                        
                        B[nextCol * self.numRows + nextRow] = __CLPK_doublecomplex(r: value.real, i: value.imag)
                    }
                }
                
                return PCH_Matrix(numRows: self.numRows, numCols: X.numCols, buffer: B, matrixType: types.generalMatrix)
            }
        }
        else if (self.matrixType == types.diagonalMatrix) && (X.matrixType == types.diagonalMatrix)
        {
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                var B = [__CLPK_doublereal](repeating: 0.0, count: self.numRows)
                
                for nextVal in 0..<self.numRows
                {
                    B[nextVal] = self.doubleBuffer![nextVal] * X.doubleBuffer![nextVal]
                }
                
                return PCH_Matrix(numRows: self.numRows, numCols: X.numCols, buffer: B, matrixType: types.diagonalMatrix)
            }
            else
            {
                var B = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: self.numRows)
                
                for nextVal in 0..<self.numRows
                {
                    let value:Complex = self[nextVal, nextVal] * X[nextVal, nextVal]
                    
                    B[nextVal] = __CLPK_doublecomplex(r: value.real, i: value.imag)
                }
                
                return PCH_Matrix(numRows: self.numRows, numCols: X.numCols, buffer: B, matrixType: types.diagonalMatrix)
            }
        }
        else
        {
            ALog("Function not implemented for this type of matrix!")
        }
        
        return nil
    }
    
    /**
        Solve the system AX = B where A is self and B is passed to the routine.
     
        - note: The B matrix MUST be a generalMatrix type
        
        - parameter B: The B matrix in AX = B
     
        - returns: The solution matrix X, or nil if the system could not be solved.
    */
    func SolveWith(_ B:PCH_Matrix) -> PCH_Matrix?
    {
        // NOTE: At this time, only "simple drivers" are implemented (ie: no equilibrium or conditioning). This may change at some point.
        
        ZAssert(self.numRows == B.numRows, message: "The A and B matrices must have the same number of rows")
        
        ZAssert(self.numRows == self.numCols, message: "The A matrix must be square")
        
        ZAssert(self.matrixPrecision == B.matrixPrecision, message: "The A and B matrices must be of the same precision")
        
        ZAssert(B.matrixType == types.generalMatrix, message: "The B matrix must be a general matrix")
        
        if (self.matrixType == types.sparseMatrix)
        {
            // TODO: Implement sparse matrix solving
            
            // The strategy here is to do an LU factorization of the sparse matrix A. So, first we do PA=LU (where P is the "permutation matrix" and is representative of the reordering of rows that may be required - this is the IPIV argument in many LAPACK routines). Then, AX=B becomes LUX=B. This can be solved by doing LY=PB and then UX=Y. Now, this is good, because the Sparse BLAS provides triangular solve routines. However, it does not provide sparse LU factorization. One strategy is to create a general matrix from the sparse matrix. We then can do a factorization using DGETRF. The two triangular matrices L and U must then be converted to sparse types, and the two solves can be done (simple!). However, some poor schmuck already did lots of the testing we'll need to do. See https://forums.developer.apple.com/thread/27631 Note that he says in a follow-up post that it's really not worth the work (presumably since the only way to use BLAS factoring is to recreate the sparse matrix as a general one). I will try and find/implement a sparse factorization algorithm.
        }
        else if (self.matrixType == types.generalMatrix)
        {
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                var Am = self.doubleBuffer!
                var Bm = B.doubleBuffer!
                
                var n:__CLPK_integer = __CLPK_integer(self.numRows)
                var nrhs = __CLPK_integer(B.numCols)
                var lda = n
                var ldb = n
                var ipiv = [__CLPK_integer](repeating: 0, count: self.numRows)
                var info:__CLPK_integer = 0
                
                dgesv_(&n, &nrhs, &Am, &lda, &ipiv, &Bm, &ldb, &info)
                
                if (info != 0)
                {
                    DLog("Error in dgesv: \(info)")
                    
                    return nil
                }
                
                return PCH_Matrix(numRows: B.numRows, numCols: B.numCols, buffer: Bm, matrixType: B.matrixType)
            }
            else
            {
                var Am = self.complexBuffer!
                var Bm = B.complexBuffer!
                
                var n:__CLPK_integer = __CLPK_integer(self.numRows)
                var nrhs = __CLPK_integer(B.numCols)
                var lda = n
                var ldb = n
                var ipiv = [__CLPK_integer](repeating: 0, count: self.numRows)
                var info:__CLPK_integer = 0
                
                zgesv_(&n, &nrhs, &Am, &lda, &ipiv, &Bm, &ldb, &info)
                
                if (info != 0)
                {
                    DLog("Error in zgesv: \(info)")
                    
                    return nil
                }
                
                return PCH_Matrix(numRows: B.numRows, numCols: B.numCols, buffer: Bm, matrixType: B.matrixType)
            }
        }
        else if (self.matrixType == types.bandedMatrix) || (self.matrixType == types.upperTriangularMatrix) || (self.matrixType == types.lowerTriangularMatrix) || (self.matrixType == types.diagonalMatrix)
        {
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                var Am = self.doubleBuffer!
                var Bm = B.doubleBuffer!
                
                var n:__CLPK_integer = __CLPK_integer(self.numRows)
                var nrhs = __CLPK_integer(B.numCols)
                var kl = __CLPK_integer(self.subDiagonals)
                var ku = __CLPK_integer(self.superDiagonals)
                var ldab = 2 * kl + ku + 1
                var ldb = n
                var ipiv = [__CLPK_integer](repeating: 0, count: self.numRows)
                var info:__CLPK_integer = 0
                
                dgbsv_(&n, &kl, &ku, &nrhs, &Am, &ldab, &ipiv, &Bm, &ldb, &info)
                
                if (info != 0)
                {
                    DLog("Error in dgbsv: \(info)")
                    
                    return nil
                }
                
                return PCH_Matrix(numRows: B.numRows, numCols: B.numCols, buffer: Bm, matrixType: B.matrixType)
            }
            else
            {
                var Am = self.complexBuffer!
                var Bm = B.complexBuffer!
                
                var n:__CLPK_integer = __CLPK_integer(self.numRows)
                var nrhs = __CLPK_integer(B.numCols)
                var kl = __CLPK_integer(self.subDiagonals)
                var ku = __CLPK_integer(self.superDiagonals)
                var ldab = 2 * kl + ku + 1
                var ldb = n
                var ipiv = [__CLPK_integer](repeating: 0, count: self.numRows)
                var info:__CLPK_integer = 0
                
                zgbsv_(&n, &kl, &ku, &nrhs, &Am, &ldab, &ipiv, &Bm, &ldb, &info)
                
                if (info != 0)
                {
                    DLog("Error in zgbsv: \(info)")
                    
                    return nil
                }
                
                return PCH_Matrix(numRows: B.numRows, numCols: B.numCols, buffer: Bm, matrixType: B.matrixType)
            }

        }
        else if (self.matrixType == types.symmetricMatrix)
        {
            // I found a disturbing fact when calling dsysv_ to solve symmetric matrices. If the A matrix is not invertible, the call SHOULD fail, bit does not (I have tested the same matrix with dgesv_ and ir DOES fail). Unless you're sure that the system is solvable (ie: A is invertible), it would probably be better to define the matrix as "general" instead. BTW, I have also found some anecdotal evidence that the dsysv_ call is actually SLOWER then the dgesv_ call, so....
            
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                // This is a bit weird because the buffer in self is in packed form, but the buffer we need to pass to the solving routine is not (presumably it needs the space to carry out the function). 
                
                var Am = [__CLPK_doublereal](repeating: 0.0, count: self.numRows * self.numCols)
                
                for col in 0..<self.numCols
                {
                    for row in 0...col
                    {
                        // we're only going to set the upper triangle (UPLO = 'U') of the buffer
                        Am[col * self.numRows + row] = self.doubleBuffer![row + col * (col + 1) / 2]
                        // Am[row * self.numCols + col] = self.doubleBuffer![row + col * (col + 1) / 2]
                    }
                }
                
                var uplo:Int8 = 85
                var n = __CLPK_integer(self.numRows)
                var nrhs = __CLPK_integer(B.numCols)
                var lda = n
                var ipiv = [__CLPK_integer](repeating: 0, count: self.numRows)
                var Bm = B.doubleBuffer!
                var ldb = n
                var info = __CLPK_integer(0)
                
                var optWork = [__CLPK_doublereal](repeating: 0.0, count: 1)
                var lWork:__CLPK_integer = -1 // First time through, we need to find the optimium size for WORK
                
                dsysv_(&uplo, &n, &nrhs, &Am, &lda, &ipiv, &Bm, &ldb, &optWork, &lWork, &info)
                
                if (info != 0)
                {
                    DLog("Error in dsysv 'work check': \(info)")
                    
                    return nil
                }

                lWork = __CLPK_integer(optWork[0])
                var actualWork = [__CLPK_doublereal](repeating: 0.0, count: Int(lWork))
                
                // dgesv_(&n, &nrhs, &Am, &lda, &ipiv, &Bm, &ldb, &info)
                dsysv_(&uplo, &n, &nrhs, &Am, &lda, &ipiv, &Bm, &ldb, &actualWork, &lWork, &info)
                
                if (info != 0)
                {
                    DLog("Error in dsysv: \(info)")
                    
                    return nil
                }
                
                return PCH_Matrix(numRows: B.numRows, numCols: B.numCols, buffer: Bm, matrixType: B.matrixType)
                
            }
            else
            {
                var Am = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: self.numRows * self.numCols)
                
                for col in 0..<self.numCols
                {
                    for row in 0...col
                    {
                        // we're only going to set the upper triangle (UPLO = 'U') of the buffer
                        Am[col * self.numRows + row] = self.complexBuffer![row + col * (col + 1) / 2]
                    }
                }
                
                var uplo:Int8 = 85 // 'U'
                var n = __CLPK_integer(self.numRows)
                var nrhs = __CLPK_integer(B.numCols)
                var lda = n
                var ipiv = [__CLPK_integer](repeating: 0, count: self.numRows)
                var Bm = B.complexBuffer!
                var ldb = n
                var info = __CLPK_integer(0)
                
                var optWork = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: 1)
                var lWork:__CLPK_integer = -1 // First time through, we need to find the optimium size for WORK
                
                zsysv_(&uplo, &n, &nrhs, &Am, &lda, &ipiv, &Bm, &ldb, &optWork, &lWork, &info)
                
                lWork = __CLPK_integer(optWork[0].r)
                var actualWork = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: Int(optWork[0].r))
                
                zsysv_(&uplo, &n, &nrhs, &Am, &lda, &ipiv, &Bm, &ldb, &actualWork, &lWork, &info)
                
                if (info != 0)
                {
                    DLog("Error in dsysv: \(info)")
                    
                    return nil
                }
                
                return PCH_Matrix(numRows: B.numRows, numCols: B.numCols, buffer: Bm, matrixType: B.matrixType)
            }
        }
        else if (self.matrixType == types.positiveDefinite)
        {
            if (self.matrixPrecision == precisions.doublePrecision)
            {
                // we need to create a full-sized buffer, the same as for symmetric matrices (see the note above)
                var Am = [__CLPK_doublereal](repeating: 0.0, count: self.numRows * self.numCols)
                
                    // Try using lower-triangular factorization to try and clear up the "leading minor of order i of A is not positive definite" errors that I've been getting in this routine. The LLt method is what is described in the Blue Book (pg 438).
                
                for row in 0..<self.numRows
                {
                    for col in 0...row
                    {
                        // we're only going to set the lower triangle (UPLO = 'L') of the buffer
                        Am[row * self.numCols + col] = self.doubleBuffer![row + col * (col + 1) / 2]
                    }
                }
                
                var fact:Int8 = 69 // 'E'
                var uplo:Int8 = 76 // 'L'
                var n = __CLPK_integer(self.numRows)
                var nrhs = __CLPK_integer(B.numCols)
                var lda = n
                var Bm = B.doubleBuffer!
                var ldb = n
                var info = __CLPK_integer(0)
                
                var AF = [__CLPK_doublereal](repeating: 0.0, count: self.numRows * self.numCols)
                var ldaf = n
                var equed:Int8 = 0
                var S = [__CLPK_doublereal](repeating: 0.0, count: self.numRows)
                
                var X = [__CLPK_doublereal](repeating: 0.0, count: self.numRows * B.numCols)
                var ldx = n
                
                var rcond:__CLPK_doublereal = 0.0
                
                var ferr = [__CLPK_doublereal](repeating: 0.0, count: B.numCols)
                var berr = [__CLPK_doublereal](repeating: 0.0, count: B.numCols)
                
                var work = [__CLPK_doublereal](repeating: 0.0, count: 3 * self.numRows)
                var iwork = [__CLPK_integer](repeating: __CLPK_integer(0), count: self.numRows)
                
                dposvx_(&fact, &uplo, &n, &nrhs, &Am, &lda, &AF, &ldaf, &equed, &S, &Bm, &ldb, &X, &ldx, &rcond, &ferr, &berr, &work, &iwork, &info)
                
                /*
                for col in 0..<self.numCols
                {
                    for row in 0...col
                    {
                        // we're only going to set the upper triangle (UPLO = 'U') of the buffer
                        Am[col * self.numRows + row] = self.doubleBuffer![row + col * (col + 1) / 2]
                    }
                }
                */
                /* Testing with TME job 016 is giving issues when increasing the number of subdivisions of the HV winding beyond 30 on the laptop and around 36 on the desktop machines. I am going to try a different LAPACK call, dposvx, which is supposed to "equilibrate" the system.
                
                var fact:Int8 = 69 // 'E'
                var uplo:Int8 = 85 // 'U'
                var n = __CLPK_integer(self.numRows)
                var nrhs = __CLPK_integer(B.numCols)
                var lda = n
                var Bm = B.doubleBuffer!
                var ldb = n
                var info = __CLPK_integer(0)
                
                var AF = [__CLPK_doublereal](repeating: 0.0, count: self.numRows * self.numCols)
                var ldaf = n
                var equed:Int8 = 0
                var S = [__CLPK_doublereal](repeating: 0.0, count: self.numRows)
                
                var X = [__CLPK_doublereal](repeating: 0.0, count: self.numRows * B.numCols)
                var ldx = n
                
                var rcond:__CLPK_doublereal = 0.0
                
                var ferr = [__CLPK_doublereal](repeating: 0.0, count: B.numCols)
                var berr = [__CLPK_doublereal](repeating: 0.0, count: B.numCols)
                
                var work = [__CLPK_doublereal](repeating: 0.0, count: 3 * self.numRows)
                var iwork = [__CLPK_integer](repeating: __CLPK_integer(0), count: self.numRows)
                
                dposvx_(&fact, &uplo, &n, &nrhs, &Am, &lda, &AF, &ldaf, &equed, &S, &Bm, &ldb, &X, &ldx, &rcond, &ferr, &berr, &work, &iwork, &info)
                */
                /* Simple dposv_ call, which fails with high number of disks and large differences between LV and HV winding inductances (ie: high ratio).
                
                var uplo:Int8 = 85
                var n = __CLPK_integer(self.numRows)
                var nrhs = __CLPK_integer(B.numCols)
                var lda = n
                var Bm = B.doubleBuffer!
                var ldb = n
                var info = __CLPK_integer(0)
                
                dposv_(&uplo, &n, &nrhs, &Am, &lda, &Bm, &ldb, &info)
                */
                
                if (info != 0)
                {
                    DLog("Error in dposvx: \(info)")
                    
                    return nil
                }
                
                
                return PCH_Matrix(numRows: B.numRows, numCols: B.numCols, buffer: X, matrixType: B.matrixType)
                
            }
            else
            {
                var Am = [__CLPK_doublecomplex](repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: self.numRows * self.numCols)
                
                for col in 0..<self.numCols
                {
                    for row in 0...col
                    {
                        // we're only going to set the upper triangle (UPLO = 'U') of the buffer
                        Am[col * self.numRows + row] = self.complexBuffer![row + col * (col + 1) / 2]
                    }
                }
                
                var uplo:Int8 = 85 // 'U'
                var n = __CLPK_integer(self.numRows)
                var nrhs = __CLPK_integer(B.numCols)
                var lda = n
                var Bm = B.complexBuffer!
                var ldb = n
                var info = __CLPK_integer(0)
                
                zposv_(&uplo, &n, &nrhs, &Am, &lda, &Bm, &ldb, &info)
                
                if (info != 0)
                {
                    DLog("Error in dposvx: \(info)")
                    
                    return nil
                }
                
                return PCH_Matrix(numRows: B.numRows, numCols: B.numCols, buffer: Bm, matrixType: B.matrixType)
            }
        }
        else
        {
            ALog("Function not implemented for this type of matrix!")
        }
        
        return nil
    }
/*
    func SaveAsCSV()
    {
        let saveFilePanel = NSSavePanel()
        
        saveFilePanel.title = "Save Matrix as CSV file"
        saveFilePanel.canCreateDirectories = true
        saveFilePanel.allowedFileTypes = ["csv"]
        saveFilePanel.allowsOtherFileTypes = false
        
        if (saveFilePanel.runModal().rawValue == NSFileHandlingPanelOKButton)
        {
            guard let newFileURL = saveFilePanel.url
                else
            {
                DLog("Bad file name")
                return
            }
            
            var result = ""
            
            for i in 0..<self.numRows
            {
                for j in 0..<self.numCols
                {
                    if (j == self.numCols - 1)
                    {
                        if (self.matrixPrecision == precisions.doublePrecision)
                        {
                            let value:Double = self[i,j]
                            result += "\(value)\n"
                        }
                        else
                        {
                            let value:Complex = self[i,j]
                            result += "\(value)\n"
                        }
                    }
                    else
                    {
                        if (self.matrixPrecision == precisions.doublePrecision)
                        {
                            let value:Double = self[i,j]
                            result += "\(value),"
                        }
                        else
                        {
                            let value:Complex = self[i,j]
                            result += "\(value),"
                        }
                    }
                }
            }
            
            do {
                try result.write(to: newFileURL, atomically: true, encoding: String.Encoding.utf8)
            }
            catch {
                ALog("Could not write file!")
            }
            
            DLog("Finished writing file")
        }
    }
 */
}
