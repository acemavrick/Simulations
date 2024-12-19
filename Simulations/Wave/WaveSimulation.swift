//
//  WaveSimulation.swift
//  Simulations
//
//
//  A 2D wave equation simulation, using the finite difference method.

import SwiftUI
import MetalKit
import MetalPerformanceShaders

struct WaveSimulationView: NSViewRepresentable {
    
    func makeCoordinator() -> WaveCoordinator {
        WaveCoordinator(self, size: 1000, dx: 0.0005, dt: 0.00005, c: 4.0)
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // nothing so far
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.framebufferOnly = false
        return view
    }
    
    func pause() {
        Coordinator.isRunning = false
    }
    
    func play() {
        Coordinator.isRunning = true
    }
    
    func runningState() -> Bool {
        return Coordinator.isRunning
    }
    
    class WaveCoordinator: NSObject, MTKViewDelegate {
        var parent: WaveSimulationView
        var commandQueue: MTLCommandQueue?
        var renderPipelineState: MTLRenderPipelineState?
        var size: SIMD2<Float>
        var uniforms: WaveSimUniforms
        var computePipelineState: MTLComputePipelineState?
        var copyPipelineState: MTLComputePipelineState?
        var u_tot: MTLTexture?
        var laplacian: MTLTexture?
        var image_convolver: MPSImageConvolution?
        
        // for the compute function, u_tot will be read from and u_next will be written to
        // for the copy function, u_next will be used to write to u_tot
        
        static var isRunning = false
        
        init(_ parent: WaveSimulationView, size s: Float, dx: Float = 1, dt: Float = 0.01, c: Float = 1) {
            self.parent = parent
            self.size = SIMD2<Float>(s, s)
            self.uniforms = WaveSimUniforms(dx: dx, dt: dt, c: c,
                                            resolution: SIMD2<Float>(0, 0),
                                            simSize: size)
            super.init()
            
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
            guard let fragmentFunction = library?.makeFunction(name: "wave_fragment") else {
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
            
            // initialize textures
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.pixelFormat = .rgba32Float
            textureDescriptor.width = Int(size.x)
            textureDescriptor.height = Int(size.y)
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            self.u_tot = device.makeTexture(descriptor: textureDescriptor)
            self.laplacian = device.makeTexture(descriptor: textureDescriptor)
            
            // populate everything with 0s
            let region = MTLRegionMake2D(0, 0, Int(size.x), Int(size.y))
            let zeroData = [Float](repeating: 0, count: Int(size.x) * Int(size.y))
            self.laplacian?.replace(region: region, mipmapLevel: 0, withBytes: zeroData, bytesPerRow: Int(size.x) * MemoryLayout<Float>.stride * 4)
            
            let centerRegion = MTLRegionMake2D(Int(size.x) / 2 - 10, Int(size.y) / 2 - 10, 20, 20)
            let disturbanceData = [Float](repeating: 10, count: 20 * 20 * 4) // 4 channels
            self.u_tot?.replace(
                region: centerRegion,
                mipmapLevel: 0,
                withBytes: disturbanceData,
                bytesPerRow: 20 * MemoryLayout<Float>.stride * 4
            )
            
            //            gaussianPulse(x: Int(size.x) / 2, y: Int(size.y) / 2, r: 20, a: 4.0)
            //            ring(x: Int(size.x) / 2, y: Int(size.y) / 2, a: 4.0, rOuter: 400, rInner: 380)
            
            // set up compute pipeline
            do {
                self.computePipelineState = try device.makeComputePipelineState(function: kernelFunction)
                self.copyPipelineState = try device.makeComputePipelineState(function: copyFunction)
            } catch {
                fatalError("Unable to compile compute pipeline state: \(error)")
            }
            
            let weights =
            [0, 1, 0,
            1, -4, 1,
            0, 1, 0]
                .map({ Float($0) })
            self.image_convolver = MPSImageConvolution(device: device, kernelWidth: 3, kernelHeight: 3, weights: weights)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // size changes
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
//                            u_curr?.contents().bindMemory(to: Float.self, capacity: Int(size.x * size.y))[xi + yj * Int(size.x)] = a
                        }
                    }
                }
            }
        }
        
        func gaussianPulse(x: Int, y: Int, r: Int, stdev: Float = 0.0, a: Float = 1.0) {
            // make a pulse centered at x, y with standard deviation stdev
            let sigma = (stdev <= 0.0) ? Float(r) / 2 : stdev
            for i in -r...r {
                for j in -r...r {
                    let xi = Int(x) + i
                    let yj = Int(y) + j
                    if 0 <= xi && xi < Int(size.x) && 0 <= yj && yj < Int(size.y) {
                        let distanceSquared = Float(i * i + j * j)
                        if distanceSquared <= Float(r * r) {
//                            u_curr?.contents().bindMemory(to: Float.self, capacity: Int(size.x * size.y))[xi + yj * Int(size.x)] = a * exp(-distanceSquared / (2 * sigma * sigma))
                        }
                    }
                }
            }
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let commandQueue = self.commandQueue,
                  let u_tot = self.u_tot,
                  let imConv = self.image_convolver,
                  let lap = self.laplacian else {return}
                
            let commandBuffer = commandQueue.makeCommandBuffer()

            // Compute Pass
            if Coordinator.isRunning {
                imConv.encode(commandBuffer: commandBuffer!, sourceTexture: u_tot, destinationTexture: lap)
                
                // only compute if simulation is running
                guard let computeEncoder = commandBuffer?.makeComputeCommandEncoder() else { return }
                
                computeEncoder.setComputePipelineState(self.computePipelineState!)
                
                computeEncoder.setTexture(u_tot, index: 0)
                computeEncoder.setTexture(lap, index: 1)
                computeEncoder.setBytes(&uniforms, length: MemoryLayout<WaveSimUniforms>.stride, index: 0)
                
                let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
                
                let threadGroups = MTLSize(
                    width: (Int(size.x) + threadGroupSize.width - 1) / threadGroupSize.width,
                    height: (Int(size.y) + threadGroupSize.height - 1) / threadGroupSize.height,
                    depth: 1
                )
                
                computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                
                computeEncoder.setComputePipelineState(self.copyPipelineState!)
                computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                computeEncoder.endEncoding()
            }
            
            // Render Pass
            guard let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
                  let rPipelineState = self.renderPipelineState else { return }
            
            renderEncoder.setRenderPipelineState(rPipelineState)
            
            // update uniform
            self.uniforms.resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
            
            renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<WaveSimUniforms>.stride, index: 0)
            renderEncoder.setFragmentTexture(u_tot, index: 0)
            
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            // commit
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}

struct WaveSimUniforms {
    var dx: Float
    var dt: Float
    var c: Float
    var resolution: SIMD2<Float>
    var simSize: SIMD2<Float>
    
    // colormap coefficients
    var c0, c1, c2, c3, c4, c5, c6: SIMD3<Float>
    
    init(dx: Float, dt: Float, c: Float, resolution: SIMD2<Float>, simSize: SIMD2<Float>) {
        self.dx = dx
        self.dt = dt
        self.c = c
        
        self.resolution = resolution
        self.simSize = simSize

        // viridis
        self.c0 = SIMD3<Float>(0.274344,0.004462,0.331359)
        self.c1 = SIMD3<Float>(0.108915,1.397291,1.388110)
        self.c2 = SIMD3<Float>(-0.319631,0.243490,0.156419)
        self.c3 = SIMD3<Float>(-4.629188,-5.882803,-19.646115)
        self.c4 = SIMD3<Float>(6.181719,14.388598,57.442181)
        self.c5 = SIMD3<Float>(4.876952,-13.955112,-66.125783)
        self.c6 = SIMD3<Float>(-5.513165,4.709245,26.582180)
    }
}
