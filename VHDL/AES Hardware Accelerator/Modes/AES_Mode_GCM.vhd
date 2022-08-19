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


entity AES_Mode_GCM is
    Port (
           IV : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           newIV : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in std_logic;
           EnO : out std_logic;
           encrypt : in std_logic;
           GCMPhase : in std_logic_vector(1 downto 0);
           -- signals to control the AEA unit
           EnIAEA : out std_logic;
           EnOAEA : in std_logic;
           dInAEA : out std_logic_vector (KEY_SIZE-1 downto 0);
           dOutAEA : in std_logic_vector (KEY_SIZE-1 downto 0);
           Clock : in std_logic;
           Resetn : in std_logic
           );
end AES_Mode_GCM;



architecture Behavioral of AES_Mode_GCM is

component AddRoundKey is
    Port ( din : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dout : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;


function incrementIV(IV : std_logic_vector(KEY_SIZE-1 downto 0)) return std_logic_vector is
begin
    return IV(KEY_SIZE-1 downto 32) & std_logic_vector(unsigned(IV(31 downto 0)) + to_unsigned(1,32));
end function;


constant ZERO : std_logic_vector(KEY_SIZE-2 downto 0) := (others => '0');
constant POLYGF : std_logic_vector(KEY_SIZE downto 0) := '1' & x"00000000000000000000000010000111";

function mulGF(val : std_logic_vector(KEY_SIZE-1 downto 0); prod : std_logic_vector(KEY_SIZE-1 downto 0)) return std_logic_vector is
    variable c : std_logic_vector(KEY_SIZE*2-2 downto 0); -- val has 128 bits, which can be shifted 127 times
begin
    c := (others => '0');
    -- Polynomial Multiplication
    for i in 0 to KEY_SIZE-1 loop
        if prod(i) = '1' then
            c := c xor (ZERO(KEY_SIZE-2-i downto 0) & val & ZERO(i-1 downto 0)); -- Shift the value by attaching the right amount of zeros
        end if;
    end loop;
    -- Polynomial Division
    for i in KEY_SIZE*2-2 downto KEY_SIZE+1 loop
        -- if bit c(i) is set, substract the shifted polynomial
        if c(i) = '1' then
            c := c xor (ZERO(9-i downto 0 ) & POLYGF & ZERO(i-9 downto 0));
        end if;
    end loop;
    return c(KEY_SIZE-1 downto 0);
end function;

-- signal definitions
signal  dInXOR1, dInXOR2, dOutXOR : std_logic_vector(KEY_SIZE-1 downto 0);
signal  EnIXOR, EnOXOR : std_logic;



begin
-- Use an AddRoundKey unit as XOR
xorUnit : AddRoundKey port map(dInXOR1, dOutXOR, dInXOR2, EnIXOR, EnOXOR, Clock, Resetn);




dInAEA <=   IV;

-- First Input into XOR is always plaintext, except for decryption in CBC mode
dInXOR1 <= dOutAEA;
            
-- Second Input of XOR depends on the mode
    dInXOR2 <= dOutAEA;

dOut <=     dOutXOR;


-- For CBC mode, during encryption the input of the AEA is the output of XOR, except in KeyExpansion mode
EnIAEA <=   EnI;
          
-- TODO this can be simplified by setting the EnIXOR signal anyway and just ignoring the output EnO. Should I do it?
EnIXOR <=  EnOAEA;
            

EnO <=  EnOXOR;
 
-- update IV
newIV <= incrementIV(IV);

end Behavioral;
