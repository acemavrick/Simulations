//
//  WaveSimulation.swift
//  Simulations
//
//
//  A 2D wave equation simulation, using the finite difference method.

import SwiftUI
import MetalKit
import Combine

struct WaveController: NSViewRepresentable {
    @ObservedObject var model: WaveModel
    
    func makeCoordinator() -> WaveCoordinator {
        WaveCoordinator(self, model: self.model, size: 1000, dx: 0.0005, dt: 0.00005, c: 4.0)
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // nothing so far
    }
    
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero)
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.framebufferOnly = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    class WaveCoordinator: NSObject, MTKViewDelegate {
        var model: WaveModel
        var parent: WaveController
        var uniforms: WaveUniforms
        var cancellables: Set<AnyCancellable> = []
        var startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

        var device_scale: CGFloat = 1.0
        var sizeChangeTimer: Timer?
        var sizeChangeTime: TimeInterval = 0.1
        var size: SIMD2<Float>
        
        var commandQueue: MTLCommandQueue?
        var renderPipelineState: MTLRenderPipelineState?
        var blankPipelineState: MTLRenderPipelineState?
        var computePipelineState: MTLComputePipelineState?
        var copyPipelineState: MTLComputePipelineState?

        var u_prev: MTLBuffer?
        var u_curr: MTLBuffer?
        var u_next: MTLBuffer?
        var upPtr: UnsafeMutablePointer<SIMD2<Float>>?
        var ucPtr: UnsafeMutablePointer<SIMD2<Float>>?
        var unPtr: UnsafeMutablePointer<SIMD2<Float>>?
        
        
        var lastFrameTime: CFTimeInterval = 1.0
        var fps: Double = 0.0
        var fpsFrameCount: Int = 0
        var fpsMaxFrames: Int = 30
        
        var rpf: Int = 5
        var rpfFrameCount: Int = 0
        var avgHeadroom: Double = 0.0
        var headroom: Double = 0.0
        let frameBudget: Double = 1.0/60.0 // 60 FPS target
        
        /// # Explanation for Dynamic RPF
        ///  Each frame, the simulation is computed a certain number of times, `rpf` (renders per frame). By multiplying RPF and FPS,
        ///  we can get the "effective FPS" – the actual amount of times the simulation computes each second. The RPF significantly affects
        ///  the FPS of the sim: if it is too high, performance takes a hit and FPS drops. This is not ideal. To fix this, we attempt to dynamically
        ///  change the RPF to approach the most we can while staying at a stable 60 FPS.
        ///  One way to do this is to calculate the GPU headroom (time left in a frame) per frame and adjust RPF so that it is minimized. However,
        ///  this approach results in the RPF changing almost every frame and a rapid variation of speed in the simulation's waves- an effect
        ///  visually similar to low FPS and quite disturbing.
        ///  An alternative to that is to take measurements over a range of frames, so that we
        ///  adjust the RPF every N frames, which slows down the oscillation. The downside of this is that we reduce the reactivity of the process,
        ///  meaning that rapid changes in optimal RPF result in large times when the user has to deal with bad FPS. **We use this method to
        ///  calculate the FPS.**

        
        init(_ parent: WaveController, model: WaveModel, size s: Float, dx: Float = 1, dt: Float = 0.01, c: Float = 1) {
            self.parent = parent
            self.model = model
            self.size = SIMD2<Float>(s, s)
            self.uniforms = WaveUniforms(dx: dx, dt: dt, c: c,
                                         resolution: SIMD2<Float>(0, 0))
            super.init()
            observeViewModel()
            setupMetalResources()
        }
        
        func syncViewModel() {
            let unis = self.uniforms
            let slf = self
            let viewModel = self.model
            DispatchQueue.main.async {
                viewModel.dx = unis.dx
                viewModel.dt = unis.dt
                viewModel.c = unis.c
                viewModel.dampening = unis.damper
                viewModel.resolution = unis.resolution
                viewModel.FPS = slf.fps
                viewModel.RPF = Double(slf.rpf)
            }
        }
        
        func observeViewModel() {
            model.$RPF
                .sink { value in
                    self.rpf = Int(value)
                }
                .store(in: &cancellables)
            
            model.$tapValue
                .sink { value in
                    guard let value = value else { return }
                    let x = value.location.x * self.device_scale
                    let y = value.location.y * self.device_scale
                    let shiftClicked = NSEvent.modifierFlags.contains(.shift)
                    if shiftClicked {
                        self.gaussianPulse(x: Int(x), y: Int(y), r: 20, stdev: 0.0, isBlock: true)
                    } else {
                        self.gaussianPulse(x: Int(x), y: Int(y), r: 8)
                    }
                }
                .store(in: &cancellables)
            
            model.$dragValue
                .sink { value in
                    guard let value = value else { return }
                    let x = value.location.x * self.device_scale
                    let y = value.location.y * self.device_scale
                    let shiftClicked = NSEvent.modifierFlags.contains(.shift)
                    if shiftClicked {
                        self.gaussianPulse(x: Int(x), y: Int(y), r: 20, stdev: 0.0, isBlock: true)
                    } else {
                        self.gaussianPulse(x: Int(x), y: Int(y), r: 8)
                    }
                }
                .store(in: &cancellables)
        }
        
        func setupMetalResources() {
            // init the device
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal is not supported on this device.")
            }
            
            self.commandQueue = device.makeCommandQueue()
            
            let library = device.makeDefaultLibrary()
            
            // make the functions
            guard let kernelFunction = library?.makeFunction(name: "wave_compute"),
                  let copyFunction = library?.makeFunction(name: "wave_copy") else {
                fatalError("Unable to load compute function")
            }
            guard let vertexFunction = library?.makeFunction(name: "wave_vertex") else {
                fatalError("Unable to load vertex function")
            }
            guard let fragmentFunction = library?.makeFunction(name: "wave_fragment"),
                  let blankFunction = library?.makeFunction(name: "wave_fragment_blank") else {
                fatalError("Unable to load fragment functions")
            }
            
            // set up render pipeline
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            let blankDescriptor = MTLRenderPipelineDescriptor()
            blankDescriptor.vertexFunction = vertexFunction
            blankDescriptor.fragmentFunction = blankFunction
            blankDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            do {
                self.renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
                self.blankPipelineState = try device.makeRenderPipelineState(descriptor: blankDescriptor)
            } catch {
                fatalError("Unable to compile render pipeline state: \(error)")
            }
            
            // set up compute pipeline
            do {
                self.computePipelineState = try device.makeComputePipelineState(function: kernelFunction)
                self.copyPipelineState = try device.makeComputePipelineState(function: copyFunction)
            } catch {
                fatalError("Unable to compile compute pipeline state: \(error)")
            }
        }
        
        func initBuffers() {
            let bufferSize = Int(size.x * size.y) * MemoryLayout<SIMD2<Float>>.stride
            
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal device not available.")
            }
            u_prev = device.makeBuffer(length: bufferSize, options: .storageModeShared)
            u_curr = device.makeBuffer(length: bufferSize, options: .storageModeShared)
            u_next = device.makeBuffer(length: bufferSize, options: .storageModeShared)
            
            // clear the buffers
            let xTimesY = Int(size.x * size.y)
            
            self.upPtr = u_prev?.contents().bindMemory(to: SIMD2<Float>.self, capacity: xTimesY)
            self.ucPtr = u_curr?.contents().bindMemory(to: SIMD2<Float>.self, capacity: xTimesY)
            self.unPtr = u_next?.contents().bindMemory(to: SIMD2<Float>.self, capacity: xTimesY)
            
            let defval = SIMD2<Float>(0.0, 1.0)
            
            for i in 0..<xTimesY {
                upPtr?[i] = defval
                ucPtr?[i] = defval
            }
            
            for i in 0..<xTimesY {
                unPtr?[i] = upPtr?[i] ?? defval
            }
            
            if u_prev == nil || u_curr == nil || u_next == nil {
                fatalError("Could not create buffers")
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // pausing the sim makes sense since we reset pretty much everything when resized
            let m = model
            DispatchQueue.main.async {
                m.play = false
                m.visible = false
            }
            sizeChangeTimer?.invalidate()
            sizeChangeTimer = Timer.scheduledTimer(withTimeInterval: sizeChangeTime, repeats: false) { _ in
                self.device_scale = view.window!.backingScaleFactor
                
                // resize
                self.size = SIMD2<Float>(Float(size.width), Float(size.height))
                self.uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
                
                self.initBuffers()
                
                // reset rps values
                self.rpfFrameCount = 0
                self.avgHeadroom = 0.0
                m.visible = true
            }
        }
        
        
        func ring(x: Int, y: Int, a: Float = 1.0, rOuter: Int, rInner: Int) {
            // make a ring
            for i in -rOuter...rOuter {
                for j in -rOuter...rOuter {
                    let xi = x + i
                    let yj = y + j
                    if 0 <= xi && xi < Int(size.x) && 0 <= yj && yj < Int(size.y) {
                        let distanceSquared = Float(i * i + j * j)
                        if distanceSquared <= Float(rOuter * rOuter) && distanceSquared >= Float(rInner * rInner) {
                            u_curr?.contents().bindMemory(to: Float.self, capacity: Int(size.x * size.y))[xi + yj * Int(size.x)] = a
                        }
                    }
                }
            }
        }
        
        func gaussianPulse(x: Int, y: Int, r: Int, stdev: Float = 0.0, a: Float = 1.0, isBlock: Bool = false) {
            // make a pulse centered at x, y with standard deviation stdev
            guard let ucptr = self.ucPtr else { return }
            let sigma = (stdev <= 0.0) ? Float(r) / 3 : stdev
            
            for i in -r...r {
                for j in -r...r {
                    let xi = x + i
                    let yj = y + j
                    if 0 <= xi && xi < Int(size.x) && 0 <= yj && yj < Int(size.y) {
                        let distanceSquared = Float(i * i + j * j)
                        if distanceSquared <= Float(r * r) {
                            if isBlock {
                                ucptr[xi + yj * Int(size.x)].y = 0.0
                            } else {
                                ucptr[xi + yj * Int(size.x)].x = a * exp(-distanceSquared / (2 * sigma * sigma))
                            }
                        }
                    }
                }
            }
        }

        func gaussianPulseAsync(x: Int, y: Int, r: Int, stdev: Float = 0.0, a: Float = 1.0, isBlock: Bool = false) async {
            // make a pulse centered at x, y with standard deviation stdev
            guard let ucptr = self.ucPtr else { return }
            let sigma = (stdev <= 0.0) ? Float(r) / 2 : stdev
            let range = -r...r
            let totalTasks = ProcessInfo.processInfo.activeProcessorCount
            let step = range.count / totalTasks
            
            func processRange(start: Int, end: Int) {
                for i in start...end {
                    for j in range {
                        let xi = x + i
                        let yj = y + j
                        if 0 <= xi && xi < Int(size.x) && 0 <= yj && yj < Int(size.y) {
                            let distanceSquared = Float(i * i + j * j)
                            if distanceSquared <= Float(r * r) {
                                if isBlock {
                                    ucptr[xi + yj * Int(size.x)].y = 0.0
                                } else {
                                    ucptr[xi + yj * Int(size.x)].x = a * exp(-distanceSquared / (2 * sigma * sigma))
                                }
                            }
                        }
                    }
                }
            }
            
            await withTaskGroup(of: Void.self) { group in
                for ti in 0..<totalTasks {
                    group.addTask {
                        let start = range.lowerBound + ti * step
                        let end = ti == totalTasks - 1 ? range.upperBound : start + step
                        processRange(start: start, end: end)
                    }
                }
            }
        }
        
        func draw(in view: MTKView) {
            fpsFrameCount += 1
            rpfFrameCount += 1

            // calculate FPS
            if (fpsFrameCount == fpsMaxFrames) {
                let ctime = CACurrentMediaTime()
                let dtime = ctime-lastFrameTime
                self.fps = Double(fpsMaxFrames)/(dtime)
                lastFrameTime = ctime
                fpsFrameCount = 0
            }

            if (model.play && model.dynamicRPF) {
                if (self.avgHeadroom <= -0.001) {
                    self.avgHeadroom = 0
                    self.rpf -= 1
                }
                if (self.avgHeadroom >=  0.001) {
                    self.avgHeadroom = 0
                    self.rpf += 1
                }
            }
            
            self.rpf = max(1, self.rpf)

            guard let drawable = view.currentDrawable,
                  let commandQueue = self.commandQueue,
                  let u_p = self.u_prev,
                  let u_c = self.u_curr,
                  let u_n = self.u_next else { return }
            
            let commandBuffer = commandQueue.makeCommandBuffer()
            uniforms.time = Float(CFAbsoluteTimeGetCurrent()-startTime)
            uniforms.resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
            syncViewModel()

            // Compute Pass
            if model.play {
                // only compute if simulation is running
                guard let computeEncoder = commandBuffer?.makeComputeCommandEncoder() else { return }
                
                computeEncoder.setBuffer(u_p, offset: 0, index: 0)
                computeEncoder.setBuffer(u_c, offset: 0, index: 1)
                computeEncoder.setBuffer(u_n, offset: 0, index: 2)
                computeEncoder.setBytes(&uniforms, length: MemoryLayout<WaveUniforms>.stride, index: 3)
                
                let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
                
                let threadGroups = MTLSize(
                    width: (Int(size.x) + threadGroupSize.width - 1) / threadGroupSize.width,
                    height: (Int(size.y) + threadGroupSize.height - 1) / threadGroupSize.height,
                    depth: 1
                )
                
                for _ in 0..<self.rpf {
                    computeEncoder.setComputePipelineState(self.computePipelineState!)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                    
                    computeEncoder.setComputePipelineState(self.copyPipelineState!)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                }
                
                computeEncoder.endEncoding()
            }
            
            // Render Pass
            guard let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
                  let rPipelineState = self.renderPipelineState,
                  let bPipelineState = self.blankPipelineState else { return }
            
            if model.visible {
                renderEncoder.setRenderPipelineState(rPipelineState)
            } else {
                renderEncoder.setRenderPipelineState(bPipelineState)
            }
            
            let u = u_curr
            renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<WaveUniforms>.stride, index: 0)
            renderEncoder.setFragmentBuffer(u, offset: 0, index: 1)
            
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            // commit
            commandBuffer?.addCompletedHandler { commandBuffer in
                // compute headroom
                let headroom = self.frameBudget - commandBuffer.gpuEndTime + commandBuffer.gpuStartTime
                
                // add current headroom to average
                self.avgHeadroom += (headroom - self.avgHeadroom) / Double(self.rpfFrameCount)
            }
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}
