library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.common.ALL;
use work.binary_search_types.ALL;



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.common.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Binary_Search is
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
end Binary_Search;

architecture Behavioral of Binary_Search is

-- log2 that rounds up
function log2( i : natural) return integer is
    variable temp    : integer := 1;
    variable ret_val : integer := 0; 
  begin
    					
    while temp < i loop
      ret_val := ret_val + 1;
      temp    := temp * 2;     
    end loop;
    
    return ret_val;
  end function;
  
subtype channel_range is integer range NUM_CHANNELS-1 downto 0;

signal channelIdx : IdxArrayType(NUM_CHANNELS-1 downto 0);
signal sizeInternal : std_logic_vector(31 downto 0); -- TODO log2(NUM_CHANNELS)-1 downto 0 ?
  
begin

-- process that initializes a new search and does one search step per cycle.
-- If EnI = '1' while a search is running, the search will be aborted and a new search will be started
process(Clock)
variable idx1, idx2, winnerIdx : integer;
begin
if rising_edge(Clock) then
    EnO <= '0';
    -- Init channelIdx array at reset and when a new search begins
    if Resetn = '0' or EnI = '1' then
        for i in channelIdx'RANGE loop -- TODO Bei Suche den Initialisierungstakt irgendwie sparen?
            channelIdx(i) <= i;
        end loop;
        if Resetn = '1' and unsigned(size) < to_unsigned(2, size'LENGTH) then
            EnO <= '1';
            highestChannel <= 0;
        else
            -- Round up size to next power of 2
            report "log2 of " & integer'image(to_integer(unsigned(size))) & " gives " & integer'image(log2(to_integer(unsigned(size))));
            
            sizeInternal <= std_logic_vector(to_unsigned(2**log2(to_integer(unsigned(size))), sizeInternal'LENGTH));
        end if;    
    else
        -- Do one search step per cycle
        for i in NUM_CHANNELS/2-1 downto 0 loop
            idx1 := channelIdx(i*2);
            idx2 := channelIdx(i*2+1);
            report integer'image(i) & " = testing " & integer'image(idx1) & " and " & integer'image(idx2);
            -- TODO Sonderfall, wenn size keine Zweierpotenz?
            if ChannelEn(idx2) = '1' and (ChannelEn(idx1) = '0' or ChannelPriority(idx2) > ChannelPriority(idx1)) then
                winnerIdx := idx2;
            else
                winnerIdx := idx1;
            end if;
            channelIdx(i) <= winnerIdx;
        end loop;
        -- divide sizeInternal by 2
        sizeInternal <= '0' & sizeInternal(sizeInternal'HIGH downto sizeInternal'LOW+1); 
        -- check if current search has finished
        if unsigned(sizeInternal) = to_unsigned(2, sizeInternal'LENGTH) then
            EnO <= '1';
            -- Best Channel is the winner of the comparison for position 0, i.e. the last loop iteration
            highestChannel <= winnerIdx;
        end if;
    end if;
end if;
end process;
    



end architecture;