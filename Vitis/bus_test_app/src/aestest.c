#include "xparameters.h"
#include "xscutimer.h"
#include "xuartps.h"
#include "xgpiops.h"

#include "xil_printf.h"
#include <stdio.h>
#include <string.h>


#include "AES_Interface.h"

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


#define AES_BASEADDR XPAR_AES_INTERFACE_0_S_AXI_BASEADDR
#define DDR_BASEADDR XPAR_PS7_DDR_0_S_AXI_BASEADDR

int main()
{
    xil_printf("Starting main\n");
	// Do a test write to the DDR memory
    /*u32 val = Xil_In32(DDR_BASEADDR);
	Xil_Out32(DDR_BASEADDR, 0xdeadbeef);
	val = Xil_In32(DDR_BASEADDR);
	*/

    int status;

    AES_Config *aesConfig = AES_LookupConfig(XPAR_AES_INTERFACE_0_DEVICE_ID);
    AES aes;
    AES_Initialize(&aes, aesConfig->BaseAddress);

    //status = AES_Mem_SelfTest((void*)(aes.BaseAddress));

    u8 plaintext[BLOCK_SIZE] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33 };
    u8 key[BLOCK_SIZE] =  {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };

    u8 readKey[BLOCK_SIZE];
    AES_SetKey(&aes, key);
    AES_GetKey(&aes, readKey);

    //AES_PerformKeyExpansion(&aes);

    u8 ciphertext[BLOCK_SIZE];

    AES_SetEnabled(&aes, 1);
    AES_SetChainingMode(&aes, CHAINING_MODE_ECB);
    AES_processBlock(&aes, plaintext, ciphertext);
    AES_SetEnabled(&aes, 0);

    // One quick ECB test
    char debugText[500];
    xil_printf("===== ECB ======\n\r");
    hexToString(plaintext, 16, debugText);
    xil_printf("Plaintext:\n\r\t%s\n\r", debugText);
    hexToString(ciphertext, 16, debugText);
    xil_printf("Ciphertext:\n\r\t%s\n\r", debugText);

    memcpy(plaintext, ciphertext, 16);

    AES_SetMode(&aes, MODE_DECRYPTION);
	AES_SetEnabled(&aes, 1);
	AES_processBlock(&aes, plaintext, ciphertext);
	AES_SetEnabled(&aes, 0);

	xil_printf("Ciphertext after decryption:\n\r");
	hexToStdOut(ciphertext, 16);


	// Test the different modi
	u8 block1[16] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33};
	u8 block2[16] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};
	u8 block3[16] = {0xaf, 0xfe, 0xde, 0xad, 0xbe, 0xef, 0xda, 0xdc, 0xab, 0xbe, 0xad, 0xbe, 0xec, 0x0c, 0xab, 0xad};

	u8 IV[16] = {0xf0, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00};

	u8 data[16*3];
	memcpy(data, block1, 16);
	memcpy(data+16, block2, 16);
	memcpy(data+16*2, block3, 16);

	u8 cipherdata[16*3];
	u8 deciphered_cipherdata[16*3];


	xil_printf("======================= Testing the different modi ====================\n\r");
	for (int i = 0; i < 3; i++)
	{
		if (i == 0)
		{
			xil_printf("\n==== ECB ====\n\r");
			AES_processDataECB(&aes, 1, data, cipherdata, 16*3);
			AES_processDataECB(&aes, 0, cipherdata, deciphered_cipherdata, 16*3);
		}
		else if (i == 1)
		{
			xil_printf("\n==== CBC ====\n\r");
			AES_processDataCBC(&aes, 1, data, cipherdata, 16*3, IV);
			AES_processDataCBC(&aes, 0, cipherdata, deciphered_cipherdata, 16*3, IV);
		}
		else
		{
			xil_printf("\n==== CTR ====\n\r");
			AES_processDataCTR(&aes, data, cipherdata, 16*3, IV);
			AES_processDataCTR(&aes, cipherdata, deciphered_cipherdata, 16*3, IV);
		}
		xil_printf("Plaintext:\n\r");
		hexToStdOut(data, 16*3);
		xil_printf("Ciphertext:\n\r");
		hexToStdOut(cipherdata, 16*3);
		xil_printf("Deciphered Ciphertext:\n\r");
		hexToStdOut(deciphered_cipherdata, 16*3);
	}



	xil_printf("\n==== GCM ====\n\r");
	u8 header[2*BLOCK_SIZE];
	u8 tag[BLOCK_SIZE], decryptTag[BLOCK_SIZE];

	// setup header =  block1 | block3
	memcpy(header, block1, BLOCK_SIZE);
	memcpy(header+BLOCK_SIZE, block3, BLOCK_SIZE);
	// setup data  = block1 | block1 | block2
	memcpy(data, block1, BLOCK_SIZE);
	memcpy(data+BLOCK_SIZE, block1, BLOCK_SIZE);
	memcpy(data+2*BLOCK_SIZE, block2, BLOCK_SIZE);

	AES_processDataGCM(&aes, 1, header, 2*BLOCK_SIZE, data, cipherdata, 3*BLOCK_SIZE, IV, tag);
	xil_printf("Tag after encryption:\n\r\t");
	hexToStdOut(tag, 16);
	// decryption
	AES_processDataGCM(&aes, 0, header, 2*BLOCK_SIZE, cipherdata, deciphered_cipherdata, 3*BLOCK_SIZE, IV, decryptTag);
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
