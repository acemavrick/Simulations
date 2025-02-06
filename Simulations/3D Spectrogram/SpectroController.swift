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
        scene.rootNode.addChildNode(cameraNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.color = NSColor.white
        lightNode.position = SCNVector3(x: 5, y: 5, z: 5)
        scene.rootNode.addChildNode(lightNode)
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = NSColor(white: 0.3, alpha: 1.0)
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
        directionalLightNode.position = SCNVector3(x: 0, y: 20, z: 20)
        directionalLightNode.eulerAngles = SCNVector3(-Float.pi/4, 0, 0)
        scene.rootNode.addChildNode(directionalLightNode)
        
        context.coordinator.scnView = scnView
        scnView.delegate = context.coordinator

        scnView.isPlaying = true
        scnView.loops = true
        
        context.coordinator.startAudio()

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
        let maxSlices = 400
        let zSpacing: Float = 0.3
        let maxDepth: Float

        init(model: SpectroscapeModel) {
            self.model = model
            
            if let url = Bundle.main.url(forResource: model.songname, withExtension: model.songext) {
                audioController = AudioController(url: url)
            } else {
                fatalError("Failed to find audio file")
            }
            
            maxDepth = Float(maxSlices) * zSpacing
        }
        
        func startAudio() {
            audioController.start()
        }
        
        func updateWaveform() {
            guard let scene = scnView?.scene else { return }
            let data = audioController.fftData
            let newSlice = createWaveformNode(with: data)
            scene.rootNode.addChildNode(newSlice)
            
            let count = waveformNodes.count
            
            if count >= maxSlices {
                let oldest = waveformNodes.removeFirst()
                oldest.removeFromParentNode()
            }
            
            for (index, node) in waveformNodes.enumerated() {
                let newZ = Float(count - index) * -zSpacing
                node.position.z = CGFloat(newZ)

                let factor = max(0.0, 0.3 - 0.5 * (abs(Float(node.position.z)) / maxDepth))
                let col = NSColor.systemBlue.withAlphaComponent(CGFloat(factor))
                node.geometry?.firstMaterial?.emission.contents = col
                node.geometry?.firstMaterial?.diffuse.contents = col
            }
            
            waveformNodes.append(newSlice)
        }
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            updateWaveform()
        }
        
        func createWaveformNode(with data: [Float]) -> SCNNode {
            guard !data.isEmpty else { return SCNNode() }
            
            var vertices: [SCNVector3] = []
            var data = data
            let count = data.count
            let halfCount = Float(count) / 2.0
            
            // smooth values (averaging, for now)
            for i in 1..<Int(halfCount - 1) {
                data[i] = (data[i - 1] + data[i] + data[i + 1]) / 3.0
            }
            
            let totalWidth: Float = 100.0
            
            let sampleRate: Float = 44100.0
            let fftBufferSize: Float = Float(audioController.fftBufferSize)
            let deltaF = sampleRate / fftBufferSize
            
            let minFreq: Float = deltaF
            let maxFreq: Float = sampleRate/2.0

            for i in 1..<Int(halfCount) {
                let freq = (i == 0) ? minFreq : Float(i) * deltaF
                let clampedFreq = max(freq, minFreq)
                let normalizedX = (log10(clampedFreq) - log10(minFreq)) / (log10(maxFreq) - log10(minFreq))
                let x = normalizedX * totalWidth - totalWidth / 2.0
                
                let y = 0.4 * (20 * log10(max(0.0001, data[i])) + 80)
                
                let z: Float = 0.0
                vertices.append(SCNVector3(x, y, z))
            }
            
            // duplicate the vertices but negative to make a reflection
            for i in 1..<Int(halfCount) {
                var v = vertices[Int(halfCount) - i - 1]
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
            geometry.firstMaterial?.diffuse.contents = NSColor.systemBlue
            geometry.firstMaterial?.emission.contents = NSColor.systemBlue.withAlphaComponent(0.1)
            
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
    
    init(url: URL) {
        self.fileURL = url
    }
    
    func start() {
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
            DispatchQueue.main.async {
                slf.fftData = fftData
            }
        }
        fftTap.isNormalized = false
        fftTap.start()
        
        let format = audioPlayer.avAudioNode.outputFormat(forBus: 0)
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
