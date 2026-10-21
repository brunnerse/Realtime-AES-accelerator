----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.08.2022 01:09:30
-- Design Name: 
-- Module Name: KeyExpansion - Behavioral
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
use IEEE.NUMERIC_STD.ALL;
 
use work.common.ALL;
use work.aes_sbox.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity KeyExpansion is
    Port (  userKey : in key_t; 
            init : in STD_LOGIC;
            reverse : in STD_LOGIC;

            calcNextRoundKey : in STD_LOGIC;

--
            roundKey : out block_t; 
            isLastRoundKey : out STD_LOGIC;
            Clock : in STD_LOGIC;
            Resetn : in STD_LOGIC);
end entity;


architecture RTL of KeyExpansion is

subtype rcon_t is STD_LOGIC_VECTOR(7 downto 0);
subtype word_t is STD_LOGIC_VECTOR(31 downto 0);
type words_t is array(0 to AES_NK-1) of word_t; 



function calcNextWord(W : words_t; wordIdx : natural; RCon : rcon_t) return word_t is
    variable v_nextW : word_t;
    variable v_temp : STD_LOGIC_VECTOR(31 downto 0);          
begin  
    v_temp := W(AES_NK-1); 

    -- TODO use something more efficient than rem?
    if wordIdx rem AES_NK = 0 then -- TODO key size as parameter
        -- Rotate word: rol 8
        v_temp := v_temp(23 downto 0) & v_temp(31 downto 24);
        -- perform substitution for each byte 
        v_temp := SubBytesInVec(v_temp); 
        -- xor with Rcon constant
        v_temp := v_temp xor (Rcon & x"000000");

    elsif AES_NK > 6 and wordIdx rem AES_NK = 4 then
        -- Special rule for AES256: sbox substitution for middle word
        v_temp := SubBytesInVec(v_temp); 
    end if;
    
    v_nextW := W(0) xor v_temp; -- W(0) = W{i-N}

    return v_nextW;
end function;

procedure updateWords(variable W : inout words_t; newWord : in word_t) is
begin

    for i in 0 to AES_NK-2 loop
        W(i) := W(i+1);   
    end loop;

    W(AES_NK-1) := newWord;  
end procedure;

-- TODO is wordIdx the idx of the word being calculated, or the idx of the word that is used to calculate the next word?  
function calcPrevWord(W : words_t; wordIdx : natural; RCon : rcon_t) return word_t is
    variable v_prevW : word_t;
    variable v_temp : STD_LOGIC_VECTOR(31 downto 0);          
begin  
    -- TODO
    v_temp := W(0); 

    -- TODO use something more efficient than rem?
    if wordIdx rem AES_NK = 0 then -- TODO key size as parameter
        -- Rotate word: rol 8
        v_temp := v_temp(23 downto 0) & v_temp(31 downto 24);
        -- perform substitution for each byte 
        v_temp := SubBytesInVec(v_temp); 
        -- xor with Rcon constant
        v_temp := v_temp xor (Rcon & x"000000");

    elsif AES_NK > 6 and wordIdx rem AES_NK = 4 then
        -- Special rule for AES256: sbox substitution for middle word
        v_temp := SubBytesInVec(v_temp); 
    end if;
    
    v_prevW := W(AES_NK-1) xor v_temp; -- W(0) = W{i-N}

    return v_prevW;
end function;

procedure updateWordsInv(variable W : inout words_t; newWord : in word_t) is
begin
    for i in 1 to AES_NK-1 loop
        W(i) := W(i-1);   
    end loop;

    W(0) := newWord;  
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
signal round : natural; -- range 0 to AES_NR;
signal RCon : rcon_t;

signal finalWords : words_t;

--signal nextKeyIdxInWord : natural;

begin

/*
process (Clock)
begin
if rising_edge(Clock) then
    if Resetn = '0' or init = '1' then
        if reverse /= '1' then
            nextKeyIdxInWord <= 0;
        else
            nextKeyIdxInWord <= 0; -- 
        end if;
    else
        for i in 0 to AES_NB-1 loop
            roundKey(roundKey'HIGH-32*i downto roundKey'HIGH-31-32*i) <= 
                words(nextKeyIdxInWord + i);
        end loop;
        if calcNextRoundKey = '1' then
            if reverse /= '1' then
                nextKeyIdxInWord <= (nextKeyIdxInWord + 4) rem AES_NK; 
            else
                nextKeyIdxInWord <= (nextKeyIdxInWord + AES_NK - 4) rem AES_NK; 
            end if;
        end if;

    end if;
end if;
end process;
*/
--assert AES_NK = 4 report "Module does not support AES_NK /= 4!" severity failure;

process (Clock)

variable v_temp : word_t; 

variable v_W, v_prevW : words_t;  -- TODO eliminate prevW
variable v_nextW : word_t;

variable v_wordIdx : natural;

begin
if rising_edge(Clock) then
    if Resetn = '0' or init = '1' then
        if reverse /= '1' then
            for i in 0 to AES_NK-1 loop
                v_W(i) := userKey(userKey'HIGH-32*i downto userKey'HIGH-31-32*i); 
            end loop;
            v_wordIdx := AES_NK;

            RCon <= x"01"; 
            round <= 0;
            -- finalWords <= (others => (others => '-'));

        else
            /*
            -- This assumes the 
            v_W := finalWords;
            RCon <= x"36"; -- TODO depends on number of rounds and key size 
            round <= AES_NR;
            */
        end if;
    else
        if calcNextRoundKey = '1' then

            if round = AES_NR - 1 then
                isLastRoundKey <= '1';
            else
                isLastRoundKey <= '0';
            end if;

            if reverse /= '1' then
                round <= round + 1;

                -- Do four updates since next round key is always four words
                for i in 0 to AES_NB-1 loop
                    -- One update: Calculate one word, then shift them all
                    -- We calculate W_next = W_i, which is then inserted by shifting the entire W

                    v_nextW := calcNextWord(v_W, v_wordIdx, RCon);

                    updateWords(v_W, v_nextW);

                    if v_wordIdx rem AES_NK = 0 then
                        calcNextRcon(RCon);
                    end if;

                    report "Calculated word " & integer'image(v_wordIdx) & " = " & to_hstring(v_nextW);

                    v_wordIdx := v_wordIdx + 1;
                end loop;
                
                -- Calculate new constant:  Old RCon * 'x' (i.e. 02), which means 2Rcon 
                if round /= AES_NR - 1 then
                    calcNextRcon(RCon);
                else
                    finalWords <= v_W;
                end if;

            else
                -- Reverse KeyExpansion
                round <= round - 1;

                --prevkeyW[3] = keyW[3] ^ keyW[2]; 
                for i in AES_NB-1 downto 1 loop
                    v_W(i) := v_prevW(i) xor v_prevW(i-1);
                end loop;

                v_temp := v_W(3);
                -- Rotate word: rol 8
                v_temp := v_temp(23 downto 0) & v_temp(31 downto 24);
                -- perform substitution for each byte 
                v_temp := SubBytesInVec(v_temp);
                -- xor with Rcon constant
                v_temp := v_temp xor (Rcon & x"000000");

                v_W(0) := v_prevW(0) xor v_temp;


                -- Calculate prev constant:  RCon / 'x' (i.e. 02), which means 2Rcon 
                -- if lowest bit was set, that must men "xor x1b" was executed previously
                calcPrevRcon(RCon);
            end if;
        end if;

    end if;

    -- Round key always equals the four lowest words 
    for i in 0 to AES_NB-1 loop
        roundKey(roundKey'HIGH-32*i downto roundKey'HIGH-31-32*i) <= v_W(i);
    end loop;
    
    -- TODO remove again
    finalWords <= v_W;
end if;
end process;



end architecture;
