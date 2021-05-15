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
    id<MTLRenderPipelineState> _piplineState;
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
        _device = view.device;
        // Set a black clear color.
        view.clearColor = MTLClearColorMake(0, 0, 0, 1);
        // Indicate that each pixel in the depth buffer is a 32-bit floating point value.
        view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
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
        /// load shader
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
        id<MTLFunction> vertFunction = [defaultLibrary newFunctionWithName:@"vertShader"];
        id<MTLFunction> fragFunction = [defaultLibrary newFunctionWithName:@"fragShader"];
        MTLRenderPipelineDescriptor *renderPipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        renderPipelineDescriptor.label = @"myPipeline";
        renderPipelineDescriptor.sampleCount = view.sampleCount;
        renderPipelineDescriptor.vertexFunction = vertFunction;
        renderPipelineDescriptor.fragmentFunction = fragFunction;
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
        renderPipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
        NSError *error = nil;
        _piplineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];
        if (!_piplineState)
        {
            NSLog(@"create piplineState failed!");
        }
        MTLDepthStencilDescriptor* depthStencilDescriptor = [[MTLDepthStencilDescriptor alloc] init];
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionLessEqual;
        depthStencilDescriptor.depthWriteEnabled = YES;
        _depthState = [_device newDepthStencilStateWithDescriptor:depthStencilDescriptor];
        _commandQueue = [_device newCommandQueue];
    }
    return self;
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    id<MTLCommandBuffer> commanBuffer = [_commandQueue commandBuffer];
    /// 渲染描述符
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil)
    {
        id<MTLRenderCommandEncoder> renderEncoder = [commanBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"renderEncoder";
        [renderEncoder setRenderPipelineState:_piplineState];
        [renderEncoder setDepthStencilState:_depthState];
        [renderEncoder setVertexBuffer:_vertices0 offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:_texture0 atIndex:0];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        [renderEncoder setVertexBuffer:_vertices1 offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:_texture1 atIndex:0];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        [renderEncoder endEncoding];
        [commanBuffer presentDrawable:view.currentDrawable];
    }
    [commanBuffer commit];
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
