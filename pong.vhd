library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity pong is
    port(
        clk:     in std_logic;
        btn_rst: in std_logic; -- reset button
        btn_1:   in std_logic; -- Player 1 Button Up
		btn_2:   in std_logic; -- Player 1 Button Down
		btn_3:   in std_logic; -- Player 2 Button Up
		btn_4:   in std_logic; -- Player 2 Button Down

        tx:      out std_logic;
        red:     out std_logic_vector(1 downto 0);
        green:   out std_logic_vector(1 downto 0);
        blue:    out std_logic_vector(1 downto 0);
        hsync:   out std_logic;
        vsync:   out std_logic
    );
end pong;

architecture arch of pong is
    -- VGA signals
    signal clkfb:   std_logic;
    signal clkfx:   std_logic;
    signal hcount:  unsigned(9 downto 0);
    signal vcount:  unsigned(9 downto 0);
    signal blank:   std_logic;
    signal frame:   std_logic;
    signal obj_red: std_logic_vector(1 downto 0);
    signal obj_grn: std_logic_vector(1 downto 0);
    signal obj_blu: std_logic_vector(1 downto 0);
    
    -- Game states
    type state_type is (PLAYING, GAME_OVER);
    signal game_state: state_type := PLAYING;
    
    -- Signals for button debounce
    signal cnt1: unsigned(6 downto 0);
    signal cnt2: unsigned(6 downto 0);
    signal cnt3: unsigned(6 downto 0);
    signal cnt4: unsigned(6 downto 0);
    
    signal counter_rst, counter_1, counter_2, counter_3, counter_4: unsigned(19 downto 0) := (others => '0'); -- 20-bit saturation counters
    signal state_rst, state_1, state_2, state_3, state_4:           std_logic := '0';
    signal state_1_d1, state_2_d1, state_3_d1, state_4_d1:          std_logic := '0';
    
    -- Metastability registers for button debounce
    signal btn_rst_meta1, btn_rst_meta2: std_logic := '0';
    signal btn_1_meta1, btn_1_meta2:     std_logic := '0';
    signal btn_2_meta1, btn_2_meta2:     std_logic := '0';
    signal btn_3_meta1, btn_3_meta2:     std_logic := '0';
    signal btn_4_meta1, btn_4_meta2:     std_logic := '0';
    
    -- Ball properties (640 * 480 display)
    constant BALL_SIZE: integer := 10; -- Ball square side
    signal ball_x:      integer range 0 to 639 := 100; -- Initial X position
    signal ball_y:      integer range 0 to 479 := 100; -- Initial Y position
    signal ball_dx:     integer := 2; -- Initial X direction
    signal ball_dy:     integer := 2; -- Initial Y direction
    
    -- Paddle properties
    constant PADDLE_WIDTH:      integer := 10; -- Paddle width
    constant PADDLE_HEIGHT:     integer := 60; -- Paddle height
    constant PADDLE_SPEED:      integer := 10; -- Paddle speed
    constant PLAYER1_PADDLE_X : integer := 30; -- Player 1 (left) paddle x position
    constant PLAYER2_PADDLE_X : integer := 610; -- Player 2 (right) paddle x position
    signal p1_paddle_y :        integer range 0 to 480 - PADDLE_HEIGHT := 210; -- Player 1 (left) paddle y position
    signal p2_paddle_y :        integer range 0 to 480 - PADDLE_HEIGHT := 210; -- Player 2 (right) paddle y position
    
    -- Paddle movement speed
    signal v_paddle1: integer := 0; -- Velocity of Player 1 paddle (-: up, +: down, 0: stationary)
    signal v_paddle2: integer := 0; -- Velocity of Player 2 paddle (-: up, +: down, 0: stationary)
    
    -- Ball reflection scaling
    constant K_PADDLE_SPEED: integer := 7; -- Scaling factor for paddle speed effect
    constant M_X_REL:        integer := 1; -- Scaling factor for impact location
    
    -- Score box properties
    constant SCORE_BOX_WIDTH:  integer := 100; -- Score box width
    constant SCORE_BOX_HEIGHT: integer := 20; -- Score box height
    constant P1_SCORE_X:       integer := 20; -- Player 1 (left) score box x position
    constant P1_SCORE_Y:       integer := 10; -- Player 1 (left) score box y position
    constant P2_SCORE_X :      integer := 520; -- Player 2 (right) score box x position
    constant P2_SCORE_Y :      integer := 10; -- Player 2 (right) score box y position
    
    -- Score counters
    signal p1_score : integer range 0 to 10 := 0; -- Player 1 Score
    signal p2_score : integer range 0 to 10 := 0; -- Player 2 Score

    -- Rendering signals
    signal obj_red_i : std_logic_vector(1 downto 0) := "00";
    signal obj_grn_i : std_logic_vector(1 downto 0) := "00";
    signal obj_blu_i : std_logic_vector(1 downto 0) := "00";
    
begin
   tx <= '1';
	------------------------------------------------------------------
	-- Clock management tile (adapted from VGA mini lab)
	--
	-- Input clock: 12 MHz
	-- Output clock: 25.2 MHz
	--
	-- CLKFBOUT_MULT_F: 50.875
	-- CLKOUT0_DIVIDE_F: 24.250
	-- DIVCLK_DIVIDE: 1
	------------------------------------------------------------------
	cmt: MMCME2_BASE generic map (
		-- Jitter programming (OPTIMIZED, HIGH, LOW)
		BANDWIDTH=>"OPTIMIZED",
		-- Multiply value for all CLKOUT (2.000-64.000).
		CLKFBOUT_MULT_F=>50.875,
		-- Phase offset in degrees of CLKFB (-360.000-360.000).
		CLKFBOUT_PHASE=>0.0,
		-- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
		CLKIN1_PERIOD=>83.333,
		-- Divide amount for each CLKOUT (1-128)
		CLKOUT1_DIVIDE=>1,
		CLKOUT2_DIVIDE=>1,
		CLKOUT3_DIVIDE=>1,
		CLKOUT4_DIVIDE=>1,
		CLKOUT5_DIVIDE=>1,
		CLKOUT6_DIVIDE=>1,
		-- Divide amount for CLKOUT0 (1.000-128.000):
		CLKOUT0_DIVIDE_F=>24.250,
		-- Duty cycle for each CLKOUT (0.01-0.99):
		CLKOUT0_DUTY_CYCLE=>0.5,
		CLKOUT1_DUTY_CYCLE=>0.5,
		CLKOUT2_DUTY_CYCLE=>0.5,
		CLKOUT3_DUTY_CYCLE=>0.5,
		CLKOUT4_DUTY_CYCLE=>0.5,
		CLKOUT5_DUTY_CYCLE=>0.5,
		CLKOUT6_DUTY_CYCLE=>0.5,
		-- Phase offset for each CLKOUT (-360.000-360.000):
		CLKOUT0_PHASE=>0.0,
		CLKOUT1_PHASE=>0.0,
		CLKOUT2_PHASE=>0.0,
		CLKOUT3_PHASE=>0.0,
		CLKOUT4_PHASE=>0.0,
		CLKOUT5_PHASE=>0.0,
		CLKOUT6_PHASE=>0.0,
		-- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
		CLKOUT4_CASCADE=>FALSE,
		-- Master division value (1-106)
		DIVCLK_DIVIDE=>1,
		-- Reference input jitter in UI (0.000-0.999).
		REF_JITTER1=>0.0,
		-- Delays DONE until MMCM is locked (FALSE, TRUE)
		STARTUP_WAIT=>FALSE
	) port map (
		-- User Configurable Clock Outputs:
		CLKOUT0=>clkfx,  -- 1-bit output: CLKOUT0
		CLKOUT0B=>open,  -- 1-bit output: Inverted CLKOUT0
		CLKOUT1=>open,   -- 1-bit output: CLKOUT1
		CLKOUT1B=>open,  -- 1-bit output: Inverted CLKOUT1
		CLKOUT2=>open,   -- 1-bit output: CLKOUT2
		CLKOUT2B=>open,  -- 1-bit output: Inverted CLKOUT2
		CLKOUT3=>open,   -- 1-bit output: CLKOUT3
		CLKOUT3B=>open,  -- 1-bit output: Inverted CLKOUT3
		CLKOUT4=>open,   -- 1-bit output: CLKOUT4
		CLKOUT5=>open,   -- 1-bit output: CLKOUT5
		CLKOUT6=>open,   -- 1-bit output: CLKOUT6
		-- Clock Feedback Output Ports:
		CLKFBOUT=>clkfb,-- 1-bit output: Feedback clock
		CLKFBOUTB=>open, -- 1-bit output: Inverted CLKFBOUT
		-- MMCM Status Ports:
		LOCKED=>open,    -- 1-bit output: LOCK
		-- Clock Input:
		CLKIN1=>clk,   -- 1-bit input: Clock
		-- MMCM Control Ports:
		PWRDWN=>'0',     -- 1-bit input: Power-down
		RST=>'0',        -- 1-bit input: Reset
		-- Clock Feedback Input Port:
		CLKFBIN=>clkfb  -- 1-bit input: Feedback clock
	);
    
	------------------------------------------------------------------
	-- VGA display counters (adapted from VGA mini lab)
	--
	-- Pixel clock: 25.175 MHz (actual: 25.2 MHz)
	-- Horizontal count (active low sync):
	--     0 to 639: Active video
	--     640 to 799: Horizontal blank
	--     656 to 751: Horizontal sync (active low)
	-- Vertical count (active low sync):
	--     0 to 479: Active video
	--     480 to 524: Vertical blank
	--     490 to 491: Vertical sync (active low)
	------------------------------------------------------------------
	process(clkfx)
	begin
		if rising_edge(clkfx) then
			-- Pixel position counters
			if (hcount>=to_unsigned(799,10)) then
				hcount<=(others=>'0');
				if (vcount>=to_unsigned(524,10)) then
					vcount<=(others=>'0');
				else
					vcount<=vcount+1;
				end if;
			else
				hcount<=hcount+1;
			end if;
			-- Sync, blank and frame
			if (hcount>=to_unsigned(656,10)) and
				(hcount<=to_unsigned(751,10)) then
				hsync<='0';
			else
				hsync<='1';
			end if;
			if (vcount>=to_unsigned(490,10)) and
				(vcount<=to_unsigned(491,10)) then
				vsync<='0';
			else
				vsync<='1';
			end if;
			if (hcount>=to_unsigned(640,10)) or
				(vcount>=to_unsigned(480,10)) then
				blank<='1';
			else
				blank<='0';
			end if;
			if (hcount=to_unsigned(640,10)) and
				(vcount=to_unsigned(479,10)) then
				frame<='1';
			else
				frame<='0';
			end if;
		end if;
    end process;
	
	------------------------------------------------------------------
    -- Button Debounce
    ------------------------------------------------------------------
    process(clkfx)
    begin
        if rising_edge(clkfx) then
        -- Metastability shift register for btn_rst
			btn_rst_meta1 <= btn_rst;
			btn_rst_meta2 <= btn_rst_meta1;
			
        -- Metastability shift register for btn_1
			btn_1_meta1 <= btn_1;
			btn_1_meta2 <= btn_1_meta1;
			
		-- Metastability shift register for btn_2
			btn_2_meta1 <= btn_2;
			btn_2_meta2 <= btn_2_meta1;
			
		-- Metastability shift register for btn_3
			btn_3_meta1 <= btn_3;
			btn_3_meta2 <= btn_3_meta1;
			
		-- Metastability shift register for btn_4
			btn_4_meta1 <= btn_4;
			btn_4_meta2 <= btn_4_meta1;
			
		-- Debounce logic for btn_rst
			if (btn_rst_meta2 = '1') then
				if (counter_rst /= b"11111111111111111111") then
					counter_rst <= counter_rst + 1; -- Increment counter
				else
					state_rst <= '1'; -- Button press detected
				end if;
			else
				if (counter_rst /= b"00000000000000000000") then
					counter_rst <= counter_rst - 1; -- Decrement counter
				else
					state_rst <= '0'; -- Button release detected
				end if;
			end if;
			
			-- Debounce logic for btn_1
			if (btn_1_meta2 = '1') then
				if (counter_1 /= b"11111111111111111111") then
					counter_1 <= counter_1 + 1; -- Increment counter
				else
					state_1 <= '0'; -- Button press detected
				end if;
			else
				if (counter_1 /= b"00000000000000000000") then
					counter_1 <= counter_1 - 1; -- Decrement counter
				else
					state_1 <= '1'; -- Button release detected
				end if;
			end if;
			
			-- Debounce logic for btn_2
			if (btn_2_meta2 = '1') then
				if (counter_2 /= b"11111111111111111111") then
					counter_2 <= counter_2 + 1; -- Increment counter
				else
					state_2 <= '0'; -- Button press detected
				end if;
			else
				if (counter_2 /= b"00000000000000000000") then
					counter_2 <= counter_2 - 1; -- Decrement counter
				else
					state_2 <= '1'; -- Button release detected
				end if;
			end if;
			
			-- Debounce logic for btn_3
			if (btn_3_meta2 = '1') then
				if (counter_3 /= b"11111111111111111111") then
					counter_3 <= counter_3 + 1; -- Increment counter
				else
					state_3 <= '0'; -- Button press detected
				end if;
			else
				if (counter_3 /= b"00000000000000000000") then
					counter_3 <= counter_3 - 1; -- Decrement counter
				else
					state_3 <= '1'; -- Button release detected
				end if;
			end if;
			
			-- Debounce logic for btn_4
			if (btn_4_meta2 = '1') then
				if (counter_4 /= b"11111111111111111111") then
					counter_4 <= counter_4 + 1; -- Increment counter
				else
					state_4 <= '0'; -- Button press detected
				end if;
			else
				if (counter_4 /= b"00000000000000000000") then
					counter_4 <= counter_4 - 1; -- Decrement counter
				else
					state_4 <= '1'; -- Button release detected
				end if;
			end if;
		end if;
	end process;
	
    ------------------------------------------------------------------
    -- Paddle Movement
    ------------------------------------------------------------------
    process(clkfx)
    begin
        if rising_edge(clkfx) then
            if frame = '1' then  -- Update paddles once per frame
                if game_state = PLAYING then
                    -- Player 1 Paddle Movement
                    if state_1 = '0' and state_2 = '1' then -- Down button pressed
                        if p1_paddle_y < (480 - PADDLE_HEIGHT) then
                            p1_paddle_y <= p1_paddle_y + PADDLE_SPEED;
                            v_paddle1 <= 1; -- Moving Down
                        end if;
                    elsif state_1 = '1' and state_2 = '0' then -- Up button pressed
                        if p1_paddle_y > 30 then
                            p1_paddle_y <= p1_paddle_y - PADDLE_SPEED;
                            v_paddle1 <= -1; -- Moving Up
                        end if;
                    else -- If no button press / both buttons are pressed
                        v_paddle1 <= 0; -- Do not move the paddle
                    end if;
                   
                    -- Player 2 Paddle Movement
                    if state_3 = '0' and state_4 = '1' then -- Down button pressed
                        if p2_paddle_y < (480 - PADDLE_HEIGHT) then
                            p2_paddle_y <= p2_paddle_y + PADDLE_SPEED;
                            v_paddle2 <= 1; -- Moving Down
                        end if;
                    elsif state_3 = '1' and state_4 = '0' then -- Up button pressed
                        if p2_paddle_y > 30 then
                            p2_paddle_y <= p2_paddle_y - PADDLE_SPEED;
                            v_paddle2 <= -1; -- Moving Up
                        end if;
                    else -- If no button press / both buttons are pressed
                        v_paddle2 <= 0; -- Do not move the paddle
                    end if;
                else -- Game over: reset the paddle positions
                    p1_paddle_y <= 210;
                    p2_paddle_y <= 210;
                end if;
            end if;
        end if;
    end process;
    
    ------------------------------------------------------------------
    -- Update Ball Position and Direction Update
    ------------------------------------------------------------------
    process(clkfx)
        variable next_ball_x : integer;
        variable next_ball_y : integer;
        variable next_ball_dx : integer;
        variable next_ball_dy : integer;
        variable x_rel : integer;
    begin
        if rising_edge(clkfx) then
            if frame = '1' and game_state = PLAYING then
                -- Initialize next position and direction variables
                next_ball_x := ball_x + ball_dx;
                next_ball_y := ball_y + ball_dy;
                next_ball_dx := ball_dx;
                next_ball_dy := ball_dy;
                
                -- Collision detection with top wall
                if (next_ball_y <= 30) then
                    next_ball_dy := -ball_dy; -- Reverse Y direction
                end if;
                
                -- Collision detection with bottom wall
                if (next_ball_y + BALL_SIZE >= 480) then
                    next_ball_dy := -ball_dy; -- Reverse Y direction
                end if;
                
                -- Collision detection with Player 1 Paddle
                if ((next_ball_x <= PLAYER1_PADDLE_X + PADDLE_WIDTH) and
                    (next_ball_x >= PLAYER1_PADDLE_X) and
                    (next_ball_y + BALL_SIZE >= p1_paddle_y) and
                    (next_ball_y <= p1_paddle_y + PADDLE_HEIGHT)) then
                    
                    -- Reverse X direction and increment speed
                    next_ball_dx := -(ball_dx + 1);
                    
                    -- Calculate relative impact position
                    x_rel := (next_ball_y + (BALL_SIZE / 2)) - (p1_paddle_y + (PADDLE_HEIGHT / 2));
                    
                    -- Adjust Y direction based on impact location and paddle speed
                    next_ball_dy := next_ball_dy + (M_X_REL * x_rel)/30 + (K_PADDLE_SPEED * v_paddle1);
                    
                    -- Clamp Y direction to prevent excessive angles
                    if next_ball_dy > 5 then
                        next_ball_dy := 5;
                    elsif next_ball_dy < -5 then
                        next_ball_dy := -5;
                    end if;
                    
                    -- Clamp X direction to prevent excessive speeds
                    if next_ball_dx > 3 then
                        next_ball_dx := 3;
                    elsif next_ball_dx < -3 then
                        next_ball_dx := -3;
                    end if;
                    
                    -- Clamp X position to prevent sticking into the paddle
                    next_ball_x := PLAYER1_PADDLE_X + PADDLE_WIDTH;
                end if;
                
                -- Collision detection with Player 2 Paddle
                if (next_ball_x + BALL_SIZE >= PLAYER2_PADDLE_X) and
                    (next_ball_x + BALL_SIZE <= PLAYER2_PADDLE_X + PADDLE_WIDTH) and
                    (next_ball_y + BALL_SIZE >= p2_paddle_y) and
                    (next_ball_y <= p2_paddle_y + PADDLE_HEIGHT) then
                       
                    -- Reverse X direction
                    next_ball_dx := -(ball_dx + 1);
                    
                    -- Calculate relative impact position
                    x_rel := (next_ball_y + (BALL_SIZE / 2)) - (p2_paddle_y + (PADDLE_HEIGHT / 2));
                    
                    -- Adjust Y direction based on impact location and paddle speed
                    next_ball_dy := next_ball_dy + (M_X_REL * x_rel) / 30 + (K_PADDLE_SPEED * v_paddle2);
                    
                    -- Clamp Y direction to prevent excessive angles
                    if next_ball_dy > 5 then
                        next_ball_dy := 5;
                    elsif next_ball_dy < -5 then
                        next_ball_dy := -5;
                    end if;
                    
                    -- Clamp X direction to prevent excessive speeds
                    if next_ball_dx > 4 then
                        next_ball_dx := 4;
                    elsif next_ball_dx < -4 then
                        next_ball_dx := -4;
                    end if;
                    
                    -- Clamp X position to prevent sticking into the paddle
                    next_ball_x := PLAYER2_PADDLE_X - BALL_SIZE;
                end if;
                
                -- Assign the calculated next positions and directions to the actual signals
                ball_x <= next_ball_x;
                ball_y <= next_ball_y;
                ball_dx <= next_ball_dx;
                ball_dy <= next_ball_dy;
                
                -- Check for scoring
                if (next_ball_x + BALL_SIZE >= 640) then
                    -- Player 1 scores
                    if p1_score < 10 then
                        p1_score <= p1_score + 1;
                    end if;
                    
                    -- Reset ball position and direction
                    ball_x  <= 300;
                    ball_y  <= 220;
                    ball_dx <= -2;
                    ball_dy <= 2;
                    
                    -- Check for game over
                    if p1_score >= 9 then
                        game_state <= GAME_OVER;
                    end if;
                    
                elsif (next_ball_x <= 0) then
                    -- Player 2 scores
                    if p2_score < 10 then
                        p2_score <= p2_score + 1;
                    end if;
                    
                    -- Reset ball position and direction
                    ball_x  <= 300;
                    ball_y  <= 220;
                    ball_dx <= 2;
                    ball_dy <= 2;
                    
                    -- Check for game over
                    if p2_score >= 9 then
                        game_state <= GAME_OVER;
                    end if;
                end if;
                
            elsif frame = '1' and game_state = GAME_OVER then
            -- In GAME_OVER state, handle game reset
                if state_rst = '1' then
                    -- Change Game State to PLAYING
                    game_state <= PLAYING;
                    -- Reset Score Counters
                    p1_score <= 0;
                    p2_score <= 0;
                    
                    -- Reset Ball Position and Direction
                    ball_x  <= 100;
                    ball_y  <= 100;
                    ball_dx <= 2;
                    ball_dy <= 2;
                end if;
            end if;
        end if;
    end process;
    
    ------------------------------------------------------------------
    -- Process VGA Rendering
    ------------------------------------------------------------------
    process(hcount, vcount, ball_x, ball_y, p1_paddle_y, p2_paddle_y, p1_score, p2_score, game_state)
    begin
        -- Default: no color
        obj_red_i <= "00";
        obj_grn_i <= "00";
        obj_blu_i <= "00";
    
        -- Game Over Display
        if game_state = GAME_OVER then
            -- Determine the winner and set the color accordingly
            if p1_score >= 9 then
                -- Player 1 wins: Fill screen with red
                obj_red_i <= "11";
                obj_grn_i <= "00";
                obj_blu_i <= "00";
            elsif p2_score >= 9 then
                -- Player 2 wins: Fill screen with blue
                obj_red_i <= "00";
                obj_grn_i <= "00";
                obj_blu_i <= "11";
            else
                -- Shouldn't happen
                obj_red_i <= "00";
                obj_grn_i <= "00";
                obj_blu_i <= "00"; -- White or another neutral color
            end if;
        else
            -- Ball Rendering
            if (to_integer(hcount) >= ball_x) and 
                (to_integer(hcount) < ball_x + BALL_SIZE) and
                (to_integer(vcount) >= ball_y) and
                (to_integer(vcount) < ball_y + BALL_SIZE) then
                obj_red_i <= "11";
                obj_grn_i <= "11";
                obj_blu_i <= "11";
            end if;
    
            -- Player 1 Paddle Rendering
            if (to_integer(hcount) >= PLAYER1_PADDLE_X) and
                (to_integer(hcount) < PLAYER1_PADDLE_X + PADDLE_WIDTH) and
                (to_integer(vcount) >= p1_paddle_y) and
                (to_integer(vcount) < p1_paddle_y + PADDLE_HEIGHT) then
                obj_red_i <= "11";   -- Red color
                obj_grn_i <= "00";
                obj_blu_i <= "00";
            end if;
    
            -- Player 2 Paddle Rendering
            if (to_integer(hcount) >= PLAYER2_PADDLE_X) and
                (to_integer(hcount) < PLAYER2_PADDLE_X + PADDLE_WIDTH) and
                (to_integer(vcount) >= p2_paddle_y) and
                (to_integer(vcount) < p2_paddle_y + PADDLE_HEIGHT) then
                obj_red_i <= "00";
                obj_grn_i <= "00";
                obj_blu_i <= "11";   -- Blue color
            end if;
    
            -- Player 1 Score Box Rendering
            -- Draw the border
            if ((to_integer(hcount) = P1_SCORE_X) or 
                (to_integer(hcount) = P1_SCORE_X + SCORE_BOX_WIDTH - 1)) and
                (to_integer(vcount) >= P1_SCORE_Y) and
                (to_integer(vcount) < P1_SCORE_Y + SCORE_BOX_HEIGHT) then
                obj_red_i <= "11";
                obj_grn_i <= "11";
                obj_blu_i <= "11"; -- White border
            elsif ((to_integer(vcount) = P1_SCORE_Y) or 
                (to_integer(vcount) = P1_SCORE_Y + SCORE_BOX_HEIGHT - 1)) and
                (to_integer(hcount) >= P1_SCORE_X) and
                (to_integer(hcount) < P1_SCORE_X + SCORE_BOX_WIDTH) then
                obj_red_i <= "11";
                obj_grn_i <= "11";
                obj_blu_i <= "11"; -- White border
            end if;
    
            -- Fill Player 1 Score Box based on p1_score
            if (to_integer(hcount) > P1_SCORE_X) and
                (to_integer(hcount) < P1_SCORE_X + SCORE_BOX_WIDTH - 1) then
                -- Calculate the filled width based on score
                if (to_integer(hcount) <= P1_SCORE_X + (p1_score * (SCORE_BOX_WIDTH / 10))) and
                    (to_integer(vcount) > P1_SCORE_Y) and
                    (to_integer(vcount) < P1_SCORE_Y + SCORE_BOX_HEIGHT - 1) then
                    obj_red_i <= "11";
                    obj_grn_i <= "00";
                    obj_blu_i <= "00"; -- Filled portion
                end if;
            end if;
    
            -- Player 2 Score Box Rendering
            -- Draw the border
            if ((to_integer(hcount) = P2_SCORE_X) or 
                (to_integer(hcount) = P2_SCORE_X + SCORE_BOX_WIDTH - 1)) and
                (to_integer(vcount) >= P2_SCORE_Y) and
                (to_integer(vcount) < P2_SCORE_Y + SCORE_BOX_HEIGHT) then
                obj_red_i <= "11";
                obj_grn_i <= "11";
                obj_blu_i <= "11"; -- White border
            elsif ((to_integer(vcount) = P2_SCORE_Y) or 
                (to_integer(vcount) = P2_SCORE_Y + SCORE_BOX_HEIGHT - 1)) and
                (to_integer(hcount) >= P2_SCORE_X) and
                (to_integer(hcount) < P2_SCORE_X + SCORE_BOX_WIDTH) then
                obj_red_i <= "11";
                obj_grn_i <= "11";
                obj_blu_i <= "11"; -- White border
            end if;
    
            -- Fill Player 2 Score Box based on p2_score
            if (to_integer(hcount) > P2_SCORE_X) and
                (to_integer(hcount) < P2_SCORE_X + SCORE_BOX_WIDTH - 1) then
                -- Calculate the filled width based on score
                if (to_integer(hcount) <= P2_SCORE_X + (p2_score * (SCORE_BOX_WIDTH / 10))) and
                    (to_integer(vcount) > P2_SCORE_Y) and
                    (to_integer(vcount) < P2_SCORE_Y + SCORE_BOX_HEIGHT - 1) then
                    obj_red_i <= "00";
                    obj_grn_i <= "00";
                    obj_blu_i <= "11"; -- Filled portion
                end if;
            end if;
    
            end if;
        end process;
    
    ------------------------------------------------------------------
    -- Combine VGA Rendering Signals
    ------------------------------------------------------------------
    obj_red <= obj_red_i;
    obj_grn <= obj_grn_i;
    obj_blu <= obj_blu_i;

    ------------------------------------------------------------------
    -- Update VGA Output with Blank
    ------------------------------------------------------------------
    red   <= "00" when blank = '1' else obj_red;
    green <= "00" when blank = '1' else obj_grn;
    blue  <= "00" when blank = '1' else obj_blu;

end arch;