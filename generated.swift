/*
Gen by SwiftFile...
=== ToC ===
1. requires_import (len 18)
2. requires
2.1. arraysafe (len 398)
2.2. safetensors_ndarrays (len 2185)
2.3. safetensors.shapeString (len 186)
2.4. SuccessOrFailure (len 203)
2.5. ext.FileManager.fileSize (len 321)
2.6. safetensors (len 11020)
2.7. xcode_safetensors (len 45)
3. emacs_auto_revert (len 103)

*/
//SECTION 1. requires_import
import Foundation
//SECTION 2. requires
//SECTION 2.1. arraysafe
/*
 file under ext.Collection.safe ?
 
 usage: A[safe:k]

 any performance issues with using .contains(index)
 vs having a version with a simple Int argument?
 
*/
extension Collection {

    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
}
//SECTION 2.2. safetensors_ndarrays
/*
 Utilities dealing with ndarrays.

 For, now simple swift types,
 [T], [[T]], ...

 'ndim'

 reshape2
 reshape3
 reshape4


 All take args: (fileHandle fh:FileHandle, shape: [Int], offset:UInt64)

 readArray_i32_d2(...) -> [[Int32]]?
 readArray_f64_d1(...) -> [Float64]?
*/

func reshape2<T>(_ array: [T], shape:[Int]) -> [[T]] {

    precondition(shape.count == 2,"Invalid shape")

    let rows = shape[0]
    let cols = shape[1]
    
    precondition(array.count == rows * cols, "Invalid dimensions")
    
    // or:
    //  guard array.count == rows * cols else { return nil }

    return (0..<rows).map { row in
        let start = row * cols
        let end = start + cols
        return Array(array[start..<end])
    }
    
}

/*
 
 read array of N,
 Int32LE
 C64: real f32l, imag f32l
 
*/
extension FileHandle {

    //func readArrayInt32LE(count:Int)
    
}



/*
 */
func readArray_i32_d2(fileHandle fh:FileHandle, shape: [Int], offset:UInt64) -> [[Int32]]? {

    if shape.count != 2 { return nil }

    let bytesPerElement:Int = 4

    let prod = shape.product()

    do {
        try fh.seek(toOffset:offset)
    } catch { return nil }

    let byteCount:Int = prod * bytesPerElement

    guard let data = try? fh.read(upToCount:byteCount) else {
        return nil
    }
    if data.count != byteCount {return nil}

    let flatArray: [Int32] = data.withUnsafeBytes { rawBuffer in
        let buffer = rawBuffer.bindMemory(to: Int32.self)
        return Array(buffer)
    }

    return reshape2(flatArray, shape:shape)
}

func readArray_f64_d1(
  fileHandle fh:FileHandle,
  shape: [Int],
  offset:UInt64) -> [Float64]? {

    if shape.count != 1 { return nil }

    let bytesPerElement:Int = 8

    let prod = shape.product()

    do {
        try fh.seek(toOffset:offset)
    } catch { return nil }

    let byteCount:Int = prod * bytesPerElement

    guard let data = try? fh.read(upToCount:byteCount) else {
        return nil
    }
    if data.count != byteCount {return nil}

    let flatArray: [Float64] = data.withUnsafeBytes { rawBuffer in
        let buffer = rawBuffer.bindMemory(to: Float64.self)
        return Array(buffer)
    }

    return flatArray
}
//SECTION 2.3. safetensors.shapeString
/*
 
 */
func shapeString(_ shape:[Int]) -> String {

    //option: add space...
    
    let commasep = (shape.map {String($0)}).joined(separator:",")
    return "[" + commasep + "]"
}
//SECTION 2.4. SuccessOrFailure
/*
 should use this instead of returning Bool

 why? because returning Bool is ambiguous and hard
 to remember if true=success or failure.
 */
enum SuccessOrFailure {
    case success
    case failure
}
//SECTION 2.5. ext.FileManager.fileSize

/*
 
 */
extension FileManager {

    func fileSize(atPath path:String) -> UInt64? {

        let attr:[FileAttributeKey : Any]
        do {
            attr = try FileManager.default.attributesOfItem(atPath:path)
        }
        catch {
            return nil
        }

        return attr[.size] as? UInt64
    }
}
//SECTION 2.6. safetensors
/*

 */

//requires_import:Foundation
//requires:safetensors_ndarrays
//requires:safetensors.shapeString


/*
 move.
 convert optional numeric values to String()
 */
extension Optional where Wrapped: CustomStringConvertible {
    func string(or defaultValue: String) -> String {
        return self.map { $0.description } ?? defaultValue
    }
}

/*
 */
//requires:SuccessOrFailure
extension FileHandle {
    //func seek(toOffset offset: UInt64) throws

    //name?
    func seek2(toOffset offset: UInt64) -> SuccessOrFailure {
        do {
            try self.seek(toOffset:offset)
            return .success
        }
        catch {
            return .failure
        }
    }

    /*
     convert .seek() to a Result
     */
    func seekResult(to offset: UInt64) -> Result<Void, Error> {
        Result {
            try self.seek(toOffset: offset)
        }
    }
    
}




/*
 should be generated...
 */
enum STDtype {
    case I32
    case U16

    //?
    //unknown(String)
}

/*
 */
struct STSummary {
    var fileSize:UInt64?
    var headerSize:UInt64?
    var tensorCount:Int
    var dtypes:Dictionary<String,Int>
}




/*

 Helper for counters.
 
 */
extension Dictionary where Value: Comparable {
    func sortedByValueAscending() -> [(key: Key, value: Value)] {
        sorted { $0.value < $1.value }
    }

    func sortedByValueDescending() -> [(key: Key, value: Value)] {
        sorted { $0.value > $1.value }
    }
    
}




extension STSummary {

    init(stfile:STFile) {

        var counts: [String: Int] = [:]
        for tensor in stfile.tensors {
            counts[tensor.dtype, default: 0] += 1
        }

        self.fileSize    = stfile.fileSize
        self.headerSize  = stfile.headerSize
        self.tensorCount = stfile.tensors.count
        self.dtypes      = counts
    }

    /*
     human-readable string.
     */
    func toString() -> String {

        var tt:[String] = []

        tt.append(contentsOf:[

                    "fileSize:  ",
                    fileSize.string(or:"-"),
                    "\n",
                    
                    "headerSize: ",
                    headerSize.string(or:"-"),
                    "\n",

                    "tensorCount: ", String(tensorCount), "\n",

                    "dtypes:\n",
                  ])
        for pair in dtypes.sortedByValueDescending() {
            tt.append("  ")
            tt.append(pair.key)
            tt.append(" : ")
            tt.append(String(pair.value))
            tt.append("\n")
        }

        return tt.joined(separator:"")
        
    }
    
}



extension STDtype {
    
    func bytesPerValue() -> Int {
        switch self {
        case .I32: return 4
        case .U16: return 2
        }
    }
    
}

//enum STDtype {
//    case 
//}



/*
 */
extension Sequence where Element == Int {
    func product() -> Int {
        reduce(1, *)
    }
}


/*
 */
extension FileHandle {

    func u64l() -> UInt64? {

        guard let sizeBytes = try? self.read(upToCount:8) else {
            //return .error
            return nil
        }

        let headerSize = sizeBytes.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 0,
                             as: UInt64.self).littleEndian
        }

        return headerSize
    }
    
}


/*


 should we use mmap?
    guard let mapped = try? Data(contentsOf:url, options: .mappedIfSafe) else {
        return .error
        }
 
 
 
 */

//requires:ext.FileManager.fileSize

struct STFileHeaderResult {
    var metadata:Any?
    var tensors:[STTensor]
}

extension STFileHeaderResult {

    /*
     error messages?
     */
    static func fromData(_ data:Data) -> STFileHeaderResult? {

        guard let json:Any = try? JSONSerialization.jsonObject(
                with:data, options:[
                             //?
                           ]) else {
            return nil
        }
            
        guard let d = json as? Dictionary<String,Any> else {
            return nil
        }

        var tensors:[STTensor] = []
        var metadata:Any? = nil

        for keyval in d {

            if keyval.key == STFile.NAME_METADATA {
                metadata = keyval.value
            }
            else {
                guard let tensor = STTensor.fromJSONAny(
                        name  : keyval.key,
                        value : keyval.value) else {
                    print("error.")
                    return nil
                }
                tensors.append(tensor)
            }
        }

        return STFileHeaderResult(
          metadata: metadata,
          tensors:  tensors
        )

    }
    
}



/*
 We can load from,
 - .safetensors
 - .json

 
 headerOnly=True
 - from .json

 

 What about sharded?
 
*/
struct STFile {

    //-- file-format constants --
    static let NAME_METADATA = "__metadata__"

    //////
    
    var path:String
    
    var fileHandle:FileHandle?
    var fileSize:UInt64?
    var headerSize:UInt64?
    
    var tensors:[STTensor] = []

    var headerOnly:Bool

    /*
     Any: an JSON data.
     */
    var metadata:Any? = nil

    init?(path:String) {
        self.path = path

        // optional:
        self.fileSize = FileManager.default.fileSize(atPath:path)

        let url = URL(fileURLWithPath:path)

        if url.path.lowercased().hasSuffix(".json") {
            guard let d = try? Data(contentsOf:url) else {return nil}
            guard let r = STFileHeaderResult.fromData(d) else {return nil}

            self.metadata   = r.metadata
            self.tensors    = r.tensors
            self.fileHandle = nil
            self.headerOnly = true
            self.headerSize = nil            
        }
        else {
            guard let fh = try? FileHandle(forReadingFrom: url) else {return nil}
            //defer { try? fh.close() }

            guard let headerSize = fh.u64l() else {return nil}
            

            guard let jsonBytes = try? fh.read(upToCount: Int(headerSize)) else {return nil}

            guard let r = STFileHeaderResult.fromData(jsonBytes) else {return nil}
                
            self.metadata   = r.metadata
            self.tensors    = r.tensors
            self.fileHandle = fh
            self.headerOnly = false
            self.headerSize = headerSize
        }
        
    }
    
        
    /*
     todo: build index.
     */
    func tensor(forName name:String) -> STTensor? {
        for t in tensors {
            if t.name == name {
                return t
            }
        }
        return nil
    }

    /*
     */
    func close() {
        //print("[in close()]")
        if let fh = fileHandle {
            //print("Closing...")
            try? fh.close() //can throw?
        }
        
    }
    
}


/*

 - check/limit 'dtype'?
 - allow for extra keys?
 
 */
struct STTensor {

    //should we make these case-insensative?
    static let KEY_DTYPE        = "dtype"
    static let KEY_SHAPE        = "shape"
    static let KEY_DATA_OFFSETS = "data_offsets"

    var name:String
    var dtype:String //choices:...
    var shape:[Int]  //limits on int.

    /*
     use Int? fileHandle uses UInt64 offsets.
     */
    var dataOffsetStart:Int
    var dataOffsetEnd  :Int
}

/*
 */
extension STTensor {

    /*
     todo: return error message.
     */
    static func fromJSONAny(name:String, value:Any) -> STTensor? {
        guard let d = value as? Dictionary<String,Any> else {
            print("Error: non-dict")
            return nil
        }
        guard let dtype = d[Self.KEY_DTYPE] as? String else {
            print("Error: bad dtype")
            return nil
        }
        guard let shape = d[Self.KEY_SHAPE] as? [Int] else {
            print("Error: bad shape")
            return nil
        }
        //check shape?

        guard let data_offsets = d[Self.KEY_DATA_OFFSETS] as? [Int] else {
            print("Error: bad data_offsets")
            return nil
        }
        if data_offsets.count < 2 {
            print("Error: wrong data_offsets size")
            return nil
        }

        return STTensor(
          name:  name,
          dtype: dtype,
          shape: shape,
          dataOffsetStart : data_offsets[0],
          dataOffsetEnd   : data_offsets[1]
        )
        
    }

    /*
     */
    func toJSON() -> Any {

        var out:Dictionary<String,Any> = [:]

        out[Self.KEY_DTYPE] = self.dtype
        out[Self.KEY_SHAPE] = self.shape
        out[Self.KEY_DATA_OFFSETS] = [
          self.dataOffsetStart,
          self.dataOffsetEnd
        ]

        return out
    }

    /*
     returning {} on error, because errors shouldn't occur.
     */
    func toJSONString() -> String {

        let obj = self.toJSON()

        guard let data = try? JSONSerialization.data(
                withJSONObject: obj,
                options: [.fragmentsAllowed]) else {return "{}"}//
    
        //note: this is optional, but shouldn't fail.
        return String(data:data, encoding:.utf8) ?? "{}"
    }
    
}


/*
 helper
 */
func JSONAscii(_ object:Any) -> String? {

    guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.fragmentsAllowed]) else {return nil}
    
    //note: this is optional, but shouldn't fail.
    return String(data:data, encoding:.ascii)
    
}



extension STFile {

    /*
     if headerSize is nil, just use 0. We shouldn't be calling this method in that cse.
     */
    func offset(forTensor tensor:STTensor) -> UInt64 {
        return offset(forOffset:tensor.dataOffsetStart)
    }
    func offset(forOffset offset:Int) -> UInt64 {
        return (self.headerSize ?? 0) + UInt64(8 + offset)
    }
    

    /*

     dispatch to functions:
     - readArray_i32_d2
     - readArray_f64_d1
     ...

     How to make generic?
     - iterator for each dtype
     --- yields [str]
     --- each value as a (json) str.
     
     */
    func readArrayAsJSON(tensor:STTensor) -> String? {

        guard let fh = self.fileHandle else {return nil}

        let offset:UInt64 = offset(forTensor:tensor)

//        switch tensor.dtype {
//        case "I32":
//        }

        let ndim = tensor.shape.count

        if ndim == 2 {
            if tensor.dtype != "I32" {return nil}
            
            guard let arr = readArray_i32_d2(fileHandle:fh,
                                             shape:  tensor.shape,
                                             offset: offset) else {
                return nil
            }
            return JSONAscii(arr)
            
        }
        else if ndim == 1 {
            
            if tensor.dtype != "F64" {return nil}

            guard let arr = readArray_f64_d1(fileHandle:fh, shape:tensor.shape, offset: offset) else {
                return nil
            }
            return JSONAscii(arr)
            
        }
        
        else {
            print("Error: unhandled ndim: \(ndim)")
            return nil
        }

    }
    
}



//SECTION 2.7. xcode_safetensors

//requires:arraysafe
//requires:safetensors
//SECTION 3. emacs_auto_revert
// For Emacs:
// - auto-revert-mode: ...
// 
// Local Variables:
//   eval: (auto-revert-mode)
// End:
