=begin
	function of diag stress test
=end

require 'orclib'
require 'csv'
require 'pry'
require '../../orc_service/ruby_client/watch_dog_client.rb'



include Orclib::MsgModule

SCRIPT_VERSION = "1.0.0"

class Diag_Stress_test

	# attr_reader
	attr_accessor :diag_loops , :task_file_name , :diag_folder ,:tasks_row , :id , :diag_case , :result , :atitool_timeout , :adjust_clock ,:asic_die ,:asic_package ,:default_clock , :default_voltage , :current_voltage, :max_voltage, :voltage_step, :voltage_name , :server_ip , :wombat_ip , :client_ip
	
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


		#adjust_voltage
		@voltage_name = nil
		@oringinal_voltage = {}
		@starting_voltage = nil
		@step_voltage = 0.00625   #APU usually has this value
		@current_voltage = nil 
		@actual_voltage = nil
		@max_voltage = 1.2 #default max voltage
		@default_voltage = {}


		
		
		#ip
		@server_ip = nil
		@wombat_ip = nil
		@client_ip = nil
		

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

#function area
def 
end





begin
	
	putz "Diag_Stress_test begin"

	$os = Orclib::OS()
	$obj = Orclib::ObjectSave()
	$t = Orclib::Atitool()
	
	#judge if start by machine
	$manal_run = false
	ARGV.each |i|
		if i =~ /^--start/
			$manal_run = true
		end
	end
	
	
	
	if $manal_run == true
		$test = Diag_Stress_test.new()
	
	
		ARGV.each do |i|
			if i =~ /--server_ip=(.*)/
				$test.server_ip = $1
			end
			
			if i =~ /--wombat_ip=(.*)/
				$test.wombat_ip = $1
			end
			
			if i =~ /--client_ip=(.*)/
				$test.client_ip = $1
			end
			
		end
	else
		$test = $obj.restore
	end
	
	#start watch_dog function 
	$client = WatchDogClient.new($test.server_ip,$test.client_ip)
	
	
	
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
			

			#parament read from tasks.csv
			$test.diag_loops = current_row["diag_loops"].to_i
			$test.diag_case = current_row["workload"]
			$test.id = current_row["id"]
			$test.asic_package = current_row["asic_package"]
			$test.asic_die = current_row["asic_die"]
			$test.voltage_name = current_row["voltage_rail_name"]
			$test.starting_voltage = current_row["starting_voltage"]



			#call some module
			$t = Orclib::Atitool()
			$test.atitool_timeout = current_row["atitool_timeout"]
			
			
			#reading clks
			regex = /clk_(.*)/
			current_row.headers.each do |i|
				if i.match(regex)
					$test.adjust_clock["#{i.match(regex)[1]}"] = current_row["#{i}"]
				end
			end


			





			#read default clk
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
			
			$adjust_voltage step by step
			
			
		elsif current_row == nil
			putz "Finishing test"
			break
		end
	end	
	$test.clean_up
	$test.summary
end