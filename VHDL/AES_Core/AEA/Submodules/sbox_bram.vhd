library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.common.ALL;
use work.sbox_definition.ALL;

entity sbox_bram is
generic (
    DATA    : integer := 8;
    ADDR    : integer := 9
);
port (
    -- Port A
    clka   : in std_logic;
    ena    : in std_logic;
    addra  : in std_logic_vector(ADDR-1 downto 0);
    douta  : out std_logic_vector(DATA-1 downto 0)
);
end sbox_bram;

architecture rtl of sbox_bram is

   type mem_type is array (511 downto 0) of std_logic_vector(7 downto 0);

    impure function initSBox return mem_type is
    
    variable mem_init : mem_type;
    begin
        for i in 0 to 255 loop
            mem_init(i) := sbox_decrypt(i);
            mem_init(i+256) := sbox_encrypt(i);
        end loop;
        return mem_init;
    end function;   


   signal mem : mem_type := initSBox;
begin

-- Port A
process(clka)
begin
    if(clka'event and clka='1') then
        if ena = '1' then
            douta <= mem(conv_integer(addra));
        end if;
    end if;
end process;

end rtl;