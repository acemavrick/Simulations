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
    @ObservedObject var viewModel: WaveViewModel
    
    func makeCoordinator() -> WaveCoordinator {
        WaveCoordinator(self, viewModel: self.viewModel, size: 1000, dx: 0.0005, dt: 0.00005, c: 4.0)
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
        var device_scale: CGFloat = 1.0
        var sizeChangeTimer: Timer?
        var sizeChangeTime: TimeInterval = 0.2
        var viewModel: WaveViewModel
        var parent: WaveController
        var commandQueue: MTLCommandQueue?
        var renderPipelineState: MTLRenderPipelineState?
        var size: SIMD2<Float>
        var uniforms: WaveUniforms
        var computePipelineState: MTLComputePipelineState?
        var copyPipelineState: MTLComputePipelineState?
        var startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        var u_prev: MTLBuffer?
        var u_curr: MTLBuffer?
        var u_next: MTLBuffer?
        var upPtr: UnsafeMutablePointer<Float>?
        var ucPtr: UnsafeMutablePointer<Float>?
        var unPtr: UnsafeMutablePointer<Float>?
        var cancellables: Set<AnyCancellable> = []
        
        init(_ parent: WaveController, viewModel: WaveViewModel, size s: Float, dx: Float = 1, dt: Float = 0.01, c: Float = 1) {
            self.parent = parent
            self.viewModel = viewModel
            self.size = SIMD2<Float>(s, s)
            self.uniforms = WaveUniforms(dx: dx, dt: dt, c: c,
                                            resolution: SIMD2<Float>(0, 0),
                                            simSize: size)
            super.init()
            self.observeViewModel()
            setupMetalResources()
        }
        
        func syncViewModel() {
            let unis = self.uniforms
            let viewModel = self.viewModel
            DispatchQueue.main.async {
                viewModel.dx = unis.dx
                viewModel.dt = unis.dt
                viewModel.c = unis.c
                viewModel.dampening = unis.damper
                viewModel.resolution = unis.resolution
            }
        }
        
        func observeViewModel() {
            // subscribe to tapLocation
            viewModel.$tapLocation
                .sink { [weak self] location in
                    guard let self=self else { return }
                    guard let location=location else { return }
                    print("tap at \(location)")
                    let x = location.x * self.device_scale
                    let y = location.y * self.device_scale
                    gaussianPulse(x: Int(x), y: Int(y), r: 5)
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
            guard let fragmentFunction = library?.makeFunction(name: "wave_fragment_grey") else {
                fatalError("Unable to load fragment function")
            }
            
            // set up render pipeline
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            do {
                self.renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
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
            let bufferSize = Int(size.x * size.y) * MemoryLayout<Float>.stride
            
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal device not available.")
            }
            u_prev = device.makeBuffer(length: bufferSize, options: .storageModeShared)
            u_curr = device.makeBuffer(length: bufferSize, options: .storageModeShared)
            u_next = device.makeBuffer(length: bufferSize, options: .storageModeShared)
            
            // Clear the buffers
            let xTimesY = Int(size.x * size.y)
            self.upPtr = u_prev?.contents().bindMemory(to: Float.self, capacity: xTimesY)
            self.ucPtr = u_curr?.contents().bindMemory(to: Float.self, capacity: xTimesY)
            self.unPtr = u_next?.contents().bindMemory(to: Float.self, capacity: xTimesY)
            
            for i in 0..<xTimesY {
                upPtr?[i] = 0.0
                ucPtr?[i] = 0.0
            }
            
            for i in 0..<xTimesY {
                unPtr?[i] = upPtr?[i] ?? 0.0
            }
            
            if u_prev == nil || u_curr == nil || u_next == nil {
                fatalError("Could not create buffers")
            }

        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            sizeChangeTimer?.invalidate()
            sizeChangeTimer = Timer.scheduledTimer(withTimeInterval: sizeChangeTime, repeats: false) { _ in
                self.device_scale = view.window!.backingScaleFactor
                self.resize(size: size)
            }
        }
        
        func resize(size: CGSize) {
            print("resizing to \(size)")
            let runstate = viewModel.play
            viewModel.play = false
            self.size = SIMD2<Float>(Float(size.width), Float(size.height))
            uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
            uniforms.simSize = uniforms.resolution
            initBuffers()
            viewModel.play = runstate
        }
        
        func ring(x: Int, y: Int, a: Float = 1.0, rOuter: Int, rInner: Int) {
            // make a ring
            for i in -rOuter...rOuter {
                for j in -rOuter...rOuter {
                    let xi = Int(x) + i
                    let yj = Int(y) + j
                    if 0 <= xi && xi < Int(size.x) && 0 <= yj && yj < Int(size.y) {
                        let distanceSquared = Float(i * i + j * j)
                        if distanceSquared <= Float(rOuter * rOuter) && distanceSquared >= Float(rInner * rInner) {
                            u_curr?.contents().bindMemory(to: Float.self, capacity: Int(size.x * size.y))[xi + yj * Int(size.x)] = a
                        }
                    }
                }
            }
        }
        
        func gaussianPulse(x: Int, y: Int, r: Int, stdev: Float = 0.0, a: Float = 1.0) {
            // make a pulse centered at x, y with standard deviation stdev
            guard let ucptr = self.ucPtr else { return }
            
            let sigma = (stdev <= 0.0) ? Float(r) / 2 : stdev
            for i in -r...r {
                for j in -r...r {
                    let xi = Int(x) + i
                    let yj = Int(y) + j
                    if 0 <= xi && xi < Int(size.x) && 0 <= yj && yj < Int(size.y) {
                        let distanceSquared = Float(i * i + j * j)
                        if distanceSquared <= Float(r * r) {
                            ucptr[xi + yj * Int(size.x)] = a * exp(-distanceSquared / (2 * sigma * sigma))
                        }
                    }
                }
            }
            print("gaussian pulse at \(x), \(y)")
        }
        
        func draw(in view: MTKView) {
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
            if viewModel.play {
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
                
                for _ in 0..<5 {
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
                  let rPipelineState = self.renderPipelineState else { return }
            
            renderEncoder.setRenderPipelineState(rPipelineState)
            
            // update uniform
            
            let u = u_curr
            renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<WaveUniforms>.stride, index: 0)
            renderEncoder.setFragmentBuffer(u, offset: 0, index: 1)
            
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            // commit
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}
