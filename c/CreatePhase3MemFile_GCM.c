#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define CHUNKS_PER_LINE 4



#include "AES_Interface_M.h"
#include "AES_Interface_M_hw.h"

#define AES_NUM_CHANNELS 4

#define START_ADDR 0x10


uint Xil_EndianSwap32(uint x)
{
    uint r = 0;
    for (int i = 0; i < 32; i += 8)
    {
        uint byte = (x >> (i)) & 0xff;
        r |= byte << (24-i);
    }
    return r;
}

void coe_write(FILE *f, uint bytewidth, uint blocklen,
    const unsigned char *buf, uint len)
{
    // Header of COE file
    fprintf(f, ";Initialization file for phase 3 block ram generator\n"
      "memory_initialization_radix = 16;\n");

    fprintf(f, "\n; Format per Channel:\n");
    fprintf(f, "; CR  DataSize  DinAddr  DoutAddr\n");
    fprintf(f, "; Key\n");
    fprintf(f, "; IV\n");
    fprintf(f, "; ProcessedSize  SUSP[0:2]\n");
    fprintf(f, "; SUSP[3:6]\n");
    fprintf(f, "; SUSP[7];\n\n");

    fprintf(f, "memory_initialization_vector = \n");

    uint i;

    // hexdump the content of buf
    uint numChunksLine = 0;
    for (i=0; i < len; i += bytewidth) {

        // Insert extra newline once the channel part begins
        if (i == START_ADDR && numChunksLine % CHUNKS_PER_LINE != 0)
            fprintf(f, "\n");

        // Insert newline after each channel  
        if (i >= START_ADDR && (i % sizeof(RegisterSet) == START_ADDR) && i <= sizeof(RegisterSet)*AES_NUM_CHANNELS + START_ADDR)
        {
            fprintf(f, "\n");
            numChunksLine = 0; 
        }

        // Take the next 8 bytes out of the buffer
        unsigned long long u = *(unsigned long long *)(&buf[i]);

        fprintf(f, "%0*llX ",
                            2*bytewidth,                          // Refers to the asterisk, gives the length of the chunk
                            u & ((1LL<<(8*bytewidth))-1));         // The bytewidth bytes of this chunk 

              
        if (++numChunksLine % CHUNKS_PER_LINE == 0)
        {
                fprintf(f, "\n"); 
        }

    }
    printf("Wrote %d bytes, total is %d\n", i, blocklen*bytewidth);
    // Fill the rest of the memory with zeros until blocklen chunks have been written
    i = i/bytewidth;  // At this point, i is a multiple of bytewidth, so no chunks are accidentally skipped
    while (i < blocklen) {
        fprintf(f, "%0*llX ", 2*bytewidth, 0LL);
        if (++numChunksLine % CHUNKS_PER_LINE == 0)
            fprintf(f, "\n");
        i++;
    }
    // Enclose the memory_initialization_vector statement
    fprintf(f, ";\n");
}

void hexToStdOut(u8* array, int len)
{
	xil_printf("\t");
    for (int i = 0; i < len; i++)
    {
            xil_printf("%02x ", array[i]);
            if ((i+1) % BLOCK_SIZE == 0)
            	xil_printf("\n\r\t");
    }
    xil_printf("\n\r");
}

int main()
{
    const char* filename = "phase3_GCM_mem.coe";
    AES aes;
    u8 buf[0x3000];

    // Create AES struct and fill it with test data for each channel
    printf("Sizeof RegisterSet struct: %d\nSize of AES with %u channels: %d\n", sizeof(RegisterSet), AES_NUM_CHANNELS, sizeof(AES));
    printf("\tOf that size of Registers array: %d\t(%d * %d = %d)\n\n", sizeof(aes.Registers),
        sizeof(RegisterSet), AES_NUM_CHANNELS, sizeof(RegisterSet) * AES_NUM_CHANNELS);


    // Fill AES array and databuffer
    u8 plaintext[BLOCK_SIZE] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33 };
    u8 key[BLOCK_SIZE] =  {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };

    u8 block1[16] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33};
    u8 block2[16] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};
    u8 block3[16] = {0xaf, 0xfe, 0xde, 0xad, 0xbe, 0xef, 0xda, 0xdc, 0xab, 0xbe, 0xad, 0xbe, 0xec, 0x0c, 0xab, 0xad};

    u8 IV[16] = {0x00, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00};
    u8 H[16] = {0xc6, 0xa1, 0x3b, 0x37, 0x87, 0x8f, 0x5b, 0x82, 0x6f, 0x4f, 0x81, 0x62, 0xa1, 0xc8, 0xd8, 0x79};
    u8 SuspAfterHeader[16] = {0x3b, 0x2a, 0xbd, 0xc9, 0xbf, 0x42, 0xb8, 0x53, 0x21, 0xa4, 0x41, 0xaf, 0xc9, 0xd7, 0xa0, 0x06};
    u8 SuspAfterPayload[16] = {0x5c, 0x58, 0x89, 0x20, 0x43, 0xc9, 0x3c, 0x29, 0xbf, 0xb7, 0x1e, 0x68, 0x3c, 0xb1, 0x11, 0x53};


    u8 testData[BLOCK_SIZE*3], testHeader[BLOCK_SIZE*2];
    memcpy(testHeader, block1, BLOCK_SIZE);
    memcpy(testHeader+BLOCK_SIZE, block3, BLOCK_SIZE);

    memcpy(testData, block1, BLOCK_SIZE);
    memcpy(testData+BLOCK_SIZE, block1, BLOCK_SIZE);
    memcpy(testData+2*BLOCK_SIZE, block2, BLOCK_SIZE);

    printf("IV:");
    hexToStdOut(IV, BLOCK_SIZE);
    printf("\nHeader:");
    hexToStdOut(testHeader, BLOCK_SIZE*2);
    printf("Payld:");
    hexToStdOut(testData, BLOCK_SIZE*3);

    u8 *baseAddr = (u8*)0x540;
    u8 *baseAddrCiphertext = (u8*)0x2000;

    u8* headerAddr = baseAddr;
    u8* plaintextAddr = baseAddr + BLOCK_SIZE*2;
    u8* finalAddr = baseAddr + BLOCK_SIZE*5;
    u8* ciphertextAddr = baseAddrCiphertext;
    u8* tagAddr = baseAddrCiphertext + BLOCK_SIZE*5;


    for (u32 channel = 0; channel <  4; channel++)
    {
    	AES_SetKey(&aes, channel, key);
    	AES_SetIV(&aes, channel, IV, 12);
        // Set last word of IV to 0
    	*(u32*)(&aes.Registers[channel].IV[12]) = 0;
    	AES_SetMode(&aes, channel, MODE_ENCRYPTION);
    	ChainingMode chMode = CHAINING_MODE_GCM;
    	AES_SetChainingMode(&aes, channel,  chMode);

        if (channel == 0)
        {
            AES_SetGCMPhase(&aes, channel, GCM_PHASE_INIT);
            // AES_SetDataParameters(&aes, channel, NULL, NULL, BLOCK_SIZE);
        }
        else if (channel == 1)
        {
            AES_SetGCMPhase(&aes, channel, GCM_PHASE_HEADER);
            AES_SetDataParameters(&aes, channel, headerAddr, NULL, BLOCK_SIZE*2);
            memcpy((uint)buf + headerAddr, testHeader, BLOCK_SIZE*2);
            memset(aes.Registers[channel].Susp, 0, BLOCK_SIZE);
            memcpy(aes.Registers[channel].Susp + BLOCK_SIZE, H, BLOCK_SIZE);
        }
        else if (channel == 2)
        {
            *(u32*)(&aes.Registers[channel].IV[12]) = 0x02000000;
            AES_SetGCMPhase(&aes, channel, GCM_PHASE_PAYLOAD);
            AES_SetDataParameters(&aes, channel, plaintextAddr, ciphertextAddr, BLOCK_SIZE*3);
            memcpy((uint)buf + plaintextAddr, testData, BLOCK_SIZE*3);
            memcpy(aes.Registers[channel].Susp, SuspAfterHeader, BLOCK_SIZE);
            memcpy(aes.Registers[channel].Susp + BLOCK_SIZE, H, BLOCK_SIZE);

        }
        else if (channel == 3)
        {
            *(u32*)(&aes.Registers[channel].IV[12]) = 0x01000000;
            AES_SetGCMPhase(&aes, channel, GCM_PHASE_FINAL);
	        AES_SetDataParameters(&aes, channel, finalAddr, tagAddr, BLOCK_SIZE);
            memcpy(aes.Registers[channel].Susp, SuspAfterPayload, BLOCK_SIZE);
            memcpy(aes.Registers[channel].Susp + BLOCK_SIZE, H, BLOCK_SIZE);
            u8 finalData[BLOCK_SIZE];
            *(u32*)finalData = 0;
            *(u32*)(finalData+4) = Xil_EndianSwap32(2*16*8);
            *(u32*)(finalData+8) = 0;
            *(u32*)(finalData+12) = Xil_EndianSwap32(3*16*8);
            memcpy((uint)buf + finalAddr, finalData, BLOCK_SIZE);
        }

    	// Set default priority here; can be changed in the simulation VHDL file
    	AES_SetPriority(&aes, channel, 0);

    	memset((uint)buf + ciphertextAddr, 0, BLOCK_SIZE*3);
   
        AES_startComputation(&aes, channel);
        printf("Channel %d CR: %08x\n", channel, aes.Registers[channel].CR);

    }

    FILE* file = fopen(filename, "w");
    memcpy(buf + START_ADDR, aes.Registers, sizeof(RegisterSet) * AES_NUM_CHANNELS);
    //memcpy(buf + START_ADDR, (unsigned char*)aes.Registers, sizeof(aes.Registers));
    uint len = sizeof(buf);

    coe_write(file, 4, 0x3000/4, buf, len);
    fclose(file);
}