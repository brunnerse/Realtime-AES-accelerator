#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "aes.h"
#include "aes_constants.h"
#include "test_data.h"


void KeyExpansion(uint8_t *RoundKey, const uint8_t* Key);
void KeyExpansion_rev(uint8_t *RoundKey, const uint8_t* lastKey);


// prints string as hex
void __attribute__((weak)) phex_key(uint8_t* str) {
    unsigned char i;
    for (i = 0; i < Nk * 4; ++i)
        printf("%.2x ", str[i]);
    printf("\n");
}


int main(void)
{
    printf("\nTesting KeyExpansion for AES128\n\n");

    // 128-bit 16-byte key
    uint8_t *key = key1; 


    struct AES_ctx ctx;

    AES_init_ctx(&ctx, key);

    printf("Key:\n");
    phex_key(key);
    printf("\n");

    printf("\nRound keys according to tiny-AES:\n");
    for (int round = 0; round < AES_keyExpSize / 16; round += 1)
    {
        printf("%2i:\t", round);
        phex(ctx.RoundKey + round * 16);
    }


    uint8_t RoundKey[AES_keyExpSize];
    // AES_KeyExpSize: 16 * 11 = 176


    KeyExpansion(RoundKey, key);

    printf("\n\nRound keys (custom):\n");
    for (int round = 0; round < AES_keyExpSize / 16; round += 1)
    {
        printf("%2i:\t", round);
        phex(RoundKey + round * 16);
    }

    uint8_t last_words[Nk * 4];
    memcpy(last_words, RoundKey +  4*Nb*(Nr+1) - Nk*4, Nk * 4);
    memset(RoundKey, 0, AES_keyExpSize);


    KeyExpansion_rev(RoundKey, last_words);

    printf("\nReversed Round keys:\n");
    for (int round = 0; round < AES_keyExpSize / 16; round += 1)
    {
        printf("%2i:\t", round);
        phex(RoundKey + round * 16);
    }



    return 0;
}




// AES state:  Always 4 rows, Nb columns
extern const uint8_t sbox[256];
extern const uint8_t Rcon[11];


uint32_t RotByte(uint32_t word) {
    // Keep little endian in mind
    //uint8_t leftmost = (uint8_t)(word >> 24); 
    uint8_t leftmost = (uint8_t)(word & 0xff); 
    return (word >> 8) | (leftmost << 24);

    // Produces same result as:
/*
    uint8_t *tempa = (uint8_t*)&word;
    // Keep little endian in mind
    const uint8_t u8tmp = tempa[0];
    tempa[0] = tempa[1];
    tempa[1] = tempa[2];
    tempa[2] = tempa[3];
    tempa[3] = u8tmp;

    return *(uint32_t*)tempa;
*/
}


uint32_t SubByte(uint32_t word) {

    extern const uint8_t sbox[256];

    uint8_t *temp = (uint8_t*)&word;
    for (unsigned i = 0; i < 4; i++)
        temp[i] = sbox[ (temp[i]) ]; 
    return word;
}


#define KEYEXPANSION_WORDWISE 1 


void KeyExpansion(uint8_t *RoundKey, const uint8_t* Key)
{
    uint32_t *W = (uint32_t*)RoundKey;

    // First round key equals user key
    for (unsigned i = 0; i < Nk; i++)
        W[i] = ((uint32_t*)Key)[i]; 

#if KEYEXPANSION_WORDWISE 
    // Build subsequent Nr round keys word by word
    for (unsigned i = Nk; i < Nb * (Nr + 1); i++)
    {
        uint32_t temp = W[i-1];
        if (i % Nk == 0)
            temp = SubByte(RotByte(temp)) ^  Rcon[i / Nk];
        else if (Nk > 6 && i % Nk == 4)
            temp = SubByte(temp);
        
        W[i] = W[i - Nk] ^ temp;
    }
#else
    // Build subsequent Nr round keys key by key 
    for (unsigned r = 1; r < (Nr + 1); r++)
    {
        uint32_t* prevkeyW = &W[(r-1) * Nb];
        uint32_t* keyW = &W[r * Nb]; 

        keyW[0] = prevkeyW[0] ^ SubByte(RotByte(prevkeyW[3])) ^ Rcon[r]; 
        keyW[1] = prevkeyW[1] ^ keyW[0]; 
        keyW[2] = prevkeyW[2] ^ keyW[1];
        keyW[3] = prevkeyW[3] ^ keyW[2];
    }

#endif
}


// This function produces Nb(Nr+1) round keys. The round keys are used in each round to decrypt the states.
void KeyExpansion_rev(uint8_t *RoundKey, const uint8_t* last_words)
{
    uint32_t *W = (uint32_t*)RoundKey;

    // Enter last roudn key 
    memcpy(&W[(Nr+1)*Nb - Nk], last_words, 4*Nk);

#if KEYEXPANSION_WORDWISE 
    // Build previous Nr round keys word by word
    for (int i = (Nr+1)*Nb - Nk - 1; i >= 0; i--)
    {
        uint32_t temp = W[i + Nk - 1];
        if (i % Nk == 0)
            temp = SubByte(RotByte(temp)) ^ Rcon[(i + Nk) / Nk]; 
        else if (Nk > 6 && i % Nk == 4)
            temp = SubByte(temp);
        W[i] = W[i + Nk] ^ temp;
    }
#else
    // Build prev round keys key by key 
    for (int r = Nr; r >= 0; r--)
    {
        uint32_t* keyW = &W[r * Nb]; 
        uint32_t* prevkeyW = &W[(r-1) * Nb];

        prevkeyW[3] = keyW[3] ^ keyW[2]; 
        prevkeyW[2] = keyW[2] ^ keyW[1];
        prevkeyW[1] = keyW[1] ^ keyW[0];
        prevkeyW[0] = keyW[0] ^ SubByte(RotByte(prevkeyW[3])) ^ Rcon[r];
    }
#endif
}