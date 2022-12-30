library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.common.ALL;
use work.addresses.ALL;
use work.register_bit_positions.ALL;

entity Test_AES_Unit_3 is 
generic (
    LITTLE_ENDIAN : boolean := true; 
    NUM_CHANNELS : integer := 16
    );
end Test_AES_Unit_3;


architecture TB of Test_AES_Unit_3 is


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



component AES_Unit_3_Sim is
port (
  Address_0 : in STD_LOGIC_VECTOR (31 downto 0);
  Clock : in STD_LOGIC;
  DataIn_0 : in STD_LOGIC_VECTOR (31 downto 0);
  DataOut_0 : out STD_LOGIC_VECTOR (31 downto 0);
  ReadEn_0 : in STD_LOGIC;
  Resetn : in STD_LOGIC;
  WrByteEna_0 : in STD_LOGIC_VECTOR (3 downto 0);
  WriteEn_0 : in STD_LOGIC;
  aes_introut : out STD_LOGIC;
  busy_0 : out STD_LOGIC
);
end component AES_Unit_3_Sim;

signal Address : STD_LOGIC_VECTOR (31 downto 0);
signal Clock : STD_LOGIC := '1';
signal DataIn : STD_LOGIC_VECTOR (31 downto 0);
signal DataOutEndian, DataOut : STD_LOGIC_VECTOR (31 downto 0);
signal ReadEn : STD_LOGIC := '0';
signal Resetn : STD_LOGIC := '0';
signal WriteEn : STD_LOGIC :='0';
signal aes_introut : STD_LOGIC;
signal busy : STD_LOGIC;


subtype channel_range is integer range NUM_CHANNELS-1 downto 0;

type channel_off_type is array(channel_range) of integer;
signal CHANNEL_OFFSET : channel_off_type;

type channel_cr_type is array(channel_range) of std_logic_vector(31 downto 0);
signal CHANNEL_CR : channel_cr_type;

signal channel : channel_range;

constant START_ADDR : std_logic_vector(31 downto 0) := x"00000014";

begin

DUT: component AES_Unit_3_Sim port map (
  Address_0 => Address,
  Clock => Clock,
  DataIn_0 => SwapEndian(DataIn),
  DataOut_0 => DataOutEndian,
  ReadEn_0 => ReadEn,
  Resetn => Resetn,
  WrByteEna_0 => "1111",
  WriteEn_0 => WriteEn,
  aes_introut => aes_introut,
  busy_0 => busy
);

DataOut <= SwapEndian(DataOutEndian);

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
procedure write(ch: channel_range; addr : integer; data : std_logic_vector) is
begin
Address <= std_logic_vector(to_unsigned(addr, Address'LENGTH) + CHANNEL_OFFSET(ch));
DataIn <= data;
WriteEn <= '1';
wait until rising_edge(Clock);
WriteEn <= '0';
wait until rising_edge(Clock) and busy = '0';
end procedure;

procedure read(ch : channel_range; addr : integer) is
begin
Address <= std_logic_vector(to_unsigned(addr, Address'LENGTH) + CHANNEL_OFFSET(ch));
ReadEn <= '1';
wait until rising_edge(Clock);
ReadEn <= '0';
wait until rising_edge(Clock) and busy = '0';
end procedure;

procedure activateChannel(ch: channel_range) is
begin
write(ch, ADDR_CR, CHANNEL_CR(ch));
end procedure;

procedure waitUntilCCF(ch: channel_range) is
begin
while true loop
    read(ch, ADDR_SR);
    if DataIn(SR_POS_CCF) = '1' then
        exit;
    end if;
end loop;

end procedure;

procedure clearCCF(ch: channel_range) is
begin

DataOut <= CHANNEL_CR(ch);
DataOut(7) <= '1'; -- set CCFC flag
DataOut(0) <= '0'; -- deassert EN
wait for 0ns;
-- deassert CCFC flag again
DataOut(7) <= '0';
wait for 0ns;
write(ch, ADDR_CR, DataOut);
end procedure;

procedure setBaseAddr(baseaddr: std_logic_vector) is
begin
write(0, ADDR_BASEADDR, SwapEndian(baseaddr));
end procedure;

begin

-- wait until reset is deasserted
wait until Resetn = '1' and rising_edge(Clock);
-- write baseaddr
setBaseAddr(START_ADDR);
-- Setup channel 1
channel <= 1;
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

wait for 50ns;
-- clear CCF of first channel
clearCCF(1);

waitUntilCCF(2);
clearCCF(2);

waitUntilCCF(3);
clearCCF(3);
wait;
end process;

end TB;

