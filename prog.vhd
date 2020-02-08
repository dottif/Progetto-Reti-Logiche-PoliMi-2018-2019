library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity project_reti_logiche is
	port (
		i_clk     : in std_logic;
		i_start   : in std_logic;
		i_rst     : in std_logic;
		i_data    : in std_logic_vector(7 downto 0);
		o_address : out std_logic_vector(15 downto 0);
		o_done    : out std_logic;
		o_en      : out std_logic;
		o_we      : out std_logic;
		o_data    : out std_logic_vector (7 downto 0)
	);
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
	type state_type is (START, WAIT_CLK, DONE_LOW, DONE_HIGH, READ_DATA, REQUEST_YP, REQUEST_BITMASK, WAIT_X, READ_X_PREP_Y, WAIT_Y, READ_Y, REQUEST_CENTROIDS, CALCULATE_DISTANCE, CALCULATE_MIN, WRITE_RESULT);
	signal PS, NS                                                   : state_type;
	signal bitmask, bitmask_next, output_mask_next, output_mask     : std_logic_vector(7 downto 0)  := (others => '0');
	signal xp, yp, xt, xt_next, yt, yt_next, xp_next, yp_next       : integer range 0 to 255        := 0;
	signal min_distance, min_distance_next, distance, distance_next : integer range 0 to 511        := 511;
	signal current_address, next_address                            : std_logic_vector(15 downto 0) := (others => '0');
begin
	sync_proc : process (i_clk, NS, i_rst)
	begin
		if (i_rst = '1') then
			PS           <= START;
			output_mask  <= (7 downto 0 => '0');
			min_distance <= 511;
		elsif (rising_edge(i_clk)) then
			PS              <= NS;
			bitmask         <= bitmask_next;
			min_distance    <= min_distance_next;
			current_address <= next_address;
			output_mask     <= output_mask_next;
			xp              <= xp_next;
			yp              <= yp_next;
			xt              <= xt_next;
			yt              <= yt_next;
			distance        <= distance_next;
		end if;
	end process sync_proc;

	comb_proc : process (i_start, i_data, PS, bitmask, output_mask, xp, yp, xt, yt, min_distance, current_address, distance)
	begin
		--default values
		o_en              <= '1';
		o_we              <= '0';
		o_done            <= '0';
		o_data            <= output_mask;
		o_address         <= current_address;
		NS                <= PS;
		bitmask_next      <= bitmask;
		min_distance_next <= min_distance;
		next_address      <= current_address;
		output_mask_next  <= output_mask;
		xp_next           <= xp;
		yp_next           <= yp;
		xt_next           <= xt;
		yt_next           <= yt;
		distance_next     <= distance;

		case PS is
			when START =>
				if (i_start = '1') then
					next_address <= "0000000000000000"; --bitmask address
					o_address    <= "0000000000000000";
					NS           <= WAIT_CLK;
				else o_done  <= '1';
				end if;

			when WAIT_CLK =>
				NS <= READ_DATA;

			when READ_DATA =>
				if (current_address = "0000000000010001") then
					xp_next      <= to_integer(unsigned(i_data)); --read xp
					next_address <= "0000000000010010";           --y address
					o_address    <= "0000000000010010";
					NS           <= WAIT_CLK;
				elsif (current_address = "0000000000010010") then
					yp_next <= to_integer(unsigned(i_data)); --read yp
					NS      <= REQUEST_CENTROIDS;
				elsif (current_address = "0000000000000000") then
					bitmask_next <= i_data;             --read input mask
					next_address <= "0000000000010001"; --x address
					o_address    <= "0000000000010001";
					NS           <= WAIT_CLK;
				end if;

			when REQUEST_CENTROIDS => -- if bitmask[i] = 1 -> read centroid i coordinates
				NS <= WAIT_X;
				if (bitmask(0) = '1') then
					next_address <= "0000000000000001";
					o_address    <= "0000000000000001";
					bitmask_next <= bitmask(7 downto 1) & '0';
				elsif (bitmask(1) = '1') then
					next_address <= "0000000000000011";
					o_address    <= "0000000000000011";
					bitmask_next <= bitmask(7 downto 2) & '0' & bitmask(0);
				elsif (bitmask(2) = '1') then
					next_address <= "0000000000000101";
					o_address    <= "0000000000000101";
					bitmask_next <= bitmask(7 downto 3) & '0' & bitmask(1 downto 0);
				elsif (bitmask(3) = '1') then
					next_address <= "0000000000000111";
					o_address    <= "0000000000000111";
					bitmask_next <= bitmask(7 downto 4) & '0' & bitmask(2 downto 0);
				elsif (bitmask(4) = '1') then
					next_address <= "0000000000001001";
					o_address    <= "0000000000001001";
					bitmask_next <= bitmask(7 downto 5) & '0' & bitmask(3 downto 0);
				elsif (bitmask(5) = '1') then
					next_address <= "0000000000001011";
					o_address    <= "0000000000001011";
					bitmask_next <= bitmask(7 downto 6) & '0' & bitmask(4 downto 0);
				elsif (bitmask(6) = '1') then
					next_address <= "0000000000001101";
					o_address    <= "0000000000001101";
					bitmask_next <= bitmask(7) & '0' & bitmask(5 downto 0);
				elsif (bitmask(7) = '1') then
					next_address <= "0000000000001111";
					o_address    <= "0000000000001111";
					bitmask_next <= '0' & bitmask(6 downto 0);
				else o_we    <= '1';
					next_address <= "0000000000010011"; --19
					o_address    <= "0000000000010011"; --19
					NS           <= WRITE_RESULT;
				end if;

			when WAIT_X =>
				NS <= READ_X_PREP_Y;

			when READ_X_PREP_Y =>
				xt_next      <= to_integer(unsigned(i_data));         --read tx
				o_address    <= current_address + "0000000000000001"; --ty address
				next_address <= current_address + "0000000000000001";
				NS           <= WAIT_Y;

			when WAIT_Y =>
				NS <= READ_Y;

			when READ_Y =>
				yt_next <= to_integer(unsigned(i_data)); --read ty
				NS      <= CALCULATE_DISTANCE;

			when CALCULATE_DISTANCE =>
				distance_next <= abs(xp - xt) + abs(yp - yt); --calculate manhattan distance
				NS            <= CALCULATE_MIN;

			when CALCULATE_MIN => --check if this distance is the min
				if (distance < min_distance) then
					output_mask_next                                                <= (others => '0');
					output_mask_next((to_integer(unsigned(current_address))/2) - 1) <= '1';
					min_distance_next                                               <= distance;
				elsif (distance = min_distance) then
					output_mask_next((to_integer(unsigned(current_address))/2) - 1) <= '1';
				end if;
				NS <= REQUEST_CENTROIDS;

			when WRITE_RESULT =>
				NS <= DONE_HIGH;

			when DONE_HIGH =>
				o_en   <= '0';
				o_done <= '1';
				NS     <= DONE_LOW;

			when DONE_LOW =>
				NS <= START;

			when others =>
				NS <= START;

		end case;
	end process comb_proc;
end Behavioral;