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

constant NUM_CHANNELS : integer := 1024;

component Binary_Search is
    generic (
        NUM_CHANNELS : natural := 8
    );
    Port (
        EnI : in std_logic;
        EnO : out std_logic;  
        size : in std_logic_vector(31 downto 0);
        ChannelPriority: in PrioArrayType(NUM_CHANNELS-1 downto 0);
        ChannelEn : in std_logic_vector(NUM_CHANNELS-1 downto 0);
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
signal highestChannel : integer;
signal size : std_logic_vector(31 downto 0);


begin

Clock <= not Clock after 5ns;
Resetn <= '1' after 20ns;

search : Binary_Search 
    generic map (NUM_CHANNELS => NUM_CHANNELS)
    port map(
        EnI => EnIBS, EnO => EnOBS, ChannelPriority => Priority, ChannelEn => ChannelEn, highestChannel => highestChannel,
        size => size, Clock => Clock, Resetn => Resetn);

-- process to set En and Priority to defaults        
process(Resetn)
 begin
 if Resetn = '0' then
    for i in 0 to NUM_CHANNELS-1 loop
        if i < 14 then
            ChannelEn(i) <= '1';
        else
            ChannelEn(i) <= '0';
        end if;
        Priority(i) <= std_logic_vector(to_unsigned(i, NUM_PRIORITY_BITS));
    end loop;
 end if;
 end process;     

-- process to start the binary search
process
begin
if Resetn = '0' then
    size <= std_logic_vector(to_unsigned(1, size'LENGTH));
end if;
EnIBS <= '0';
wait for 30ns;
-- multiply size by 2
size <= std_logic_vector(to_unsigned(to_integer(unsigned(size)*2), size'LENGTH));
EnIBS <= '1';
wait for 10ns;
EnIBS <= '0';
wait until EnOBS = '1';
end process;

end Behavioral;
