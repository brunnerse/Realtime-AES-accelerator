library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
 
use work.common.ALL;
use work.aes_sbox.ALL;

use IEEE.NUMERIC_STD.ALL;


entity KeyExpansion is
    Generic (
        CYCLES_PER_KEY : natural range 1 to 4 := 2
        -- TODO add generic to configure if with/without configurable key size
    );
    Port (  userKey : in key_t; 
            init : in STD_LOGIC;
            reverse : in STD_LOGIC;
            keysize : in mode_t := KEYSIZE_256;

            calcNextRoundKey : in STD_LOGIC;
--
            roundKey : out block_t; 
            Clock : in STD_LOGIC;
            Resetn : in STD_LOGIC
    );
end entity;


architecture RTL of KeyExpansion is


subtype wordidx_t is unsigned(5 downto 0);  -- Max value 56 for AES256
type wordidx_array_t is array(0 to 2) of wordidx_t;

subtype rcon_t is STD_LOGIC_VECTOR(7 downto 0);
subtype word_t is STD_LOGIC_VECTOR(31 downto 0);
type words_t is array(0 to AES_MAX_NK-1) of word_t; 




-- wordIdx is the idx of the word being calculated 
function calcNewWord(W : words_t; RCon : rcon_t; 
    reverse_dir : boolean; isRoundkeyStartIdx : boolean; isRoundkeyHalfIdx : boolean;
    Nk : wordidx_t
) return word_t is
    variable v_prevW : word_t;
    variable v_temp : STD_LOGIC_VECTOR(31 downto 0);          
begin  
    -- We essentially calculate W(i) from W(i+1) to W(i+AES_NK) 
    -- wordIdx equals i

    if not reverse_dir then
        v_temp := W(to_integer(Nk)-1);  
        v_prevW := W(0);
    else
        v_temp := W(to_integer(Nk)-2);  
        v_prevW := W(to_integer(Nk)-1);
    end if;

    -- TODO use something more efficient than rem?
    if isRoundkeyStartIdx then 
        v_temp := v_temp(23 downto 0) & v_temp(31 downto 24); -- Rotate word: rol 8
    end if;
    if isRoundkeyStartIdx or isRoundkeyHalfIdx then
        v_temp := SubBytesInVec(v_temp);  -- perform substitution for each byte 
    end if;
    if isRoundkeyStartIdx then
        -- xor with Rcon constant
        v_temp(31 downto 24) := v_temp(31 downto 24) xor Rcon; -- Only highest byte, since Rcon is extended to  [Rcon 00 00 00]
    end if;

    return v_prevW xor v_temp; 

    return v_prevW;
end function;


----------
-- Procedures to update Words by shifting in the next/previous word on the left/right 
procedure shiftWords(variable W : inout words_t; shiftLeft : boolean) is 
begin
    if shiftLeft then
        for i in 0 to AES_MAX_NK-2 loop
            W(i) := W(i+1);   
        end loop;
    else
        for i in AES_MAX_NK-1 downto 1 loop
            W(i) := W(i-1);   
        end loop;
    end if;
end procedure;



procedure calcNextRcon(signal RCon : inout rcon_t) is 
begin
    -- Multiple Rcon by x (i.e. 02) in GF(2^8) modulo m(x ) = x^8 + x^4 + x^3 + x + 1 
    if RCon(7) = '0' then -- RCon < 0x80
        RCon <= RCon(6 downto 0) & '0';   -- Multiply by x equals left shift by 1
    else -- Result would not be representable by 8 bits; reduce by subtracting m(x) 
        RCon <= (RCon(6 downto 0) & '0') xor x"1b"; 
    end if;
end procedure;


procedure calcPrevRcon(signal RCon : inout rcon_t) is 
begin
    -- Reverse multiplication of Rcon by x (i.e. 02) in GF(2^8)

    -- Check if a reduction of a simple left shift happened by bit 0:
    -- Bit 0 can only by '1' if a reduction happened, since a mere left shift always set bit 0 to '0' 
    if RCon(0) = '0' then  
        -- Step was a mere left shift -> reverse via right shift
        RCon <= std_logic_vector(shift_right(unsigned(RCon), 1)); 
        Rcon(7) <= '0'; -- Since no reduction happened, MSB must have been a '0'
    else 
        -- Step was left shift + reduction; reverse by adding m(x), then doing a right shift 
        RCon <= std_logic_vector(shift_right(unsigned(RCon xor x"1b"), 1));
        RCon(7) <= '1'; -- Since reduction happened, MSB must have been a '1'
    end if;
end procedure;


-- The Index of the key that is being calculated in this cycle
signal RCon : rcon_t;

signal finalRcon : rcon_t;
signal finalWords : words_t;

signal W : words_t;
signal nextWordIdx : wordidx_t;

signal update_ctr : unsigned(log2(CYCLES_PER_KEY)-1 downto 0);



constant AES_NK_SEL : wordidx_array_t := (     
    to_integer(unsigned(KEYSIZE_128)) => to_unsigned(128/32, wordidx_t'LENGTH),
    to_integer(unsigned(KEYSIZE_192)) => to_unsigned(192/32, wordidx_t'LENGTH),
    to_integer(unsigned(KEYSIZE_256)) => to_unsigned(256/32, wordidx_t'LENGTH)
);

-- Starting point for wordidx on reversal (when calculating from the last round key)
constant AES_NB_TIMES_NR_SEL : wordidx_array_t := (  -- Equals NR * NR      
    to_integer(unsigned(KEYSIZE_128)) => to_unsigned(10 * 4, wordidx_t'LENGTH), -- 40
    to_integer(unsigned(KEYSIZE_192)) => to_unsigned(12 * 4, wordidx_t'LENGTH), -- 48
    to_integer(unsigned(KEYSIZE_256)) => to_unsigned(14 * 4, wordidx_t'LENGTH) -- 56
);

signal aes_nk : wordidx_t;
signal aes_wordidx_max : wordidx_t;

begin

assert CYCLES_PER_KEY /= 3 severity failure;

process (Clock)
begin
if rising_edge(Clock) then
    if init = '1' then
        aes_nk <= AES_NK_SEL(to_integer(unsigned(keysize))); 
        aes_wordidx_max <= AES_NB_TIMES_NR_SEL(to_integer(unsigned(keysize)));
    end if;
end if;
end process;

process (Clock)
    -- TODO instead of nextWordIdx, use wordidxRemNk variable

    variable v_W : words_t; 
    variable v_newW : word_t;
    -- v_nextWordIdx equals index of next word to calculate,
    -- i.e. for reverse, it decrements (technically prevWordIdx)
    variable v_nextWordIdx : unsigned(5 downto 0); -- Max value 56 (for AES256) -> 6 bits sufficient

begin
if rising_edge(Clock) then
    if Resetn = '0' then
        v_W := (others => (others => '-'));
        finalWords <= (others => (others => '-'));
        finalRCon <= (others => '-');

        update_ctr <= to_unsigned(0, update_ctr'LENGTH);

    else
        -- TODO test different init scheme 
        if init = '1' then
            if reverse /= '1' then
                -- For simplicity, we always set all words to the userKey, even if Nk < AES_MAX_NK
                for i in 0 to AES_MAX_NK-1 loop
                    v_W(i) := userKey(userKey'HIGH-32*i downto userKey'HIGH-31-32*i); 
                end loop;

                -- Next Idx is the word after the ones we initialized 
                v_nextWordIdx := AES_NK_SEL(to_integer(unsigned(keysize))); --to_unsigned(AES_NK, wordidx_t'LENGTH);

                RCon <= x"01"; 

                -- Set finalWords and finalRcon to don't care to show that they are not valid anymore
                finalWords <= (others => (others => '-'));
                finalRCon <= (others => '-');

            else
                -- This assumes that before, a non-reversed keyexpansion ran until its last round 
                v_W := finalWords;
                RCon <= finalRcon; 

                -- Next idx is the last word of second-last round key: AES_NR * AES_NB - 1 
                v_nextWordIdx := AES_NB_TIMES_NR_SEL(to_integer(unsigned(keysize))); 
            end if;

            update_ctr <= to_unsigned(0, update_ctr'LENGTH);

        elsif calcNextRoundKey = '1' or (update_ctr'LENGTH > 0 and update_ctr /= 0) then
            -- Calculate words for next round key until another full key has been calculated

            update_ctr <= update_ctr + 1;

            -- Do up to NB updates since next round key is always NB words
            for i in 0 to AES_NB/CYCLES_PER_KEY-1 loop
                
                if reverse = '1' then
                    v_nextWordIdx := v_nextWordIdx - 1;
                end if;

                v_newW := calcNewWord(v_W, RCon, reverse = '1', v_nextWordIdx rem aes_nk = 0,
                       aes_nk > 6 and v_nextWordIdx rem aes_nk = 4, aes_nk);

                -- Insert newW into words, either at the end (for forward) or at the beginning (for reverse) 
                if reverse /= '1' then
                    shiftWords(v_W, true); -- Shift words left to make space for new word
                    v_W(to_integer(aes_nk)-1) := v_newW; 
                else
                    shiftWords(v_W, false); -- Shift words right to make space for new word
                    v_W(0) := v_newW;
                end if;

                -- Check if we used the RCon constant 
                if v_nextWordIdx rem aes_nk = 0 then

                    if reverse /= '1' then

                        finalRcon <= RCon; -- Store the lastest used RCon in finalRCon

                        if v_nextWordIdx < aes_wordidx_max then -- TODO we can skip this if we do an INIT step after keyexpansion 
                            calcNextRcon(RCon); -- Calculate the next RCon
                        end if;
                    else
                        calcPrevRcon(RCon); -- Calculate the previous RCon
                    end if;

                end if;

                if reverse /= '1' then
                    v_nextWordIdx := v_nextWordIdx + 1;
                end if;
            end loop;

            if reverse /= '1' then
                -- Store the most recently calculated W as finalW 
                finalWords <= v_W;
            end if; 
        end if;
    end if;

    -- Round key always equals the four lowest words 
    for i in 0 to AES_NB-1 loop
        roundKey(roundKey'HIGH-32*i downto roundKey'HIGH-31-32*i) <= v_W(i);
    end loop;
    
    -- TODO for debug; remove eventually
    W <= v_W;
    nextWordIdx  <= v_nextWordIdx;
end if;
end process;



end architecture;
