//
//  ESController.swift
//  Simulations
//
//

import Foundation

import SwiftUI
import MetalKit
import Combine

struct ESController: NSViewRepresentable {
    @ObservedObject var model: ESModel
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self, model: self.model, scale: 1.0)
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
        var parent: ESController
        var dscale: Float = 1.0
        var model: ESModel
        var uniforms: ESUniforms
        var charges: [Charge]

        var renderState: MTLRenderPipelineState?
        var commandQueue: MTLCommandQueue?
        var computeState: MTLComputePipelineState?
        var fieldState: MTLComputePipelineState?
        var cancellables: Set<AnyCancellable> = []
        
        var chargeBuffer: MTLBuffer?
        var field: MTLTexture?
        
        init(_ parent: ESController, model: ESModel, scale: Float) {
            self.parent = parent
            self.model = model
            self.charges = []
            self.uniforms = ESUniforms(screen_resolution: [0.0, 0.0], units_per_pixel: scale, dt: 1.0, numCharges: self.charges.count)
            charges.append(Charge(x: 100, y: 100, charge: +1.0))
            charges.append(Charge(x: 150, y: 150, charge: +1.0))
            charges.append(Charge(x: 500, y: 500, charge: +1.0))
            charges.append(Charge(x: 200, y: 400, charge: -1.0))
            charges.append(Charge(x: 400, y: 200, charge: -1.0))
            self.uniforms.numCharges = self.charges.count
            super.init()
            
            observeViewModel()
            syncViewModel()
            setupMetal()
        }
        
        func addCharge(_ charge: Charge) {
            var ncharge = charge
            self.charges.append(ncharge)
            // need to update buffer, while preserving current content
            let device = MTLCreateSystemDefaultDevice()!
            let mSize = MemoryLayout<Charge>.stride * self.charges.count
            
            let newChargeBuffer = device.makeBuffer(length: mSize, options: [.storageModeShared])
            newChargeBuffer?.contents().copyMemory(from: self.chargeBuffer!.contents(), byteCount: self.chargeBuffer!.length)
            newChargeBuffer?.contents().advanced(by: MemoryLayout<Charge>.stride * (self.charges.count-1)).copyMemory(from: &ncharge, byteCount: MemoryLayout<Charge>.stride)
            self.chargeBuffer = newChargeBuffer
            uniforms.addCharge()
        }
        
        func circleOcharge(_ charge: Charge, radius: Float, num: Int) {
            let theta = 2.0 * Float.pi / Float(num)
            for i in 0..<num {
                let x = charge.position.x + radius * cos(Float(i) * theta)
                let y = charge.position.y + radius * sin(Float(i) * theta)
                let ncharge = Charge(x: x, y: y, charge: charge.charge, fixed: charge.fixed)
                self.charges.append(ncharge)
            }
            
            let device = MTLCreateSystemDefaultDevice()!
            let mSize = MemoryLayout<Charge>.stride * self.charges.count
            let newChargeBuffer = device.makeBuffer(length: mSize, options: [.storageModeShared])
            newChargeBuffer?.contents().copyMemory(from: self.chargeBuffer!.contents(), byteCount: self.chargeBuffer!.length)
            for i in 0..<num {
                var ncharge = self.charges[self.charges.count - num + i]
                newChargeBuffer?.contents().advanced(by: MemoryLayout<Charge>.stride * (self.charges.count - num + i)).copyMemory(from: &ncharge, byteCount: MemoryLayout<Charge>.stride)
            }
            self.chargeBuffer = newChargeBuffer
            uniforms.addCharge(count: num)
        }
            
        func syncViewModel() {
            let unis = self.uniforms
            let viewModel = self.model
            DispatchQueue.main.async {
                viewModel.numCharges = unis.numCharges
                viewModel.resolution = unis.resolution
                viewModel.scale = unis.scale
                viewModel.dimensions = unis.resolution*unis.scale
                viewModel.k = unis.k
                viewModel.dt = unis.dt
            }
        }
        
        func observeViewModel() {
            model.$tapValue
                .sink { value in
                    guard let value = value else { return }
                    let location = value.location
                    let x = Float(location.x) * self.uniforms.scale * self.dscale
                    let y = Float(location.y) * self.uniforms.scale * self.dscale
                    let sign = NSEvent.modifierFlags.contains(.shift)
                    let fixed = NSEvent.modifierFlags.contains(.option)
                    let intense = NSEvent.modifierFlags.contains(.control)
                    let charge = (sign ? -1.0 : +1.0) * (intense ? 10.0 : 1.0)
                    if (NSEvent.modifierFlags.contains(.command)) {
                        self.circleOcharge(Charge(x: x, y: y, charge: Float(charge), fixed: fixed), radius: 90.0 * (intense ? 4.0 : 1.0), num: 20)
                    } else {
                        self.addCharge(Charge(x: x, y: y, charge: Float(charge), fixed: fixed))
                    }
                }
                .store(in: &cancellables)
            
            model.$dragValue
                .sink { value in
                    guard let value = value else { return }
                    let location = value.location
                    let x = Float(location.x) * self.uniforms.scale * self.dscale
                    let y = Float(location.y) * self.uniforms.scale * self.dscale
                    let sign = NSEvent.modifierFlags.contains(.shift)
                    let fixed = NSEvent.modifierFlags.contains(.option)
                    let intense = NSEvent.modifierFlags.contains(.control)
                    let charge = (sign ? -1.0 : +1.0) * (intense ? 10.0 : 1.0)
                    self.addCharge(Charge(x: x, y: y, charge: Float(charge), fixed: fixed))
                }
                .store(in: &cancellables)
        }

        func setupMetal() {
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal is not supported on this device.")
            }
            
            self.commandQueue = device.makeCommandQueue()
            
            let library = device.makeDefaultLibrary()
            let vertexFunction = library?.makeFunction(name: "es_vertex")
            let fieldFunction = library?.makeFunction(name: "es_field_compute")
            let computeFunction = library?.makeFunction(name: "es_charge_compute")
            let fragmentFunction = library?.makeFunction(name: "es_fragment")

            // render
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            do {
                self.renderState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            } catch {
                fatalError("Unable to compile render pipeline state: \(error)")
            }
            
            // compute
            do {
                self.computeState = try device.makeComputePipelineState(function: computeFunction!)
                self.fieldState = try device.makeComputePipelineState(function: fieldFunction!)
            } catch {
                fatalError("Unable to compile compute pipeline state: \(error)")
            }
            
            // set up mBuffer and field
            let mSize = MemoryLayout<Charge>.stride * self.charges.count
            // copy charges to buffer
            self.chargeBuffer = device.makeBuffer(bytes: self.charges, length: mSize, options: [.storageModeShared])
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
        }
        
        func draw(in view: MTKView) {
            if (uniforms.setResolution(view.drawableSize)) {
                self.dscale = Float(view.window!.backingScaleFactor)
                initTexture()
            }
            syncViewModel()
            
            guard let drawable = view.currentDrawable,
                  let commandQueue = self.commandQueue,
                  let c_b = self.chargeBuffer,
                  let field = self.field else { return }

            let commandBuffer = commandQueue.makeCommandBuffer()
            
            guard let computeEncoder = commandBuffer?.makeComputeCommandEncoder() else { return }
            
            computeEncoder.setTexture(field, index: 0)
            computeEncoder.setBytes(&uniforms, length: MemoryLayout<ESUniforms>.stride, index: 0)
            computeEncoder.setBuffer(c_b, offset: 0, index: 1)
            
            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            
            let threadGroups = MTLSize(
                width: (Int(uniforms.resolution.x) + threadGroupSize.width - 1) / threadGroupSize.width,
                height: (Int(uniforms.resolution.y) + threadGroupSize.height - 1) / threadGroupSize.height,
                depth: 1
            )
            
            if (model.play) {
                for _ in 0..<10 {
                    computeEncoder.setComputePipelineState(computeState!)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                }
            }
            
            computeEncoder.endEncoding()
            
            guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            let cb = chargeBuffer
            renderEncoder?.setRenderPipelineState(renderState!)
            renderEncoder?.setFragmentBytes(&uniforms, length: MemoryLayout<ESUniforms>.stride, index: 0)
            renderEncoder?.setFragmentBuffer(cb, offset: 0, index: 1)
            renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 6)
            renderEncoder?.endEncoding()
            
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}
