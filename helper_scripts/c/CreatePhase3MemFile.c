#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define CHUNKS_PER_LINE 4

#include "AES_Interface_M.h"

void coe_write(FILE *f, uint bytewidth, uint blocklen,
    const unsigned char *buf, uint len)
{
    // Header of COE file
    fprintf(f, ";Initialization file for phase 3 block ram generator\n"
      "memory_initialization_radix = 16;\n");
    fprintf(f, "memory_initialization_vector = \n");

    uint i;

    // hexdump the content of buf
    uint numChunksLine = 0;
    for (i=0; i < len; i += bytewidth) {
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
    const char* filename = "phase3_mem.coe";
    AES aes;
    u8 buf[0x3000];


    // Fill AES array and databuffer
    u8 plaintext[BLOCK_SIZE] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33 };
    u8 key[BLOCK_SIZE] =  {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };

    u8 block1[16] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33};
    u8 block2[16] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};
    u8 block3[16] = {0xaf, 0xfe, 0xde, 0xad, 0xbe, 0xef, 0xda, 0xdc, 0xab, 0xbe, 0xad, 0xbe, 0xec, 0x0c, 0xab, 0xad};

    u8 IV[16] = {0xf0, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00};

    u8 testData[BLOCK_SIZE*3];
    memcpy(testData, block1, BLOCK_SIZE);
    memcpy(testData+BLOCK_SIZE, block2, BLOCK_SIZE);
    memcpy(testData+2*BLOCK_SIZE, block3, BLOCK_SIZE);

    u8 *baseAddr = (u8*)0x560;
    u8 *baseAddrCiphertext = (u8*)0x2000;
    u8 *plaintextAddr = baseAddr;
    u8 *ciphertextAddr = baseAddrCiphertext;
    for (u32 channel = 0; channel < AES_NUM_CHANNELS; channel++)
    {
	    key[0] = channel;
    	AES_SetKey(&aes, channel, key);
    	IV[0] = channel;

    	AES_SetMode(&aes, channel, MODE_ENCRYPTION);
    	ChainingMode chMode = (channel % 3 == 0 ? CHAINING_MODE_ECB : channel % 3 == 1 ? CHAINING_MODE_CBC : CHAINING_MODE_CTR);
    	AES_SetChainingMode(&aes, channel,  chMode);
    	// for CTR Mode, set the last word of the IV to zero (as it is the index of the block)
    	if (chMode != CHAINING_MODE_CTR)
            AES_SetIV(&aes, channel, IV, BLOCK_SIZE);
    	else
            AES_SetIV(&aes, channel, IV, 12);
    	
        plaintextAddr += BLOCK_SIZE * channel;
    	ciphertextAddr += BLOCK_SIZE * channel;
        if (plaintextAddr >= baseAddrCiphertext)
        {
            printf("[ERROR] Plaintext is overlapping into ciphertext region at channel %d (0x%p). "
            "Choose a higher ciphertext base address\n", channel, plaintextAddr);
            return 1;
        }
    	uint size = BLOCK_SIZE * (channel+1);
    	// initialize arrays
    	testData[0] = channel;
    	for (u32 i = 0; i < size; i += BLOCK_SIZE * 3)
    	{
    		memcpy((uint)buf + plaintextAddr + i, testData, BLOCK_SIZE*3);

    	}
    	// Priorities don't matter here, as they are defined in the simulation VHDL file
    	AES_SetPriority(&aes, channel, 0);

    	memset((uint)buf + ciphertextAddr, 0, size);
    	AES_SetDataParameters(&aes, channel, plaintextAddr, ciphertextAddr, size);
   

        AES_startComputation(&aes, channel);
        printf("Channel %d to encrypt: (addr %p to %p, %d bytes)\n", channel, plaintextAddr, ciphertextAddr, size);
        hexToStdOut((uint)buf + plaintextAddr, size);

    }

    FILE* file = fopen(filename, "w");
    uint len = sizeof(buf);

    coe_write(file, 4, 0x3000/4, buf, len);
    fclose(file);
}