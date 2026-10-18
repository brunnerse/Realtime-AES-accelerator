#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "aes.h"
#include "test_data.h"

void phex(uint8_t* str);
static int test_encrypt_ecb(void);

int main() 
{
    test_encrypt_ecb();

}


static int test_encrypt_ecb(void)
{
    uint8_t *key = key1; 

    uint8_t *in = plaintext1; 
    
    printf("Plaintext data:\n\t");
    phex(in);


    struct AES_ctx ctx;

    AES_init_ctx(&ctx, key);

    printf("\nRound keys:\n");

    for (int i = 0; i < AES_keyExpSize; i += AES_BLOCKLEN) {
        printf("%2i:\t", i/16);
        phex(&ctx.RoundKey[i]);
    }

    printf("\n\n");

    AES_ECB_encrypt(&ctx, in);

    printf("\n\nECB encrypt:\n\t");
    phex(in);
    printf("\n\n");

    AES_ECB_decrypt(&ctx, in);

    printf("\n\nECB decrypt: ");
    phex(in);
    printf("\n\n");
}


// prints string as hex
void phex(uint8_t* str)
{
    for (unsigned i = 0; i < AES_BLOCKLEN; ++i)
        printf("%.2x ", str[i]);
    printf("\n");
}

