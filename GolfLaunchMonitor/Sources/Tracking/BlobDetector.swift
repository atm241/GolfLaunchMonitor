import Foundation

struct Blob {
    let pixelCount: Int
    let minX: Int
    let maxX: Int
    let minY: Int
    let maxY: Int
    let centroidX: Double
    let centroidY: Double

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
    var diameter: Double { Double(max(width, height)) }

    /// 1.0 = a perfect circle filling its bounding box; motion blur and thresholding
    /// noise pull this down, so callers should use a lenient cutoff.
    var circularity: Double {
        let boxArea = Double(width * height)
        guard boxArea > 0 else { return 0 }
        let idealFill = Double.pi / 4.0 // a circle fills ~78.5% of its bounding square
        return (Double(pixelCount) / boxArea) / idealFill
    }
}

/// Finds connected components in a binary mask via iterative flood fill.
enum BlobDetector {
    static func findBlobs(mask: [Bool], width: Int, height: Int, minPixels: Int = 4, maxPixels: Int = 20000) -> [Blob] {
        var visited = [Bool](repeating: false, count: mask.count)
        var blobs: [Blob] = []
        var stack: [Int] = []

        for start in 0..<mask.count where mask[start] && !visited[start] {
            stack.removeAll(keepingCapacity: true)
            stack.append(start)
            visited[start] = true

            var pixelCount = 0
            var minX = width, maxX = 0, minY = height, maxY = 0
            var sumX = 0.0, sumY = 0.0

            while let idx = stack.popLast() {
                let x = idx % width
                let y = idx / width
                pixelCount += 1
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                sumX += Double(x); sumY += Double(y)

                // 4-connected neighbors
                if x > 0 {
                    let n = idx - 1
                    if mask[n] && !visited[n] { visited[n] = true; stack.append(n) }
                }
                if x < width - 1 {
                    let n = idx + 1
                    if mask[n] && !visited[n] { visited[n] = true; stack.append(n) }
                }
                if y > 0 {
                    let n = idx - width
                    if mask[n] && !visited[n] { visited[n] = true; stack.append(n) }
                }
                if y < height - 1 {
                    let n = idx + width
                    if mask[n] && !visited[n] { visited[n] = true; stack.append(n) }
                }
            }

            if pixelCount >= minPixels && pixelCount <= maxPixels {
                blobs.append(Blob(
                    pixelCount: pixelCount,
                    minX: minX, maxX: maxX, minY: minY, maxY: maxY,
                    centroidX: sumX / Double(pixelCount),
                    centroidY: sumY / Double(pixelCount)
                ))
            }
        }

        return blobs
    }

    /// Absolute difference between two same-sized grayscale buffers, thresholded to a binary mask.
    static func diffMask(_ a: [UInt8], _ b: [UInt8], threshold: UInt8 = 25) -> [Bool] {
        var mask = [Bool](repeating: false, count: a.count)
        for i in 0..<a.count {
            let diff = a[i] > b[i] ? a[i] - b[i] : b[i] - a[i]
            mask[i] = diff >= threshold
        }
        return mask
    }

    /// Bright, roughly circular blobs in a single static frame — used to locate the
    /// ball at address, before it's moving (frame-differencing sees nothing at rest).
    static func brightBlobs(in frame: GrayscaleFrame, brightnessThreshold: UInt8 = 170) -> [Blob] {
        var mask = [Bool](repeating: false, count: frame.pixels.count)
        for i in 0..<frame.pixels.count {
            mask[i] = frame.pixels[i] >= brightnessThreshold
        }
        return findBlobs(mask: mask, width: frame.width, height: frame.height, minPixels: 3, maxPixels: 4000)
    }
}
