import numpy as np 
from BuildSBox import *

a = np.array([0x01, 0x02, 0x03, 0x04])
data = [[0x00, 0x10, 0x20, 0x30], [0x01, 0x11, 0x21, 0x31], [0x02, 0x12, 0x22, 0x32], [0x03, 0x13, 0x23, 0x33]]

def mixcol(a):
    b = np.zeros(4, int)
    for i in range(4):
        b[i] = mul2(a[i]) ^ mul3(a[(i+1)%4]) ^ a[(i+2)%4] ^ a[(i+3)%4]
        print("b[%d] = %s"%(i, hex(int(b[i]))))
    return b

def mixcol_inv(a):
    b = np.zeros(4, int)
    for i in range(4):
        b[i] = mulGF(a[i], 0xe) ^ mulGF(a[(i+1)%4], 0xb) ^ mulGF(a[(i+2)%4], 0xd) ^ mulGF(a[(i+3)%4], 0x9)
        print("b[%d] = %s"%(i, hex(int(b[i]))))
    return b

def mul2(x):
        if x > 127:
            return 2*x ^ 0x11b
        return 2*x

def mul3(x):
        return mul2(x) ^ x

def mulGF(poly1, poly2):
    result = 0
    # multiple the polynomials
    for i in range(8):
        x = poly2 & (1 << i)
        if x != 0:
            result ^= poly1 << i
    # divide polynom by 0x11b (x^8 + x^4 + x^3 + x + 1)
    for i in range(15, 7, -1):
        #print("Result: ", hex(result))
        #print (hex(0x11b << (i-8)))
        if result & (1 << i) != 0:
            result ^= 0x11b << (i-8)
    
    #print(hex(result))
    return result


def keyExpansion(key):
    words = [None] * 44
    for i in range(4):
        words[i] = key >> ((3-i)*32) & 0xffffffff
    for i in range(4):
        print(hex(words[i]))
    Rcon = 1
    for i in range(4, 44):
        word_1 = words[i-1]
        word_4 = words[i-4]
        print(word_1, word_4)
        print(hex(word_1), hex(word_4))
        if i % 4 == 0:
            #print(format(word_1, "032b"))
            word_1 = rol(word_1, 8, 32)
            byte = [None] * 4
            for j in range(4):
                byte[j] = (word_1 >> ((3-j)*8)) & 0xff
                #print(format(byte[j], "08b"), format(sbox[byte[j]], "08b"))
                byte[j] = sbox[byte[j]]
                
            word_1 = (byte[0] << 24) | (byte[1] << 16) | (byte[2] << 8) | byte[3]
            #print(format(word_1, "032b"))
            word_1 ^= Rcon << 24
            Rcon = mulGF(Rcon, 2)
        print(hex(word_1), hex(word_4))
        words[i] = word_1 ^ word_4
        print(hex(words[i]))
    keys = [None] * 11
    print("\n Words:")
    for w in words:
        print(format(w, "08x"))
    for i in range(11):
        keys[i] = 0
        for j in range(4):
            keys[i] |= words[i*4+j] << (32 * (3-j)) 
        print(format(keys[i], "032x"))
    return keys





testKey = 0x000102030405060708090a0b0c0d0e0f

print(keyExpansion(testKey))

# test MixColumns
#result = mixcol(a)
#result_inv = mixcol_inv(result)

#print(a, result, result_inv, sep="\n\t")
