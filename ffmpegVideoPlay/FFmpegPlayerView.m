//
//  FFmpegPlayerView.m
//  SameFunctionModules
//
//  Created by jian zhang on 2017/1/3.
//  Copyright © 2017年 jian zhang. All rights reserved.
//

#import "FFmpegPlayerView.h"
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#pragma mark - shaders

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

/*
 1 position 这个变量用“attribute”声明了这个shader会接受一个传入变量。在后面的代码中，你会用它来传入顶点的位置数据。这个变量的类型是“vec4”,表示这是一个由4部分组成的矢量。
 2 texcoord 这个变量与上面同理，这里是传入顶点的颜色变量。
 3 modelViewProjectionMatrix(投影), uniform 关键字表示，这会是一个应用于所有顶点的常量，而不是会因为顶点不同而不同的值。mat4 是 4X4矩阵的意思。用于放大缩小、旋转、变形。
 4 v_texcoord 这个变量没有“attribute”的关键字。表明它是一个传出变量，它就是会传入片段着色器的参数。“varying”关键字表示，依据顶点的颜色，平滑计算出顶点之间每个像素的颜色。
 5 每个shader都从main开始。
 6 gl_Position 是一个内建的传出变量。这是一个在 vertex shader中必须设置的变量。Position位置乘以modelViewProjectionMatrix矩阵，得到最终的位置数值。
 7 设置目标颜色 = 传入变量
 */
NSString *const vertexShaderString = SHADER_STRING(attribute vec4 position;
                                                   attribute vec2 texcoord;
                                                   uniform mat4 modelViewProjectionMatrix;
                                                   uniform mat4 modelViewProjectionMatrixRotate;
                                                   uniform mat4 modelViewProjectionMatrixScale;
                                                   varying vec2 v_texcoord;
                                                   
                                                   void main()
                                                   {
                                                       gl_Position = modelViewProjectionMatrix * modelViewProjectionMatrixRotate * modelViewProjectionMatrixScale * position;
                                                       v_texcoord = texcoord.xy;
                                                   }
                                                   );

/*
 1 这是从vertex shader中传入的变量，这里和vertex shader定义的一致。在fragment shader中，必须给出一个计算的精度。可以设置成lowp、medp、highp。
 2 也是从main开始
 3 正如你在vertex shader中必须设置gl_Position, 在fragment shader中必须设置gl_FragColor.
 */
NSString *const rgbFragmentShaderString = SHADER_STRING(varying highp vec2 v_texcoord;
                                                        uniform sampler2D s_texture;
                                                        
                                                        void main()
                                                        {
                                                            gl_FragColor = texture2D(s_texture, v_texcoord);
                                                        }
                                                        );

NSString *const yuvFragmentShaderString = SHADER_STRING(varying highp vec2 v_texcoord;
                                                        uniform sampler2D s_texture_y;
                                                        uniform sampler2D s_texture_u;
                                                        uniform sampler2D s_texture_v;
                                                        
                                                        void main()
                                                        {
                                                            highp float y = texture2D(s_texture_y, v_texcoord).r;
                                                            highp float u = texture2D(s_texture_u, v_texcoord).r - 0.5;
                                                            highp float v = texture2D(s_texture_v, v_texcoord).r - 0.5;
                                                            
                                                            highp float r = y +             1.402 * v;
                                                            highp float g = y - 0.344 * u - 0.714 * v;
                                                            highp float b = y + 1.772 * u;
                                                            
                                                            gl_FragColor = vec4(r,g,b,1.0);
                                                        }
                                                        );

static void mat4f_LoadOrtho(float left, float right, float bottom, float top, float near, float far, float* mout)
{
    float r_l = right - left;
    float t_b = top - bottom;
    float f_n = far - near;
    float tx = - (right + left) / (right - left);
    float ty = - (top + bottom) / (top - bottom);
    float tz = - (far + near) / (far - near);
    
    mout[0] = 2.0f / r_l;
    mout[1] = 0.0f;
    mout[2] = 0.0f;
    mout[3] = 0.0f;
    
    mout[4] = 0.0f;
    mout[5] = 2.0f / t_b;
    mout[6] = 0.0f;
    mout[7] = 0.0f;
    
    mout[8] = 0.0f;
    mout[9] = 0.0f;
    mout[10] = -2.0f / f_n;
    mout[11] = 0.0f;
    
    mout[12] = tx;
    mout[13] = ty;
    mout[14] = tz;
    mout[15] = 1.0f;
}

static void mat4f_LoadRotate(double angle, float* mout)
{
    mout[0] = cos(angle);
    mout[1] = -sin(angle);
    mout[2] = 0.0f;
    mout[3] = 0.0f;
    
    mout[4] = sin(angle);
    mout[5] = cos(angle);
    mout[6] = 0.0f;
    mout[7] = 0.0f;
    
    mout[8] = 0.0f;
    mout[9] = 0.0f;
    mout[10] = 1.0f;
    mout[11] = 0.0f;
    
    mout[12] = 0.0f;
    mout[13] = 0.0f;
    mout[14] = 0.0f;
    mout[15] = 1.0f;
}

static void mat4f_LoadScale(float scale, float* mout)
{
    mout[0] = scale;
    mout[1] = 0.0f;
    mout[2] = 0.0f;
    mout[3] = 0.0f;
    
    mout[4] = 0.0f;
    mout[5] = scale;
    mout[6] = 0.0f;
    mout[7] = 0.0f;
    
    mout[8] = 0.0f;
    mout[9] = 0.0f;
    mout[10] = scale;
    mout[11] = 0.0f;
    
    mout[12] = 0.0f;
    mout[13] = 0.0f;
    mout[14] = 0.0f;
    mout[15] = 1.0f;
}

/**
 生成渲染着色器
 1）创建shader对象
 2）装着shader源码
 3）编译shader

 @param type 着色器类型   
 1） GL_VERTEX_SHADER: 它运行在可编程的“顶点处理器”上，用于代替固定功能的顶点处理。在你的场景中，每个顶点都需要调用的程序，称为“顶点着色器”。假如你在渲染一个简单的场景：一个长方形，每个角只有一个顶点。于是vertex shader 会被调用四次。它负责执行：诸如灯光、几何变换等等的计算。得出最终的顶点位置后，为下面的片段着色器提供必须的数据。
 2） GL_FRAGMENT_SHADER: 它运行在可编程的“片断处理器”上，用于代替固定功能的片段处理。在你的场景中，大概每个像素都会调用的程序，称为“片段着色器”。在一个简单的场景，也是刚刚说到的长方形。这个长方形所覆盖到的每一个像素，都会调用一次fragment shader。片段着色器的责任是计算灯光，以及更重要的是计算出每个像素的最终颜色。
 @param shaderString 源码段
 @return  着色器对象
 */
static GLuint loadShader(GLenum type, NSString *shaderString)
{
    GLint status;
    const GLchar *sources = (GLchar *)shaderString.UTF8String;
    
    // Create an empty shader object, which maintain the source code strings that define a shader
    //创建一个顶点着色器对象或一个片段着色器对象
    //这里是顶点着色器
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        //NSLog( @"Failed to create shader %d", type);
        return 0;
    }
    
    // Replaces the source code in a shader object
    //将顶点着色程序的源代码字符数组绑定到顶点着色器对象，将片段着色程序的源代码字符数组绑定到片段着色器对象
    glShaderSource(shader, 1, &sources, NULL);
    
    // Compile the shader object
    //编译顶点着色器对象或片段着色器对象
    glCompileShader(shader);
    
    // Check the shader object compile status
    //检查着色器对象编译状态
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE)
    {
        GLint infoLen = 0;
        
        glGetShaderiv ( shader, GL_INFO_LOG_LENGTH, &infoLen );
        
        if ( infoLen > 1 )
        {
            char* infoLog = malloc (sizeof(char) * infoLen );
            glGetShaderInfoLog ( shader, infoLen, NULL, infoLog );
            NSLog(@"Error compiling shader:\n%s\n", infoLog);
            free ( infoLog );
        }
        
        glDeleteShader(shader);
        return 0;
    }    
    return shader;
}

#pragma mark - frame renderers

@protocol PlayerMovieGLRenderer
- (BOOL) isValid;
- (NSString *) fragmentShader;
- (void) resolveUniforms: (GLuint) program;
- (void) setFrame: (FFmpegFrameModel *) frame;
- (BOOL) prepareRender;
@end

#pragma mark - frame renderers RGB

@interface PlayerMovieGLRenderer_RGB : NSObject<PlayerMovieGLRenderer> {
    
    GLint _uniformSampler;
    GLuint _texture;
}
@end

@implementation PlayerMovieGLRenderer_RGB

- (BOOL) isValid
{
    return (_texture != 0);
}

- (NSString *) fragmentShader
{
    return rgbFragmentShaderString;
}

- (void) resolveUniforms: (GLuint) program
{
    _uniformSampler = glGetUniformLocation(program, "s_texture");
}

- (void) setFrame: (FFmpegFrameModel *) frame
{
    FFmpegVideoFrameModelRGB *rgbFrame = (FFmpegVideoFrameModelRGB *)frame;
    
    assert(rgbFrame.rgb.length == rgbFrame.width * rgbFrame.height * 3);
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (0 == _texture)
        glGenTextures(1, &_texture);
    
    glBindTexture(GL_TEXTURE_2D, _texture);
    
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RGB,
                 frame.width,
                 frame.height,
                 0,
                 GL_RGB,
                 GL_UNSIGNED_BYTE,
                 rgbFrame.rgb.bytes);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (BOOL) prepareRender
{
    if (_texture == 0)
        return NO;
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glUniform1i(_uniformSampler, 0);
    
    return YES;
}

- (void) dealloc
{
    if (_texture)
    {
        glDeleteTextures(1, &_texture);
        _texture = 0;
    }
}

@end

#pragma mark - frame renderers YUV

@interface PlayerMovieGLRenderer_YUV : NSObject<PlayerMovieGLRenderer> {
    
    GLint _uniformSamplers[3];
    GLuint _textures[3];
}
@end

@implementation PlayerMovieGLRenderer_YUV

- (BOOL) isValid
{
    return (_textures[0] != 0);
}

- (NSString *) fragmentShader
{
    return yuvFragmentShaderString;
}

- (void) resolveUniforms: (GLuint) program
{
    _uniformSamplers[0] = glGetUniformLocation(program, "s_texture_y");
    _uniformSamplers[1] = glGetUniformLocation(program, "s_texture_u");
    _uniformSamplers[2] = glGetUniformLocation(program, "s_texture_v");
}

- (void) setFrame: (FFmpegFrameModel *) frame
{
    FFmpegVideoFrameModelYUV *yuvFrame = (FFmpegVideoFrameModelYUV *)frame;
    
    assert(yuvFrame.luma.length == yuvFrame.width * yuvFrame.height);
    assert(yuvFrame.chromaB.length == (yuvFrame.width * yuvFrame.height) / 4);
    assert(yuvFrame.chromaR.length == (yuvFrame.width * yuvFrame.height) / 4);
    
    const NSUInteger frameWidth = frame.width;
    const NSUInteger frameHeight = frame.height;
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (0 == _textures[0])
        glGenTextures(3, _textures);    //生成一个纹理
    
    const UInt8 *pixels[3] = { yuvFrame.luma.bytes, yuvFrame.chromaB.bytes, yuvFrame.chromaR.bytes };
    const NSUInteger widths[3]  = { frameWidth, frameWidth / 2, frameWidth / 2 };
    const NSUInteger heights[3] = { frameHeight, frameHeight / 2, frameHeight / 2 };
    
    for (int i = 0; i < 3; ++i) {
        
        glBindTexture(GL_TEXTURE_2D, _textures[i]); //绑定纹理
        
        //赋值,将frame数据就转换成了texture
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE,
                     widths[i],
                     heights[i],
                     0,
                     GL_LUMINANCE,
                     GL_UNSIGNED_BYTE,
                     pixels[i]);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
}

- (BOOL) prepareRender
{
    if (_textures[0] == 0)
        return NO;
    
    for (int i = 0; i < 3; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, _textures[i]);
        glUniform1i(_uniformSamplers[i], i);
    }
    
    return YES;
}

- (void) dealloc
{
    if (_textures[0])
        glDeleteTextures(3, _textures);
}

@end


#pragma mark - gl view
enum {
    ATTRIBUTE_VERTEX,
   	ATTRIBUTE_TEXCOORD,
};

@implementation FFmpegPlayerView
{
    FFmpegPlayerDecoder  *_decoder;
    CAEAGLLayer     *_eaglLayer;
    EAGLContext     *_context;
    GLuint          _framebuffer;
    GLuint          _renderbuffer;
    GLint           _backingWidth;
    GLint           _backingHeight;
    GLuint          _program;
    GLint           _uniformMatrix;
    GLint           _uniformMatrixRotate;
    GLint           _uniformMatrixScale;
    GLfloat         _vertices[8];
    
    id<PlayerMovieGLRenderer> _renderer;
    
    UIImageView *m_ImageView;
    NSRecursiveLock *m_Lock;
    NSMutableArray *m_FrameArray;
}

- (id) initWithFrame:(CGRect)frame decoder:(FFmpegPlayerDecoder *)decoder
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.interfaceOr = [[UIApplication sharedApplication] statusBarOrientation];
        m_FrameArray = [NSMutableArray array];
        m_Lock = [[NSRecursiveLock alloc] init];
        _decoder = decoder;
        m_ImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
        [m_ImageView setCenter:self.center];
        [self addSubview:m_ImageView];
        [self setupLayer];
        
        if (![self setupContext])
        {
            NSLog( @"failed to setup EAGLContext");
            self = nil;
            return nil;
        }
        
        [self setupRenderBuffer];
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
        [self setupFrameBuffer];
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE)
        {
            NSLog( @"failed to make complete framebuffer object %x", status);
            self = nil;
            return nil;
        }
        GLenum glError = glGetError();
        if (GL_NO_ERROR != glError)
        {
            NSLog( @"failed to setup GL %x", glError);
            self = nil;
            return nil;
        }
        
        
        _renderer = [[PlayerMovieGLRenderer_YUV alloc] init];
        if (![self loadProgram])
        {
            self = nil;
            return nil;
        }
        
        _vertices[0] = -1.0f;  // x0
        _vertices[1] = -1.0f;  // y0
        _vertices[2] =  1.0f;  // ..
        _vertices[3] = -1.0f;
        _vertices[4] = -1.0f;
        _vertices[5] =  1.0f;
        _vertices[6] =  1.0f;  // x3
        _vertices[7] =  1.0f;  // y3
        
        NSLog( @"OK setup GL");
    }
    
    return self;
}

/**
1）设置layer class 为 CAEAGLLayer
想要显示OpenGL的内容，你需要把它缺省的layer设置为一个特殊的layer。（CAEAGLLayer）。这里通过直接复写layerClass的方法。
 */
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

/**
2) 设置layer为不透明（Opaque）
因为缺省的话，CALayer是透明的。而透明的层对性能负荷很大，特别是OpenGL的层。
(如果可能，尽量都把层设置为不透明。另一个比较明显的例子是自定义tableview cell）
 */
- (void)setupLayer
{
    _eaglLayer = (CAEAGLLayer*) self.layer;
    _eaglLayer.opaque = YES;
    _eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                     kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                     nil];
}

/**
3）创建OpenGL context
无论你要OpenGL帮你实现什么，总需要这个 EAGLContext。
EAGLContext管理所有通过OpenGL进行draw的信息。这个与Core Graphics context类似。
当你创建一个context，你要声明你要用哪个version的API。这里，我们选择OpenGL ES 2.0.
 */
- (BOOL)setupContext
{
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    _context = [[EAGLContext alloc] initWithAPI:api];
    if (!_context)
    {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        return NO;
    }
    
    if (![EAGLContext setCurrentContext:_context])
    {
        NSLog(@"Failed to set current OpenGL context");
        return NO;
    }
    return YES;
}

/**
4）创建render buffer （渲染缓冲区）
Render buffer 是OpenGL的一个对象，用于存放渲染过的图像。
有时候你会发现render buffer会作为一个color buffer被引用，因为本质上它就是存放用于显示的颜色。
创建render buffer的三步：
 1.调用glGenRenderbuffers来创建一个新的render buffer object。这里返回一个唯一的integer来标记render buffer（这里把这个唯一值赋值到_renderbuffer）。有时候你会发现这个唯一值被用来作为程序内的一个OpenGL 的名称。（反正它唯一嘛）
 2.调用glBindRenderbuffer ，告诉这个OpenGL：我在后面引用GL_RENDERBUFFER的地方，其实是想用_renderbuffer。其实就是告诉OpenGL，我们定义的buffer对象是属于哪一种OpenGL对象
 3.最后，为render buffer分配空间。renderbufferStorage
 */
- (void)setupRenderBuffer
{
    //创建一个新的render buffer object
    glGenRenderbuffers(1, &_renderbuffer);
    //绑定render buffer对象类型
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    //为render buffer分配空间
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
}

/**
 5）创建一个 frame buffer （帧缓冲区）
 Frame buffer也是OpenGL的对象，它包含了前面提到的render buffer，以及其它后面会讲到的诸如：depth buffer、stencil buffer 和 accumulation buffer。
 前两步创建frame buffer的动作跟创建render buffer的动作很类似。（反正也是用一个glBind什么的）
 而最后一步 glFramebufferRenderbuffer 这个才有点新意。它让你把前面创建的buffer render依附在frame buffer的GL_COLOR_ATTACHMENT0位置上。
 */
- (void)setupFrameBuffer
{
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
}


/**
 6）清理屏幕
 为了尽快在屏幕上显示一些什么，在我们和那些 vertexes、shaders打交道之前，把屏幕清理一下. 
 这里每个RGB色的范围是0~1.
 下面解析一下每一步动作：
 1.调用glClearColor ，设置一个RGB颜色和透明度，接下来会用这个颜色涂满全屏。
 2.调用glClear来进行这个“填色”的动作（大概就是photoshop那个油桶嘛）。还记得前面说过有很多buffer的话，这里我们要用到GL_COLOR_BUFFER_BIT来声明要清理哪一个缓冲区。
 */
- (void)clearRenderBuffer
{
    glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
}

- (void)layoutSubviews
{
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE)
        NSLog( @"failed to make complete framebuffer object %x", status);
    else
        NSLog( @"OK setup GL framebuffer %d:%d, %@", _backingWidth, _backingHeight, [NSValue valueWithCGRect:self.frame]);
    
    [self updateVertices];
    [self render];
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    [super setContentMode:contentMode];
    [self updateVertices];
    if (_renderer.isValid)
        [self render];
}

- (void)updateVertices
{
    const BOOL fit      = (self.contentMode == UIViewContentModeScaleAspectFit);
    const float width   = _decoder.frameWidth;
    const float height  = _decoder.frameHeight;
    const float dH      = (float)_backingHeight / height;
    const float dW      = (float)_backingWidth	  / width;
    const float dd      = fit ? MIN(dH, dW) : MAX(dH, dW);
    const float h       = (height * dd / (float)_backingHeight);
    const float w       = (width  * dd / (float)_backingWidth );
    
    _vertices[0] = - w;
    _vertices[1] = - h;
    _vertices[2] =   w;
    _vertices[3] = - h;
    _vertices[4] = - w;
    _vertices[5] =   h;
    _vertices[6] =   w;
    _vertices[7] =   h;
}

/**
 1 生成Program
    1.1 LoadShader
    1.2 LoadProgram
 2 安装并执行Program
 */
/**
 生成渲染着色器
 1 用来调用你刚刚写的动态编译方法，分别编译了vertex shader 和 fragment shader
 2 调用了glCreateProgram glAttachShader  glLinkProgram 连接 vertex 和 fragment shader成一个完整的program。
 3 调用 glGetProgramiv  lglGetProgramInfoLog 来检查是否有error，并输出信息。
 */
- (BOOL)loadProgram
{
    BOOL result = YES;
    GLuint vertShader = 0, fragShader = 0;
    
    vertShader = loadShader(GL_VERTEX_SHADER, vertexShaderString);
    if (!vertShader)
        goto exit;
    fragShader = loadShader(GL_FRAGMENT_SHADER, _renderer.fragmentShader);
    if (!fragShader)
        goto exit;
    
    //创建一个（着色）程序对象
    _program = glCreateProgram();
    if (_program == 0)
        goto exit;
    
    //分别将顶点着色器对象和片段着色器对象附加到（着色）程序对象上
    glAttachShader(_program, vertShader);
    glAttachShader(_program, fragShader);
    //把program的顶点属性索引与顶点shader中的变量名进行绑定
    glBindAttribLocation(_program, ATTRIBUTE_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIBUTE_TEXCOORD, "texcoord");
    //对（着色）程序对象执行链接操作
    glLinkProgram(_program);
    
    //检查（着色）程序对象链接状态
    GLint status;
    glGetProgramiv(_program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE)
    {
        GLint infoLen = 0;
        glGetProgramiv(_program, GL_INFO_LOG_LENGTH, &infoLen);
        if ( infoLen > 1 )
        {
            char* infoLog = malloc (sizeof(char) * infoLen );
            glGetProgramInfoLog(_program, infoLen, NULL, infoLog );
            NSLog(@"Error linking program:\n%s\n", infoLog);
            free(infoLog);
        }
        result = NO;
        NSLog( @"Failed to link program %d", _program);
        goto exit;
    }
    
    //获取在vertex shader中的Projection输入变量
    _uniformMatrix = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    _uniformMatrixRotate = glGetUniformLocation(_program, "modelViewProjectionMatrixRotate");
    _uniformMatrixScale = glGetUniformLocation(_program, "modelViewProjectionMatrixScale");
    [_renderer resolveUniforms:_program];
    
exit:
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (result)
    {
        NSLog( @"OK setup GL programm");
    }
    else
    {
        glDeleteProgram(_program);
        _program = 0;
    }
    
    return result;
}

/*
 1 设置OpenGL context
 2 调用glViewport 设置UIView中用于渲染的部分
 3 清理屏幕
 4 调用 glUseProgram  让OpenGL真正执行你的program
 5 调用 glEnableVertexAttribArray来启用这些数据。（因为默认是 disabled的。）
 6 展示
 */
- (FFmpegFrameModel *)render
{
    if (m_FrameArray.count <= 0)
    {
        return nil;
    }
    FFmpegFrameModel *frame = nil;
    [m_Lock lock];
    if (m_FrameArray.count > 0)
    {
        printf("\n1 video   -----> %d\n ", m_FrameArray.count);
        frame = m_FrameArray[0];
        [m_FrameArray removeObjectAtIndex:0];
        printf("2 video   ------------> %d, frame.position = %f, frame.duration = %f\n ", m_FrameArray.count, frame.position, frame.duration);
    }
    [m_Lock unlock];
    printf("FFmpegPlayView Render frame\n");
    static const GLfloat texCoords[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    [EAGLContext setCurrentContext:_context];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    // Set the viewport
    glViewport(0, 0, _backingWidth, _backingHeight);
    
    [self clearRenderBuffer];
    
    //Use the program object
    //安装一个program object，并把它作为当前rendering state的一部分
    glUseProgram(_program);
    
    if (frame)
    {
        [_renderer setFrame:frame];
    }
    
    if ([_renderer prepareRender])
    {        
        //把投影数据传入到vertex shader
        [self setOrthoMatrix];
        [self setRotateMatrix];
        [self setScaleMatrix:CGSizeMake(frame.width, frame.height)];
        
        // Load the vertex data
        //定义一个通用顶点属性数组。当渲染时，它指定了通用顶点属性数组从索引index处开始的位置和数据格式
        glVertexAttribPointer(ATTRIBUTE_VERTEX, 2, GL_FLOAT, 0, 0, _vertices);
        glVertexAttribPointer(ATTRIBUTE_TEXCOORD, 2, GL_FLOAT, 0, 0, texCoords);
        //Enable由索引index指定的通用顶点属性数组
        glEnableVertexAttribArray(ATTRIBUTE_VERTEX);
        glEnableVertexAttribArray(ATTRIBUTE_TEXCOORD);
        
        //使用每个enable的数组中的count个连续的元素，来构造一系列几何原语，从第first个元素开始。
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    //把缓冲区（render buffer）的颜色呈现到UIView上
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    
    return frame;
}

- (void)appendVideoFrameModel:(FFmpegFrameModel *)model
{
//    @synchronized(m_FrameArray)
    if ([m_Lock tryLock])
    {
        [m_FrameArray addObject:model];
    }
    [m_Lock unlock];
}

- (void)cleanBuffer
{
    if ([m_Lock tryLock])
    {
        [m_FrameArray removeAllObjects];
    }
    [m_Lock unlock];
}

- (void)setOrthoMatrix
{
    GLfloat modelviewProj[16];
    mat4f_LoadOrtho(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f, modelviewProj);
    glUniformMatrix4fv(_uniformMatrix, 1, GL_FALSE, modelviewProj);
}

- (void)setRotateMatrix
{
    GLfloat modelviewProj[16];
    double angle = 0.f;
    switch (self.interfaceOr)
    {
        case UIInterfaceOrientationPortrait:
            angle = 0.f;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            angle = 360.f;
        case UIInterfaceOrientationLandscapeLeft:
            angle = 270.f;
        case UIInterfaceOrientationLandscapeRight:
            angle = 90.f;
        default:
            break;
    }
    mat4f_LoadRotate(0.0f, modelviewProj);
    glUniformMatrix4fv(_uniformMatrixRotate, 1, GL_FALSE, modelviewProj);
}

- (void)setScaleMatrix:(CGSize)size
{
    GLfloat modelviewProj[16];
    CGFloat scale = 1.f;
    if (_backingWidth >= size.width && _backingHeight >= size.height)
    {
        scale = (_backingWidth/size.width) <= (_backingHeight/size.height)?
        _backingWidth/size.width:_backingHeight/size.height;
    }
    else if (_backingWidth < size.width && _backingHeight < size.height)
    {
        scale = (_backingWidth/size.width) <= (_backingHeight/size.height)?
        _backingWidth/size.width:_backingHeight/size.height;
    }
    else if (_backingWidth >= size.width && _backingHeight <= size.height)
    {
        scale = _backingHeight/size.height;
    }
    else if (_backingWidth <= size.width && _backingHeight >= size.height)
    {
        scale = _backingWidth/size.width;
    }
    mat4f_LoadScale(scale, modelviewProj);
    glUniformMatrix4fv(_uniformMatrixScale, 1, GL_FALSE, modelviewProj);
}

@end
