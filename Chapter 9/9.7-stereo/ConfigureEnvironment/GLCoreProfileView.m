//
//  GLCoreProfileView.m
//  ConfigureEnvironment
//
//  Created by 陈杰 on 26/10/2017.
//  Copyright © 2017 陈杰. All rights reserved.
//

#import "GLCoreProfileView.h"
#import <OpenGL/OpenGL.h>
#import <GLKit/GLKit.h>
#import "TextureManager.h"
#import "TDModelManger.h"

typedef NS_ENUM(NSUInteger, GLCoreProfileViewRenderMode) {
    GLCoreProfileViewRenderModeFull,
    GLCoreProfileViewRenderModeLight,
    GLCoreProfileViewRenderModeDepth,
};

@interface GLCoreProfileView()

{
    GLKMatrix4 mv_matrix[4];
    GLKMatrix4 light_view_matrix;
    GLKMatrix4 light_proj_matrix;
    
    GLKMatrix4 camera_view_matrix[2];
    GLKMatrix4 camera_proj_matrix;
    
    struct {
        GLint mv_matrix;
        GLint proj_matrix;
        GLint shadow_matrix;
        GLint full_shading;
        GLint specular_albedo;
        GLint diffuse_albedo;
    } uniformLocations;
}

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) GLCoreProfileViewRenderMode renderMode;

@property (atomic, assign) GLuint program;
@property (nonatomic, strong) NSMutableArray<TDModelManger *> *modelManagers;

@end

@implementation GLCoreProfileView
#pragma mark - lifecycle methods
- (instancetype)initWithCoder:(NSCoder *)decoder {
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFATripleBuffer,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
    NSOpenGLContext *openGLContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
    
    
    if (self = [super initWithCoder:decoder]) {
        _modelManagers = [[NSMutableArray alloc] init];
        
        [self setOpenGLContext:openGLContext];
        [self.openGLContext makeCurrentContext];
        GLint sync = 1;
        CGLSetParameter(CGLGetCurrentContext(), kCGLCPSwapInterval, &sync);
        
        _lifeTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(lifeTimerUpdate) userInfo:nil repeats:YES];
        _paused = NO;
    
        __weak __typeof(self) weakself = self;
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull aEvent) {
            [weakself keyDown:aEvent];
            return aEvent;
        }];
        
    }
    return self;
}

- (void)keyDown:(NSEvent *)event {
    if ([event.characters isEqualToString:@"f"]) {
        
    } else if ([event.characters isEqualToString:@"d"]) {

    } else if ([event.characters isEqualToString:@"w"]) {
    } else if ([event.characters isEqualToString:@"p"]) {
        self.paused = !self.paused;
    } else if ([event.characters isEqualToString:@"+"]) {

    } else if ([event.characters isEqualToString:@"-"]) {

    }
    NSLog(@"%@",event.characters);
}

- (void)dealloc {
    [_lifeTimer invalidate];
    _lifeTimer = nil;

//    glDeleteBuffers(1, &_patchBuffer);
//    glDeleteBuffers(1, &_cageIndicesBuffer);
//    glDeleteVertexArrays(1, &_vertexArray);
//    glDeleteProgram(_tessProgram);
//    glDeleteProgram(_deawCpProgram);
}

- (void)prepareOpenGL {
    [super prepareOpenGL];
    
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [self loadShaders];
    
    NSArray<NSString *> *modelFileNames = @[@"dragon.sbm", @"sphere.sbm", @"cube.sbm", @"torus.sbm"];
    [modelFileNames enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        TDModelManger *modelMnager = [[TDModelManger alloc] init];
        [modelMnager loadObjectWithFileName:obj];
        [self.modelManagers addObject:modelMnager];
    }];
    
    glEnable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
}

- (void)reshape {
    [super reshape];
    
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)prepareBasicMatrixWithCurrentDuration:(double)total_time {
    GLKVector3 light_position = GLKVector3Make(20.0f, 20.0f, 20.0f);
    light_proj_matrix = GLKMatrix4MakeFrustum(-1.0f, 1.0f, -1.0f, 1.0f, 1.0f, 200.0f);
    light_view_matrix =
    GLKMatrix4MakeLookAt(light_position.x, light_position.y, light_position.z,
                         0.0f, 0.0f, 0.0f,
                         0.0f, 1.0f, 0.0f);
    
    NSRect bounds = [self bounds];
    camera_proj_matrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50.0f), NSWidth(bounds) / NSHeight(bounds), 1.0f, 200.0f);
    GLKVector3 view_position = GLKVector3Make(0.0f, 0.0f, -40.0f);
    GLfloat eyeGap = 20.0f;
    camera_view_matrix[0] =
    GLKMatrix4MakeLookAt(view_position.x - eyeGap, view_position.y, view_position.z,
                         0.0f, 0.0f, 50.0f,
                         0.0f, 1.0f, 0.0f);
    camera_view_matrix[1] =
    GLKMatrix4MakeLookAt(view_position.x + eyeGap, view_position.y, view_position.z,
                         0.0f, 0.0f, 50.0f,
                         0.0f, 1.0f, 0.0f);
    
    // 龙
    GLKMatrix4 mv_matrix0 = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(total_time * 14.5f), 0.0f, 1.0f, 0.0f);
    mv_matrix0 = GLKMatrix4Rotate(mv_matrix0, GLKMathDegreesToRadians(20.0f), 1.0f, 0.0f, 0.0f);
    mv_matrix[0] = GLKMatrix4Translate(mv_matrix0, 0.0f, -4.0f, 0.0f);

    // 球
    GLKMatrix4 mv_matrix1 = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(total_time * 3.7f), 0.0f, 1.0f, 0.0f);
    mv_matrix1 = GLKMatrix4Translate(mv_matrix1,
                                     sinf(GLKMathDegreesToRadians(total_time * 0.37f)) * 12.0f,
                                     cosf(GLKMathDegreesToRadians(total_time * 0.37f)) * 12.0f,
                                     0.0f);
    mv_matrix[1] = GLKMatrix4Scale(mv_matrix1, 2.0f, 2.0f, 2.0f);
    
    // 立方体
    GLKMatrix4 mv_matrix2 = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(total_time * 6.45f), 0.0f, 1.0f, 0.0f);
    mv_matrix2 = GLKMatrix4Translate(mv_matrix2,
                                     sinf(GLKMathDegreesToRadians(total_time * 0.25f) * 10.0f) + 5,
                                     cosf(GLKMathDegreesToRadians(total_time * 0.25f) * 10.0f),
                                     0.0f);
    mv_matrix2 = GLKMatrix4Rotate(mv_matrix2, GLKMathDegreesToRadians(total_time * 99.0f), 0.0f, 0.0f, 1.0f);
    mv_matrix[2] = GLKMatrix4Scale(mv_matrix2, 2.0f, 2.0f, 2.0f);
    
    // 环
    GLKMatrix4 mv_matrix3 = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(total_time * 5.25f), 0.0f, 1.0f, 0.0f);
    mv_matrix3 = GLKMatrix4Translate(mv_matrix3,
                                     sinf(GLKMathDegreesToRadians(total_time * 0.51f) * 14.0f),
                                     cosf(GLKMathDegreesToRadians(total_time * 0.51f) * 14.0f) + 5,
                                     0.0f);
    mv_matrix3 = GLKMatrix4Rotate(mv_matrix3, GLKMathDegreesToRadians(total_time * 120.3f), 0.707106f, 0.0f, 0.707106f);
    mv_matrix[3] = GLKMatrix4Scale(mv_matrix3, 2.0f, 2.0f, 2.0f);
}

- (void)drawRect:(NSRect)dirtyRect {
    static double last_time = 0.0;
    static double total_time = 0.0;
    if (!_paused) {
        total_time += (_lifeDuration - last_time);
    }
    last_time = _lifeDuration;

    // 准备模型和光源的mv_matrix和proj_matrix
    [self prepareBasicMatrixWithCurrentDuration:total_time];

    GLKMatrix4 scale_basis_matix =
    GLKMatrix4MakeWithRows(GLKVector4Make(0.5f, 0.0f, 0.0f, 0.0f),
                           GLKVector4Make(0.0f, 0.5f, 0.0f, 0.0f),
                           GLKVector4Make(0.0f, 0.0f, 0.5f, 0.0f),
                           GLKVector4Make(0.5f, 0.5f, 0.5f, 1.0f));
    GLKMatrix4 light_vp_matix = GLKMatrix4Multiply(light_proj_matrix, light_view_matrix);
    GLKMatrix4 shadow_sbvp_matrix = GLKMatrix4Multiply(scale_basis_matix, GLKMatrix4Multiply(light_proj_matrix, light_view_matrix));

    // 清空默认的前置缓存
    static const GLfloat gray[] = { 0.1f, 0.1f, 0.1f, 0.0f };
    glClearBufferfv(GL_COLOR, 0, gray);
    glUseProgram(self.program);
    glActiveTexture(GL_TEXTURE0);
    glUniformMatrix4fv(uniformLocations.proj_matrix, 1, GL_FALSE, camera_proj_matrix.m);
    // 绘制后置缓存
    glDrawBuffer(GL_BACK);
    
    // 准备漫反射颜色
    GLKVector3 diffuse_colors[4] = {
        GLKVector3Make(1.0f, 0.6f, 0.3f),
        GLKVector3Make(0.2f, 0.8f, 0.9f),
        GLKVector3Make(0.3f, 0.9f, 0.4f),
        GLKVector3Make(0.5f, 0.2f, 1.0f)
    };
    static const GLfloat one = 1.0f;
    
    // 分别绘制后置左右缓存
    for (int i = 0 ; i < 2; i++) {
        static const GLenum buffers[2] = {GL_BACK_LEFT, GL_BACK_RIGHT};
        glDrawBuffer(buffers[i]);
        glClearBufferfv(GL_COLOR, 0, gray);
        glClearBufferfv(GL_DEPTH, 0, &one);
        for (int j = 0; j < 4; j++) {
            GLKMatrix4 model_matrix = mv_matrix[j];
            GLKMatrix4 shadow_matrix = GLKMatrix4Multiply(shadow_sbvp_matrix, model_matrix);
            glUniformMatrix4fv(uniformLocations.shadow_matrix, 1, GL_FALSE, shadow_matrix.m);
            GLKMatrix4 mv_matrix = GLKMatrix4Multiply(camera_view_matrix[i], model_matrix);
            glUniformMatrix4fv(uniformLocations.mv_matrix, 1, GL_FALSE, mv_matrix.m);
            
            glUniform1i(uniformLocations.full_shading, self.renderMode == GLCoreProfileViewRenderModeFull ? 1 : 0);
            glUniform3fv(uniformLocations.diffuse_albedo, 1, diffuse_colors[j].v);
            TDModelManger *modelManager = self.modelManagers[j];
            glBindVertexArray(modelManager.vao);
            [modelManager render];
        }
    }
    
    [self.openGLContext flushBuffer];
}

#pragma mark - private methods
- (BOOL)loadShaders {
    GLuint vertex_lineShader, frag_lineShader;
    NSString *vs_linePath = [[NSBundle mainBundle] pathForResource:@"linesadjacencyVS" ofType:@"glsl"];
    NSString *fs_linePath = [[NSBundle mainBundle] pathForResource:@"linesadjacencyFS" ofType:@"glsl"];
    
    if (![self compileShader:&vertex_lineShader type:GL_VERTEX_SHADER filePath:vs_linePath]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&frag_lineShader type:GL_FRAGMENT_SHADER filePath:fs_linePath]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    
    _program = glCreateProgram();
    glAttachShader(_program, vertex_lineShader);
    glAttachShader(_program, frag_lineShader);
    
    GLuint shaders2[] = {vertex_lineShader, frag_lineShader};
    for (int i = 0; i < 3; i++) {
        GLuint deleteShader = shaders2[i];
        glDeleteShader(deleteShader);
        deleteShader = 0;
    }
    
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link _tessProgram");
        if (_program != 0) {
            glDeleteProgram(_program);
            _program = 0;
        }
        return NO;
    }
    
    uniformLocations.mv_matrix = glGetUniformLocation(self.program, "mv_matrix");
    uniformLocations.proj_matrix = glGetUniformLocation(self.program, "proj_matrix");
    uniformLocations.shadow_matrix = glGetUniformLocation(self.program, "shadow_matrix");

    uniformLocations.diffuse_albedo = glGetUniformLocation(self.program, "diffuse_albedo");
    uniformLocations.specular_albedo = glGetUniformLocation(self.program, "specular_albedo");
    uniformLocations.full_shading = glGetUniformLocation(self.program, "full_shading");
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type filePath:(NSString *)path {
    const GLchar *shaderSource = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil].UTF8String;
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &shaderSource, nil);
    glCompileShader(*shader);
    
    GLint status = 0;
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        GLint logLen = 0;
        glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLen);
        GLchar *infoLog = malloc(sizeof(char) * logLen);
        glGetShaderInfoLog(*shader, logLen, NULL, infoLog);
        NSLog(@"Shader at: %@", path);
        fprintf(stderr, "Info Log: %s\n", infoLog);
        
        glDeleteShader(*shader);
        return NO;
    }
    return YES;
}

- (BOOL)linkProgram:(GLuint)program {
    glLinkProgram(program);
    GLint status = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == 0) {
        GLint logLen = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLen);
        GLchar *infoLog = malloc(sizeof(char) * logLen);
        glGetProgramInfoLog(program, logLen, NULL, infoLog);
        fprintf(stderr, "Prog Info Log: %s\n", infoLog);
        return NO;
    }
    return YES;
}

#pragma mark - listening methods
- (void)lifeTimerUpdate {
    _lifeDuration += _lifeTimer.timeInterval;
    // _lifeDuration为程序运行时间
    [self drawRect:self.bounds];
}

#pragma mark - accessor methods

@end



