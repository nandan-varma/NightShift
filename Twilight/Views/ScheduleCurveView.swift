import SwiftUI

/// A 24-hour preview of the scheduled color temperature for the current local
/// day: the Kelvin curve with night (warm) hours dimmed, a marker at "now",
/// and a tick where the next transition happens. Uses the same pure schedule
/// functions as the engine, so it stays accurate across all modes.
struct ScheduleCurveView: View {
    let settings: SettingsStore
    var now: Date = Date()
    var nextTransition: Date?

    private let height: CGFloat = 60
    private let sampleCount = 96 // every 15 minutes
    private let kelvinRange: ClosedRange<Double> = 1800...6500

    var body: some View {
        Canvas { context, size in
            draw(context: &context, size: size)
        }
        .frame(height: height)
        .accessibilityLabel("24-hour schedule preview")
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let samples = samples()
        guard !samples.isEmpty else { return }
        let start = samples[0].date
        let end = start.addingTimeInterval(86400)

        func x(_ date: Date) -> CGFloat {
            CGFloat(date.timeIntervalSince(start) / 86400) * size.width
        }
        func y(_ kelvin: Double) -> CGFloat {
            let progress = (kelvin.clamped(to: kelvinRange) - kelvinRange.lowerBound)
                / (kelvinRange.upperBound - kelvinRange.lowerBound)
            return size.height * (1 - CGFloat(progress)) // warm (low K) sits low
        }

        // Dim the night (warm) hours.
        var bandStart: CGFloat?
        for sample in samples {
            if sample.isWarm {
                if bandStart == nil { bandStart = x(sample.date) }
            } else if let startX = bandStart {
                fillBand(context: &context, from: startX, to: x(sample.date), size: size)
                bandStart = nil
            }
        }
        if let startX = bandStart {
            fillBand(context: &context, from: startX, to: size.width, size: size)
        }

        // Kelvin curve.
        var path = Path()
        for (index, sample) in samples.enumerated() {
            let point = CGPoint(x: x(sample.date), y: y(sample.kelvin))
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        var area = path
        area.addLine(to: CGPoint(x: size.width, y: size.height))
        area.addLine(to: CGPoint(x: 0, y: size.height))
        area.closeSubpath()
        context.fill(area, with: .color(Color.primary.opacity(0.04)))

        let gradient = Gradient(colors: [
            Color.fromKelvin(settings.dayColorTemperatureKelvin),
            Color.fromKelvin(settings.nightColorTemperatureKelvin)
        ])
        context.stroke(
            path,
            with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)),
            lineWidth: 1.5
        )

        // Next-transition tick at the top edge.
        if let next = nextTransition, next > now, next < end {
            let tickX = x(next)
            let tick = Path { builder in
                builder.move(to: CGPoint(x: tickX, y: 0))
                builder.addLine(to: CGPoint(x: tickX, y: 6))
            }
            context.stroke(tick, with: .color(Color.secondary.opacity(0.6)), lineWidth: 1.5)
        }

        // "Now" marker.
        let nowX = x(now)
        let nowLine = Path { builder in
            builder.move(to: CGPoint(x: nowX, y: 0))
            builder.addLine(to: CGPoint(x: nowX, y: size.height))
        }
        context.stroke(nowLine, with: .color(Color.secondary.opacity(0.6)), lineWidth: 1)

        let nowKelvin = ScheduleEngine.scheduledKelvin(now: now, solar: solar, settings: settings)
        let dot = Path(ellipseIn: CGRect(x: nowX - 3, y: y(nowKelvin) - 3, width: 6, height: 6))
        context.fill(dot, with: .color(Color.fromKelvin(nowKelvin)))
        context.stroke(dot, with: .color(.white.opacity(0.9)), lineWidth: 1)
    }

    private func fillBand(context: inout GraphicsContext, from startX: CGFloat, to endX: CGFloat, size: CGSize) {
        let rect = CGRect(x: startX, y: 0, width: max(endX - startX, 0), height: size.height)
        context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Color.primary.opacity(0.05)))
    }

    private var solar: SolarTimes? {
        guard settings.scheduleMode == .auto else { return nil }
        let calendar = Calendar.current
        let anchor = ScheduleEngine.solarCalculatorAnchor(now: now, calendar: calendar)
        return SolarCalculator.sunriseSunset(
            for: anchor,
            latitude: settings.latitude,
            longitude: settings.longitude
        )
    }

    private func samples() -> [Sample] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let warmThreshold = (settings.dayColorTemperatureKelvin + settings.nightColorTemperatureKelvin) / 2
        var result: [Sample] = []
        result.reserveCapacity(sampleCount)

        for step in 0..<sampleCount {
            let date = start.addingTimeInterval(Double(step) * 15 * 60)
            let kelvin = ScheduleEngine.scheduledKelvin(now: date, solar: solar, settings: settings)
            result.append(Sample(date: date, kelvin: kelvin, isWarm: kelvin < warmThreshold))
        }
        return result
    }

    private struct Sample {
        let date: Date
        let kelvin: Double
        let isWarm: Bool
    }
}
