import SwiftUI
import MetalKit

struct MetalWrapper: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.framebufferOnly = false
        // scale to highest possible resolution
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // No additional updates needed for now
        if let window = nsView.window {
            let scale = window.backingScaleFactor
            nsView.drawableSize = CGSize(width: nsView.bounds.width * scale,
                                       height: nsView.bounds.height * scale)
            print("scale \(scale)")
        }
        print("drawableSize \(nsView.drawableSize)")
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalWrapper
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        var startTime: CFAbsoluteTime

        init(_ parent: MetalWrapper) {
            self.parent = parent
            self.startTime = CFAbsoluteTimeGetCurrent()
            super.init()

            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal is not supported on this device.")
            }

            self.commandQueue = device.makeCommandQueue()

            let library = device.makeDefaultLibrary()
            let vertexFunction = library?.makeFunction(name: "vertex_main")
            let fragmentFunction = library?.makeFunction(name: "creation_silexars")

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            do {
                self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                fatalError("Unable to compile pipeline state: \(error)")
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle size changes
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let pipelineState = self.pipelineState,
                  let commandQueue = self.commandQueue else { return }

            let commandBuffer = commandQueue.makeCommandBuffer()
            let renderPassDescriptor = view.currentRenderPassDescriptor

            guard let renderPassDescriptor = renderPassDescriptor else { return }

            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            renderEncoder?.setRenderPipelineState(pipelineState)

            var uniforms = Uniforms(
                time: Float(CFAbsoluteTimeGetCurrent() - self.startTime),
                resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
            )

            // Pass the uniform data to the fragment shader
            renderEncoder?.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

            renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder?.endEncoding()

            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}
