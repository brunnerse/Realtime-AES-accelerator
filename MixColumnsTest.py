import numpy as np 

a = np.array([0x00, 0x10, 0x20, 0x30])

def mixcol(a):
    b = np.zeros(4)
    for i in range(4):
        b[i] = mul2(a[i]) ^ mul3(a[(i+1)%4]) ^ a[(i+2)%4] ^ a[(i+3)%4]
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