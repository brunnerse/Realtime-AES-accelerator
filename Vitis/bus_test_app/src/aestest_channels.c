#include "xparameters.h"
#include "xscutimer.h"
#include "xgpiops.h"
#include "xscugic.h"
#include "xaxicdma.h"


#include "xil_assert.h"
#include "xil_printf.h"
#include <stdio.h>
#include <string.h>


#include "AES_Interface_M.h"
#define AES_IVR0_OFFSET 0x20


volatile u32 interruptEvent = 0;

void onInterrupt0(AES* aes)
{
	xil_printf("=> Interrupt called for channel %d!\n\r", 0);
	interruptEvent += 1;
}

void onInterrupt1(AES* aes)
{
	xil_printf("=> Interrupt called for channel %d!\n\r", 1);
	interruptEvent += 1;
}
void onInterrupt2(AES* aes)
{
	xil_printf("=> Interrupt called for channel %d!\n\r", 2);
	interruptEvent += 1;
}

void onInterrupt(AES* aes)
{
	xil_printf("=> Interrupt called!\n\r");
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


void hexToString(u8 *array, int len, char* outStr)
{
    for (int i = 0; i < len; i++)
            sprintf(outStr+i*3, "%02x ", array[i]);
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


#define AES_BASEADDR XPAR_AES_INTERFACE_M_0_S_AXI_BASEADDR
#define DDR_BASEADDR XPAR_PS7_DDR_0_S_AXI_BASEADDR


/* Source and Destination buffer
 */
#define BUFFER_BYTESIZE 48
//static u8 SrcBuffer[BUFFER_BYTESIZE] __attribute__ ((aligned (64)));
static u8 DestBuffer[BUFFER_BYTESIZE] __attribute__ ((aligned (64)));

u8 plaintext[BLOCK_SIZE] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33 };
u8 key[BLOCK_SIZE] =  {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };

u8 block1[16] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33};
u8 block2[16] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};
u8 block3[16] = {0xaf, 0xfe, 0xde, 0xad, 0xbe, 0xef, 0xda, 0xdc, 0xab, 0xbe, 0xad, 0xbe, 0xec, 0x0c, 0xab, 0xad};

u8 IV[16] = {0xf0, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00};


int main()
{

	Xil_DCacheDisable();

    xil_printf("Running file %s\n\r", __FILE__);
    s32 status;


	// Initialize exceptions and the Interrupt Controller on the ARM processor
    xil_printf("Enabling exceptions..\n\r");
	XScuGic_Config *IntcConfig;
	XScuGic IntcInstance;
	IntcConfig = XScuGic_LookupConfig(XPAR_SCUGIC_0_DEVICE_ID);
	status = XScuGic_CfgInitialize(&IntcInstance, IntcConfig, IntcConfig->CpuBaseAddress);
    Xil_AssertNonvoid(status == XST_SUCCESS);
	Xil_ExceptionInit();
	// Connect the interrupt controller interrupt handler to the hardware interrupt handling logic in the processor.
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT, (Xil_ExceptionHandler)XScuGic_InterruptHandler, &IntcInstance);
	// Enable interrupts in the Processor.
	Xil_ExceptionEnable();



	// Set up the AES unit
	AES aes;
    AES_Config *aesConfigPtr = AES_LookupConfig(XPAR_AES_INTERFACE_M_0_DEVICE_ID);
    status = AES_CfgInitialize(&aes, aesConfigPtr);
    Xil_AssertNonvoid(status == XST_SUCCESS);
    status = AES_Mem_SelfTest((void*)(aes.BaseAddress));
    Xil_AssertNonvoid(status == XST_SUCCESS);
    // Interrupt test TODO remove
	AES_SetInterruptRoutine(&aes, 0, &IntcInstance, (AES_InterruptHandler)onInterrupt0);
	AES_PerformKeyExpansion(&aes, 0);
	AES_PerformKeyExpansion(&aes, 0);

	// Enable interrupts for all 8 channels
	AES_SetInterruptRoutine(&aes, 0, &IntcInstance, (AES_InterruptHandler)onInterrupt0);
	AES_SetInterruptRoutine(&aes, 1, &IntcInstance, (AES_InterruptHandler)onInterrupt1);
	AES_SetInterruptRoutine(&aes, 2, &IntcInstance, (AES_InterruptHandler)onInterrupt2);
	for (u32 channel = 3; channel < 8; channel++)
	{
		AES_SetInterruptRoutine(&aes, channel, &IntcInstance, (AES_InterruptHandler)onInterrupt);
	}

    // Test simple ECB encryption for each channel
	xil_printf("\n====== Testing simple ECB encryption for each channel =====\r\n");
	for (u32 channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		AES_SetKey(&aes, channel, key);
		AES_SetDataParameters(&aes, channel, block1 , DestBuffer, 16);
		AES_startComputation(&aes, channel);
	    AES_waitUntilCompleted(&aes, channel);
		Xil_DCacheInvalidateRange((UINTPTR)DestBuffer, 16);
		hexToStdOut(DestBuffer, 16);
		memset(DestBuffer, 0, 16);
		Xil_DCacheFlushRange((UINTPTR)DestBuffer, 16);
		//hexToStdOut(DestBuffer, 16);
	}


	// Test for Interrupt disable/enable option
	xil_printf("\n====== Testing Interrupt enable/disable =====\r\n");
    u32 channel = 5;
    xil_printf("Starting KeyExpansion...\r\n");
    AES_PerformKeyExpansion(&aes, channel);
    AES_waitUntilCompleted(&aes, channel);
	AES_SetInterruptEnabled(&aes, channel, 0);
	xil_printf("Interrupt disabled\r\nStarting KeyExpansion...\r\n");
	AES_PerformKeyExpansion(&aes, channel);
    AES_waitUntilCompleted(&aes, channel);
	AES_SetInterruptEnabled(&aes, channel, 1);
	xil_printf("Interrupt enabled again\n\r");
    xil_printf("Starting KeyExpansion...\r\n");
	AES_PerformKeyExpansion(&aes, channel);
    AES_waitUntilCompleted(&aes, channel);

    // Test with different sizes
	xil_printf("\n====== Testing different data sizes =====\r\n");
	channel = 0;
	for (u32 size = BLOCK_SIZE * 8; size < (10 << 20); size <<= 1)
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
		//AES_startNewComputationECB(&aes, channel, 1, plaintext_custom, ciphertext_custom, size);
		AES_startNewComputationCTR(&aes, channel, plaintext_custom, ciphertext_custom, size, IV);
		AES_waitUntilCompleted(&aes, channel);

		// Decrypt ciphertext inplace
		xil_printf("Starting decryption...\r\n");
		//AES_startNewComputationECB(&aes, channel, 0, ciphertext_custom, ciphertext_custom, size);
		AES_startNewComputationCTR(&aes, channel, ciphertext_custom, ciphertext_custom, size, IV);
		AES_waitUntilCompleted(&aes, channel);

		xil_printf("Test with size %u (adresses %p -> %p) successful:  %s\n\r", size, plaintext_custom, ciphertext_custom,
				memcmp(plaintext_custom, ciphertext_custom, size) == 0 ? "Yes" : "No");
	}


	xil_printf("\n====== Configuring channels for different modi tests  =====\r\n");


	// Generate test data for each channel
	u8* baseAddr = (u8*)0x1000000;
	u8 * baseAddrCiphertext = (u8*)0x1500000;
	int repeatPerChannel = 10;
	u8* plaintextAddr[AES_NUM_CHANNELS];
    u8* ciphertextAddr[AES_NUM_CHANNELS];
    u32 size[AES_NUM_CHANNELS];

    u8 testData[BLOCK_SIZE*3];
    memcpy(testData, block1, BLOCK_SIZE);
    memcpy(testData+BLOCK_SIZE, block2, BLOCK_SIZE);
    memcpy(testData+2*BLOCK_SIZE, block3, BLOCK_SIZE);

    // Configure channels
    for (u32 channel = 0; channel < AES_NUM_CHANNELS; channel++)
    {
    	key[0] = channel;
    	AES_SetKey(&aes, channel, key);
    	IV[0] = channel;
    	AES_SetIV(&aes, channel, IV, BLOCK_SIZE);
    	AES_SetMode(&aes, channel, MODE_ENCRYPTION);
    	ChainingMode chMode = (channel % 3 == 0 ? CHAINING_MODE_ECB : channel % 3 == 1 ? CHAINING_MODE_CBC : CHAINING_MODE_CTR);
    	AES_SetChainingMode(&aes, channel,  chMode);
    	// for CTR Mode, set the last word of the IV to zero (as it is the index of the block)
    	if (chMode == CHAINING_MODE_CTR)
    		AES_Write(&aes, channel, AES_IVR0_OFFSET+12, 0);
    	plaintextAddr[channel] = baseAddr + BLOCK_SIZE * 3 * repeatPerChannel * channel;
    	ciphertextAddr[channel] = baseAddrCiphertext + BLOCK_SIZE * 3 * repeatPerChannel * channel;
    	// TODO Size absteigend:  * (AES_NUM_CHANNELS - channels - 1)
    	size[channel] = BLOCK_SIZE * 3 * repeatPerChannel * (channel+1);
    	// initialize arrays
    	testData[0] = channel;
    	for (u32 i = 0; i < size[channel]; i += BLOCK_SIZE * 3)
    	{
    		testData[16] = i;
    		memcpy(plaintextAddr[channel] + i, testData, BLOCK_SIZE*3);
    	}
    	// TODO Choose different Priorities
    	AES_SetPriority(&aes, channel, 0);

    	memset(ciphertextAddr[channel], 0, size[channel]);
    	AES_SetDataParameters(&aes, channel, plaintextAddr[channel], ciphertextAddr[channel], size[channel]);
    }





	// Test the different modi
	xil_printf("======================= Testing the different modi ====================\n\r");
	// Start all channels
	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
			AES_startComputation(&aes, channel);
	}
	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		AES_waitUntilCompleted(&aes, channel);
		//xil_printf("Channel %d finished encryption.\n\r");
	}
	// switch configs between channels up, so that channel 1 decrypts channel 0 and so on
	// This checks that the keyexpansion is working correctly
	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		int prevChannel = (channel + AES_NUM_CHANNELS - 1) % AES_NUM_CHANNELS;
    	key[0] = prevChannel;
    	AES_SetKey(&aes, channel, key);
    	IV[0] = prevChannel;
    	AES_SetIV(&aes, channel, IV, BLOCK_SIZE);
    	AES_SetMode(&aes, channel, MODE_KEYEXPANSION_AND_DECRYPTION);
    	ChainingMode chMode = (prevChannel % 3 == 0 ? CHAINING_MODE_ECB : channel % 3 == 1 ? CHAINING_MODE_CBC : CHAINING_MODE_CTR);
    	AES_SetChainingMode(&aes, channel,  chMode);
    	// for CTR Mode, set the last word of the IV to zero (as it is the index of the block)
    	if (chMode == CHAINING_MODE_CTR)
    		AES_Write(&aes, channel, AES_IVR0_OFFSET+12, 0);
       	plaintextAddr[channel] = baseAddr + BLOCK_SIZE * 3 * repeatPerChannel * prevChannel;
        ciphertextAddr[channel] = baseAddrCiphertext + BLOCK_SIZE * 3 * repeatPerChannel * prevChannel;
        size[channel] = BLOCK_SIZE * 3 * repeatPerChannel * (prevChannel+1);
		// TODO priority?
	    AES_SetDataParameters(&aes, channel, plaintextAddr[channel], ciphertextAddr[channel], size[channel]);
	}

	// Decrypt in-place
	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		AES_SetMode(&aes, channel, MODE_KEYEXPANSION_AND_DECRYPTION);
		AES_SetDataParameters(&aes, channel, ciphertextAddr[channel], ciphertextAddr[channel], BLOCK_SIZE * 3 * repeatPerChannel * channel);
		AES_startComputation(&aes, channel);
	}
	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		AES_waitUntilCompleted(&aes, channel);
		xil_printf("Channel %d finished decryption.\n\r");
	}

	for (int channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		xil_printf("Check channel %d successful:  %s\n\r", channel,
			memcmp(plaintextAddr[channel], ciphertextAddr[channel], size[channel]) == 0 ? "Yes" : "No");
	}

	xil_printf("Completed tests.");


	xil_printf("\n==== GCM ====\n\r");
	u8 data[16*3];
	memcpy(data, block1, 16);
	memcpy(data+16, block2, 16);
	memcpy(data+16*2, block3, 16);

	u8 cipherdata[16*3];
	u8 deciphered_cipherdata[16*3];

	u8 header[2*BLOCK_SIZE];
	u8 tag[BLOCK_SIZE], decryptTag[BLOCK_SIZE];

	// setup header =  block1 | block3
	memcpy(header, block1, BLOCK_SIZE);
	memcpy(header+BLOCK_SIZE, block3, BLOCK_SIZE);
	// setup data  = block1 | block1 | block2
	memcpy(data, block1, BLOCK_SIZE);
	memcpy(data+BLOCK_SIZE, block1, BLOCK_SIZE);
	memcpy(data+2*BLOCK_SIZE, block2, BLOCK_SIZE);

	AES_processDataGCM(&aes, channel, 1, header, 2*BLOCK_SIZE, data, cipherdata, 3*BLOCK_SIZE, IV, tag);
	xil_printf("Tag after encryption:\n\r\t");
	hexToStdOut(tag, 16);
	// decryption
	AES_processDataGCM(&aes, channel, 0, header, 2*BLOCK_SIZE, cipherdata, deciphered_cipherdata, 3*BLOCK_SIZE, IV, decryptTag);
	xil_printf("\r\nTag after decryption:\n\r\t");
	hexToStdOut(decryptTag, 16);

	if (AES_compareTags(tag, decryptTag) == 0)
		xil_printf("Test passed: Tags are equal\r\n");
	else
		xil_printf("Test failed: Tags are not equal\r\n");

	xil_printf("\r\nPlaintext:\n\r");
	hexToStdOut(data, 16*3);
	xil_printf("Ciphertext:\n\r");
	hexToStdOut(cipherdata, 16*3);
	xil_printf("Deciphered Ciphertext:\n\r");
	hexToStdOut(deciphered_cipherdata, 16*3);


	xil_printf("Processed all AES tests.\n\r");



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


    xil_printf("Successfully ran the application");
    return 0;
}
