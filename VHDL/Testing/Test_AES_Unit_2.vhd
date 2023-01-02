library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.common.ALL;
use work.addresses.ALL;
use work.register_bit_positions.ALL;


entity Test_AES_Unit_2 is 
generic (
    LITTLE_ENDIAN: boolean := true;
    NUM_CHANNELS : integer := 8
    );
end Test_AES_Unit_2;


architecture TB of Test_AES_Unit_2 is

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

component AES_Unit_2_Sim is
port (
  Address_0 : in STD_LOGIC_VECTOR (31 downto 0);
  Address_1 : in STD_LOGIC_VECTOR (31 downto 0);
  Clock : in STD_LOGIC;
  DataIn_0 : in STD_LOGIC_VECTOR (31 downto 0);
  DataIn_1 : in STD_LOGIC_VECTOR (31 downto 0);
  DataOut_0 : out STD_LOGIC_VECTOR (31 downto 0);
  DataOut_1 : out STD_LOGIC_VECTOR (31 downto 0);
  ReadEn_0 : in STD_LOGIC;
  ReadEn_1 : in STD_LOGIC;
  Resetn : in STD_LOGIC;
  WrByteEna_0 : in STD_LOGIC_VECTOR (3 downto 0);
  WrByteEna_1 : in STD_LOGIC_VECTOR (3 downto 0);
  WriteEn_0 : in STD_LOGIC;
  WriteEn_1 : in STD_LOGIC;
  aes_introut : out STD_LOGIC;
  busy_0 : out STD_LOGIC;
  busy_1 : out STD_LOGIC
);
end component AES_Unit_2_Sim;



signal Addr : STD_LOGIC_VECTOR (ADDR_WIDTH-1 downto 0);
signal Clock : STD_LOGIC := '0';
signal wrdata, wrdataLE : STD_LOGIC_VECTOR (31 downto 0);
signal rddata, rddataLE : STD_LOGIC_VECTOR (31 downto 0);
signal rden : STD_LOGIC := '0';
signal Resetn : STD_LOGIC := '0';
signal WrByteEna : STD_LOGIC_VECTOR (3 downto 0) := "1111";
signal Wren : STD_LOGIC := '0';
signal busy : STD_LOGIC;



signal Address_1 : STD_LOGIC_VECTOR (31 downto 0);
signal DataIn_1 : STD_LOGIC_VECTOR (31 downto 0);
signal DataOut_1 : STD_LOGIC_VECTOR (31 downto 0);
signal ReadEn_1 : STD_LOGIC := '0';
signal WrByteEna_1 : STD_LOGIC_VECTOR (3 downto 0) := "1111";
signal WriteEn_1 : STD_LOGIC := '0';
signal aes_introut : STD_LOGIC;
signal busy_1 : STD_LOGIC;

signal RdData_Mem : STD_LOGIC_VECTOR(31 downto 0);


subtype channel_range is integer range NUM_CHANNELS-1 downto 0;

type channel_off_type is array(channel_range) of integer;
signal CHANNEL_OFFSET : channel_off_type;

type channel_cr_type is array(channel_range) of std_logic_vector(31 downto 0);
signal CHANNEL_CR : channel_cr_type;

signal addrextended : std_logic_vector(31 downto 0);

constant key : std_logic_vector(KEY_SIZE-1 downto 0) := x"000102030405060708090a0b0c0d0e0f";
constant plaintext1 : std_logic_vector(KEY_SIZE-1 downto 0) := x"00102030011121310212223203132333";
constant plaintext2 : std_logic_vector(KEY_SIZE-1 downto 0) := x"000102030405060708090a0b0c0d0e0f";
constant plaintext3 : std_logic_vector(KEY_SIZE-1 downto 0) := x"affedeadbeefdadcabbeadbeec0cabad";

constant testIV : std_logic_vector(KEY_SIZE-1 downto 0) := x"f0e0d0c0b0a090807060504030201000";

type vector_array is array(natural range<>) of std_logic_vector(127 downto 0);
type channel_vector_array is array(0 to 3) of vector_array(0 to 3);

constant rCipher : channel_vector_array := (
    0 => (
    x"37c2539128699009617d4d8935e66c12",
        x"37c2539128699009617d4d8935e66c12",
            x"37c2539128699009617d4d8935e66c12",
                x"37c2539128699009617d4d8935e66c12"
    ),
    1 => (
    x"703120e5f337c2f4dc8a9ae76ec15c51",
    x"c4a0a2b01b2d447221d4439d06254107",
        x"c4a0a2b01b2d447221d4439d06254107",
            x"c4a0a2b01b2d447221d4439d06254107"
    ),
    2 => (
    x"ff18b572fed93cae3a10c25a622378d4",
    x"271d9d8060e0cc065ee270e17843f36d",
    x"eb291cdab7863ac90c4ff0519f886f80",
        x"eb291cdab7863ac90c4ff0519f886f80"
    ),
    3 => (x"8e560554d74121bd0ff9aed2ad3cf476",
    x"bbb73ab3ed2f4a06afa7c2d049a82089",
    x"51f81928df15015412a2654e59d710c1",
    x"8e560554d74121bd0ff9aed2ad3cf476"
    )
);



constant plainAddr : integer := 16#560#;
constant cipherAddr : integer := 16#1000#;


begin

addrextended <= x"00000" & "00" & Addr;
wrdataLE <= SwapEndian(wrdata);
rddata <= SwapEndian(rddataLE);

RdData_Mem <= SwapEndian(DataOut_1);

DUT: component AES_Unit_2_Sim port map (
  Address_0 => addrextended,
  Clock => Clock,
  DataIn_0 => wrdataLE,
  DataOut_0 => rddataLE,
  ReadEn_0 => rden,
  Resetn => Resetn,
  WrByteEna_0 => WrByteEna,
  WriteEn_0 => wren,
  busy_0 => busy,
  Address_1 => Address_1,
  DataIn_1 => DataIn_1,
  DataOut_1 => DataOut_1,
  ReadEn_1 => ReadEn_1,
  WrByteEna_1 => WrByteEna_1,
  WriteEn_1 => WriteEn_1,
  busy_1 => busy_1
);


Clock <= not Clock after 5ns;
Resetn <= '1' after 50ns;


channel_gen:
for i in channel_range generate
signal chmode : std_logic_vector(1 downto 0);
signal priority : unsigned(NUM_PRIORITY_BITS-1 downto 0);
signal gcmphase : std_logic_vector(1 downto 0);
begin
    CHANNEL_OFFSET(i) <= i * 128;
    chmode <= CHAINING_MODE_ECB when i mod 3 = 0 else
              CHAINING_MODE_CBC when i mod 3 = 1 else
              CHAINING_MODE_CTR; -- when i mod 3 = 2 else
    priority <= to_unsigned(1, priority'LENGTH) when i = 2 else
                to_unsigned(2, priority'LENGTH) when i = 3 else
                to_unsigned(0, priority'LENGTH);
    CHANNEL_CR(i)(31 downto CR_RANGE_PRIORITY'HIGH+1) <= (others => '0');
    CHANNEL_CR(i)(CR_RANGE_PRIORITY) <= std_logic_vector(priority);        
    CHANNEL_CR(i)(15 downto 0) <= '0' & GCM_PHASE_INIT & "000" & "0" & "00" & chmode & MODE_ENCRYPTION & "00" & '1';
end generate;


process 

procedure readWord(ch: channel_range; regaddr : integer) is
begin
addr <= std_logic_vector(to_unsigned(regaddr, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
rden <= '1';
wait until rising_edge(Clock);
rden <= '0';
wait until rising_edge(Clock) and busy = '0';
end procedure;

procedure readWordMem(addr : integer) is
begin
Address_1 <= std_logic_vector(to_unsigned(addr, Address_1'LENGTH));
ReadEn_1 <= '1';
wait until rising_edge(Clock);
ReadEn_1 <= '0';
wait until rising_edge(Clock) and busy_1 = '0';
end procedure;

procedure writeWord(ch: channel_range; regaddr : integer; data : std_logic_vector(31 downto 0)) is
begin
    -- validate all writes until here
    wait for 0ns;
    wren <= '1';
    addr <= std_logic_vector(to_unsigned(regaddr, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
    wrdata <= data;
    wait for 10ns;
    wren <= '0';
    wait until rising_edge(Clock) and busy = '0';
    report "Wrote " & to_hstring(to_bitvector(data)) & " to 0x" & to_hstring(to_bitvector(addr));
end procedure;


procedure assertMem(ch: channel_range; startaddr : integer; size : integer) is
variable assertVal: std_logic_vector(31 downto 0);
begin
for i in 0 to size/16-1 loop
    report "[Checking] Mem Addr " & to_hstring(to_bitvector(std_logic_vector(to_unsigned(startaddr+i*16, 32)))) & 
        " for value " & to_hstring(to_bitvector(rCipher(ch)(i)));
    for j in 0 to 3 loop
        assertVal := rCipher(ch)(i)(127-j*32 downto 96-j*32);
        readWordMem(startaddr + i*16 + j*4);
        report "[Checking] Mem Addr " & to_hstring(to_bitvector(std_logic_vector(to_unsigned(startaddr + i*16 + j*4, 32)))) & 
            " for value " & to_hstring(to_bitvector(assertVal));
         assert RdData_Mem = assertVal
            report "[Check Error] Value is wrong! Value is " & to_hstring(to_bitvector(RdData_Mem))
            severity failure;
    end loop;
end loop;
end procedure;


procedure assertBlock(ch: channel_range; regaddr: integer; assertVal : std_logic_vector(127 downto 0)) is 
begin
for i in 0 to 3 loop
    readWord(ch, regaddr+i*4);
    report "[Checking] Channel " & integer'image(ch) & " 0x" &
         to_hstring(to_bitvector(std_logic_vector(to_unsigned(regaddr+i*4, 8)))) &
         " = " & to_hstring(to_bitvector(assertVal(127-i*32 downto 96-i*32)));
    assert wrdata = assertVal(127-i*32 downto 96-i*32)
        report "[CHeck Error] Value is wrong!"
        severity failure;
end loop;
end procedure;

procedure activateChannel(ch: channel_range) is
begin
    wrdata <= CHANNEL_CR(ch);
    wait for 0ns;
    WriteWord(ch, ADDR_CR, wrdata);
end procedure;

procedure setDataParameters(ch : channel_range; source : integer; dest : integer; size : integer) is
begin
    WriteWord(ch, ADDR_DINADDR, SwapEndian(std_logic_vector(to_unsigned(source, 32))));
    -- set source addr
    report "Set as sourceaddr for channel " & integer'image(ch) & ": " & to_hstring(to_bitvector(wrdata));
    WriteWord(ch, ADDR_DOUTADDR, SwapEndian(std_logic_vector(to_unsigned(dest, 32))));
    WriteWord(ch, ADDR_DATASIZE, SwapEndian(std_logic_vector(to_unsigned(size, 32))));
end procedure;


procedure configureChannel(ch: channel_range) is
    variable longval : std_logic_vector(KEY_SIZE-1 downto 0);
begin
    setDataParameters(ch, plainAddr + ((ch+1)*ch/2)*BLOCK_SIZE, 
        cipherAddr + ((ch+1)*ch/2)*BLOCK_SIZE, (ch+1)*BLOCK_SIZE);
    -- set key
    longval := key;
    longval(127 downto 120) := std_logic_vector(to_unsigned(ch, 8));
    for i in 0 to 3 loop
        WriteWord(ch, ADDR_KEYR0+i*4, longval(127-i*32 downto 96-i*32));
    end loop;
    
    -- set IV
    longval := testIV;
    longval(127 downto 120) := std_logic_vector(to_unsigned(ch, 8));
    -- set last word to 0 if in CTR Mode
    if CHANNEL_CR(ch)(CR_RANGE_CHMODE) = CHAINING_MODE_CTR then
        longval(31 downto 0) := (others => '0');
    end if;
    for i in 0 to 3 loop
        WriteWord(ch, ADDR_IVR0+i*4, longval(127-i*32 downto 96-i*32));
    end loop;
end procedure;


procedure waitUntilCCF(ch: channel_range) is
begin
while true loop
    readWord(ch, ADDR_SR);
    if  rddata(SR_POS_CCF+ch) = '1' then
        exit;
    end if;
end loop;
end procedure;

procedure clearCCF(ch: channel_range) is
begin
wrdata <= CHANNEL_CR(ch);
wrdata(7) <= '1'; -- set CCFC flag
wrdata(0) <= '0'; -- deassert EN
wait for 0ns;
WriteWord(ch, ADDR_CR, wrdata);
-- deassert CCFC flag again
wrdata(7) <= '0';
wait for 0ns;
WriteWord(ch, ADDR_CR, wrdata);
end procedure;


begin
-- wait until reset is deasserted
wait until Resetn = '1' and rising_edge(Clock);

--  Write Channel Configuration data to mem
for i in 0 to 3 loop
    ConfigureChannel(i);
end loop;

report "[INFO] Configured all channels.";

-- Activate channel 0 Init phase
activateChannel(0);
wait for 10ns;

activateChannel(1);


-- Wait, then setup channel 2
wait for 100ns;
activateChannel(2);

wait for 1000ns;
activateChannel(3);

-- wait until channels are finished, then assert the data
for ch in 0 to 3 loop
    waitUntilCCF(ch);
    assertMem(ch, cipherAddr + (ch*(ch+1)/2)*BLOCK_SIZE, (ch+1)*BLOCK_SIZE);
end loop;

report "[Checked] Completed all checks.";

wait;
end process;



end TB;

