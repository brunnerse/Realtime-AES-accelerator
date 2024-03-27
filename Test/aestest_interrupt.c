#include "xgpiops.h"
#include "xscugic.h"
#include "xil_assert.h"

#include <stdio.h>
#include <string.h>


#include "AES_Unit.h"


volatile u32 interruptEvent = 0;


void onInterrupt(void *data)
{
	printf("\nInterrupt called (data %p)\n\r", data);
	interruptEvent += 1;
}

void waitForInterrupt()
{
	while (interruptEvent == 0)
		;
	// Reset interruptCount
	interruptEvent = 0;
	printf("\n Returning after interrupt...\n");
}


void hexToString(char *array, int len, char* outStr)
{
    for (int i = 0; i < len; i++)
            sprintf(outStr+i*3, "%02x ", array[i]);
}

void hexToStdOut(char* array, int len)
{
	printf("\t");
    for (int i = 0; i < len; i++)
    {
            printf("%02x ", array[i]);
            if ((i+1) % BLOCK_SIZE == 0)
            	printf("\n\r\t");
    }
    printf("\n\r");
}

int main(int argc, char *argv[])
{
    s32 status;
    printf("Running AES_Unit test file %s\n\r", __FILE__);

	// Set up the AES unit
	AES aes;
    AES_Config *aesConfigPtr = AES_LookupConfig(0);
    status = AES_CfgInitialize(&aes, aesConfigPtr);

	// Initialize exceptions and the Interrupt Controller on the ARM processor
    printf("Enabling exceptions..\n\r");
    XScuGic IntCtrl;

	Xil_ExceptionInit();
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT,
				(Xil_ExceptionHandler)XScuGic_InterruptHandler,
				&IntCtrl);
	Xil_ExceptionEnable();

	XScuGic_Config* IntcConfig = XScuGic_LookupConfig(XPAR_SCUGIC_0_DEVICE_ID);
	if (NULL == IntcConfig) {
		return XST_FAILURE;
	}
	status = XScuGic_CfgInitialize(&IntCtrl, IntcConfig, IntcConfig->CpuBaseAddress);
	if (status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	u32 IntrId =  XPS_FPGA0_INT_ID;
	XScuGic_SetPriorityTriggerType(&IntCtrl, IntrId, 0xA0, 0x1);
	status = XScuGic_Connect(&IntCtrl, IntrId, (Xil_InterruptHandler)AES_IntrHandler, &aes);
	if (status != XST_SUCCESS) {
		return status;
	}
	XScuGic_Enable(&IntCtrl, IntrId);

    u32 channel = 0;

    status = AES_Mem_SelfTest((void*)(aes.BaseAddress));

    AES_SetInterruptEnabled(&aes, channel, 1);
	AES_SetInterruptCallback(&aes, channel, onInterrupt, (void*)(UINTPTR)channel);



    char plaintext[BLOCK_SIZE] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33 };
    char key[BLOCK_SIZE] =  {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };



    AES_SetKey(&aes, channel, key);
#if !AES_REG_KEY_WRITEONLY
    char readKey[BLOCK_SIZE];
    AES_GetKey(&aes, channel, readKey);
#endif


	AES_SetDataParameters(&aes, channel, (char*)0x7aa00010, (char*)0x7aa00020, 16);
	AES_startComputation(&aes, channel);
    AES_waitUntilCompleted(&aes, channel);

	AES_SetDataParameters(&aes, channel, (char*)0x7aa00000, (char*)0x7aa00030, 32);
	AES_startComputation(&aes, channel);
    AES_waitUntilCompleted(&aes, channel);

    // Try it with fresh addresses
    char* const plaintext_custom =  (char*)0x100000;
    char* const ciphertext_custom = (char*)0x110000;

    for (char* addr = plaintext_custom; addr < plaintext_custom + BLOCK_SIZE*10; addr += BLOCK_SIZE)
    	memcpy(addr, plaintext, BLOCK_SIZE);


    AES_SetDataParameters(&aes, channel, plaintext_custom, ciphertext_custom, BLOCK_SIZE);
    AES_startComputation(&aes, channel);
    AES_waitUntilCompleted(&aes, channel);

    AES_SetDataParameters(&aes, channel, plaintext_custom, ciphertext_custom, BLOCK_SIZE*3);
	AES_startComputation(&aes, channel);
	AES_waitUntilCompleted(&aes, channel);

	u32 size = (u32)(ciphertext_custom - plaintext_custom);
    AES_SetDataParameters(&aes, channel, plaintext_custom, ciphertext_custom, size);
    AES_startComputation(&aes, channel);
    AES_waitUntilCompleted(&aes, channel);

    memcpy(plaintext_custom, ciphertext_custom, size);
    AES_startComputation(&aes, channel);
    waitForInterrupt();




	// Test the different modi
	char block1[16] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33};
	char block2[16] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};
	char block3[16] = {0xaf, 0xfe, 0xde, 0xad, 0xbe, 0xef, 0xda, 0xdc, 0xab, 0xbe, 0xad, 0xbe, 0xec, 0x0c, 0xab, 0xad};

	char IV[16] = {0xf0, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00};

	char data[16*3];
	memcpy(data, block1, 16);
	memcpy(data+16, block2, 16);
	memcpy(data+16*2, block3, 16);

	char cipherdata[16*3];
	char deciphered_cipherdata[16*3];


	printf("======================= Testing the different modi ====================\n\r");
	for (int i = 0; i < 3; i++)
	{
		if (i == 0)
		{
			printf("\n==== ECB ====\n\r");
			AES_processDataECB(&aes, channel, 1, data, cipherdata, 16*3);
			AES_processDataECB(&aes, channel, 0, cipherdata, deciphered_cipherdata, 16*3);
		}
		else if (i == 1)
		{
			printf("\n==== CBC ====\n\r");
			AES_processDataCBC(&aes, channel, 1, data, cipherdata, 16*3, IV);
			AES_processDataCBC(&aes, channel, 0, cipherdata, deciphered_cipherdata, 16*3, IV);
		}
		else
		{
			printf("\n==== CTR ====\n\r");
			AES_processDataCTR(&aes, channel, data, cipherdata, 16*3, IV);
			AES_processDataCTR(&aes, channel, cipherdata, deciphered_cipherdata, 16*3, IV);
		}
		printf("Plaintext:\n\r");
		hexToStdOut(data, 16*3);
		printf("Ciphertext:\n\r");
		hexToStdOut(cipherdata, 16*3);
		printf("Deciphered Ciphertext:\n\r");
		hexToStdOut(deciphered_cipherdata, 16*3);
	}



	printf("\n==== GCM ====\n\r");
	char header[2*BLOCK_SIZE];
	char tag[BLOCK_SIZE], decryptTag[BLOCK_SIZE];

	// setup header =  block1 | block3
	memcpy(header, block1, BLOCK_SIZE);
	memcpy(header+BLOCK_SIZE, block3, BLOCK_SIZE);
	// setup data  = block1 | block1 | block2
	memcpy(data, block1, BLOCK_SIZE);
	memcpy(data+BLOCK_SIZE, block1, BLOCK_SIZE);
	memcpy(data+2*BLOCK_SIZE, block2, BLOCK_SIZE);

	AES_processDataGCM(&aes, channel, 1, header, 2*BLOCK_SIZE, data, cipherdata, 3*BLOCK_SIZE, IV, tag);
	printf("Tag after encryption:\n\r\t");
	hexToStdOut(tag, 16);
	// decryption
	AES_processDataGCM(&aes, channel, 0, header, 2*BLOCK_SIZE, cipherdata, deciphered_cipherdata, 3*BLOCK_SIZE, IV, decryptTag);
	printf("\r\nTag after decryption:\n\r\t");
	hexToStdOut(decryptTag, 16);

	if (AES_compareTags(tag, decryptTag) == 0)
		printf("Test passed: Tags are equal\r\n");
	else
		printf("Test failed: Tags are not equal\r\n");

	printf("\r\nPlaintext:\n\r");
	hexToStdOut(data, 16*3);
	printf("Ciphertext:\n\r");
	hexToStdOut(cipherdata, 16*3);
	printf("Deciphered Ciphertext:\n\r");
	hexToStdOut(deciphered_cipherdata, 16*3);


	printf("Processed all AES tests.\n\r");

    return 0;
}
