library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

use work.common.ALL;
use work.addresses.ALL;
use work.register_bit_positions.ALL;

use IEEE.NUMERIC_STD.ALL;

entity Test_AES_Unit_2_Sim_Bd_Scheduler is 
generic (
    NUM_CHANNELS : integer := 8;
    LITTLE_ENDIAN : boolean := true
    );
end Test_AES_Unit_2_Sim_Bd_Scheduler;


architecture TB of Test_AES_Unit_2_Sim_Bd_Scheduler is

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
  S_ReadWritePort_0_rdaddr : in STD_LOGIC_VECTOR (10 downto 0);
  S_ReadWritePort_0_rddata : out STD_LOGIC_VECTOR (31 downto 0);
  S_ReadWritePort_0_rden : in STD_LOGIC;
  S_ReadWritePort_0_wraddr : in STD_LOGIC_VECTOR (10 downto 0);
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

constant testIV : std_logic_vector(KEY_SIZE-1 downto 0) := x"00e0d0c0b0a090807060504030201000";

constant plainAddr : integer := 16#560#;
constant cipherAddr : integer := 16#2000#;


type vector_array is array(natural range<>) of std_logic_vector(127 downto 0);

signal Clock : STD_LOGIC := '0';
signal EnOCore : STD_LOGIC := '0';
signal Resetn : STD_LOGIC := '0';
signal rdaddr : STD_LOGIC_VECTOR (10 downto 0);
signal rddata : STD_LOGIC_VECTOR (31 downto 0);
signal rden : STD_LOGIC;
signal wraddr : STD_LOGIC_VECTOR (10 downto 0);
signal wrdata : STD_LOGIC_VECTOR (31 downto 0);
signal wren : STD_LOGIC;
signal wrstrb : STD_LOGIC_VECTOR (3 downto 0) := "1111";
signal aes_introut_0 : STD_LOGIC;
signal dOutCore : STD_LOGIC_VECTOR (127 downto 0);



subtype channel_range is integer range NUM_CHANNELS-1 downto 0;

type channel_off_type is array(channel_range) of integer;
signal CHANNEL_OFFSET : channel_off_type;

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
begin
    CHANNEL_OFFSET(i) <= i * 128;
    chmode <= CHAINING_MODE_ECB;
    priority <= to_unsigned(NUM_CHANNELS-1-i, priority'LENGTH);
    CHANNEL_CR(i)(31 downto CR_RANGE_PRIORITY'HIGH+1) <= (others => '0');
    CHANNEL_CR(i)(CR_RANGE_PRIORITY) <= std_logic_vector(priority);        
    CHANNEL_CR(i)(15 downto 0) <= '0' & GCM_PHASE_INIT & "000" & "0" & "00" & chmode & MODE_KEYEXPANSION & "00" & '1';

end generate;

Clock <= not Clock after 5ns;
Resetn <= '1' after 50ns;




process 
procedure activateChannel(ch: channel_range) is
begin
wraddr <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
wrdata <= CHANNEL_CR(ch);
wren <= '1';
wait for 10ns;
wren <= '0';
end procedure;

procedure writeCR(ch: channel_range) is
begin
wraddr <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
wrdata <= CHANNEL_CR(ch);
wrdata(CR_POS_EN) <= '0';
wren <= '1';
wait for 10ns;
wren <= '0';
end procedure;

procedure waitUntilCCF(ch: channel_range) is
begin
rden <= '1';
rdaddr <= std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
wait until rddata(SR_POS_CCF+ch) = '1'; 
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
for i in 0 to NUM_CHANNELS-1 loop
    writeCR(i);
end loop;
wait for 50ns;
activateChannel(0);
activateChannel(1);
activateChannel(3);
-- activate last channel shortly before first one is ready
wait for 150ns;
activateChannel(2);


wait for 90ns;
activateChannel(4);
-- repeat activation several times, so that the search is aborted and restarted a few times
for i in 0 to 4 loop
  wait for 10ns;
  activateChannel(4);
end loop;
-- channel 1 activates after channel 3 finished, so the search isnt restarted again
wait for 80ns;
activateChannel(0);
-- channel 2 starts; new search that channel 1 wins

wait;
end process;


end TB;

