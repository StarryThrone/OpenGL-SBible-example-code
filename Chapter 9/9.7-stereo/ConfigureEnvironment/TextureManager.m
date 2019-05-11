//
//  TextureManager.m
//  ConfigureEnvironment
//
//  Created by 陈杰 on 11/12/2017.
//  Copyright © 2017 陈杰. All rights reserved.
//

#import "TextureManager.h"
#import <stdio.h>

// KTX文件标识符
static const unsigned char identifier[] = {
    0xAB, 0x4B, 0x54, 0x58, 0x20, 0x31, 0x31, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A
};

// 用于计算单个纹理像素偏离大小，pad用于控制像素行对其方式，取1.2.4.8.16....，这样返回的数字一定为pad的整数倍
static unsigned int calculate_stride(const header *h, unsigned int width, unsigned int pad) {
    unsigned int channels = 0;
    switch (h->glbaseinternalformat) {
        case GL_RED:    channels = 1;
            break;
        case GL_RG:     channels = 2;
            break;
        case GL_BGR:
        case GL_RGB:    channels = 3;
            break;
        case GL_BGRA:
        case GL_RGBA:   channels = 4;
            break;
    }

    unsigned int stride = h->gltypesize * channels * width;
    stride = (stride + (pad - 1)) & ~(pad - 1);
    return stride;
}

static unsigned int calculate_face_size(const header *h) {
    unsigned int stride = calculate_stride(h, h->pixelwidth, 4);
    return stride * h->pixelheight;
}

@implementation TextureManager

+ (instancetype)shareManager {
    static TextureManager *shareManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareManager = [[TextureManager alloc] init];
    });
    return shareManager;
}

- (int)loadObjectWithFileName:(NSString *)name toTextureID:(GLuint *)texureID {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:name ofType:nil];
    FILE *fp;
    header h;
    size_t data_start, data_end;
    unsigned char *data;
    GLenum target = GL_NONE;
    
    fp = fopen([filePath cStringUsingEncoding:NSUTF8StringEncoding], "rb");
    if (!fp) {
        return -1;
    }
    if (fread(&h, sizeof(h), 1, fp) != 1) {
        return -1;
    }
    if (memcmp(h.identifier, identifier, sizeof(identifier)) != 0) {
        return -1;
    }
    
    if (h.endianness == 0x04030201) {
        // 小端模式不用转换
    } else if (h.endianness == 0x01020304) {
        h.endianness            = CFSwapInt32(h.endianness);
        h.gltype                = CFSwapInt32(h.gltype);
        h.gltypesize            = CFSwapInt32(h.gltypesize);
        h.glformat              = CFSwapInt32(h.glformat);
        h.glinternalformat      = CFSwapInt32(h.glinternalformat);
        h.glbaseinternalformat  = CFSwapInt32(h.glbaseinternalformat);
        h.pixelwidth            = CFSwapInt32(h.pixelwidth);
        h.pixelheight           = CFSwapInt32(h.pixelheight);
        h.pixeldepth            = CFSwapInt32(h.pixeldepth);
        h.arrayelements         = CFSwapInt32(h.arrayelements);
        h.faces                 = CFSwapInt32(h.faces);
        h.miplevels             = CFSwapInt32(h.miplevels);
        h.keypairbytes          = CFSwapInt32(h.keypairbytes);
    } else {
        // 解析失败，无法确定大小端模式
    }
    
    // 确定纹理类型
    if (h.pixelheight == 0) {
        if (h.arrayelements == 0) {
            target = GL_TEXTURE_1D;
        } else {
            target = GL_TEXTURE_1D_ARRAY;
        }
    } else if (h.pixeldepth == 0) {
        if (h.arrayelements == 0) {
            if (h.faces == 0) {
                target = GL_TEXTURE_2D;
            } else {
                target = GL_TEXTURE_CUBE_MAP;
            }
        } else {
            if (h.faces == 0) {
                target = GL_TEXTURE_2D_ARRAY;
            } else {
                target = GL_TEXTURE_CUBE_MAP_ARRAY;
            }
        }
    } else {
        target = GL_TEXTURE_3D;
    }
    
    // Couldn't figure out target---Texture has no width???---// Texture has depth but no height???
    if (target == GL_NONE || (h.pixelwidth == 0) || (h.pixelheight == 0 && h.pixeldepth != 0)) {
        return -1;
    }
    
    if (*texureID == 0) {
        glGenTextures(1, texureID);
    }
    glBindTexture(target, *texureID);
    
    data_start = ftell(fp) + h.keypairbytes;
    fseek(fp, 0, SEEK_END);
    data_end = ftell(fp);
    fseek(fp, data_start, SEEK_SET);
    
    data = (unsigned char *)malloc(data_end-data_start);
    memset(data, 0, data_end-data_start);
    
    fread(data, 1, data_end-data_start, fp);
    
    if (h.miplevels == 0) {
        h.miplevels = 1;
    }
    
    switch (target) {
            //0x0DE0    3552
        case GL_TEXTURE_1D:
            glTexImage1D(GL_TEXTURE_1D, h.miplevels, h.glinternalformat, h.pixelwidth, 0, h.glformat, h.gltype, data);
            break;
            //0x0DE1    3553
        case GL_TEXTURE_2D: {
            unsigned char *ptr = data;
            int height = h.pixelheight;
            int width = h.pixelwidth;
            // 纹理中使用紧凑型像素布局
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            for (int i = 0; i < h.miplevels; i++) {
                glTexImage2D(GL_TEXTURE_2D, i, h.glinternalformat, width, height, 0, h.glformat, h.gltype, ptr);
                ptr += height * calculate_stride(&h, width, 1);
                height >>= 1;
                width >>= 1;
                if (!height) {
                    height = 1;
                }
                if (!width) {
                    width = 1;
                }
            }
        }
            break;
            //0x806F    32879
        case GL_TEXTURE_3D:
            glTexImage3D(GL_TEXTURE_3D, h.miplevels, h.glinternalformat, h.pixelwidth, h.pixelheight, h.pixeldepth, 0, h.glformat, h.gltype, data);
            break;
            //0x8C18    35864
        case GL_TEXTURE_1D_ARRAY:
            glTexImage2D(GL_TEXTURE_1D_ARRAY, h.miplevels, h.glinternalformat, h.pixelwidth, h.arrayelements, 0, h.glformat, h.gltype, data);
            break;
            //0x8C1A    35866
        case GL_TEXTURE_2D_ARRAY:
            glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, h.glinternalformat, h.pixelwidth, h.pixelheight, h.arrayelements, 0, h.glformat, h.gltype, data);
            break;
            //0x8513    34067
        case GL_TEXTURE_CUBE_MAP: {
            unsigned int face_size = calculate_face_size(&h);
            for (int i = 0; i < h.faces; i++) {
                glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, h.miplevels, h.glinternalformat, h.pixelwidth, h.pixelheight, 0, h.glformat, h.gltype, data+face_size*i);
            }
        }
            break;
            //0x9009    36873
        case GL_TEXTURE_CUBE_MAP_ARRAY:
            glTexImage3D(GL_TEXTURE_CUBE_MAP_ARRAY, h.miplevels, h.glinternalformat, h.pixelwidth, h.pixelheight, h.arrayelements, 0, h.glformat, h.gltype, data);
            break;
        default:
            return -1;
            break;
    }
    
    // 生成分级纹理
    if (h.miplevels == 1) {
        glGenerateMipmap(target);
    }

    free(data);
    fclose(fp);
    return *texureID;
}
@end
