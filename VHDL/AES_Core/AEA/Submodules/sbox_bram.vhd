library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.common.ALL;
use work.sbox_definition.ALL;

entity sbox_bram is
generic (
    DATA    : integer := 8;
    ADDR    : integer := 8;
    ENCRYPT : boolean := true
);
port (
    -- Port A
    clka   : in std_logic;
    wea    : in std_logic;
    ena    : in std_logic;
    addra  : in std_logic_vector(ADDR-1 downto 0);
    dina   : in std_logic_vector(DATA-1 downto 0);
    douta  : out std_logic_vector(DATA-1 downto 0)
);
end sbox_bram;

architecture rtl of sbox_bram is

    impure function initSBox return SBOX is
    begin
        if ENCRYPT then
            return sbox_encrypt;
        else
            return sbox_decrypt;
        end if;
    end function;   

   type mem_type is array (255 downto 0) of std_logic_vector(31 downto 0);
   signal mem : SBOX := initSBox;
begin

-- Port A
process(clka)
begin
    if(clka'event and clka='1') then
        -- TODO can remove write port, SBOX can be read only
        if(wea='1') then
            mem(conv_integer(addra)) <= dina;
            report "Bram write-a " & integer'image(to_integer(unsigned(dina))) & " at " & integer'image(to_integer(unsigned(addra)));
        end if;
        if ena = '1' then
            douta <= mem(conv_integer(addra));
        end if;
    end if;
end process;

end rtl;