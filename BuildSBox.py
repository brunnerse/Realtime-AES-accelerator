def createConstArrayStr(arr):
    content = ""
    for i in range(len(arr)):
        # Convert sbox[i] to hex string with exactly two digits
        valStr = "%02s"%(str(hex(sbox[i]))[2:])
        valStr = valStr.replace(' ', '0')

        content += "\t%3i => x\"%s\""%(i, valStr)
        if i < len(arr)-1:
            content += ",\n"
    return content


# Perform rotate left for byte i
def rol(i, shifts, nBits = 8):
    result = ((i << shifts) | (i >> (nBits-shifts)))
    # set bits higher than nBits to 0
    return result & (0xffffffff >> (32 - nBits))


sbox = [0] * 256
sbox_inv = [0] * 256

sbox[0] = 0x63
sbox_inv[0x63] = 0

p = 1
q = 1  # q is always the inverse of p

while True:
    # multiply p by 3
    p = p ^ ( p << 1)
    if p >= 256:  # Polynom division
        p ^= 0x11B

    # divide q by 3  (by multiplying by 0xf6: 11111010)
    q ^= q << 1
    q ^= q << 2
    q ^= q << 4
    if q & 0x80 != 0:
        q ^= 0x09
    
    q &= 0xff

    xformed = q ^ rol(q,1) ^ rol(q, 2) ^ rol(q, 3) ^ rol(q, 4) ^ 0x63

    sbox[p] = xformed
    sbox_inv[xformed] = p

    if p == 1:
        break

# Create VHDL file
content = '''
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package sbox_definition is

type SBOX is array(255 downto 0) of std_logic_vector(7 downto 0);

constant sbox_encrypt : SBOX := (
''' 

content += createConstArrayStr(sbox)


content +=  '''
         );

constant sbox_decrypt : SBOX := (
'''

content += createConstArrayStr(sbox_inv)

content += '''
);


end package;
'''

file = open("sbox_definition.vhd", "w")
file.write(content)
file.close()

