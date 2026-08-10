/*
* Copyright (c) 2020, Nordic Semiconductor
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without modification,
* are permitted provided that the following conditions are met:
*
* 1. Redistributions of source code must retain the above copyright notice, this
*    list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice, this
*    list of conditions and the following disclaimer in the documentation and/or
*    other materials provided with the distribution.
*
* 3. Neither the name of the copyright holder nor the names of its contributors may
*    be used to endorse or promote products derived from this software without
*    specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
* IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
* INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
* NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
* WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
* ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
* POSSIBILITY OF SUCH DAMAGE.
*/



import Foundation

struct Nibble {
    var first  : UInt8
    var second : UInt8
}

enum ReservedSFloatValues : Int16 {
    case positiveInfinity = 0x07FE
    case nan = 0x07FF
    case nres = 0x0800
    case reserved = 0x0801
    case negativeInfinity = 0x0802
    
    static let firstReservedValue = ReservedSFloatValues.positiveInfinity
}

extension Double {
    static var reservedValues: [Double] {
        [.infinity, .nan, .nan, .nan, -.infinity]
    }
}

struct CharacteristicReader {

    static func readUInt8Value(ptr aPointer : inout UnsafeMutablePointer<UInt8>) -> UInt8 {
        let val = aPointer.pointee
        aPointer = aPointer.successor()
        return val
    }
    
    static func readSInt8Value(ptr aPointer : UnsafeMutablePointer<UInt8>) -> Int8 {
        Int8(aPointer.successor().pointee)
    }

    static func readUInt16Value(ptr aPointer : inout UnsafeMutablePointer<UInt8>) -> UInt16 {
        let anUInt16Pointer = UnsafeMutablePointer<UInt16>(OpaquePointer(aPointer))
        let val = CFSwapInt16LittleToHost(anUInt16Pointer.pointee)
        aPointer = aPointer.advanced(by: 2)
        return val
    }
    
    static func readSInt16Value(ptr aPointer : inout UnsafeMutablePointer<UInt8>) -> Int16 {
        let anInt16Pointer = UnsafeMutablePointer<Int16>(OpaquePointer(aPointer))
        let val = CFSwapInt16LittleToHost(UnsafeMutablePointer<UInt16>(OpaquePointer(anInt16Pointer)).pointee)
        aPointer = aPointer.advanced(by: 2)
        return Int16(val)
    }
    
    static func readUInt32Value(ptr aPointer : inout UnsafeMutablePointer<UInt8>) -> UInt32 {
        let anInt32Pointer = UnsafeMutablePointer<UInt32>(OpaquePointer(aPointer))
        let val = CFSwapInt32LittleToHost(UnsafeMutablePointer<UInt32>(OpaquePointer(anInt32Pointer)).pointee)
        aPointer = aPointer.advanced(by: 4)
        return UInt32(val)
    }
    
    static func readSInt32Value(ptr aPointer : inout UnsafeMutablePointer<UInt8>) -> Int32 {
        let anInt32Pointer = UnsafeMutablePointer<UInt32>(OpaquePointer(aPointer))
        let val  = CFSwapInt32LittleToHost(UnsafeMutablePointer<UInt32>(OpaquePointer(anInt32Pointer)).pointee)
        aPointer = aPointer.advanced(by: 4)
        return Int32(val)
    }
    
    static func readSFloat(_ data: Data, offset: Int) throws -> Float32 {
        let tempData: UInt16 = try data.read(fromOffset: offset)
        var mantissa = Int16(tempData & 0x0FFF)
        var exponent = Int8(tempData >> 12)
        if exponent >= 0x0008 {
            exponent = -( (0x000F + 1) - exponent )
        }
        
        var output : Float32 = 0
        
        if mantissa >= ReservedSFloatValues.firstReservedValue.rawValue && mantissa <= ReservedSFloatValues.negativeInfinity.rawValue {
            output = Float32(Double.reservedValues[Int(mantissa - ReservedSFloatValues.firstReservedValue.rawValue)])
        } else {
            if mantissa > 0x0800 {
                mantissa = -((0x0FFF + 1) - mantissa)
            }
            let magnitude = pow(10.0, Double(exponent))
            output = Float32(mantissa) * Float32(magnitude)
        }
        
        return output
    }
    
    static func readSFloatValue(ptr aPointer : inout UnsafeMutablePointer<UInt8>) -> Float32 {
        let tempData = CFSwapInt16LittleToHost(UnsafeMutablePointer<UInt16>(OpaquePointer(aPointer)).pointee)
        var mantissa = Int16(tempData & 0x0FFF)
        var exponent = Int8(tempData >> 12)
        if exponent >= 0x0008 {
            exponent = -((0x000F + 1) - exponent)
        }

        var output : Float32 = 0
        
        if mantissa >= ReservedSFloatValues.firstReservedValue.rawValue && mantissa <= ReservedSFloatValues.negativeInfinity.rawValue {
            output = Float32(Double.reservedValues[Int(mantissa - ReservedSFloatValues.firstReservedValue.rawValue)])
        } else {
            if mantissa > 0x0800 {
                mantissa = -((0x0FFF + 1) - mantissa)
            }
            let magnitude = pow(10.0, Double(exponent))
            output = Float32(mantissa) * Float32(magnitude)
        }
        aPointer = aPointer.advanced(by: 2)
        
        return output
    }
    
    private static let twelveHourDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy MM dd HH mm ss a"
        return formatter
    }()

    private static let twentyFourHourDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy MM dd HH mm ss"
        return formatter
    }()

    static func readDateTime(ptr aPointer : inout UnsafeMutablePointer<UInt8>) -> Date {
        let year  = CharacteristicReader.readUInt16Value(ptr: &aPointer)
        let month = CharacteristicReader.readUInt8Value(ptr: &aPointer)
        let day   = CharacteristicReader.readUInt8Value(ptr: &aPointer)
        var hour  = CharacteristicReader.readUInt8Value(ptr: &aPointer)
        let min   = CharacteristicReader.readUInt8Value(ptr: &aPointer)
        let sec   = CharacteristicReader.readUInt8Value(ptr: &aPointer)

        let dateFormatter: DateFormatter
        var dateString : String
        if using12hClockFormat()  == true {
            var merediumString :String = "am"
            if (hour > 12) {
                hour = hour - 12;
                merediumString = "pm"
            }
            dateString = String(format: "%d %d %d %d %d %d %@", year, month, day, hour, min, sec, merediumString)
            dateFormatter = twelveHourDateFormatter
        }else{
            dateString = String(format: "%d %d %d %d %d %d", year, month, day, hour, min, sec)
            dateFormatter = twentyFourHourDateFormatter
        }
        return dateFormatter.date(from: dateString)!
    }

    static func readNibble(ptr aPointer : inout UnsafeMutablePointer<UInt8>) -> Nibble {
        let value = CharacteristicReader.readUInt8Value(ptr: &aPointer)
        let nibble = Nibble(first: value & 0xF, second: value >> 4)
        return nibble
    }

    private static let clockFormatCacheLock = NSLock()
    private static var clockFormatCache: (localeIdentifier: String, isTwelveHour: Bool)?

    static func using12hClockFormat() -> Bool {
        let locale = Locale.current

        clockFormatCacheLock.lock()
        let cached = clockFormatCache
        clockFormatCacheLock.unlock()

        if let cached, cached.localeIdentifier == locale.identifier {
            return cached.isTwelveHour
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let dateString = formatter.string(from: Date())
        let amRange = dateString.range(of: formatter.amSymbol)
        let pmRange = dateString.range(of: formatter.pmSymbol)

        let isTwelveHour = !(pmRange == nil && amRange == nil)

        clockFormatCacheLock.lock()
        clockFormatCache = (locale.identifier, isTwelveHour)
        clockFormatCacheLock.unlock()

        return isTwelveHour
    }
}
