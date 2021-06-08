library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity prescaler is
  port (
    clk_16mhz_i : in  std_logic;
    rstn_i      : in  std_logic;
    clk_1mhz_o  : out std_logic;
    clk_2mhz_o  : out std_logic;
    clk_4mhz_o  : out std_logic;
    clk_8mhz_o  : out std_logic);
end entity prescaler;

architecture rtl of prescaler is
  signal prescaler_cnt : unsigned(3 downto 0);
begin

  p_prescaler : process (clk_16mhz_i, rstn_i) is
  begin
    if rstn_i = '0' then
      prescaler_cnt <= (others => '0');
    elsif clk_16mhz_i'event and clk_16mhz_i = '1' then
      prescaler_cnt <= prescaler_cnt + 1;
    end if;
  end process p_prescaler;

  clk_1mhz_o <= prescaler_cnt(3);
  clk_2mhz_o <= prescaler_cnt(2);
  clk_4mhz_o <= prescaler_cnt(1);
  clk_8mhz_o <= prescaler_cnt(0);

end architecture rtl;
