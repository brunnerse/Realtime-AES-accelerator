library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.common.ALL;

entity AEA is
    Generic (
        CYCLES_PER_ROUNDKEY : natural range 1 to 2 := 2
    );
    Port ( 
       dIn : in block_t; 
       dOut : out block_t; 
       key : in key_t; 
       encrypt : in STD_LOGIC;
       -- for encrypt = 1, keyExpand=1 means just keyExpansion, for encrypt = 0, keyExpand=0 means no KeyExpansion
       keysize : in mode_t; 
       keyExpand : in STD_LOGIC; 
       EnI : in STD_LOGIC;
       EnO : out STD_LOGIC;
       Clock : in STD_LOGIC;
       Resetn : in STD_LOGIC);
end entity;

architecture RTL of AEA is


subtype round_t is unsigned(3 downto 0); -- Max round number is 14 -> 4 bit
type nr_array_t is array(0 to 2) of round_t;

constant AES_NR_SEL : nr_array_t := (           -- Number of rounds
    to_integer(unsigned(KEYSIZE_128)) => to_unsigned(10, round_t'LENGTH),
    to_integer(unsigned(KEYSIZE_192)) => to_unsigned(12, round_t'LENGTH),
    to_integer(unsigned(KEYSIZE_256)) => to_unsigned(14, round_t'LENGTH)
);

signal aes_nr : round_t;


type state_t is (Idle, KeyExpansion, Rounds, PreARK);

signal prevEnI : std_logic;

signal currentRound : round_t; 
signal state : state_t;

signal roundKey : block_t;
signal keyexpInit, keyexpCalcNextKey, keyexpReverse : std_logic;

signal dataState : block_t;
signal dInSB : block_t;


signal dInARK : block_t;
signal keyARK : block_t;
signal EnARK : std_logic;


signal dOutSB, dOutMC, dOutARK : block_t;
signal subEn, prevSubEn : unsigned(2 downto 0); 

constant EN_IDX_ARK : natural := 0;
constant EN_IDX_SB : natural := 1;
constant EN_IDX_MC : natural := 2;




begin




keyExp : entity work.KeyExpansion
            generic map (CYCLES_PER_KEY => CYCLES_PER_ROUNDKEY)
            port map(userKey => key, init => keyexpInit, keysize => keysize, 
                reverse => keyexpReverse, calcNextRoundKey => keyexpCalcNextKey,
                roundKey => roundKey, 
                Clock => Clock, Resetn => Resetn);




ARK : entity work.AddRoundKey
        port map(dIn => dInARK, dOut => dOutARK, roundKey => keyARK, 
            EnI => EnARK, Clock => Clock, Resetn => Resetn);


-- SR and SB as one connected entity
SR : entity work.ShiftRows
        generic map(synchronous => false)
        port map(dIn => dataState, dOut => dInSB, encrypt => encrypt);

SB : entity work.SubBytes
        port map(dIn => dInSB, dOut => dOutSB, encrypt => encrypt,
                EnI => subEn(EN_IDX_SB), Clock => Clock, Resetn => Resetn);


MC : entity work.MixColumns
        port map(dIn => dataState, dOut => dOutMC, encrypt => encrypt,
                EnI => subEn(EN_IDX_MC), Clock => Clock, Resetn => Resetn);

    
--------------------------------
aes_nr <= AES_NR_SEL(to_integer(unsigned(keysize))); -- TODO better as register??

--------------------------------
-- KeyExpansion control 

prevEnI <= EnI when rising_edge(Clock);
 
-- TODO improve this process
process (all)
begin
    keyExpInit <= '0';
    keyExpCalcNextKey <= '0';

    keyExpReverse <= not encrypt; -- Usually: Reverse keyexpansion for decryption

    if EnI = '1' then
        -- Initialize keyexpansion at start (except for solo-decryption)
        if encrypt = '1' or keyExpand = '1' then
            keyExpInit <= '1';   
            keyExpReverse <= '0';
        else
            -- solo-decryption: Calculate next round key immediately
            keyExpCalcNextKey <= '1';
        end if;
    end if;

    -- Encryption: First cycle init, second cycle roudn key calculation
    if prevEnI = '1' and encrypt = '1' then
        keyExpCalcNextKey <= '1'; 
    end if;

    if state = KeyExpansion then
        keyExpCalcNextKey <= '1'; -- Run KeyExpansion one cycle later since initializing in the first cycle 
        keyExpReverse <= '0';
    end if;

    -- Always start calculating next key once we use the current one
    if EnARK = '1' then
        if currentRound = aes_nr then
            -- In the last round, reset back to decryption init state for next run 
            keyExpReverse <= '1';
            keyExpInit <= '1';
        else
            keyExpCalcNextKey <= '1';
        end if;
    end if;


end process;


--------------------------------
-- Substeps control 

dInARK <= dIn when state /= Rounds else dataState;
-- First step is always an ARK for both en-/decrypt
EnARK <= EnI or subEn(EN_IDX_ARK);
-- roundKey or UserKey depending on en-/decrypt and round
keyARK <= roundKey when state = Rounds or encrypt = '0' else
          key(key_t'length-1 downto key_t'length-block_t'length);


-- Do not update when EnO is set so datastate stays constant
prevSubEn <= subEn when rising_edge(Clock);

-- Assign dataState the output data of the component that was enabled in the last cycle
process (all)
begin
    -- Assign data state according to En
    case prevSubEn is 
        when "100" => 
            dataState <= dOutMC;
        when "010" => 
            dataState <= dOutSB;
        when others => 
            dataState <= dOutARK;
    end case;
end process;


dOut <= dOutARK;



-- State Machine that coordinates the rounds
process (Clock)
    variable keycalc_count : unsigned(2 downto 0);
begin
if rising_edge(Clock) then

    EnO <= '0';

    if Resetn = '0' then
        state <= Idle;
        currentRound <= (others => '-'); 
        subEn <= (others => '0'); 

    else
        case (state) is
            when Idle =>
                currentRound <= to_unsigned(1, currentRound'length);
                subEn <= (others => '0');

                -- when an encryption starts, change currentRound and isLastRound to its encryption init values
                -- otherwise, keep them on their decryption initial values
                if EnI = '1'  then
                    -- Depending on keyExpand, either do keyexpansion first or go directly to Rounds
                    if keyExpand = '1' then
                        state <= KeyExpansion;
                        keycalc_count := to_unsigned(0, keycalc_count'length);
                    else
                        state <= Rounds;
                        -- First step after initial AddRoundKey is SubBytes for both
                        -- encryption (first round) and decryption (last round, since MixColumns is skipped)
                        subEn <= (EN_IDX_SB => '1', others => '0'); 
                    end if;
                end if; 

            when KeyExpansion => 
                -- Usually, KeyExpansion and Rounds run in parallel.
                -- In state KeyExpansion, only the KeyExpansion runs. 

                assert keyExpand = '1' severity failure;

                if keycalc_count = CYCLES_PER_ROUNDKEY-1 then

                    keycalc_count := to_unsigned(0, keycalc_count'length);

                    currentRound <= currentRound + 1;

                    if currentRound = aes_nr then
                        if encrypt = '1' then
                            state <= Idle; -- For encryption, stop after last roundkey has been calculated 
                            EnO <= '1';
                        else
                            subEn <= (EN_IDX_ARK => '1', others => '0'); 
                            state <= PreARK;
                        end if;
                    end if;
                else
                    keycalc_count := keycalc_count + 1; 
                end if;
            
            when PreARK =>
                currentRound <= to_unsigned(1, currentRound'length);
                state <= Rounds; 
                -- Next step is SB since MixColumns is skipped
                subEn <= (EN_IDX_SB => '1', others => '0'); 

            -- RoundState: AEA is executing Rounds         
            when Rounds =>

                if encrypt = '1' then
                    subEn <= subEn rol 1; -- Encryption: Run steps in loop in order
                else
                    subEn <= subEn ror 1; -- Decryption: Run steps in loop in reverse order
                end if;

                -- In last round of encryption: Skip MixColumns, go straight from SB to ARK
                if currentRound = aes_nr and encrypt = '1' and subEn(EN_IDX_SB) = '1' then
                    subEn <= (EN_IDX_ARK => '1', others => '0'); 
                end if;

                -- AddRoundKey is always the last step in a round for both en-/decryption
                if subEn(EN_IDX_ARK) = '1' then 

                    -- Update round number, or quit in last round
                    if currentRound = aes_nr then
                        -- Last round finishes in next cycle

                        state <= Idle;
                        EnO <= '1';
                    else
                        currentRound <= currentRound + 1;
                    end if;
                end if;
        end case;
    end if;
end if;
end process;

end architecture;
