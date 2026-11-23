extension Acoustics.Membrane {
    public struct Mode: Hashable, Sendable {
        public let diameters: Cardinal
        public let circles: Cardinal
        public let zero: Double

        init(diameters: Cardinal, circles: Cardinal, zero: Double) {
            self.diameters = diameters
            self.circles = circles
            self.zero = zero
        }
    }
}
