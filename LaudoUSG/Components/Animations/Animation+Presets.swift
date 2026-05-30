import SwiftUI

extension Animation {
    static let laudousgSmooth = Animation.spring(
        response: 0.35,
        dampingFraction: 0.86,
        blendDuration: 0
    )

    static let laudousgSnappy = Animation.spring(
        response: 0.24,
        dampingFraction: 0.9,
        blendDuration: 0
    )

    static let laudousgEase = Animation.timingCurve(
        0.25,
        0.46,
        0.45,
        0.94,
        duration: 0.36
    )
}
