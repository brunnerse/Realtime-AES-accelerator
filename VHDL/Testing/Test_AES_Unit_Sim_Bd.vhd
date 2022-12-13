library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.common.ALL;
use work.addresses.ALL;
use work.register_bit_positions.ALL;



entity Test_AES_Unit_Sim_Bd is 
generic (
    NUM_CHANNELS : integer := 8;
    LITTLE_ENDIAN : boolean := true
    );
end Test_AES_Unit_Sim_Bd;


architecture TB of Test_AES_Unit_Sim_Bd is

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

signal Clock : STD_LOGIC := '0';
signal EnO : STD_LOGIC := '0';
signal Resetn : STD_LOGIC := '1';
signal rdaddr : STD_LOGIC_VECTOR (9 downto 0);
signal rddata : STD_LOGIC_VECTOR (31 downto 0);
signal rden : STD_LOGIC;
signal wraddr : STD_LOGIC_VECTOR (9 downto 0);
signal wrdata : STD_LOGIC_VECTOR (31 downto 0);
signal wren : STD_LOGIC;
signal wrstrb : STD_LOGIC_VECTOR (3 downto 0) := "1111";
signal aes_introut_0 : STD_LOGIC;
signal dOut : STD_LOGIC_VECTOR (127 downto 0);


subtype channel_range is integer range NUM_CHANNELS-1 downto 0;

type channel_off_type is array(channel_range) of integer;
signal CHANNEL_OFFSET : channel_off_type;

type channel_cr_type is array(channel_range) of std_logic_vector(31 downto 0);
signal CHANNEL_CR : channel_cr_type;


begin

DUT: component AES_Unit_Sim_Bd port map (
  Clock => Clock,
  EnO => EnO,
  Resetn => Resetn,
  S_ReadWritePort_0_rdaddr => rdaddr,
  S_ReadWritePort_0_rddata => rddata,
  S_ReadWritePort_0_rden => rden,
  S_ReadWritePort_0_wraddr => wraddr,
  S_ReadWritePort_0_wrdata => wrdata,
  S_ReadWritePort_0_wren => wren,
  S_ReadWritePort_0_wrstrb => wrstrb,
  aes_introut_0 => aes_introut_0,
  dOut => dOut
);


Clock <= not Clock after 5ns;
Resetn <= '1' after 50ns;


channel_gen:
for i in channel_range generate
signal chmode : std_logic_vector(1 downto 0);
signal priority : unsigned(NUM_PRIORITY_BITS-1 downto 0);
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
procedure activateChannel(ch: channel_range) is
begin
wraddr <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
wrdata <= CHANNEL_CR(ch);
wren <= '1';
wait for 10ns;
wren <= '0';
end procedure;


procedure waitUntilCCF(ch: channel_range) is
begin
rden <= '1';
rdaddr <= std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH) + CHANNEL_OFFSET(ch));
wait until rddata(SR_POS_CCF) = '1'; 
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

-- TODO Write Channel Configuration data to mem


-- Setup channel 1
wait for 0ns; -- set signal 

activateChannel(0);
wait for 10ns;

activateChannel(1);

-- Wait, then setup channel 2
wait for 100ns;
activateChannel(2);

wait for 1000ns;
activateChannel(3);

-- wait until CCF of channel 1 is set
waitUntilCCF(1);
end process;


end TB;

