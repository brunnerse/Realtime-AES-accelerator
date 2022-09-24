#include "xparameters.h"
#include "xscutimer.h"
#include "xuartps.h"
#include "xgpiops.h"

#include <stdio.h>

#include "AES_Interface.h"



#define AES_BASEADDR XPAR_AES_INTERFACE_0_S_AXI_BASEADDR
#define DDR_BASEADDR XPAR_PS7_DDR_0_S_AXI_BASEADDR

int main()
{
    print("Starting main\n\r");
	// Do a test write to the DDR memory
    u32 val = Xil_In32(DDR_BASEADDR);
	Xil_Out32(DDR_BASEADDR, 0xdeadbeef);
	val = Xil_In32(DDR_BASEADDR);

    int status;

    AES_Config *aesConfig = AES_LookupConfig(XPAR_AES_INTERFACE_0_DEVICE_ID);
    AES aes;
    AES_Initialize(&aes, aesConfig->BaseAddress);

    //status = AES_Mem_SelfTest((void*)(aes.BaseAddress));

    u8 plaintext[BLOCK_SIZE] = {0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33 };
    u8 key[BLOCK_SIZE] =  {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };

    //u8 plaintext[BLOCK_SIZE] = {0x30, 0x20, 0x10, 0x00, 0x31, 0x21, 0x11, 0x01, 0x32, 0x22, 0x12, 0x02, 0x33, 0x23, 0x13, 0x03};
    //u8 key[BLOCK_SIZE] =  {0x03, 0x02, 0x01, 0x00, 0x07, 0x06, 0x05, 0x04, 0x0b, 0x0a, 0x09, 0x08, 0x0f, 0x0e, 0x0d, 0x0c };

    u8 readKey[BLOCK_SIZE];
    AES_GetKey(&aes, readKey);
    AES_SetKey(&aes, key);
    AES_GetKey(&aes, readKey);
    u32 testNumber = 0x01020304;
    u8 testArr[] = {0x01, 0x02, 0x03, 0x04};
    AES_SetEnabled(&aes, 1);
    Xil_Out32(AES_BASEADDR+8, testNumber);
    Xil_Out32(AES_BASEADDR+8, *(u32*)testArr);
    Xil_Out32(AES_BASEADDR+8, 0);
    AES_SetEnabled(&aes, 0);
    AES_SetEnabled(&aes, 1);
    for (int i = 0; i < 4; i++)
    	Xil_Out8(AES_BASEADDR+8+i, testArr[i]);

    Mode mode = MODE_ENCRYPTION;
    AES_SetMode(&aes, mode);
    AES_SetChainingMode(&aes, CHAINING_MODE_ECB);
    ChainingMode chMode = AES_GetChainingMode(&aes);

    u8 ciphertext[BLOCK_SIZE];

    AES_SetEnabled(&aes, 1);
    AES_processBlock(&aes, plaintext, ciphertext);

    char debugText[500];

    for (int i = 0; i < 16; i++)
            sprintf(debugText+i*3, "%02x ", plaintext[i]);
    for (int i = 0; i < 16; i++)
                sprintf(debugText+i*3, "%02x ", ciphertext[i]);

    AES_processBlock(&aes, plaintext, ciphertext);
    AES_SetEnabled(&aes, 0);
    //AES_processData(&aes, MODE_ENCRYPTION, CHAINING_MODE_ECB, plaintext, ciphertext, 16);


    XUartPs_Config *uartConfig = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
    XUartPs uart;
    status =  XUartPs_CfgInitialize(&uart, uartConfig, uartConfig->BaseAddress);

    status = XUartPs_SelfTest(&uart);
    //XUartPs_SetBaudRate(&uart, 9600);
    XUartPsFormat format;
    XUartPs_GetDataFormat(&uart, &format);
    u8 str[8] = {49, 50, 51, 52, 53, 54, 10, 13};
    XUartPs_Send(&uart, str, 8);

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
