library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

use work.common.ALL;
use work.addresses.ALL;

entity Test_AES_Unit_3_Sim_Bd is 
generic (
    NUM_CHANNELS : integer := 16
    );
end Test_AES_Unit_3_Sim_Bd;


architecture TB of Test_AES_Unit_3_Sim_Bd is

component AES_Unit_3_Sim_Bd is
port (
  Clock : in STD_LOGIC;
  Resetn : in STD_LOGIC;
  S_ReadWritePort_rdaddr : in STD_LOGIC_VECTOR (16 downto 0);
  S_ReadWritePort_rddata : out STD_LOGIC_VECTOR (31 downto 0);
  S_ReadWritePort_rden : in STD_LOGIC;
  S_ReadWritePort_wraddr : in STD_LOGIC_VECTOR (16 downto 0);
  S_ReadWritePort_wrdata : in STD_LOGIC_VECTOR (31 downto 0);
  S_ReadWritePort_wren : in STD_LOGIC;
  S_ReadWritePort_wrstrb : in STD_LOGIC_VECTOR (3 downto 0);
  aes_introut_0 : out STD_LOGIC
);
end component AES_Unit_3_Sim_Bd;

constant START_ADDR : std_logic_vector(31 downto 0) := x"00000010";


signal Clock : STD_LOGIC := '1';
signal Resetn : STD_LOGIC := '0';
signal rdaddr : STD_LOGIC_VECTOR (16 downto 0);
signal rddata : STD_LOGIC_VECTOR (31 downto 0);
signal rden : STD_LOGIC := '0';
signal wraddr : STD_LOGIC_VECTOR (16 downto 0);
signal wrdata : STD_LOGIC_VECTOR (31 downto 0);
signal wren : STD_LOGIC := '0';
signal wrstrb : STD_LOGIC_VECTOR (3 downto 0) := "1111";
signal aes_introut_0 : STD_LOGIC;


subtype channel_range is integer range NUM_CHANNELS-1 downto 0;

type channel_off_type is array(channel_range) of integer;
signal CHANNEL_OFFSET : channel_off_type;

type channel_cr_type is array(channel_range) of std_logic_vector(31 downto 0);
signal CHANNEL_CR : channel_cr_type;

signal channel : channel_range;


begin

DUT: component AES_Unit_3_Sim_Bd port map (
  Clock => Clock,
  Resetn => Resetn,
  S_ReadWritePort_rdaddr => rdaddr,
  S_ReadWritePort_rddata => rddata,
  S_ReadWritePort_rden => rden,
  S_ReadWritePort_wraddr => wraddr,
  S_ReadWritePort_wrdata => wrdata,
  S_ReadWritePort_wren => wren,
  S_ReadWritePort_wrstrb => wrstrb,
  aes_introut_0 => aes_introut_0
);

channel_gen:
for i in channel_range generate
signal chmode : std_logic_vector(1 downto 0);
begin
    CHANNEL_OFFSET(i) <= i * 128;
    chmode <= CHAINING_MODE_ECB when i mod 3 = 0 else
              CHAINING_MODE_CBC when i mod 3 = 1 else
              CHAINING_MODE_CTR; -- when i mod 3 = 2 else
            
    CHANNEL_CR(i) <= x"0000" & '0' & GCM_PHASE_INIT & "000" & "0" & "00" & chmode & MODE_ENCRYPTION & "00" & '1';
end generate;

Clock <= not Clock after 5ns;
Resetn <= '1' after 50ns;




process begin
-- wait until reset is deasserted
wait until Resetn = '1' and rising_edge(Clock);
wrdata <= START_ADDR;
wraddr <= std_logic_vector(to_unsigned(ADDR_BASEADDR, ADDR_WIDTH));
wren <= '1';
wait for 10ns;
wren <= '0';

-- Setup channel 1
channel <= 1;
wait for 0ns; -- set signal channel
-- Write CR of channel 1
wrdata <= CHANNEL_CR(channel);
wraddr <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_OFFSET(channel));
wren <= '1';
wait for 10 ns;
wren <= '0';

-- wait until CCF of channel 1 is set
rden <= '1';
rdaddr <= std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH) + CHANNEL_OFFSET(channel));
wait until rddata(0) = '1'; 
-- clear CCF of first channel
wait for 50ns;
wren <= '1';
wraddr <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_OFFSET(3));
wrdata <= CHANNEL_CR(channel);
wrdata(7) <= '1'; -- set CCFC flag
wrdata(0) <= '0'; -- deassert EN
wait for 10ns;
-- deassert CCFC flag again
wrdata(7) <= '0';
wait for 10ns;
wren <= '0';
rden <= '0';
wait;
end process;



end TB;

