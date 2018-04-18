//
//  SparseMatrix.swift
//  PCH_SparseMatrix
//
//  Created by PeterCoolAssHuber on 2018-04-14.
//  Copyright © 2018 Peter Huber. All rights reserved.
//

// This is a class to make it easier to work with Apple's sparse matrix routines. The reason for taking this on is that Apple does not offer Complex precision, which we need for a number of programs. Also, the Apple routines for creating a memory structure for Sparse matrices assumes that the entries in the matrix are already known. Our strategy here is one we've used before where we store the numbers in a dictionary where the keys are instances of a special index struct and the values are the Complex values (duh). We will use the Complex Matrix Theory that we developed some time ago where any complex number is converted into a 2x2 matrix with the real number repeated on the diagonal, the negative of the imaginary part on the first row and the unmodified impaginary part on the second row.

// Note: All row and column indices are 0-based

// Note: The routines that create Apple-defined matrices and structs should have the data fields deallocated IN THE CALLING ROUTINE after finishing working with them.

import Foundation
import Accelerate

class PCH_SparseMatrix:CustomStringConvertible
{
    // We support two data types of sparse matrices, Double and Complex
    enum DataType {
        case double
        case complex
    }
    
    let type:DataType
    
    // routines will return some form of this error in the event of a problem
    let SPARSE_MATRIX_ERROR = Double.greatestFiniteMagnitude
    
    // This is the number of rows and cols in the "virtual" Complex matrix (which does not really exist, since we actually store each complex as a 2x2 matrix)
    let rows:Int
    let cols:Int
    
    /// A simple description function to display matrices with 'print' (the output is quite ugly and not nicely formatted)
    var description:String
    {
        var result = ""
        
        for i in 0..<self.rows
        {
            result += "\n| "
            
            for j in 0..<self.cols
            {
                if (j == self.cols - 1)
                {
                    if self.type == .complex
                    {
                        let value:Complex = self[i,j]
                        result += "\(value) |"
                    }
                    else
                    {
                        let value:Double = self[i,j]
                        result += "\(value) |"
                    }
                }
                else
                {
                    if self.type == .complex
                    {
                        let value:Complex = self[i,j]
                        result += "\(value)   "
                    }
                    else
                    {
                        let value:Double = self[i,j]
                        result += "\(value)   "
                    }
                }
            }
        }
        
        return result
    }
    
    struct SparseKey:Hashable
    {
        let row:Int
        let col:Int
        
        // Standard hash function
        var hashValue: Int
        {
            return self.row.hashValue ^ self.col.hashValue &* 16777619
        }
        
        static func == (lhs:SparseKey, rhs:SparseKey) -> Bool
        {
            if lhs.row == rhs.row && lhs.col == rhs.col
            {
                return true
            }
            
            return false
        }
    }
    
    // We actually store doubles (even for Complex types) to make life easier
    var matrix:[SparseKey:Double] = [:]
    
    // subscript for Double matrices
    subscript(row: Int, column: Int) -> Double
    {
        get
        {
            if self.type != .double
            {
                ALog("Illegal matrix type for value (should be Double")
                return SPARSE_MATRIX_ERROR
            }
            
            if row >= self.rows || column >= self.cols
            {
                ALog("Illegal index")
                return SPARSE_MATRIX_ERROR
            }
            
            let key = SparseKey(row: row, col: column)
            
            if let result = self.matrix[key]
            {
                return result
            }
            else
            {
                return 0.0
            }
        }
        set
        {
            var theValue = newValue
            if self.type != .double
            {
                ALog("Illegal matrix type for value (should be Double")
                theValue = SPARSE_MATRIX_ERROR
            }
            
            if row >= self.rows || column >= self.cols
            {
                ALog("Illegal index")
            }
            
            let key = SparseKey(row: row, col: column)
            
            if fabs(theValue) < 1.0E-14
            {
                self.matrix.removeValue(forKey: key)
            }
            else
            {
                self.matrix[key] = theValue
            }
            
        }
    }
    
    // subscript for Complex matrices
    subscript(row: Int, column: Int) -> Complex
    {
        get
        {
            if self.type != .complex
            {
                ALog("Illegal matrix type for value (should be Complex")
                return Complex.ComplexNan
            }
            
            if row >= self.rows || column >= self.cols
            {
                ALog("Illegal index")
                return Complex.ComplexNan
            }
            
            let realKey = SparseKey(row: row * 2, col: column * 2)
            let imagKey = SparseKey(row: row * 2, col: column * 2 + 1)
            
            if let realResult = self.matrix[realKey]
            {
                if let imagResult = self.matrix[imagKey]
                {
                    return Complex(real: realResult, imag: -imagResult)
                }
                else
                {
                    return Complex(real: realResult)
                }
            }
            else if let imagResult = self.matrix[imagKey]
            {
                return Complex(real: 0.0, imag: -imagResult)
            }
            else
            {
                return Complex(real:0.0)
            }
        }
        set
        {
            var theValue = newValue
            if self.type != .complex
            {
                ALog("Illegal matrix type for value (should be Double")
                theValue = Complex.ComplexNan
            }
            
            if row >= self.rows || column >= self.cols
            {
                ALog("Illegal index")
            }
            
            let realKey1 = SparseKey(row: row * 2, col: column * 2)
            let realKey2 = SparseKey(row: row * 2 + 1, col: column * 2 + 1)
            let imagKey1 = SparseKey(row: row * 2, col: column * 2 + 1) // negative imaginary term
            let imagKey2 = SparseKey(row: row * 2 + 1, col: column * 2)
            
            if fabs(theValue.real) < 1.0E-12
            {
                self.matrix.removeValue(forKey: realKey1)
                self.matrix.removeValue(forKey: realKey2)
            }
            else
            {
                self.matrix[realKey1] = newValue.real
                self.matrix[realKey2] = newValue.real
            }
            
            if fabs(theValue.imag) < 1.0E-12
            {
                self.matrix.removeValue(forKey: imagKey1)
                self.matrix.removeValue(forKey: imagKey2)
            }
            else
            {
                self.matrix[imagKey1] = -newValue.imag
                self.matrix[imagKey2] = newValue.imag
            }
        }
    }
    
    
    // Designated initializer
    // Call with the number of Complex rows and columns (ie: don't multiply them by 2)
    init(type:DataType, rows:Int, cols:Int)
    {
        self.type = type
        self.rows = rows
        self.cols = cols
    }
    
    func CreateSparseMatrix() -> SparseMatrix_Double
    {
        var typeMultiplier = 1
        if self.type == .complex
        {
            typeMultiplier = 2
        }
        
        // Debug (slow) checking
        #if DEBUG
        
            var columnCheck:[Bool] = Array(repeating: false, count: self.cols * typeMultiplier)
        
            for (key, _) in self.matrix
            {
                columnCheck[key.col] = true
            }
        
            if columnCheck.contains(false)
            {
                ALog("Illegal blank column in matrix!")
            }
        
        #endif
        
        // var rowIndices:[Int32] = Array(repeating: -1, count: self.matrix.count)
        let rowIndices = UnsafeMutablePointer<Int32>.allocate(capacity: self.matrix.count)
        rowIndices.initialize(repeating: -1, count: self.matrix.count)
        
        // var values:[Double] = Array(repeating: Double.greatestFiniteMagnitude, count: self.matrix.count)
        let values = UnsafeMutablePointer<Double>.allocate(capacity: self.matrix.count)
        values.initialize(repeating:0.0, count: self.matrix.count)
        
        // var columnStarts:[Int] = Array(repeating: -1, count: self.cols * typeMultiplier + 1)
        let columnStarts = UnsafeMutablePointer<Int>.allocate(capacity: self.cols * typeMultiplier + 1)
        columnStarts.initialize(repeating: 0, count: self.cols * typeMultiplier + 1)
        
        // Faster (I hope) method of setting up the fields.
        
        // First we sort the matrix Dictionary. I don't know how slow this call is.
        let sortedMatrix = self.matrix.sorted {(aDic, bDic) -> Bool in
            
            let aCol = aDic.key.col
            let aRow = aDic.key.row
            let bCol = bDic.key.col
            let bRow = bDic.key.row
            
            if aCol == bCol
            {
                return aRow < bRow
            }
            
            return aCol < bCol
        }
        
        var valuesPerColumn:[Int] = Array(repeating: 0, count: self.cols * typeMultiplier)
        var rowIndex = 0
        for (key, value) in sortedMatrix
        {
            rowIndices[rowIndex] = Int32(key.row)
            values[rowIndex] = value
            rowIndex += 1
            valuesPerColumn[key.col] += 1
        }
        
        for i in 0..<valuesPerColumn.count
        {
            columnStarts[i + 1] = columnStarts[i] + valuesPerColumn[i]
        }
        
        // Do some slow checking in DEBUG builds only
        #if DEBUG
        
            for i in 0..<self.matrix.count
            {
                if rowIndices[i] < 0
                {
                    ALog("Illegal value in 'rowIndices'")
                }
                
                if values[i] == Double.greatestFiniteMagnitude
                {
                    ALog("Illegal value in 'values'")
                }
            }
        
            for i in 1...self.cols * typeMultiplier
            {
                if columnStarts[i] == 0
                {
                    ALog("Illegal value in 'columnStarts'")
                }
            }
        
        #endif
        
        let sparseStruct = SparseMatrixStructure(rowCount: Int32(self.rows * typeMultiplier), columnCount: Int32(self.cols * typeMultiplier), columnStarts: columnStarts, rowIndices: rowIndices, attributes: SparseAttributes_t(), blockSize: 1)
        
        let result = SparseMatrix_Double(structure: sparseStruct, data: values)
        
        return result
    }
    
    static func CreateEmptyMatrixForComplexVector(count:Int) -> DenseMatrix_Double
    {
        let ptr = UnsafeMutablePointer<Double>.allocate(capacity: count * 4)
        ptr.initialize(repeating: 0.0, count: count * 4)
        
        let result = DenseMatrix_Double(rowCount: Int32(count * 2), columnCount: 2, columnStride: Int32(count * 2), attributes: SparseAttributes_t(), data: ptr)
        
        return result
    }
    
    static func CreateEmptyVectorForDoubleVector(count:Int) -> DenseVector_Double
    {
        let ptr = UnsafeMutablePointer<Double>.allocate(capacity: count)
        ptr.initialize(repeating: 0.0, count: count)
        
        let result = DenseVector_Double(count: Int32(count), data: ptr)
        
        return result
    }
    
    static func CreateDenseVectorForDoubleVector(values:[Double]) -> DenseVector_Double
    {
        let rowCount = values.count
        let data = UnsafeMutablePointer<Double>.allocate(capacity: rowCount)
        
        var i = 0
        for nextValue in values
        {
            data[i] = nextValue
            i += 1
        }
        
        let result = DenseVector_Double(count: Int32(rowCount), data: data)
        
        return result
    }
    
    static func CreateDenseMatrixForComplexVector(values:[Complex]) -> DenseMatrix_Double
    {
        let rowCount = values.count
        let data = UnsafeMutablePointer<Double>.allocate(capacity: rowCount * 4)
        let columnStride = rowCount * 2
        
        var i = 0
        for nextValue in values
        {
            data[i] = nextValue.real
            data[i + 1] = nextValue.imag
            data[i + columnStride] = -nextValue.imag
            data[i + 1 + columnStride] = nextValue.real
            
            i += 2
        }
        
        // For our purposes, the stride is usually defined as the number of ROWS of Doubles 
        let result = DenseMatrix_Double(rowCount: Int32(rowCount * 2), columnCount: 2, columnStride: Int32(columnStride), attributes: SparseAttributes_t(), data: data)
        
        return result
    }
}


