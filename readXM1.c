// readXM1: load module for Fuji X-M1 RAF file
//
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#define MAX(a,b)    a>b?a:b // Larger Value

struct XM1_head{
    char    magicNum[16];       // magic number in ASCII, to be 'FUJIFILMCCD-RAW' 
    char    address[4];         // to be '0201' in ASCII
    char    modelID[8];
    char    modelName[32];      // to be 'X-M1' in ASCII
    char    version[4];         // to be '0100' in ASCII
    char    UNDEF1[20];         // filler
    int     JPEG_addr;          // Address offset to JPEG area
    int     JPEG_size;          // Size of JPEG area
    int     CFAhead_addr;       // Address of CFA header area
    int     CFAhead_size;       // Size of CFA header area
    int     CFA_addr;           // Address of CFA data
    int     CFA_size;           // Size of CFA data
    char    UNDEF2[40];         // filler
};

union headerInterpreter {   // char <-> int interpreter
    unsigned char byte[4];
    int           as_int;
    short         as_short[2];
};

int RAFhead(
    char    *fname,     // File name to open
    struct  XM1_head *RAFheader)
{
    FILE    *file_ptr;  // File Pointer

    if((file_ptr = fopen(fname, "r")) == NULL){ return(-1);}       // Open RAF file
    fread(RAFheader, sizeof(struct XM1_head), 1, file_ptr);
    fclose(file_ptr);
    return(0);
}    

int CFAhead(
    char    *fname,         // File name to open
    int     addr_offset,    // address to the CFA header
    int     CFA_head_size,  // Byte size of the CFA header
    short   *rawFullsize )  // Pointer to raw Full size
{
    FILE    *file_ptr;      // File Pointer
    unsigned char *tmpHead; // memory area for reading the header
    union headerInterpreter tmpInterpreter;
    int     record_num;         // Number of records in CFA header
    int     byte_offset = 0;    // Bytes from the top of CFA header
    int     rec_index;          // loop index
    short   CFA_ID;             // CFA ID
    short   recSize;            // CFA ID

    if((file_ptr = fopen(fname, "r")) == NULL){ return(-1);}       // Open RAF file

    /*---- Read CFA header as unsigned char ----*/
    tmpHead = (unsigned char *)malloc(CFA_head_size);
    fseek(file_ptr, addr_offset, SEEK_SET);
    fread(tmpHead, CFA_head_size, 1, file_ptr);
    fclose(file_ptr);

    //---- Number of records
    memcpy(tmpInterpreter.byte, tmpHead, sizeof(int));
    byte_offset += sizeof(int);
    record_num = __builtin_bswap32(tmpInterpreter.as_int);
    printf("Num_rec =  %d\n", record_num);

    //---- CFA ID
    memcpy(tmpInterpreter.byte, &tmpHead[byte_offset], sizeof(int));
    byte_offset += sizeof(int);
    CFA_ID = __builtin_bswap16(tmpInterpreter.as_short[0]);
    recSize= __builtin_bswap16(tmpInterpreter.as_short[1]);
    printf("CFA_ID, size =  %X %d\n", CFA_ID, recSize);

    //---- raw Full size
    memcpy(tmpInterpreter.byte, &tmpHead[byte_offset], recSize);
    byte_offset += recSize;
    rawFullsize[0] = __builtin_bswap16(tmpInterpreter.as_short[0]);
    rawFullsize[1] = __builtin_bswap16(tmpInterpreter.as_short[1]);
    printf("FULL size =  %d %d\n", __builtin_bswap16(tmpInterpreter.as_short[0]), __builtin_bswap16(tmpInterpreter.as_short[1]));

    free(tmpHead);
    return(0);
}

int RAWread(
    char    *fname,
    int     raw_addr,
    int     rawByte,
    short   *rawFormat,
    unsigned short   *rawImage)
{
    FILE    *file_ptr;  // File Pointer
    unsigned char   *rawData;
    union headerInterpreter tmpInterpreter;

    rawData = (unsigned char *)malloc(rawByte);
    if((file_ptr = fopen(fname, "r")) == NULL){ return(-1);}       // Open RAF file
    fseek(file_ptr, raw_addr, SEEK_SET);
    fread(rawData, rawByte, 1, file_ptr);
    fclose(file_ptr);

    //---- raw Endian
    memcpy(tmpInterpreter.byte, rawData, sizeof(int));
    printf("Endian = %X  Magic Number = %X\n", tmpInterpreter.as_short[0], tmpInterpreter.as_short[1]);
    

    memcpy(rawImage, &rawData[0x800], 0x181500);
    return(0);
}

int main(
    int     argc,       // Number of arguments
    char    **argv)     // Pointer to arguments
{
    struct XM1_head     RAF_header;
    short   fullSize[2];
    unsigned short  *rawImage;  // Pointer to the raw Image

    printf("Reading RAF header [%d bytes]\n", (int)sizeof(RAF_header));
    RAFhead(argv[1], &RAF_header);
    printf("magic = %s\n", RAF_header.magicNum);
    printf("address %s\n", RAF_header.address);
    printf("Model   %s\n", RAF_header.modelID);
    printf("Version %s\n", RAF_header.version);
    printf("JPEG addr %X\n", __builtin_bswap32(RAF_header.JPEG_addr));
    printf("JPEG size %X\n", __builtin_bswap32(RAF_header.JPEG_size));
    printf("CFA addr %X\n", __builtin_bswap32(RAF_header.CFAhead_addr));
    printf("CFAhead addr %X\n", __builtin_bswap32(RAF_header.CFAhead_addr));
    printf("CFAhead size %X\n", __builtin_bswap32(RAF_header.CFAhead_size));
    printf("CFA addr %X\n", __builtin_bswap32(RAF_header.CFA_addr));
    printf("CFA size %X\n", __builtin_bswap32(RAF_header.CFA_size));
    //
    CFAhead(argv[1], __builtin_bswap32(RAF_header.CFAhead_addr), __builtin_bswap32(RAF_header.CFAhead_addr), fullSize);
    printf("FULL size %d %d\n", fullSize[0], fullSize[1]);
    rawImage = (unsigned short *)malloc(3* fullSize[0]* fullSize[1]);       // Image area 
    RAWread(argv[1], __builtin_bswap32(RAF_header.CFA_addr), __builtin_bswap32(RAF_header.CFA_size), fullSize, rawImage);
    free(rawImage);
    return(0);    
}
