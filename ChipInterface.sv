`timescale 1 ns / 1 ns
module ChipInterface
    (input  logic   CLOCK_50,
     input  logic[17:0] SW,
     input  logic[3:0] KEY,
     output logic[17:0] LEDR,
     output logic[8:0] LEDG,
     output logic[6:0] HEX7, HEX6 ,HEX5, HEX4, HEX3, HEX2, HEX1, HEX0);

    assign LEDR = SW;
    assign LEDG = {2'd0, ~KEY[3],
    			   1'b0, ~KEY[2],
    			   1'b0, ~KEY[1],
    			   1'b0, ~KEY[0]};

    /*SimpleTest st(
    	.clk(CLOCK_50),
    	.sw(SW),
    	.key(KEY),
    	.hexDisplays({HEX7, HEX6 ,HEX5, HEX4, HEX3, HEX2, HEX1, HEX0}));*/

	/*MemTest mt(
    	.clk(CLOCK_50),
    	.sw(SW),
    	.key(KEY),
    	.hexDisplays({HEX7, HEX6 ,HEX5, HEX4, HEX3, HEX2, HEX1, HEX0}));*/

	NeuralHookup nh(
    	.clk(CLOCK_50),
    	.sw(SW),
    	.key(KEY),
    	.hexDisplays({HEX7, HEX6 ,HEX5, HEX4, HEX3, HEX2, HEX1, HEX0}));

endmodule: ChipInterface





module ToppTest;
 bit[31:0] data;
	 bit[31:0] result;
	initial begin 
	data= 32'hfffadf8d;
	forever #5 data= data+32'h00001111;
	end 
	
sigmoid nh(data, result);


endmodule: ToppTest


module TopTest;
    bit clk;
    bit[17:0] sw;
    bit[3:0] key;
    bit[15:0] finalVal;
    bit[7:0][6:0] hexDisplays;
	 	bit  [31:0]  dataa;
	bit   [31:0]  datab;
	bit   [31:0]  result;
	

    initial begin
        clk = 0;
		    dataa= 32'b00000000000000000000000000001111;
		  datab=32'b10000000100000010000000000000011;
		  /*
		  The MSB holds the sign bit.
			The next 8 bits hold the exponent bits.
				23 LSBs hold the mantissa.

		  
		  */
        forever #5 clk = ~clk;
        end

   

	
	NeuralHookup nh(
    	.clk(clk),
    	.sw(sw),
    	.key(key),
    	.hexDisplays(hexDisplays));
		
		

		
	//	int_to_float inttofloat(.input_a(dataa),.output_z(result));
		
		
		CONVERT con(
		.clock(clk),
		.dataa(dataa),
		.result(result)
		);
		
	
//		mu fp (
//		.clock(clk),
//		.dataa(dataa),
//		.datab(datab),
//		.result(result));
		
		
		//			 FP_Mu nhh
//	( 
//	
//	.a(dataa),
//	.b(datab),
//	.p(result))) ;
//	
	//https://github.com/dawsonjon/fpu

endmodule: TopTest

module NeuralHookup
    (input  bit   clk,
     input  bit[17:0] sw,
     input  bit[3:0] key,
     output bit [7:0][6:0] hexDisplays);

	bit[31:0]  out;
	bit[10:0] address;
    bit[11:0][31:0] mem_data;

    // Parameters
	bit[3:0][3:0][31:0] hidden_products;
	bit[3:0][31:0] hidden_sums;
	bit[3:0][31:0] hidden_outputs;
	bit[3:0][31:0] output_products;

    // Stored values (not intermediate calculations)
	bit[2:0][31:0] input_values;
	bit[3:0][3:0][31:0] stored_hidden_weights;
	bit[3:0][31:0] stored_output_weights;
	bit[3:0][31:0] stored_hidden_outputs;
	bit[31:0] stored_final_output;

    	// Update parameters info
	bit[31:0] final_output;
	bit[31:0] output_error, output_diff, output_inversion, output_err_temp;
	bit[3:0][31:0] hidden_error, hidden_inversion, hidden_err_temp1, hidden_err_temp2;
	bit[3:0][3:0][31:0] hidden_correction;
	bit[3:0][31:0] hidden_correc_temp;
	bit[3:0][31:0] out_correction;
	bit[31:0] out_error_temp;

	// Stored error values
	bit[31:0] stored_output_error;
	bit[3:0][31:0] stored_hidden_error;
   	bit[31:0] learn_rate;

bit[72:0] numIterations;
	
bit[31:0] iw; // initial weight


    
    enum logic[2:0] {propagation, backpropagate, test } cs, ns;

	
  assign mem_data[0]= 32'h0001e000; // 1
  assign mem_data[1]=32'h0001e000; //  1
  assign mem_data[2]= 32'h00001000; //  0 target 

  assign mem_data[3]= 32'h0001e000; // 1
  assign mem_data[4]= 32'h00001000; //  0
  assign mem_data[5]= 32'h0001e000; //  1 target 


  assign mem_data[6]= 32'h00001000; // 0
  assign mem_data[7]= 32'h0001e000; //  1
  assign mem_data[8]= 32'h0001e000; //  1 target 


  assign mem_data[9]=  32'h00001000; // 0
  assign mem_data[10]= 32'h00001000; //  0
  assign mem_data[11]= 32'h00001000; //  0 target 


//assign iw = 32'h00003800; // 1/8 + 1/16 + 1/32 ~ 0.22 ~ 0.2

assign output_diff = input_values[2] - stored_final_output;
	
	



bit [3:0] i;
    initial begin  // initialize 
    i<=4'd0;//address 
	 numIterations<=0;
    cs=propagation;
    learn_rate <= 32'h00001000; // 0.25
	iw <= 32'h00003800;
  
    end

	
//initial begin
//		  	for (int i=0; i < 4; i++) begin
  //          		for (int l=0; l < 4; l++) begin

    //        		stored_hidden_weights[i][l] <=  32'h00003800;
	//			end
	//			end 


            	
	//	end
		
	//initial begin 
	  //  stored_output_weights[0] <= 32'h00003800;
		//stored_output_weights[1] <= 32'h00003800; 
		//stored_output_weights[2] <= 32'h00003800; 
		//stored_output_weights[3] <= 32'h00003800; 
		
	  	//end
	  


    
 
 // initial begin 
  //repeat (200) 
   // begin
//#5~10 is for upate weight
 //#10 i <= i == 9? 0: (i+3) ; 
 	//input_sel <= input_sel == 5 ? 0 : input_sel + 1;

 
   // end

	 //end 

initial begin 
numIterations=numIterations+1;
input_values[0] <= mem_data[0];
input_values[1] <= mem_data[1];
input_values[2] <= mem_data[2];
stored_output_weights[0] <= 32'h00003800;
stored_output_weights[1] <= 32'h00003800; 
stored_output_weights[2] <=  32'h00003800;
stored_output_weights[3] <=  32'h00003800;

	for (int i=0; i < 4; i++) begin
            		for (int l=0; l < 4; l++) begin

            		stored_hidden_weights[i][l] <=   32'h00003800;
				end
				end 

ns=backpropagate;
end 

always@(negedge clk ) begin 

i <= i == 9? 0: (i+3) ;
 //numIterations=numIterations+1;
 if(cs != backpropagate)
 begin 
input_values[0] <= mem_data[i];
input_values[1] <= mem_data[i+1];
input_values[2] <= mem_data[i+2];
end

cs=ns;

 
end 




 assign stored_output_error = cs==backpropagate? output_error:stored_output_error;
 
assign stored_hidden_error = cs==backpropagate? hidden_error:stored_hidden_error;
 
 
always_ff @(negedge clk) begin 

//stored_final_output<=32'b0;
//stored_hidden_outputs[1]<=32'b0;
//stored_hidden_outputs[0]<=32'b0;
//stored_hidden_outputs[2]<=32'b0;
//stored_hidden_outputs[3]<=32'b0;

//stored_output_error<=32'b0;
//stored_hidden_error[0] <=32'b0;
//stored_hidden_error[1] <= 32'b0;
//stored_hidden_error[2] <=32'b0;
//stored_hidden_error[3] <=32'b0;
/*
	for (int i=0; i < 4; i++) begin
            		for (int l=0; l < 4; l++) begin

            		stored_hidden_weights[i][l] <=  32'h00003800;
				end
				end 
*/
ns=backpropagate;

 if(cs==propagation)begin
  
  ns=backpropagate;
   end
 
  else begin 
 // stored_output_error <= output_error;
  stored_final_output<= final_output;
  stored_hidden_outputs <= hidden_outputs;
 // stored_hidden_error <= hidden_error;
  	for (int i=0; i < 4; i++) begin
            		for (int l=0; l < 2; l++) begin
            			stored_hidden_weights[i][l] <=stored_hidden_weights[i][l] + hidden_correction[i][l];
            			end
 
    end
            	
   stored_output_weights[0] <= stored_output_weights[0] + out_correction[0];
	   stored_output_weights[1] <= stored_output_weights[1] + out_correction[1];
		   stored_output_weights[2] <= stored_output_weights[2] + out_correction[2];
			   stored_output_weights[3] <= stored_output_weights[3] + out_correction[3];
			   numIterations=numIterations+1;
				
  //ns= numIterations== 1000 ? test: propagation;
  ns=  propagation;
  end


  

  end

  
	assign output_inversion = 32'h00010000 - stored_final_output;
    	fixed_point_multiplier OERR_MULT(
		.dataa(output_diff),
		.datab(output_inversion),
		.result(output_err_temp));
	fixed_point_multiplier OERR_FINAL_MULT(
		.dataa(output_err_temp),
		.datab(stored_final_output),
		.result(output_error));



//always_ff @(negedge clk)
//begin 
//numIterations=numIterations-1;
//input_values[i] <= mem_data[i];
//input_values[i+1] <= mem_data[i+1];
//input_values[i+2] <= mem_data[i+2];
//end 




	always_comb begin
		for (int i = 0; i < 4; i++) begin
			hidden_inversion[i] = 1 - stored_hidden_outputs[i];
		end
	end


    always_comb begin
		for (int k=0; k<4; k++) begin: ADDER_OUTER
				hidden_sums[k] = hidden_products[0][k] + 
								 hidden_products[1][k] ;
								
        end
    end


    genvar k, j;
	generate
	
			for (j=0; j < 4; j++) begin: HID_MULTS_INNER
				for (k=0; k<2; k++) begin: HID_MULTS_OUTER
				fixed_point_multiplier HIDMULT(
					.dataa(stored_hidden_weights[k][j]),//ex: weights for a target 
					.datab(input_values[k]), //input value [4] (target)
					.result(hidden_products[k][j]));
			
				end
			// Perform activation function on sum
			sigmoid sigm(
				.data(hidden_sums[j]),
				.result(hidden_outputs[j]));

			fixed_point_multiplier OUTMULT(
				.dataa(hidden_outputs[j]),
				.datab(stored_output_weights[j]),
				.result(output_products[j]));
			
			end
	endgenerate



    generate
	
			for (j=0; j < 4; j++) begin: HID_MUL
            fixed_point_multiplier HERR_TEMP1(
				.dataa(stored_hidden_outputs[j]),
				.datab(hidden_inversion[j]),
				.result(hidden_err_temp1[j]));

			fixed_point_multiplier HERR_TEMP2(
				.dataa(stored_output_error), //don't exist 
				.datab(stored_output_weights[j]), 
				.result(hidden_err_temp2[j]));

			fixed_point_multiplier HERR_FINAL(
				.dataa(hidden_err_temp2[j]),
				.datab(hidden_err_temp1[j]),
				.result(hidden_error[j]));

			end
	endgenerate

	 generate
	
			for (j=0; j < 4; j++) begin: HID_MU

                	fixed_point_multiplier HID_CORRECT_TEMP1(
				.dataa(learn_rate),
				.datab(stored_hidden_error[j]),
				.result(hidden_correc_temp[j]));

             for (k=0; k<2; k++) begin: HID_MULTS_OUT
				fixed_point_multiplier HID_CORRECTT(
					.dataa(hidden_correc_temp[j]),
					.datab(input_values[k]),
					.result(hidden_correction[j][k]));
						end
						end
	endgenerate

	fixed_point_multiplier out_correc(
		.dataa(learn_rate),
		.datab(stored_output_error),
		.result(out_error_temp));
			
     generate
		
			for (j=0; j < 4; j++) begin: HID_MUU

            fixed_point_multiplier HID_CORRECT_TEMP22(
				.dataa(out_error_temp),
				.datab(stored_hidden_outputs[j]),
				.result(out_correction[j]));
		
	
		end
	endgenerate


    assign final_output = output_products[0] + 
						  output_products[1] +
						  output_products[2] +
						  output_products[3];
		
        
    
endmodule: NeuralHookup




