module processor (DIN, reset, clock, run, bus, done);

	input reset, clock, run;  // main control unit inputs
	input [15:0] DIN;         // data in input 
	output reg [15:0] bus;    // data out output
	output reg done;          // done indicator
	

	// control lines
	reg IR_in, G_out, G_in, A_in, addsub, DIN_out;  // enable lines
	reg [2:0] R_out;                                // Register enables
	reg [7:0] R_in;                                 // control to Register lines

	// Separate nine least sig bit of DIN into iii, xxx, yyy
	wire [2:0] i, reg_x, reg_y;
	assign {i, reg_x, reg_y} = IR[8:0];

	// assigning states to values
	parameter reg [1:0] T0 = 2'b00, T1 = 2'b01, T2 = 2'b10, T3 = 2'b11;
	reg [1:0] present_state, next_state;

	// state machine
	always @(present_state, run, done) begin
		// changing states depends on clock clock cycles
		case (present_state)
			T0: begin
				// if run sw is at 0 then state returns or remains at T0
				// if a done is true at anytime state returns to T0
				// else state incraments 
				if (!run | done) 
					next_state = T0;
				else 
					next_state = T1;
			end
			T1: begin
				if (!run | done) 
					next_state = T0;
				else 
					next_state = T2;
			end
			T2: begin
				if (!run | done) 
					next_state = T0;
				else 
					next_state = T3;
			end
			default: begin
				next_state = T0;
			end
		endcase
	end

	// Assert control lines according to Table 2
	always @(present_state, i, reg_x, reg_y) begin
		// setting enable lines to zero
		{IR_in, R_out, R_in, G_out, DIN_out, A_in, addsub, G_in, done} = 23'b0;
			case (present_state)
				// state T0 
				T0: begin
					IR_in = 1'b1;
				end
				// state T1
				T1: begin
					case (i)
						3'h0: begin               // move instuction
							R_out = reg_y;        // move reg_y into reg_x
							R_in = 1'b1 << reg_x;  
							done = 1'b1;          // end instuction
						end
						3'h1: begin               // move immediate  
							R_in = 1'b1 << reg_x; // movei value into reg_x
							DIN_out = 1'b1;		  // enable data in
							done = 1'b1;		  // end instuction
						end
						3'h2: begin               // add instuction
							R_out = reg_x;		  // get reg_x
							A_in = 1'b1;		  // enable input ALU
						end
						3'h3: begin				  // sub instuction 
							R_out = reg_x;        // get reg_x
							A_in = 1'b1;		  // enable input ALU
						end	
					endcase
				end
				// state T2
				T2: begin
					case (i)
						3'h2: begin               // add instuction
							R_out = reg_y;        // get reg_y
							G_in = 1'b1;          // enable ALU output
						end
						3'h3: begin               // sub instuction
							R_out = reg_y;        // get reg_y
							G_in = 1'b1;          // enable ALU output
							addsub = 1'b1;        // enable ALU subtraction
						end
					endcase
				end
				// state T3
				T3: begin
					case (i)
						3'h2: begin               // add instuction
							R_in = 1'b1 << reg_x; // store result into reg_x
							G_out = 1'b1;         // enable mux output sum back to ALU
							done = 1'b1;          // end instuction
						end
						3'h3: begin               // sub instuction
							R_in= 1'b1 << reg_x;  // store result into reg_x
							G_out = 1'b1;         // ebable mux to output differnece back to ALU
							done = 1'b1;          // end instuction
						end
					endcase
				end
			endcase
		end

	// Register to change states 
	always @(posedge clock, negedge reset) begin
		if (!reset) begin
			present_state <= T0;         // if reset is true present_state gets reset to T0
		end else
			present_state <= next_state; // on a posedge clock edge states change
		end

	// Register enable wires
	reg [15:0] regn[7:0];
	reg [15:0] IR, A, G;

	// Control Unit: Register Updates
	// Update each register (regn[0] to regn[7]) based on R_in signals
	always @(posedge clock) begin
		regn[0] <= R_in[0] ? bus : regn[0]; // if R_in[i] is true regn gets bus
		regn[1] <= R_in[1] ? bus : regn[1]; // where bus is the the output of the mux
		regn[2] <= R_in[2] ? bus : regn[2]; 
		regn[3] <= R_in[3] ? bus : regn[3]; 
		regn[4] <= R_in[4] ? bus : regn[4]; 
		regn[5] <= R_in[5] ? bus : regn[5]; 
		regn[6] <= R_in[6] ? bus : regn[6]; 
		regn[7] <= R_in[7] ? bus : regn[7]; 
		IR <= IR_in ? DIN : IR;                       // reg input IR for control unit
		A <= A_in ? bus : A;                          // enable line for ALU
		G <= G_in ? (addsub ? A - bus : A + bus) : G; // module for ALU unit
	end

	// Main multiplexer
	always @(*) begin
		if (DIN_out)           // enable line DIN_out
			bus = DIN;         // bus gets DIN if DIN_out true
		else if (G_out)        // enable line G_out
			bus = G;           // bus gets G if G_out is true
		else 
			bus = regn[R_out]; // if nothing else is enabled bus gets a register 
	end
endmodule