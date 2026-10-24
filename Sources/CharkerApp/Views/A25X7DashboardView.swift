import Charts
import CharkerCore
import SwiftUI

/// Three-pad overview. No device render and no volts or amps: those integers
/// do not have a confirmed unit, and public evidence disagrees about which
/// pad is a phone, a watch, or earbuds.
struct A25X7DashboardView: View {
    @ObservedObject var model: AppModel

    private var snapshot: SessionSnapshot { model.snapshot }
    private var reading: ChargerReading? { model.activeReading }
    private var history: [PowerSample] { model.plottedHistory }

    private var observedPeak: Double {
        history.reduce(0) { max($0, $1.total) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                header
                if reading == nil {
                    SlateCard {
                        Text(L10n.text("连接后这里显示三个充电位的功率。"))
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    padCard
                }
                chartCard
            }
            .padding(Space.xxl)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    private var header: some View {
        SlateCard {
            HStack(alignment: .center, spacing: Space.l) {
                WirelessPadGlyph()
                    .frame(width: 148, height: 92)
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack(spacing: Space.s) {
                        StateDot(phase: snapshot.phase, stale: snapshot.isStale)
                        Text(snapshot.isStale ? L10n.text("数据陈旧") : snapshot.statusLabel)
                            .font(Typo.label)
                            .foregroundStyle(snapshot.isStale ? Palette.warnText : Palette.textSecondary)
                        Chip(text: L10n.text("实验性"), tone: .neutral)
                    }
                    TotalReadout(
                        watts: model.activeTotalPower,
                        isStale: snapshot.isStale,
                        size: 48
                    )
                    Text(model.activeDisplayName ?? ChargerProduct.a25x7.displayName)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var padCard: some View {
        SlateCard {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(L10n.text("三个充电位"))
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                ForEach(ChargerProduct.a25x7.ports) { port in
                    PadPowerRow(
                        port: port,
                        reading: reading?.port(port),
                        stale: snapshot.isStale
                    )
                }
            }
        }
    }

    private var chartCard: some View {
        SlateCard {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
                    Text(L10n.text("本次连接的功率"))
                        .font(Typo.label)
                        .foregroundStyle(Palette.textSecondary)
                    Spacer(minLength: Space.s)
                    PowerChartScaleMenu(
                        product: .a25x7,
                        observedPeak: observedPeak,
                        preference: $model.preferences.a25x7PowerChartMaximum
                    )
                }
                if history.count > 1 {
                    A25X7PowerChart(
                        history: history,
                        scalePreference: model.preferences.a25x7PowerChartMaximum
                    )
                    .frame(height: 180)
                } else {
                    Text(L10n.text("连接后这里显示三个充电位的功率。"))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                }
            }
        }
    }
}

struct WirelessPadGlyph: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.accent)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Palette.well)
                        .frame(width: 36, height: 22)
                        .overlay {
                            Circle()
                                .fill(Palette.accent.opacity(0.9))
                                .frame(width: 7, height: 7)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Palette.stroke, lineWidth: Stroke.hairline)
                        }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PadPowerRow: View {
    let port: ChargerPortID
    let reading: ChargerPortReading?
    let stale: Bool

    private var watts: Double {
        guard let reading, reading.isOn else { return 0 }
        return reading.power
    }

    private var delivering: Bool { !stale && (reading?.isDelivering ?? false) }

    var body: some View {
        HStack(spacing: Space.m) {
            Text(port.readoutLabel(for: .a25x7))
                .font(Typo.label)
                .foregroundStyle(delivering ? Palette.accentText : Palette.textSecondary)
                .frame(width: 72, alignment: .leading)
            PowerRail(
                watts: watts,
                ceiling: ChargerProduct.a25x7.ratedWatts,
                isDelivering: delivering,
                dimmed: stale
            )
            Text(reading == nil ? "—" : L10n.format("%.2f", watts) + " W")
                .font(.numeral(13, .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 72, alignment: .trailing)
            Text(delivering ? L10n.text("输出中") : L10n.text("空闲", table: "Core"))
                .font(Typo.micro)
                .foregroundStyle(delivering ? Palette.accentText : Palette.textTertiary)
                .frame(width: 52, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct A25X7PowerChart: View, Equatable {
    let history: [PowerSample]
    let scalePreference: Int

    static func == (lhs: A25X7PowerChart, rhs: A25X7PowerChart) -> Bool {
        lhs.scalePreference == rhs.scalePreference
            && lhs.history.count == rhs.history.count
            && lhs.history.last?.at == rhs.history.last?.at
            && lhs.history.last?.total == rhs.history.last?.total
    }

    private var axisMaximum: Int {
        PowerChartScale.effectiveMaximum(
            preference: scalePreference,
            product: .a25x7,
            observedPeak: history.reduce(0) { max($0, $1.total) }
        )
    }

    private enum ChartLabel {
        static let time = L10n.text("时间")
        static let watts = L10n.text("功率")
    }

    var body: some View {
        Chart(history) { sample in
            AreaMark(
                x: .value(ChartLabel.time, sample.at),
                y: .value(ChartLabel.watts, sample.total)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Palette.accent.opacity(0.18))
            LineMark(
                x: .value(ChartLabel.time, sample.at),
                y: .value(ChartLabel.watts, sample.total)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Palette.accent)
        }
        .chartYScale(domain: 0...PowerChartScale.chartCeiling(maximum: axisMaximum))
        .chartYAxis {
            AxisMarks(values: PowerChartScale.axisValues(maximum: axisMaximum)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: Stroke.hairline))
                    .foregroundStyle(Palette.stroke)
                AxisValueLabel {
                    if let watts = value.as(Int.self) {
                        Text(L10n.format("%d W", watts))
                            .font(.numeral(10, .medium))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.numeral(10, .medium))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }
}
