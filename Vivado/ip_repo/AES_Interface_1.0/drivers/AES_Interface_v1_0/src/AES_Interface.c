

/***************************** Include Files *******************************/
#include "AES_Interface.h"
/************************** Function Definitions ***************************/


#define AES_CR_OFFSET 0x00
#define AES_SR_OFFSET 0x04
#define AES_DINR_OFFSET 0x08
#define AES_DOUTR_OFFSET 0x0c
#define AES_KEYR0_OFFSET 0x10
#define AES_IVR0_OFFSET 0x20
#define AES_SUSPR0_OFFSET 0x40


int AES_Initialize(AES *InstancePtr, UINTPTR BaseAddr)
{
    InstancePtr->BaseAddress = BaseAddr;
    return (XST_SUCCESS);
}

void AES_SetKey(AES *InstancePtr, u8 key[BLOCK_SIZE])
{
   for (int i = 0; i < 4; i++)
        AES_Write(InstancePtr, AES_KEYR0_OFFSET+i*4, *(u32*)(key+i*4));
}
void AES_SetMode(AES *InstancePtr, Mode mode)
{
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
    // Set bit 3 and 4 to mode: first set them to 1, then clear them using logic and
    cr |= 0x3 << 3;
    cr &= ((u32)mode & 0x3) << 3;
    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
}

void AES_SetChainingMode(AES* InstancePtr, ChainingMode chainMode)
{
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
    // Set bit 5,6 and 16 to chainMode: first set them to 1, then clear them using logic and
    cr |= 0x3 << 5;
    cr |= 0x1 << 16;
    // Set bit 5 and 6
    cr &= ((u32)chainMode & 0x3) << 5;
    // Set bit 16
    cr &= ((u32)chainMode & 0x4) << 16-2;
    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
}

void AES_GetKey(AES *InstancePtr, u8 *outKey[BLOCK_SIZE])
{
   for (int i = 0; i < 4; i++)
        *(u32*)(outKey+i*4) = AES_Read(InstancePtr, AES_KEYR0_OFFSET+i*4);
}
Mode AES_GetMode(AES *InstancePtr)
{
    return (Mode)((AES_Read(InstancePtr, AES_CR_OFFSET) >> 3) & 0x3);
}

ChainingMode AES_GetChainingMode(AES* InstancePtr, ChainingMode chainMode)
{
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
	// read bit 5 and 6
	u32 chMode = (cr & (0x3 << 5)) >> 5;
	// read bit 16
	chMode |= (cr & (1 << 16)) >> (16-2);
    return (ChainingMode)chMode;
}

void AES_PerformKeyExpansion(AES *InstancePtr)
{

}


void AES_processBlock(AES* InstancePtr, u8 dataBlock[BLOCK_SIZE], u8 outDataBlock[BLOCK_SIZE])
{

}
