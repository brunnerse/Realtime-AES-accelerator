
#include "xaxicdma.h"
#include "xdebug.h"
#include "xil_cache.h"
#include "xparameters.h"


#define BUFFER_BYTESIZE	16


volatile static u8 SrcBuffer[BUFFER_BYTESIZE] __attribute__ ((aligned (64)));
volatile static u8 DestBuffer[BUFFER_BYTESIZE] __attribute__ ((aligned (64)));


void hexToStdOut(volatile u8* array, int len)
{
	xil_printf("\t");
    for (int i = 0; i < len; i++)
    {
            xil_printf("%02x ", array[i]);
            if ((i+1) % 16 == 0)
            	xil_printf("\n\r\t");
    }
    xil_printf("\n\r");
}


int main()
{

	int Status;
	XAxiCdma AxiCdmaInstance;


	xil_printf("\r\n--- Entering main() --- \r\n");
	u16 DeviceId = XPAR_AXICDMA_0_DEVICE_ID;
	XAxiCdma_Config *CfgPtr;

	/* Initialize the XAxiCdma device.
	 */
	CfgPtr = XAxiCdma_LookupConfig(DeviceId);
	if (!CfgPtr) {
		return XST_FAILURE;
	}

	Status = XAxiCdma_CfgInitialize(&AxiCdmaInstance, CfgPtr,
		CfgPtr->BaseAddress);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/* Disable interrupts, we use polling mode
	 */
	//XAxiCdma_IntrDisable(&AxiCdmaInstance, XAXICDMA_XR_IRQ_ALL_MASK);


	// Do the write accesses
	int Length = BUFFER_BYTESIZE;
	int Index;
	int failure = 0;
	u8  *SrcPtr = (u8*)SrcBuffer;
	u8  *DestPtr = (u8*)DestBuffer;
	u8 buffer[BUFFER_BYTESIZE];

	u8* testAddresses[] = {SrcBuffer, DestBuffer, buffer,
			(u8*)0x001000000,  (u8*)0x00150000, (u8*)0x10000000, (u8*)0x15000000,
			(u8*)XPAR_PS7_DDR_0_S_AXI_HIGHADDR-BUFFER_BYTESIZE*2+1, (u8*)XPAR_PS7_DDR_0_S_AXI_BASEADDR};
	u32 numTestAddresses = sizeof(testAddresses)/sizeof(u8*);

	for (Index = 0; Index < numTestAddresses; Index++) {
		/* Initialize the source buffer bytes with a pattern and the
		 * the destination buffer bytes to zero
		 */
		SrcPtr = (u8 *)testAddresses[Index];
		DestPtr = (u8 *)testAddresses[(Index+1)%numTestAddresses];
		for (int j = 0; j < BUFFER_BYTESIZE; j++) {
			SrcPtr[j] = (j+Index) & 0xFF;
			DestPtr[j] = 0;
		}

		xil_printf("\n\rBefore transfer:\n\r");
		xil_printf("Source at %p:\n\r", SrcPtr);
		hexToStdOut(SrcPtr, BUFFER_BYTESIZE);
		xil_printf("Dest at %p:\n\r", DestPtr);
		hexToStdOut(DestPtr, BUFFER_BYTESIZE);

		/* Flush the SrcBuffer before the DMA transfer, in case the Data Cache
		 * is enabled
		 */
		Xil_DCacheFlushRange((UINTPTR)SrcPtr, Length);
		//Xil_DCacheFlushRange((UINTPTR)DestPtr, Length);

		Status = XAxiCdma_SimpleTransfer(&AxiCdmaInstance, (UINTPTR)SrcPtr,
			(UINTPTR)DestPtr, BUFFER_BYTESIZE, NULL, NULL);

		if (Status != XST_SUCCESS) {
				xil_printf("===== Error during SimpleTransfer: %d! =======\n\r", Status);
				return XST_FAILURE;
		}

		/* Wait until the DMA transfer is done
		 */
		while (XAxiCdma_IsBusy(&AxiCdmaInstance)) {
			/* Wait */
		}

		int Error = XAxiCdma_GetError(&AxiCdmaInstance);
		if (Error != 0x0) {
			xil_printf("===== Error from Cdma: %d! =======\n\r", Error);
			return XST_FAILURE;
		}


		/* Flush the DestBuffer after the DMA transfer, in case the Data Cache
		 * is enabled
		 * Flushing AFTER the call is only necessary for arrays on the stack
		 */
		Xil_DCacheFlushRange((UINTPTR)DestPtr, Length);

		xil_printf("After transfer:\n\r");
		xil_printf("Source at %p:\n\r", SrcPtr);
		hexToStdOut(SrcPtr, BUFFER_BYTESIZE);
		xil_printf("Dest at %p:\n\r", DestPtr);
		hexToStdOut(DestPtr, BUFFER_BYTESIZE);

		if(memcmp(SrcPtr, DestPtr, BUFFER_BYTESIZE) != 0)
		{
			xil_printf("===== FAILED: Data are not the same! =======\n\r");
			failure = 1;
		}

	}

	if (failure == 1)
		xil_printf("\n\rFinished tests with errors\n\r");
	else
		xil_printf("\n\rFinished test successfully!");

	/* Test finishes successfully
	 */
	return XST_SUCCESS;
}
