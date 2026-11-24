import Acoustics_Membrane
import Foundation
import Testing

enum `Acoustics Tests` {}

extension `Acoustics Tests` {
    @Suite struct Membrane {}
}

extension `Acoustics Tests`.Membrane {
    fileprivate static let head = Acoustics.Membrane(
        radius: 0.32,
        tension: Tension.Surface.amount(5_360),
        density: 0.262,
        load: 3.95
    )

    @Test func `In a vacuum a mode sounds at its zero times the wave speed over the rim`() {
        let bare = Acoustics.Membrane(radius: 0.3, tension: Tension.Surface.amount(3_000), density: 0.25)
        let modes = bare.modes(below: 700)
        let first = modes.first { $0.diameters == 0 && $0.circles == 1 }!
        #expect(abs(first.zero - 2.404825557695773) < 1e-12)
        #expect(
            abs(
                bare.frequency(of: first).underlying - 2.404825557695773 * (3_000 / 0.25).squareRoot()
                    / (2 * Double.pi * 0.3)
            ) < 1e-9
        )
        #expect(modes.allSatisfy { bare.frequency(of: $0) < 700 })
        #expect(modes.count == Set(modes).count && modes.count > 10)
    }

    @Test func `The air's load brings the measured head near the fifth, octave and beyond`() {
        let head = `Acoustics Tests`.Membrane.head
        let modes = head.modes(below: 600)
        func frequency(_ diameters: Cardinal, _ circles: Cardinal) -> Double {
            head.frequency(of: modes.first { $0.diameters == diameters && $0.circles == circles }!).underlying
        }
        let principal = frequency(1, 1)
        #expect(abs(principal - 172) < 2)
        #expect(abs(frequency(2, 1) / principal / 1.50 - 1) < 0.035)
        #expect(abs(frequency(3, 1) / principal / 1.97 - 1) < 0.035)
        #expect(abs(frequency(4, 1) / principal / 2.44 - 1) < 0.035)
    }

    @Test func `A mode's mass is its moved mass per area times the integral of its squared shape`() {
        let head = `Acoustics Tests`.Membrane.head
        for mode in head.modes(below: 500) {
            let rings = 4_000
            let sum = (0..<rings).reduce(0.0) { sum, ring in
                let distance = (Double(ring) + 0.5) * head.radius.underlying / Double(rings)
                let shape = head.shape(of: mode, at: Space.Physical.metres(distance))
                return sum + shape * shape * distance * head.radius.underlying / Double(rings)
            }
            let around = mode.diameters == 0 ? 2 * Double.pi : Double.pi
            #expect(abs(head.mass(of: mode).underlying / (head.moved(by: mode).underlying * sum * around) - 1) < 1e-5)
        }
    }

    @Test func `What a mode radiates gives ring times near the calculated ones of the measured drum`() {
        let head = `Acoustics Tests`.Membrane.head
        let modes = head.modes(below: 600)
        let calculated: [(UInt, UInt, Double)] = [(1, 1, 0.8), (2, 1, 1.8), (0, 2, 0.2), (1, 2, 0.2)]
        for (diameters, circles, seconds) in calculated {
            let mode = modes.first {
                $0.diameters == Cardinal(diameters) && $0.circles == Cardinal(circles)
            }!
            let ring = 6.908 / head.radiated(by: mode, at: head.frequency(of: mode)).underlying
            #expect(ring > seconds / 2 && ring < seconds * 2)
        }
    }

    @Test
    func
        `Straight above, only modes without diameters are heard, and a patch hears less of fine modes`()
    {
        let head = `Acoustics Tests`.Membrane.head
        let modes = head.modes(below: 3_000)
        for mode in modes where mode.diameters != 0 {
            #expect(head.area(of: mode, at: head.frequency(of: mode), tilted: 0) == 0)
        }
        let round = modes.first { $0.diameters == 0 && $0.circles == 1 }!
        #expect(head.area(of: round, at: 100, tilted: 0) != 0)
        let coarse = modes.min { $0.zero < $1.zero }!
        let fine = modes.max { $0.zero < $1.zero }!
        #expect(head.patch(of: fine, across: 0.015).magnitude < head.patch(of: coarse, across: 0.015))
        #expect(head.patch(of: coarse, across: 0) == 1)
    }

    @Test func `Straight above, a mode without diameters shows the integral of its shape over the head`() {
        let head = `Acoustics Tests`.Membrane.head
        let mode = head.modes(below: 600).first { $0.diameters == 0 && $0.circles == 1 }!
        let radius = head.radius.underlying
        let integral = 2 * Double.pi * radius * radius * Bessel.First<Double>(order: 1).value(at: mode.zero) / mode.zero
        let area = head.area(of: mode, at: head.frequency(of: mode), tilted: 0).underlying
        #expect(abs(area / integral - 1) < 1e-12)
    }
}

extension `Acoustics Tests`.Membrane {
    @Test func `The membrane's law balances its dimensions`() {
        typealias D = Quantity.Dimension
        // ω = k √(T / σ): a surface tension over a surface density, times a squared wavenumber, is a squared
        // angular frequency
        let wavenumber = D.of(Wavenumber.self)
        let angular = D.of(Frequency.Angular.self)
        #expect(D.of(Tension.Surface.self) / D.of(Density.Surface.self) * wavenumber * wavenumber == angular * angular)
        // a surface tension is a force per length of rim: kg m s⁻² / m
        #expect(D.of(Tension.Surface.self) * D.of(Measure<1, Space.Physical>.self) == D(length: 1, mass: 1, time: -2))
    }

    @Test func `A tension given as a scalar is the same tension`() {
        let typed = Acoustics.Membrane(radius: 0.3, tension: Tension.Surface.amount(3_000), density: 0.25)
        let scalar = Acoustics.Membrane(radius: 0.3, tension: 3_000.0, density: 0.25)
        #expect(typed == scalar)
    }
}
