#include "xscugic.h"
#include "xil_cache.h"
#include "xil_assert.h"

#include <stdio.h>
#include <string.h>

#include "AES_Unit_hw.h"
#include "AES_Unit.h"


#define SETUP_INTERRUPT_SYSTEM

#define TEST_ECB
#define TEST_SIZE
#define TEST_MODI
#define TEST_GCM

#define MIN(x, y) (((x) < (y)) ? (x) : (y))

volatile u32 interruptEvent = 0;



void onInterrupt(void* number)
{
	printf("=> Interrupt called for channel %u!\n\r", (UINTPTR)number);
	interruptEvent += 1;
}

void waitForInterrupt()
{
	while (interruptEvent == 0)
		;
	// Reset interruptCount
	interruptEvent = 0;
	printf("=>      Returning after interrupt...");
}


void hexToString(const char *array, int len, char* outStr)
{
    for (int i = 0; i < len; i++)
            sprintf(outStr+i*3, "%02x ", array[i]);
}

void hexToStdOut(const char* array, int len)
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


char passedAllTests = 1;
const char* getMemEqual(const char* block1, const char* block2, const u32 size)
{
	if (memcmp(block1, block2, size) == 0) {
		return "Yes";
	} else {
		passedAllTests = 0;
		return "No";
	}
}


/* Source and Destination buffer
 */
#define BUFFER_BYTESIZE 48
//static char SrcBuffer[BUFFER_BYTESIZE] __attribute__ ((aligned (64)));
static char DestBuffer[BUFFER_BYTESIZE] __attribute__ ((aligned (64)));

char plaintext[BLOCK_SIZE] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33 };
char key[BLOCK_SIZE] =  {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };

char block1[BLOCK_SIZE] __attribute__ ((aligned (64))) = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33};
char block2[BLOCK_SIZE] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};
char block3[BLOCK_SIZE] = {0xaf, 0xfe, 0xde, 0xad, 0xbe, 0xef, 0xda, 0xdc, 0xab, 0xbe, 0xad, 0xbe, 0xec, 0x0c, 0xab, 0xad};

char IV[BLOCK_SIZE] = {0xf0, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00};

char trashDestBuffer[16];



int main()
{

	Xil_DCacheDisable();

    printf("Running AES_Unit test file %s\n\r", __FILE__);



    s32 status;
	AES aes;

#ifdef SETUP_INTERRUPT_SYSTEM
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

	status = XScuGic_CfgInitialize(&IntCtrl, IntcConfig,
					IntcConfig->CpuBaseAddress);
	if (status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	u32 IntrId =  XPS_FPGA0_INT_ID;
	XScuGic_SetPriorityTriggerType(&IntCtrl, IntrId, 0xA0, 0x1);
	status = XScuGic_Connect(&IntCtrl, IntrId, (Xil_InterruptHandler)AES_IntrHandler,
					&aes);
	if (status != XST_SUCCESS) {
		return status;
	}
	XScuGic_Enable(&IntCtrl, IntrId);

#endif


	// Set up the AES unit

    AES_Config *aesConfigPtr = AES_LookupConfig(0);
    status = AES_CfgInitialize(&aes, aesConfigPtr);
    Xil_AssertNonvoid(status == XST_SUCCESS);
    status = AES_Mem_SelfTest((void*)(aes.BaseAddress));
    Xil_AssertNonvoid(status == XST_SUCCESS);

#ifdef SETUP_INTERRUPT_SYSTEM
	printf("\n====== Testing Interrupt enable/disable =====\r\n");
    printf("Starting Encryption with Interrupt enabled...\r\n");
    AES_SetInterruptEnabled(&aes, 0, 1);
    AES_startComputationECB(&aes, 0, 1, plaintext, DestBuffer, 16, onInterrupt, (void*)0);
    AES_waitUntilCompleted(&aes, 0);
	printf("Starting KeyExpansion with Interrupt disabled...\r\n");
    AES_SetInterruptEnabled(&aes, 0, 0);
	AES_PerformKeyExpansion(&aes, 0);
    AES_waitUntilCompleted(&aes, 0);
    printf("Starting KeyExpansion with Interrupt enabled...\r\n");
	AES_SetInterruptEnabled(&aes, 0, 1);
    aes.CallbackFn[0] = onInterrupt;
    aes.CallbackRef[0] = (void*)1337;
	AES_PerformKeyExpansion(&aes, 0);
    AES_waitUntilCompleted(&aes, 0);
#endif


#ifdef TEST_ECB
    // Test simple ECB encryption for each channel
	printf("\n====== Testing simple ECB encryption for each channel =====\r\n");
	printf("Plaintext:\r\n");
	hexToStdOut(block1, 16);

	for (u32 channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		printf("Channel %d:\r\n", channel);
		char keyC[BLOCK_SIZE];
		memcpy(keyC, key, BLOCK_SIZE);
		keyC[0] = channel;
		AES_SetInterruptEnabled(&aes, channel, 1);
		AES_SetKey(&aes, channel, keyC);

		AES_startComputationECB(&aes, channel, 1, block1, DestBuffer, BLOCK_SIZE, onInterrupt, (void*)(UINTPTR)channel);
	    AES_waitUntilCompleted(&aes, channel);
		//Xil_DCacheInvalidateRange((UINTPTR)DestBuffer, 16);
		hexToStdOut(DestBuffer, 16);
		// Use a different key for testing the KeyExpand functionality during decryption
		printf("\tEncrypt with different key:\r\n\t");
		AES_SetKey(&aes, channel, key);
		AES_processDataECB(&aes, channel, 1, block1, trashDestBuffer, BLOCK_SIZE);
		hexToStdOut(trashDestBuffer, 16);
		printf("\tDecrypt with same key:\r\n");
		AES_SetKey(&aes, channel, keyC);
		AES_startComputationECB(&aes, channel, 0, DestBuffer, DestBuffer, BLOCK_SIZE, onInterrupt, (void*)(UINTPTR)channel);
		AES_waitUntilCompleted(&aes, channel);
		hexToStdOut(DestBuffer, 16);
		//Xil_DCacheFlushRange((UINTPTR)DestBuffer, 16);
		//hexToStdOut(DestBuffer, 16);
		printf("[TEST] Channel %d successful:  %s\n\r", channel, getMemEqual(block1, DestBuffer, BLOCK_SIZE));
	}
#endif
#ifdef TEST_SIZE
    // Test with different sizes
    u32 channel = AES_NUM_CHANNELS - 1; // use last channel
    ChainingMode chmode = CHAINING_MODE_CBC;
	printf("\n====== Testing different data sizes =====\r\n");

	for (u32 size = BLOCK_SIZE * 8; size < (32 << 20); size <<= 1)
	{
		//u32 size = BLOCK_SIZE * 100; //(u32)(1 << 10) * 1; // 1 MiB
		char* plaintext_custom = (char*)0x1000000;
		char* ciphertext_custom = plaintext_custom + size;

		// init plaintext
		for (char* addr = plaintext_custom; addr < plaintext_custom + size; addr += BLOCK_SIZE)
		{
			memcpy(addr, plaintext, BLOCK_SIZE);
			// Change plaintext slightly
			*(u32*)plaintext += 1;
		}
		printf("Starting encryption...\r\n");
		AES_startComputationMode(&aes, channel, chmode, 1, plaintext_custom, ciphertext_custom, size, IV, onInterrupt, (void*)(UINTPTR)channel);
		AES_waitUntilCompleted(&aes, channel);

		hexToStdOut(plaintext_custom, 32);
		hexToStdOut(ciphertext_custom, 32);

		// Decrypt ciphertext inplace
		printf("Starting decryption...\r\n");
		AES_startComputationMode(&aes, channel, chmode, 0, ciphertext_custom, ciphertext_custom, size, IV, onInterrupt, (void*)(UINTPTR)channel);
		AES_waitUntilCompleted(&aes, channel);

		hexToStdOut(ciphertext_custom, 32);

		printf("[TEST] Size %u (addresses 0x%p -> 0x%p) successful:  %s\n\r", size, plaintext_custom, ciphertext_custom,
				getMemEqual(plaintext_custom, ciphertext_custom, size));
	}
#endif

#ifdef TEST_MODI

{ // Encapsulate in block for variable scope
	printf("\n====== Configuring channels for different modi tests  =====\r\n");

	// Generate test data for each channel

	char* plaintextAddr[AES_NUM_CHANNELS];
    char* ciphertextAddr[AES_NUM_CHANNELS];
    u32 size[AES_NUM_CHANNELS];
    ChainingMode chMode[AES_NUM_CHANNELS];

    char testData[BLOCK_SIZE*3];
    memcpy(testData, block1, BLOCK_SIZE);
    memcpy(testData+BLOCK_SIZE, block2, BLOCK_SIZE);
    memcpy(testData+2*BLOCK_SIZE, block3, BLOCK_SIZE);

	char* baseAddr = (char*)0x1000000;
	char * baseAddrCiphertext = baseAddr;

    // set sizes and calculate ciphertext base address
    for (u32 channel = 0; channel < AES_NUM_CHANNELS; channel++)
    {
		size[channel] = 100 * BLOCK_SIZE * (AES_NUM_CHANNELS - channel+1);
		baseAddrCiphertext += size[channel];
    }

    // Configure channels
    for (u32 channel = 0; channel < AES_NUM_CHANNELS; channel++)
    {
    	// Set data addresses for channel
    	if (channel == 0) {
    		plaintextAddr[channel] = baseAddr;
    		ciphertextAddr[channel] = baseAddrCiphertext;
    	} else {
    		plaintextAddr[channel] = plaintextAddr[channel-1] + size[channel-1];
    		ciphertextAddr[channel] = ciphertextAddr[channel-1] + size[channel-1];
    	}

		// initialize data for channel
		testData[0] = channel;
		// Small overflow here possible if size[channel] isn't divisible by BLOCK_SIZE*3, but that is not a real issue
		for (u32 i = 0; i < size[channel]; i += BLOCK_SIZE * 3)
		{
			memcpy(plaintextAddr[channel] + i, testData, BLOCK_SIZE*3);
		}
		// Init ciphertext with 0
		memset(ciphertextAddr[channel], 0, size[channel]);


		// Configure channel
		// Initialize priorities in decreasing order
		AES_SetPriority(&aes, channel, AES_MAX_PRIORITY - channel );

    	key[0] = channel;
    	AES_SetKey(&aes, channel, key);
    	AES_SetMode(&aes, channel, MODE_ENCRYPTION);

    	chMode[channel] = (channel % 3 == 0 ? CHAINING_MODE_ECB : channel % 3 == 1 ? CHAINING_MODE_CBC : CHAINING_MODE_CTR);
    	AES_SetChainingMode(&aes, channel,  chMode[channel]);

    	// for CTR Mode, set the last word of the IV to zero (as it is the index of the block)
    	// Set IV
    	IV[0] = channel;
    	if (chMode[channel] == CHAINING_MODE_CTR)
    	{
    		AES_SetIV(&aes, channel, IV, 12);
    		AES_Write(&aes, channel, AES_IVR0_OFFSET+12, 0);
    	}
    	else
        {
    		AES_SetIV(&aes, channel, IV, BLOCK_SIZE);
        }

		AES_SetDataParameters(&aes, channel, plaintextAddr[channel], ciphertextAddr[channel], size[channel]);

		// setup interrupt
		AES_SetInterruptEnabled(&aes, channel, 1);
		AES_SetInterruptCallback(&aes, channel, onInterrupt, (void*)(UINTPTR)channel);

		printf("\t Channel %d:\tpriority %2d,\t%6d = 0x%04x bytes\n\r", channel, AES_GetPriority(&aes, channel), size[channel], size[channel]);
    }

	// Test the different modi while starting multiple channels immediately after each other
	printf("======================= Testing the different modi ====================\n\r");
	// Start all channels
	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		AES_startComputation(&aes, channel);
	}
	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		AES_waitUntilCompleted(&aes, channel);
		printf("Channel %d finished encryption:\n\r", channel);
		hexToStdOut(ciphertextAddr[channel], MIN(size[channel], BLOCK_SIZE*3));

		// Setup in-place decryption
		AES_SetDataParameters(&aes, channel, ciphertextAddr[channel], ciphertextAddr[channel], size[channel]);
		AES_SetMode(&aes, channel, MODE_DECRYPTION);
		// Reset IV again
		IV[0] = channel;
		if (chMode[channel] == CHAINING_MODE_CTR)
		{
			AES_SetIV(&aes, channel, IV, 12);
			AES_Write(&aes, channel, AES_IVR0_OFFSET+12, 0);
		}
		else if (chMode[channel] == CHAINING_MODE_CBC)
		{
			AES_SetIV(&aes, channel, IV, BLOCK_SIZE);
		}
		// setup interrupt
		AES_SetInterruptEnabled(&aes, channel, 1);
		AES_SetInterruptCallback(&aes, channel, onInterrupt, (void*)(UINTPTR)channel);
	}

	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		AES_startComputation(&aes, channel);
	}
	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		AES_waitUntilCompleted(&aes, channel);
		printf("Channel %d finished decryption.\n\r", channel);
	}

	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		printf("[TEST] Channel %d successful:  %s\n\r", channel,
			getMemEqual(plaintextAddr[channel], ciphertextAddr[channel], size[channel]));
	}

	printf("\r\nCompleted Modi tests.\r\n");
}
#endif


#ifdef TEST_GCM
	printf("\n================== GCM =====================\n\r");

	const u32 headerLen = BLOCK_SIZE*2;
	const u32 payloadLen = BLOCK_SIZE*3;


	char testData[BLOCK_SIZE*3], testHeader[BLOCK_SIZE*2];
	// setup header =  block1 | block3
    memcpy(testHeader, block1, BLOCK_SIZE);
    memcpy(testHeader+BLOCK_SIZE, block3, BLOCK_SIZE);
	// setup data  = block1 | block1 | block2
    memcpy(testData, block1, BLOCK_SIZE);
    memcpy(testData+BLOCK_SIZE, block1, BLOCK_SIZE);
    memcpy(testData+2*BLOCK_SIZE, block2, BLOCK_SIZE);

    char *baseAddr = (char*)0x1100000;
	char * baseAddrCiphertext = (char*)0x1500000;
    for (u32 channel = 0; channel < 2; channel++)
    {
    	printf("\r\nCHANNEL %u\r\n", channel);
    	// Change data slightly for each channel
    	IV[0] = channel;
		testHeader[0] = channel;
	    testData[0] = channel;
	    key[0] = channel;

	    AES_SetKey(&aes, channel, key);

		printf("IV:\r\n");
		hexToStdOut(IV, BLOCK_SIZE);
		printf("Key:\r\n");
		hexToStdOut(key, BLOCK_SIZE);
		printf("Header:\r\n");
		hexToStdOut(testHeader, BLOCK_SIZE*2);
		printf("Payload:\r\n");
		hexToStdOut(testData, BLOCK_SIZE*3);

		// Setup data
		AES_SetKey(&aes, channel, key);
		char* headerAddr = baseAddr + BLOCK_SIZE * 6 * channel;
		char* plaintextAddr = baseAddr + BLOCK_SIZE * 6 * channel + BLOCK_SIZE*2;
		char* ciphertextAddr = baseAddrCiphertext + BLOCK_SIZE * 6 * channel;
		char* tagAddr = baseAddrCiphertext + BLOCK_SIZE * 6 * channel + BLOCK_SIZE*5;

		memcpy(headerAddr, testHeader, BLOCK_SIZE*2);
		memcpy(plaintextAddr, testData, BLOCK_SIZE*3);


		AES_startComputationGCM(&aes, channel, 1, headerAddr, headerLen, NULL, NULL, 0, IV, NULL, NULL);
		AES_waitUntilCompleted(&aes, channel);

#if !AES_REG_KEY_WRITEONLY
		char Susp[BLOCK_SIZE*2];
		AES_GetSusp(&aes, channel, Susp);
		printf("Susp after header phase: \r\n");
		hexToStdOut(Susp, BLOCK_SIZE*2);
#endif
		AES_startComputationGCM(&aes, channel, 1, headerAddr, headerLen, plaintextAddr, ciphertextAddr, payloadLen, IV, NULL, NULL);
		AES_waitUntilCompleted(&aes, channel);
#if !AES_REG_KEY_WRITEONLY
		AES_GetSusp(&aes, channel, Susp);
		printf("Susp after payload phase: \r\n");
		hexToStdOut(Susp, BLOCK_SIZE*2);
#endif
		// Make test with in-place decryption afterwards
		AES_processDataGCM(&aes, channel, 1, headerAddr, headerLen, plaintextAddr, ciphertextAddr, payloadLen, IV, tagAddr);
		printf("Ciphertext:\r\n");
		hexToStdOut(ciphertextAddr, BLOCK_SIZE*3);
		printf("Tag after encryption:\n\r");
		hexToStdOut(tagAddr, 16);
		// decryption
		char decryptTag[16];
		AES_processDataGCM(&aes, channel, 0, headerAddr, headerLen, ciphertextAddr, ciphertextAddr, payloadLen, IV, decryptTag);
		printf("Deciphered Ciphertext:\n\r");
		hexToStdOut(ciphertextAddr, 16*3);
		printf("Tag after decryption:\n\r");
		hexToStdOut(decryptTag, 16);

		if (AES_compareTags(tagAddr, decryptTag) == 0) {
			printf("[TEST] Passed: Tags are equal\r\n");
		} else {
			printf("[TEST] Failed: Tags are not equal\r\n");
			passedAllTests = 0;
		}
    }
#endif
    if (passedAllTests) {
    	printf("\n\r[PASSED] ");
	} else {
    	printf("\n\r[FAILED] ");
    }
	printf("Processed all AES tests.\n\r");


    return 0;
}
