require 'erb'
require 'yaml'

task :exam do
	Dir.foreach("_exams") do |directory|
		if not (directory == '.' || directory == '..')
			puts directory

	yaml_file = YAML.load_file("_exams/" + directory)
	name = yaml_file["title"]
	#puts name
	
	questions = yaml_file["q"]
	#puts questions

	footer = yaml_file["footer"]
	#puts footer
		
	j = 0
	liste=[]
	for i in questions
		inc = File.read("_includes/q/" + i )
		liste[j] = inc
		#puts liste[j]
		j = j + 1
	end

	read_erb = File.read("_templates/exam.md.erb")
	#puts read_erb

	f = File.open("sinav.md","w")
	new = ERB.new(read_erb)
	f.write(new.result(binding))
	f.close

	sh "markdown2pdf sinav.md"
	sh "rm sinav.md"


		end
	end
end	

task:default => :exam
