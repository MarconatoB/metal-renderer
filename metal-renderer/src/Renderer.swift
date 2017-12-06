//
//  Renderer.swift
//  metal-renderer
//
//  Created by Bastien Marconato on 05.12.17.
//  Copyright © 2017 Marconato. All rights reserved.
//

import Metal
import MetalKit
import simd


struct Constants {
    var modelViewProjectionMatrix = matrix_identity_float4x4
    var normalMatrix = matrix_identity_float3x3
}

public class Renderer: NSObject, MTKViewDelegate {
    
    weak var view: MTKView!
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let renderPipelineState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState
    let sampler: MTLSamplerState
    let texture: MTLTexture
    let cube: Cube
    
    var time = TimeInterval(0.0)
    var constants = Constants()
    
    init?(mtkView: MTKView) {
        view = mtkView
        
        //Use 4x MSAA multisampling
        view.sampleCount = 4
        //Clear to solid white
        view.clearColor = MTLClearColorMake(1, 1, 1, 1)
        //Use a BGRA 8-bit normalized texture for the drawable
        view.colorPixelFormat = .bgra8Unorm
        //Use a 32-bit depth buffer
        view.depthStencilPixelFormat = .depth32Float
        
        //Ask for the default Metal device; this represents our GPU.
        if let defaultDevice = MTLCreateSystemDefaultDevice() {
            device = defaultDevice
        }
        else {
            print("Metal is not supported")
            return nil
        }
        
        //Create the command queue we will be using to submit work to the GPU.
        commandQueue = device.makeCommandQueue()!
        
        //Compile the functions and other state into a pipeline object.
        do {
            renderPipelineState = try Renderer.buildRenderPipelineWithDevice(device, view: mtkView)
        }
        catch {
            print("Unable to compile render pipeline state")
            return nil
        }
        
        cube = Cube(cubeWithSize: 1.0, device: device)!
        
        do {
            texture = try Renderer.buildTexture(name: "checkerboard", device)
        }
        catch {
            print ("Unable to load texture from main bundle")
            return nil
        }
        
        //Make a depth-stencil state that passes when fragments are nearer to the camera than previous fragments
        depthStencilState = Renderer.buildDepthStencilStateWithDevice(device, compareFunc: .less, isWriteEnabled: true)
        
        //Make a texture sampler that wraps in both directions and performs bilinear filtering
        sampler = Renderer.buildSamplerStateWithDevice(device, addressMode: .repeat, filter: .linear)
        
        super.init()
        
        //Now that all of our members are initialized, set ourselves as the drawing delegate of the view
        view.delegate = self
        view.device = device
    }
    
    class func buildRenderPipelineWithDevice(_ device: MTLDevice, view: MTKView) throws -> MTLRenderPipelineState {
        //The default library contains all of the shader functions that were compiled into our app bundle
        let library = device.makeDefaultLibrary()!
        
        //Retrieve the functions that will comprise our pipeline
        let vertexFunction = library.makeFunction(name: "vertex_transform")
        let fragmentFunction = library.makeFunction(name: "fragment_lit_textured")
        
        //A render pipeline descriptor describes the configuration of our programmable pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Render Pipeline"
        pipelineDescriptor.sampleCount = view.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    class func buildTexture(name: String, _ device: MTLDevice) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)
        let asset = NSDataAsset.init(name: NSDataAsset.Name(rawValue: name))
        if let data = asset?.data {
            return try textureLoader.newTexture(data: data, options: [:])
        } else {
            fatalError("Could not load image \(name) from an asset catalog in the main bundle")
        }
    }
    
    class func buildSamplerStateWithDevice(_ device: MTLDevice,
                                           addressMode: MTLSamplerAddressMode,
                                           filter: MTLSamplerMinMagFilter) -> MTLSamplerState
    {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = addressMode
        samplerDescriptor.tAddressMode = addressMode
        samplerDescriptor.minFilter = filter
        samplerDescriptor.magFilter = filter
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    class func buildDepthStencilStateWithDevice(_ device: MTLDevice,
                                                compareFunc: MTLCompareFunction,
                                                isWriteEnabled: Bool) -> MTLDepthStencilState
    {
        let desc = MTLDepthStencilDescriptor()
        desc.depthCompareFunction = compareFunc
        desc.isDepthWriteEnabled = isWriteEnabled
        return device.makeDepthStencilState(descriptor: desc)!
    }
    
    func updateWithTimestep(_ timestep: TimeInterval)
    {
        //We keep track of time so we can animate the various transformations
        time = time + timestep
        
        let modelToWorldMatrix = rotationMatrix(Float(time * 0.5), vector_float3(0.7, 1, 0))
        
        let viewSize = self.view.bounds.size
        let aspectRatio = Float(viewSize.width / viewSize.height)
        let verticalViewAngle = radiansFromDegrees(degrees: 65)
        let nearZ: Float = 0.1
        let farZ: Float = 100.0
        
        let projectionMatrix = perspectiveMatrix(fovyRadians: Float(verticalViewAngle), aspect: aspectRatio, nearZ: nearZ, farZ: farZ)
        let viewMatrix = lookAtMatrix(eyeX: 0, eyeY: 0, eyeZ: 2.5, centerX: 0, centerY: 0, centerZ: 0, upX: 0, upY: 1, upZ: 0)
        
        let mvMatrix = matrix_multiply(viewMatrix, modelToWorldMatrix);
        constants.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, mvMatrix)
        constants.normalMatrix = invertTransposeMatrix(m: (upperLeftMatrix3x3(m: mvMatrix)))
    }
    
    func render(_ view: MTKView) {
        
        let timestep = 1.0 / TimeInterval(view.preferredFramesPerSecond)
        updateWithTimestep(timestep)
        
        //Our command buffer is a container for the work we want to perform with the GPU.
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        //Ask the view for a configured render pass descriptor. It will have a loadAction of MTLLoadActionClear and have the clear color of the drawable set to our desired clear color.
        let renderPassDescriptor = view.currentRenderPassDescriptor
        
        if let renderPassDescriptor = renderPassDescriptor {
            //Create a render encoder to clear the screen and draw our objects
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            renderEncoder?.pushDebugGroup("Draw Cube")
            renderEncoder?.setFrontFacing(.counterClockwise)
            renderEncoder?.setDepthStencilState(depthStencilState)
            renderEncoder?.setRenderPipelineState(renderPipelineState)
            renderEncoder?.setVertexBuffer(cube.vertexBuffer, offset: 0, index: 0)
            renderEncoder?.setVertexBytes(&constants, length: MemoryLayout<Constants>.size, index: 1)
            renderEncoder?.setFragmentTexture(texture, index: 0)
            renderEncoder?.setFragmentSamplerState(sampler, index: 0)
            //Issue the draw call to draw the indexed geometry of the mesh
            renderEncoder?.drawIndexedPrimitives(type: cube.primitiveType,
                                                 indexCount: cube.indexCount,
                                                 indexType: cube.indexType,
                                                 indexBuffer: cube.indexBuffer,
                                                 indexBufferOffset: 0)
            renderEncoder?.popDebugGroup()
            renderEncoder?.endEncoding()
            
            if let drawable = view.currentDrawable
            {
                commandBuffer?.present(drawable)
            }
        }
        
        commandBuffer?.commit()
        
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //respond to resize
    }
    
    @objc(drawInMTKView:)
    public func draw(in metalView: MTKView) {
        render(metalView)
    }
}
