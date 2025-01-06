//
//  Gravity.swift
//  Simulations
//
//  Models the gravitational field in a medium with different (point) masses.
//

import SwiftUI
import MetalKit
import Combine

struct GravityController: NSViewRepresentable {
    @ObservedObject var viewModel: GravityViewModel
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self, viewModel: self.viewModel, scale: 0.5)
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
        var parent: GravityController
        var dscale: Float = 1.0
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
        
        init(_ parent: GravityController, viewModel: GravityViewModel, scale: Float) {
            self.parent = parent
            self.viewModel = viewModel
            self.masses = []
            self.uniforms = GravityUniforms(screen_resolution: [0.0, 0.0], units_per_pixel: scale, dt: 1.0, numMasses: self.masses.count)
            masses.append(PtMass(x: 100, y: 100, mass: 1000))
            self.uniforms.numMasses = self.masses.count
            super.init()
            
            syncViewModel()
            setupMetal()
        }
        
        func addMass(_ mass: PtMass) {
            var newMass = mass
            self.masses.append(mass)
            // need to update buffer, while preserving current content
            let device = MTLCreateSystemDefaultDevice()!
            let mSize = MemoryLayout<PtMass>.stride * self.masses.count
            
            let newMBuffer = device.makeBuffer(length: mSize, options: [.storageModeShared])
            newMBuffer?.contents().copyMemory(from: self.mBuffer!.contents(), byteCount: self.mBuffer!.length)
            // add new mass to mBuffer
            newMBuffer?.contents().advanced(by: MemoryLayout<PtMass>.stride * (self.masses.count-1)).copyMemory(from: &newMass, byteCount: MemoryLayout<PtMass>.stride)
            self.mBuffer = newMBuffer
            
            let cBuffer = device.makeBuffer(length: mSize, options: [.storageModeShared])
            cBuffer?.contents().copyMemory(from: self.cBuffer!.contents(), byteCount: self.cBuffer!.length)
            // add new mass to cBuffer
            cBuffer?.contents().advanced(by: MemoryLayout<PtMass>.stride * (self.masses.count-1)).copyMemory(from: &newMass, byteCount: MemoryLayout<PtMass>.stride)
            self.cBuffer = cBuffer
            
            uniforms.addMass()
            print("added mass")
        }
        
        func syncViewModel() {
            let unis = self.uniforms
            let viewModel = self.viewModel
            let slf = self
            DispatchQueue.main.async {
                if (viewModel.tapLocation != nil) {
                    print("detected tap at \(viewModel.tapLocation!)")
                    let tap = viewModel.tapLocation!
                    slf.addMass(PtMass(x: Float(tap.x) * slf.dscale * unis.scale, y: Float(tap.y) * self.dscale * unis.scale, mass: 1000))
                    viewModel.tapLocation = nil
                }
                viewModel.numMasses = unis.numMasses
                viewModel.resolution = unis.resolution
                viewModel.scale = unis.scale
                viewModel.dimensions = unis.resolution*unis.scale
                viewModel.G = unis.G
                viewModel.dt = unis.dt
                viewModel.collisionDist = unis.collisionDist
            }
        }
        
        func setupMetal() {
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
        }
        
        func initTexture(){
            let device = MTLCreateSystemDefaultDevice()!
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.pixelFormat = .r32Float
            textureDescriptor.width = Int(self.uniforms.resolution.x)
            textureDescriptor.height = Int(self.uniforms.resolution.y)
            textureDescriptor.usage = [.shaderWrite, .shaderRead]
            self.field = device.makeTexture(descriptor: textureDescriptor)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // No additional updates needed for now
        }
        
        func draw(in view: MTKView) {
            if (uniforms.setResolution(view.drawableSize)) {
                // changed
                initTexture()
            }
            syncViewModel()
            
            guard let drawable = view.currentDrawable,
                  let commandQueue = self.commandQueue,
                  let mBuffer = self.mBuffer,
                  let field = self.field else { return }

            let commandBuffer = commandQueue.makeCommandBuffer()
            
            guard let computeEncoder = commandBuffer?.makeComputeCommandEncoder() else { return }
            
            computeEncoder.setTexture(field, index: 0)
            computeEncoder.setBytes(&uniforms, length: MemoryLayout<GravityUniforms>.stride, index: 0)
            computeEncoder.setBuffer(mBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(cBuffer, offset: 0, index: 2)
            
            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            
            let threadGroups = MTLSize(
                width: (Int(uniforms.resolution.x) + threadGroupSize.width - 1) / threadGroupSize.width,
                height: (Int(uniforms.resolution.y) + threadGroupSize.height - 1) / threadGroupSize.height,
                depth: 1
            )
            
            if (viewModel.play) {
                    computeEncoder.setComputePipelineState(mcState!)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                    
                    computeEncoder.setComputePipelineState(colState!)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                    
                    computeEncoder.setComputePipelineState(colCState!)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                    
                    computeEncoder.setComputePipelineState(cState!)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
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
