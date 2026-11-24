internal import Bessel
internal import Numeric

extension Acoustics {
    public struct Membrane: Hashable, Sendable {
        public var radius: Length<Space.Physical, Double>
        /// The pull per length of rim, in N/m. No atom holds this kind yet (a membrane's tension is not a stiffness,
        /// though they share a dimension), so it is a scalar.
        public var tension: Double
        public var density: Density.Surface.Value<Double>
        /// How much air moves with the head, as a pure number: the moved mass per area gains `load` × the air's
        /// density / wavenumber.
        public var load: Double

        public init(
            radius: Length<Space.Physical, Double>,
            tension: Double,
            density: Density.Surface.Value<Double>,
            load: Double = 0
        ) {
            self.radius = radius
            self.tension = tension
            self.density = density
            self.load = load
        }
    }
}

extension Acoustics.Membrane {
    public func modes(below frequency: Frequency.Value<Double>, in air: Acoustics.Air = .room) -> [Mode] {
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

    public func wavenumber(of mode: Mode) -> Wavenumber.Value<Double> {
        Wavenumber.amount(mode.zero / radius.underlying)
    }

    /// The mass per area that moves with a mode: the head's, and the air's load.
    public func moved(by mode: Mode, in air: Acoustics.Air = .room) -> Density.Surface.Value<Double> {
        Density.Surface.amount(density.underlying + load * air.density.underlying / wavenumber(of: mode).underlying)
    }

    public func frequency(of mode: Mode, in air: Acoustics.Air = .room) -> Frequency.Value<Double> {
        let wavenumber = wavenumber(of: mode).underlying
        return Frequency.hertz(
            wavenumber * (tension / moved(by: mode, in: air).underlying).squareRoot() / (2 * Double.pi)
        )
    }

    /// The mode's shape at a distance from the centre, where it is largest around the head: a pure number.
    public func shape(of mode: Mode, at distance: Length<Space.Physical, Double>) -> Double {
        let distance = distance.underlying
        let radius = radius.underlying
        return distance.magnitude > radius
            ? 0 : Bessel.First<Double>(order: mode.diameters).value(at: mode.zero * distance / radius)
    }

    /// How much of the mode a round patch of radius `width` feels against a point: a pure number.
    public func patch(of mode: Mode, across width: Length<Space.Physical, Double>) -> Double {
        let reach = wavenumber(of: mode).underlying * width.underlying
        return reach.magnitude < 1e-9 ? 1 : 2 * Bessel.First<Double>(order: 1).value(at: reach) / reach
    }

    /// The integral of the squared shape over the head, in square metres.
    func square(of mode: Mode) -> Double {
        let radius = radius.underlying
        let edge = Bessel.First<Double>(order: Cardinal(UInt(Int(clamping: mode.diameters)) + 1)).value(
            at: mode.zero
        )
        return Double.pi * radius * radius * edge * edge
            * (Int(clamping: mode.diameters) == 0 ? 1 : 0.5)
    }

    public func mass(of mode: Mode, in air: Acoustics.Air = .room) -> Mass.Value<Double> {
        Mass.kilograms(moved(by: mode, in: air).underlying * square(of: mode))
    }

    /// The integral of the squared slope of the shape over the head: a pure number.
    public func stretch(of mode: Mode) -> Double {
        let wavenumber = wavenumber(of: mode).underlying
        return wavenumber * wavenumber * square(of: mode)
    }

    /// The mode's area as the far field sees it at `angle` from straight above: the integral over the head of its
    /// shape times e^(−i k·x), for the wavenumber k of sound leaving at that angle, in the direction around the head
    /// where the mode is loudest. Far from a head set in a wall, sound pressure × distance is the air's density ×
    /// this area × the mode's acceleration / 2π (Rayleigh's integral).
    public func area(
        of mode: Mode,
        at frequency: Frequency.Value<Double>,
        tilted angle: Radian<Double>,
        in air: Acoustics.Air = .room
    ) -> Area<Space.Physical>.Value<Double> {
        let radius = radius.underlying
        let across = 2 * Double.pi * frequency.underlying / air.speed.underlying * Double.math.sin(angle.underlying)
        let along = wavenumber(of: mode).underlying
        let order = UInt(Int(clamping: mode.diameters))
        var apart = along * along - across * across
        if apart.magnitude < 1e-9 * along * along { apart = 1e-9 * along * along }
        let edge = Bessel.First<Double>(order: Cardinal(order + 1)).value(at: mode.zero)
        return Area<Space.Physical>.amount(
            2 * Double.pi * radius * along * edge * Bessel.First<Double>(order: Cardinal(order)).value(at: across * radius)
                / apart
        )
    }

    /// The decay a mode has from the sound it sends out alone.
    public func radiated(
        by mode: Mode,
        at frequency: Frequency.Value<Double>,
        in air: Acoustics.Air = .room
    ) -> Decay.Value<Double> {
        let slices = 200
        var sum = 0.0
        var index = 0
        while index <= slices {
            let angle = Double.pi / 2 * Double(index) / Double(slices)
            let beam =
                area(of: mode, at: frequency, tilted: Angle.Radian.amount(angle), in: air).underlying / (2 * Double.pi)
            let edge = index == 0 || index == slices ? 0.5 : 1.0
            sum += edge * beam * beam * Double.math.sin(angle)
            index += 1
        }
        let around = Int(clamping: mode.diameters) == 0 ? 2 * Double.pi : Double.pi
        let angular = 2 * Double.pi * frequency.underlying
        let density = air.density.underlying
        return Decay.amount(
            density * angular * angular * sum * (Double.pi / 2 / Double(slices)) * around
                / (2 * air.speed.underlying * mass(of: mode, in: air).underlying)
        )
    }
}
