----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2022 01:09:13
-- Design Name: 
-- Module Name: AES_Core - Behavioral
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
use IEEE.std_logic_1164.ALL;
use work.common.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity AES_Mode_ECBCBCCTR is
    generic (
        ADDR_IV : integer
        );
    Port (
           IV : in block_t;
           dIn : in block_t;
           dOut : out block_t;
           EnI : in std_logic;
           EnO : out std_logic;
            -- signals to control the AEA unit
           EnIAEA : out std_logic;
           EnOAEA : in std_logic;
           dInAEA : out block_t; 
           dOutAEA : in block_t;
           -- signals to write to register set
           WrEn   : out STD_LOGIC;
           WrAddr : out STD_LOGIC_VECTOR(ADDR_REGISTER_BITS-1 downto 0);
           WrData : out block_t;
           mode : in mode_t;
           chaining_mode : in mode_t;
           Clock : in std_logic;
           Resetn : in std_logic
           );
end entity;

architecture RTL of AES_Mode_ECBCBCCTR is

component AddRoundKey is
    Port ( din : in block_t;
           dout : out block_t;
           roundKey : in block_t;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;


function incrementIV(IV_val : block_t) return std_logic_vector is
begin
    return IV_val(AES_BLOCK_SIZE-1 downto 32) & std_logic_vector(unsigned(IV_val(31 downto 0)) + to_unsigned(1,32));
end function;


-- signal definitions
signal dInXOR1, dInXOR2, dOutXOR: block_t;
signal EnIXOR, EnOXOR, WrEnSignal : std_logic;
signal encrypt : std_logic;

begin

encrypt <= not mode(1);

-- Use an AddRoundKey unit as XOR
xorUnit : AddRoundKey port map(dInXOR1, dOutXOR, dInXOR2, EnIXOR, EnOXOR, Clock, Resetn);

-- Input of AEA differs for each chaining mode
dInAEA <=   dOutXOR when chaining_mode = CHAINING_MODE_CBC and encrypt = '1' else
            IV when chaining_mode = CHAINING_MODE_CTR  else
            dIn;

-- First Input into XOR is always plaintext, except for decryption in CBC mode
dInXOR1 <= dIn when encrypt = '1' or chaining_mode /= CHAINING_MODE_CBC else
           dOutAEA;
            
-- Second Input of XOR depends on the mode
with chaining_mode select
    dInXOR2 <=  IV when CHAINING_MODE_CBC,
                dOutAEA when others; -- CHAINING_MODE_CTR; as XOR isn't used for mode ECB, input doesnt matter then
            

dOut <=     dOutXOR when chaining_mode = CHAINING_MODE_CTR or (chaining_mode = CHAINING_MODE_CBC and encrypt = '0') else
            dOutAEA; 


-- For CBC mode, during encryption the input of the AEA is the output of XOR
EnIAEA <=   EnOXOR when chaining_mode = CHAINING_MODE_CBC and encrypt = '1' else
            EnI;
          
EnIXOR <=   EnI when chaining_mode = CHAINING_MODE_CBC and encrypt = '1' else
            EnOAEA when (chaining_mode = CHAINING_MODE_CBC and encrypt = '0') or chaining_mode = CHAINING_MODE_CTR else
            '0'; -- XOR unit is unused in other modes

            
EnO <=  EnOAEA when chaining_mode = CHAINING_MODE_ECB else
        WrEnSignal when (chaining_mode = CHAINING_MODE_CBC and encrypt = '1') else  -- wait until IV has been written until EnO is set
        EnOXOR;  -- CTR mode, CBC with decryption





-- update IV
WrAddr <= std_logic_vector(to_unsigned(ADDR_IV, WrAddr'LENGTH));
WrEn <= WrEnSignal;

process(Clock)
begin
if rising_edge(Clock) then 
    WrEnSignal <= '0';
    -- For chaining mode CBC
    if chaining_mode = CHAINING_MODE_CBC then
        -- When encrypting, wait until the AEA has finished
        if encrypt = '1' and EnOAEA = '1' then
            WrData <= dOutAEA;
            WrEnSignal <= '1';
        -- For decrypting, we can write back the new IV immediately as it is the input (ciphertext)
        elsif encrypt = '0' and EnI = '1' then
            WrData <= dIn;
            WrEnSignal <= '1';
        end if;
    -- For chaining mode CTR, write the incremented IV back immediately
    elsif EnI = '1' and chaining_mode = CHAINING_MODE_CTR then
        WrEnSignal <= '1';
        WrData <= incrementIV(IV);
    end if;
end if;
end process;


end architecture;
