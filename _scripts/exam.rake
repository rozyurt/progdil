require 'erb'
require 'yaml'

task :exam do
	Dir.foreach("_exams") do |dizin|
		if not (dizin == '.' || dizin == '..')
			puts dizin
	config = YAML.load_file("_exams/" + dizin)
	isim = config["title"]
	#puts isim
	
	sorular=config["q"]
	#puts sorular

	alt_kisim=config["footer"]
	#puts alt_kisim
		
	j=0
	liste=[]
	for i in sorular
		a = File.read("_includes/q/" + i )
		liste[j] = a
		#puts liste[j]
		j = j + 1
end

	oku_erb = File.read("_templates/exam.md.erb")
	#puts oku_erb

	f = File.open("sinav.md","w")
	new = ERB.new(oku_erb)
	f.write(new.result(binding))
	f.close

	sh "markdown2pdf sinav.md"
	sh "rm sinav.md"
end
end
end	
task:default => :exam
