//
//  SpectroController.swift
//  Simulations
//
//

import Foundation
import SwiftUI
import AudioKit
import AVFoundation
import SceneKit
import Combine

struct SpectroController: NSViewRepresentable {
    var model: SpectroscapeModel
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(model: self.model)
    }
    
    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.autoresizingMask = [.width, .height]
        
        let scene = SCNScene()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .black
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 50)
        cameraNode.camera?.zFar = 1000
        scene.rootNode.addChildNode(cameraNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .ambient
        lightNode.light?.color = NSColor.white
        lightNode.position = SCNVector3(x: 5, y: 5, z: 5)
        scene.rootNode.addChildNode(lightNode)
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = NSColor(white: 0.4, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLightNode)
        
        let directionalLightNode = SCNNode()
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.castsShadow = true
        directionalLight.shadowMode = .deferred
        directionalLight.shadowColor = NSColor(white: 0, alpha: 0.7)
        directionalLight.shadowSampleCount = 16
        directionalLight.shadowRadius = 5.0
        directionalLightNode.light = directionalLight
        directionalLightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        directionalLightNode.eulerAngles = SCNVector3(-Float.pi/4, 0, 0)
        scene.rootNode.addChildNode(directionalLightNode)
        
        context.coordinator.scnView = scnView
        scnView.delegate = context.coordinator

        scnView.isPlaying = true
        scnView.loops = true
        
        return scnView
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
        // No updates needed for now
    }
    
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var model: SpectroscapeModel
        var audioController: AudioController
        var scnView: SCNView?
        
        var waveformNodes: [SCNNode] = []
        let maxSlices = 500
        let zSpacing: Float = 0.3
        let maxDepth: Float
        
        var cancellables: Set<AnyCancellable> = []

        init(model: SpectroscapeModel) {
            self.model = model
            
            audioController = AudioController(url: URL(fileURLWithPath: ""))
            
            maxDepth = Float(maxSlices) * zSpacing
            super.init()
            
            subscribeToVM()
            audioController.setCoordinator(self)
        }
        
        func subscribeToVM() {
            model.$play.sink { [weak self] play in
                guard let self = self else { return }
                self.setAudioPlayingState(play)
            }
            .store(in: &cancellables)
            
            model.$stop.sink { [weak self] stop in
                guard let self = self else { return }
                if (stop) {
                    self.stopAudio()
                    model.stop = false
                }
            }
            .store(in: &cancellables)
            
            model.$songIndex.sink { [weak self] index in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.model.play = false
                }
                self.setAudioFile(model.songs[index])
            }
            .store(in: &cancellables)
        }
        
        func setAudioPlayingState(_ play: Bool) {
            audioController.pauseState(play)
        }
        
        func setAudioFile(_ song: Song) {
            let slf = self
            DispatchQueue.main.async {
                for node in slf.waveformNodes {
                    node.removeFromParentNode()
                }
                slf.waveformNodes.removeAll()
            }
            let url = Bundle.main.url(forResource: song.name, withExtension: song.ext)!
            audioController.setFile(url: url)
        }
        
        private func stopAudio() {
            audioController.stop()
        }
        
        func updateWaveform() {
            guard let player = audioController.audioPlayer else { return }
            if (!player.isPlaying) { return }
            guard let scene = scnView?.scene else { return }
            let data = audioController.fftData
            let newSlice = createWaveformNode(with: data)
            scene.rootNode.addChildNode(newSlice)
            
            let count = waveformNodes.count
            
            if count >= maxSlices {
                let oldest = waveformNodes.removeFirst()
                oldest.removeFromParentNode()
            }
            let fc = Float(count)
            for (index, node) in waveformNodes.enumerated() {
                let newZ = Float(count - index) * -zSpacing
                node.position.z = CGFloat(newZ)

                // factor is dependent on the maxSlices... 0 at maxDepth
                let factor = Float(index)/fc
                let col = NSColor.systemBlue.withAlphaComponent(CGFloat(factor))
                node.geometry?.firstMaterial?.emission.contents = 0
                node.geometry?.firstMaterial?.diffuse.contents = col
            }
            
            waveformNodes.append(newSlice)
        }
        
        func catmullRom(t: Float, p0: SCNVector3, p1: SCNVector3, p2: SCNVector3, p3: SCNVector3) -> SCNVector3 {
            // Catmull-Rom spline formula (assuming uniform parameterization)
            let t2 = t * t
            let t3 = t2 * t
            
            let p0x = Float(p0.x)
            let p0y = Float(p0.y)
            
            let p1x = Float(p1.x)
            let p1y = Float(p1.y)
            
            let p2x = Float(p2.x)
            let p2y = Float(p2.y)
            
            let p3x = Float(p3.x)
            let p3y = Float(p3.y)
            
            // 0.5 factor scales the result for uniform Catmull-Rom splines.
            let xA: Float = 2*p1x + (-p0x + p2x) * t + (2*p0x - 5*p1x + 4*p2x - p3x) * t2
            let xB: Float = (-p0x + 3*p1x - 3*p2x + p3x) * t3
            let x = 0.5 * (xA + xB)
            
            let yA: Float = 2*p1y + (-p0y + p2y) * t + (2*p0y - 5*p1y + 4*p2y - p3y) * t2
            let yB: Float = (-p0y + 3*p1y - 3*p2y + p3y) * t3
            let y = 0.5 * (yA + yB)
            
            return SCNVector3(x, y, 0)
        }
        
        func smoothVertices(from points: [SCNVector3], segments: Int) -> [SCNVector3] {
            guard points.count >= 4 else { return points }
            
            var smoothedPoints: [SCNVector3] = []
            
            // iterate through all valid points
            for i in 1..<points.count - 2 {
                let p0 = points[i - 1]
                let p1 = points[i]
                let p2 = points[i + 1]
                let p3 = points[i + 2]
                
                // append first control pt
                if i == 1 {
                    smoothedPoints.append(p1)
                }
                
                // interpolate points between p1 and p2
                for j in 1...segments {
                    let t = Float(j) / Float(segments + 1)
                    let interpolated = catmullRom(t: t, p0: p0, p1: p1, p2: p2, p3: p3)
                    smoothedPoints.append(interpolated)
                }
                
                // Append p2 as a control point so the curve goes through it.
                smoothedPoints.append(p2)
            }
            
            return smoothedPoints
        }
        
        func createWaveformNode(with data: [Float]) -> SCNNode {
            guard !data.isEmpty else { return SCNNode() }
            
            var vertices: [SCNVector3] = []
            let count = data.count
            let halfCount = Float(count) / 2.0
            
            let totalWidth: Float = 100.0
            
            let sampleRate: Float = 44100.0
            let fftBufferSize: Float = Float(audioController.fftBufferSize)
            let deltaF = sampleRate / fftBufferSize
            
            let minFreq: Float = deltaF
            let maxFreq: Float = sampleRate/2.0
            
            // avg
            var avgdata: [Float] = [data[0]]
            for i in 1..<Int(halfCount-1) {
                avgdata.append((data[i-1] + 2 * data[i] + data[i+1]) / 4.0)
            }
            avgdata.append(data[Int(halfCount-1)])
            var data = avgdata

            for i in 0..<Int(halfCount) {
                let freq = (i == 0) ? minFreq : Float(i) * deltaF
                let clampedFreq = max(freq, minFreq)
                let normalizedX = (log10(clampedFreq) - log10(minFreq)) / (log10(maxFreq) - log10(minFreq))
                let x = normalizedX * totalWidth - totalWidth / 2.0
                
                // linear
//                let x = Float(i) * totalWidth / halfCount - totalWidth / 2.0
                
                let y = 0.4 * (20 * log10(max(0.0001, data[i])) + 80)
                
                vertices.append(SCNVector3(x, y, 0))
            }
            
            // add pts in between to make it smoother
            let newVertices: [SCNVector3] = smoothVertices(from: vertices, segments: 5)
            vertices = newVertices
            
            // duplicate the vertices but negative to make a reflection
            let nc = vertices.count
            for i in 0..<nc {
                var v = vertices[nc - i - 1]
                v.y = -v.y
                vertices.append(v)
            }
            

            //            for (i, value) in data.enumerated() {
            //                let x: Float = Float(i) * xScale
            //                let y: Float = Float(value) * yScale
            //                let z: Float = 0.0
            //                vertices.append(SCNVector3(x, y, z))
            //            }
            
            let vertexSource = SCNGeometrySource(vertices: vertices)
            
            var indices: [Int32] = []
            for i in 0..<vertices.count - 1 {
                indices.append(Int32(i))
                indices.append(Int32(i + 1))
            }
            let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
            
            let element = SCNGeometryElement(data: indexData, primitiveType: .line, primitiveCount: indices.count / 2, bytesPerIndex: MemoryLayout<Int32>.size)
            
            let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
            
            geometry.firstMaterial?.lightingModel = .phong
            geometry.firstMaterial?.diffuse.contents = NSColor.white
            geometry.firstMaterial?.emission.contents = NSColor.white
            
            return SCNNode(geometry: geometry)
        }
    }
}

class AudioController {
    private let engine = AudioEngine()
    var audioPlayer: AudioPlayer!
    var waveformData: [Float] = []
    var fftData: [Float] = []
    var fftBufferSize: UInt32 = 2048
    
    private var fftTap: FFTTap!
    private var tapInstalled = false
    
    private var audioFile: AVAudioFile!
    private var fileURL: URL
    
    
    private var coordinator: SpectroController.Coordinator!
    
    init(url: URL) {
        self.fileURL = url
        self.audioPlayer = AudioPlayer()
        engine.output = audioPlayer
        installTap()
        do {
            try engine.start()
        } catch {
            print("error starting engine")
        }
    }

    func setCoordinator(_ coordinator: SpectroController.Coordinator) {
        self.coordinator = coordinator
    }
    
    func setFile(url: URL) {
        self.pauseState(false)
        self.fileURL = url
        do {
            audioFile = try AVAudioFile(forReading: fileURL)
        } catch {
            print("Error reading audio file: \(error)")
            return
        }
        
        guard let audioFile = audioFile else { return }
        
        audioPlayer = AudioPlayer(file: audioFile)
        engine.output = audioPlayer
        fftTap.input = audioPlayer
    }
    
    func pauseState(_ play: Bool) {
        do {
            try engine.start()
        } catch {
            print("error starting engine")
        }
        if play {
            audioPlayer.play()
        } else {
            audioPlayer.pause()
        }
    }
    
    func start() {
        fatalError("Start shouldn't be called")
        do {
            audioFile = try AVAudioFile(forReading: fileURL)
        } catch {
            print("Error reading audio file: \(error)")
            return
        }
        
        guard let audioFile = audioFile else { return }
        
        audioPlayer = AudioPlayer(file: audioFile)
        audioPlayer.isLooping = false
        print("Audio sample rate: \(audioPlayer.outputFormat.sampleRate)")

        engine.output = audioPlayer
        
        do {
            try engine.start()
            audioPlayer.play()
            print("Audio started successfully")
        } catch {
            print("Error starting audio: \(error)")
        }
        
        installTap()
    }
    
    func installTap() {
        if tapInstalled { return }
        
        
        fftTap = FFTTap(audioPlayer, bufferSize: fftBufferSize) { fftData in
            let slf = self
            let coord = slf.coordinator!
            DispatchQueue.main.async {
                slf.fftData = fftData
                coord.updateWaveform()
            }
        }
        fftTap.isNormalized = false
        fftTap.start()
        
//        let format = audioPlayer.avAudioNode.outputFormat(forBus: 0)
//        audioPlayer.avAudioNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
//            guard let self = self else { return }
//            guard let channelData = buffer.floatChannelData?[0] else { return }
//            let frameLength = Int(buffer.frameLength)
//            var samples = [Float]()
//            
//            for i in 0..<frameLength {
//                samples.append(channelData[i])
//            }
//            
//            DispatchQueue.main.async {
//                self.waveformData = samples
//            }
//        }
        tapInstalled = true
    }
    
    func stop() {
        audioPlayer.stop()
        engine.stop()
    }
}
