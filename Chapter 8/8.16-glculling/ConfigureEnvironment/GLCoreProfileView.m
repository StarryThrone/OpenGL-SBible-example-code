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

@property (atomic, assign) GLint vLightPositionLocation;
@property (atomic, assign) GLint mvMatrixLocation;
@property (nonatomic, assign) GLint mvpMatrixLocation;
@property (nonatomic, assign) GLint viewpointLocation;



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
    
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
    [self loadShaders];
    [[TDModelManger shareManager] loadObjectWithFileName:@"bunny_1k.sbm"];
    glEnable(GL_DEPTH_TEST);
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
    
    float f = (float)_lifeDuration;
    glUseProgram(_program);
    NSRect bounds = [self bounds];
    GLKMatrix4 proj_matrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50.0f), NSWidth(bounds)/NSHeight(bounds), 0.1f, 1000.0f);
    GLKMatrix4 translation_matrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -1.0f);
    GLKMatrix4 scale_matrix = GLKMatrix4MakeScale(2, 2, 2);
    GLKMatrix4 mv_matrix = GLKMatrix4Multiply(translation_matrix, scale_matrix);
    GLKMatrix4 mvp_matrix = GLKMatrix4Multiply(proj_matrix, mv_matrix);
    glUniformMatrix4fv(_mvpMatrixLocation, 1, GL_FALSE, mvp_matrix.m);
    glUniformMatrix4fv(_mvMatrixLocation, 1, GL_FALSE, mv_matrix.m);
    GLfloat vViewPoint[] = {sinf(f * 2.1f) * 70.0f, cosf(f*1.4f)*70.0f, sinf(f*0.7f)*70.f};
    glUniform3fv(_viewpointLocation, 1, vViewPoint);
    [[TDModelManger shareManager] render];
    
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
    _viewpointLocation = glGetUniformLocation(_program, "viewpoint");
    _vLightPositionLocation = glGetUniformLocation(_program, "vLightPosition");
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



