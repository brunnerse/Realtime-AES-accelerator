----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.11.2022 19:53:53
-- Design Name: 
-- Module Name: TestBinarySearch - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.ALL;
use work.binary_search_types.ALL;
use ieee.std_logic_misc.and_reduce;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TestBinarySearch is
--  Port ( );
end TestBinarySearch;

architecture Behavioral of TestBinarySearch is

constant NUM_CHANNELS : integer := 128;

component BinarySearch is
    generic (
        NUM_CHANNELS : natural := 8
    );
    Port (
        EnI : in std_logic;
        EnO : out std_logic;  
        size : in std_logic_vector(ADDR_CHANNEL_BITS downto 0);
        ChannelPriority: in PrioArrayType(NUM_CHANNELS-1 downto 0);
        ChannelEn : in std_logic_vector(NUM_CHANNELS-1 downto 0);
        avoidChannelIdx : in integer range NUM_CHANNELS-1 downto 0;
        highestChannel : out integer range NUM_CHANNELS -1 downto 0;
        Clock : in std_logic;
        Resetn : in std_logic
           );
end component;

signal EnIBS, EnOBS : std_logic;
signal Resetn : std_logic := '0';
signal Clock : std_logic := '1';
signal Priority : PrioArrayType(NUM_CHANNELS-1 downto 0);
signal ChannelEn : std_logic_vector(NUM_CHANNELS-1 downto 0);
signal highestChannel, avoidChannel : integer;
signal size :  std_logic_vector(ADDR_CHANNEL_BITS downto 0) := (others => '0');


begin

Clock <= not Clock after 5ns;
Resetn <= '1' after 20ns;
avoidChannel <= 7;

search : BinarySearch 
    generic map (NUM_CHANNELS => NUM_CHANNELS)
    port map(
        EnI => EnIBS, EnO => EnOBS, ChannelPriority => Priority, ChannelEn => ChannelEn, highestChannel => highestChannel,
        avoidChannelIdx => avoidChannel,
        size => size, Clock => Clock, Resetn => Resetn);

-- generate Priority to defaults
GenPrio:        
for i in NUM_CHANNELS-1 downto 0 generate
    Priority(i) <= std_logic_vector(to_unsigned(NUM_CHANNELS-i, NUM_PRIORITY_BITS)) when i/= 31 else 
                   (others => '0');
end generate;


-- process to start the binary search
process
procedure adjustEn(size: std_logic_vector(size'LENGTH-1 downto 0)) is
begin
    for i in 0 to NUM_CHANNELS-1 loop
        if i < to_integer(unsigned(size)) and i < 68 then
            ChannelEn(i) <= '1';
        else
            ChannelEn(i) <= '0';
        end if;
     end loop;
end procedure;


begin

EnIBS <= '0';
wait for 30ns;
-- adjust size
if unsigned(size) = 0 then
    size <= std_logic_vector(to_unsigned(1, size'LENGTH));
else
    -- multiply size by 2
    size <= std_logic_vector(to_unsigned(to_integer(unsigned(size)*2), size'LENGTH));
end if;
wait for 0ns;
adjustEn(size);

EnIBS <= '1';
wait for 10ns;
EnIBS <= '0';
wait until EnOBS = '1';
if unsigned(size) = to_unsigned(NUM_CHANNELS, size'LENGTH) then
    wait;
end if;
end process;

end Behavioral;
