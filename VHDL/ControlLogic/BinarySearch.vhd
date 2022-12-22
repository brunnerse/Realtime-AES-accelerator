library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.common.ALL;

entity BinarySearch is
    generic (
        NUM_CHANNELS : natural := 8;
        SIZE_IS_POWER_OF_2 : boolean := false
    );
    Port (
        EnI : in std_logic;
        EnO : out std_logic;
        size : in std_logic_vector(ADDR_CHANNEL_BITS downto 0); -- Big enough to at least store the number MAX_CHANNELS
        ChannelPriority: in PrioArrayType(NUM_CHANNELS-1 downto 0);
        ChannelEn : in std_logic_vector(NUM_CHANNELS-1 downto 0);
        avoidChannelIdx : in integer range NUM_CHANNELS-1 downto 0;
        highestChannel : out integer range NUM_CHANNELS -1 downto 0;
        Clock : in std_logic;
        Resetn : in std_logic
           );
end BinarySearch;

architecture Behavioral of BinarySearch is

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
type IdxArrayType is array(natural range<>) of integer range MAX_CHANNELS-1 downto 0;

signal channelIdx : IdxArrayType(NUM_CHANNELS-1 downto 0);
signal InterPriority : PrioArrayType(NUM_CHANNELS-1 downto 0);
signal InterEn : std_logic_vector(NUM_CHANNELS-1 downto 0);


signal sizeInternal : std_logic_vector(size'HIGH downto 0);
  
begin

-- process that initializes a new search and does one search step per cycle.
-- If EnI = '1' while a search is running, the search will be aborted and a new search will be started
process(Clock)

variable idx1, idx2, channelIdx1, channelIdx2, winnerIdx : integer range NUM_CHANNELS-1 downto 0;
variable prio1, prio2 : std_logic_vector(NUM_PRIORITY_BITS-1 downto 0);
variable en1, en2 : std_logic;

begin
if rising_edge(Clock) then
    EnO <= '0';
    -- Init channelIdx array at reset and when a new search begins
    if Resetn = '0' then
        for i in channelIdx'RANGE loop
            channelIdx(i) <= i;
        end loop;
        sizeInternal <= (others => '0');
        highestChannel <= 0;
    else

        for i in NUM_CHANNELS/2-1 downto 0 loop
            idx1 := i*2;
            idx2 := i*2+1;
            -- use Port Input values during Initialization, else use the Intermediate results
            if EnI = '1' then
                channelIdx1 := idx1;
                channelidx2 := idx2;
                en1 := ChannelEn(idx1);
                en2 := ChannelEn(idx2);
                prio1 := ChannelPriority(idx1);
                prio2 := ChannelPriority(idx2);
            else
                channelIdx1 := channelIdx(idx1);
                channelidx2 := channelIdx(idx2);
                en1 := InterEn(idx1);
                en2 := InterEn(idx2);
                prio1 := InterPriority(idx1);
                prio2 := InterPriority(idx2);
            end if;

            if not (avoidChannelIdx = channelIdx2 or en2 = '0') and
                    (avoidChannelIdx = channelIdx1 or en1 = '0' or unsigned(prio2) > unsigned(prio1)) then
                winnerIdx := channelIdx2;
                channelIdx(i) <= channelIdx2;
                InterPriority(i) <= prio2;
                InterEn(i) <= en2;
            else
                winnerIdx := channelIdx1;
                channelIdx(i) <= channelIdx1;
                InterPriority(i) <= prio1;
                InterEn(i) <= en1;
            end if;
            
            -- Set highestChannel if finished
            if i = 0 then
                -- check if a search has finished
                if (EnI = '1' and unsigned(size) <= to_unsigned(2, size'LENGTH)) or
                        unsigned(sizeInternal) = to_unsigned(2, sizeInternal'LENGTH) then
                    highestChannel <= winnerIdx;
                end if;
            end if;
        end loop;

        -- update sizeInternal: set to size/2 on start, then always to sizeInternal/2 in every cycle
        if EnI = '1' then
             -- Round up size to next power of 2
            if SIZE_IS_POWER_OF_2 then -- not necessary when size is already a power of 2
                sizeInternal <= '0' & size(size'HIGH downto 1);
            else
                -- sizeInternal = 2**log2(size) / 2
                sizeInternal <= '0' & std_logic_vector(to_unsigned(2**log2(to_integer(unsigned(size))), sizeInternal'LENGTH)(sizeInternal'HIGH downto 1));
            end if;
        else
            -- divide sizeInternal by 2
            sizeInternal <= '0' & sizeInternal(sizeInternal'HIGH downto 1);
        end if;
        
         -- set EnO when a search has finished
         -- This is done outside of the for loop in case of NUM_CHANNELS = 1
        if (EnI = '1' and unsigned(size) <= to_unsigned(2, size'LENGTH)) or
                unsigned(sizeInternal) = to_unsigned(2, sizeInternal'LENGTH) then
            EnO <= '1';
        end if;
    end if;
end if;
end process;
    



end architecture;