//
//  NordicLogoAnimationTypes.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 28/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

extension NordicLogoAnimation {
    
    enum Curve {
        case fastOutSlowIn
        case decelerate
        
        func value(_ x: Double) -> Double {
            switch self {
            case .decelerate:
                return 1 - (1 - x) * (1 - x)
            case .fastOutSlowIn:
                return Self.bezier(x, x1: 0.4, y1: 0, x2: 0.2, y2: 1)
            }
        }
        
        private static func bezier(_ x: Double, x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
            func component(_ t: Double, _ a: Double, _ b: Double) -> Double {
                let u = 1 - t
                return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
            }
            var low = 0.0
            var high = 1.0
            var t = x
            for _ in 0..<24 {
                t = (low + high) / 2
                if component(t, x1, x2) < x {
                    low = t
                } else {
                    high = t
                }
            }
            return component(t, y1, y2)
        }
    }
    
    struct Animation {
        let start: TimeInterval
        let duration: TimeInterval
        let from: Double
        let to: Double
        let curve: Curve
        
        init(start: Double, duration: Double, from: Double, to: Double, curve: Curve) {
            self.start = start / 1000
            self.duration = duration / 1000
            self.from = from
            self.to = to
            self.curve = curve
        }
        
        static func value(_ animations: [Animation], at time: TimeInterval, default initial: Double) -> Double {
            guard let current = animations.last(where: { time >= $0.start }) else { return initial }
            let progress = min(max((time - current.start) / current.duration, 0), 1)
            return current.from + (current.to - current.from) * current.curve.value(progress)
        }
    }
    
    struct Group {
        let pivotX: Double
        let pivotY: Double
        let translateX: Double
        let translateY: Double
        let translateXAnimations: [Animation]
        let translateYAnimations: [Animation]
        let scaleXAnimations: [Animation]
        let scaleYAnimations: [Animation]
        let rotationAnimations: [Animation]
        
        func transform(at time: TimeInterval) -> CGAffineTransform {
            let tx = Animation.value(translateXAnimations, at: time, default: translateX)
            let ty = Animation.value(translateYAnimations, at: time, default: translateY)
            let sx = Animation.value(scaleXAnimations, at: time, default: 1)
            let sy = Animation.value(scaleYAnimations, at: time, default: 1)
            let rotation = Animation.value(rotationAnimations, at: time, default: 0)
            return CGAffineTransform(translationX: tx + pivotX, y: ty + pivotY)
                .rotated(by: rotation * .pi / 180)
                .scaledBy(x: sx, y: sy)
                .translatedBy(x: -pivotX, y: -pivotY)
        }
    }
    
    struct Shape {
        enum Kind {
            case logo
            case text
        }
        
        let group: String?
        let path: String
        let kind: Kind
        let alpha: Double
        let alphaAnimations: [Animation]
        
        func opacity(at time: TimeInterval) -> Double {
            Animation.value(alphaAnimations, at: time, default: alpha)
        }
    }
}

enum NordicLogoPath {
    
    static let paths: [Path] = NordicLogoAnimation.shapes.map { parse($0.path) }
    
    static func parse(_ data: String) -> Path {
        var path = Path()
        let scanner = Scanner(string: data)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: " ,\n\t")
        var command: Character = "M"
        func number() -> CGFloat {
            CGFloat(scanner.scanDouble() ?? 0)
        }
        while !scanner.isAtEnd {
            if let letter = scanner.scanCharacters(from: CharacterSet(charactersIn: "MLCZmlcz")), let last = letter.last {
                command = last
            }
            switch command {
            case "M":
                path.move(to: CGPoint(x: number(), y: number()))
                command = "L"
            case "L":
                path.addLine(to: CGPoint(x: number(), y: number()))
            case "C":
                let c1 = CGPoint(x: number(), y: number())
                let c2 = CGPoint(x: number(), y: number())
                let end = CGPoint(x: number(), y: number())
                path.addCurve(to: end, control1: c1, control2: c2)
            case "Z", "z":
                path.closeSubpath()
            default:
                return path
            }
        }
        return path
    }
}
