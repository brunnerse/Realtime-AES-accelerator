#include "xparameters.h"
#include "xscutimer.h"
#include "xgpiops.h"
#include "xscugic.h"

#include "xil_cache.h"
#include "xil_assert.h"
#include "xil_printf.h"
#include <stdio.h>
#include <string.h>


#include "AES_Unit_2.h"
#define AES_IVR0_OFFSET 0x20

//#define SETUP_INTERRUPT_SYSTEM

#define TEST_ECB
#define TEST_SIZE
#define TEST_MODI
#define TEST_GCM


volatile u32 interruptEvent = 0;

void onInterrupt(void* number)
{
	xil_printf("=> Interrupt called for channel %u!\n\r", (u32)number);
	interruptEvent += 1;
}

void waitForInterrupt()
{
	while (interruptEvent == 0)
		;
	// Reset interruptCount
	interruptEvent = 0;
	xil_printf("=>      Returning after interrupt...");
}


void hexToString(const u8 *array, int len, char* outStr)
{
    for (int i = 0; i < len; i++)
            sprintf(outStr+i*3, "%02x ", array[i]);
}

void hexToStdOut(const u8* array, int len)
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


#define AES_BASEADDR XPAR_AES_INTERFACE_M_0_S_AXI_BASEADDR
#define DDR_BASEADDR XPAR_PS7_DDR_0_S_AXI_BASEADDR


/* Source and Destination buffer
 */
#define BUFFER_BYTESIZE 48
//static u8 SrcBuffer[BUFFER_BYTESIZE] __attribute__ ((aligned (64)));
static u8 DestBuffer[BUFFER_BYTESIZE] __attribute__ ((aligned (64)));

u8 plaintext[BLOCK_SIZE] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33 };
u8 key[BLOCK_SIZE] =  {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };

u8 block1[BLOCK_SIZE] __attribute__ ((aligned (64))) = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33};
u8 block2[BLOCK_SIZE] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};
u8 block3[BLOCK_SIZE] = {0xaf, 0xfe, 0xde, 0xad, 0xbe, 0xef, 0xda, 0xdc, 0xab, 0xbe, 0xad, 0xbe, 0xec, 0x0c, 0xab, 0xad};

u8 IV[BLOCK_SIZE] = {0xf0, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00};

u8 trashDestBuffer[16];

int main()
{

	Xil_DCacheDisable();

    xil_printf("Running AES_Unit_2 test file %s\n\r", __FILE__);



    s32 status;
	AES aes;

#ifdef SETUP_INTERRUPT_SYSTEM
	// Initialize exceptions and the Interrupt Controller on the ARM processor
    xil_printf("Enabling exceptions..\n\r");
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

    AES_Config *aesConfigPtr = AES_LookupConfig(XPAR_AES_UNIT_2_0_DEVICE_ID);
    status = AES_CfgInitialize(&aes, aesConfigPtr);
    Xil_AssertNonvoid(status == XST_SUCCESS);
    status = AES_Mem_SelfTest((void*)(aes.BaseAddress));
    Xil_AssertNonvoid(status == XST_SUCCESS);

#ifdef SETUP_INTERRUPT_SYSTEM
	xil_printf("\n====== Testing Interrupt enable/disable =====\r\n");
    xil_printf("Starting Encryption with Interrupt enabled...\r\n");
    AES_SetInterruptEnabled(&aes, 0, 1);
    AES_startComputationECB(&aes, 0, 1, plaintext, DestBuffer, 16, onInterrupt, (void*)0);
    AES_waitUntilCompleted(&aes, 0);
	xil_printf("Starting KeyExpansion with Interrupt disabled...\r\n");
	AES_PerformKeyExpansion(&aes, 0);
    AES_waitUntilCompleted(&aes, 0);
	AES_SetInterruptEnabled(&aes, 0, 1);
    xil_printf("Starting KeyExpansion with Interrupt enabled...\r\n");
    aes.CallbackFn[0] = onInterrupt;
    aes.CallbackRef[0] = (void*)1337;
	AES_PerformKeyExpansion(&aes, 0);
    AES_waitUntilCompleted(&aes, 0);
#endif


#ifdef TEST_ECB
    // Test simple ECB encryption for each channel
	xil_printf("\n====== Testing simple ECB encryption for each channel =====\r\n");
	xil_printf("Plaintext:\r\n");
	hexToStdOut(block1, 16);

	for (u32 channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		xil_printf("Channel %d:\r\n", channel);
		u8 keyC[BLOCK_SIZE];
		memcpy(keyC, key, BLOCK_SIZE);
		keyC[0] = channel;
		AES_SetInterruptEnabled(&aes, channel, 1);
		AES_SetKey(&aes, channel, keyC);

		AES_startComputationECB(&aes, channel, 1, block1, DestBuffer, BLOCK_SIZE, onInterrupt, (void*)channel);
	    AES_waitUntilCompleted(&aes, channel);
		//Xil_DCacheInvalidateRange((UINTPTR)DestBuffer, 16);
		hexToStdOut(DestBuffer, 16);
		// Use a different key for testing the KeyExpand functionality during decryption
		xil_printf("\tEncrypt with different key:");
		AES_SetKey(&aes, channel, key);
		AES_processDataECB(&aes, channel, 1, block1, trashDestBuffer, BLOCK_SIZE);
		hexToStdOut(trashDestBuffer, 16);
		xil_printf("\tDecrypt with same key:\r\n");
		AES_SetKey(&aes, channel, keyC);
		AES_startComputationECB(&aes, channel, 0, DestBuffer, DestBuffer, BLOCK_SIZE, onInterrupt, (void*)channel);
		AES_waitUntilCompleted(&aes, channel);
		hexToStdOut(DestBuffer, 16);
		//Xil_DCacheFlushRange((UINTPTR)DestBuffer, 16);
		//hexToStdOut(DestBuffer, 16);
		xil_printf("[TEST] Channel %d successful:  %s\n\r", channel,
				memcmp(block1, DestBuffer, BLOCK_SIZE) == 0 ? "Yes" : "No");
	}
#endif
#ifdef TEST_SIZE
    // Test with different sizes
    u32 channel = 1;
    // TODO test all modi instead of choosing one?
    ChainingMode chmode = CHAINING_MODE_CBC;
	xil_printf("\n====== Testing different data sizes =====\r\n");

	for (u32 size = BLOCK_SIZE * 8; size < (32 << 20); size <<= 1)
	{
		//u32 size = BLOCK_SIZE * 100; //(u32)(1 << 10) * 1; // 1 MiB
		u8* plaintext_custom = (u8*)0x1000000;
		u8* ciphertext_custom = plaintext_custom + size;

		// init plaintext
		for (u8* addr = plaintext_custom; addr < plaintext_custom + size; addr += BLOCK_SIZE)
		{
			memcpy(addr, plaintext, BLOCK_SIZE);
			// Change plaintext slightly
			*(u32*)plaintext += 1;
		}
		xil_printf("Starting encryption...\r\n");
		AES_startComputationMode(&aes, channel, chmode, 1, plaintext_custom, ciphertext_custom, size, IV, NULL, NULL);
		AES_waitUntilCompleted(&aes, channel);

		hexToStdOut(plaintext_custom, 32);
		hexToStdOut(ciphertext_custom, 32);

		// Decrypt ciphertext inplace
		xil_printf("Starting decryption...\r\n");
		AES_startComputationMode(&aes, channel, chmode, 0, ciphertext_custom, ciphertext_custom, size, IV, NULL, NULL);
		AES_waitUntilCompleted(&aes, channel);

		hexToStdOut(ciphertext_custom, 32);

		xil_printf("[TEST] Size %u (addresses 0x%p -> 0x%p) successful:  %s\n\r", size, plaintext_custom, ciphertext_custom,
				memcmp(plaintext_custom, ciphertext_custom, size) == 0 ? "Yes" : "No");
	}
#endif

#ifdef TEST_MODI

{ // Encapsulate in block for variable scope
	xil_printf("\n====== Configuring channels for different modi tests  =====\r\n");

	// Generate test data for each channel
	u8* baseAddr = (u8*)0x1000000;
	u8 * baseAddrCiphertext = (u8*)0x1500000;
	u8* plaintextAddr[AES_NUM_CHANNELS];
    u8* ciphertextAddr[AES_NUM_CHANNELS];
    u32 size[AES_NUM_CHANNELS];
    ChainingMode chMode[AES_NUM_CHANNELS];

    u8 testData[BLOCK_SIZE*3];
    memcpy(testData, block1, BLOCK_SIZE);
    memcpy(testData+BLOCK_SIZE, block2, BLOCK_SIZE);
    memcpy(testData+2*BLOCK_SIZE, block3, BLOCK_SIZE);

    // Configure channels
    for (u32 channel = 0; channel < AES_NUM_CHANNELS; channel++)
    {
    	// Set data addresses for channel
		plaintextAddr[channel] = baseAddr + BLOCK_SIZE * (channel + 1) * channel / 2;
		ciphertextAddr[channel] = baseAddrCiphertext + BLOCK_SIZE * (channel + 1) * channel / 2;
		size[channel] = BLOCK_SIZE * (channel+1);
		// initialize data for channel
		testData[0] = channel;
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
    }

	// Test the different modi while starting multiple channels immediately after each other
	xil_printf("======================= Testing the different modi ====================\n\r");
	// Start all channels
	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
			AES_startComputation(&aes, channel); // TODO reverse order doesnt work, only in Debug mode?
	}
	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		AES_waitUntilCompleted(&aes, channel);
		xil_printf("Channel %d finished encryption:\n\r", channel);
		hexToStdOut(ciphertextAddr[channel], size[channel]);

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
	}

	for (int channel = 0; channel < 4; channel++)
	{
		AES_startComputation(&aes, channel);
	}
	for (int channel = 0; channel < 4; channel++)
	{
		AES_waitUntilCompleted(&aes, channel);
		xil_printf("Channel %d finished decryption.\n\r", channel);
	}

	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		xil_printf("[TEST] Channel %d successful:  %s\n\r", channel,
			memcmp(plaintextAddr[channel], ciphertextAddr[channel], size[channel]) == 0 ? "Yes" : "No");
	}

	xil_printf("\r\nCompleted Modi tests.\r\n");
}
#endif


#ifdef TEST_GCM
	xil_printf("\n================== GCM =====================\n\r");

	const u32 headerLen = BLOCK_SIZE*2;
	const u32 payloadLen = BLOCK_SIZE*3;


	u8 testData[BLOCK_SIZE*3], testHeader[BLOCK_SIZE*2];
	// setup header =  block1 | block3
    memcpy(testHeader, block1, BLOCK_SIZE);
    memcpy(testHeader+BLOCK_SIZE, block3, BLOCK_SIZE);
	// setup data  = block1 | block1 | block2
    memcpy(testData, block1, BLOCK_SIZE);
    memcpy(testData+BLOCK_SIZE, block1, BLOCK_SIZE);
    memcpy(testData+2*BLOCK_SIZE, block2, BLOCK_SIZE);

    u8 *baseAddr = (u8*)0x1100000;
	u8 * baseAddrCiphertext = (u8*)0x1500000;
    for (u32 channel = 0; channel < 2; channel++)
    {
    	printf("\r\nCHANNEL %lu\r\n", channel);
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
		u8* headerAddr = baseAddr + BLOCK_SIZE * 6 * channel;
		u8* plaintextAddr = baseAddr + BLOCK_SIZE * 6 * channel + BLOCK_SIZE*2;
		u8* ciphertextAddr = baseAddrCiphertext + BLOCK_SIZE * 6 * channel;
		u8* tagAddr = baseAddrCiphertext + BLOCK_SIZE * 6 * channel + BLOCK_SIZE*5;

		memcpy(headerAddr, testHeader, BLOCK_SIZE*2);
		memcpy(plaintextAddr, testData, BLOCK_SIZE*3);



		u8 Susp[BLOCK_SIZE*2];

		// TODO for this, the case len(header) = 0 or len(payload) = 0 has to be handled
		AES_startComputationGCM(&aes, channel, 1, headerAddr, headerLen, NULL, NULL, 0, IV, NULL, NULL);
		AES_waitUntilCompleted(&aes, channel);
		AES_GetSusp(&aes, channel, Susp);
		printf("Susp after header phase: \r\n");
		hexToStdOut(Susp, BLOCK_SIZE*2);

		AES_startComputationGCM(&aes, channel, 1, headerAddr, headerLen, plaintextAddr, ciphertextAddr, payloadLen, IV, NULL, NULL);
		AES_waitUntilCompleted(&aes, channel);

		AES_GetSusp(&aes, channel, Susp);
		printf("Susp after payload phase: \r\n");
		hexToStdOut(Susp, BLOCK_SIZE*2);

		// TODO make another process with higher priority that interrupts the GCM process

		// Make test with in-place decryption afterwards
		AES_processDataGCM(&aes, channel, 1, headerAddr, headerLen, plaintextAddr, ciphertextAddr, payloadLen, IV, tagAddr);
		printf("Ciphertext:\r\n");
		hexToStdOut(ciphertextAddr, BLOCK_SIZE*3);
		xil_printf("Tag after encryption:\n\r");
		hexToStdOut(tagAddr, 16);
		// decryption
		u8 decryptTag[16];
		AES_processDataGCM(&aes, channel, 0, headerAddr, headerLen, ciphertextAddr, ciphertextAddr, payloadLen, IV, decryptTag);
		xil_printf("Deciphered Ciphertext:\n\r");
		hexToStdOut(ciphertextAddr, 16*3);
		xil_printf("Tag after decryption:\n\r");
		hexToStdOut(decryptTag, 16);

		if (AES_compareTags(tagAddr, decryptTag) == 0)
			xil_printf("[TEST] Passed: Tags are equal\r\n");
		else
			xil_printf("[TEST] Failed: Tags are not equal\r\n");
    }
#endif

	xil_printf("Processed all AES tests.\n\r");


	// TODO remove this in final version
    // Configure LED as output
    XGpioPs_Config *GPIO_Config = XGpioPs_LookupConfig(XPAR_PS7_GPIO_0_DEVICE_ID);
    XGpioPs my_Gpio;
    status = XGpioPs_CfgInitialize(&my_Gpio, GPIO_Config, GPIO_Config->BaseAddr);
    XGpioPs_SetDirectionPin(&my_Gpio, 7, 1);
    XGpioPs_WritePin(&my_Gpio, 7, 1);


    // Configure timer
    XScuTimer_Config *timerConfig = XScuTimer_LookupConfig(XPAR_PS7_SCUTIMER_0_DEVICE_ID);
    XScuTimer timer;
    status = XScuTimer_CfgInitialize(&timer, timerConfig, timerConfig->BaseAddr);

    XScuTimer_LoadTimer(&timer, 100000000);
    //print("Starting timer...\n\r");
    XScuTimer_Start(&timer);

    // Switch LED on and off
    int isLedOn = 0;
    while(1)
    {
	    isLedOn = !isLedOn;
		XGpioPs_WritePin(&my_Gpio, 7, isLedOn);
	    XScuTimer_RestartTimer(&timer);
	    while (XScuTimer_GetCounterValue(&timer) > 0)
				;

     }

    return 0;
}
