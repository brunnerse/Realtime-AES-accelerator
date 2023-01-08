#include "xparameters.h"
#include "xscutimer.h"
#include "xgpiops.h"
#include "xscugic.h"

#include "xil_cache.h"
#include "xil_assert.h"
#include "xil_printf.h"
#include <stdio.h>
#include <string.h>


#include "AES_Unit_0.h"
#define AES_IVR0_OFFSET 0x20

#define SETUP_INTERRUPT_SYSTEM

#define TEST_ECB
#define TEST_SIZE
#define TEST_MODI
#define TEST_GCM


void onInterrupt(void* number)
{
	xil_printf("=> Interrupt called!\n\r");
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

    xil_printf("Running AES_Unit_0 test file %s\n\r", __FILE__);



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
	XScuGic_SetPriorityTriggerType(&IntCtrl, IntrId, 0xA0, 0x3);
	status = XScuGic_Connect(&IntCtrl, IntrId, (Xil_InterruptHandler)onInterrupt,
					&aes);
	if (status != XST_SUCCESS) {
		return status;
	}
	XScuGic_Enable(&IntCtrl, IntrId);

#endif


	// Set up the AES unit

    AES_Config *aesConfigPtr = AES_LookupConfig(XPAR_AES_UNIT_0_0_DEVICE_ID);
    status = AES_CfgInitialize(&aes, aesConfigPtr);
    Xil_AssertNonvoid(status == XST_SUCCESS);
    status = AES_Mem_SelfTest((void*)(aes.BaseAddress));
    Xil_AssertNonvoid(status == XST_SUCCESS);

#ifdef SETUP_INTERRUPT_SYSTEM
	xil_printf("\n====== Testing Interrupt enable/disable =====\r\n");
    xil_printf("Starting Encryption with Interrupt enabled...\r\n");
    AES_SetInterruptEnabled(&aes, 1);
    AES_processDataECB(&aes, 1, plaintext, DestBuffer, 16);
	xil_printf("Starting KeyExpansion with Interrupt disabled...\r\n");
    AES_SetInterruptEnabled(&aes, 0);
	AES_PerformKeyExpansion(&aes);
	AES_SetInterruptEnabled(&aes, 1);
    xil_printf("Starting KeyExpansion with Interrupt enabled...\r\n");
	AES_PerformKeyExpansion(&aes);
#endif


#ifdef TEST_ECB
    // Test simple ECB encryption
	xil_printf("\n====== Testing simple ECB encryption =====\r\n");
	xil_printf("Plaintext:\r\n");
	hexToStdOut(block1, 16);

	for (u32 testnum = 0; testnum < 8; testnum++)
	{
		xil_printf("Test %d:\r\n", testnum);
		u8 keyC[BLOCK_SIZE];
		memcpy(keyC, key, BLOCK_SIZE);
		keyC[0] = testnum;
		AES_SetInterruptEnabled(&aes, 0);
		AES_SetKey(&aes, keyC);

		AES_processDataECB(&aes, 1, block1, DestBuffer, BLOCK_SIZE);
		//Xil_DCacheInvalidateRange((UINTPTR)DestBuffer, 16);
		hexToStdOut(DestBuffer, 16);
		// Use a different key for testing the KeyExpand functionality during decryption
		xil_printf("\tEncrypt with different key:\n\r\t");
		AES_SetKey(&aes, key);
		AES_processDataECB(&aes, 1, block1, trashDestBuffer, BLOCK_SIZE);
		hexToStdOut(trashDestBuffer, 16);
		xil_printf("\tDecrypt with same key:\r\n");
		AES_SetKey(&aes, keyC);
		AES_processDataECB(&aes, 0, DestBuffer, DestBuffer, BLOCK_SIZE);
		hexToStdOut(DestBuffer, 16);
		//Xil_DCacheFlushRange((UINTPTR)DestBuffer, 16);
		//hexToStdOut(DestBuffer, 16);
		xil_printf("[TEST] Test %d successful:  %s\n\r", testnum,
				memcmp(block1, DestBuffer, BLOCK_SIZE) == 0 ? "Yes" : "No");
	}
#endif
#ifdef TEST_SIZE
    // Test with different sizes in CBC mode
	xil_printf("\n====== Testing different data sizes =====\r\n");

	for (u32 size = BLOCK_SIZE * 8; size < (32 << 20); size <<= 1)
	{
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
		AES_processDataCBC(&aes, 1, plaintext_custom, ciphertext_custom, size, IV);

		hexToStdOut(plaintext_custom, 32);
		hexToStdOut(ciphertext_custom, 32);

		// Decrypt ciphertext inplace
		xil_printf("Starting decryption...\r\n");
		AES_processDataCBC(&aes, 0, ciphertext_custom, ciphertext_custom, size, IV);

		hexToStdOut(ciphertext_custom, 32);

		xil_printf("[TEST] Size %u (addresses 0x%p -> 0x%p) successful:  %s\n\r", size, plaintext_custom, ciphertext_custom,
				memcmp(plaintext_custom, ciphertext_custom, size) == 0 ? "Yes" : "No");
	}
#endif

#ifdef TEST_MODI

{ // Encapsulate in block for variable scope
	xil_printf("\n======================= Testing the different modi ====================\n\r");
	// Generate test data for each mode
	u8* baseAddr = (u8*)0x1000000;
	u8 * baseAddrCiphertext = (u8*)0x1500000;
	u8* plaintextAddr;
    u8* ciphertextAddr;
    u32 size;

    u8 testData[BLOCK_SIZE*3];
    memcpy(testData, block1, BLOCK_SIZE);
    memcpy(testData+BLOCK_SIZE, block2, BLOCK_SIZE);
    memcpy(testData+2*BLOCK_SIZE, block3, BLOCK_SIZE);

    // Configure modi
    for (u32 chmode = 0; chmode < 3; chmode++)
    {
    	// Set data addresses for channel
		plaintextAddr = baseAddr + BLOCK_SIZE * (chmode + 1) * chmode / 2;
		ciphertextAddr = baseAddrCiphertext + BLOCK_SIZE * (chmode + 1) * chmode / 2;
		size = BLOCK_SIZE * (chmode+1);
		// initialize data for mode
		testData[0] = chmode;
		for (u32 i = 0; i < size; i += BLOCK_SIZE * 3)
		{
			memcpy(plaintextAddr + i, testData, BLOCK_SIZE*3);
		}
		// Init ciphertext with 0
		memset(ciphertextAddr, 0, size);


		// Configure channel
		// Initialize priorities in decreasing order
    	key[0] = chmode;
    	AES_SetKey(&aes, key);
    	AES_SetMode(&aes, MODE_ENCRYPTION);

    	AES_SetChainingMode(&aes,  chmode);

    	// for CTR Mode, set the last word of the IV to zero (as it is the index of the block)
    	// Set IV
    	IV[0] = chmode;

    	if (chmode == CHAINING_MODE_ECB)
    	{
    		AES_processDataECB(&aes, 1, plaintextAddr, ciphertextAddr, size);
    	}
    	else if (chmode == CHAINING_MODE_CBC)
    	{
    		AES_SetIV(&aes, IV, BLOCK_SIZE);
    		AES_processDataCBC(&aes, 1, plaintextAddr, ciphertextAddr, size, IV);
    	}
    	else if (chmode == CHAINING_MODE_CTR)
    	{
    		AES_SetIV(&aes, IV, 12);
    		AES_Write(&aes, AES_IVR0_OFFSET+12, 0);
    		AES_processDataCTR(&aes, plaintextAddr, ciphertextAddr, size, IV);
    	}
		xil_printf("[Mode] %u Finished encryption:\n\r", chmode);
		hexToStdOut(ciphertextAddr, size);

		// In-place decryption
    	IV[0] = chmode;

    	if (chmode == CHAINING_MODE_ECB)
    	{
    		AES_processDataECB(&aes, 0, ciphertextAddr, ciphertextAddr, size);
    	}
    	else if (chmode == CHAINING_MODE_CBC)
    	{
    		AES_SetIV(&aes, IV, BLOCK_SIZE);
    		AES_processDataCBC(&aes, 0, ciphertextAddr, ciphertextAddr, size, IV);
    	}
    	else if (chmode == CHAINING_MODE_CTR)
    	{
    		AES_SetIV(&aes, IV, 12);
    		AES_Write(&aes, AES_IVR0_OFFSET+12, 0);
    		AES_processDataCTR(&aes, ciphertextAddr, ciphertextAddr, size, IV);
    	}

		xil_printf("[TEST] Mode %d successful:  %s\n\r", chmode,
			memcmp(plaintextAddr, ciphertextAddr, size) == 0 ? "Yes" : "No");
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
    for (u32 testnum = 0; testnum < 2; testnum++)
    {
    	printf("\r\nTest %lu\r\n", testnum);
    	// Change data slightly for each testnum
    	IV[0] = testnum;
		testHeader[0] = testnum;
	    testData[0] = testnum;
	    key[0] = testnum;

	    AES_SetKey(&aes, key);

		printf("IV:\r\n");
		hexToStdOut(IV, BLOCK_SIZE);
		printf("Key:\r\n");
		hexToStdOut(key, BLOCK_SIZE);
		printf("Header:\r\n");
		hexToStdOut(testHeader, BLOCK_SIZE*2);
		printf("Payload:\r\n");
		hexToStdOut(testData, BLOCK_SIZE*3);

		// Setup data
		AES_SetKey(&aes, key);
		u8* headerAddr = baseAddr + BLOCK_SIZE * 6 * testnum;
		u8* plaintextAddr = baseAddr + BLOCK_SIZE * 6 * testnum + BLOCK_SIZE*2;
		u8* ciphertextAddr = baseAddrCiphertext + BLOCK_SIZE * 6 * testnum;
		u8* tagAddr = baseAddrCiphertext + BLOCK_SIZE * 6 * testnum + BLOCK_SIZE*5;

		memcpy(headerAddr, testHeader, BLOCK_SIZE*2);
		memcpy(plaintextAddr, testData, BLOCK_SIZE*3);

		// Make test with in-place decryption afterwards
		AES_processDataGCM(&aes, 1, headerAddr, headerLen, plaintextAddr, ciphertextAddr, payloadLen, IV, tagAddr);
		printf("Ciphertext:\r\n");
		hexToStdOut(ciphertextAddr, BLOCK_SIZE*3);
		xil_printf("Tag after encryption:\n\r");
		hexToStdOut(tagAddr, 16);
		// decryption
		u8 decryptTag[16];
		AES_processDataGCM(&aes, 0, headerAddr, headerLen, ciphertextAddr, ciphertextAddr, payloadLen, IV, decryptTag);
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


	// When test are through, blink with an LED for fun

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
