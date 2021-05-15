//
//  mtlView.m
//  metal_learning
//
//  Created by william on 2021/5/14.
//

#import "renderer.h"
/// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "shaderTypes.h"
#import <array>

@implementation Renderer
{
    // The device (aka GPU) used to render
    id<MTLDevice> _device;
    // The command Queue used to submit commands.
    id<MTLCommandQueue> _commandQueue;
    // Render pass descriptor to draw to the texture
    MTLRenderPassDescriptor* _renderToTextureRenderPassDescriptor;
    // A pipeline object to render to the offscreen texture.
    id<MTLRenderPipelineState> _renderToTextureRenderPipeline;
    // A pipeline object to render to the screen.
    id<MTLRenderPipelineState> _drawableRenderPipelineState;
    // Combined depth and stencil state object.
    id<MTLDepthStencilState> _depthState;
    // The Metal buffer that holds the vertex data.
    id<MTLBuffer> _vertices0;
    id<MTLBuffer> _vertices1;
    // The Metal texture object
    id<MTLTexture> _texture0;
    id<MTLTexture> _texture1;
}

- (id)initWithMetalKitView:(MTKView*) view
{
    self = [super init];
    if (self)
    {
        NSError *error = nil;
        _device = view.device;
        // Set a black clear color.
        view.clearColor = MTLClearColorMake(0, 0, 0, 1);
        // Indicate that each pixel in the depth buffer is a 32-bit floating point value.
        view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
        view.clearDepth = 1.0;
        _texture0 = [self loadTextureFromFile:@"test.png"];
        _texture1 = [self loadTextureFromFile:@"test1.jpg"];
        static const Vertex vertexes0[] = {
            {{-0.5f, -0.5f, 0.0f}, {0.0f, 0.0f}},
            {{-0.5f, 0.5f, 0.0f}, {0.0f, 1.0f}},
            {{0.5f, -0.5f, 0.0f}, {1.0f, 0.0f}},
            {{0.5f, 0.5f, 0.0f}, {1.0f, 1.0f}}
        };
        static const Vertex vertexes1[] = {
            {{-1.0f, -1.0f, 0.5f}, {0.0f, 0.0f}},
            {{-1.0f, 1.0f, 0.5f}, {0.0f, 1.0f}},
            {{1.0f, -1.0f, 0.5f}, {1.0f, 0.0f}},
            {{1.0f, 1.0f, 0.5f}, {1.0f, 1.0f}}
        };
        _vertices0 = [_device newBufferWithBytes:vertexes0 length:sizeof(vertexes0) options:MTLResourceStorageModeShared];
        _vertices1 = [_device newBufferWithBytes:vertexes1 length:sizeof(vertexes1) options:MTLResourceStorageModeShared];
        /// RenderPass：可以理解为framebuffer
        _renderToTextureRenderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
        _renderToTextureRenderPassDescriptor.colorAttachments[0].texture = _texture0;
        _renderToTextureRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        _renderToTextureRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderToTextureRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        /// load shader
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
        id<MTLFunction> vertFunction = [defaultLibrary newFunctionWithName:@"vertShader"];
        id<MTLFunction> fragFunction = [defaultLibrary newFunctionWithName:@"fragShader"];
        MTLRenderPipelineDescriptor *renderPipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        /// 绘制framebuffer
        renderPipelineDescriptor.label = @"Drawable Render Pipeline";
        renderPipelineDescriptor.sampleCount = view.sampleCount;
        renderPipelineDescriptor.vertexFunction = vertFunction;
        renderPipelineDescriptor.fragmentFunction = fragFunction;
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
        renderPipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
        renderPipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
        _drawableRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];
        NSAssert(_drawableRenderPipelineState, @"Failed to create pipeline state to render to screen: %@", error);
        
        /// 离屏framebuffer
        renderPipelineDescriptor.label = @"Offscreen Render Pipeline";
        renderPipelineDescriptor.sampleCount = 1;
        renderPipelineDescriptor.vertexFunction = vertFunction;
        renderPipelineDescriptor.fragmentFunction = fragFunction;
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = _texture0.pixelFormat;
        renderPipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
        renderPipelineDescriptor.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
        _renderToTextureRenderPipeline = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];
        NSAssert(_renderToTextureRenderPipeline, @"Failed to create pipeline state to render to texture: %@", error);
        
        /// 深度模板
        MTLDepthStencilDescriptor* depthStencilDescriptor = [[MTLDepthStencilDescriptor alloc] init];
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionLessEqual;
        depthStencilDescriptor.depthWriteEnabled = YES;
        depthStencilDescriptor.frontFaceStencil.stencilCompareFunction = MTLCompareFunctionEqual;
        depthStencilDescriptor.frontFaceStencil.stencilFailureOperation = MTLStencilOperationKeep;
        depthStencilDescriptor.frontFaceStencil.depthFailureOperation = MTLStencilOperationIncrementClamp;
        depthStencilDescriptor.frontFaceStencil.depthStencilPassOperation = MTLStencilOperationIncrementClamp;
        depthStencilDescriptor.frontFaceStencil.readMask = 0x1;
        depthStencilDescriptor.frontFaceStencil.writeMask = 0x1;
        depthStencilDescriptor.backFaceStencil = nil;
        
        _depthState = [_device newDepthStencilStateWithDescriptor:depthStencilDescriptor];
        _commandQueue = [_device newCommandQueue];
    }
    return self;
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Command Buffer";
    {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_renderToTextureRenderPassDescriptor];
        renderEncoder.label = @"Offscreen Render Pass";
        [renderEncoder setRenderPipelineState:_renderToTextureRenderPipeline];
        [renderEncoder setVertexBuffer:_vertices1 offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:_texture1 atIndex:0];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        [renderEncoder endEncoding];
    }
    /// 渲染描述符
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil)
    {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"renderEncoder";
        [renderEncoder setRenderPipelineState:_drawableRenderPipelineState];
        [renderEncoder setDepthStencilState:_depthState];
        [renderEncoder setStencilReferenceValue:0x1];
        [renderEncoder setVertexBuffer:_vertices0 offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:_texture0 atIndex:0];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        [renderEncoder setVertexBuffer:_vertices1 offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:_texture1 atIndex:0];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    
}

// UIImage 中读取字节流
-(unsigned char*)readPixelsByUIImage:(UIImage*) image
{
    CGImageRef imageRef = image.CGImage;
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    size_t bytesPerRow = 4 * image.size.width;
    unsigned char* imageData = (unsigned char*)malloc(bytesPerRow * height);
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, bytesPerRow, CGImageGetColorSpace(imageRef), kCGImageAlphaPremultipliedLast);
    CGRect rect = CGRectMake(0, 0, width, height);
    CGContextTranslateCTM(context, rect.origin.x, rect.origin.y);
    CGContextTranslateCTM(context, 0, rect.size.height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);
    CGContextDrawImage(context, rect, imageRef);
    CGContextRelease(context);
    return imageData;
}

- (id<MTLTexture>)loadTextureFromFile:(NSString*) path
{
    UIImage* image = [UIImage imageNamed:path];
    MTLTextureDescriptor* textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
    textureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    unsigned int width = image.size.width;
    unsigned int height = image.size.height;
    textureDescriptor.width = width;
    textureDescriptor.height = height;

    id<MTLTexture> texture = [_device newTextureWithDescriptor:textureDescriptor];
    size_t bytesPerRow = 4 * image.size.width;
    MTLRegion region = {
        {0, 0, 0},
        {width, height, 1}
    };
    unsigned char* imageBytes = [self readPixelsByUIImage:image];
        // Copy the bytes from the data object into the texture
    [texture replaceRegion:region mipmapLevel:0 withBytes:imageBytes bytesPerRow:bytesPerRow];
    return texture;
}

@end
