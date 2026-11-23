internal import Bessel
internal import Numeric

extension Acoustics {
    public struct Membrane: Hashable, Sendable {
        public var radius: Double
        public var tension: Double
        public var density: Double
        public var load: Double

        public init(radius: Double, tension: Double, density: Double, load: Double = 0) {
            self.radius = radius
            self.tension = tension
            self.density = density
            self.load = load
        }
    }
}

extension Acoustics.Membrane {
    public func modes(below frequency: Double, in air: Acoustics.Air = .room) -> [Mode] {
        var modes: [Mode] = []
        var diameters: UInt = 0
        while true {
            var found = false
            var known = 8
            var checked = 0
            var rising = true
            while rising {
                let zeros = Bessel.First<Double>(order: Cardinal(diameters)).zeros(Cardinal(UInt(known)))
                while checked < zeros.count, rising {
                    let mode = Mode(
                        diameters: Cardinal(diameters),
                        circles: Cardinal(UInt(checked + 1)),
                        zero: zeros[checked]
                    )
                    if self.frequency(of: mode, in: air) < frequency {
                        modes.append(mode)
                        found = true
                        checked += 1
                    } else {
                        rising = false
                    }
                }
                known *= 2
            }
            guard found else { break }
            diameters += 1
        }
        return modes
    }

    public func wavenumber(of mode: Mode) -> Double { mode.zero / radius }

    public func moved(by mode: Mode, in air: Acoustics.Air = .room) -> Double {
        density + load * air.density / wavenumber(of: mode)
    }

    public func frequency(of mode: Mode, in air: Acoustics.Air = .room) -> Double {
        let wavenumber = wavenumber(of: mode)
        return wavenumber * (tension / moved(by: mode, in: air)).squareRoot() / (2 * Double.pi)
    }

    public func shape(of mode: Mode, at distance: Double) -> Double {
        distance.magnitude > radius
            ? 0 : Bessel.First<Double>(order: mode.diameters).value(at: mode.zero * distance / radius)
    }

    public func patch(of mode: Mode, across width: Double) -> Double {
        let reach = wavenumber(of: mode) * width
        return reach.magnitude < 1e-9 ? 1 : 2 * Bessel.First<Double>(order: 1).value(at: reach) / reach
    }

    func square(of mode: Mode) -> Double {
        let edge = Bessel.First<Double>(order: Cardinal(UInt(Int(clamping: mode.diameters)) + 1)).value(
            at: mode.zero
        )
        return Double.pi * radius * radius * edge * edge
            * (Int(clamping: mode.diameters) == 0 ? 1 : 0.5)
    }

    public func mass(of mode: Mode, in air: Acoustics.Air = .room) -> Double {
        moved(by: mode, in: air) * square(of: mode)
    }

    public func stretch(of mode: Mode) -> Double {
        let wavenumber = wavenumber(of: mode)
        return wavenumber * wavenumber * square(of: mode)
    }

    public func beam(
        of mode: Mode,
        at frequency: Double,
        tilted angle: Double,
        in air: Acoustics.Air = .room
    ) -> Double {
        let across = 2 * Double.pi * frequency / air.speed * Double.math.sin(angle)
        let along = wavenumber(of: mode)
        let order = UInt(Int(clamping: mode.diameters))
        var apart = along * along - across * across
        if apart.magnitude < 1e-9 * along * along { apart = 1e-9 * along * along }
        let edge = Bessel.First<Double>(order: Cardinal(order + 1)).value(at: mode.zero)
        return air.density * radius * along * edge
            * Bessel.First<Double>(order: Cardinal(order)).value(at: across * radius) / apart
    }

    public func radiated(by mode: Mode, at frequency: Double, in air: Acoustics.Air = .room) -> Double {
        let slices = 200
        var sum = 0.0
        var index = 0
        while index <= slices {
            let angle = Double.pi / 2 * Double(index) / Double(slices)
            let beam = beam(of: mode, at: frequency, tilted: angle, in: air) / air.density
            let edge = index == 0 || index == slices ? 0.5 : 1.0
            sum += edge * beam * beam * Double.math.sin(angle)
            index += 1
        }
        let around = Int(clamping: mode.diameters) == 0 ? 2 * Double.pi : Double.pi
        let angular = 2 * Double.pi * frequency
        return air.density * angular * angular * sum * (Double.pi / 2 / Double(slices)) * around
            / (2 * air.speed * mass(of: mode, in: air))
    }
}
