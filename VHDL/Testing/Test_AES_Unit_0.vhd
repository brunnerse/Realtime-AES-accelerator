library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.common.ALL;
use work.addresses.ALL;


entity Test_AES_Unit_0  is 
generic (
    LITTLE_ENDIAN : boolean := true
    );

end Test_AES_Unit_0 ;


architecture TB of Test_AES_Unit_0 is

function SwapEndian(x : std_logic_vector) return std_logic_vector is
variable r : std_logic_vector(x'RANGE);
variable idx : integer;
begin
if not LITTLE_ENDIAN then
    return x;
end if;
for i in x'LENGTH/8-1 downto 0 loop
    idx := (x'LENGTH/8-1-i)*8;
    r(idx+7 downto idx) := x(i*8+7 downto i*8);
end loop;
return r;
end function;


component AES_Unit_Sim is
port (
  Address_0 : in STD_LOGIC_VECTOR (31 downto 0);
  Clock : in STD_LOGIC;
  DataIn_0 : in STD_LOGIC_VECTOR (31 downto 0);
  DataOut_0 : out STD_LOGIC_VECTOR (31 downto 0);
  ReadEn_0 : in STD_LOGIC;
  Resetn : in STD_LOGIC;
  WrByteEna_0 : in STD_LOGIC_VECTOR (3 downto 0);
  WriteEn_0 : in STD_LOGIC;
  aes_introut_0 : out STD_LOGIC;
  busy_0 : out STD_LOGIC
);
end component AES_Unit_Sim;

signal Address : STD_LOGIC_VECTOR (31 downto 0);
signal Clock : STD_LOGIC := '1';
signal DataIn : STD_LOGIC_VECTOR (31 downto 0);
signal DataOutEndian, DataOut : STD_LOGIC_VECTOR (31 downto 0);
signal ReadEn : STD_LOGIC := '0';
signal Resetn : STD_LOGIC := '0';
signal WriteEn : STD_LOGIC :='0';
signal aes_introut : STD_LOGIC;
signal busy : STD_LOGIC;


constant rCipherECB : std_logic_vector(127 downto 0) := x"37c2539128699009617d4d8935e66c12";
constant rCipherCBC : std_logic_vector(127 downto 0) := x"577d1339076d631c8bdd62cacd25ad46";

constant plaintext : std_logic_vector(127 downto 0) := x"00102030011121310212223203132333";
constant key : std_logic_vector(127 downto 0) := x"000102030405060708090a0b0c0d0e0f";
constant iv : std_logic_vector(127 downto 0) := x"00e0d0c0b0a090807060504030201000";

begin

DUT: component AES_Unit_Sim port map (
  Address_0 => Address,
  Clock => Clock,
  DataIn_0 => SwapEndian(DataIn),
  DataOut_0 => DataOutEndian,
  ReadEn_0 => ReadEn,
  Resetn => Resetn,
  WrByteEna_0 => "1111",
  WriteEn_0 => WriteEn,
  aes_introut_0 => aes_introut,
  busy_0 => busy
);

DataOut <= SwapEndian(DataOutEndian);

Clock <= not Clock after 5ns;
Resetn <= '1' after 50ns;


process
procedure performWrite(addr : integer; data : std_logic_vector) is
begin
Address <= std_logic_vector(to_unsigned(addr, Address'LENGTH));
DataIn <= data;
WriteEn <= '1';
wait until rising_edge(Clock);
WriteEn <= '0';
wait until rising_edge(Clock) and busy = '0';
end procedure;

procedure performRead(addr : integer) is
begin
Address <= std_logic_vector(to_unsigned(addr, Address'LENGTH));
ReadEn <= '1';
wait until rising_edge(Clock);
ReadEn <= '0';
wait until rising_edge(Clock) and busy = '0';
end procedure;

variable chMode : std_logic_vector(1 downto 0);
variable rCipher : std_logic_vector(127 downto 0);

begin
wait until rising_edge(Clock) and Resetn = '1';
-- write key and iv
for i in 3 downto 0 loop
    performWrite(ADDR_KEYR0+(3-i)*4, key(i*32+31 downto i*32));
    performWrite(ADDR_IVR0+(3-i)*4, iv(i*32+31 downto i*32));
end loop;

-- do two tests: first ECB mode, then CBC mode
for j in 0 to 1 loop
    if j = 0 then
        chMode := CHAINING_MODE_ECB;
        rCipher := rCipherECB;
    else
        chMode := CHAINING_MODE_CBC;
        rCipher := rCipherCBC;
    end if;
    
    -- write control register
    performWrite(ADDR_CR,
        x"00000" & "00100" & chMode & MODE_ENCRYPTION & "00" & '1');
    -- write input data
    for i in 3 downto 0 loop
        performWrite(ADDR_DINR, plaintext(i*32+31 downto i*32));
    end loop;
    -- wait until CCF is set
    while true loop
        performRead(ADDR_SR);
        if DataOut(0) = '1' then
            exit;
        end if;
    end loop;
    
    -- read result, assert that it is correct
    for i in 3 downto 0 loop
        performRead(ADDR_DOUTR);
        report "[Checking] ciphertext = " & to_hstring(to_bitvector(rCipher(i*32+31 downto i*32)));
        assert DataOut = rCipher(i*32+31 downto i*32)
            report "RdData is wrong!"
            severity failure;
    end loop;
    
    -- in CBC mode, check new IV
    if chMode = CHAINING_MODE_CBC then
        for i in 3 downto 0 loop
            performRead(ADDR_IVR0 + (3-i)*4);
                report "[Checking] IV = " & to_hstring(to_bitvector(rCipher(i*32+31 downto i*32)));
            assert DataOut = rCipher(i*32+31 downto i*32)
                report "IV is wrong!"
                severity failure;
        end loop;
    end if;
    
end loop;

end process;
end TB;

