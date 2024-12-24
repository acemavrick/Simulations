//
//  Gravity.swift
//  Simulations
//
//  Models the gravitational field in a medium with different (point) masses.
//

import SwiftUI
import MetalKit
import Combine

struct GravityView: NSViewRepresentable {
    @ObservedObject var viewModel: GravityViewModel
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self, viewModel: self.viewModel, size: 500)
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // pass
    }
    
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.framebufferOnly = false
        return view
    }
    
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: GravityView
        var viewModel: GravityViewModel
        var commandQueue: MTLCommandQueue?
        var mcState: MTLComputePipelineState?
        var cState: MTLComputePipelineState?
        var colState: MTLComputePipelineState?
        var colCState: MTLComputePipelineState?
        var rpState: MTLRenderPipelineState?
        var uniforms: GravityUniforms
        var masses: [PtMass]
        
        var mBuffer: MTLBuffer?
        var cBuffer: MTLBuffer?
        var field: MTLTexture?
        
        init(_ parent: GravityView, viewModel: GravityViewModel, size s: Int) {
//            fatalError("Gravity Simulation is currently unsafe to execute. Will cause computer to freeze.")
            self.parent = parent
            self.viewModel = viewModel
            self.masses = [
                PtMass(x: 800.0, y: 500.0, mass: 1000.0),
                
                // stable orbit
                PtMass(x: 800.0, y: 100.0, mass: 20.0, vx: 2.2912878475),
                PtMass(x: 800.0, y: 85.0, mass: 0.1, vx: 2.2912878475 + 1.6733200531),
                
                PtMass(x: 800.0, y: 900.0, mass: 20.0, vx: -2.2912878475),
                PtMass(x: 800.0, y: 915.0, mass: 0.1, vx: -2.2912878475 - 1.6733200531),
                
                // unstable
                PtMass(x: 400.0, y: 500.0, mass: 20.0, vy: -1.581),
                PtMass(x: 385.0, y: 500.0, mass: 0.1, vy: -3.226),
                
                PtMass(x: 1200.0, y: 500.0, mass: 20.0, vy: 1.581),
                PtMass(x: 1215.0, y: 500.0, mass: 0.1, vy: 3.226),
                ]
            self.uniforms = GravityUniforms(resolution: [0.0, 0.0], size: [Float(s), Float(s)], dt: 1.0, numMasses: self.masses.count)
            super.init()
            
            setupMetal()
        }
        
        func setupMetal(){
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal is not supported on this device.")
            }
            
            self.commandQueue = device.makeCommandQueue()
            
            let library = device.makeDefaultLibrary()
            let vertexFunction = library?.makeFunction(name: "gravity_vertex")
            let fragmentFunction = library?.makeFunction(name: "gravity_fragment")
            let computeFunction = library?.makeFunction(name: "gravity_field_compute")
            let mcFunction = library?.makeFunction(name: "gravity_mass_compute")
            let colF = library?.makeFunction(name: "gravity_collisions")
            let colC = library?.makeFunction(name: "gravity_collisions_copy")
            
            // render
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            do {
                self.rpState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            } catch {
                fatalError("Unable to compile render pipeline state: \(error)")
            }
            
            // compute
            do {
                self.cState = try device.makeComputePipelineState(function: computeFunction!)
                self.mcState = try device.makeComputePipelineState(function: mcFunction!)
                self.colState = try device.makeComputePipelineState(function: colF!)
                self.colCState = try device.makeComputePipelineState(function: colC!)
            } catch {
                fatalError("Unable to compile compute pipeline state: \(error)")
            }
            
            // set up mBuffer and field
            let mSize = MemoryLayout<PtMass>.stride * self.masses.count
            self.mBuffer = device.makeBuffer(bytes: &self.masses, length: mSize, options: [.storageModeShared])
            self.cBuffer = device.makeBuffer(bytes: &self.masses, length: mSize, options: [.storageModeShared])
            
            initTexture()
        }
        
        func initTexture(){
            let device = MTLCreateSystemDefaultDevice()!
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.pixelFormat = .r32Float
            textureDescriptor.width = Int(self.uniforms.size.x)
            textureDescriptor.height = Int(self.uniforms.size.y)
            textureDescriptor.usage = [.shaderWrite, .shaderRead]
            self.field = device.makeTexture(descriptor: textureDescriptor)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // No additional updates needed for now
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let commandQueue = self.commandQueue,
                  let mBuffer = self.mBuffer,
                  let field = self.field else { return }
            let commandBuffer = commandQueue.makeCommandBuffer()
            uniforms.resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
            if (uniforms.size != uniforms.resolution) {
                uniforms.size = uniforms.resolution
                initTexture()
            }
            
            guard let computeEncoder = commandBuffer?.makeComputeCommandEncoder() else { return }
            computeEncoder.setTexture(field, index: 0)
            computeEncoder.setBytes(&uniforms, length: MemoryLayout<GravityUniforms>.stride, index: 0)
            computeEncoder.setBuffer(mBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(cBuffer, offset: 0, index: 2)
            
            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            
            let threadGroups = MTLSize(
                width: (Int(uniforms.size.x) + threadGroupSize.width - 1) / threadGroupSize.width,
                height: (Int(uniforms.size.y) + threadGroupSize.height - 1) / threadGroupSize.height,
                depth: 1
            )
            
            if (viewModel.play) {
                for _ in 0..<70 {
                    computeEncoder.setComputePipelineState(mcState!)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                    
                    computeEncoder.setComputePipelineState(colState!)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                    
                    computeEncoder.setComputePipelineState(colCState!)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                    
                    computeEncoder.setComputePipelineState(cState!)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                }
            } else {
                computeEncoder.setComputePipelineState(cState!)
                computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
            }
            
            
            computeEncoder.endEncoding()
            
            guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            renderEncoder?.setRenderPipelineState(rpState!)
            renderEncoder?.setFragmentTexture(field, index: 0)
            renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 6)
            renderEncoder?.endEncoding()
            
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}
