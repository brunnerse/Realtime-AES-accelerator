library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.common.ALL;

entity BinarySearch is
    generic (
        NUM_CHANNELS_IN : natural := 8
    );
    Port (
        EnI : in std_logic;
        EnO : out std_logic;
        ChannelPriority: in PrioArrayType(NUM_CHANNELS_IN-1 downto 0);
        ChannelEn : in std_logic_vector(NUM_CHANNELS_IN-1 downto 0);
        highestChannel : out integer range NUM_CHANNELS_IN -1 downto 0;
        Clock : in std_logic;
        Resetn : in std_logic
           );
end BinarySearch;

architecture Behavioral of BinarySearch is

constant NUM_CHANNELS: natural := (NUM_CHANNELS_IN+1)/2 * 2; -- Number of channels rounded up to multiple of 

subtype channel_range is integer range NUM_CHANNELS-1 downto 0;
type IdxArrayType is array(natural range<>) of integer range MAX_CHANNELS-1 downto 0;


signal Priority : PrioArrayType(NUM_CHANNELS-1 downto 0);
signal En       : std_logic_vector(NUM_CHANNELS-1 downto 0);

signal channelIdx : IdxArrayType(NUM_CHANNELS/2-1 downto 0);
signal InterPriority : PrioArrayType(NUM_CHANNELS/2-1 downto 0);
signal InterEn : std_logic_vector(NUM_CHANNELS/2-1 downto 0);

signal size : std_logic_vector(ADDR_CHANNEL_BITS downto 0);  -- Big enough to at least store the number MAX_CHANNELS
  
begin

-- forward in priority from port to internal signal
Priority(NUM_CHANNELS_IN-1 downto 0) <= ChannelPriority;
En(NUM_CHANNELS_IN-1 downto 0) <= ChannelEn;

-- if number of input channels is odd, add another dummy channel to make it even
forwardIfOdd:
if NUM_CHANNELS_IN /= NUM_CHANNELS generate
    Priority(NUM_CHANNELS-1) <= (others => '1');
    En(NUM_CHANNELS-1) <= '0'; -- dummy channel is always deactivated
end generate;

-- process that initializes a new search and does one search step per cycle.
-- If EnI = '1' while a search is running, the search will be aborted and a new search will be started
process(Clock)

variable idx1, idx2, channelIdx1, channelIdx2, winnerIdx : integer range NUM_CHANNELS-1 downto 0;
variable prio1, prio2 : std_logic_vector(NUM_PRIORITY_BITS-1 downto 0);
variable en1, en2 : std_logic;
-- Boolean that is set the true when this is the last cycle of the search, i.e. when EnO is being set
variable isFinalCycle : boolean;
begin
if rising_edge(Clock) then
    EnO <= '0';
    -- Init channelIdx array at reset and when a new search begins
    if Resetn = '0' then
        for i in channelIdx'RANGE loop
            channelIdx(i) <= i;
        end loop;
        size <= (others => '0');
        highestChannel <= 0;
    else
        -- when a search starts with 2 or less elements, one cycle is enough, so this is the last cycle
        -- otherwise, the last cycle is when sizeInternal >= size. 
        -- However, if a new search is started with EnI = '1', the current one is aborted, 
        -- so isFinalCycle is set to false.
        isFinalCycle := ( EnI = '1' and NUM_CHANNELS <= 2 )
                    or ( EnI = '0' and unsigned(size) >= NUM_CHANNELS );
        
        for i in NUM_CHANNELS/2-1 downto 0 loop
            idx1 := i*2;
            idx2 := i*2+1;
            -- use Port Input values during Initialization, else use the Intermediate results
            if idx1 >= NUM_CHANNELS/2 or EnI = '1' then
                channelIdx1 := idx1;
                en1 := En(idx1);
                prio1 := Priority(idx1);
            else
                channelIdx1 := channelIdx(idx1);
                en1 := InterEn(idx1);
                prio1 := InterPriority(idx1);
            end if;
            if idx2 >= NUM_CHANNELS/2 or EnI = '1' then
                channelidx2 := idx2;
                en2 := En(idx2);
                prio2 := Priority(idx2);
            else
                channelidx2 := channelIdx(idx2);
                en2 := InterEn(idx2);
                prio2 := InterPriority(idx2);
            end if;

            if  en2 = '1' and (en1 = '0' or unsigned(prio2) > unsigned(prio1)) then
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
            
            -- highestChannel is the output of the first channel
            if i = 0 and isFinalCycle then
                 highestChannel <= winnerIdx;
            end if;
        end loop;

        -- update sizeInternal: set to 4 on start, then always to sizeInternal*2
        if EnI = '1' then
            size <= std_logic_vector(to_unsigned(4, size'LENGTH));
        else
            -- double sizeInternal
            size <= size(size'HIGH-1 downto 0) & '0';
        end if;
        
         -- set EnO and reset sizeInternal when a search has finished
         -- This is done outside of the for loop in case of NUM_CHANNELS = 1
        if isFinalCycle then
            EnO <= '1';
            size <= (others => '0');
        end if;
    end if;
end if;
end process;
    



end architecture;