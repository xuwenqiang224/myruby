=begin
	function of diag stress test
=end

require 'orclib'
require 'csv'
require 'pry'

include Orclib::MsgModule

SCRIPT_VERSION = "1.0.0"

class Diag_Stress_test

	# attr_reader
	attr_accessor :diag_loops , :task_file_name , :diag_folder ,:tasks_row , :id , :diag_case , :result , :atitool_timeout , :adjust_clock ,:asic_die ,:asic_package ,:default_clock
	
	def initialize
		@diag_loops = 1
		@task_file_name = "vmin_tasks.csv"
		@diag_folder = "/root/diag"
		@tasks_row = 1
		@id = ""
		@diag_case = nil
		
		@result = {}
		
		#dajust clk_
		@atitool_timeout = 2
		@adjust_clock = {}
		@default_clock = {}
	end

	def run_diag
		diag = Orclib::Diagnostic($test.diag_folder)
		putz "run #{$test.id} for #{@diag_loops} times"
		result_loops  = []
		@diag_loops.times do 
			output = diag.run(@diag_case)
			result = diag.parse_result
			if result == "pass" || result == "fail"
				return result
			else 
				summary = diag.summarize(result)
				puts "started diag test"
				pass = diag.passed?(summary)
				puts "done diag"
				putz "Diag pass: #{pass}"
				result = 'pass'
			end
			putz result.to_s
			result_loops << result
		
		end
		putz result_loops.to_s
		
		@result["#{$test.id}"] = result_loops 
		putz "finishing run #{@id} for #{@diag_loops} times "
	end
	
	def summary()
		result_sum = {}
		@result.each do |c,r|
			pass_count = 0
			c.each do |i|
				if i.match(/[pass|true]/)
					pass_count = pass_count +1
				end
			end
			result_sum["#{c} #{@duag_loops}"] = "#{((pass_count.to_f)/(r.count.to_f))*100}%"
		end
		result_sum.each do |c,r|
			putz "case : #{c} , pass rate : #{r}"
		end
	end
	
	def reset_clk
		@default_clock.each do |clk_name,value|
			$t.set_die_clock(clk_name,value,@.asic_package,@asic_die)	
		end
	end
end


begin
	
	putz "Diag_Stress_test begin"
	$os = Orclib::OS()
	$test = Diag_Stress_test.new()
	$t = Orclib::Atitool()
	
	#get default_clock
	regex = /clk_(.*)/
	
		
		
	list = CSV.read($test.task_file_name, headers: :true,converters: :numeric)
	
	loop do 
		current_row = list[$test.tasks_row]
		if current_row != nil
			$test.tasks_row = $test.tasks_row + 1
			if current_row["diag_folder"] != nil
				$test.diag_folder = current_row["diag_folder"]
			end
			
			$test.diag_loops = current_row["diag_loops"].to_i
			$test.diag_case = current_row["workload"]
			$test.id = current_row["id"]
			$test.asic_package = current_row["asic_package"]
			$test.asic_die = current_row["asic_die"]
			$t = Orclib::Atitool()
			$test.atitool_timeout = current_row["atitool_timeout"]
			
			
			#reading clks
			regex = /clk_(.*)/
			current_row.headers.each do |i|
				if i.match(regex)
					$test.adjust_clock["#{i.match(regex)[1]}"] = current_row["#{i}"]
				end
			end
			current_row.headers.each do |i|
				if i.match(regex)
					default = Orclib::Atitool()
					default.timeout = 2
					default.set_apu($test.asic_package,$test.asic_die)
					$test.default_clock["#{i.match(regex)[1]}"] = default.get_clock("#{i.match(regex)[1]}")
				end
			end
			
			#adjust clk with Atitool
			if $test.adjust_clock.size > 0
				$test.adjust_clock.each do |i|
					if i[1] != nil
						$t.set_die_clock(i[0],i[1],$test.asic_package,$test.asic_die)
					end					
				end
			end
			
			#run diag_test
			$test.run_diag()
			
			
			
		elsif current_row == nil
			putz "Finishing test"
			break
		end
	end	
	$test.clean_up
	$test.summary
end