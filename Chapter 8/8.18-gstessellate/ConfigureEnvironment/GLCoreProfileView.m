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

@interface GLCoreProfileView() {
@private
    GLKVector3 patchData[16];
}

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;
@property (nonatomic, assign) BOOL paused;

@property (atomic, assign) GLuint vertexArray;
@property (atomic, assign) GLuint program;

@property (atomic, assign) GLuint vertexArrayBuffer;
@property (atomic, assign) GLuint vertexIndexBuffer;
@property (atomic, assign) GLint mvMatrixLocation;
@property (atomic, assign) GLint mvpMatrixLocation;
@property (atomic, assign) GLint stretchLocation;

@end

@implementation GLCoreProfileView
#pragma mark - lifecycle methods
- (instancetype)initWithCoder:(NSCoder *)decoder {
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
    NSOpenGLContext *openGLContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
    
    
    if (self = [super initWithCoder:decoder]) {
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
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [self loadShaders];
    
    
    double cbZ = -tan(2*M_PI*30.0f/360.0f)*0.5;
    double cX = -0.5f, bx = 0.5f, ax = 0.0f;
    double aZ = tan(2*M_PI*60.0f/360.0f)*0.5+cbZ;
    double abcY = tan(2*M_PI*30.0f/360.0f)*0.5;
    double dY = -sqrtf(1 - pow(cbZ, 2))/2.0f;
    double dX = 0, dZ = 0;
    
    const GLfloat tetrahedron_verts[] = {
        // a
        ax,  abcY,  aZ,
        // b
        bx,  abcY, cbZ,
        // c
        cX,  abcY, cbZ,
        // d
        dX,  dY,    dZ
    };
    
    static const GLushort tetrahedron_indices[] = {
        0, 1, 2,
        0, 2, 3,
        0, 3, 1,
        3, 2, 1
    };
    
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
    // 顶点属性的帮顶点和缓存的绑定点都依赖于VAO
    glGenBuffers(1, &_vertexIndexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _vertexIndexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(tetrahedron_indices), tetrahedron_indices, GL_STATIC_DRAW);
    glGenBuffers(1, &_vertexArrayBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexArrayBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(tetrahedron_verts), tetrahedron_verts, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glDepthFunc(GL_LEQUAL);
}

- (void)reshape {
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    static const GLfloat black[] = { 0.0f, 0.0f, 0.0f, 1.0f  };
    static const GLfloat one = 1.0f;
    glClearBufferfv(GL_COLOR, 0, black);
    glClearBufferfv(GL_DEPTH, 0, &one);
    
    glUseProgram(_program);
    NSRect bounds = [self bounds];
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50.0f), NSWidth(bounds)/NSHeight(bounds), 0.1f, 1000.0f);
    // 演示看见的晃动是视觉误差造成
//    GLKMatrix4 rotateX = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(90.0f), 1.0f, 0.0f, 0.0f);
//    GLKMatrix4 rotateZ = GLKMatrix4MakeRotation(GLKMathDegreesToRadians((float)_lifeDuration * 71.0f), 0.0f, 0.0f, 1.0f);
//    GLKMatrix4 translation = GLKMatrix4MakeTranslation(0.0f, 0.0f, -3.0f);
//    GLKMatrix4 mvMatrix = GLKMatrix4Multiply(translation, GLKMatrix4Multiply(rotateY, rotateX));
    GLKMatrix4 rotateY = GLKMatrix4MakeRotation(GLKMathDegreesToRadians((float)_lifeDuration * 71.0f), 0.0f, 1.0f, 0.0f);
    GLKMatrix4 translation = GLKMatrix4MakeTranslation(0.0f, 0.0f, -3.0f);
    GLKMatrix4 mvMatrix = GLKMatrix4Multiply(translation, rotateY);
    GLKMatrix4 mvpMatrix = GLKMatrix4Multiply(projectionMatrix, mvMatrix);
    glUniformMatrix4fv(_mvMatrixLocation, 1, GL_FALSE, mvMatrix.m);
    glUniformMatrix4fv(_mvpMatrixLocation, 1, GL_FALSE, mvpMatrix.m);
//    glUniform1f(_stretchLocation, sinf(_lifeDuration * 4.0f) * 0.75f + 1.0f);
    glDrawElements(GL_TRIANGLES, 12, GL_UNSIGNED_SHORT, NULL);
    glFlush();
}

#pragma mark - public methods

#pragma mark - private methods
- (BOOL)loadShaders {
    GLuint vertexShader, gcShader, fragShader;
    NSString *vsPath = [[NSBundle mainBundle] pathForResource:@"gscullingVS" ofType:@"glsl"];
    NSString *gsPath = [[NSBundle mainBundle] pathForResource:@"gscullingGS" ofType:@"glsl"];
    NSString *fsPath = [[NSBundle mainBundle] pathForResource:@"gscullingFS" ofType:@"glsl"];
    
    if (![self compileShader:&vertexShader type:GL_VERTEX_SHADER filePath:vsPath]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&gcShader type:GL_GEOMETRY_SHADER filePath:gsPath]) {
        NSLog(@"Failed to compile GL_TESS_CONTROL_SHADER");
    }
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER filePath:fsPath]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    
    _program = glCreateProgram();
    glAttachShader(_program, vertexShader);
    glAttachShader(_program, gcShader);
    glAttachShader(_program, fragShader);
    GLuint shaders[] = {vertexShader, gcShader, fragShader};
    for (int i = 0; i < 4; i++) {
        GLuint deleteShader = shaders[i];
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
    _mvMatrixLocation = glGetUniformLocation(_program, "mvMatrix");
    _mvpMatrixLocation = glGetUniformLocation(_program, "mvpMatrix");
    _stretchLocation = glGetUniformLocation(_program, "stretch");
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



