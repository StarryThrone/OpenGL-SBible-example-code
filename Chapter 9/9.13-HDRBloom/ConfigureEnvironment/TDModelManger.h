//
//  TDModelManger.h
//  ConfigureEnvironment
//
//  Created by 陈杰 on 11/12/2017.
//  Copyright © 2017 陈杰. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>
#import <GLKit/GLKit.h>

#define SB6M_FOURCC(a,b,c,d)            ( ((unsigned int)(a) << 0) | ((unsigned int)(b) << 8) | ((unsigned int)(c) << 16) | ((unsigned int)(d) << 24) )

#define SB6M_VERTEX_ATTRIB_FLAG_NORMALIZED      0x00000001
#define SB6M_VERTEX_ATTRIB_FLAG_INTEGER         0x00000002

// 数据块类型
typedef enum SB6M_CHUNK_TYPE_t {
    SB6M_CHUNK_TYPE_INDEX_DATA      = SB6M_FOURCC('I','N','D','X'),
    SB6M_CHUNK_TYPE_VERTEX_DATA     = SB6M_FOURCC('V','R','T','X'),
    SB6M_CHUNK_TYPE_VERTEX_ATTRIBS  = SB6M_FOURCC('A','T','R','B'),
    SB6M_CHUNK_TYPE_SUB_OBJECT_LIST = SB6M_FOURCC('O','L','S','T'),
    SB6M_CHUNK_TYPE_COMMENT         = SB6M_FOURCC('C','M','N','T')
} SB6M_CHUNK_TYPE;

// 文件头
typedef struct SB6M_HEADER_t {
    union {
        unsigned int    magic;
        char            magic_name[4];
    };
    unsigned int        size;
    unsigned int        num_chunks;
    unsigned int        flags;
} SB6M_HEADER;

// 数据块头
typedef struct SB6M_CHUNK_HEADER_t {
    union {
        unsigned int    chunk_type;
        char            chunk_name[4];
    };
    unsigned int        size;
} SB6M_CHUNK_HEADER;

// 顶点属性数据块对象描述
typedef struct SB6M_VERTEX_ATTRIB_DECL_t {
    char                name[64];
    unsigned int        size;
    unsigned int        type;
    unsigned int        stride;
    unsigned int        flags;
    unsigned int        data_offset;
} SB6M_VERTEX_ATTRIB_DECL;

// 顶点属性数据块
typedef struct SB6M_VERTEX_ATTRIB_CHUNK_t {
    SB6M_CHUNK_HEADER           header;
    unsigned int                attrib_count;
    SB6M_VERTEX_ATTRIB_DECL     attrib_data[1];
} SB6M_VERTEX_ATTRIB_CHUNK;

// 顶点位置数据块
typedef struct SB6M_CHUNK_VERTEX_DATA_t {
    SB6M_CHUNK_HEADER   header;
    unsigned int        data_size;
    unsigned int        data_offset;
    unsigned int        total_vertices;
} SB6M_CHUNK_VERTEX_DATA;

// 索引数据块
typedef struct SB6M_CHUNK_INDEX_DATA_t {
    SB6M_CHUNK_HEADER   header;
    unsigned int        index_type;
    unsigned int        index_count;
    unsigned int        index_data_offset;
} SB6M_CHUNK_INDEX_DATA;

// 子对象描述
typedef struct SB6M_SUB_OBJECT_DECL_t {
    unsigned int                first;
    unsigned int                count;
} SB6M_SUB_OBJECT_DECL;

// 子对象列表数据块
typedef struct SB6M_CHUNK_SUB_OBJECT_LIST_t {
    SB6M_CHUNK_HEADER           header;
    unsigned int                count;
    SB6M_SUB_OBJECT_DECL        sub_object[1];
} SB6M_CHUNK_SUB_OBJECT_LIST;

@interface TDModelManger : NSObject

@property (nonatomic, assign, readonly) GLuint vao;
@property (nonatomic, assign, readonly) NSInteger num_sub_objects;

+ (instancetype)shareManager;
- (void)loadObjectWithFileName:(NSString *)name;
- (void)render;
- (void)renderWithInstanceCount:(NSUInteger)count;
- (void)getSubObjectInfoWithIndex:(NSUInteger)index first:(GLuint *)first count:(GLuint *)count;
- (void)free;

@end
