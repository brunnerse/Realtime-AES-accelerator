library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.common.ALL;
use work.addresses.ALL;
use work.register_bit_positions.ALL;



entity Test_AES_Unit_Sim_Bd_GCM is 
generic (
    NUM_CHANNELS : integer := 4;
    LITTLE_ENDIAN : boolean := true
    );
end Test_AES_Unit_Sim_Bd_GCM;


architecture TB of Test_AES_Unit_Sim_Bd_GCM is

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



component AES_Unit_Sim_Bd is
port (
  Clock : in STD_LOGIC;
  EnO : out STD_LOGIC;
  Resetn : in STD_LOGIC;
  S_ReadWritePort_0_rdaddr : in STD_LOGIC_VECTOR (9 downto 0);
  S_ReadWritePort_0_rddata : out STD_LOGIC_VECTOR (31 downto 0);
  S_ReadWritePort_0_rden : in STD_LOGIC;
  S_ReadWritePort_0_wraddr : in STD_LOGIC_VECTOR (9 downto 0);
  S_ReadWritePort_0_wrdata : in STD_LOGIC_VECTOR (31 downto 0);
  S_ReadWritePort_0_wren : in STD_LOGIC;
  S_ReadWritePort_0_wrstrb : in STD_LOGIC_VECTOR (3 downto 0);
  aes_introut_0 : out STD_LOGIC;
  dOut : out STD_LOGIC_VECTOR (127 downto 0)
);
end component AES_Unit_Sim_Bd;


constant key : std_logic_vector(KEY_SIZE-1 downto 0) := x"000102030405060708090a0b0c0d0e0f";
constant plaintext1 : std_logic_vector(KEY_SIZE-1 downto 0) := x"00102030011121310212223203132333";
constant plaintext2 : std_logic_vector(KEY_SIZE-1 downto 0) := x"000102030405060708090a0b0c0d0e0f";
constant plaintext3 : std_logic_vector(KEY_SIZE-1 downto 0) := x"affedeadbeefdadcabbeadbeec0cabad";

constant testIV : std_logic_vector(KEY_SIZE-1 downto 0) := x"f0e0d0c0b0a090807060504030201000";

constant plainAddr : integer := 16#540#;
constant cipherAddr : integer := 16#2000#;


signal Clock : STD_LOGIC := '0';
signal EnOCore : STD_LOGIC := '0';
signal Resetn : STD_LOGIC := '0';
signal rdaddr : STD_LOGIC_VECTOR (9 downto 0);
signal rddata : STD_LOGIC_VECTOR (31 downto 0);
signal rden : STD_LOGIC;
signal wraddr : STD_LOGIC_VECTOR (9 downto 0);
signal wrdata : STD_LOGIC_VECTOR (31 downto 0);
signal wren : STD_LOGIC;
signal wrstrb : STD_LOGIC_VECTOR (3 downto 0) := "1111";
signal aes_introut_0 : STD_LOGIC;
signal dOutCore : STD_LOGIC_VECTOR (127 downto 0);


subtype channel_range is integer range NUM_CHANNELS-1 downto 0;

type channel_off_type is array(channel_range) of integer;
signal CHANNEL_OFFSET : channel_off_type;

signal CHANNEL_HDRADDR, CHANNEL_PAYLDADDR, CHANNEL_CIPHERADDR, CHANNEL_FINALADDR, CHANNEL_TAGADDR : channel_off_type;

type channel_cr_type is array(channel_range) of std_logic_vector(31 downto 0);
signal CHANNEL_CR : channel_cr_type;


begin

DUT: component AES_Unit_Sim_Bd port map (
  Clock => Clock,
  EnO => EnOCore,
  Resetn => Resetn,
  S_ReadWritePort_0_rdaddr => rdaddr,
  S_ReadWritePort_0_rddata => rddata,
  S_ReadWritePort_0_rden => rden,
  S_ReadWritePort_0_wraddr => wraddr,
  S_ReadWritePort_0_wrdata => wrdata,
  S_ReadWritePort_0_wren => wren,
  S_ReadWritePort_0_wrstrb => wrstrb,
  aes_introut_0 => aes_introut_0,
  dOut => dOutCore
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
    chmode <= CHAINING_MODE_GCM;
    priority <= to_unsigned(1, priority'LENGTH) when i = 1 else
                to_unsigned(0, priority'LENGTH);
    CHANNEL_CR(i)(31 downto CR_RANGE_PRIORITY'HIGH+1) <= (others => '0');
    CHANNEL_CR(i)(CR_RANGE_PRIORITY) <= std_logic_vector(priority);        
    CHANNEL_CR(i)(15 downto 0) <= '0' & GCM_PHASE_INIT & "000" & "0" & "00" & chmode & MODE_ENCRYPTION & "00" & '1';

    CHANNEL_HDRADDR(i) <= plainAddr + BLOCK_SIZE * 6 * i;
    CHANNEL_PAYLDADDR(i) <= plainAddr + BLOCK_SIZE * 6 * i + BLOCK_SIZE * 2; 
    CHANNEL_CIPHERADDR(i) <= cipherAddr + BLOCK_SIZE * 6 * i;
    CHANNEL_FINALADDR(i) <= plainAddr + BLOCK_SIZE * 6 * i + BLOCK_SIZE * 5;
    CHANNEL_TAGADDR(i) <= cipherAddr + BLOCK_SIZE * 6 * i + BLOCK_SIZE * 5;
end generate;



process (Clock)
begin
if rising_edge(Clock) and EnOCore = '1' then
    report "[INFO] Core finished: Result is " & to_hstring(to_bitvector(dOutCore));
end if;
end process;



process 
procedure activateChannel(ch: channel_range; phase : std_logic_vector(1 downto 0)) is
begin
    wraddr <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
    wrdata <= CHANNEL_CR(ch);
    wrdata(CR_RANGE_GCMPHASE) <= phase;
    wren <= '1';
    wait for 10ns;
    wren <= '0';
end procedure;

procedure setDataParameters(ch : channel_range; source : integer; dest : integer; size : integer) is
begin
    wren <= '1';
    wraddr <= std_logic_vector(to_unsigned(ADDR_DINADDR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
    wrdata <= SwapEndian(std_logic_vector(to_unsigned(source, 32)));
    wait for 10ns;
    wraddr <= std_logic_vector(to_unsigned(ADDR_DOUTADDR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
    wrdata <= SwapEndian(std_logic_vector(to_unsigned(dest, 32)));
    wait for 10ns;
    wraddr <= std_logic_vector(to_unsigned(ADDR_DATASIZE, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
    wrdata <= SwapEndian(std_logic_vector(to_unsigned(size, 32)));
    wait for 10ns;
    wren <= '0';
end procedure;


procedure writeWord(ch: channel_range; regaddr : integer; data : std_logic_vector(31 downto 0)) is
begin
    wren <= '1';
    wraddr <= std_logic_vector(to_unsigned(regaddr, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
    wrdata <= data;
    wait for 10ns;
    wren <= '0';
end procedure;

procedure configureChannel(ch: channel_range) is
    variable longval : std_logic_vector(KEY_SIZE-1 downto 0);
begin
    wren <= '1';
    -- set source addr
    wraddr <= std_logic_vector(to_unsigned(ADDR_DINADDR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
    wrdata <= SwapEndian(std_logic_vector(to_unsigned(plainAddr + ((ch+1)*ch/2)*BLOCK_SIZE, 32)));
    wait for 10ns;
    report "Set as sourceaddr for channel " & integer'image(ch) & ": " & to_hstring(to_bitvector(wrdata));
    -- set dest addr
    wraddr <= std_logic_vector(to_unsigned(ADDR_DOUTADDR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
    wrdata <= SwapEndian(std_logic_vector(to_unsigned(cipherAddr + (ch/2*(ch+1))*BLOCK_SIZE, 32)));
    wait for 10ns;
    -- set size
    wraddr <= std_logic_vector(to_unsigned(ADDR_DATASIZE, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
    wrdata <= SwapEndian(std_logic_vector(to_unsigned((ch+1)*BLOCK_SIZE, 32)));
    wait for 10ns;
    -- set key
    longval := key;
    longval(127 downto 120) := std_logic_vector(to_unsigned(ch, 8));
    for i in 0 to 3 loop
        wren <= '1';
        wraddr <= std_logic_vector(to_unsigned(ADDR_KEYR0, ADDR_WIDTH) + i*4 + CHANNEL_OFFSET(ch));
        wrdata <= longval(127-i*32 downto 96-i*32);
        wait for 10ns;
    end loop;
    -- set IV
    longval := testIV;
    longval(127 downto 120) := std_logic_vector(to_unsigned(ch, 8));
    -- set last word to 0 if in CTR Mode
    if CHANNEL_CR(ch)(CR_RANGE_CHMODE) = CHAINING_MODE_CTR then
        longval(31 downto 0) := (others => '0');
    end if;
    for i in 0 to 3 loop
        wren <= '1';
        wraddr <= std_logic_vector(to_unsigned(ADDR_IVR0, ADDR_WIDTH) + i*4 + CHANNEL_OFFSET(ch));
        wrdata <= longval(127-i*32 downto 96-i*32);
        wait for 10ns;
    end loop;
    wren <= '0';
end procedure;


procedure waitUntilCCF(ch: channel_range) is
begin
rden <= '1';
rdaddr <= std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
report "Checking Pos " & integer'image(SR_POS_CCF +ch);
while  rddata(SR_POS_CCF+ch) /= '1' loop
    report "RdData: " & to_hstring(to_bitvector(rddata))&  "\t" & std_logic'image(rddata(SR_POS_CCF+ch));
    wait for 10ns;
end loop;
--wait until rddata(SR_POS_CCF+ch) = '1'; 
end procedure;

procedure clearCCF(ch: channel_range) is
begin
wren <= '1';
wraddr <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
wrdata <= CHANNEL_CR(ch);
wrdata(7) <= '1'; -- set CCFC flag
wrdata(0) <= '0'; -- deassert EN
wait for 10ns;
-- deassert CCFC flag again
wrdata(7) <= '0';
wait for 10ns;
wren <= '0';
end procedure;


begin
-- wait until reset is deasserted
wait until Resetn = '1' and rising_edge(Clock);

--  Write Channel Configuration data to mem
for i in channel_range loop
    ConfigureChannel(i);
end loop;

report "[INFO] Configured all channels.";

--setDataParameters(0, 0, 0, BLOCK_SIZE);
activateChannel(0, GCM_PHASE_INIT);
waitUntilCCF(0);

setDataParameters(0, CHANNEL_HDRADDR(0), 0, BLOCK_SIZE*2);
activateChannel(0, GCM_PHASE_HEADER);

-- meanwhile, activate Channel 1
wait for 10ns;
activateChannel(1, GCM_PHASE_INIT);
waitUntilCCF(1);

setDataParameters(1, CHANNEL_HDRADDR(1), 0, BLOCK_SIZE*2);
activateChannel(1, GCM_PHASE_HEADER);


-- activate Channel 0 payload phase
waitUntilCCF(0);
setDataParameters(0, CHANNEL_PAYLDADDR(0), CHANNEL_CIPHERADDR(0), BLOCK_SIZE*3);
-- init IV
writeWord(0, ADDR_IVR3, x"00000002");
activateChannel(0, GCM_PHASE_PAYLOAD);


-- activate Channel 1 payload phase
wait for 700ns;
waitUntilCCF(1);
setDataParameters(1, CHANNEL_PAYLDADDR(1), CHANNEL_CIPHERADDR(1), BLOCK_SIZE*3);
-- init IV
writeWord(1, ADDR_IVR3, x"00000002");
activateChannel(1, GCM_PHASE_PAYLOAD);


-- calculate tag of channel 0
waitUntilCCF(0);
setDataParameters(0, CHANNEL_FINALADDR(0), CHANNEL_TAGADDR(0), BLOCK_SIZE);
-- init IV
writeWord(0, ADDR_IVR3, x"00000001");
activateChannel(0, GCM_PHASE_FINAL);


-- calculate tag of channel 1
waitUntilCCF(1);
setDataParameters(1, CHANNEL_FINALADDR(1), CHANNEL_TAGADDR(1), BLOCK_SIZE);
-- init IV
writeWord(1, ADDR_IVR3, x"00000001");
activateChannel(1, GCM_PHASE_FINAL);
waitUntilCCF(1);


wait;
end process;


end TB;

