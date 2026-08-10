//
//  CGMSMeasurement.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 2/4/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

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
import iOS_Common_Libraries

// MARK: - CGMSMeasurement

struct CGMSMeasurement {
    
    // MARK: Properties
    
    let measurement: Measurement<UnitConcentrationMass>
    let timeOffset: Int
    let date: Date
    
    let sensorStatus: BitField<CGMSSensorStatusOctet>?
    let calTempStatus: BitField<CGMSCalTempOctet>?
    let warningStatus: BitField<CGMSWarningOctet>?
    
    let trend: Measurement<UnitGlucoseTrend>?
    let quality: Float?
    let crc: UInt16?
    
    let size: Int
    let measuredSize: Int
    
    let calculatedCrc: UInt16?

    // MARK: init
    
    init(data: Data, sessionStartTime: Date) throws {
        let reader = DataReader(data: data)
        
        size = try reader.read(UInt8.self)
        
        let featureFlags = UInt(try reader.read(UInt8.self))
        let flags = BitField<Flags>(featureFlags)
        
        measurement = Measurement<UnitConcentrationMass>(value: try reader.read(), unit: .milligramsPerDeciliter)
        
        timeOffset = try reader.read(UInt16.self)
        date = sessionStartTime.addingTimeInterval(TimeInterval(timeOffset * 60))
        
        sensorStatus = flags.contains(.statusPresent) ? BitField(RegisterValue(try reader.read(UInt8.self))) : nil
        calTempStatus = flags.contains(.calTempPresent) ? BitField(RegisterValue(try reader.read(UInt8.self))) : nil
        warningStatus = flags.contains(.warningPresent) ? BitField(RegisterValue(try reader.read(UInt8.self))) : nil
        
        trend = flags.contains(.trendPresent) ? Measurement<UnitGlucoseTrend>(value: try reader.read(), unit: .milligramsPerDecilitrePerMinute) : nil
        quality = flags.contains(.qualityPresent) ? try reader.read() : nil
        
        let offset = reader.size()
        crc = offset + MemoryLayout<UInt16>.size <= size && reader.hasData(UInt16.self) ? try reader.read() : nil
        calculatedCrc = CRC16.mcrf4xx(data: data, offset: 0, length: offset)
        
        measuredSize = reader.size()
    }
    
    // MARK: API
    
    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.setLocalizedDateFormatFromTemplate("E d MMM yyyy HH:mm:ss")
        return dateFormatter
    }()

    func toStringDate() -> String {
        return Self.dateFormatter.string(from: date)
    }
    
    func isCrcValid() -> Bool? {
        guard let crc, let calculatedCrc else { return nil }
        return crc == calculatedCrc
    }
}

// MARK: - CustomStringConvertible

extension CGMSMeasurement: CustomStringConvertible {
    
    var description: String {
        return measurement.formatted()
    }
}

extension CGMSMeasurement {
    
    enum Flags: RegisterValue, Option, CaseIterable {
        
        case trendPresent, qualityPresent
        case reserved2, reserved3, reserved4
        case warningPresent, calTempPresent, statusPresent
    }
}
