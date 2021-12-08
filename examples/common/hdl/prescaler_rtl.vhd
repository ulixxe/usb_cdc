library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity prescaler is
  port (
    clk_i       : in  std_logic;
    rstn_i      : in  std_logic;
    clk_div16_o : out std_logic;
    clk_div8_o  : out std_logic;
    clk_div4_o  : out std_logic;
    clk_div2_o  : out std_logic);
end entity prescaler;

architecture rtl of prescaler is
  signal prescaler_cnt : unsigned(3 downto 0);
begin

  p_prescaler : process (clk_i, rstn_i) is
  begin
    if rstn_i = '0' then
      prescaler_cnt <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      prescaler_cnt <= prescaler_cnt + 1;
    end if;
  end process p_prescaler;

  clk_div16_o <= prescaler_cnt(3);
  clk_div8_o  <= prescaler_cnt(2);
  clk_div4_o  <= prescaler_cnt(1);
  clk_div2_o  <= prescaler_cnt(0);

end architecture rtl;
